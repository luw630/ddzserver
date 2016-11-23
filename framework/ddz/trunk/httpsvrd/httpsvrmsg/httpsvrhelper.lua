local skynet = require "skynet"
local filelog = require "filelog"
local helperbase = require "helperbase"
local socket = require "socket"
local incrservicepoolmng = require "incrservicepoolmng"
local filename = "httpsvrhelper.lua"

local HttpsvrHelper = helperbase:new({}) 

function HttpsvrHelper:init_idle_agent_mng(conf)
	--初始化agent池子
	self.server.idle_agent_mng = incrservicepoolmng:new({}, {service_name="agent", service_size=conf.agentsize, incr=conf.agentincr})
end

function HttpsvrHelper:open_websvr_socket(conf)
	local ip
	local port
	local agentobj
	if conf.svr_ip == nil then
		ip = "0.0.0.0"
	else
		ip = conf.svr_ip
	end

	if conf.svr_port == nil then
		port = 8080
	else
		port = conf.svr_port
	end

	if conf.svr_port ~= self.server.conf.svr_port then
		socket.close(self.server.websvr_socket_fd)
	end

	self.server.websvr_socket_fd = socket.listen(ip, port)
	socket.start(self.server.websvr_socket_fd , function(client_fd, addr)
		agentobj = self.server.idle_agent_mng:create_service()
		if agentobj == nil then
			filelog.sys_error("HttpsvrHelper:open_websvr_socket, idle_agent_mng:create_service failed", client_fd, addr)
			socket.close(client_fd)
		else
			skynet.call(agentobj.service, "lua", "cmd", "start", agentobj.id, self.server.conf)			
			agentobj.client_fd = client_fd
			self.server.used_agent_pool[agentobj.id] = agentobj
			skynet.send(agentobj.service, "lua", "request", "callback", client_fd)
		end
	end)
end

function HttpsvrHelper:deleteagent(id)
	local agentobj = self.server.used_agent_pool[id]
	if agentobj ~= nil then
		if agentobj.client_fd ~= nil then
			socket.close(agentobj.client_fd)
		end
		if agentobj.responsefunc ~= nil then
			base.pcall(agentobj.responsefunc, true, nil)
		end 
		self.server.used_agent_pool[id] = nil
	end
end

return	HttpsvrHelper