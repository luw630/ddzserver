local skynet = require "skynet"
local filelog = require "filelog"
local configdao = require "configdao"
local msgproxy = require "msgproxy"
local msghelper = require "rechargesvrhelper"
local filename = "rechargesvrcmd.lua"
local RechargesvrCMD = {}

function RechargesvrCMD.process(session, source, event, ...)
	local f = RechargesvrCMD[event] 
	if f == nil then
		filelog.sys_error(filename.."RechargesvrCMD.process invalid event:"..event)
		return nil
	end
	f(...)	 
end

function RechargesvrCMD.start(conf)	
	skynet.retpack(true)
end

function RechargesvrCMD.reload(...)
	base.skynet_retpack(1)
	filelog.sys_error("RechargesvrCMD.reload start")

	configdao.reload()

	skynet.sleep(200)

	msgproxy.reload()
	
	filelog.sys_error("RechargesvrCMD.reload end")
end

return RechargesvrCMD