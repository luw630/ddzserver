--长连接管理
local incrservicepoolmng = require "incrservicepoolmng"
local filelog = require "filelog"
local skynet = require "skynet"
local base = require "base"
local timetool = require "timetool"

local LongTcpMng = {
	agentpool = nil,
	connections={},
	agents={},
	server=nil,
	agentnum = 0,
}


local function close_socket(fd)
	local server = LongTcpMng.server
	LongTcpMng.connections[fd] = nil
	pcall(skynet.call, server.gate_service, "lua", "kick", fd)
end

local function close_agent(fd)
	local server = LongTcpMng.server
	local c = LongTcpMng.connections[fd]
	local a
	if c ~= nil and c.rid ~= nil then
		LongTcpMng.connections[fd] = nil
		if c.isclose == nil or not c.isclose then
			pcall(skynet.call, server.gate_service, "lua", "kick", fd)
		end
		a = LongTcpMng.agents[c.rid]
		if a ~= nil then
			LongTcpMng.agents[c.rid] = nil
			LongTcpMng.agentnum = LongTcpMng.agentnum - 1
			pcall(skynet.send, a.agent, "lua", "cmd", "close", fd)
		end
		return
	end 
	
	close_socket(fd)
end

function LongTcpMng.init(server, agentmodule, agentsize, agentincr, netpackmodule)
 	LongTcpMng.agentpool = incrservicepoolmng:new({}, {service_name=agentmodule, service_size=agentsize, incr=agentincr}, netpackmodule)
	LongTcpMng.server = server	
	skynet.fork(function()
		local now_time
		while true do
			skynet.sleep(400)
			now_time = timetool.get_time()
			for fd, c in pairs(LongTcpMng.connections) do
				if c.rid == nil then
					if c.time+20 <= now_time then
						filelog.sys_info("LongTcpMng.init timeout kick")
						pcall(skynet.call, server.gate_service, "lua", "kick", fd)
						c.isclose = true
						filelog.sys_warning("delete zombie connection", fd, c)
					end
				end
			end
		end
	end)

end

--表示agent已经退出后的处理
function LongTcpMng.agentexit(fd, rid)
	filelog.sys_info("LongTcpMng.agentexit", fd, rid)
	local server = LongTcpMng.server
	local c = LongTcpMng.connections[fd]
	local a
	if c ~= nil and c.rid == rid then
		LongTcpMng.connections[fd] = nil
		if c.isclose == nil or not c.isclose then
			pcall(skynet.call, server.gate_service, "lua", "kick", fd)
		end
		a = LongTcpMng.agents[rid]
		if a ~= nil and a.fd == fd then
			pcall(skynet.send, a.agent, "lua", "cmd", "close", fd)
			LongTcpMng.agents[rid] = nil
			LongTcpMng.agentnum = LongTcpMng.agentnum - 1
		--[[elseif a ~= nil and a.fd ~= fd then
			pcall(skynet.send, a.agent, "lua", "cmd", "close")
			LongTcpMng.agents[rid] = nil
			LongTcpMng.agentnum = LongTcpMng.agentnum - 1
			close_socket(a.fd)]]			
		end
		return
	end

	if rid ~= nil then
		a = LongTcpMng.agents[rid]
		if a ~= nil 
			and a.agent ~= nil 
			and a.fd == fd then
			pcall(skynet.send, a.agent, "lua", "cmd", "close", a.fd)
			LongTcpMng.agents[rid] = nil
			LongTcpMng.agentnum = LongTcpMng.agentnum - 1
		end
	end
	close_socket(fd)
end

function LongTcpMng.open_socket(fd, ip)
 	local server = LongTcpMng.server
	local status, result = base.pcall(skynet.call, server.gate_service, "lua", "forward", fd)
	if not status then
		pcall(skynet.call, server.gate_service, "lua", "kick", fd)
		return
	end
	if not result then
		pcall(skynet.call, server.gate_service, "lua", "kick", fd)
		return
	end

	local c = {
		fd = fd,
		ip = ip,
		time = timetool.get_time(),
	}
	LongTcpMng.connections[fd] = c
	filelog.sys_info("New client from : " ..ip)
end

function LongTcpMng.close_socket(fd)
	filelog.sys_info("LongTcpMng.close_socket", fd)
	--如果对应的服务存在通知服务玩家掉线
	local c = LongTcpMng.connections[fd]
	local a
	if c ~= nil and c.rid ~= nil then
		a = LongTcpMng.agents[c.rid]
		if a ~= nil and a.fd == fd then
			if c.isclose == nil or not c.isclose then
				filelog.sys_info("LongTcpMng.close_socket disconnect", fd)
				pcall(skynet.send, a.agent, "lua", "cmd", "disconnect", nil, fd)
			end
			return			
		end
	end 
	close_socket(fd)
end

function LongTcpMng.create_session(fd, msgname, request)
 	local result = false
	local status = false
	local server = LongTcpMng.server
	if request.rid == nil then
		return false
	end
	--判断是否断线重连
	if LongTcpMng.agents[request.rid] ~= nil and LongTcpMng.agents[request.rid].agent ~= nil then
		local tmp_fd = LongTcpMng.agents[request.rid].fd		
		--通知agent 更新fd		
		status, result = pcall(skynet.call, LongTcpMng.agents[request.rid].agent,
			 "lua", "cmd", "reconnect",
			  {ip=LongTcpMng.connections[fd].ip, gate = server.gate_service, client = fd, watchdog = skynet.self(), msg=request})
		filelog.sys_info("LongTcpMng.create_session reconnect")
		if not status then
			filelog.sys_warning("LongTcpMng.create_session agent had exit", result)
			close_socket(fd)

			--通知释放之前的socket
			LongTcpMng.agents[request.rid] = nil			
			close_socket(tmp_fd)
			return false
		end

		if not result then
			filelog.sys_warning("LongTcpMng.create_session agent had exit", result)
			close_socket(fd)
			return false			
		end

		if LongTcpMng.connections[fd] == nil then
			--filelog.sys_warning("LongTcpMng.create_session reconn connections[fd] == nil", fd)
			--return false
			LongTcpMng.connections[fd] = {
				fd = fd,
				ip = "",
				time = timetool.get_time(),
			}			
		end 
		--找到一个有效的agent
		LongTcpMng.agents[request.rid].fd = fd
		LongTcpMng.connections[fd].rid = request.rid
		LongTcpMng.connections[fd].isclose = false

		--通知释放之前的socket
		filelog.sys_info("LongTcpMng.create_session close_socket tmp_fd:", tmp_fd)
		close_socket(tmp_fd)
		return true
	elseif LongTcpMng.agents[request.rid] ~= nil and LongTcpMng.agents[request.rid].agent == nil then 
		if LongTcpMng.agents[request.rid].fd ~= nil then
			filelog.sys_info("LongTcpMng.create_session close_socket LongTcpMng.agents[request.rid].fd:", LongTcpMng.agents[request.rid].fd, request.rid)			
			close_socket(LongTcpMng.agents[request.rid].fd)
		end
	end

	local agentservice = LongTcpMng.agentpool:create_service()
	if agentservice == nil then
		filelog.sys_error("LongTcpMng.create_session not enough agentservice")		
		return false
	end
	
	status, result = pcall(skynet.call, agentservice.service, "lua", "cmd", "start", {ip=LongTcpMng.connections[fd].ip, gate = server.gate_service, client = fd, watchdog = skynet.self(), msgname = msgname, msg=request})
	if not status then
		filelog.sys_error("LongTcpMng.create_session agent start failed", result)
		if LongTcpMng.agents[request.rid] ~= nil and LongTcpMng.agents[request.rid].agent ~= nil then
			pcall(skynet.kill, LongTcpMng.agents[request.rid].agent)
		end
		pcall(skynet.kill, agentservice.service)
		close_socket(fd)

		LongTcpMng.agents[request.rid] = nil
		return false		
	end

	if not result then
		filelog.sys_error("LongTcpMng.create_session agent start failed", result)
		if LongTcpMng.agents[request.rid] ~= nil and LongTcpMng.agents[request.rid].agent ~= nil then
			pcall(skynet.kill, LongTcpMng.agents[request.rid].agent)
		end
		pcall(skynet.kill, agentservice.service)

		close_socket(fd)

		LongTcpMng.agents[request.rid] = nil
		return false		
	end

	if LongTcpMng.connections[fd] == nil then
		--filelog.sys_warning("LongTcpMng.create_session new connection[fd] == nil", fd)
		--skynet.send(agentservice.service, "lua", "cmd", "close")
		--LongTcpMng.agents[request.rid] = nil

		--return false
		LongTcpMng.connections[fd] = {
			fd = fd,
			ip = "",
			time = timetool.get_time(),
		}
	end
	LongTcpMng.agents[request.rid] = {}
	LongTcpMng.agents[request.rid].agent = agentservice.service
	LongTcpMng.agents[request.rid].fd = fd
	LongTcpMng.agents[request.rid].serviceid = agentservice.id
	LongTcpMng.connections[fd].rid = request.rid
	LongTcpMng.connections[fd].isclose = false
	LongTcpMng.agentnum = LongTcpMng.agentnum + 1 

	return result
end

function LongTcpMng.heart_timeout(fd)
	local server = LongTcpMng.server
	local c = LongTcpMng.connections[fd]
	filelog.sys_info("LongTcpMng.heart_timeout", fd)
	if c ~= nil then
		pcall(skynet.call, server.gate_service, "lua", "kick", fd)
		LongTcpMng.connections[fd].isclose = true
	end	
end

function LongTcpMng.clear()
	for fd, _ in pairs(LongTcpMng.connections) do
	   close_agent(fd)
	end

	if LongTcpMng.agentpool ~= nil then
		local iter = LongTcpMng.agentpool:idle_service_iter()
		local service = iter()
		while service do
			pcall(skynet.send, service, "lua", "cmd", "close")
			service = iter()
		end
	end
end 

return LongTcpMng