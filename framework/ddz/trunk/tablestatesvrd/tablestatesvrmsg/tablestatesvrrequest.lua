local skynet = require "skynet"
local filelog = require "filelog"
local msghelper = require "tablestatesvrhelper"
local base = require "base"

local TableStatesvrRequest = {}

function TableStatesvrRequest.process(session, source, event, ...)
	local f = TableStatesvrRequest[event] 
	if f == nil then
		return
	end
	f(...)
end

function TableStatesvrRequest.gettablestatebycreateid(request)
	local server = msghelper:get_server()	
	local table_pool = server.table_pool
	local create_table_indexs = server.create_table_indexs
	local responsemsg = {
		errcode = EErrCode.ERR_SUCCESS,
	}
	local id = create_table_indexs[request.create_table_id]
	local tableinfo = table_pool[id]

	if id == nil or tableinfo == nil then
		responsemsg.errcode = EErrCode.ERR_INVALID_CREATETABLEID
		responsemsg.errcodedes = "无效的桌号！"
		base.skynet_retpack(responsemsg)
		return
	end
	responsemsg.tablestate = tableinfo
	base.skynet_retpack(responsemsg)
end

function TableStatesvrRequest.getfriendtablelist(request)
	local server = msghelper:get_server()	
	local table_pool = server.table_pool
	local tableinfo
	local createusers_table_indexs = server.createusers_table_indexs

	local responsemsg = {
		errcode = EErrCode.ERR_SUCCESS,
	}

	if createusers_table_indexs[request.rid] == nil then
		responsemsg.tablelist = {}
		base.skynet_retpack(responsemsg)
		return
	end

	responsemsg.tablelist = {}	
	for id, _ in pairs(createusers_table_indexs[request.rid]) do
		tableinfo = table_pool[id]
		if tableinfo ~= nil then
			table.insert(responsemsg.tablelist, tableinfo)
		end
	end

	base.skynet_retpack(responsemsg)
end

function TableStatesvrRequest.getgamerooms(request)
	local server = msghelper:get_server()	
	local table_pool = server.table_pool
	local roomsvrs = server.roomsvrs
	local tableinfo = nil
	local game_type_list = {}
	local responsemsg = {
		errcode = EErrCode.ERR_SUCCESS,
		tablestates = {},
	}
	if request.room_type <= 0 then
		responsemsg.errcode = EErrCode.ERR_INVALID_ROOMTYPE
		responsemsg.errcodedes = "无效的场次类型！"
		base.skynet_retpack(responsemsg)
		return
	end
	local room_type = request.room_type
	for roomsvr_id, roomsvr in pairs(roomsvrs) do
		if roomsvr ~= nil and type(roomsvr) == "table" then
			local roomlist = roomsvr[room_type]
			if roomlist ~= nil then
				for gametype, gamelist in pairs(roomlist) do
					for id, _ in pairs(gamelist) do
						if id ~= "num" then
							if game_type_list[gametype] == nil then
								tableinfo = table_pool[id]
                                table.insert(responsemsg.tablestates, tableinfo)
                                tableinfo.totalplayernum = gamelist.num
                                game_type_list[gametype] = id
							else
								local tableid = game_type_list[gametype]
								local tableinfo = table_pool[tableid]
								local tatolnum = tableinfo.totalplayernum
								tableinfo.totalplayernum = tatolnum + gamelist.num
							end
							break
						end
					end
				end
			end
		end
	end

	base.skynet_retpack(responsemsg)
end

--添加快速开始逻辑
function TableStatesvrRequest.quickstart(request)
	local server = msghelper:get_server()
	local table_pool = server.table_pool
	local tableplayernumindexs = server.tableplayernumindexs

	local responsemsg = {
		errcode = EErrCode.ERR_SUCCESS,
	}

	local room_list
	local game_list
	local table_list
	local tableinfo

	room_list = tableplayernumindexs[request.room_type]
	if room_list == nil then
		responsemsg.errcode = EErrCode.ERR_INVALID_ROOMTYPE
		responsemsg.errcodedes = "无效的场次类型！"
		base.skynet_retpack(responsemsg)
		return
	end
	game_list = room_list[request.game_type]
	if game_list == nil then
		responsemsg.errcode = EErrCode.ERR_INVALID_GAMETYPE
		responsemsg.errcodedes = "无效的游戏类型！"
		base.skynet_retpack(responsemsg)
		return
	end
	
	for i=3, 1, -1 do
		table_list = game_list[i]
		for id, _ in pairs(table_list) do
			tableinfo = table_pool[id]
			if tableinfo ~= nil and id ~= request.id and i < tableinfo.max_player_num and tableinfo.distribute_playernum < tableinfo.max_player_num then
				responsemsg.id = tableinfo.id
				responsemsg.roomsvr_id = tableinfo.roomsvr_id
				responsemsg.roomsvr_table_address = tableinfo.roomsvr_table_address 
				tableinfo.distribute_playernum = tableinfo.distribute_playernum + 1			    	
				base.skynet_retpack(responsemsg)
				return	
			end
		end
	end

	table_list = game_list[5]
	for id, _ in pairs(table_list) do
		tableinfo = table_pool[id]
		if tableinfo ~= nil and id ~= request.id then
			responsemsg.id = tableinfo.id
			responsemsg.roomsvr_id = tableinfo.roomsvr_id
			responsemsg.roomsvr_table_address = tableinfo.roomsvr_table_address 
			base.skynet_retpack(responsemsg)
			return
		end 
	end

	responsemsg.errcode = EErrCode.ERR_NO_VALID_TABLE
	responsemsg.errcodedes = "无可用的房间！"
	base.skynet_retpack(responsemsg)
end

return TableStatesvrRequest