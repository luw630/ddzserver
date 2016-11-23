local skynet = require "skynet"
local filelog = require "filelog"
local msgproxy = require "msgproxy"
local configdao = require "configdao"
local base = require "base"
local tabletool = require "tabletool"
local timetool = require "timetool"
local helperbase = require "helperbase"
local logicmng = require "logicmng"
require "enum"

local TablesvrHelper = helperbase:new({
    writelog_tables = nil,
    })

function TablesvrHelper:sendmsg_to_alltableplayer(msgname, msg, ...)
    local table_data = self.server.table_data
    --通知座位上的玩家
    for _, seat in ipairs(table_data.seats) do
        if seat.state ~= ESeatState.SEAT_STATE_NO_PLAYER and seat.gatesvr_id ~= "" and seat.is_disconnected == 0 then
            --filelog.sys_protomsg(msgname..":"..seat.rid, "____"..skynet.self().."_game_notice_____", msg)
            msgproxy.sendrpc_noticemsgto_gatesvrd(seat.gatesvr_id,seat.agent_address, msgname, msg, ...)
        end
    end
    --通知旁观玩家
    for rid, wait in pairs(table_data.waits) do
        --filelog.sys_protomsg(msgname..":"..rid, "____"..skynet.self().."_game_notice_____", msg)
        if wait.gatesvr_id ~= "" then
            msgproxy.sendrpc_noticemsgto_gatesvrd(wait.gatesvr_id, wait.agent_address, msgname, msg, ...)
        end
    end
end

function TablesvrHelper:sendmsg_to_tableplayer(seat, msgname, ...)
    if seat.state ~= ESeatState.SEAT_STATE_NO_PLAYER and seat.gatesvr_id ~= "" and seat.is_disconnected == 0 then
        msgproxy.sendrpc_noticemsgto_gatesvrd(seat.gatesvr_id,seat.agent_address, msgname, ...)
    end
end

function TablesvrHelper:sendmsg_to_allwaitplayer(msgname, msg, ...)
    local table_data = self.server.table_data
    for rid, wait in pairs(table_data.waits) do
        --filelog.sys_protomsg(msgname..":"..rid, "____"..skynet.self().."_game_notice_____", msg)
        if wait.gatesvr_id ~= "" then
            msgproxy.sendrpc_noticemsgto_gatesvrd(wait.gatesvr_id, wait.agent_address, msgname, msg, ...)
        end
    end
end
function TablesvrHelper:sendmsg_to_waitplayer(wait, msgname, ...)
    if wait.gatesvr_id ~= "" then
        msgproxy.sendrpc_noticemsgto_gatesvrd(wait.gatesvr_id, wait.agent_address, msgname, ...)
    end
end

--[[
message SeatInfo {
    optional int32 rid = 1;
    optional int32 index = 2;
    optional int32 state = 3;
    optional int32 is_tuoguan = 4; //1表示是 2表示否
    optional int32 coin = 5;  //金币
}

message TablePlayerInfo {
    optional int32 rid = 1;
    optional string rolename = 2;
    optional string logo = 3;
    optional int32 sex = 4;
}

message GameInfo {
    optional int32 id = 1;    //table id
    optional int32 state = 2; //table state
    optional string name = 3; //桌子名字
    optional int32 room_type = 4; //房间类型
    optional int32 game_type = 5; //游戏类型
    optional int32 max_player_num = 6;   //房间支持的最大人数
    optional int32 cur_player_num = 7;   //状态服务器
    optional int32 retain_to_time = 8;   //桌子保留到的时间(linux时间擢)
    optional int32 create_user_rid = 9; //创建者rid
    optional string create_user_rolename = 10; //创建者姓名
    optional int32 create_time = 11;      //桌子的创建时间
    optional string create_table_id = 12; //创建桌子的索引id   
    optional string roomsvr_id = 13;      //房间服务器id
    optional int32 roomsvr_table_address = 14; //桌子table的地址
    optional int32 action_timeout = 15;       //玩家操作限时
    optional int32 action_timeout_count = 16; //玩家可操作超时次数   
    optional string create_user_logo = 17;
    optional int32 min_carry_coin = 18;
    optional int32 max_carry_coin = 19;
    optional int32 base_coin = 20;            //基础分
    optional int32 common_times  = 21;        //牌级

    optional int32 action_seat_index = 22;    //当前操作玩家的座位号
    optional int32 action_to_time = 23;       //当前操作玩家的到期时间


    //下面两个结构按数组下标一一对应
    repeated SeatInfo seats = 24; //座位
    repeated TablePlayerInfo tableplayerinfos = 25;
}

]]

function TablesvrHelper:copy_table_gameinfo(gameinfo)
    local table_data = self.server.table_data
    gameinfo.id = table_data.id
    gameinfo.state = table_data.state
    gameinfo.name = table_data.conf.name
    gameinfo.room_type = table_data.conf.room_type
    gameinfo.game_type = table_data.conf.game_type
    gameinfo.max_player_num = table_data.conf.max_player_num
    gameinfo.cur_player_num = table_data.conf.cur_player_num
    gameinfo.game_time = table_data.conf.game_time
    gameinfo.retain_to_time = table_data.retain_to_time
    gameinfo.create_user_rid = table_data.conf.create_user_rid
    gameinfo.create_user_rolename = table_data.conf.create_user_rolename
    gameinfo.create_time = table_data.conf.create_time
    gameinfo.create_table_id = table_data.conf.create_table_id
    gameinfo.action_timeout = table_data.conf.action_timeout
    gameinfo.action_timeout_count = table_data.conf.action_timeout_count           
    gameinfo.create_user_logo = table_data.conf.create_user_logo
    gameinfo.min_carry_coin = table_data.conf.min_carry_coin
    gameinfo.max_carry_coin = table_data.conf.max_carry_coin
    gameinfo.base_coin = table_data.conf.base_coin
    gameinfo.common_times  = table_data.conf.common_times
    gameinfo.all_times = table_data.baseTimes

    gameinfo.roomsvr_id = table_data.svr_id
    gameinfo.roomsvr_table_address = skynet.self()        

    gameinfo.action_seat_index = table_data.action_seat_index
    gameinfo.action_to_time = table_data.action_to_time
    gameinfo.dz_seat_index = table_data.dz_seat_index
    gameinfo.action_type = table_data.action_type

    gameinfo.seats = {}
    gameinfo.tableplayerinfos = {}
    local seatinfo, tableplayerinfo
    for index, seat in pairs(table_data.seats) do
        seatinfo = {}
        tableplayerinfo = {}
        self:copy_seatinfo(seatinfo, seat)
        table.insert(gameinfo.seats, seatinfo)
        self:copy_tableplayerinfo(tableplayerinfo, seat)
        table.insert(gameinfo.tableplayerinfos, tableplayerinfo)
    end

end

function TablesvrHelper:copy_seatinfo(seatinfo, seat)
    seatinfo.rid = seat.rid
    seatinfo.index = seat.index
    seatinfo.state = seat.state
    seatinfo.is_tuoguan = seat.is_tuoguan
    seatinfo.coin = seat.coin
    seatinfo.jdztag = seat.jdztag
    seatinfo.isdz = seat.isdz
    seatinfo.ready_to_time = seat.ready_to_time
    if seat.cards == nil then
        seatinfo.cardsnum = 0
    else
        seatinfo.cardsnum = #seat.cards
    end
end

function TablesvrHelper:copy_tableplayerinfo(tableplayerinfo, seat)
    tableplayerinfo.rid = seat.rid
    tableplayerinfo.rolename = seat.playerinfo.rolename
    tableplayerinfo.logo = seat.playerinfo.logo
    tableplayerinfo.sex = seat.playerinfo.sex
    tableplayerinfo.totalgamenum  = seat.playerinfo.totalgamenum
    tableplayerinfo.winnum = seat.playerinfo.winnum
    tableplayerinfo.coins = seat.playerinfo.coins
    tableplayerinfo.diamonds = seat.playerinfo.diamonds
    tableplayerinfo.highwininseries = seat.playerinfo.highwininseries
    tableplayerinfo.maxcoinnum = seat.playerinfo.maxcoinnum
end


--用于输出指定table_id桌子的信息，方便定位问题
function TablesvrHelper:write_tableinfo_log(...)
    if self.writelog_tables == nil then
        self.writelog_tables = configdao.get_common_conf("tables")
    end

    if self.writelog_tables == nil then
        return
    end
    if self.writelog_tables[self.server.table_data.id] ~= nil then
        filelog.sys_obj("table", self.server.table_data.id, ...)           
    end 
end

--记录调试日志
function TablesvrHelper:write_debug_log(classname, objname, ...)
    if base.isdebug() then
        filelog.sys_obj(classname, objname, ...)
    end
end

function TablesvrHelper:report_table_state()
    local table_data = self.server.table_data
    --上报table
    local table_state = {
        id = table_data.id,
        state = table_data.state,
        name = table_data.conf.name,
        room_type = table_data.conf.room_type,
        game_type = table_data.conf.game_type,
        max_player_num = table_data.conf.max_player_num,
        cur_player_num = table_data.sitdown_player_num,

        retain_to_time = table_data.retain_to_time,
        create_user_rid = table_data.conf.create_user_rid,
        create_user_rolename = table_data.conf.create_user_rolename,
        create_user_logo = table_data.conf.create_user_logo,
        create_time = table_data.conf.create_time,
        create_table_id = table_data.conf.create_table_id,
        action_timeout = table_data.conf.action_timeout,
        action_timeout_count = table_data.conf.action_timeout_count,           
        min_carry_coin = table_data.conf.min_carry_coin,
        max_carry_coin = table_data.conf.max_carry_coin,
        base_coin = table_data.conf.base_coin,
        common_times = table_data.conf.common_times,

        roomsvr_id = table_data.svr_id,
        roomsvr_table_address = skynet.self(),        
    }
    msgproxy.sendrpc_broadcastmsgto_tablesvrd("update", table_data.svr_id, table_state)
end

function TablesvrHelper:get_game_logic()
    local table_data = self.server.table_data  
    if table_data.conf.room_type == ERoomType.ROOM_TYPE_COMMON then
        return logicmng.get_logicbyname("roomgamelogic")
    elseif table_data.conf.room_type == ERoomType.ROOM_TYPE_FRIEND_COMMON then
        return logicmng.get_logicbyname("roomfndgamelogic")
    end
end

function TablesvrHelper:copy_playerinfoingameend(playerendinfos)
    local table_data = self.server.table_data
    local playerendinfo
    for index, seat in pairs(table_data.seats) do
        playerendinfo = {}
        playerendinfo.rid = seat.rid
        playerendinfo.rolename = seat.playerinfo.rolename ---玩家名字
        playerendinfo.allcoins = seat.coin ---当前玩家总金币
        if seat.win == 0 then
            if seat.isdz == 0 then
                playerendinfo.getcoins = - math.floor(table_data.baseTimes * table_data.conf.base_coin)---本局比赛获得的金币
            elseif seat.isdz == 1 then
                playerendinfo.getcoins = - math.floor(2 * table_data.baseTimes * table_data.conf.base_coin)---本局比赛获得的金币
            end
        elseif seat.win == 1 then
            if seat.isdz == 0 then
                playerendinfo.getcoins = math.floor(table_data.baseTimes * table_data.conf.base_coin)---本局比赛获得的金币
            elseif seat.isdz == 1 then
                playerendinfo.getcoins = math.floor(2 * table_data.baseTimes * table_data.conf.base_coin)---本局比赛获得的金币
            end
        end
        playerendinfo.isdz = seat.isdz ---是否是地主(0农民,1地主)
        playerendinfo.iswin = seat.win ----是否胜利(1胜利，0失败)
        playerendinfo.seatindex = seat.index
        table.insert(playerendinfos,playerendinfo)
    end
end

return  TablesvrHelper