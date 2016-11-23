local filelog = require "filelog"
local filename = "rechargesvrnotice.lua"

local RechargesvrNotice = {}

function RechargesvrNotice.process(session, source, event, ...)
	local f = RechargesvrNotice[event] 
	if f == nil then
		filelog.sys_error(filename.." RechargesvrNotice.process invalid event:"..event)
		return nil
	end
	f(...)
end

return RechargesvrNotice