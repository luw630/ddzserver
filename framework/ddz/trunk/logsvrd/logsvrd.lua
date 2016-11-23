local skynet = require "skynet"
local filelog = require "filelog"
local msghelper = require "logsvrmsghelper"
local serverbase = require "serverbase"
local base = require "base"
require "enum"
require "skynet.manager"

local params = ...
local Logsvrd = serverbase:new({
	logger_pool = {}
})

function Logsvrd:tostring()
	return "logsvrd"
end
local function logsvrd_to_sring()
	return Logsvrd:tostring()
end
function  Logsvrd:init()
	msghelper:init(Logsvrd)
	self.eventmng.init(Logsvrd)
	self.eventmng.add_eventbyname("cmd", "logsvrcmd")
	self.eventmng.add_eventbyname("notice", "logsvrnoticemsg")
	---self.eventmng.add_eventbyname("request", "logsvrrequestmsg")
	Logsvrd.__tostring = logsvrd_to_sring
end
skynet.start(function()
	if params == nil then
		Logsvrd:start()
	else
		Logsvrd:start(table.unpack(base.strsplit(params, ",")))
	end
end)
