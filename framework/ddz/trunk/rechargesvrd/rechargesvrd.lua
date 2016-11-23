local skynet = require "skynet"
local filelog = require "filelog"
local msghelper = require "rechargesvrhelper"
local serverbase = require "serverbase"
local base = require "base"
local table = table
require "skynet.manager"

local params = ...

local Rechargesvrd = serverbase:new({})


function Rechargesvrd:tostring()
	return "Rechargesvrd"
end

local function rechargesvrd_to_sring()
	return Rechargesvrd:tostring()
end

function Rechargesvrd:init()
	msghelper:init(Rechargesvrd)
	self.eventmng.init(Rechargesvrd)
	self.eventmng.add_eventbyname("notice", "rechargesvrnotice")
	self.eventmng.add_eventbyname("request", "rechargesvrrequest")
	self.eventmng.add_eventbyname("cmd", "rechargesvrcmd")

	Rechargesvrd.__tostring = rechargesvrd_to_sring
end

skynet.start(function()
	if params == nil then
		Rechargesvrd:start()
	else
		Rechargesvrd:start(table.unpack(base.strsplit(params, ",")))
	end
end)

