local skynet = require "skynet"
local msghelper = require "httpsvrhelper"
local base = require "base"
local serverbase = require "serverbase"
local table = table
require "skynet.manager"

local params = ...

local Httpsvrd = serverbase:new({
	idle_agent_mng = nil,
	used_agent_pool = {},
	websvr_socket_fd = nil,
	conf = nil,
})

function Httpsvrd:tostring()
	return "Httpsvrd"
end

local function Httpsvrd_to_sring()
	return Httpsvrd:tostring()
end

function  Httpsvrd:init()
	msghelper:init(Httpsvrd)
	self.eventmng.init(Httpsvrd)
	self.eventmng.add_eventbyname("cmd", "httpsvrcmd")
	self.eventmng.add_eventbyname("notice", "httpsvrnotice")
	self.eventmng.add_eventbyname("request", "httpsvrrequest")
	Httpsvrd.__tostring = Httpsvrd_to_sring
end

skynet.start(function()
	if params == nil then
		Httpsvrd:start()
	else		
		Httpsvrd:start(table.unpack(base.strsplit(params, ",")))
	end	
end)