local skynet = require "skynet"
local filelog = require "filelog"
local msghelper = require "logsvrmsghelper"
local configdao = require "configdao"
local filename = "logsvrcmd.lua"
local Logsvrcmd = {}

function Logsvrcmd.process(session, source, event, ...)
	local f = Logsvrcmd[event]
	if f == nil then
		filelog.sys_error(filename.."Logsvrcmd.process invalid event:"..event)
		return nil
	end
	f(...)	 
end

function Logsvrcmd.start(conf)
	local logscfg = configdao.get_common_conf("logscfg")
	msghelper:set_idle_logger_pool(logscfg)
	msghelper:loadloggercfg(logscfg)
	skynet.retpack(true)
end

return Logsvrcmd