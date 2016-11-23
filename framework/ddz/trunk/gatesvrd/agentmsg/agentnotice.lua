local filelog = require "filelog"
local msghelper = require "agenthelper"
local base = require "base"
local playerdatadao = require "playerdatadao"
local gamelog = require "gamelog"
require "enum"

local AgentNotice = {}

function AgentNotice.process(session, source, event, ...)
	local f = AgentNotice[event] 
	if f == nil then
		f = AgentNotice["other"]
		f(event, ...)
		return
	end
	f(...)
end

function AgentNotice.leavetable(noticemsg)
	if not msghelper:is_login_success() then
		return
	end

	local server = msghelper:get_server()
	if server.rid ~= noticemsg.rid then
		return
	end

	if server.roomsvr_id ~= noticemsg.roomsvr_id then
		return
	end

	if server.roomsvr_table_id ~= noticemsg.roomsvr_table_id then
		return
	end

	if server.roomsvr_table_address ~= noticemsg.roomsvr_table_address then
		return
	end

	server.roomsvr_id = ""
	server.roomsvr_table_id = 0
	server.roomsvr_table_address = -1
	server.roomsvr_seat_index = 0
	server.online.roomsvr_id = ""
	server.online.roomsvr_table_id = 0
    server.online.roomsvr_table_address = -1
	playerdatadao.save_player_online("update", server.rid, server.online)

	if noticemsg.is_sendto_client then
		msghelper:send_resmsgto_client(nil, "LeaveTableRes", {errcode = EErrCode.ERR_SUCCESS})		
	end
end

function AgentNotice.standuptable(noticemsg)
	local server = msghelper:get_server()
	if server.rid ~= noticemsg.rid then
		return
	end

	if server.roomsvr_id ~= noticemsg.roomsvr_id then
		return
	end

	if server.roomsvr_table_id ~= noticemsg.roomsvr_table_id then
		return
	end

	if server.roomsvr_seat_index ~= noticemsg.roomsvr_seat_index then
		return
	end
	server.roomsvr_seat_index = 0
end

function AgentNotice.other(msgname, noticemsg)
	msghelper:send_noticemsgto_client(nil, msgname, noticemsg)
end

function AgentNotice.updateplayerinfo(rid,update_key_value,reason,key,is_sendto_client)
	local server = msghelper:get_server()
	if server.rid ~= rid or not update_key_value or type(update_key_value) ~= "table" then
		return 
    end
    for k,value in pairs(update_key_value) do
        if k == "money" then
            if type(value) == "table" then
                if value.coin and value.coin ~= 0 then
                    msghelper:save_player_coin(rid,value.coin,reason,key)
                end
                if value.diamond and value.diamond ~= 0 then
                    msghelper:save_player_diamond(rid, value.diamond, reason, key)
                end
            end
        elseif k == "playgame" then
            if type(value) == "table" then
                msghelper:save_player_gameInfo(rid, value, reason)
            end
        end
    end

    if is_sendto_client == 1 then
        local responsemsg = {
            baseinfo = {},
        }
        msghelper:copy_base_info(responsemsg.baseinfo, server.info, server.playgame, server.money)
        msghelper:send_noticemsgto_client(nil,"PlayerBaseInfoNtc",responsemsg)
    end
end

--商城通知发货
function AgentNotice.delivergoods(noticemsg)
	local server = msghelper:get_server()
	if server.rid ~= noticemsg.rid then
		return
	end

	if not msghelper:is_login_success() then
		return
	end

	local order = playerdatadao.query_player_order(noticemsg.rid, noticemsg.order_id)
	if order == nil then
		return
	end

	if not msghelper:is_login_success() then		
		return
	end

	if order.state ~= 2 then
		return
	end
	local beforecoin = server.money.coin
	local beforediamond = server.money.diamond
	msghelper:save_player_awards(noticemsg.rid, noticemsg.awards, EReasonChangeCurrency.CHANGE_CURRENCY_RECHARGE,noticemsg.order_id)
	order.state = 3
	--记录发货成功
	gamelog.write_orderlog(order)

	--修改mysql订单状态
	playerdatadao.save_player_order("update", order.rid, order, {rid = order.rid, order_id = order.order_id})

	--通知client金币、宝石、道具发生变化
	--TO ADD

	--如果玩家在桌内游戏，将玩家改变的金币或宝石同步到游戏服
	if server.roomsvr_id ~= "" and server.roomsvr_table_id > 0 then
		local aftercoin = server.money.coin
		local afterdiamond = server.money.diamond
		local update_table = {}
		if aftercoin > beforecoin then
			table.insert(update_table,{id = ECurrencyType.CURRENCY_TYPE_COIN, num = aftercoin - beforecoin})
		end
		if afterdiamond > beforediamond then
			table.insert(update_table,{id = ECurrencyType.CURRENCY_TYPE_DIAMOND, num = afterdiamond - beforediamond})
		end
		if #update_table > 0 then
			msghelper:update_money_to_roomsvrd(server.rid,update_table)
		end
	end
	--通知client 发货
	noticemsg.rid = nil
	msghelper:send_noticemsgto_client(nil, "DeliverGoodNtc", noticemsg)
end

return AgentNotice