local skynet = require "skynet"
local msghelper = require "rechargedbsvrhelper"
local base = require "base"
local serverbase = require "serverbase"
require "skynet.manager"

local params = ...

local Rechargedbsvrd = serverbase:new({
	redisdb_service = {},
	mysqldb_service = {},
})

function Rechargedbsvrd:tostring()
	return "Rechargedbsvrd"
end

local function rechargedbsvrd_to_sring()
	return Rechargedbsvrd:tostring()
end

function  Rechargedbsvrd:init()
	msghelper:init(Rechargedbsvrd)
	self.eventmng.init(Rechargedbsvrd)
	self.eventmng.add_eventbyname("cmd", "rechargedbsvrcmd")
	self.eventmng.add_eventbyname("dao", "rechargedbsvrdao")
	Rechargedbsvrd.__tostring = rechargedbsvrd_to_sring
end 

skynet.start(function()  
	if params == nil then
		Rechargedbsvrd:start()
	else		
		Rechargedbsvrd:start(table.unpack(base.strsplit(params, ",")))
	end	
end)
