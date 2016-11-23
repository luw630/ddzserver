local skynet = require "skynet"
local filelog = require "filelog"
local msghelper = require "agenthelper"
local base = require "base"
local serverbase = require "serverbase"

local params = ...

local Agent = serverbase:new({
		session_id = nil,
		session_begin_time = 0,
	}) 


function Agent:tostring()
	return "login agent"
end

local function agent_to_string()
	return Agent:tostring()
end

function  Agent:init()
	msghelper:init(Agent)
	self.eventmng.init(Agent)
	self.eventmng.add_eventbyname("cmd", "agentcmd")
	self.eventmng.add_eventbyname("request", "agentrequest")

	Agent.__tostring = agent_to_string						
end

function Agent:clear()
	
end

skynet.start(function()
	if params == nil then
		Agent:start()
	else		
		Agent:start(table.unpack(base.strsplit(params, ",")))
	end	
end)