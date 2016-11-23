local skynet = require "skynet"
local filelog = require "filelog"
local msghelper = require "agenthelper"
local msgproxy = require "msgproxy"
local table = table
require "enum"

local  GetGameRooms = {}

--[[
//取得游戏类型列表
message GetGameRoomsReq {
	optional Version version = 1;
	optional int32 room_type = 2;//房间类型(1经典场)
}

//响应游戏类型列表
message GetGameRoomsRes {
	optional int32 errcode = 1; //错误原因 0表示成功
	optional string errcodedes = 2; //错误描述
	repeated TableStateItem tablestates = 3; //桌子状态列表
}
]]

function  GetGameRooms.process(session, source, fd, request)
	local responsemsg = {
		errcode = EErrCode.ERR_SUCCESS,
	}
	local server = msghelper:get_server()

	--检查当前登陆状态
	if not msghelper:is_login_success() then
		filelog.sys_warning("GetGameRooms.process invalid server state", server.state)
		responsemsg.errcode = EErrCode.ERR_INVALID_REQUEST
		responsemsg.errcodedes = "无效的请求！"
		msghelper:send_resmsgto_client(fd, "GetGameRoomsRes", responsemsg)		
		return
	end

	request.rid = server.rid
	responsemsg = msgproxy.sendrpc_reqmsgto_tablesvrd(server.rid, "getgamerooms", request)

	if not msghelper:is_login_success() then
		return
	end

	if responsemsg == nil then
		responsemsg = {
			errcode = EErrCode.ERR_INVALID_REQUEST,
			errcodedes = "无效的请求!"
		}
	end
	msghelper:send_resmsgto_client(fd, "GetGameRoomsRes", responsemsg)
end

return GetGameRooms

