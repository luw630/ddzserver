local skynet = require "skynet"
local filelog = require "filelog"
local timetool = require "timetool"
local filename = "helperbase.lua"

local HelperBase = {
	server = nil,
}

function HelperBase:new(obj)
    obj = obj or {}
    setmetatable(obj, self)
    self.__index = self
    self.__newindex = self
    return obj
end

function HelperBase:init(server)
	if server == nil or type(server) ~= "table" then
		skynet.exit()
	end
	HelperBase.server = server
end

function HelperBase:event_process(type, msgname, ...)
	HelperBase.server.eventmng.process(_, _, type, msgname, ...)
end

function HelperBase:send_resmsgto_client(fd, msgname, msg)
	if HelperBase.server ~= nil then
		HelperBase.server:send_resmsgto_client(fd, msgname, msg)
	else
		filelog.sys_error(filename.."HelperBase server == nil")
	end
end

function HelperBase:send_noticemsgto_client(fd, msgname, msg)
	if HelperBase.server ~= nil then
		HelperBase.server:send_noticemsgto_client(fd, msgname, msg)
	else
		filelog.sys_error(filename.."HelperBase server == nil")
	end
end

function HelperBase:set_enterging_state(state)
	HelperBase.server.isenteringtableormatch = state
	HelperBase.server.enteringtableormatchtime = timetool.get_time()
end

function HelperBase:get_enterging_state()
	if HelperBase.server.isenteringtableormatch 
		and (HelperBase.server.enteringtableormatchtime + 8 >= timetool.get_time()) then
		return false
	end
	return HelperBase.server.isenteringtableormatch
end

function HelperBase:get_server()
	return HelperBase.server
end

return	HelperBase  