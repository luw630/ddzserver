local skynet = require "skynet"
local filelog = require "filelog"
local msghelper = require "agenthelper"
local processstate = require "processstate"
local playerdatadao = require "playerdatadao"
local configdao = require "configdao"
local tabletool = require "tabletool"
local timetool = require "timetool"
local tostring = tostring
require "enum"
local Getmails = {}

--[[
//请求玩家的邮件信息
message GetMailsReq {
	optional Version version = 1;
	optional int32 rid = 2;
}

//响应玩家的邮件信息
message GetMailsRes {
	optional int32 errcode = 1; //错误原因 0表示成功
	optional string errcodedes = 2; // 错误描述 
	repeated MailItem mailitems = 3; // 玩家邮件列表
}

{
	"isattach":true,
	"des":"尊敬的玩家，由于我们的比赛配置失误，造成了【星期六京东卡大奖赛】的日期错误。目前该错误已经修复，错误日期的比赛已经下架。
	若您报名参加了该场错误日期的比赛，您的报名费用或门票都将以5000聚众币的形式返还，请注意查收。\\n对您造成的不便，恳请您的谅解。",
	"awards":[{"id":1,"num":5000}]
}
--]]

function  Getmails.process(session, source, fd, request)
    local responsemsg = {
        errcode = EErrCode.ERR_SUCCESS,
    }
    local server = msghelper:get_server()

    --检查当前登陆状态
	if not msghelper:is_login_success() then
		filelog.sys_error("Getmails.process invalid server state", server.state)
		responsemsg.errcode = EErrCode.ERR_INVALID_REQUEST
		responsemsg.errcodedes = "无效的请求!"
		msghelper:send_resmsgto_client(fd, "GetMailsRes", responsemsg)		
		return
	end

	local status
	local mails
	local condition = ""
	local mailconf = configdao.get_business_conf(100, 1000, "mailcfg")
   	local maillimitconf = tabletool.deepcopy(mailconf.maillimitconf)
   	if request.create_time == 0 then
   		local difftime = timetool.get_time() - maillimitconf.limittime
		if maillimitconf.limittime > 0 and difftime > 0 then
			condition = condition .. "select * from role_mailinfos where rid="..tostring(server.rid)..
			" and (isattach = 1 or create_time >=" .. difftime ..")"
		else
			condition = condition .. "select * from role_mailinfos where rid="..tostring(server.rid)..
			" and (isattach = 1 or create_time >= 0)"
		end
   	else
   		condition = condition .. "select * from role_mailinfos where rid="..tostring(server.rid)..
			" and (isattach = 1 or create_time >=" .. request.create_time ..")"
   	end
   	if maillimitconf.limitnum > 0 then
   		condition = condition .. " limit " .. tostring(maillimitconf.limitnum)
	end
	---filelog.sys_error("=============get mails======",condition)
	status, mails = playerdatadao.query_player_mail(server.rid, condition)
	responsemsg.mailitems = {}
	if status == false then
		for key,value in ipairs(mails) do
			local onemail = {}
			onemail.mail_key = value.mail_key
			onemail.rid = value.rid
			onemail.create_time = value.create_time
			onemail.content = value.content
			onemail.isattach = value.isattach
			table.insert(responsemsg.mailitems,onemail)
		end
	end
	if #responsemsg.mailitems > 0 then
		table.sort(responsemsg.mailitems, function(first,second)
											return first.create_time > second.create_time
											end )
	end
    msghelper:send_resmsgto_client(fd, "GetMailsRes", responsemsg)
end


return Getmails
