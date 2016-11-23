local skynet = require "skynet"
local filelog = require "filelog"
local helperbase = require "helperbase"
local msgproxy = require "msgproxy"
local servicepoolmng = require "incrservicepoolmng"
local timetool = require "timetool"
local configdao = require "configdao"
local math = math
local string = string

local filename = "roomsvrhelper.lua"
local roomtablecfg = nil
local RoomsvrHelper = helperbase:new({})

function RoomsvrHelper:start_time_tick()
	skynet.fork(function()
		while true do
			skynet.sleep(3000)
			--发送心跳包
			msgproxy.sendrpc_broadcastmsgto_tablesvrd("heart", skynet.getenv("svr_id"))
		end
	end)	
end

function RoomsvrHelper:set_idle_table_pool(conf)
	self.server.idle_table_mng = servicepoolmng:new({}, {service_name="table", service_size=conf.tablesize, incr=conf.tableinrc})
end

function RoomsvrHelper:generate_create_table_id()
	local code = string.match(skynet.getenv("svr_id"), "%a*_(%d+)")
	math.randomseed(timetool.get_time())
	while true do		
		for i = 1, 5 do
			code = code..(math.random(0, 9))
		end
		if self.server.create_table_ids[code] == nil then
			break
		end
		code = string.match(skynet.getenv("svr_id"), "%a*_(%d+)")
	end
	return code
end

function RoomsvrHelper:delete_table(id)
	local tableinfo = self.server.used_table_pool[id]
	if tableinfo ~= nil then
		if tableinfo.create_table_id ~= nil then
			self.server.create_table_ids[tableinfo.create_table_id] = nil
		end
		self.server.used_table_pool[id] = nil
	end
end

function RoomsvrHelper:create_friend_table(conf)
	local tableservice = self.server.idle_table_mng:create_service()
	local create_table_id
	local tableinfo
	if tableservice ~= nil then
		--生成随机码
		create_table_id = self:generate_create_table_id()

		self.server.used_table_pool[self.server.friend_table_id] = {}
		tableinfo = self.server.used_table_pool[self.server.friend_table_id]
		tableinfo.table_service = tableservice.service
		tableinfo.isdelete = false
		tableinfo.table_service_id = tableservice.id
		tableinfo.create_table_id = create_table_id

		conf.create_table_id = create_table_id
		conf.create_time = timetool.get_time()
		conf.id = self.server.friend_table_id
		local result = skynet.call(tableinfo.table_service, "lua", "cmd", "start", conf, skynet.getenv("svr_id"))
		if not result then
			filelog.sys_error("RoomsvrHelper:create_friend_table(:"..self.server.friend_table_id..") failed")
			pcall(skynet.kill, tableinfo.table_service)
			self.server.used_table_pool[self.server.friend_table_id] = nil
			return false, create_table_id

		end
		self.server.friend_table_id = self.server.friend_table_id + 1
		self.server.create_table_ids[create_table_id] = true	
	else
		filelog.sys_error("RoomsvrHelper:create_friend_table roomsvr's idle_table_mng not enough tableservice!")
		return false, create_table_id
	end
	return true, create_table_id
end

function RoomsvrHelper:loadroomtablecfg()
	if roomtablecfg == nil then
		roomtablecfg = configdao.get_business_conf(100, 1000, "roomtablecfg")
	end
	if roomtablecfg == nil then
		filelog.sys_error("RoomsvrHelper:loadroomtablecfg get cfg failed")
		return false
	end
	local used_table_pool = self.server.used_table_pool

	for id, tableitem in pairs(used_table_pool) do
		if id < 100000 then
			tableitem.isdelete = true
		else
			tableitem.isdelete = false
		end
	end

	local count = 0
	local begin_id = 0
	for _, table_conf_list in pairs(roomtablecfg) do
		count = 1
		begin_id = table_conf_list.begin_id
		while count <= table_conf_list.num do
			if used_table_pool[begin_id] == nil then
				--创建新的
				local tableservice = self.server.idle_table_mng:create_service()
				if tableservice ~= nil then
					used_table_pool[begin_id] = {}
					used_table_pool[begin_id].table_service = tableservice.service
					used_table_pool[begin_id].table_service_id = tableservice.id
					used_table_pool[begin_id].isdelete = false
					local result = skynet.call(tableservice.service, "lua", "cmd", "start", table_conf_list.conf, skynet.getenv("svr_id"), begin_id)
					if not result then
						filelog.sys_error("roomsvrd create table(:"..begin_id..") failed")
						used_table_pool[begin_id] = nil
					end 
				else
					filelog.sys_error("roomsvrd idle_table_mng not enough tableservice!")
				end
			else
				--通知桌子更新配置
				used_table_pool[begin_id].isdelete = false
				skynet.send(used_table_pool[begin_id].table_service, "lua", "cmd", "reload", table_conf_list.conf)
			end
			begin_id = begin_id + 1
			count = count + 1
		end

	end

	--通知删除桌子
	for id, tableitem in pairs(used_table_pool) do
		if tableitem.isdelete then
			pcall(skynet.send, tableitem.table_service, "lua", "cmd", "delete")
		end
	end
	return true
end



return	RoomsvrHelper 