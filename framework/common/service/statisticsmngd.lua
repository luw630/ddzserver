local skynet = require "skynet"
local base = require "base"
require "skynet.manager"
local filelog = require "filelog"
local timetool = require "timetool"

local svr_id=".statistics" 

local funcstat = {}
local msgstat = {}

local lastfunctime = timetool.get_time()
local lastmsgtime = timetool.get_time()

local CMD = {}

function CMD.init(conf)
	
end

function CMD.reload(conf)

end

function CMD.func(stat)
	local data
 	for key, value in pairs(stat) do
 		data = funcstat[key]
 		if data == nil then
 			funcstat[key] = value
 		else
 			data.n = data.n + value.n
 			data.time = data.time + value.time
 		end
 	end

 	local now_time = timetool.get_time()
 	if lastfunctime+300 > now_time then
 		filelog.sys_obj("statics", "funcstat", funcstat)
 		lastfunctime = now_time
 		funcstat = nil
 		funcstat = {}
 	end 
end

function CMD.mqlen(stat)
 	filelog.sys_obj("statics", "mqlenstat", stat)
end 

function CMD.msg(stat)
	local data
 	for key, value in pairs(stat) do
 		data = msgstat[key]
 		if data == nil then
 			msgstat[key] = value
 		else
 			data.n = data.n + value.n
 			data.time = data.time + value.time
 			if data.maxtime < value.maxtime then
 				data.maxtime = value.maxtime
 			end 	
 		end
 	end

 	local now_time = timetool.get_time()
 	if lastmsgtime+300 > now_time then
 		filelog.sys_obj("statics", "msgstat", msgstat)
 		lastmsgtime = now_time
 		msgstat = nil
 		msgstat = {}
 	end 
end

function CMD.exit(...)
    skynet.exit()
end

skynet.dispatch("lua", function(_, address,  cmd, ...)
	    local f = CMD[cmd]
	    if cmd == "init" then
	    	skynet.retpack(f(...))
	    	return
	    end

		if f ~= nil then			
			f(...)
        end
end)

skynet.start(function()
    skynet.register(svr_id)
end)

