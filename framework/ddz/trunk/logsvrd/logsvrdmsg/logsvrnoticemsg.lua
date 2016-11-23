local skynet = require "skynet"
local filelog = require "filelog"
local filename = "logsvrnoticemsg.lua"
local msghelper = require "logsvrmsghelper"
local configdao = require "configdao"
local tinsert = table.insert
local tconcat = table.concat
local next = next
local pairs = pairs
local tostring = tostring
local srep = string.rep
local type = type
local base = require "base"

local LogsvrNoticeMsg = {}

local function tabletostring(table)
	local cache = {  [table] = "." }
	local function _dump(t,space,name)
		local temp = {}
		for k,v in pairs(t) do
			local key = tostring(k)
			if cache[v] then
				tinsert(temp,"" .. key .. " {" .. cache[v].."}")
			elseif type(v) == "table" then
				local new_key = name .. "." .. key
				cache[v] = new_key
				tinsert(temp,"" .. key .. _dump(v,space .. (next(t,k) and "|" or " " ).. srep(" ",#key),new_key))
			else
				tinsert(temp,"## " .. key .. "=" .. tostring(v).."")
			end
		end
		return tconcat(temp," "..space)
	end
	return _dump(table, "","")
end

function LogsvrNoticeMsg.process(session, source, event, ...)
	local f = LogsvrNoticeMsg[event]
	if f == nil then
		filelog.sys_error(filename.." LogsvrNoticeMsg.process invalid event:"..event)
		return nil
	end
	f(...)
end

function LogsvrNoticeMsg.addlogtologsvr(loggerkind,message)
    local messagestring = ""
    if type(message) == "table" then
    	messagestring = messagestring .. tabletostring(message)
    else
    	return
    end
    local server = msghelper:get_server()
   	local logscfg = configdao.get_common_conf("logscfg")
   	for key,value in pairs(logscfg) do
   		if value.logsname == loggerkind then
   			local randomserverid = base.get_random(value.begin_id+1,value.begin_id+value.num)
   			if server.logger_pool[randomserverid] then
   				local result = skynet.call(server.logger_pool[randomserverid], "lua", "cmd", "addlog", messagestring)
   				break
			end
   		end
   	end
end


return LogsvrNoticeMsg