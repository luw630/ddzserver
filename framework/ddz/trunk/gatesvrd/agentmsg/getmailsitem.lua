local skynet = require "skynet"
local filelog = require "filelog"
local msghelper = require "agenthelper"
local processstate = require "processstate"
local playerdatadao = require "playerdatadao"
local tabletool = require "tabletool"
local timetool = require "timetool"
local tostring = tostring
local gamelog = require "gamelog"
local json = require "cjson"
require "enum"

json.encode_sparse_array(true,1,1)

local Getmailsitem = {}
--[[
//玩家请求领取邮件附件
message GetmailItemsReq {
	optional Version version = 1;
	optional string mail_key = 2;
}
//响应玩家请求领取邮件附件
message GetmailItemsRes {
	optional int32 errcode = 1; //错误原因 0表示成功
	optional string errcodedes = 2; // 错误描述 
	optional string mail_key = 3; //
	optional string resultdes = 4; // 得到物品的json串
}
--]]


function  Getmailsitem.process(session, source, fd, request)
    local responsemsg = {
        errcode = EErrCode.ERR_SUCCESS,
    }
    local server = msghelper:get_server()
    --检查当前登陆状态
	if not msghelper:is_login_success() then
		filelog.sys_error("Getmails.process invalid server state", server.state)
		responsemsg.errcode = EErrCode.ERR_INVALID_REQUEST
		responsemsg.errcodedes = "无效的请求!"
		msghelper:send_resmsgto_client(fd, "GetmailItemsRes", responsemsg)		
		return
	end

	local status
	local mails
	local condition = " select * from role_mailinfos where mail_key = '" .. request.mail_key .. "'"

	status, mails = playerdatadao.query_player_mail(server.rid,condition)

	if status == true or #mails == 0 then
		responsemsg.errcode = EErrCode.ERR_INVALID_REQUEST
		responsemsg.errcodedes = "无效的邮件!"
		msghelper:send_resmsgto_client(fd, "GetmailItemsRes", responsemsg)		
		return
	end
	
	if mails[1].isattach == 1 then
		local mailscontent = json.decode(mails[1].content)
		local items
		local gettime = timetool.get_time()
		gamelog.write_getmailitem_log(server.rid, gettime, mails[1].mail_key, mails[1].create_time, mails[1].reason, mails[1].content)
		if mailscontent.isattach == true then
			 mailscontent.isattach = false
			 mails[1].isattach = 0
		end
		mails[1].content = tabletool.deepcopy(mailscontent)
		responsemsg.mail_key = mails[1].mail_key
		responsemsg.resultdes = ""
		if mailscontent.awards then
			responsemsg.resultdes = responsemsg.resultdes..json.encode(mailscontent.awards)
		end
		if #mailscontent.awards> 0 then
			msghelper:save_player_awards(server.rid,mailscontent.awards,EReasonChangeCurrency.CHANGE_CURRENCY_GETITEM_FROM_MAIL,mails[1].mail_key)
		end
		mailscontent.awards = {}
		condition = "where mail_key = '" .. request.mail_key .. "'"
		playerdatadao.save_player_mail("delete",server.rid, nil,condition)
		msghelper:send_resmsgto_client(fd, "GetmailItemsRes", responsemsg)
		local responsemsg = {
			baseinfo = {},
		}
		msghelper:copy_base_info(responsemsg.baseinfo, server.info, server.playgame, server.money)
		msghelper:send_noticemsgto_client(nil,"PlayerBaseInfoNtc",responsemsg)
		return 
	end

    msghelper:send_resmsgto_client(fd, "GetmailItemsRes", responsemsg)
end

return Getmailsitem




