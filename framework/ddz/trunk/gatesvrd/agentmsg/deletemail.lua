local skynet = require "skynet"
local filelog = require "filelog"
local msghelper = require "agenthelper"
local processstate = require "processstate"
local playerdatadao = require "playerdatadao"
require "enum"

local Deletemail = {}
--[[
// 玩家请求删除邮件
message DeleteMailReq {
	optional Version version = 1;
	optional string mail_key = 2;
}

// 响应玩家请求删除邮件
message DeleteMailRes {
	optional int32 errcode = 1; //错误原因 0表示成功
	optional string errcodedes = 2; // 错误描述 
	optional string resultdes = 3; //
}
--]]

function  Deletemail.process(session, source, fd, request)
    local responsemsg = {
        errcode = EErrCode.ERR_SUCCESS,
    }
    local server = msghelper:get_server()
    --检查当前登陆状态
	if not msghelper:is_login_success() then
		filelog.sys_error("Deletemail.process invalid server state", server.state)
		responsemsg.errcode = EErrCode.ERR_INVALID_REQUEST
		responsemsg.errcodedes = "无效的请求!"
		msghelper:send_resmsgto_client(fd, "DeleteMailRes", responsemsg)		
		return
	end

	local status
	local mails
	local condition = " select * from role_mailinfos where mail_key = '" .. request.mail_key .. "'"
	status, mails = playerdatadao.query_player_mail(server.rid,condition)
	if status == true or #mails == 0 then
		responsemsg.errcode = EErrCode.ERR_INVALID_REQUEST
		responsemsg.errcodedes = "无效的邮件!"
		msghelper:send_resmsgto_client(fd, "DeleteMailRes", responsemsg)
		return
	end
	if mails[1].isattach == 1 then
		responsemsg.errcode = EErrCode.ERR_INVALID_REQUEST
		responsemsg.errcodedes = "邮件有附件,请领取后删除!"
		msghelper:send_resmsgto_client(fd, "DeleteMailRes", responsemsg)
		return
	end
	condition = "where mail_key='"..tostring(request.mail_key).."'"
	playerdatadao.save_player_mail("delete",server.rid,nil,condition)
	responsemsg.mail_key = request.mail_key

	msghelper:send_resmsgto_client(fd, "DeleteMailRes", responsemsg)
end

return Deletemail