local skynet = require "skynet"
local filelog = require "filelog"
local channel = require "channel"
local helperbase = require "helperbase"
local timetool = require "timetool"
local configdao = require "configdao"
local filename = "agenthelper.lua"

local AgentHelper = helperbase:new({})

function AgentHelper:agentexit()
	--做一些退出前处理
	skynet.send(skynet.getenv("svr_id"), "lua", "cmd", "agentexit", self.server.session_id)
	self.server:clear()
	skynet.exit()	
end

function AgentHelper:check_session_timeout()
	local now_time = timetool.get_time()
	local session_timeout = configdao.get_common_conf("session_timeout")
	local timeout = session_timeout - (now_time - self.server.session_begin_time)
	skynet.fork(function()
		skynet.sleep(timeout)
		self:agentexit()
	end)
end 


function AgentHelper:load_channel()
	--[[local config_filename = "./agentmsg/channel.lua"
	local file = io.open(config_filename, "r")
	local data = file:read("*all")
    local ftmp = load(data, "@"..config_filename, "t")
    if ftmp == nil then
    	filelog.sys_error(filename.." AgentHelper.load_channel load "..config_filename.." failed")
        return
    end

    channel = ftmp()]]
end

function AgentHelper:write_http_info(...)
	filelog.sys_obj("http", "payinfo", ...)
end

function AgentHelper:write_httpclient_info(...)
	filelog.sys_obj("http", "webclient", ...)
end

function AgentHelper:get_channel_byurl(url)
	return channel:get_channel_byurl(url)
end

function AgentHelper:get_channel_byid(id)
	return channel:get_channel_byid(id)
end

return	AgentHelper  
