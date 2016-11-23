local base = require "base"
local msghelper = require "tablehelper"
local timetool = require "timetool"
local timer = require "timer"
local filelog = require "filelog"
local logicmng = require "logicmng"
local ddzgamelogic = require "ddzgamelogic"
local gamelog = require "gamelog"
require "enum"
local RoomGameLogic = {}
--[[
----桌子的状态
ETableState = {
	TABLE_STATE_UNKNOW = 0,
	TABLE_STATE_WAIT_ALL_READY = 1,			--等待所有玩家准备
	TABLE_STATE_WAIT_START_COUNT_DOWN = 2,  --等待开始倒计时
	TABLE_STATE_WAIT_PLAYER_MINGPAI = 3,    --等待明牌
	TABLE_STATE_WAIT_PLAYER_JDZ = 4,        --等待叫地主
	TABLE_STATE_WAIT_PLAYER_CHUPAI = 5,     --等待出牌
	TABLE_STATE_WAIT_ONE_GAME_REAL_END = 6, --等待一局游戏真正结束
	TABLE_STATE_WAIT_GAME_END = 7,     --等待游戏结束
	TABLE_STATE_GAME_START = 8,        --游戏开始状态
	TABLE_STATE_ONE_GAME_START = 9,    --一局游戏开始
	TABLE_STATE_CONTINUE = 10,
	TABLE_STATE_CONTINUE_AND_STANDUP = 11,
	TABLE_STATE_CONTINUE_AND_LEAVE = 12,
	TABLE_STATE_ONE_GAME_END = 13,      --一局游戏结束
	TABLE_STATE_ONE_GAME_REAL_END = 14, --一局游戏真正结束
	TABLE_STATE_GAME_END = 15,  	    --游戏结束
	TABLE_STATE_WAIT_COUNT_DOWN = 16,   --开始倒计时
	TABLE_STATE_WAIT_CLIENT_ACTION = 17, --等待客户端操作
}
]]
function RoomGameLogic.init(gameobj, tableobj)
	gameobj.tableobj = tableobj
	gameobj.stateevent[ETableState.TABLE_STATE_GAME_START] = RoomGameLogic.gamestart
	gameobj.stateevent[ETableState.TABLE_STATE_ONE_GAME_START] = RoomGameLogic.onegamestart
	gameobj.stateevent[ETableState.TABLE_STATE_WAIT_START_COUNT_DOWN] = RoomGameLogic.waitstartcountdown
	gameobj.stateevent[ETableState.TABLE_STATE_WAIT_PLAYER_MINGPAI] = RoomGameLogic.waitmingpai
	gameobj.stateevent[ETableState.TABLE_STATE_PLAYER_JDZ] = RoomGameLogic.playerjdz
	gameobj.stateevent[ETableState.TABLE_STATE_WAIT_PLAYER_CHUPAI] = RoomGameLogic.chupai
	gameobj.stateevent[ETableState.TABLE_STATE_ONE_GAME_END] = RoomGameLogic.onegameend
	gameobj.stateevent[ETableState.TABLE_STATE_ONE_GAME_END_AFTER] = RoomGameLogic.onegameendafter
	gameobj.stateevent[ETableState.TABLE_STATE_ONE_GAME_REAL_END] = RoomGameLogic.onegamerealend
	gameobj.stateevent[ETableState.TABLE_STATE_GAME_END] = RoomGameLogic.gameend
	gameobj.stateevent[ETableState.TABLE_STATE_CONTINUE] = RoomGameLogic.continue
	return true
end

function RoomGameLogic.run(gameobj)
	local f = nil
	local loopcount = 10
	while true do
		if gameobj.tableobj.state == ETableState.TABLE_STATE_WAIT_ALL_READY then
			break
		end

		f = gameobj.stateevent[gameobj.tableobj.state]
		if f == nil then
			break
		end
		loopcount = loopcount - 1
		if loopcount <= 0 then
			gamelog.sys_error("-------roomgamelogic out of looptimes-----",loopcount)
			break
		end
		f(gameobj)
	end
end

function RoomGameLogic.gamestart(gameobj)
	local tableobj = gameobj.tableobj
	tableobj.state = ETableState.TABLE_STATE_WAIT_PLAYER_SITDOWN
	----设置一些连续牌桌游戏的变量
end

function RoomGameLogic.onegamestart(gameobj)
	local tableobj = gameobj.tableobj
	RoomGameLogic.onegamestart_inittable(gameobj)
	tableobj.state = ETableState.TABLE_STATE_WAIT_START_COUNT_DOWN
end

----桌子进入开始倒计时阶段
function RoomGameLogic.waitstartcountdown(gameobj)
	local tableobj = gameobj.tableobj
	local startcountdownmsg = {

	}
	if tableobj.timer_id >0 then
		timer.cleartimer(tableobj.timer_id)
		tableobj.timer_id = -1
	end
	-----启动开始倒计时定时器，在定时器超时函数中处理发牌逻辑
	tableobj.timer_id = timer.settimer(3*100, "waitstartcountdown", startcountdownmsg)

	tableobj.state = ETableState.TABLE_STATE_WAIT_COUNT_DOWN
end

----发完牌后开启定时器等待玩家明牌
function RoomGameLogic.waitmingpai(gameobj)
	local tableobj = gameobj.tableobj


	local mingpaimsg = {
		action_type = EActionType.ACTION_TYPE_MINGPAI
	}
	if tableobj.timer_id >0 then
		timer.cleartimer(tableobj.timer_id)
		tableobj.timer_id = -1
	end
	-----启动开始倒计时定时器
	tableobj.timer_id = timer.settimer(2*100, "doaction", mingpaimsg)

	tableobj.state = ETableState.TABLE_STATE_WAIT_CLIENT_ACTION
end

----明牌阶段后进入叫地主阶段
function RoomGameLogic.playerjdz(gameobj)
	local tableobj = gameobj.tableobj
	local seatIndex = base.get_random(1,#tableobj.seats)
	local action_seat_index = seatIndex
	tableobj.action_type = EActionType.ACTION_TYPE_JIAODIZHU
	tableobj.action_seat_index = seatIndex
	tableobj.jzdbegin_index = seatIndex
	tableobj.action_to_time = timetool.get_time() + tableobj.conf.action_timeout

	--下发当前玩家操作协议
	local doactionntcmsg = {
		rid = tableobj.seats[action_seat_index].rid,
		roomsvr_seat_index = action_seat_index,
		action_to_time = tableobj.action_to_time,
		action_type = EActionType.ACTION_TYPE_JIAODIZHU
	}
	----通知所有玩家 seatIndex上的玩家在叫地主了
	msghelper:sendmsg_to_alltableplayer("DoactionNtc", doactionntcmsg)

	if tableobj.timer_id >0 then
		timer.cleartimer(tableobj.timer_id)
		tableobj.timer_id = -1
	end

	local jdzouttimemsg = {
		action_type = EActionType.ACTION_TYPE_JIAODIZHU,
		roomsvr_seat_index = action_seat_index,
	}
	if tableobj.seats[tableobj.action_seat_index].is_tuoguan == EBOOL.TRUE then
		tableobj.timer_id = timer.settimer(tableobj.conf.tuoguan_action_time*100, "doaction", doactionntcmsg)
	else
		tableobj.timer_id = timer.settimer(tableobj.conf.action_timeout*100, "doaction", doactionntcmsg)
	end
	----切换桌子状态
	tableobj.state = ETableState.TABLE_STATE_WAIT_PLAYER_JDZ
end

-----玩家出牌游戏开始
function RoomGameLogic.chupai(gameobj)
	local tableobj = gameobj.tableobj
	if tableobj.timer_id > 0 then
		timer.cleartimer(tableobj.timer_id)
		tableobj.timer_id = -1
	end
	----设置seat是否是地主的标识
	for k,v in ipairs(tableobj.seats) do
		if v.index == tableobj.dz_seat_index then
			v.isdz = EBOOL.TRUE
		end
	end
	------通知玩家出牌之前,通知玩家底牌
	local DealCardsEndmsg = {
		rid = tableobj.seats[tableobj.dz_seat_index].rid,
		cards = {},
	}
	for k,v in ipairs(tableobj.initCards) do
		table.insert(DealCardsEndmsg.cards,v)
		table.insert(tableobj.seats[tableobj.dz_seat_index].cards, v) ---将剩余的三张底牌加入地主的手牌中
	end
	tableobj.ddzgame.SortCards(tableobj.seats[tableobj.dz_seat_index].cards)
	msghelper:sendmsg_to_alltableplayer("DealCardsEndNtc", DealCardsEndmsg)

	local roomtablelogic = logicmng.get_logicbyname("roomtablelogic")
	roomtablelogic.setallseatstate(tableobj,ESeatState.SEAT_STATE_WAIT_NOTICE)
	roomtablelogic.sendGameStart(tableobj)
	local action_seat_index = tableobj.action_seat_index
	if tableobj.action_type ~= EActionType.ACTION_TYPE_CHUPAI then
		tableobj.action_type = EActionType.ACTION_TYPE_CHUPAI
	end
	tableobj.action_to_time = timetool.get_time() + tableobj.conf.action_timeout
	--下发当前玩家操作协议
	local doactionntcmsg = {
		rid = tableobj.seats[action_seat_index].rid,
		roomsvr_seat_index = action_seat_index,
		action_to_time = tableobj.action_to_time,
		action_type = tableobj.action_type
	}
	----通知所有玩家 seatIndex上的玩家在出牌了
	msghelper:sendmsg_to_alltableplayer("DoactionNtc", doactionntcmsg)
	if tableobj.seats[tableobj.action_seat_index].is_tuoguan == EBOOL.TRUE then
		tableobj.timer_id = timer.settimer(tableobj.conf.tuoguan_action_time*100, "doaction", doactionntcmsg)
	else
		tableobj.timer_id = timer.settimer(tableobj.conf.action_timeout*100, "doaction", doactionntcmsg)
	end
	tableobj.state = ETableState.TABLE_STATE_WAIT_CLIENT_ACTION
end
local function jzdwithqdzdealfun(tableobj,seat,next_action_index,next_action_index_next)
	local roomtablelogic = logicmng.get_logicbyname("roomtablelogic")
	local roomseatlogic = logicmng.get_logicbyname("roomseatlogic")
	if tableobj.action_type == EActionType.ACTION_TYPE_JIAODIZHU then
		seat.jdztag = 1 ----表示当前玩家已经叫过地主了
		tableobj.noputsCardsNum = 0
		if tableobj.jzdbegin_index == next_action_index and tableobj.seats[tableobj.action_seat_index].jdztag == 1 and
				tableobj.seats[next_action_index].jdztag < 0 and tableobj.seats[next_action_index_next].jdztag < 0 then
			----确定地主
			seat.jdztag = 1 ----表示当前玩家已经叫过地主了
			roomtablelogic.setdizhu(tableobj,tableobj.action_seat_index)
			return true
		else
			-----通知下一家抢地主
			tableobj.action_type = EActionType.ACTION_TYPE_QIANGDIZHU
			tableobj.action_seat_index = next_action_index
		end
	elseif tableobj.action_type == EActionType.ACTION_TYPE_TIMEOUT_JDZ or tableobj.action_type == EActionType.ACTION_TYPE_BUJIAO_DIZHU then
		----玩家不叫地主或叫地主超时
		seat.jdztag = -1  ----表示当前玩家已经叫过地主了
		tableobj.noputsCardsNum = tableobj.noputsCardsNum + 1
		---尾家不叫地主
		if tableobj.jzdbegin_index == next_action_index and tableobj.seats[tableobj.action_seat_index].jdztag < 0 and
				((tableobj.seats[next_action_index].jdztag == 1 and tableobj.seats[next_action_index_next].jdztag < 0) or
						(tableobj.seats[next_action_index].jdztag < 0 and tableobj.seats[next_action_index_next].jdztag == 1)) then
			---设置地主
			local seatindex = tableobj.action_seat_index
			if tableobj.seats[next_action_index].jdztag == 1 and tableobj.seats[next_action_index_next] < 0 then
				seatindex = next_action_index
			elseif tableobj.seats[next_action_index].jdztag < 0 and tableobj.seats[next_action_index_next] == 1 then
				seatindex = next_action_index_next
			end
			roomtablelogic.setdizhu(tableobj,seatindex)
			return true
		else
			-----通知下一家叫地主
			tableobj.action_type = EActionType.ACTION_TYPE_JIAODIZHU
			tableobj.action_seat_index = next_action_index
		end
	elseif tableobj.action_type == 	EActionType.ACTION_TYPE_TIMEOUT_QIANGDIZHU or tableobj.action_type == EActionType.ACTION_TYPE_BUQIANGDIZHU then
		----玩家不抢地主或抢地主超时
		seat.jdztag = -2
		if tableobj.seats[next_action_index].jdztag == 2 then
			---确定地主
			local actionindex = next_action_index
			if tableobj.seats[next_action_index_next].jdztag == 2 then
				actionindex = next_action_index_next
			end
			roomtablelogic.setdizhu(tableobj,actionindex)
			return true
		elseif tableobj.seats[next_action_index].jdztag == 1 then
			---通知下一家玩家抢地主
			if tableobj.seats[next_action_index_next].jdztag < 0 then
				roomtablelogic.setdizhu(tableobj,next_action_index)
				return true
			else
				tableobj.action_seat_index = next_action_index
				tableobj.action_type = EActionType.ACTION_TYPE_QIANGDIZHU
			end
		elseif tableobj.seats[next_action_index].jdztag < 0 then
			if tableobj.seats[next_action_index_next].jdztag == 2 or tableobj.seats[next_action_index_next].jdztag == 1 then
				---确定地主
				roomtablelogic.setdizhu(tableobj,next_action_index_next)
				return true
			end
		else
			tableobj.action_seat_index = next_action_index
			tableobj.action_type = EActionType.ACTION_TYPE_QIANGDIZHU
		end
	elseif tableobj.action_type == EActionType.ACTION_TYPE_QIANGDIZHU then
		seat.jdztag = 2 ----表示当前玩家已经抢过地主了
		tableobj.noputsCardsNum = 0
		tableobj.baseTimes = tableobj.baseTimes * 2
		roomtablelogic.sendHandsInfo(tableobj)
		---判断下一家是否抢过,如果抢过则,强地主规则结束
		if tableobj.seats[next_action_index].jdztag == 2 then
			---确定地主
			roomtablelogic.setdizhu(tableobj,tableobj.action_seat_index)
			return true
		elseif tableobj.seats[next_action_index].jdztag == 1 then
			---通知下一家玩家抢地主
			tableobj.action_seat_index = next_action_index
			tableobj.action_type = EActionType.ACTION_TYPE_QIANGDIZHU
		elseif tableobj.seats[next_action_index].jdztag < 0 then
			if tableobj.seats[next_action_index_next].jdztag == 2 then
				---确定地主
				roomtablelogic.setdizhu(tableobj,tableobj.action_seat_index)
				return true
			elseif tableobj.seats[next_action_index_next].jdztag == 1 then
				tableobj.action_seat_index = next_action_index_next
				tableobj.action_type = EActionType.ACTION_TYPE_QIANGDIZHU
			end
		else
			tableobj.action_seat_index = next_action_index
			tableobj.action_type = EActionType.ACTION_TYPE_QIANGDIZHU
		end
	end
	if tableobj.noputsCardsNum >= 3 then
		----玩家都不叫地主，重新发牌
		roomtablelogic.noonejdz(tableobj)
		return true
	end
	return false
end

local function jdz_base123_func(tableobj,seat,next_action_index,next_action_index_next)
	local roomtablelogic = logicmng.get_logicbyname("roomtablelogic")
	local roomseatlogic = logicmng.get_logicbyname("roomseatlogic")
	if tableobj.action_type == EActionType.ACTION_TYPE_JIAODIZHU then
		if seat.jdz_score ~= 0 then
			tableobj.baseTimes = tableobj.conf.common_times * seat.jdz_score
		end
		roomtablelogic.sendHandsInfo(tableobj)
		if seat.jdz_score < 3 then
			if tableobj.jzdbegin_index == next_action_index then
				local calltime = 0
				local dz_index = 0
				for k,value in ipairs(tableobj.seats) do
					if value.jdz_score > calltime then
						calltime = value.jdz_score
						dz_index = value.index
					end
				end
				if dz_index ~= 0 then
					roomtablelogic.setdizhu(tableobj,dz_index)
					return true
				end
			end
			tableobj.action_seat_index = next_action_index
			tableobj.action_type = EActionType.ACTION_TYPE_JIAODIZHU
		elseif seat.jdz_score >= 3 then
			---确定地主
			roomtablelogic.setdizhu(tableobj,tableobj.action_seat_index)
			return true
		end
	elseif tableobj.action_type == EActionType.ACTION_TYPE_TIMEOUT_JDZ or tableobj.action_type == EActionType.ACTION_TYPE_BUJIAO_DIZHU then
		tableobj.noputsCardsNum = tableobj.noputsCardsNum + 1
		if tableobj.noputsCardsNum >= 3 then
			----玩家都不叫地主，重新发牌
			roomtablelogic.noonejdz(tableobj)
			return true
		end
		if tableobj.jzdbegin_index == next_action_index then
			local flag = false
			local calltime = 0
			local dz_index = 0
			for k,value in ipairs(tableobj.seats) do
				if value.jdz_score > calltime then
					calltime = value.jdz_score
					dz_index = value.index
				end
			end
			if dz_index ~= 0 then
				roomtablelogic.setdizhu(tableobj,dz_index)
				return true
			end
		end
		tableobj.action_seat_index = next_action_index
		tableobj.action_type = EActionType.ACTION_TYPE_JIAODIZHU
	end
	return false
end

function RoomGameLogic.continue(gameobj)
	local tableobj = gameobj.tableobj
	if tableobj.timer_id >= 0 then
		timer.cleartimer(tableobj.timer_id)
		tableobj.timer_id = -1
	end
	local roomtablelogic = logicmng.get_logicbyname("roomtablelogic")
	local roomseatlogic = logicmng.get_logicbyname("roomseatlogic")
	local seat = tableobj.seats[tableobj.action_seat_index]

	local noticemsg = {
		rid = seat.rid,
		roomsvr_seat_index = tableobj.action_seat_index,
		action_type = tableobj.action_type,
		cards = {},
		call_times = seat.jdz_score,
	}
	---如果table上的状态是等待玩家出牌
	if tableobj.action_type == EActionType.ACTION_TYPE_CHUPAI or tableobj.action_type == EActionType.ACTION_TYPE_FOLLOW_CHUPAI or
		tableobj.action_type == EActionType.ACTION_TYPE_CHECK then
		if tableobj.action_type ~= EActionType.ACTION_TYPE_CHECK and #tableobj.CardsHeaps > 0 then
			if tableobj.action_type == EActionType.ACTION_TYPE_FOLLOW_CHUPAI and (tableobj.ischuntian == 10 or tableobj.ischuntian == 11
					or tableobj.ischuntian == 20 or tableobj.ischuntian == 21) then
				local isdz = tableobj.seats[tableobj.action_seat_index].isdz
				if isdz ~= math.floor(tableobj.ischuntian%10) then
					tableobj.ischuntian = 0
				end
			end
			local roundheaps = tableobj.CardsHeaps[#tableobj.CardsHeaps]
			for k,v in ipairs(roundheaps[#roundheaps].cardHelper) do
				table.insert(noticemsg.cards,v)
			end
			----通知服务器当前牌桌的倍数,玩家的手牌数
			roomtablelogic.sendHandsInfo(tableobj)
		end
		tableobj.state = ETableState.TABLE_STATE_ONE_GAME_START
	end

	roomseatlogic.setSeatstate(tableobj)
	-- TO ADD操作类型

	msghelper:sendmsg_to_alltableplayer("DoactionResultNtc", noticemsg)

	local is_end_game = false
	if tableobj.action_type == EActionType.ACTION_TYPE_CHUPAI or tableobj.action_type == EActionType.ACTION_TYPE_FOLLOW_CHUPAI then
		for k,v in ipairs(tableobj.seats) do
			if #v.cards	== 0 then is_end_game = true break end
		end
	end
	--判断是否结束游戏
	if is_end_game then
		tableobj.state = ETableState.TABLE_STATE_ONE_GAME_END
		local roomgamelogic = msghelper:get_game_logic()
		roomgamelogic.run(tableobj.gamelogic)
		return
	end
	local next_action_index = 0
	local next_action_index_next = 0
	if tableobj.action_seat_index == 1 then
		next_action_index = 2
		next_action_index_next = 3
	elseif tableobj.action_seat_index == 2 then
		next_action_index = 3
		next_action_index_next = 1
	elseif	tableobj.action_seat_index == 3 then
		next_action_index = 1
		next_action_index_next = 2
	end
	if tableobj.action_type == EActionType.ACTION_TYPE_CHUPAI then
		if tableobj.seats[tableobj.action_seat_index].handsround == 0 then
			if tableobj.seats[tableobj.dz_seat_index].handsround <= 1 then
				local chuflag = ""
				if tableobj.seats[tableobj.action_seat_index].isdz == EBOOL.FALSE then
					chuflag = chuflag .. "2"
				elseif tableobj.seats[tableobj.action_seat_index].isdz == EBOOL.TRUE then
					chuflag = chuflag .. "1"
				end
				local is = chuflag ..tostring(tableobj.seats[tableobj.action_seat_index].isdz)
				tableobj.ischuntian = tonumber(is)
			end
		end
		tableobj.seats[tableobj.action_seat_index].handsround = tableobj.seats[tableobj.action_seat_index].handsround + 1
	end
	
	----如果是在叫地主或者是抢地主过程中的各种操作,则需要把房间状态设置为等待玩家叫地主状态
	if roomtablelogic.isQiangdz(tableobj) then
		tableobj.state = ETableState.TABLE_STATE_WAIT_PLAYER_JDZ
	end
	if tableobj.state == ETableState.TABLE_STATE_WAIT_PLAYER_JDZ then
		local status = jdz_base123_func(tableobj,seat,next_action_index,next_action_index_next)
		if status == true then return end
	elseif tableobj.state == ETableState.TABLE_STATE_ONE_GAME_START then
		---通知下一位玩家跟牌
		if tableobj.action_type == EActionType.ACTION_TYPE_CHUPAI then
			tableobj.noputsCardsNum = 0
			tableobj.action_type = EActionType.ACTION_TYPE_FOLLOW_CHUPAI
		elseif tableobj.action_type == EActionType.ACTION_TYPE_CHECK or tableobj.action_type == EActionType.ACTION_TYPE_TIMEOUT_FOLLOW_CHUPAI then
			tableobj.noputsCardsNum =  tableobj.noputsCardsNum + 1
			if tableobj.noputsCardsNum == 2 then
				tableobj.action_type = EActionType.ACTION_TYPE_CHUPAI
			else
				tableobj.action_type = EActionType.ACTION_TYPE_FOLLOW_CHUPAI
			end
		elseif tableobj.action_type == EActionType.	ACTION_TYPE_FOLLOW_CHUPAI then
			tableobj.noputsCardsNum = 0
		end
		tableobj.action_seat_index = next_action_index
	end

	--通知下一个玩家操作下发当前玩家操作协议
	tableobj.action_to_time = timetool.get_time() + tableobj.conf.action_timeout
	local doactionntcmsg = {
		rid = tableobj.seats[tableobj.action_seat_index].rid,
		roomsvr_seat_index = tableobj.action_seat_index,
		action_type = tableobj.action_type,
		action_to_time = tableobj.action_to_time,
	}
	
	msghelper:sendmsg_to_alltableplayer("DoactionNtc", doactionntcmsg)
	if tableobj.seats[tableobj.action_seat_index].is_tuoguan == EBOOL.TRUE then
		tableobj.timer_id = timer.settimer(tableobj.conf.tuoguan_action_time*100, "doaction", doactionntcmsg)
	else
		tableobj.timer_id = timer.settimer(tableobj.conf.action_timeout*100, "doaction", doactionntcmsg)
	end

	tableobj.state = ETableState.TABLE_STATE_WAIT_CLIENT_ACTION
end

function RoomGameLogic.onegameend(gameobj)
	-- body
	local tableobj = gameobj.tableobj

	if tableobj.timer_id >0 then
		timer.cleartimer(tableobj.timer_id)
		tableobj.timer_id = -1
	end
	local roomtablelogic = logicmng.get_logicbyname("roomtablelogic")
	---获取最后一手手牌
	local roundheaps = tableobj.CardsHeaps[#tableobj.CardsHeaps]
	if not roundheaps or #roundheaps <= 0 then return end
	local playercardhelper = roundheaps[#roundheaps].cardHelper
	local delayTime = EDelayTimeCardType.COMMON_CARDTYPE
	for k,v in pairs(ECardType) do
		if playercardhelper.m_eCardType == v then
			if 	EDelayTimeCardType[k] then
				delayTime = EDelayTimeCardType[k]
				break
			end
		end
	end
	local gameendmsg = {

	}
	---设置定时器，用于客户端展示牌局游戏结果界面
	tableobj.timer_id = timer.settimer(delayTime, "onegameend", gameendmsg)
	tableobj.state = ETableState.TABLE_STATE_WAIT_ONE_GAME_REAL_END
end

function RoomGameLogic.onegameendafter(gameobj)
	local tableobj = gameobj.tableobj
	if tableobj.timer_id >0 then
		timer.cleartimer(tableobj.timer_id)
		tableobj.timer_id = -1
	end
	local roomtablelogic = logicmng.get_logicbyname("roomtablelogic")
	----通知玩家游戏结束了
	if tableobj.action_type == EActionType.ACTION_TYPE_CHUPAI or tableobj.action_type == EActionType.ACTION_TYPE_FOLLOW_CHUPAI then
		local dizhuiswin = 0
		----判断最后一手是地主还是农民
		if tableobj.seats[tableobj.action_seat_index].isdz == EBOOL.FALSE then
			dizhuiswin = 0
		else
			dizhuiswin = 1
		end
		for k,v in ipairs(tableobj.seats) do
			if v.isdz == EBOOL.FALSE then
				v.win = ( dizhuiswin==1 ) and 0 or 1
			else
				v.win = ( dizhuiswin==1 ) and 1 or 0
			end
		end
		---判断是否是春天
		if tableobj.ischuntian == 10 or tableobj.ischuntian == 11 then
			tableobj.baseTimes = tableobj.baseTimes * 2
			roomtablelogic.sendHandsInfo(tableobj)
		end
		----结果结算逻辑处理部分
		roomtablelogic.balancegame(tableobj)
		local GameEndResultNtcmsg = {
			basecoins = tableobj.conf.base_coin,
			times = tableobj.baseTimes,
			playerinfos = nil,
			ischuntian = math.floor(tableobj.ischuntian/10),
		}
		GameEndResultNtcmsg.playerinfos = {}
		msghelper:copy_playerinfoingameend(GameEndResultNtcmsg.playerinfos)
		msghelper:sendmsg_to_alltableplayer("GameEndResultNtc", GameEndResultNtcmsg)
		gamelog.write_table_records(tableobj.conf.id,tableobj.conf.room_type,tableobj.conf.base_coin,tableobj.baseTimes,
			tableobj.conf.create_user_rid,GameEndResultNtcmsg.playerinfos)
	end
	local gameendmsg = {

	}
	---设置定时器，用于客户端展示牌局游戏结果界面
	if tableobj.ischuntian == 10 or tableobj.ischuntian == 11 or tableobj.ischuntian == 20 or tableobj.ischuntian == 21 then
		tableobj.timer_id = timer.settimer(EDelayTimeCardType.COMMON_CHUNTIAN, "onegameendafter", gameendmsg)
	else
		tableobj.timer_id = timer.settimer(EDelayTimeCardType.COMMON_CARDTYPE, "onegameendafter", gameendmsg)
	end
	---切换桌子状态为等待定时器结束
	local roomseatlogic = logicmng.get_logicbyname("roomseatlogic")
	for k,value in ipairs(tableobj.seats) do
		roomseatlogic.resetstate(value)
	end

	tableobj.state = ETableState.TABLE_STATE_WAIT_ONE_GAME_REAL_END

end

function RoomGameLogic.onegamerealend(gameobj)
	-- body
	local tableobj = gameobj.tableobj

	if tableobj.timer_id >0 then
		timer.cleartimer(tableobj.timer_id)
		tableobj.timer_id = -1
	end
	local roomtablelogic = logicmng.get_logicbyname("roomtablelogic")
	roomtablelogic.check_player_coin(tableobj)

	local noticeDoReadymsg = {
		rid = 0,
		roomsvr_seat_index = 0,
		ready_to_time = 0,
	}
	for k,v in ipairs(tableobj.seats) do
		if v.rid ~= 0 and v.state == ESeatState.SEAT_STATE_WAIT_READY then
			noticeDoReadymsg.rid =  v.rid
			noticeDoReadymsg.roomsvr_seat_index = v.index
			noticeDoReadymsg.ready_to_time = timetool.get_time() + tableobj.conf.ready_timeout
			v.ready_to_time = timetool.get_time() + tableobj.conf.ready_timeout
			msghelper:sendmsg_to_alltableplayer("DoReadyNtc",noticeDoReadymsg)
			if v.ready_timer_id > 0 then
				timer.cleartimer(v.ready_timer_id)
				v.ready_timer_id = -1
			end
			local outoftimermsg = {
				rid = v.rid,
				roomsvr_seat_index = v.index,
			}
			----每个玩家增加准备倒计时定时器
			v.ready_timer_id = timer.settimer(tableobj.conf.ready_timeout*100, "doready", outoftimermsg)
		end
	end
	local roomtablelogic = logicmng.get_logicbyname("roomtablelogic")
	----重置桌子状态为等待玩家准备开始游戏的状态
	roomtablelogic.resetTable(tableobj)

	RoomGameLogic.onegamestart_inittable(gameobj)
	tableobj.state = ETableState.TABLE_STATE_WAIT_ALL_READY
end

function RoomGameLogic.gameend(gameobj)
	local tableobj = gameobj.tableobj
	local roomtablelogic = logicmng.get_logicbyname("roomtablelogic")
	----重置桌子状态为等待玩家准备开始游戏的状态
	roomtablelogic.resetTable(tableobj)
end

function RoomGameLogic.is_ingame(gameobj, seat)
	return (seat.state == ESeatState.SEAT_STATE_PLAYING
			or seat.state == ESeatState.SEAT_STATE_CHECK
			or seat.state == ESeatState.SEAT_STATE_CHUPAI
			or seat.state == ESeatState.SEAT_STATE_FOLLOW_CHUPAI
			or seat.state == ESeatState.SEAT_STATE_TAOPAO)
end

function RoomGameLogic.onegamestart_inittable(gameobj)
	local tableobj = gameobj.tableobj
	tableobj.action_seat_index = 0
	tableobj.action_to_time = 0
	tableobj.action_type = 0
	tableobj.dz_seat_index = 0
	if tableobj.ddzgame == nil then
		tableobj.ddzgame = ddzgamelogic:new()
	end
	tableobj.initCards = nil	   --牌池
	tableobj.baseTimes = tableobj.conf.common_times
	tableobj.CardsHeaps = nil 		---保存玩家出过的牌的牌堆
	tableobj.jzdbegin_index = 0
	tableobj.noputsCardsNum = 0
	if tableobj.iswilldelete ~= 1 then
		tableobj.iswilldelete = 0
	end
	tableobj.nojdznums = 0
	tableobj.ischuntian = 0
	if tableobj.timer_id >= 0 then
		timer.cleartimer(tableobj.timer_id)
		tableobj.timer_id = -1
	end	
end

function RoomGameLogic.standup_clear_seat(gameobj, seat)
	local roomseatlogic = logicmng.get_logicbyname("roomseatlogic")
	roomseatlogic.clear_seat(seat)
end

------普通桌发牌
function RoomGameLogic.RiffleandPostCards(gameobj)
	local tableobj = gameobj
	if tableobj.state == ETableState.TABLE_STATE_WAIT_COUNT_DOWN then
		----生成一副牌
		tableobj.ddzgame.InitCards(tableobj)
		----洗牌
		tableobj.ddzgame.Riffle(tableobj)
		----发牌
		local firstIndex = base.get_random(1,3)
		tableobj.ddzgame.PostCards(tableobj,firstIndex)
		-----发牌给客户端
		local roomseatlogic = logicmng.get_logicbyname("roomseatlogic")
		for key,value in pairs(tableobj.seats) do
			if value.state == ESeatState.SEAT_STATE_WAIT_START then
				roomseatlogic.dealcards(value)
				roomseatlogic.onegamestart_initseat(value)
			end
		end
		----设置桌子状态为等待明牌状态
		tableobj.state = ETableState.TABLE_STATE_WAIT_PLAYER_MINGPAI
		tableobj.action_type = EActionType.ACTION_TYPE_MINGPAI
		local roomgamelogic = msghelper:get_game_logic()
		roomgamelogic.run(tableobj.gamelogic)
	end
end

return RoomGameLogic