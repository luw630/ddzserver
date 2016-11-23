local msgproxy = require "msgproxy"
--[[
	主要用于记录全局数据

	key作为每条记录的关键索引，其他需要使用者自己设计
]]
--[[
	request/notice {
		order_id,	   订单id
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

local RechargedbDao = {}

--key 必须是字符串或数字
function RechargedbDao.update(order_id,  noticemsg)
	msgproxy.sendrpc_noticemsgto_rechargedbsvrd(order_id, "dao", "update", noticemsg)
end

function RechargedbDao.sync_update(order_id, noticemsg)
	return msgproxy.sendrpc_reqmsgto_rechargedbsvrd(order_id, "dao", "sync_update", noticemsg)
end

function RechargedbDao.insert(order_id,  noticemsg)
	msgproxy.sendrpc_noticemsgto_rechargedbsvrd(order_id, "dao", "insert", noticemsg)
end

function RechargedbDao.sync_insert(order_id, noticemsg)
	return msgproxy.sendrpc_reqmsgto_rechargedbsvrd(order_id, "dao", "sync_insert", noticemsg)
end

function RechargedbDao.delete(order_id,  noticemsg)
	msgproxy.sendrpc_noticemsgto_rechargedbsvrd(order_id, "dao", "delete", noticemsg)
end

function RechargedbDao.query(order_id, requestmsg)
	return msgproxy.sendrpc_reqmsgto_rechargedbsvrd(order_id, "dao", "query", requestmsg)
end

return RechargedbDao