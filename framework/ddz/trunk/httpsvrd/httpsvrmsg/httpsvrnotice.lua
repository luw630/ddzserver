local skynet = require "skynet"
local filelog = require "filelog"
local msghelper = require "httpsvrhelper"
local msgproxy = require "msgproxy"

local filename = "httpsvrnotice.lua"
local HttpsvrNotice = {}

function HttpsvrNotice.process(session, source, event, ...)
	local f = HttpsvrNotice[event] 
	if f == nil then
		filelog.sys_error(filename.." HttpsvrNotice.process invalid event:"..event)
		return nil
	end
	skynet.retpack(true)
	f(...)
end

return HttpsvrNotice