# Change Log
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/) 
and this project adheres to [Semantic Versioning](http://semver.org/).

## [Unreleased]

### Changed

- Use per request configuration when cache is disabled [PR #289](https://github.com/3scale/apicast/pull/289)
- Automatically expose all environment variables starting with `APICAST_` or `THREESCALE_` to nginx [PR #292](https://github.com/3scale/apicast/pull/292)
- Increased number of background timers and connections in the cosocket pool [PR #290](https://github.com/3scale/apicast/pull/290)

### Added

- Backend HTTP client that uses cosockets [PR #295](https://github.com/3scale/apicast/pull/295)
- Ability to customize main section of nginx configuration (and expose more env variables) [PR #292](https://github.com/3scale/apicast/pull/292)
- Ability to lock service to specific configuration version [PR #293](https://github.com/3scale/apicast/pull/292)
- Experimental option for true out of band reporting (`APICAST_REPORTING_WORKERS`) [PR #290](https://github.com/3scale/apicast/pull/290)
- `/status/info` endpoint to the Management API [PR #290](https://github.com/3scale/apicast/pull/290)

### Removed

- Removed support for sending Request logs [PR #296](https://github.com/3scale/apicast/pull/296)

## [3.0.0-beta2] - 2017-03-08

### Fixed

- Reloading of configuration with every request when cache is disabled [PR #287](https://github.com/3scale/apicast/pull/287)

## [3.0.0-beta1] - 2017-03-03

### Changed
- Lazy load DNS resolver to improve performance [PR #251](https://github.com/3scale/apicast/pull/251)
- Execute queries to all defined nameservers in parallel [PR #260](https://github.com/3scale/apicast/pull/260)
- `RESOLVER` ENV variable overrides all other nameservers detected from `/etc/resolv.conf` [PR #260](https://github.com/3scale/apicast/pull/260)
- Use stale DNS cache when there is a query in progress for that record [PR #260](https://github.com/3scale/apicast/pull/260)
- Bump s2i-openresty to 1.11.2.2-2 [PR #260](https://github.com/3scale/apicast/pull/260)
- Echo API on port 8081 listens accepts any Host [PR #268](https://github.com/3scale/apicast/pull/268)
- Always use DNS search scopes [PR #271](https://github.com/3scale/apicast/pull/271)
- Reduce use of global objects [PR #273](https://github.com/3scale/apicast/pull/273)
- Configuration is using LRU cache [PR #274](https://github.com/3scale/apicast/pull/274)
- Management API not opened by default [PR #276](https://github.com/3scale/apicast/pull/276)
- Management API returns ready status with no services [PR #]()

### Added

* Danger bot to check for consistency in Pull Requests [PR #265](https://github.com/3scale/apicast/pull/265)
* Start local caching DNS server in the container [PR #260](https://github.com/3scale/apicast/pull/260)
* Management API to show the DNS cache [PR #260](https://github.com/3scale/apicast/pull/260)
* Extract correct Host header from the backend endpoint when backend host not provided [PR #267](https://github.com/3scale/apicast/pull/267)
* `APICAST_CONFIGURATION_CACHE` environment variable [PR #270](https://github.com/3scale/apicast/pull/270)
* `APICAST_CONFIGURATION_LOADER` environment variable [PR #270](https://github.com/3scale/apicast/pull/270)

### Removed

* Support for downloading configuration via curl [PR #266](https://github.com/3scale/apicast/pull/266)
* `AUTO_UPDATE_INTERVAL` environment variable [PR #270](https://github.com/3scale/apicast/pull/270)
* `APICAST_RELOAD_CONFIG` environment variable [PR #270](https://github.com/3scale/apicast/pull/270)
* `APICAST_MISSING_CONFIGURATION` environment variable [PR #270](https://github.com/3scale/apicast/pull/270)

## [3.0.0-alpha2] - 2017-02-06

### Added
- A way to override backend endpoint [PR #248](https://github.com/3scale/apicast/pull/248)

### Changed
- Cache all calls to `os.getenv` via custom module [PR #231](https://github.com/3scale/apicast/pull/231)
- Bump s2i-openresty to 1.11.2.2-1 [PR #239](https://github.com/3scale/apicast/pull/239)
- Use resty-resolver over nginx resolver for HTTP [PR #237](https://github.com/3scale/apicast/pull/237)
- Use resty-resolver over nginx resolver for Redis [PR #237](https://github.com/3scale/apicast/pull/237)
- Internal change to reduce global state [PR #233](https://github.com/3scale/apicast/pull/233)

### Fixed
- [OAuth] Return correct state value back to client

### Removed
- Nginx resolver directive auto detection. Rely on internal DNS resolver [PR #237](https://github.com/3scale/apicast/pull/237)

## [3.0.0-alpha1] - 2017-01-16
### Added
- A CHANGELOG.md to track important changes
- User-Agent header with APIcast version and system information [PR #214](https://github.com/3scale/apicast/pull/214)
- Try to load configuration from V2 API [PR #193](https://github.com/3scale/apicast/pull/193)

### Changed
- Require openresty 1.11.2 [PR #194](https://github.com/3scale/apicast/pull/194)
- moved development from `v2` branch to `master` [PR #209](https://github.com/3scale/apicast/pull/209)
- `X-3scale-Debug` HTTP header now uses Service Token [PR #217](https://github.com/3scale/apicast/pull/217)

## [2.0.0] - 2016-11-29
### Changed
- Major rewrite using JSON configuration instead of code generation.

[Unreleased]: https://github.com/3scale/apicast/compare/v2.0.0...HEAD
[2.0.0]: https://github.com/3scale/apicast/compare/v0.2...v2.0.0
[3.0.0-alpha1]: https://github.com/3scale/apicast/compare/v2.0.0...v3.0.0-alpha1
[3.0.0-alpha2]: https://github.com/3scale/apicast/compare/v3.0.0-alpha1...v3.0.0-alpha2
[3.0.0-beta1]: https://github.com/3scale/apicast/compare/v3.0.0-alpha2...v3.0.0-beta1
[3.0.0-beta2]: https://github.com/3scale/apicast/compare/v3.0.0-beta1...v3.0.0-beta2
