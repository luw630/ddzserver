local skynet = require "skynet"
local filelog = require "filelog"
local msghelper = require "roomsvrhelper"
local msgproxy = require "msgproxy"
local base = require "base"
local configdao = require "configdao"
local timetool = require "timetool"
require "enum"

local filename = "RoomsvrRequest.lua"
local RoomsvrRequest = {}

function RoomsvrRequest.process(session, source, event, ...)
	local f = RoomsvrRequest[event] 
	if f == nil then
		filelog.sys_error(filename.." RoomsvrRequest.process invalid event:"..event)
		base.skynet_retpack(nil)
		return
	end
	f(session, source, ...)
end

--[[
//请求创建朋友桌
message CreateFriendTableReq {
	optional Version version = 1;
	optional int32 action_timeout = 2;       //玩家出牌时间
	optional int32 retain_time = 3;          //朋友桌保留时间单位s
	optional int32 base_coin = 4;            //基础分
	optional int32 iscontrol = 5;            //是否控制申请 1表示是 2表示否
}

//响应创建朋友桌
message CreateFriendTableRes {
	optional int32 errcode = 1; //错误原因 0表示成功
	optional string errcodedes = 2; //错误描述
	optional string create_table_id = 3; //朋友桌索引号
}
]]

function RoomsvrRequest.createfriendtable(session, source, request)
	local responsemsg = {
		errcode = EErrCode.ERR_SUCCESS,
	}

	if request.retain_time == nil or request.action_timeout == nil
			or request.base_coin == nil or request.iscontrol == nil then
		responsemsg.errcodedes = "无效请求！"
		base.skynet_retpack(responsemsg)
		filelog.sys_error("RoomsvrRequest.createfriendtable two invalid request param")
		return
	end
	local var = configdao.get_business_conf(100, 1000, "globalvarcfg")
	local conf = {
		conf_version = 1,
		room_type = ERoomType.ROOM_TYPE_FRIEND_COMMON,
		retain_time = request.retain_time,
		name = request.name or request.playerinfo.rolename.."的房间",
		game_type = request.game_type or EGameType.GAME_TYPE_DDZ_NEW_PLAYER,
	    max_player_num = 3,		---玩家数
	    create_user_rid = request.rid,
	    create_user_rolename = request.playerinfo.rolename,
	    create_user_logo = request.playerinfo.logo,
	    create_time = timetool.get_time(),
	   	action_timeout = request.action_timeout,       --玩家出牌时间
		action_timeout_count = var.action_timeout_count_friend,
		min_carry_coin = 0,
		max_carry_coin = 0,
		base_coin = request.base_coin,
    	common_times  = var.common_times_firend,
    	iscontrol = request.iscontrol,
    	ready_timeout = var.ready_timeout_friend,
    	max_watch_playernum = 20,
		tuoguan_action_time = var.tuoguan_action_time,
		max_putcards_time = var.putcards_times_friend,
	}

    local result, create_table_id = msghelper:create_friend_table(conf)
    if not result then
		responsemsg.errcode = EErrCode.ERR_CREATE_TABLE_FAILED
    	responsemsg.errcodedes = "系统错误，创建朋友桌失败！"
		filelog.sys_error("RoomsvrRequest.createfriendtable create_friend_table failed")
    else
    	responsemsg.create_table_id = create_table_id
    end

    base.skynet_retpack(responsemsg)
end

return RoomsvrRequest