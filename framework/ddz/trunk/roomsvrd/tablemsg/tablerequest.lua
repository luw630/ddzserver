local skynet = require "skynet"
local filelog = require "filelog"
local msghelper = require "tablehelper"
local timer = require "timer"
local timetool = require "timetool"
local configdao = require "configdao"
local base = require "base"
local msgproxy = require "msgproxy"
local logicmng = require "logicmng"
local tabletool = require "tabletool"
local filename = "tablerequest.lua"

require "enum"

local TableRequest = {}

function TableRequest.process(session, source, event, ...)
	local f = TableRequest[event] 
	if f == nil then
		filelog.sys_error(filename.." TableRequest.process invalid event:"..event)
		base.skynet_retpack(nil)
        return nil
	end
	f(...)
end

function TableRequest.disconnect(request)
	local result
	local server = msghelper:get_server()
	local table_data = server.table_data
	local seat
	local roomtablelogic = logicmng.get_logicbyname("roomtablelogic")
	if request.id ~= table_data.id then
		base.skynet_retpack(false)		
		return
	end

	seat = roomtablelogic.get_seat_by_rid(table_data, request.rid)

	if seat == nil then
		base.skynet_retpack(false)		
		return		
	end

	if seat.gatesvr_id ~= request.gatesvr_id 
		or seat.agent_address ~= request.agent_address then
		base.skynet_retpack(false)		
		return		
	end
	base.skynet_retpack(true)
	
	roomtablelogic.disconnect(table_data, request, seat)
end
--[[
//请求进入桌子
message EnterTableReq {
	optional Version version = 1;
	optional int32 id = 2;
	optional string roomsvr_id = 3; //房间服务器id
	optional int32  roomsvr_table_address = 4; //桌子的服务器地址 
}

//响应进入桌子
message EnterTableRes {
	optional int32 errcode = 1; //错误原因 0表示成功
	optional string errcodedes = 2; //错误描述	
	optional GameInfo gameinfo = 3;
}
]]
function TableRequest.entertable(request)
	local responsemsg = {
		errcode = EErrCode.ERR_SUCCESS, 
	}
	local server = msghelper:get_server()
	local table_data = server.table_data
	local seatinfo, seat
	local roomtablelogic = logicmng.get_logicbyname("roomtablelogic")
	
	if request.id ~= table_data.id then
		responsemsg.errcode = EErrCode.ERR_INVALID_REQUEST
		responsemsg.errcodedes = "无效请求！"
		base.skynet_retpack(responsemsg, nil)		
		return
	end

	if table_data.conf.max_watch_playernum ~= nil 
		and table_data.cur_watch_playernum >= table_data.conf.max_watch_playernum then
		responsemsg.errcode = EErrCode.ERR_TABLE_FULL
		responsemsg.errcodedes = " 旁观人数过多!!!"
		base.skynet_retpack(responsemsg, nil)
		return 
	end
	seat = roomtablelogic.get_seat_by_rid(table_data, request.rid)

	if seat ~= nil then
		seatinfo = {
			index = seat.index,
		}
		seat.gatesvr_id=request.gatesvr_id
		seat.agent_address = request.agent_address
		seat.playerinfo.rolename=request.playerinfo.rolename
		seat.playerinfo.logo=request.playerinfo.logo
		seat.playerinfo.sex=request.playerinfo.sex
	end

	responsemsg.gameinfo = {}

	msghelper:copy_table_gameinfo(responsemsg.gameinfo)
	----filelog.sys_error("rid ===================",request.rid)
	----filelog.sys_error("responsemsg.gameinfo ===================",responsemsg.gameinfo)
	base.skynet_retpack(responsemsg, seatinfo)
	roomtablelogic.entertable(table_data, request, seat)
end

function TableRequest.reentertable(request)
	local responsemsg = {
		errcode = EErrCode.ERR_SUCCESS, 
	}
	local server = msghelper:get_server()
	local table_data = server.table_data
	local seatinfo, seat, waitinfo
	local roomtablelogic = logicmng.get_logicbyname("roomtablelogic")

	seat = roomtablelogic.get_seat_by_rid(table_data, request.rid)
    waitinfo = table_data.waits[request.rid]
	if seat ~= nil then
		seatinfo = {
			index = seat.index,
		}
		seat.gatesvr_id=request.gatesvr_id
		seat.agent_address = request.agent_address
		seat.playerinfo.rolename=request.playerinfo.rolename
		seat.playerinfo.logo=request.playerinfo.logo
		seat.playerinfo.sex=request.playerinfo.sex
	elseif waitinfo ~= nil then
		waitinfo.gatesvr_id=request.gatesvr_id
		waitinfo.agent_address = request.agent_address
		waitinfo.playerinfo.rolename=request.playerinfo.rolename
		waitinfo.playerinfo.logo=request.playerinfo.logo
		waitinfo.playerinfo.sex=request.playerinfo.sex		
	end

	if waitinfo == nil and seat == nil then
		responsemsg.errcode = EErrCode.ERR_INVALID_REQUEST
		responsemsg.errcodedes = "无效的请求！"
		base.skynet_retpack(responsemsg, seatinfo)
		return
	end

	responsemsg.gameinfo = {}
	msghelper:copy_table_gameinfo(responsemsg.gameinfo)
	base.skynet_retpack(responsemsg, seatinfo)
	if seat ~= nil then
		if seat.is_disconnected == 1 then
			seat.is_disconnected = 0
		end
		roomtablelogic.reentertable(table_data, request, seat)	 
	end
end

--[[
//请求离开桌子
message LeaveTableReq {
	optional Version version = 1;	
	optional int32 id = 2;
	optional string roomsvr_id = 3; //房间服务器id
	optional int32  roomsvr_table_address = 4; //桌子的服务器地址
}

//响应离开桌子
message LeaveTableReq {
	optional int32 errcode = 1; //错误原因 0表示成功
	optional string errcodedes = 2; //错误描述			
}
]]
function TableRequest.leavetable(request)
	local responsemsg = {
		errcode = EErrCode.ERR_SUCCESS, 
	}
	local server = msghelper:get_server()
	local table_data = server.table_data
	local seat
	local roomtablelogic = logicmng.get_logicbyname("roomtablelogic")

	if request.id ~= table_data.id then
		responsemsg.errcode = EErrCode.ERR_INVALID_REQUEST
		responsemsg.errcodedes = "无效请求！"
		base.skynet_retpack(responsemsg)		
		return
	end
	seat = roomtablelogic.get_seat_by_rid(table_data, request.rid)

	if seat == nil then
		roomtablelogic.leavetable(table_data, request, seat)
		base.skynet_retpack(responsemsg)		
		return
	end
	----如果玩家在游戏中,不能让他能够退出房间
	if not roomtablelogic.is_onegameend(table_data) then
		responsemsg.errcode = EErrCode.ERR_PLAYER_IN_GAME
		responsemsg.errcodedes = "房间正在游戏中,不能退出！"
		base.skynet_retpack(responsemsg)
		return
	end

	roomtablelogic.standuptable(table_data, request, seat)
	roomtablelogic.leavetable(table_data, request, seat)	
	base.skynet_retpack(responsemsg)		
end

--[[
//请求坐入桌子
message SitdownTableReq {
	optional Version version = 1;
	optional int32 id = 2;
	optional string roomsvr_id = 3; //房间服务器id
	optional int32  roomsvr_table_address = 4; //桌子的服务器地址
	optional int32  roomsvr_seat_index = 5; //指定桌位号
}

//响应坐入桌子
message SitdownTableRes {
	optional int32 errcode = 1; //错误原因 0表示成功
	optional string errcodedes = 2; //错误描述	
}
]]
function TableRequest.sitdowntable(request)
 	local responsemsg = {
		errcode = EErrCode.ERR_SUCCESS, 
	}
	local server = msghelper:get_server()
	local table_data = server.table_data
	local seatinfo, seat
	local roomtablelogic = logicmng.get_logicbyname("roomtablelogic")

	seat = roomtablelogic.get_seat_by_rid(table_data, request.rid)

	if seat ~= nil then
		seatinfo = {
			index = seat.index
		}
		seat.gatesvr_id=request.gatesvr_id
		seat.agent_address = request.agent_address
		seat.playerinfo.rolename=request.playerinfo.rolename
		seat.playerinfo.logo=request.playerinfo.logo
		seat.playerinfo.sex=request.playerinfo.sex
		seat.playerinfo.totalgamenum = request.playerinfo.totalgamenum
		seat.playerinfo.winnum = request.playerinfo.winnum
		seat.playerinfo.highwininseries = request.playerinfo.highwininseries
		seat.playerinfo.maxcoinnum = request.playerinfo.maxcoinnum
		seat.playerinfo.coins = request.playerinfo.coin
		seat.playerinfo.diamonds = request.playerinfo.diamonds

		base.skynet_retpack(responsemsg, seatinfo)
		return
	else
		if roomtablelogic.is_full(table_data) then
			responsemsg.errcode = EErrCode.ERR_TABLE_FULL
			responsemsg.errcodedes = "当前桌子已经满了！"
			base.skynet_retpack(responsemsg, seatinfo)
			return
		end

		--他的金币是否能够坐下
		if table_data.conf.max_carry_coin > 0 and request.coin > table_data.conf.max_carry_coin then
			responsemsg.errcode = EErrCode.ERR_TOO_MOUCH_COIN
			responsemsg.errcodedes = "金币太多，不能进入当前场次！"
			base.skynet_retpack(responsemsg, seatinfo)
			return
		end

		if request.coin < table_data.conf.min_carry_coin then
			responsemsg.errcode = EErrCode.ERR_NOTENOUGH_COIN
			responsemsg.errcodedes = "金币不足，不能进入当前场次！"
			base.skynet_retpack(responsemsg, seatinfo)
			return
		end
		if request.roomsvr_seat_index == 0 then
			seat = roomtablelogic.get_emptyseat_by_index(table_data, nil)
		else
			seat = roomtablelogic.get_emptyseat_by_index(table_data, request.roomsvr_seat_index)
		end

		if seat == nil then
			responsemsg.errcode = EErrCode.ERR_NO_EMPTY_SEAT
			responsemsg.errcodedes = "当前桌子没有空座位了！"
			base.skynet_retpack(responsemsg, seatinfo)
			return			
		end
		if seat.state ~= ESeatState.SEAT_STATE_NO_PLAYER then
			responsemsg.errcode = EErrCode.ERR_NOT_NO_PLAYER
			responsemsg.errcodedes = "座位不是没有玩家的状态！"
			base.skynet_retpack(responsemsg, seatinfo)
		end
		seatinfo = {
			index = seat.index,
		}

		--增加桌子人数计数 
		table_data.sitdown_player_num = table_data.sitdown_player_num + 1		
	end
	base.skynet_retpack(responsemsg, seatinfo)

	roomtablelogic.sitdowntable(table_data, request, seat)

end

--[[
//请求从桌子站起
message StandupTableReq {
	optional Version version = 1;
	optional int32 id = 2;
	optional string roomsvr_id = 3; //房间服务器id
	optional int32  roomsvr_table_address = 4; //桌子的服务器地址
}

//响应从桌子站起
message StandupTableRes {
	optional int32 errcode = 1; //错误原因 0表示成功
	optional string errcodedes = 2; //错误描述		
}
]]
function TableRequest.standuptable(request)
	local responsemsg = {
		errcode = EErrCode.ERR_SUCCESS, 
	}
	local server = msghelper:get_server()
	local table_data = server.table_data
	local seat
	local roomtablelogic = logicmng.get_logicbyname("roomtablelogic")

	seat = roomtablelogic.get_seat_by_rid(table_data, request.rid)

	if seat == nil then
		responsemsg.errcode = EErrCode.ERR_HAD_STANDUP
		responsemsg.errcodedes = "你已经站起了！"
		base.skynet_retpack(responsemsg)
		return
	end

	base.skynet_retpack(responsemsg)

	roomtablelogic.standuptable(table_data, request, seat)
end
--[[
//桌主请求开始游戏
message StartGameReq {
	optional Version version = 1;	
	optional int32 id = 2;
	optional string roomsvr_id = 3; //房间服务器id
	optional int32  roomsvr_table_address = 4; //桌子的服务器地址	
}

//响应桌主开始游戏
message StartGameRes {
	optional int32 errcode = 1; //错误原因 0表示成功
	optional string errcodedes = 2; //错误描述		
}
]]
function TableRequest.startgame(request)
	local responsemsg = {
		errcode = EErrCode.ERR_SUCCESS, 
	}
	local server = msghelper:get_server()
	local table_data = server.table_data

	if table_data.state ~= ETableState.TABLE_STATE_WAIT_GAME_START then
		responsemsg.errcode = EErrCode.ERR_INVALID_REQUEST
		responsemsg.errcodedes = "无效请求！"
		base.skynet_retpack(responsemsg)
		return		
	end
	base.skynet_retpack(responsemsg)
	local roomtablelogic = logicmng.get_logicbyname("roomtablelogic")
	roomtablelogic.startgame(table_data, request)
end

function TableRequest.doaction(request)
	local responsemsg = {
		errcode = EErrCode.ERR_SUCCESS, 
	}
	local server = msghelper:get_server()
	local table_data = server.table_data
	local roomtablelogic = logicmng.get_logicbyname("roomtablelogic")
	local roomseatlogic = logicmng.get_logicbyname("roomseatlogic")
	local seat = roomtablelogic.get_seat_by_rid(table_data, request.rid)
	if seat == nil then
		responsemsg.errcode = EErrCode.ERR_HAD_STANDUP
		responsemsg.errcodedes = "玩家不在座位上！"
		base.skynet_retpack(responsemsg)
		return
	end

	if request.action_type == EActionType.ACTION_TYPE_REQUEST_TUOGUAN then
		---玩家托管请求
		if seat.is_tuoguan == EBOOL.TRUE then
			responsemsg.errcode = EErrCode.ERR_INVALID_REQUEST
			responsemsg.errcodedes = "在托管中,不能重复托管!!!!!"
			base.skynet_retpack(responsemsg)
		elseif seat.is_tuoguan == EBOOL.FALSE then
			base.skynet_retpack(responsemsg)
			roomseatlogic.dealtuoguan(table_data,seat)
		end
		return
	elseif request.action_type == EActionType.ACTION_TYPE_CANCEL_TUOGUAN then
		---玩家取消托管
		if seat.is_tuoguan == EBOOL.FALSE then
			responsemsg.errcode = EErrCode.ERR_INVALID_REQUEST
			responsemsg.errcodedes = "未在托管中,不能取消托管!!!!!"
			base.skynet_retpack(responsemsg)
		elseif seat.is_tuoguan == EBOOL.TRUE then
			base.skynet_retpack(responsemsg)
			roomseatlogic.canceltuoguan(table_data,seat)
		end
		return
	end

	if request.action_type == EActionType.ACTION_TYPE_CHECK 
		and table_data.action_type ~= EActionType.ACTION_TYPE_FOLLOW_CHUPAI then
		responsemsg.errcode = EErrCode.ERR_INVALID_REQUEST
		responsemsg.errcodedes = "无效请求！"
		base.skynet_retpack(responsemsg)
		return		
	end

	if ((request.action_type ~= EActionType.ACTION_TYPE_CHECK and request.action_type ~= EActionType.ACTION_TYPE_BUQIANGDIZHU
		 	and request.action_type ~= EActionType.ACTION_TYPE_BUJIAO_DIZHU and request.action_type ~= EActionType.ACTION_TYPE_TIMEOUT_JDZ )
		and table_data.action_type ~= request.action_type)
		or table_data.action_seat_index ~= seat.index then
		responsemsg.errcode = EErrCode.ERR_INVALID_REQUEST
		responsemsg.errcodedes = "无效请求！"
		base.skynet_retpack(responsemsg)
		return		
	end

	if request.action_type == EActionType.ACTION_TYPE_FOLLOW_CHUPAI or request.action_type == EActionType.ACTION_TYPE_CHUPAI then
		--TO ADD 牌大小合法性判断
		---如果是该回合第一个出牌,则只判断牌型的合法性
		if request.cards == nil or #request.cards == 0 then
			responsemsg.errcode = EErrCode.ERR_INVALID_CARDTYPE
			responsemsg.errcodedes = "无效牌型！"
			base.skynet_retpack(responsemsg)
			return
		end
		local cardHelper = table_data.ddzgame.CreateCardsHelper(request.cards)
		cardHelper:GetCardsType(cardHelper)
		if cardHelper.m_eCardType == ECardType.DDZ_CARD_TYPE_UNKNOWN then
			responsemsg.errcode = EErrCode.ERR_INVALID_CARDTYPE
			responsemsg.errcodedes = "无效牌型！"
			base.skynet_retpack(responsemsg)
			return
		end
		local keyinhands = {}
		if cardHelper.m_nLen ~= #request.cards then
			responsemsg.errcode = EErrCode.ERR_INVALID_CARDTYPE
			responsemsg.errcodedes = "无效牌型！"
			base.skynet_retpack(responsemsg)
			return
		end
		if request.action_type == EActionType.ACTION_TYPE_FOLLOW_CHUPAI then
			----取牌堆最顶上的牌,比较大小
			local roundheaps = table_data.CardsHeaps[#table_data.CardsHeaps]
			if #table_data.CardsHeaps == 0 or roundheaps[#roundheaps].cardHelper == nil then
				responsemsg.errcode = EErrCode.ERR_INVALID_CARDTYPE
				responsemsg.errcodedes = "无效牌型！"
				base.skynet_retpack(responsemsg)
				return
			else
				local roundheap = table_data.CardsHeaps[#table_data.CardsHeaps]
				local compareflag = cardHelper:CompareCards(roundheap[#roundheap].cardHelper,cardHelper)
				if compareflag == false then
					responsemsg.errcode = EErrCode.ERR_INVALID_CARDTYPE
					responsemsg.errcodedes = "你出的牌太小,大不过上家！"
					base.skynet_retpack(responsemsg)
					return
				end
			end
		end
		----从玩家手牌上删除
		for k,v in ipairs(request.cards) do
			for m,n in ipairs(seat.cards) do
				if v == n then table.remove(seat.cards,m) end
			end
		end
		----加入牌堆中
		if table_data.CardsHeaps == nil then
			table_data.CardsHeaps = {}
		end
		local heapOne = {
			rid = request.rid,
			cardHelper = tabletool.deepcopy(cardHelper)
		}
		if heapOne.cardHelper.m_eCardType == ECardType.DDZ_CARD_TYPE_BOMB or heapOne.cardHelper.m_eCardType == ECardType.DDZ_CARD_TYPE_ROCKET then
			table_data.baseTimes = table_data.baseTimes * 2
		end
		if request.action_type == EActionType.ACTION_TYPE_CHUPAI then
			table_data.CardsHeaps[#table_data.CardsHeaps+1] = {}
			table.insert(table_data.CardsHeaps[#table_data.CardsHeaps],heapOne)
		elseif request.action_type == EActionType.ACTION_TYPE_FOLLOW_CHUPAI then
			table.insert(table_data.CardsHeaps[#table_data.CardsHeaps],heapOne)
		end
	elseif request.action_type == EActionType.ACTION_TYPE_JIAODIZHU then
		---玩家叫地主 判断是否该这个玩家叫地主
		if seat.index ~= table_data.action_seat_index then
			responsemsg.errcode = EErrCode.ERR_INVALID_CARDTYPE
			responsemsg.errcodedes = "不该你叫地主,慌鸡毛啊！"
			base.skynet_retpack(responsemsg)
			return
		end
		if seat.jdztag ~= 0 or not request.call_times then
			responsemsg.errcode = EErrCode.ERR_INVALID_REQUEST
			responsemsg.errcodedes = "无效请求！"
			base.skynet_retpack(responsemsg)
			return
		end
		if request.call_times and request.call_times > 0 then
			local flag = true
			for key,value in ipairs(table_data.seats) do
				if value.jdz_score >= request.call_times then flag = false break end
			end
			if flag == false or request.call_times > 3 then
				responsemsg.errcode = EErrCode.ERR_INVALID_REQUEST
				responsemsg.errcodedes = "无效请求！"
				base.skynet_retpack(responsemsg)
				return
			end
			seat.jdz_score = request.call_times
		end
	elseif request.action_type == EActionType.ACTION_TYPE_BUJIAO_DIZHU then
		----玩家不叫地主
		---table_data.action_type = EActionType.ACTION_TYPE_BUJIAO_DIZHU

	elseif request.action_type == EActionType.ACTION_TYPE_QIANGDIZHU then
		table_data.action_type = EActionType.ACTION_TYPE_QIANGDIZHU

	elseif request.action_type == EActionType.ACTION_TYPE_CHECK then
		table_data.action_type = EActionType.ACTION_TYPE_CHECK

	elseif request.action_type == EActionType.ACTION_TYPE_REQUEST_TUOGUAN then
		---玩家托管请求
		if seat.is_tuoguan == EBOOL.TRUE then
			responsemsg.errcode = EErrCode.ERR_INVALID_REQUEST
			responsemsg.errcodedes = "在托管中,不能重复托管!!!!!"
			base.skynet_retpack(responsemsg)
		elseif seat.is_tuoguan == EBOOL.FALSE then
			base.skynet_retpack(responsemsg)
			roomtablelogic.dealtuoguan(table_data,seat)
		end
		return
	elseif request.action_type == EActionType.ACTION_TYPE_CANCEL_TUOGUAN then
		---玩家取消托管
		if seat.is_tuoguan == EBOOL.FALSE then
			responsemsg.errcode = EErrCode.ERR_INVALID_REQUEST
			responsemsg.errcodedes = "未在托管中,不能取消托管!!!!!"
			base.skynet_retpack(responsemsg)
		elseif seat.is_tuoguan == EBOOL.TRUE then
			base.skynet_retpack(responsemsg)
			roomtablelogic.canceltuoguan(table_data,seat)
		end
		return
	end
	
	base.skynet_retpack(responsemsg)
	roomtablelogic.doaction(table_data, request, seat)		
end

function TableRequest.gameready(request)
	local responsemsg = {
		errcode = EErrCode.ERR_SUCCESS,
	}
	local server = msghelper:get_server()
	local table_data = server.table_data
	local roomtablelogic = logicmng.get_logicbyname("roomtablelogic")
	local seat = roomtablelogic.get_seat_by_rid(table_data, request.rid)
	if seat == nil then
		responsemsg.errcode = EErrCode.ERR_HAD_STANDUP
		responsemsg.errcodedes = "玩家不在座位上！"
		base.skynet_retpack(responsemsg)
		return
	end

	if seat.state ~= ESeatState.SEAT_STATE_WAIT_READY then
		responsemsg.errcode = EErrCode.ERR_HAD_STANDUP
		responsemsg.errcodedes = "座位状态不是等待准备状态！"
		base.skynet_retpack(responsemsg)
		return
	end
	---如果房间
	seat.state = ESeatState.SEAT_STATE_WAIT_START
	if seat.ready_timer_id > 0  then ---取消准备倒计时
		timer.cleartimer(seat.ready_timer_id)
		seat.ready_timer_id = -1
	end
	base.skynet_retpack(responsemsg)
	roomtablelogic.gameready(table_data, request, seat)
end

--- 玩家发送桌内聊天消息
-- @param request
--
function TableRequest.sendTableMessage(request)
	-- body
	local responsemsg = {
		errcode = EErrCode.ERR_SUCCESS,
	}
	local server = msghelper:get_server()
	local table_data = server.table_data
	local roomtablelogic = logicmng.get_logicbyname("roomtablelogic")
	local seat = roomtablelogic.get_seat_by_rid(table_data, request.rid)
	if seat == nil  then
		responsemsg.errcode = EErrCode.ERR_NOT_INTABLE
		responsemsg.errcodedes = "你已经不在桌内！"
		base.skynet_retpack(responsemsg)
		return
	end
	------向房间内的玩家广播消息
	-------roomtablelogic.sendMessage(table_data, request.messages)
	base.skynet_retpack(responsemsg)
	local messageresponmsg = {
		rid = seat.rid,
		seat_index = seat.index,
		messages = request.messages,
		chat_type = request.chat_type,
	}
	msghelper:sendmsg_to_alltableplayer("PlayerTableMessageNtc",messageresponmsg)
end

return TableRequest