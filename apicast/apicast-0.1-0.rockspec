package = "apicast"
source = { url = '.' }
version = '0.1-0'
dependencies = {
  'lua-resty-http == 0.10-0',
  'inspect == 3.1.0-1',
  'router == 2.1-0',
  'lua-resty-jwt == 0.1.10-1'
}
build = {
   type = "builtin",
   modules = {
   }
}
