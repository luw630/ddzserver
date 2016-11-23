local skynet = require "skynet"
local filelog = require "filelog"
local configdao = require "configdao"
local msgproxy = require "msgproxy"
local timetool = require "timetool"
local helperbase = require "helperbase"
local playerdatadao = require "playerdatadao"
local base = require "base"
local gamelog = require "gamelog"
require "enum"

local trace_rids = nil
local AgentHelper = helperbase:new({}) 

--用于输出指定rid玩家的信息，方便定位问题
function AgentHelper:write_agentinfo_log(...)
	if trace_rids == nil then
		trace_rids = configdao.get_common_conf("rids")
	end

	if trace_rids == nil then
		return
	end

	local rid = self.server.rid
	if (trace_rids.isall ~= nil and trace_rids.isall) or trace_rids[rid] ~= nil then
		filelog.sys_obj("agent", rid, ...)	
	end	
end

--用于copy玩家的基本信息
function AgentHelper:copy_base_info(baseinfo, info, playgame, money)
	baseinfo.rid = info.rid
	-- if info.rolename == "_guest" then
	-- 	info.rolename = "游客"..tostring(info.rid%10000)
	-- end
	baseinfo.rolename = info.rolename
    baseinfo.logo = info.logo
    baseinfo.phone = info.phone
    baseinfo.totalgamenum = playgame.totalgamenum
    baseinfo.winnum = playgame.winnum
    baseinfo.sex = info.sex
	baseinfo.coins = money.coin
	baseinfo.diamonds = money.diamond
	baseinfo.maxcoinnum = money.maxcoinnum
	baseinfo.highwininseries = playgame.highwininseries
end

--判断玩家是否登陆成功
function AgentHelper:is_login_success()
	return  (self.server.state == EGateAgentState.GATE_AGENTSTATE_LOGINED) 
end

--判断玩家是否退出成功
function AgentHelper:is_logout_success()
	return  (self.server.state == EGateAgentState.GATE_AGENTSTATE_LOGOUTED) 
end

function AgentHelper:save_player_gameInfo(rid,key_value_table,reason)
	local playgame = self.server.playgame
	if playgame.rid ~= rid or not key_value_table or type(key_value_table) ~= "table" then return end
	if not key_value_table.totalgamenum or not key_value_table.winnum then return end
	if key_value_table.totalgamenum == 1 and key_value_table.winnum == 0 then
		playgame.totalgamenum = playgame.totalgamenum + key_value_table.totalgamenum
		playgame.wininseriesnum = 0
	elseif key_value_table.totalgamenum == 1 and key_value_table.winnum == 1 then
		playgame.totalgamenum = playgame.totalgamenum + key_value_table.totalgamenum
		playgame.winnum = playgame.winnum + key_value_table.winnum
		playgame.wininseriesnum = playgame.wininseriesnum + key_value_table.winnum
		if playgame.wininseriesnum > playgame.highwininseries then
			playgame.highwininseries = playgame.wininseriesnum
		end
	end
	playerdatadao.save_player_playgame("update",rid,self.server.playgame)
end

function AgentHelper:save_player_coin(rid,number,reason,key)
	local money = self.server.money
	local beforetotal = money.coin
	local aftertotal = 0
	if money.coin + number >= 0 then
		money.coin = money.coin + number
		if money.coin > money.maxcoinnum then money.maxcoinnum = money.coin end
	else
		money.coin = 0
	end
	aftertotal = money.coin
	playerdatadao.save_player_money("update",rid,self.server.money)
	gamelog.write_player_coinlog(rid, reason, ECurrencyType.CURRENCY_TYPE_COIN, number, beforetotal, aftertotal, key)
end

function AgentHelper:save_player_diamond(rid, number, reason)
	local money = self.server.money
	local beforetotal = 0
	local aftertotal = 0
	if money.diamond + number >= 0 then
		money.diamond = money.diamond + number
	else
		money.diamond = 0
	end
	aftertotal = money.diamond
	playerdatadao.save_player_money("update",rid,self.server.money)
	gamelog.write_player_diamondlog(rid, reason, ECurrencyType.CURRENCY_TYPE_DIAMOND, number, beforetotal, aftertotal)
end

function AgentHelper:save_player_awards(rid, awards, reason, key)
	if awards == nil then
		return
	end

	for _, award in ipairs(awards) do
		if award.id == ECurrencyType.CURRENCY_TYPE_COIN then
			self:save_player_coin(rid, award.num, reason, key)
		elseif award.id == ECurrencyType.CURRENCY_TYPE_DIAMOND then
			self:save_player_diamond(rid, award.num, reason)
		else
			--TO ADD 操作道具
		end
	end	
end


function AgentHelper:update_money_to_roomsvrd(rid, update_table)
	if self.server.roomsvr_id == "" or self.server.roomsvr_table_id <= 0 then return end
	if self.server.rid ~= rid or not update_table or #update_table == 0 then return end
	msgproxy.sendrpc_noticemsgto_roomsvrd(nil,self.server.roomsvr_id,self.server.roomsvr_table_id,"update_money",rid,update_table)
end
--- 生成邮件接口
-- @param rid
-- @param mailtable 邮件结构
-- @param reason
--
function AgentHelper:generate_mail(rid,mailtable,reason)
	if not rid or rid <= 0 or type(mailtable) ~= "table" then return end
	mailtable.mail_key = base.generate_uuid()
	mailtable.rid = rid
	mailtable.create_time = timetool.get_time()
	mailtable.reason = reason or ESendMailReasonType.COMMON_TYPE_TESTING
	playerdatadao.save_player_mail("insert",rid,mailtable,nil)
end



return AgentHelper