local dao = require "dao.datadbdao"
local rechargedbdao = require "dao.rechargedbdao"
local filelog = require "filelog"
local tonumber = tonumber
local timetool = require "timetool"
local tabletool = require "tabletool"
local configdao = require "configdao"
local json = require "cjson"
local base = require "base"

local playerdbinit = nil

json.encode_sparse_array(true,1,1)

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

local PlayerdataDAO = {}

--[[
	返回两个值，第一个表示是否是新建账号 true表示是, false表示否
	第二个值返回查询数据 为nil表示查询失败
]]
function PlayerdataDAO.query_player_info(rid)
	local responsemsg
	local info
	if rid == nil then
		filelog.sys_error("PlayerdataDAO.query_player_info invalid rid")
		return nil, nil
	end
	local requestmsg = {
		rid = rid,
		rediscmd = "hget",
		rediskey = "roleinfo:"..rid,
		--都是可选的使用时一定是按顺序添加
		rediscmdopt1 = "info",

		mysqltable = "role_info",
		mysqlcondition = {
			rid = rid,
		},
		choosedb = 3,
	}

	responsemsg = dao.query(rid, requestmsg)
	if responsemsg == nil then
		filelog.sys_error("PlayerdataDAO.query_player_info failed because cannot access datadbsvrd")
		return nil, nil		
	end

	if not responsemsg.issuccess then
		filelog.sys_error("PlayerdataDAO.query_player_info failed because datadbsvrd exception")		
		return nil, nil
	end

	if (responsemsg.data == nil or tabletool.is_emptytable(responsemsg.data)) 
		and responsemsg.isredisormysql then
		if playerdbinit == nil then
			playerdbinit = configdao.get_business_conf(100, 1000, "playerdbinit")
		end
		info = tabletool.deepcopy(playerdbinit.info)
		info.rid = rid
		--保存数据
		PlayerdataDAO.save_player_info("insert", rid, info)
		return true, info
	elseif responsemsg.isredisormysql then
		responsemsg.data[1].update_time = nil
		PlayerdataDAO.save_player_info("update", rid, responsemsg.data[1])		
		return false, responsemsg.data[1]
	end

	info = json.decode(responsemsg.data)
	info.rid = rid
	return false, info
end

function PlayerdataDAO.save_player_info(cmd, rid, info)
	if cmd == nil or rid == nil or info == nil then
		filelog.sys_error("PlayerdataDAO.save_player_info invalid params")
		return
	end

	local noticemsg = {
		rid = rid,
		rediscmd = "hset",
		rediskey = "roleinfo:"..rid,
		--都是可选的使用时一定是按顺序添加
		rediscmdopt1 = "info",
		rediscmdopt2 = json.encode(info),
		mysqltable = "role_info",
		mysqldata = info,
		mysqlcondition = {
			rid = rid,
		},
		choosedb = 3,
	}

	local f = dao[cmd]
	if f == nil then
		filelog.sys_error("PlayerdataDAO.save_player_info invalid cmd", cmd, info)
		return
	end
	f(rid, noticemsg)
end

--[[
	返回两个值，第一个表示是否是新建账号 true表示是, false表示否
	第二个值返回查询数据 为nil表示查询失败
]]
function PlayerdataDAO.query_player_playgame(rid)
	local responsemsg
	local playgame
	if rid == nil then
		filelog.sys_error("PlayerdataDAO.query_player_playgame invalid rid")
		return nil, nil
	end
	local requestmsg = {
		rid = rid,
		rediscmd = "hget",
		rediskey = "roleinfo:"..rid,
		--都是可选的使用时一定是按顺序添加
		rediscmdopt1 = "playgame",

		mysqltable = "role_playgame",
		mysqlcondition = {
			rid = rid,
		},
		choosedb = 3,
	}

	responsemsg = dao.query(rid, requestmsg)
	if responsemsg == nil then
		filelog.sys_error("PlayerdataDAO.query_player_playgame failed because cannot access datadbsvrd")
		return nil, nil		
	end

	if not responsemsg.issuccess then
		filelog.sys_error("PlayerdataDAO.query_player_playgame failed because datadbsvrd exception")		
		return nil, nil
	end

	if (responsemsg.data == nil or tabletool.is_emptytable(responsemsg.data)) 
		and responsemsg.isredisormysql then
		if playerdbinit == nil then
			playerdbinit = configdao.get_business_conf(100, 1000, "playerdbinit")
		end
		playgame = tabletool.deepcopy(playerdbinit.playgame)
		playgame.rid = rid
		--保存数据
		PlayerdataDAO.save_player_playgame("insert", rid, playgame)
		return true, playgame
	elseif responsemsg.isredisormysql then
		responsemsg.data[1].update_time = nil
		PlayerdataDAO.save_player_playgame("update", rid, responsemsg.data[1])		
		return false, responsemsg.data[1]
	end

	playgame = json.decode(responsemsg.data)
	playgame.rid = rid
	return false, playgame
end

function PlayerdataDAO.save_player_playgame(cmd, rid, playgame)
	if cmd == nil or rid == nil or playgame == nil then
		filelog.sys_error("PlayerdataDAO.save_player_playgame invalid params")
		return
	end

	local noticemsg = {
		rid = rid,
		rediscmd = "hset",
		rediskey = "roleinfo:"..rid,
		--都是可选的使用时一定是按顺序添加
		rediscmdopt1 = "playgame",
		rediscmdopt2 = json.encode(playgame),
		mysqltable = "role_playgame",
		mysqldata = playgame,
		mysqlcondition = {
			rid = rid,
		},
		choosedb = 3,
	}

	local f = dao[cmd]
	if f == nil then
		filelog.sys_error("PlayerdataDAO.save_player_playgame invalid cmd", cmd, playgame)
		return
	end
	f(rid, noticemsg)
end

--[[
	返回两个值，第一个表示是否是新建账号 true表示是, false表示否
	第二个值返回查询数据 为nil表示查询失败
]]
function PlayerdataDAO.query_player_online(rid)
	local responsemsg
	local online
	if rid == nil then
		filelog.sys_error("PlayerdataDAO.query_player_online invalid rid")
		return nil, nil
	end
	local requestmsg = {
		rid = rid,
		rediscmd = "hget",
		rediskey = "roleinfo:"..rid,
		--都是可选的使用时一定是按顺序添加
		rediscmdopt1 = "online",

		mysqltable = "role_online",
		mysqlcondition = {
			rid = rid,
		},
		choosedb = 3,
	}

	responsemsg = dao.query(rid, requestmsg)
	if responsemsg == nil then
		filelog.sys_error("PlayerdataDAO.query_player_online failed because cannot access datadbsvrd")
		return nil, nil		
	end

	if not responsemsg.issuccess then
		filelog.sys_error("PlayerdataDAO.query_player_online failed because datadbsvrd exception")		
		return nil, nil
	end

	if (responsemsg.data == nil or tabletool.is_emptytable(responsemsg.data)) 
		and responsemsg.isredisormysql then
		if playerdbinit == nil then
			playerdbinit = configdao.get_business_conf(100, 1000, "playerdbinit")
		end
		online = tabletool.deepcopy(playerdbinit.online)
		online.rid = rid
		--保存数据
		PlayerdataDAO.save_player_online("insert", rid, online)
		return true, online
	elseif responsemsg.isredisormysql then
		responsemsg.data[1].update_time = nil
		PlayerdataDAO.save_player_online("update", rid, responsemsg.data[1])		
		return false, responsemsg.data[1]
	end

	online = json.decode(responsemsg.data)
	online.rid = rid
	return false, online
end

function PlayerdataDAO.save_player_online(cmd, rid, online)
	if cmd == nil or rid == nil or online == nil then
		filelog.sys_error("PlayerdataDAO.save_player_online invalid params")
		return
	end

	local noticemsg = {
		rid = rid,
		rediscmd = "hset",
		rediskey = "roleinfo:"..rid,
		--都是可选的使用时一定是按顺序添加
		rediscmdopt1 = "online",
		rediscmdopt2 = json.encode(online),
		mysqltable = "role_online",
		mysqldata = online,
		mysqlcondition = {
			rid = rid,
		},
		choosedb = 3,
	}

	local f = dao[cmd]
	if f == nil then
		filelog.sys_error("PlayerdataDAO.save_player_online invalid cmd", cmd, online)
		return
	end
	f(rid, noticemsg)
end

--[[
	返回两个值，第一个表示是否是新建账号 true表示是, false表示否
	第二个值返回查询数据 为nil表示查询失败
]]
function PlayerdataDAO.query_player_money(rid)
	local responsemsg
	local money

	if rid == nil then
		filelog.sys_error("PlayerdataDAO.query_player_money invalid rid")
		return nil, nil
	end
	local requestmsg = {
		rid = rid,
		rediscmd = "hget",
		rediskey = "roleinfo:"..rid,
		--都是可选的使用时一定是按顺序添加
		rediscmdopt1 = "money",

		mysqltable = "role_money",
		mysqlcondition = {
			rid = rid,
		},
		choosedb = 3,
	}

	responsemsg = dao.query(rid, requestmsg)
	if responsemsg == nil then
		filelog.sys_error("PlayerdataDAO.query_player_money failed because cannot access datadbsvrd")
		return nil, nil		
	end

	if not responsemsg.issuccess then
		filelog.sys_error("PlayerdataDAO.query_player_money failed because datadbsvrd exception")		
		return nil, nil
	end

	if (responsemsg.data == nil or tabletool.is_emptytable(responsemsg.data)) 
		and responsemsg.isredisormysql then
		if playerdbinit == nil then
			playerdbinit = configdao.get_business_conf(100, 1000, "playerdbinit")
		end
		money = tabletool.deepcopy(playerdbinit.money)
		money.rid = rid
		--保存数据
		PlayerdataDAO.save_player_money("insert", rid, money)
		return true, money
	elseif responsemsg.isredisormysql then
		responsemsg.data[1].update_time = nil
		PlayerdataDAO.save_player_money("update", rid, responsemsg.data[1])		
		return false, responsemsg.data[1]
	end

	money = json.decode(responsemsg.data)
	money.rid = rid
	return false, money
end

function PlayerdataDAO.save_player_money(cmd, rid, money)
	if cmd == nil or rid == nil or money == nil then
		filelog.sys_error("PlayerdataDAO.save_player_money invalid params")
		return
	end

	local noticemsg = {
		rid = rid,
		rediscmd = "hset",
		rediskey = "roleinfo:"..rid,
		--都是可选的使用时一定是按顺序添加
		rediscmdopt1 = "money",
		rediscmdopt2 = json.encode(money),
		mysqltable = "role_money",
		mysqldata = money,
		mysqlcondition = {
			rid = rid,
		},
		choosedb = 3,
	}

	local f = dao[cmd]
	if f == nil then
		filelog.sys_error("PlayerdataDAO.save_player_money invalid cmd", cmd, money)
		return
	end
	f(rid, noticemsg)
end

function PlayerdataDAO.query_player_tablerecords(rid, condition)
	local responsemsg
	local tablerecords = {}
	if rid == nil then
		filelog.sys_error("PlayerdataDAO.query_player_tablerecords invalid rid")
		return nil, nil
	end
	local requestmsg = {
		rid = rid,
		---rediscmd = "hvals",
		---rediskey = "tablerecords:"..rid,
		--都是可选的使用时一定是按顺序添加
		---rediscmdopt1 = "tablerecords",

		mysqltable = "role_tablerecords",
		mysqlcondition = nil,
		choosedb = 2,
	}
	if condition and type(condition) == "string" then
		requestmsg.mysqlcondition = condition
	else
		requestmsg.mysqlcondition = { rid = rid}
	end
	responsemsg = dao.query(rid, requestmsg)
	if responsemsg == nil then
		filelog.sys_error("PlayerdataDAO.query_player_tablerecords failed because cannot access datadbsvrd")
		return nil, nil		
	end

	if not responsemsg.issuccess then
		filelog.sys_error("PlayerdataDAO.query_player_tablerecords failed because datadbsvrd exception")		
		return nil, nil
	end

	if (responsemsg.data == nil or tabletool.is_emptytable(responsemsg.data)) 
		and responsemsg.isredisormysql then
		return true, tablerecords
	elseif responsemsg.isredisormysql then
		responsemsg.data[1].update_time = nil
		PlayerdataDAO.save_player_tablerecords("update", rid, responsemsg.data[1])		
		return false, responsemsg.data
	end
	return false, responsemsg.data
end


function PlayerdataDAO.save_player_tablerecords(cmd, rid, tablerecords)
	if cmd == nil or rid == nil or tablerecords == nil then
		filelog.sys_error("PlayerdataDAO.save_player_tablerecords invalid params")
		return
	end
	if type(tablerecords.record) == "table" then
		local jsonstring = json.encode(tablerecords.record)
		tablerecords.record = jsonstring
	end	

	local noticemsg = {
		rid = rid,
		--rediscmd = "hset",
		--rediskey = "tablerecords:"..rid,
		--都是可选的使用时一定是按顺序添加
		--rediscmdopt1 = ""..tablerecords.id,
		--rediscmdopt2 = json.encode(tablerecords),
		mysqltable = "role_tablerecords",
		mysqldata = tablerecords,
		mysqlcondition = {
			rid = rid,
		},
		choosedb = 2,
	}

	local f = dao[cmd]
	if f == nil then
		filelog.sys_error("PlayerdataDAO.save_player_tablerecords invalid cmd", cmd, money)
		return
	end
	f(rid, noticemsg)
end


function PlayerdataDAO.query_player_mail(rid,condition)
	local responsemsg
	local mails = {}
	if rid == nil then
		filelog.sys_error("PlayerdataDAO.query_player_mail invalid rid")
		return nil, nil
	end
	local requestmsg = {
		rid = rid,
		---rediscmd = "",
		mysqltable = "role_mailinfos",
		mysqlcondition = nil,
		choosedb = 2,
	}
	if condition and type(condition) == "string" then
		requestmsg.mysqlcondition = condition
	else
		requestmsg.mysqlcondition = { rid = rid}
	end

	responsemsg = dao.query(rid, requestmsg)
	if responsemsg == nil then
		filelog.sys_error("PlayerdataDAO.query_player_mail failed because cannot access datadbsvrd")
		return nil, nil		
	end

	if not responsemsg.issuccess then
		filelog.sys_error("PlayerdataDAO.query_player_mail failed because datadbsvrd exception")		
		return nil, nil
	end
	if (responsemsg.data == nil or tabletool.is_emptytable(responsemsg.data)) 
		and responsemsg.isredisormysql then
		return true, mails
	end
	return false, responsemsg.data
end


function PlayerdataDAO.save_player_mail(cmd, rid, mail, condition)
	if cmd == nil or rid == nil or (mail == nil and cmd ~= "delete") then
		filelog.sys_error("PlayerdataDAO.save_player_mail invalid params")
		return
	end
	if mail and type(mail.content) == "table" then
		mail.content = json.encode(mail.content)
	end

	-- body
	local noticemsg = {
		rid = rid,
		--rediscmd = "",
		mysqltable = "role_mailinfos",
		mysqldata = mail,
		mysqlcondition = nil,
		choosedb = 2,
	}

	if condition and type(condition) == "string" then
		noticemsg.mysqlcondition = condition
	else
		noticemsg.mysqlcondition = { rid = rid}
	end
	
	local f = dao[cmd]
	if f == nil then
		filelog.sys_error("PlayerdataDAO.save_player_mail invalid cmd", cmd, mail)
		return
	end
	f(rid, noticemsg)
end

function PlayerdataDAO.query_player_iosbatchs(rid,condition)
	local responsemsg
	local iosbatchs = {}
	if rid == nil then
		filelog.sys_error("PlayerdataDAO.query_player_iosbatchs invalid rid")
		return nil, nil
	end
	local requestmsg = {
		rid = rid,
		---rediscmd = "",
		mysqltable = "role_iosbatchs",
		mysqlcondition = nil,
		choosedb = 2,
	}
	if condition and type(condition) == "string" then
		requestmsg.mysqlcondition = condition
	else
		requestmsg.mysqlcondition = { rid = rid}
	end

	responsemsg = dao.query(rid, requestmsg)
	if responsemsg == nil then
		filelog.sys_error("PlayerdataDAO.query_player_iosbatchs failed because cannot access datadbsvrd")
		return nil, nil		
	end

	if not responsemsg.issuccess then
		filelog.sys_error("PlayerdataDAO.query_player_iosbatchs failed because datadbsvrd exception")		
		return nil, nil
	end
	if (responsemsg.data == nil or tabletool.is_emptytable(responsemsg.data)) 
		and responsemsg.isredisormysql then
		return true, iosbatchs
	end
	if type(responsemsg.data) == "table" then
		for _,v in ipairs(responsemsg.data) do
			table.insert(iosbatchs,v)
		end
	end
	return false, iosbatchs
end


function PlayerdataDAO.save_player_iosbatch(cmd, rid, iosbatch, condition)
	if cmd == nil or rid == nil or (iosbatch == nil and cmd ~= "delete") then
		filelog.sys_error("PlayerdataDAO.save_player_iosbatch invalid params")
		return
	end

	-- body
	local noticemsg = {
		rid = rid,
		--rediscmd = "",
		mysqltable = "role_iosbatchs",
		mysqldata = iosbatch,
		mysqlcondition = nil,
		choosedb = 2,
	}

	if condition and type(condition) == "string" then
		noticemsg.mysqlcondition = condition
	else
		noticemsg.mysqlcondition = { rid = rid}
	end
	
	local f = dao[cmd]
	if f == nil then
		filelog.sys_error("PlayerdataDAO.save_player_iosbatch invalid cmd", cmd, iosbatch)
		return
	end
	f(rid, noticemsg)
end

function PlayerdataDAO.query_player_order(rid, order_id)
	local responsemsg
	if rid == nil or order_id == nil then
		filelog.sys_error("PlayerdataDAO.query_player_order invalid rid or order_id")
		return nil, nil
	end
	local requestmsg = {
		order_id = order_id,
		---rediscmd = "",
		mysqltable = "role_orders",
		mysqlcondition = {
			rid = rid,
			order_id = order_id,
		},
		choosedb = 2,
	}

	responsemsg = rechargedbdao.query(requestmsg.order_id, requestmsg)
	if responsemsg == nil then
		filelog.sys_error("PlayerdataDAO.query_player_order failed because cannot access rechargedbsvrd")
		return nil, nil		
	end

	if not responsemsg.issuccess then
		filelog.sys_error("PlayerdataDAO.query_player_order failed because rechargedbsvrd exception")		
		return nil, nil
	end
	if (responsemsg.data == nil or tabletool.is_emptytable(responsemsg.data)) 
		and responsemsg.isredisormysql then
		return true, nil
	end

	return false, responsemsg.data[1]
end

function PlayerdataDAO.query_player_orders(rid)
	local responsemsg
	local orders = {}
	if rid == nil then
		filelog.sys_error("PlayerdataDAO.query_player_orders invalid rid")
		return nil, nil
	end
	local requestmsg = {
		order_id = "orders",
		---rediscmd = "",
		mysqltable = "role_orders",
		mysqlcondition = {
			rid = rid,
		},
		choosedb = 2,
	}

	responsemsg = rechargedbdao.query(requestmsg.order_id, requestmsg)
	if responsemsg == nil then
		filelog.sys_error("PlayerdataDAO.query_player_orders failed because cannot access rechargedbsvrd")
		return nil, nil		
	end

	if not responsemsg.issuccess then
		filelog.sys_error("PlayerdataDAO.query_player_orders failed because rechargedbsvrd exception")		
		return nil, nil
	end
	if (responsemsg.data == nil or tabletool.is_emptytable(responsemsg.data)) 
		and responsemsg.isredisormysql then
		return true, orders
	end
	if type(responsemsg.data) == "table" then
		for _,v in ipairs(responsemsg.data) do
			table.insert(orders,v)
		end
	end
	return false, orders
end

function PlayerdataDAO.save_player_order(cmd, rid, order, condition)
	if cmd == nil or rid == nil or (order == nil and cmd ~= "delete") then
		filelog.sys_error("PlayerdataDAO.save_player_order invalid params")
		return false
	end

	-- body
	local noticemsg = {
		order_id = order.order_id,
		--rediscmd = "",
		mysqltable = "role_orders",
		mysqldata = order,
		mysqlcondition = nil,
		choosedb = 2,
	}

	if condition and type(condition) == "string" then
		noticemsg.mysqlcondition = condition
	else
		noticemsg.mysqlcondition = { rid = rid}
	end
	
	local f = rechargedbdao[cmd]
	if f == nil then
		filelog.sys_error("PlayerdataDAO.save_player_order invalid cmd", cmd, order)
		return false
	end
	if cmd == "sync_insert" then
		local responsemsg = f(order.order_id, noticemsg)
		return responsemsg.issuccess
	end

	if cmd == "sync_update" then
		local responsemsg = f(order.order_id, noticemsg)
		return responsemsg.issuccess
	end
	f(order.order_id, noticemsg)
end

return PlayerdataDAO