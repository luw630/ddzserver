local filelog = require "filelog"
local msghelper = require "tablehelper"
local logicmng = require "logicmng"
local filename = "tablenotice.lua"
require "enum"
local TableNotice = {}

function TableNotice.process(session, source, event, ...)
	local f = TableNotice[event] 
	if f == nil then
		filelog.sys_error(filename.." TableNotice.process invalid event:"..event)
		return nil
	end
	f(...)
end

function TableNotice.get_roomsvr_state( ... )
	msghelper:report_table_state()
end

function TableNotice.update_money(rid, update_table)
	local server = msghelper:get_server()
	local table_data = server.table_data
	local roomtablelogic = logicmng.get_logicbyname("roomtablelogic")
	local seat = roomtablelogic.get_seat_by_rid(table_data,rid)
	local waitplayer = table_data.waits[rid]
	if (seat == nil or waitplayer == nil) or (seat ~= nil or waitplayer ~= nil )then
		return
	end
	if seat ~= nil then
		for _, value in pairs(update_table) do
			if value.id == ECurrencyType.CURRENCY_TYPE_COIN then
				seat.playerinfo.coins = seat.playerinfo.coins + value.num
			elseif value.id == ECurrencyType.CURRENCY_TYPE_DIAMOND then
				seat.playerinfo.diamonds = seat.playerinfo.diamonds + value.num
			end
		end
	end


end


return TableNotice