local skynet = require "skynet"
local filelog = require "filelog"
local msghelper = require "agenthelper"
local msgproxy = require "msgproxy"
local processstate = require "processstate"
local gamewaterlog = require "gamelog"
local playerdatadao = require "playerdatadao"
local table = table
require "enum"

local processing = processstate:new({timeout=4})
local  Recharge = {}

--[[
// 请求充值
message RechargeReq {
	optional Version version = 1;
	optional int32 good_id = 2;        //商品id（苹果支付渠道可以为不填）
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

function  Recharge.process(session, source, fd, request)
	local responsemsg = {
		errcode = EErrCode.ERR_SUCCESS,
	}
	local status
	local server = msghelper:get_server()

	--检查当前登陆状态
	if not msghelper:is_login_success() then
		filelog.sys_warning("Recharge.process invalid server state", server.state)
		responsemsg.errcode = EErrCode.ERR_INVALID_REQUEST
		responsemsg.errcodedes = "无效的请求！"
		msghelper:send_resmsgto_client(fd, "RechargeRes", responsemsg)		
		return
	end

	if processing:is_processing() then
		responsemsg.errcode = EErrCode.ERR_DEADING_LASTREQ
		responsemsg.errcodedes = "正在处理上一次请求！"
		msghelper:send_resmsgto_client(fd, "RechargeRes", responsemsg)		
		return
	end

	request.rid = server.rid
	request.gatesvr_id = skynet.getenv("svr_id")
	request.agent_address = skynet.self()
	request.ip = server.ip

	responsemsg.good_id = request.good_id
	responsemsg.pay_type = request.pay_type
	responsemsg.ios_pay_order = request.ios_pay_order

	processing:set_process_state(true)
	if request.pay_type == EPayType.PAY_TYPE_IOS then
		gamewaterlog.write_ios_deliverreqlog(server.rid, request.pay_type, request.good_id, request.ios_pay_order, request.option_data, 1)
		playerdatadao.save_player_iosbatch(
					"insert",
					server.rid,
					{
						rid = server.rid,
                        pay_type = request.pay_type,
                        ios_pay_order = request.ios_pay_order,
                        option_data = request.option_data,
					}, nil)
		responsemsg, status = msgproxy.sendrpc_reqmsgto_rechargesvrd("recharge", request)

		if responsemsg == nil then
			gamewaterlog.write_ios_deliverreqlog(server.rid, request.pay_type
										, request.good_id, request.ios_pay_order
										, request.option_data, 2, request.isbatch or false)
			responsemsg = {}
			responsemsg.good_id = request.good_id
			responsemsg.pay_type = request.pay_type
			responsemsg.ios_pay_order = request.ios_pay_order
			responsemsg.errcode = EErrCode.ERR_INVALID_REQUEST
			responsemsg.errcodedes = "无效的请求！"
			msghelper:send_resmsgto_client(fd, "RechargeRes", responsemsg)
			return
		end
		msghelper:send_resmsgto_client(fd, "RechargeRes", responsemsg)
		if responsemsg.errcode == EErrCode.ERR_SUCCESS then
			gamewaterlog.write_ios_deliverreqlog(server.rid, request.pay_type
										, request.good_id, request.ios_pay_order
										, request.option_data, 3, request.isbatch or false)
			playerdatadao.save_player_iosbatch(
						"delete",
						server.rid,
						{
							rid = server.rid,
	                        pay_type = request.pay_type,
	                        ios_pay_order = request.ios_pay_order,
	                        option_data = request.option_data,
						}, 
						{
							rid = server.rid,
							ios_pay_order = request.ios_pay_order,
						})

			return
		end
		
		if not responsemsg.errcode then
			if status == 21003 then
				gamewaterlog.write_ios_deliverreqlog(server.rid, request.pay_type
										, request.good_id, request.ios_pay_order
										, request.option_data, 4, request.isbatch or false)
			elseif status == 21006 then
				gamewaterlog.write_ios_deliverreqlog(server.rid, request.pay_type
								, request.good_id, request.ios_pay_order
								, request.option_data, 3, request.isbatch or false)
			end

			if status ~= 20000 or status ~= 21005 then
				playerdatadao.save_player_iosbatch(
							"delete",
							server.rid,
							{
								rid = server.rid,
		                        pay_type = request.pay_type,
		                        ios_pay_order = request.ios_pay_order,
		                        option_data = request.option_data,
							}, 
							{
								rid = server.rid,
								ios_pay_order = request.ios_pay_order,
							})
			end
			return
		end
	end

	responsemsg = msgproxy.sendrpc_reqmsgto_rechargesvrd("recharge", request)
	if responsemsg == nil then	
		responsemsg.errcode = EErrCode.ERR_INVALID_REQUEST
		responsemsg.errcodedes = "系统错误，请稍后重试！"
	end
	processing:set_process_state(false)

	if not msghelper:is_login_success() then
		return
	end

	msghelper:send_resmsgto_client(fd, "RechargeRes", responsemsg)
end

return Recharge
