local skynet = require "skynet"
local filelog = require "filelog"
local msghelper = require "agenthelper"
local msgproxy = require "msgproxy"
local table = table
require "enum"

local  QuickStart = {}

--[[
//快速开始请求
message QuickStartReq {
	optional Version version = 1;
	optional int32 room_type = 2; //指定快速开始进入指定场次
	optional int32 id = 3;	//指定上一次所在的桌号主要用于快速换桌,如果不需要换桌逻辑填0
}

//响应快速开始
message QuickStartRes {
	optional int32 errcode = 1; //错误原因 0表示成功
	optional string errcodedes = 2; //错误描述
	optional TableStateItem tablestate = 3; //桌子状态
}
]]

function  QuickStart.process(session, source, fd, request)
	local responsemsg = {
		errcode = EErrCode.ERR_SUCCESS,
	}
	local server = msghelper:get_server()

	--检查当前登陆状态
	if not msghelper:is_login_success() then
		filelog.sys_warning("QuickStart.process invalid server state", server.state)
		responsemsg.errcode = EErrCode.ERR_INVALID_REQUEST
		responsemsg.errcodedes = "无效的请求！"
		msghelper:send_resmsgto_client(fd, "QuickStartRes", responsemsg)		
		return
	end

	request.rid = server.rid
	responsemsg = msgproxy.sendrpc_reqmsgto_tablesvrd(server.rid, "quickstart", request)

	if not msghelper:is_login_success() then
		return
	end

	if responsemsg == nil then
		responsemsg = {
			errcode = EErrCode.ERR_INVALID_REQUEST,
			errcodedes = "无效的请求!"
		}
	end
	msghelper:send_resmsgto_client(fd, "QuickStartRes", responsemsg)
end

return QuickStart

