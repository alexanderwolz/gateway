local http = require "resty.http"
local httpc = http.new()
httpc:set_timeout(2000)
local res, err = httpc:request_uri("http://127.0.0.1:80/health")
if not res or res.status ~= 200 then
    os.exit(1)
end
