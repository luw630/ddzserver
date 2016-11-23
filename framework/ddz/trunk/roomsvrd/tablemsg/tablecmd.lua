local skynet = require "skynet"
local filelog = require "filelog"
local msghelper = require "tablehelper"
local msgproxy = require "msgproxy"
local base = require "base"
local logicmng = require "logicmng"
local timetool = require "timetool"
local tabletool = require "tabletool"
local timer = require "timer"
local filename = "tablecmd.lua"
require "enum"
local TableCMD = {}

function TableCMD.process(session, source, event, ...)
	local f = TableCMD[event] 
	if f == nil then
		filelog.sys_error(filename.." TableCMD.process invalid event:"..event)
		return nil
	end
	f(...)	 
end
--[[
conf = {
	....
	room_type = ,
	retain_time = ,
	game_time = ,
	name = ,
	game_type = 0,
    max_player_num = 0,
    create_user_rid = ,
    create_user_rolename = ,
    create_user_logo=,
    create_time = ,
    create_table_id = ,
   	action_timeout = ,       --玩家操作限时
	action_timeout_count = , --玩家可操作超时次数
	....
}
]]
function TableCMD.start(conf, roomsvr_id, id)
	if conf == nil or roomsvr_id == nil then
		filelog.sys_error(filename.."conf == nil or roomsvr_id == nil")
		base.skynet_retpack(false)
		return
	end

	if id ~= nil then
		conf.id = id
	end

	local server = msghelper:get_server()
	local roomtablelogic = logicmng.get_logicbyname("roomtablelogic")
	--roomtablelogic.init(server.table_data, conf, roomsvr_id)
	roomtablelogic.init(server.table_data, conf, roomsvr_id)
    --上报状态
    msghelper:report_table_state()
	
	base.skynet_retpack(true)
end

function TableCMD.reload(conf)
	local server = msghelper:get_server()
	local table_data = server.table_data
	if conf.version <= table_data.conf.version then
		return
	end
	local roomtablelogic = logicmng.get_logicbyname("roomtablelogic")
	--TO ADD 添加reload操作
	---判断桌子是否在游戏中,如果是在游戏中，这将配置文件缓存
	if not roomtablelogic.is_gameend(table_data) then
		table_data.backofconf = tabletool.deepcopy(conf)
		return
	end
	table_data.conf = tabletool.deepcopy(conf)
	msghelper:report_table_state()
end

function TableCMD.delete(...)
	--上报桌子管理器房间被删除
	---local params = table.unpack(...)
	local server = msghelper:get_server()
	local table_data = server.table_data
	local roomtablelogic = logicmng.get_logicbyname("roomtablelogic")

	--检查桌子当前是否能够删除
	filelog.sys_error("------------table  delete ------------")
	if table_data.delete_table_timer_id > 0 then
		timer.cleartimer(table_data.delete_table_timer_id)
		table_data.delete_table_timer_id = -1
	end
	local nowtime = timetool.get_time()
	if table_data.retain_to_time > nowtime then
		table_data.delete_table_timer_id = timer.settimer((table_data.retain_to_time-nowtime)*100, "delete_table")
		return
	end

	--检查游戏是否结束
	if not roomtablelogic.is_gameend(table_data) then
		table_data.iswilldelete = 1
		return
	end
	--踢出座位上的玩家
	roomtablelogic.standupallplayer(table_data,EStandupReason.STANDUP_REASON_DELETE_TABLE)

	roomtablelogic.levelallplayer(table_data,EStandupReason.STANDUP_REASON_DELETE_TABLE)
	---纪录牌桌战绩数据
	roomtablelogic.saveGamerecords(table_data)

	msgproxy.sendrpc_broadcastmsgto_tablesvrd("delete", table_data.svr_id , table_data.id)

	--通知roomsvrd删除table
	skynet.send(table_data.svr_id, "lua", "cmd", "delete_table", table_data.id)
		
	--删除桌子前清除桌子的状态
	roomtablelogic.clear(table_data)
	--延迟释放桌子
	skynet.sleep(10)
	
	server:exit_service()
end

return TableCMD