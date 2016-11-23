local skynet = require "skynet"
local filelog = require "filelog"
local configdao = require "configdao"
local playerdatadao = require "playerdatadao"
local msgproxy = require "msgproxy"
local tabletool = require "tabletool"
local timetool = require "timetool"
local gamelog = require "gamelog"
local filename = "rechargesvrrequest.lua"
local base = require "base"
local json = require "cjson"
require "enum"

json.encode_sparse_array(true, 1, 1)

local RechargesvrRequest = {}

local count = 1

function RechargesvrRequest.process(session, source, event, ...)
	local f = RechargesvrRequest[event] 
	if f == nil then
		filelog.sys_error(filename.." RechargesvrRequest.process invalid event:"..event)
		base.skynet_retpack(nil)
		return nil
	end
	f(...)	 
end

--[[
// 请求充值
message RechargeReq {
	optional Version version = 1;
	optional int32 good_id = 2;        //商品id
	optional int32 pay_type = 3;       //支付类型
	optional string option_data = 4;   //附加数据
	optional string ios_pay_order = 5; //苹果预付单号
}

// 响应充值
message RechargeRes {
	optional int32 errcode = 1; //错误原因 0表示成功
	optional string errcodedes = 2; // 错误描述 
	optional string order_id = 3;   // 订单号
	optional int32  pay_type = 4;	// 支付类型
	optional int32  good_id = 5;      // 商品id
	optional string option_data = 6;  // 订单附加数据			
	optional string ios_pay_order = 7;// 苹果预付单号
}
//通知发货
message DeliverGoodNtc {
	optional string order_id = 1;    //订单号
	optional string option_data = 2; //附加数据
	repeated AwardItem awards = 3;   //奖励物品
}
]]

local function ios_recharge(request, responsemsg)
	local rechargecfg = configdao.get_business_conf(request.version.platform, request.version.channel, "rechargecfg")
	local responsemsg = {
		errcode = EErrCode.ERR_SUCCESS,
		pay_type = request.pay_type,
		good_id = request.good_id,
	}

	if rechargecfg == nil or request.option_data == nil then
		responsemsg.errcode = ERR_INVALID_REQUEST
		responsemsg.errcodedes = "无效的请求！"
		return responsemsg, nil
	end

	local data = msgproxy.sendrpc_reqmsgto_httpsvrd("webclient", request)
	if data == nil then
		responsemsg.errcode = EErrCode.ERR_SYSTEM_ERROR
		responsemsg.errcodedes = "系统错误，系统会在你下次登录时给你补单！"
		return responsemsg, 20000
	end

	if data.status ~= 0 then
		responsemsg.errcode = EErrCode.ERR_IOS_CHECK_FAILED
		responsemsg.errcodedes = "支付验证错误，"..data.status
		return responsemsg, data.status
	end

	local order = playerdatadao.query_player_order(nil, data.receipt.transaction_id)
	if order == nil then
		order = {rid = request.rid}
	end

	if order.state ~= nil and order.state >= 3 then
		responsemsg.errcode = EErrCode.ERR_INVALID_REQUEST
		responsemsg.errcodedes = "当前订单已经发货，这次请求无效！"
		return responsemsg, 10
	end

	local rechargeitem
	for _, value in pairs(rechargecfg) do
		if value.pid == data.receipt.product_id then
			rechargeitem = value
			break
		end
	end

	if rechargeitem == nil then
		responsemsg.errcode = EErrCode.ERR_INVALID_GOOD
		responsemsg.errcodedes = "当前充值商品("..data.receipt.product_id..")已经不存在，请联系客服！"
		return responsemsg, 20000
	end

	local awards = {}
	local result = true
	local isrecordlog = false
	for i, award in pairs(rechargeitem.awards) do
		awards[i]={}
		awards[i].id = award.id
		awards[i].num = award.num
	end
	order.order_id=data.receipt.transaction_id
	order.pid = data.receipt.product_id
	order.good_id = rechargeitem.id
	order.good_awards =  json.encode(awards)
	order.pay_type = request.pay_type
	order.price = rechargeitem.price
	if order.state == nil then
		order.create_time = timetool.get_time()
		isrecordlog = true
	end
	order.state = 2
	result = playerdatadao.save_player_order("sync_insert", request.rid, order, nil)
	if not result then
		responsemsg.errcodedes = "保存单据失败！"
		responsemsg.errcode = EErrCode.ERR_INVALID_REQUEST
		return responsemsg, 20000
	end

	--记录订单流水
	if isrecordlog then
		gamelog.write_orderlog(order)
	end

	responsemsg.order_id = order.order_id

	local delivergoodsmsg = {}
	delivergoodsmsg.awards = rechargeitem.awards
	delivergoodsmsg.rid = request.rid
	delivergoodsmsg.order_id = order.order_id
	msgproxy.sendrpc_noticemsgto_gatesvrd(request.gatesvr_id, request.agent_address, "delivergoods", delivergoodsmsg)
	return responsemsg, 0
end

--[[
// 请求充值
message RechargeReq {
	optional Version version = 1;
	optional int32 good_id = 2;        //商品id
	optional int32 pay_type = 3;       //支付类型
	optional string option_data = 4;   //附加数据
	optional string ios_pay_order = 5; //苹果预付单号
}

// 响应充值
message RechargeRes {
	optional int32 errcode = 1; //错误原因 0表示成功
	optional string errcodedes = 2; // 错误描述 
	optional string order_id = 3;   // 订单号
	optional int32  pay_type = 4;	// 支付类型
	optional int32  good_id = 5;      // 商品id
	optional string option_data = 6;  // 订单附加数据			
	optional string ios_pay_order = 7;// 苹果预付单号
}
]]

local function generate_order_id()
	local now = skynet.time()*100
	if count >= 1000 then
		count = 1
	end
	local order_id = string.format("%d%03d", now, count)
	count = count + 1

	return order_id
end

local function  create_thirdprepaid_order(request, rechargeconf)
	local result=true
	local params = nil
	rechargeconf = tabletool.deepcopy(rechargeconf)
	if request.pay_type == EPayType.PAY_TYPE_WECHAT then
		request.rechargeconf = json.encode(rechargeconf)
		params = msgproxy.sendrpc_reqmsgto_httpsvrd("webclient", request)

		if params == nil then
			result = false
		else
			params = json.encode(params)
		end
	elseif request.pay_type == EPayType.PAY_TYPE_ZHIFUBAO then
		params = msgproxy.sendrpc_reqmsgto_httpsvrd("generate_params", request, rechargeconf)

		if params == nil then
			result = false
		end
	end

	return result, params
end

local function other_recharge(request)
	local responsemsg = {
		errcode = EErrCode.ERR_SUCCESS,
		pay_type = request.pay_type,
		good_id = request.good_id,
	}

	local rechargecfg = configdao.get_business_conf(request.version.platform, request.version.channel, "rechargecfg")
	if rechargecfg == nil 
		or request.id == nil 
		or request.pay_type == nil then
		responsemsg.errcode = EErrCode.ERR_INVALID_REQUEST
		responsemsg.errcodedes = "无效的请求！"
		return responsemsg
	end

	local rechargeitem = rechargecfg[request.good_id]
	if rechargeitem == nil 
		or request.good_id ~= rechargeitem.id then
		responsemsg.errcode = EErrCode.ERR_INVALID_GOODID
		responsemsg.errcodedes = "无效的商品ID"
		return responsemsg
	end

	request.order_id = generate_order_id()
	local result, params = create_thirdprepaid_order(request, rechargeitem)
	if not result then
		responsemsg.errcode = EErrCode.ERR_GENERATE_ORDER_FAILED
		responsemsg.errcodedes = "生成预付订单失败！"
		return responsemsg
	end

	responsemsg.option_data = params

	--生成订单
	local order = {rid = request.rid}
	local awards = {}
	for i, award in pairs(rechargeitem.awards) do
		awards[i]={}
		awards[i].id = award.id
		awards[i].num = award.num
	end
	order.order_id=request.order_id
	order.pid = rechargeitem.pid
	order.good_id = rechargeitem.id
	order.good_awards =  json.encode(awards)
	order.pay_type = request.pay_type
	order.price = rechargeitem.price
	order.create_time = timetool.get_time()
	order.state = 1

	result = playerdatadao.save_player_order("sync_insert", request.rid, order, nil)


	if result then
		responsemsg.order_id = order.order_id

		--记录订单流水
		gamelog.write_orderlog(order)	
	else
		responsemsg.errcode = EErrCode.ERR_SAVE_ORDER_FAILED
		responsemsg.errcodedes = "生成订单后保存失败！"
	end

	return responsemsg
end

--[[
// 请求充值
message RechargeReq {
	optional Version version = 1;
	optional int32 good_id = 2;        //商品id
	optional int32 pay_type = 3;       //支付类型
	optional string option_data = 4;   //附加数据
	optional string ios_pay_order = 5; //苹果预付单号
}

// 响应充值
message RechargeRes {
	optional int32 errcode = 1; //错误原因 0表示成功
	optional string errcodedes = 2; // 错误描述 
	optional string order_id = 3;   // 订单号
	optional int32  pay_type = 4;	// 支付类型
	optional int32  good_id = 5;      // 商品id
	optional string option_data = 6;  // 订单附加数据			
	optional string ios_pay_order = 7;// 苹果预付单号
}
]]
function RechargesvrRequest.recharge(request)
	if request.pay_type == EPayType.PAY_TYPE_IOS then		
		base.skynet_retpack(ios_recharge(request))
	else		
		base.skynet_retpack(other_recharge(request))
	end
end

--[[
orderinfo={
	pay_type=0,
	order_id = "",
	price = ,
}
--]]
function RechargesvrRequest.delivergoods(orderinfo)
	--[[
		errcode,  0表示成功，非0表示失败
		info={},
	]]
	local reshttpsvrdmsg = {errcode = 0, info={}}
	if orderinfo == nil or orderinfo.order_id == nil or orderinfo.pay_type == nil then
		filelog.sys_error("RechargesvrRequest.delivergood invalid orderinfo", orderinfo)
		reshttpsvrdmsg.errcode = -1
		base.skynet_retpack(reshttpsvrdmsg)
		return
	end

	local _, order = playerdatadao.query_player_order(nil, orderinfo.order_id)
	if order == nil then
		filelog.sys_error("RechargesvrRequest.delivergood invalid orderinfo.order_id", orderinfo)
		reshttpsvrdmsg.errcode = -1
		base.skynet_retpack(reshttpsvrdmsg)
		return		
	end

	if orderinfo.pay_type ~= order.pay_type then
		filelog.sys_error("RechargesvrRequest.delivergood invalid orderinfo.pay_type", orderinfo, order)
		reshttpsvrdmsg.errcode = -1
		base.skynet_retpack(reshttpsvrdmsg)
		return
	end

	if orderinfo.price ~= nil and order.price ~= orderinfo.price then
		filelog.sys_error("RechargesvrRequest.delivergood invalid orderinfo.price", orderinfo, order)
		reshttpsvrdmsg.errcode = -1
		base.skynet_retpack(reshttpsvrdmsg)
		return		
	end

	if order.state == 3 then
		filelog.sys_error("RechargesvrRequest.delivergood order.state == 3", orderinfo, order)
		reshttpsvrdmsg.errcode = 0
		base.skynet_retpack(reshttpsvrdmsg)
		return		
	end
	local result
	order.state = 2
	result = playerdatadao.save_player_order("sync_update", order.rid, order, {rid = order.rid, order_id = order.order_id})
	if not result then
		filelog.sys_obj("RechargesvrRequest.delivergood playerdatadao.save_player_order failed", order, orderinfo)
		reshttpsvrdmsg.errcode = -1
		base.skynet_retpack(reshttpsvrdmsg)
	end

	--记录订单流水
	gamelog.write_orderlog(order)

	base.skynet_retpack(reshttpsvrdmsg)

	--通知agent发货
	local delivergoodsmsg = {}
	local _, online = playerdatadao.query_player_online(order.rid)
	if online and online.gatesvr_id ~= "" then
		delivergoodsmsg.awards = json.decode(order.good_awards)
		delivergoodsmsg.rid = order.rid
		delivergoodsmsg.order_id = order.order_id
		msgproxy.sendrpc_noticemsgto_gatesvrd(online.gatesvr_id, online.gatesvr_service_address, "delivergoods", delivergoodsmsg)
	end
end

return RechargesvrRequest