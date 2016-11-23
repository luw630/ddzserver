--
-- Created by IntelliJ IDEA.
-- User: juzhong
-- Date: 2016/11/2
-- Time: 11:05
-- To change this template use File | Settings | File Templates.
--
local skynet = require "skynet"
local filelog = require "filelog"
local msghelper = require "agenthelper"
local processstate = require "processstate"
local msgproxy = require "msgproxy"
require "enum"
local processing = processstate:new({timeout=4})
local SendMessage = {}
--[[
// 玩家请求发送聊天信息
message SendMessageReq {
    optional Version version = 1;
    optional string messages = 2; //json 串
    optional int32 chat_type = 3; //聊天类型(备用)
}

// 玩家发送聊天信息回应
message SendMessageRes {
    optional int32 errcode = 1;
    optional string errcodedes = 2;
}
-- --]]



--- 发送消息处理函数
-- @param session
-- @param source
-- @param fd
-- @param request 客户端发送的请求
--
function SendMessage.process(session, source, fd, request)
    local responsemsg = {
        errcode = EErrCode.ERR_SUCCESS,
    }
    local server = msghelper:get_server()

    ---检查当前登陆状态
    if not msghelper:is_login_success() then
        filelog.sys_error("Getmails.process invalid server state", server.state)
        responsemsg.errcode = EErrCode.ERR_INVALID_REQUEST
        responsemsg.errcodedes = "无效的请求!"
        msghelper:send_resmsgto_client(fd, "SendMessageRes", responsemsg)
        return
    end

    if processing:is_processing() then
        responsemsg.errcode = EErrCode.ERR_DEADING_LASTREQ
        responsemsg.errcodedes = "正在处理上一次请求！"
        msghelper:send_resmsgto_client(fd, "DoactionRes", responsemsg)
        return
    end

    if server.roomsvr_id == ""
            or server.roomsvr_table_id <= 0
            or server.roomsvr_table_address < 0
            or server.roomsvr_seat_index <= 0 then
        responsemsg.errcode = EErrCode.ERR_NOT_INTABLE
        responsemsg.errcodedes = "你已经不在桌内！"
        msghelper:send_resmsgto_client(fd, "SendMessageRes", responsemsg)
        return
    end

    -- if request.chat_type ~= EChatMessageType.COMMON_CHAT_IN_TABLE then
    --     ----判断聊天类型
    --     responsemsg.errcode = EErrCode.ERR_INVALID_CHAT_TYPE
    --     responsemsg.errcodedes = "错误的聊天类型"
    --     msghelper:send_resmsgto_client(fd, "SendMessageRes", responsemsg)
    --     return
    -- end

    request.rid = server.rid
    processing:set_process_state(true)
    responsemsg = msgproxy.sendrpc_reqmsgto_roomsvrd(nil, server.roomsvr_id, server.roomsvr_table_address, "sendTableMessage", request)
    processing:set_process_state(false)
    filelog.sys_error("--------------SendMessageRes------------",responsemsg)

    msghelper:send_resmsgto_client(fd, "SendMessageRes", responsemsg)
end


return SendMessage

