local nk = require("nakama")
nk.logger_info("Lua module loaded")

local function healthcheck(context, payload)
    return nk.json_encode({status = "OK"})
end

nk.register_rpc(healthcheck, "healthcheck")