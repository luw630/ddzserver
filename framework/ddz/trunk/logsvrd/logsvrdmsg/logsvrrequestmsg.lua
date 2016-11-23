local skynet = require "skynet"
local filelog = require "filelog"
local filename = "logsvrrequestmsg.lua"
local base = require "base"
local json = require "cjson"
local configdao = require "configdao"
local msgproxy = require "msgproxy"
local tabletool = require "tabletool"
local timetool = require "timetool"

json.encode_sparse_array(true, 1, 1)

local count = 1
local LogsvrRequestMsg = {}

function LogsvrRequestMsg.process(session, source, event, ...)
	local f = LogsvrRequestMsg[event]
	if f == nil then
		filelog.sys_error(filename.." RechargesvrRequestMsg.process invalid event:"..event)
		base.skynet_retpack(nil)
		return nil
	end
	f(...)	 
end


return LogsvrRequestMsg