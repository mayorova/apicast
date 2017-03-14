local env = require 'resty.env'
local custom_config = env.get('APICAST_CUSTOM_CONFIG')
local configuration_store = require 'configuration_store'
local util = require('util')

local oauth = require 'oauth'
local resty_url = require 'resty.url'

local assert = assert
local type = type
local next = next
local insert = table.insert

local concat = table.concat
local gsub = string.gsub
local tonumber = tonumber
local setmetatable = setmetatable
local encode_args = ngx.encode_args
local resty_resolver = require 'resty.resolver'
local semaphore = require('ngx.semaphore')
local backend_client = require('backend_client')
local timers = semaphore.new(tonumber(env.get('APICAST_REPORTING_THREADS') or 0))

local empty = {}

local response_codes = env.enabled('APICAST_RESPONSE_CODES')

local post_action_needed = response_codes or timers:count() < 1

local _M = { }

local mt = {
  __index = _M
}

function _M.new(configuration)
  return setmetatable({
    configuration = assert(configuration, 'missing proxy configuration')
  }, mt)
end

-- Error Codes
local function error_no_credentials(service)
  ngx.log(ngx.INFO, 'no credentials provided for service ', service.id)
  ngx.var.cached_key = nil
  ngx.status = service.auth_missing_status
  ngx.header.content_type = service.auth_missing_headers
  ngx.print(service.error_auth_missing)
  ngx.exit(ngx.HTTP_OK)
end

local function error_authorization_failed(service)
  ngx.log(ngx.INFO, 'authorization failed for service ', service.id)
  ngx.var.cached_key = nil
  ngx.status = service.auth_failed_status
  ngx.header.content_type = service.auth_failed_headers
  ngx.print(service.error_auth_failed)
  ngx.exit(ngx.HTTP_OK)
end

local function error_no_match(service)
  ngx.log(ngx.INFO, 'no rules matched for service ', service.id)
  ngx.var.cached_key = nil
  ngx.status = service.no_match_status
  ngx.header.content_type = service.no_match_headers
  ngx.print(service.error_no_match)
  ngx.exit(ngx.HTTP_OK)
end

local function error_service_not_found(host)
  ngx.status = 404
  ngx.print('')
  ngx.log(ngx.WARN, 'could not find service for host: ', host)
  ngx.exit(ngx.status)
end
-- End Error Codes

local function get_debug_value(service)
  return ngx.var.http_x_3scale_debug == service.backend_authentication.value
end

local function find_service_strict(self, host)
  local found
  local services = self.configuration:find_by_host(host)

  for s=1, #services do
    local service = services[s]
    local hosts = service.hosts or {}

    for h=1, #hosts do
      if hosts[h] == host then
        found = service
        break
      end
    end
    if found then break end
  end

  return found or ngx.log(ngx.ERR, 'service not found for host ', host)
end

local function find_service_cascade(self, host)
  local found
  local request = ngx.var.request
  local services = self.configuration:find_by_host(host)

  for s=1, #services do
    local service = services[s]
    local hosts = service.hosts or {}

    for h=1, #hosts do
      if hosts[h] == host then
        local name = service.system_name or service.id
        ngx.log(ngx.DEBUG, 'service ', name, ' matched host ', hosts[h])
        local usage, matched_patterns = service:extract_usage(request)

        if next(usage) and matched_patterns ~= '' then
          ngx.log(ngx.DEBUG, 'service ', name, ' matched patterns ', matched_patterns)
          found = service
          break
        end
      end
    end
    if found then break end
  end

  return found or find_service_strict(self, host)
end

if configuration_store.path_routing then
  ngx.log(ngx.WARN, 'apicast experimental path routing enabled')
  _M.find_service = find_service_cascade
else
  _M.find_service = find_service_strict
end

local http = {
  get = function(url)
    ngx.log(ngx.INFO, '[http] requesting ', url)
    local backend_upstream = ngx.ctx.backend_upstream
    local previous_real_url = ngx.var.real_url
    ngx.log(ngx.DEBUG, '[ctx] copying backend_upstream of size: ', #backend_upstream)
    local res = ngx.location.capture(assert(url), { share_all_vars = true, ctx = { backend_upstream = backend_upstream, backend_endpoint = ngx.var.backend_endpoint } })

    local real_url = ngx.var.real_url

    if real_url ~= previous_real_url then
      ngx.log(ngx.INFO, '[http] ', real_url, ' (',res.status, ')')
    else
      ngx.log(ngx.INFO, '[http] status: ', res.status)
    end

    ngx.var.real_url = ''

    return res
  end
}

local function oauth_authrep(proxy, service)
  local cached_key = ngx.var.cached_key .. ":" .. ngx.var.usage
  local access_tokens = assert(ngx.shared.api_keys, 'missing shared dictionary: api_keys')
  local is_known = access_tokens:get(cached_key)

  if is_known == 200 then
    ngx.log(ngx.DEBUG, 'apicast cache hit key: ', cached_key)
    ngx.var.cached_key = cached_key
  else
    proxy:set_backend_upstream(service)
    local res = http.get("/threescale_oauth_authrep")

    if res.status ~= 200   then
      access_tokens:delete(ngx.var.cached_key)
      ngx.status = res.status
      ngx.header.content_type = "application/json"
      error_authorization_failed(service)
    else
      access_tokens:set(ngx.var.cached_key,200)
    end

    ngx.var.cached_key = nil
  end
end

local function authrep(proxy, service)
  -- NYI: return to lower frame
  local cached_key = ngx.var.cached_key .. ":" .. ngx.var.usage
  local api_keys = ngx.shared.api_keys
  local is_known = api_keys and api_keys:get(cached_key)

  if is_known == 200 then
    ngx.log(ngx.DEBUG, 'apicast cache hit key: ', cached_key)
    ngx.var.cached_key = cached_key
  else

    proxy:set_backend_upstream(service)
    ngx.log(ngx.INFO, 'apicast cache miss key: ', cached_key)
    local res = http.get("/threescale_authrep")

    ngx.log(ngx.DEBUG, '[backend] response status: ', res.status, ' body: ', res.body)

    if res.status == 200 then
      if api_keys then
        ngx.log(ngx.INFO, 'apicast cache write key: ', cached_key)
        api_keys:set(cached_key, 200)
      end
    else -- TODO: proper error handling
      if api_keys then api_keys:delete(cached_key) end
      ngx.status = res.status
      ngx.header.content_type = "application/json"
      -- error_authorization_failed is an early return, so we have to reset cached_key to nil before -%>
      error_authorization_failed(service)
    end
    -- set this request_to_3scale_backend to nil to avoid doing the out of band authrep -%>
    ngx.var.cached_key = nil
  end
end

function _M:authorize(backend_version, service)
  if backend_version == 'oauth' then
    oauth_authrep(self, service)
  else
    authrep(self, service)
  end

  if not post_action_needed then
    self:post_action(true)
  end
end

function _M:set_service(host)
  host = host or ngx.var.host
  local service = self:find_service(host)

  if not service then
    error_service_not_found(host)
  end

  ngx.ctx.service = service
  ngx.var.service_id = service.id
  return service
end

function _M.get_upstream(service)
  service = service or ngx.ctx.service

  local url = resty_url.split(service.api_backend) or empty
  local scheme = url[1] or 'http'
  local host, port, path =
    url[4], url[5] or resty_url.default_port(url[1]), url[6] or ''

  return {
    server = host,
    host = service.hostname_rewrite or host,
    uri  = scheme .. '://upstream' .. path,
    port = tonumber(port)
  }
end

function _M.set_upstream(service)
  local upstream = _M.get_upstream(service)

  ngx.ctx.upstream = resty_resolver:instance():get_servers(upstream.server, { port = upstream.port })

  ngx.var.proxy_pass = upstream.uri
  ngx.req.set_header('Host', upstream.host or ngx.var.host)
end

function _M:set_backend_upstream(service)
  service = service or ngx.ctx.service

  ngx.var.backend_authentication_type = service.backend_authentication.type
  ngx.var.backend_authentication_value = service.backend_authentication.value
  ngx.var.version = self.configuration.version

  -- set backend
  local url = resty_url.split(service.backend.endpoint or ngx.var.backend_endpoint)
  local scheme, _, _, server, port, path =
    url[1], url[2], url[3], url[4], url[5] or resty_url.default_port(url[1]), url[6] or ''

  local backend_upstream = resty_resolver:instance():get_servers(server, { port = port or nil })
  ngx.log(ngx.DEBUG, '[resolver] resolved backend upstream: ', #backend_upstream)
  ngx.ctx.backend_upstream = backend_upstream

  ngx.var.backend_endpoint = scheme .. '://backend_upstream' .. path
  ngx.var.backend_host = service.backend.host or server or ngx.var.backend_host
end

function _M:call(host)
  host = host or ngx.var.host
  local service = ngx.ctx.service or self:set_service(host)

  if service.backend_version == 'oauth' then
    local f, params = oauth.call()

    if f then
      ngx.log(ngx.DEBUG, 'apicast oauth flow')
      return function() return f(params) end
    end
  end

  return function()
    -- call access phase
    return self:access(service)
  end
end

function _M:access(service)
  local backend_version = service.backend_version

  if ngx.status == 403  then
    ngx.say("Throttling due to too many requests")
    ngx.exit(403)
  end

  local request = ngx.var.request -- NYI: return to lower frame

  ngx.var.secret_token = service.secret_token

  local credentials, err = service:extract_credentials()

  if not credentials or #credentials == 0 then
    if err then
      ngx.log(ngx.WARN, "cannot get credentials: ", err)
    end
    return error_no_credentials(service)
  end

  insert(credentials, 1, service.id)
  ngx.var.cached_key = concat(credentials, ':')

  local _, matched_patterns, params = service:extract_usage(request)
  local usage = encode_args(params)

  -- remove integer keys for serialization
  -- as ngx.encode_args can't serialize integer keys
  for i=1,#credentials do
    credentials[i] = nil
  end

  -- save those tables in context so they can be used in the backend client
  ngx.ctx.usage = params
  ngx.ctx.credentials = credentials

  credentials = encode_args(credentials)

  ngx.var.credentials = credentials
  ngx.var.usage = usage
  ngx.log(ngx.INFO, 'usage: ', usage, ' credentials: ', credentials)

  -- WHAT TO DO IF NO USAGE CAN BE DERIVED FROM THE REQUEST.
  if ngx.var.usage == '' then
    ngx.header["X-3scale-matched-rules"] = ''
    return error_no_match(service)
  end

  if get_debug_value(service) then
    ngx.header["X-3scale-matched-rules"] = matched_patterns
    ngx.header["X-3scale-credentials"]   = ngx.var.credentials
    ngx.header["X-3scale-usage"]         = ngx.var.usage
    ngx.header["X-3scale-hostname"]      = ngx.var.hostname
  end

  self:authorize(backend_version, service)
end

local function response_codes_data()
  local params = {}

  if not response_codes then
    return params
  end

  if response_codes then
    params["log[code]"] = ngx.var.status
  end

  return params
end

local function response_codes_encoded_data()
  return ngx.escape_uri(ngx.encode_args(response_codes_data()))
end

local function handle_post_action_response(cached_key, res)
  if res.ok == false or res.status ~= 200 then
    local api_keys = ngx.shared.api_keys

    if api_keys then
      ngx.log(ngx.NOTICE, 'apicast cache delete key: ', cached_key, ' cause status ', res.status)
      api_keys:delete(cached_key)
    else
      ngx.log(ngx.ALERT, 'apicast cache error missing shared memory zone api_keys')
    end

    ngx.log(ngx.ERR, 'http_client error: ', res.error, ' status: ', res.status)
  end
end

local function post_action(_, cached_key, backend, ...)
  local res = util.timer('backend post_action', backend.authrep, backend, ...)

  handle_post_action_response(cached_key, res)

  if not post_action_needed then
    timers:post(1)
  end
end

local function capture_post_action(self, cached_key, service)
  self:set_backend_upstream(service)

  local auth_uri = service.backend_version == 'oauth' and 'threescale_oauth_authrep' or 'threescale_authrep'
  local res = http.get("/".. auth_uri .."?log=" .. response_codes_encoded_data())

  handle_post_action_response(cached_key, res)
end

local function timer_post_action(self, cached_key, service)
  local backend = assert(backend_client:new(service), 'missing backend')

  local ok, err

  if post_action_needed then
    ok = true
  else
    ok, err = timers:wait(10)
  end

  if ok then
    -- TODO: try to do this in different phase and use semaphore to limit number of background threads
    -- TODO: Also it is possible to use sets in shared memory to enqueue work
    ngx.timer.at(0, post_action, cached_key, backend, ngx.ctx.usage, ngx.ctx.credentials, response_codes_data())
  else
    ngx.log(ngx.ERR, 'failed to acquire timer: ', err)
    return capture_post_action(self, cached_key, service)
  end
end

function _M:post_action(force)
  if not post_action_needed and not force then
    return nil, 'post action not needed'
  end

  local cached_key = ngx.var.cached_key

  if cached_key and cached_key ~= "null" then
    ngx.log(ngx.INFO, '[async] reporting to backend asynchronously, cached_key: ', cached_key)

    local service_id = ngx.var.service_id
    local service = ngx.ctx.service or self.configuration:find_by_id(service_id)

    if post_action_needed then
      capture_post_action(self, cached_key, service)
    else
      timer_post_action(self, cached_key, service)
    end
  else
    ngx.log(ngx.INFO, '[async] skipping after action, no cached key')
  end
end

if custom_config then
  local path = package.path
  local module = gsub(custom_config, '%.lua$', '') -- strip .lua from end of the file
  package.path = package.path .. ';' .. ngx.config.prefix() .. '?.lua;'
  local ok, c = pcall(function() return require(module) end)
  package.path = path

  if ok then
    if type(c) == 'table' and type(c.setup) == 'function' then
      ngx.log(ngx.DEBUG, 'executing custom config ', custom_config)
      c.setup(_M)
    else
      ngx.log(ngx.ERR, 'failed to load custom config ', custom_config, ' because it does not return table with function setup')
    end
  else
    ngx.log(ngx.ERR, 'failed to load custom config ', custom_config, ' with ', c)
  end
end

return _M
