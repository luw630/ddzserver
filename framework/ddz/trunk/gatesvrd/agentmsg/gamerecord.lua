local skynet = require "skynet"
local filelog = require "filelog"
local msghelper = require "agenthelper"
local msgproxy = require "msgproxy"
local table = table
local processstate = require "processstate"
local playerdatadao = require "playerdatadao"
local json = require "cjson"
require "enum"

local  GameRecord = {}
json.encode_sparse_array(true,1,1)
--[[
//请求玩家战绩信息
message PlayerGameRecordinfoReq {
	optional Version version = 1;
	optional int32 rid = 2;
}
//响应玩家战绩信息
message PlayerGameRecordinfoRes {
	optional int32 errcode = 1; //错误原因 0表示成功
	optional string errcodedes = 2; //错误描述
	repeated PlayerGameRecordinfo recordinfo = 3; // 
}
]]

function  GameRecord.process(session, source, fd, request)
    local responsemsg = {
        errcode = EErrCode.ERR_SUCCESS,
    }
    local server = msghelper:get_server()

    --检查当前登陆状态
    if not msghelper:is_login_success() then
        filelog.sys_warning("EnterTable.process invalid server state", server.state)
        responsemsg.errcode = EGateAgentState.ERR_INVALID_REQUEST
        responsemsg.errcodedes = "无效的请求！"
        msghelper:send_resmsgto_client(fd, "PlayerGameRecordinfoRes", responsemsg)
        return
    end

    local status
    local records
    local beginid = 0
    local limitnum = 10
    local condition = "".."select * from role_tablerecords where rid = "..tostring(request.rid).." and id >="..
                        tostring(beginid).." limit "..tostring(limitnum)
    status, records = playerdatadao.query_player_tablerecords(request.rid,condition)
    responsemsg.errcodedes = "请求成功!!!!"
    responsemsg.records = {}
    for k, value in ipairs(records) do
    	local baseinfo = {}
    	baseinfo.id = value.id
    	baseinfo.table_id = value.table_id
    	baseinfo.table_create_time = value.table_create_time
    	baseinfo.tablecreater_rid = value.table_create_rid
    	baseinfo.entercosts = value.table_base_coin
    	baseinfo.recordinfos = {}
        local infos = json.decode(value.record)
    	for m,n in ipairs(infos) do
    		local recordinfo = {}
    		recordinfo.rid = n.rid
    		recordinfo.currencyid = n.currencyid
    		recordinfo.balancenum = n.balancenum
    		recordinfo.rolename = n.rolename
    		table.insert(baseinfo.recordinfos,recordinfo)
    	end
    	table.insert(responsemsg.records,baseinfo)
    end
    msghelper:send_resmsgto_client(fd, "PlayerGameRecordinfoRes", responsemsg)

end

return GameRecord
