local skynet = require "skynet"
local filelog = require "filelog"
local msghelper = require "httpsvrhelper"
local httpc = require "http.httpc"
local configdao = require "configdao"
local base = require "base"
local msgproxy = require "msgproxy"
local filename = "httpsvrcmd.lua"
local HttpsvrCMD = {}

function HttpsvrCMD.process(session, source, event, ...)
	local f = HttpsvrCMD[event] 
	if f == nil then
		filelog.sys_error(filename.."HttpsvrCMD.process invalid event:"..event)
		return nil
	end
	f(...)	 
end

function HttpsvrCMD.start(conf)
	local server = msghelper:get_server()

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

	server.conf = conf

	msghelper:init_idle_agent_mng(conf)

	msghelper:open_websvr_socket(conf)
end

function HttpsvrCMD.reload(...)	
	base.skynet_retpack(1)
	filelog.sys_error("HttpsvrCMD.reload start")

	configdao.reload()
	skynet.sleep(200)

	local server = msghelper:get_server()
	local svrs = configdao.get_svrs("httpsvrs")
	local conf = svrs[skynet.getenv("svr_id")]

	if conf ~= nil then
		if conf.dns_server ~= server.conf.dns_server
			or conf.dns_port ~= server.conf.dns_port then
			httpc.dns(conf.dns_server, conf.dns_port)			
		end 
		if conf.timeout ~= nil then
			httpc.timeout = conf.timeout
		end
	end

	msghelper:open_websvr_socket(conf)

	server.conf = conf

	msgproxy.reload()
	
	filelog.sys_error("HttpsvrCMD.reload end")
end

function HttpsvrCMD.agentexit(id)
	msghelper:deleteagent(id)
end

return HttpsvrCMD