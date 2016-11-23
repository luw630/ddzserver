local skynet = require "skynet"
local filelog = require "filelog"
local msghelper = require "roomsvrhelper"
local msgproxy = require "msgproxy"
local configdao = require "configdao"
local base = require "base"
local filename = "roomsvrcmd.lua"
local RoomsvrCMD = {}

function RoomsvrCMD.process(session, source, event, ...)
	local f = RoomsvrCMD[event] 
	if f == nil then
		filelog.sys_error(filename.."RoomsvrCMD.process invalid event:"..event)
		return nil
	end
	f(...)	 
end

function RoomsvrCMD.delete_table(id)
	msghelper:delete_table(id)
end

function RoomsvrCMD.start(conf)
	local server = msghelper:get_server()
	server.friend_table_id = string.match(skynet.getenv("svr_id"), "%a*_(%d+)")
	server.friend_table_id = math.floor(server.friend_table_id * 100000)

	msghelper:set_idle_table_pool(conf)

	--通知tablesvrd自己初始化
	msgproxy.sendrpc_broadcastmsgto_tablesvrd("init", skynet.getenv("svr_id"))

	--初始化桌子列表
	msghelper:loadroomtablecfg()

	base.skynet_retpack(true)

	msghelper:start_time_tick()	
end

function RoomsvrCMD.close(...)
	local server = msghelper:get_server()
	server:exit_service()	
end

function RoomsvrCMD.reload(...)
	base.skynet_retpack(1)

	filelog.sys_error("GlobaldbsvrCMD.reload start")

	configdao.reload()

	skynet.sleep(200)

	msghelper:loadroomtablecfg()

	msgproxy.reload()
	
	filelog.sys_error("GlobaldbsvrCMD.reload end")
end

return RoomsvrCMD