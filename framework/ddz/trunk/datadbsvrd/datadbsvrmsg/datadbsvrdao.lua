local filelog = require "filelog"
local skynet = require "skynet"
local redisdao = require "dao.redisdao"
local msghelper = require "datadbsvrhelper"
local mysqldao = require "dao.mysqldao"
local base = require "base"
local tabletool = require "tabletool"

local DatadbsvrDao = {}

function DatadbsvrDao.process(session, source, event, ...)
	local f = DatadbsvrDao[event] 
	if f == nil then
		filelog.sys_error(filename.."Datadbsvrd DatadbsvrDao.process invalid event:"..event)
		return nil
	end
	f(...)
end

--[[
	request {
		rid,	   玩家的角色id
		rediscmd,  redis操作命令
		rediskey,  redis数据key
		--都是可选的使用时一定是按顺序添加
		rediscmdopt1, redis命令选项1
		rediscmdopt2, redis命令选项2
		rediscmdopt3,
		rediscmdopt4,
		rediscmdopt5,

		mysqltable,  mysql数据表名
		mysqldata, mysqldata表示存入mysql的数据, 一定是table
		mysqlcondition, 是一个表格或是字符串（字符串表示完整sql语句）

		choosedb, 1 表示redis， 2表示mysql，3表示redis+mysql
	}

	response {
		issuccess, 表示成功或失败
		isredisormysql, true表示返回的是mysql数据 false表示是redis数据（业务层可能要进行不同的处理）
		data, 返回的数据
	}
]]

local function get_redis_cmds(request)
	if request.rediscmd == nil 
		or request.rediskey == nil then
		return ""
	end

	if  request.rediscmdopt5 ~= nil then
		return request.rediscmd, request.rediskey, request.rediscmdopt1, request.rediscmdopt2, request.rediscmdopt3, request.rediscmdopt4, request.rediscmdopt5 
	end

	if request.rediscmdopt4 ~= nil then
		return request.rediscmd, request.rediskey, request.rediscmdopt1, request.rediscmdopt2, request.rediscmdopt3, request.rediscmdopt4 		
	end

	if request.rediscmdopt3 ~= nil then
		return request.rediscmd, request.rediskey, request.rediscmdopt1, request.rediscmdopt2, request.rediscmdopt3 		
	end

	if request.rediscmdopt2 ~= nil then
		return request.rediscmd, request.rediskey, request.rediscmdopt1, request.rediscmdopt2 				
	end

	if request.rediscmdopt1 ~= nil then
		return request.rediscmd, request.rediskey, request.rediscmdopt1 				
	end

	return request.rediscmd, request.rediskey
end

function DatadbsvrDao.query(request)
	local response = {issuccess = true}
	local status, data
	if request.choosedb == 1 then
		status, data = redisdao.query_data(msghelper:get_redissvrid_byrid(request.rid), get_redis_cmds(request))
		response.isredisormysql = false
		if not status then
			filelog.sys_error("DatadbsvrDao.query redisdao.query_data failed", data)
			response.issuccess = false
			base.skynet_retpack(response)
			return
		end

		response.data = data
		base.skynet_retpack(response)	
		return
	end

	if request.choosedb == 2 then
		if type(request.mysqlcondition) == "table" then
			status, data = mysqldao.select(msghelper:get_mysqlsvrid_byrid(request.rid), request.mysqltable, request.mysqlcondition)
		else
			status, data = mysqldao.query(msghelper:get_mysqlsvrid_byrid(request.rid), request.mysqlcondition)
		end
		response.isredisormysql = true
		if not status then
			filelog.sys_error("DatadbsvrDao.query mysqldao.select failed", data)
			response.issuccess = false
			base.skynet_retpack(response)
			return			
		end

		if tabletool.is_emptytable(data) then
			data = nil
		end		
		response.data = data
		base.skynet_retpack(response)	
		return
	end


	status, data = redisdao.query_data(msghelper:get_redissvrid_byrid(request.rid), get_redis_cmds(request))
	response.isredisormysql = false
	if not status then
		filelog.sys_error("DatadbsvrDao.query redisdao.query_data failed", data)
		response.issuccess = false
		base.skynet_retpack(response)
		return
	end
	if data == nil 
		or (type(data) == "table" and tabletool.is_emptytable(data)) then
		--说明缓存中没有
		if type(request.mysqlcondition) == "table" then
			status, data = mysqldao.select(msghelper:get_mysqlsvrid_byrid(request.rid), request.mysqltable, request.mysqlcondition)
		else
			status, data = mysqldao.query(msghelper:get_mysqlsvrid_byrid(request.rid), request.mysqlcondition)
		end
		response.isredisormysql = true
		if not status then
			filelog.sys_error("DatadbsvrDao.query mysqldao.select failed", data)
			response.issuccess = false
			base.skynet_retpack(response)
			return			
		end

		if tabletool.is_emptytable(data) then
			data = nil
		end		
	end

	response.data = data
	base.skynet_retpack(response)	
end

function DatadbsvrDao.update(request)
	if request.choosedb == 1 then
		redisdao.save_data(msghelper:get_redissvrid_byrid(request.rid), get_redis_cmds(request))
		return
	end

	if request.choosedb == 2 then
		mysqldao.update(msghelper:get_mysqlsvrid_byrid(request.rid), request.mysqltable, request.mysqlcondition, request.mysqldata)
		return
	end

	if request.choosedb == 3 then
		redisdao.save_data(msghelper:get_redissvrid_byrid(request.rid), get_redis_cmds(request))
		mysqldao.update(msghelper:get_mysqlsvrid_byrid(request.rid), request.mysqltable, request.mysqlcondition, request.mysqldata)
		return
	end
end

function DatadbsvrDao.delete(request)
	if request.choosedb == 1 then
		redisdao.save_data(msghelper:get_redissvrid_byrid(request.rid), get_redis_cmds(request))
		return
	end

	if request.choosedb == 2 then
		mysqldao.delete(msghelper:get_mysqlsvrid_byrid(request.rid), request.mysqltable, request.mysqlcondition)
		return
	end

	if request.choosedb == 3 then
		redisdao.save_data(msghelper:get_redissvrid_byrid(request.rid), get_redis_cmds(request))
		mysqldao.delete(msghelper:get_mysqlsvrid_byrid(request.rid), request.mysqltable, request.mysqlcondition)
	end
end

function DatadbsvrDao.insert(request)
	if request.choosedb == 1 then
		redisdao.save_data(msghelper:get_redissvrid_byrid(request.rid), get_redis_cmds(request))	
		return
	end
	
	if request.choosedb == 2 then
		mysqldao.insert(msghelper:get_mysqlsvrid_byrid(request.rid), request.mysqltable, request.mysqlcondition, request.mysqldata)
		return
	end

	if request.choosedb == 3 then
		redisdao.save_data(msghelper:get_redissvrid_byrid(request.rid), get_redis_cmds(request))			
		mysqldao.insert(msghelper:get_mysqlsvrid_byrid(request.rid), request.mysqltable, request.mysqlcondition, request.mysqldata)
		return
	end
end

function DatadbsvrDao.insert(request)
	if request.choosedb == 1 then
		redisdao.save_data(msghelper:get_redissvrid_byrid(request.rid), get_redis_cmds(request))	
		return
	end
	
	if request.choosedb == 2 then
		mysqldao.insert(msghelper:get_mysqlsvrid_byrid(request.rid), request.mysqltable, request.mysqlcondition, request.mysqldata)
		return
	end

	if request.choosedb == 3 then
		redisdao.save_data(msghelper:get_redissvrid_byrid(request.rid), get_redis_cmds(request))			
		mysqldao.insert(msghelper:get_mysqlsvrid_byrid(request.rid), request.mysqltable, request.mysqlcondition, request.mysqldata)
		return
	end
end

function DatadbsvrDao.sync_insert(request)
	local response = {issuccess = true}
	local status, data
	if request.choosedb == 1 then
		status, data = redisdao.sync_save_data(msghelper:get_redissvrid_byrid(request.rid), get_redis_cmds(request))
		response.isredisormysql = false
		if not status then
			filelog.sys_error("DatadbsvrDao.sync_insert redisdao.sync_save_data failed", data)
			response.issuccess = false
			base.skynet_retpack(response)
			return
		end

		response.data = data
		base.skynet_retpack(response)	
		return
	end
	
	if request.choosedb == 2 then
		response.isredisormysql = true
		status, data = mysqldao.sync_insert(msghelper:get_mysqlsvrid_byrid(request.rid), request.mysqltable, request.mysqlcondition, request.mysqldata)
		if not status then
			filelog.sys_error("DatadbsvrDao.sync_insert mysqldao.sync_insert failed", data)
			response.issuccess = false
			base.skynet_retpack(response)
			return
		end

		response.data = data
		base.skynet_retpack(response)	
		return
	end

	if request.choosedb == 3 then
		status, data = redisdao.sync_save_data(msghelper:get_redissvrid_byrid(request.rid), get_redis_cmds(request))
		response.isredisormysql = false
		if not status then
			filelog.sys_error("DatadbsvrDao.sync_insert redisdao.sync_save_data failed", data)
			response.issuccess = false
			base.skynet_retpack(response)
			return
		end

		status, data = mysqldao.sync_insert(msghelper:get_mysqlsvrid_byrid(request.rid), request.mysqltable, request.mysqlcondition, request.mysqldata)
		response.isredisormysql = true
		if not status then
			filelog.sys_error("DatadbsvrDao.sync_insert mysqldao.sync_insert failed", data)
			response.issuccess = false
			base.skynet_retpack(response)
			return
		end
		response.data = data
		base.skynet_retpack(status, data)
		return
	end
end


return DatadbsvrDao