local skynet = require "skynet"
local filelog = require "filelog"
local msghelper = require "loggerobjhelper"
local base = require "base"
local loggerlogic = require "loggerlogic"
local filename = "loggerobjcmd.lua"
local LoggerobjCmd = {}

function LoggerobjCmd.process(session, source, event, ...)
    local f = LoggerobjCmd[event]
    if f == nil then
        filelog.sys_error(filename.." AgentCMD.process invalid event:"..event)
        return nil
    end
    f(...)
end

function LoggerobjCmd.start(conf,svr_id)
    loggerlogic.init(conf,svr_id)
	base.skynet_retpack(true)
end

function LoggerobjCmd.addlog(message)
	-- body
	local server = msghelper:get_server()
	if server.loggerbuffers == nil then
		server.loggerbuffers = {}
	end
	table.insert(server.loggerbuffers,message)
	base.skynet_retpack(true)
end


return LoggerobjCmd


