local skynet = require "skynet"
local helperbase = require "helperbase"
local filelog = require "filelog"
local LogsvrmsgHelper = helperbase:new({})

function LogsvrmsgHelper:set_idle_logger_pool(conf)
    for key, value in pairs(conf) do
    	for k = 1, value.num do
    		serverid = value.begin_id + k
    		self.server.logger_pool[serverid] = skynet.newservice("loggerobj")
    	end
    end

end


function LogsvrmsgHelper:loadloggercfg(conf)
	-- body
	for serverid, value in pairs(self.server.logger_pool) do
		for m,n in pairs(conf) do
			if serverid > n.begin_id and serverid <= n.begin_id + n.num then
				local result = skynet.call(value, "lua", "cmd", "start", conf[m], skynet.getenv("svr_id"))
			end
		end
	end
end
return	LogsvrmsgHelper