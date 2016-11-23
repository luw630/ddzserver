--[[
	游戏流水日志模块
	logsvrd
	配置文件：./logsvrd/config_cfgcenter
	------------config_cfgcenter说明--------------
	logrootpath ="../../../logs" ---日志流水根目录
	logscfg = {
		moneylogscfg = {
			logsname = "moneylog", --日志类别
			logspath = logrootpath .. "/moneylog", --日志类别对应的路径
			splitfilesize = 250*4096,--每个日志切分的大小 单位为字节
			begin_id = 100000, --该类日志的起始id，各类之间不能重叠
			num = 3, ---用于写该类日志的服务数量
		},
		....
	}

	----写日志时,向logsvrd发送名为"addlogtologsvr"的notice
	"moneylog" 对应是config_cfgcenter文件中,"moneylog"参数对应为logscfg.moneylogscfg.logsname(可配置),
	data 是日志内容对应的table,logsvrd只支持一级table，如果有多级，只能将子table格式化为json串。
	msgproxy.sendrpc_noticemsgto_logsvrd("addlogtologsvr","moneylog",data)

]]
local msgproxy = require "msgproxy"
local tabletool = require "tabletool"
local json = require "cjson"

json.encode_sparse_array(true,1,1)
local GameLog = {}
----金币日志 key = tableid+roomsvrd_id+time+skynet.self()
---- 充值时key = 订单id  邮件 key = mail_key
-----rid 玩家rid， currencyid 货币ID, num 改变量, beforetotal 改变前数量  aftertotal 改变后数量 
function GameLog.write_player_coinlog(rid, reason, currencyid, num, beforetotal, aftertotal, key)
	local data = {
		rid=rid,
		reason=reason,
		currencyid=currencyid,
		num=num,
		beforetotal=beforetotal,
		aftertotal=aftertotal,
		key = key,
	}
	msgproxy.sendrpc_noticemsgto_logsvrd("addlogtologsvr","coinlog",data)
end


function GameLog.write_player_diamondlog(rid, reason, currencyid, num, beforetotal, aftertotal)
	local data = {
		rid=rid,
		reason=reason,
		currencyid=currencyid,
		num=num,
		beforetotal=beforetotal,
		aftertotal=aftertotal,
	}
	msgproxy.sendrpc_noticemsgto_logsvrd("addlogtologsvr","diamondlog",data)
end

--isreg 1 表示新注册， 0 表示已经注册账号
function GameLog.write_player_loginlog(isreg, uid, rid, regfrom, platform, channel, authtype, version,logintime, ipaddr)
	local data = {
		uid = uid,
		rid = rid,
		regfrom = regfrom,
		platform = platform,
		channel = channel,
		authtype = authtype,
		isreg = isreg,
		version = version,
		logintime = logintime,
		ipaddr = ipaddr,
	}
	msgproxy.sendrpc_noticemsgto_logsvrd("addlogtologsvr","loginlog",data)
end

function GameLog.write_table_records(tableid,room_type,base_coin,base_times,create_user_rid,player_endinfos)
	local data = {
		tableid = tableid,
		room_type = room_type,
		base_coin = base_coin,
		base_times = base_times,
		create_user_rid = create_user_rid,
		player_endinfos = json.encode(player_endinfos),
	}

	msgproxy.sendrpc_noticemsgto_logsvrd("addlogtologsvr","recordlog",data)
end

--[[
记录ios发货请求(state 1表示记录,2表示提交失败,3表示提交成功,4表示签名验证失败)
isbatch 表示是否是补单
]]
function GameLog.write_ios_deliverreqlog(rid, pay_type, good_id, ios_pay_order, option_data, state, isbatch)
	local data = {
		rid = rid,
		pay_type = pay_type,
		good_id = good_id,
		ios_pay_order = ios_pay_order,
		option_data = option_data,
		state = state,
		isbatch = isbatch,
	}
	msgproxy.sendrpc_noticemsgto_logsvrd("addlogtologsvr", "iosdeliverreqlog", data)
end

--[[
充值订单状态流水
]]
function GameLog.write_orderlog(order)
	local data = order
	msgproxy.sendrpc_noticemsgto_logsvrd("addlogtologsvr", "orderlog", data)
end

--- 领取邮件附件流水日志
-- @param rid
--
function GameLog.write_getmailitem_log(rid,gettime, mail_key, create_time, reason, mailcontent)
	local data = {
		rid = rid,
		mail_key = mail_key,
		create_time = create_time,
		reason = reason,
		gettime = gettime,
		mailcontent = mailcontent,
	}
	msgproxy.sendrpc_noticemsgto_logsvrd("addlogtologsvr", "getmailitemlog",data)
end


return GameLog