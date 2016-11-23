local skynet = require "skynet"
local filelog = require "filelog"
local msghelper = require "agenthelper"
local timetool = require "timetool"
local filename = "agentcmd.lua"
local httpc = require "http.httpc"

local AgentCMD = {}

function AgentCMD.process(session, source, event, ...)
	local f = AgentCMD[event] 
	if f == nil then
		filelog.sys_error(filename.."AgentCMD.process invalid event:"..event)
		return nil
	end
	f(...)
end

function AgentCMD.start(session_id, conf)
	local server = msghelper:get_server()
	server.session_begin_time = timetool.get_time()
	server.session_id = session_id
	
	if conf.dns_server == nil or conf.dns_port == nil then
		httpc.dns()
	else
		httpc.dns(conf.dns_server, conf.dns_port)
	end

	if conf.timeout == nil then
		httpc.timeout = 10
	else
		httpc.timeout = conf.timeout
	end

	skynet.retpack(true)
end

return AgentCMD