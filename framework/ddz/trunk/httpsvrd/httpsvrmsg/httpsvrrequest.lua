local skynet = require "skynet"
local filelog = require "filelog"
local msghelper = require "httpsvrhelper"
local msgproxy = require "msgproxy"
local base = require "base"

local filename = "httpsvrrequest.lua"
local HttpsvrRequest = {}

function HttpsvrRequest.process(session, source, event, ...)
	local f = HttpsvrRequest[event] 
	if f == nil then
		filelog.sys_error(filename.." HttpsvrRequest.process invalid event:"..event)
		return nil
	end
	f(...)
end

function HttpsvrRequest.webclient(request)
	local server = msghelper:get_server()
	local agentpool = server.idle_agent_mng
	local agentobj = agentpool:create_service()
	if agentobj == nil then
		filelog.sys_error("HttpsvrRequest.webclient: agentpool:create_service failed", request)
		base.skynet_retpack(nil)
	else
		local agent_sessions = server.used_agent_pool
		skynet.call(agentobj.service, "lua", "cmd", "start", agentobj.id, server.conf)			
		agent_sessions[agentobj.id] = agentobj
		agentobj.responsefunc=skynet.response()

		base.pcall(agentobj.responsefunc, true, skynet.call(agentobj.service, "lua", "request", "webclient", request))
		agentobj.responsefunc = nil
	end
end

function HttpsvrRequest.versioninfo(request)
	local server = msghelper:get_server()
	local agentpool = server.idle_agent_mng
	local agentobj = agentpool:create_service()
	if agentobj == nil then
		filelog.sys_error("HttpsvrRequest.versioninfo: agentpool:create_service failed", request)
		base.skynet_retpack(nil)
	else
		local agent_sessions = server.used_agent_pool
		skynet.call(agentobj.service, "lua", "cmd", "start", agentobj.id, server.conf)			
		agent_sessions[agentobj.id] = agentobj
		agentobj.responsefunc=skynet.response()

		base.pcall(agentobj.responsefunc, true, skynet.call(agentobj.service, "lua", "request", "versioninfo", request))
		agentobj.responsefunc = nil
	end
end

function HttpsvrRequest.generate_params(request, rechargeconf)
	local server = msghelper:get_server()
	local agentpool = server.idle_agent_mng
	local agentobj = agentpool:create_service()
	if agentobj == nil then
		filelog.sys_error("HttpsvrRequest.generate_params: agentpool:create_service failed", request, rechargeconf)
		base.skynet_retpack(nil)
	else
		local agent_sessions = server.used_agent_pool
		skynet.call(agentobj.service, "lua", "cmd", "start", agentobj.id, server.conf)			
		agent_sessions[agentobj.id] = agentobj
		agentobj.responsefunc=skynet.response()

		base.pcall(agentobj.responsefunc, true, skynet.call(agentobj.service, "lua", "request", "generate_params", request, rechargeconf))
		agentobj.responsefunc = nil
	end	
end

return HttpsvrRequest