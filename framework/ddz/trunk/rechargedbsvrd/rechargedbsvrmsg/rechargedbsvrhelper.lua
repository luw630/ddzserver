local skynet = require "skynet"
local filelog = require "filelog"
local helperbase = require "helperbase"
local base = require "base"
local filename = "rechargedbsvrhelper.lua"

local RechargedbsvrHelper = helperbase:new({}) 

function RechargedbsvrHelper:get_redissvrid_byorderid(order_id)
	local server = self.server
	if order_id == nil then
		return nil
	end
	local hash = base.strtohash(order_id)	

	local index = hash % (#(server.redisdb_service)) + 1
	return server.redisdb_service[index]
end

function RechargedbsvrHelper:get_mysqlsvrid_byorderid(order_id)
	local server = self.server
	if order_id == nil then
		return nil
	end	
	local hash = base.strtohash(order_id)	
	local index = hash % (#(server.mysqldb_service)) + 1
	return server.mysqldb_service[index]
end


return	RechargedbsvrHelper 