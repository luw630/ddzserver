local skynet = require "skynet"
local filelog = require "filelog"
local msghelper = require "tablehelper"
local logicmng = require "logicmng"
local timer = require "timer"
local base = require "base"
local tabletool = require "tabletool"
require "enum"

local filename = "tabletimer.lua"

local TableTimer = {}

function TableTimer.process(session, source, event, ...)
	local f = TableTimer[event] 
	if f == nil then
		filelog.sys_error(filename.." TableTimer.process invalid event:"..event)
		return nil
	end
	f(...)	 
end

function TableTimer.doready(timerid, request)
	local server = msghelper:get_server()
	local table_data = server.table_data
	local seat = table_data.seats[request.roomsvr_seat_index]	
	if seat.rid ~= request.rid then
		return
	end
	if timerid ~= seat.ready_timer_id then
		return
	end
	seat.ready_timer_id = -1
	--将玩家站起
	seat.ready_to_time = 0
	local roomtablelogic = logicmng.get_logicbyname("roomtablelogic")
	roomtablelogic.passive_standuptable(table_data, request, seat, EStandupReason.STANDUP_REASON_READYTIMEOUT_STANDUP)	
end

function TableTimer.doaction(timerid, request)
	local server = msghelper:get_server()
	local table_data = server.table_data
	if table_data.timer_id ~= timerid then
		return
	end
	if table_data.timer_id > 0 then
		timer.cleartimer(table_data.timer_id)
	end
	table_data.timer_id = -1
	local seat = table_data.seats[request.roomsvr_seat_index]
	local roomseatlogic = logicmng.get_logicbyname("roomseatlogic")
	if seat ~= nil then
		if seat.is_tuoguan == EBOOL.FALSE then
			seat.timeout_count = seat.timeout_count + 1
			if seat.timeout_count >= table_data.conf.action_timeout_count then
				seat.timeout_count = 0
				roomseatlogic.dealtuoguan(table_data,seat)
			end
		end
	end
	
	if request.action_type == EActionType.ACTION_TYPE_MINGPAI or request.action_type == EActionType.ACTION_TYPE_JIAODIZHU then
		if table_data.action_type == EActionType.ACTION_TYPE_MINGPAI then
			table_data.state = ETableState.TABLE_STATE_PLAYER_JDZ
			local roomgamelogic = msghelper:get_game_logic()
			roomgamelogic.run(table_data.gamelogic)
			return
		elseif table_data.action_type == EActionType.ACTION_TYPE_JIAODIZHU then
			table_data.action_type = EActionType.ACTION_TYPE_BUJIAO_DIZHU
		end
	else
		
		local roomtablelogic = logicmng.get_logicbyname("roomtablelogic")
		if roomtablelogic.is_onegameend(table_data) or seat.rid ~= request.rid or table_data.action_type ~= request.action_type then
			return
		end
		table_data.timer_id = -1
		if table_data.action_type == EActionType.ACTION_TYPE_JIAODIZHU then
			table_data.action_type = EActionType.ACTION_TYPE_BUJIAO_DIZHU
		elseif table_data.action_type ==  EActionType.ACTION_TYPE_QIANGDIZHU then
			table_data.action_type = EActionType.ACTION_TYPE_BUQIANGDIZHU
		elseif table_data.action_type == EActionType.ACTION_TYPE_CHUPAI then
			table_data.action_type = EActionType.ACTION_TYPE_TIMEOUT_CHUPAI
			----出牌超时,选一张牌出
			roomtablelogic.putCards(table_data)
			table_data.action_type = EActionType.ACTION_TYPE_CHUPAI
		elseif table_data.action_type == EActionType.ACTION_TYPE_FOLLOW_CHUPAI then
			----跟牌超时,通知其他玩家，这个玩家不出
			if seat.is_tuoguan == EBOOL.TRUE then
				local status = roomtablelogic.followcards(table_data)
				if status == true then
					table_data.action_type = EActionType.ACTION_TYPE_FOLLOW_CHUPAI
				else
					table_data.action_type = EActionType.ACTION_TYPE_CHECK
				end
			else
				table_data.action_type = EActionType.ACTION_TYPE_CHECK
			end
		end
	end

 
	table_data.state = ETableState.TABLE_STATE_CONTINUE
	local roomgamelogic = msghelper:get_game_logic()
	roomgamelogic.run(table_data.gamelogic)
end

function TableTimer.delete_table(timerid, request)
    local server = msghelper:get_server()    
    local table_data = server.table_data
    if table_data.delete_table_timer_id == timerid then
        table_data.delete_table_timer_id = -1
        msghelper:event_process("lua", "cmd", "delete","timer")
    end 
end

----等待开始定时器时间到,发牌,并设置桌子状态为等待明牌状态TABLE_STATE_WAIT_PLAYER_MINGPAI
function TableTimer.waitstartcountdown(timerid, request)
	local server = msghelper:get_server()
	local table_data = server.table_data

	if table_data.timer_id ~= timerid then
		return
	end
	table_data.timer_id = -1
	local roomtablelogic = logicmng.get_logicbyname("roomtablelogic")
	if roomtablelogic.is_onegameend(table_data) then
		return
	end
	local roomgamelogic = msghelper:get_game_logic()
	roomgamelogic.RiffleandPostCards(table_data)
end
----等待明牌定时器时间到,设置牌桌状态为TABLE_STATE_WAIT_PLAYER_JDZ 叫地主阶段
function TableTimer.waitmingpai(timerid,request)
	local server = msghelper:get_server()
	local table_data = server.table_data

	if table_data.timer_id ~= timerid then
		return
	end
	table_data.timer_id = -1
	local roomtablelogic = logicmng.get_logicbyname("roomtablelogic")
	if roomtablelogic.is_onegameend(table_data) then
		return
	end
	if table_data.state == ETableState.TABLE_STATE_WAIT_CLIENT_ACTION and table_data.action_type == EActionType.ACTION_TYPE_MINGPAI then
		table_data.state = ETableState.TABLE_STATE_PLAYER_JDZ
		table_data.action_type = ETableState.ACTION_TYPE_JIAODIZHU
		local roomgamelogic = msghelper:get_game_logic()
		roomgamelogic.run(table_data.gamelogic)
	end
end

function TableTimer.outtimejdz(timerid, request)
	local server = msghelper:get_server()
	local table_data = server.table_data

	if table_data.timer_id ~= timerid then
		return
	end
	table_data.timer_id = -1
	local roomtablelogic = logicmng.get_logicbyname("roomtablelogic")
	if roomtablelogic.is_onegameend(table_data) then
		return
	end

end
----用于客户端展示牌局游戏结果界面定时器时间到
function TableTimer.onegameend(timerid, request)
	local server = msghelper:get_server()
	local table_data = server.table_data

	if table_data.timer_id ~= timerid then
		return
	end
	table_data.timer_id = -1
	local roomtablelogic = logicmng.get_logicbyname("roomtablelogic")
	--------切换房间状态到开启下一局游戏的状态
	table_data.state = ETableState.TABLE_STATE_ONE_GAME_END_AFTER
	local roomgamelogic = msghelper:get_game_logic()
	roomgamelogic.run(table_data.gamelogic)
end

function TableTimer.onegameendafter(timerid, request)
	local server = msghelper:get_server()
	local table_data = server.table_data
	if table_data.timer_id ~= timerid then
		return
	end
	table_data.timer_id = -1
	local roomtablelogic = logicmng.get_logicbyname("roomtablelogic")
	--------切换房间状态到开启下一局游戏的状态
	table_data.state = ETableState.TABLE_STATE_ONE_GAME_REAL_END
	local roomgamelogic = msghelper:get_game_logic()
	roomgamelogic.run(table_data.gamelogic)
end


return TableTimer