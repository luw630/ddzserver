--
-- Created by IntelliJ IDEA.
-- User: juzhong
-- Date: 2016/11/7
-- Time: 12:43
-- To change this template use File | Settings | File Templates.
--
local filename = "downclientcfg.lua"
local msghelper = require "agenthelper"
local configdao = require "configdao"
local filelog = require "filelog"
local sharedata = require "sharedata"
local json = require "cjson"


require "enum"
json.encode_sparse_array(true,1,1)

local DownClientCfg = {}

function DownClientCfg.process(session, source, fd, request)
    filelog.sys_error("--------------DownClientCfg---------", request)
    local responsemsg = {
        errcode = EErrCode.ERR_SUCCESS,
    }
    local server = msghelper:get_server()

    --检查当前登陆状态
    if not msghelper:is_login_success() then
        filelog.sys_warning("Doaction.process invalid server state", server.state)
        responsemsg.errcode = EErrCode.ERR_INVALID_REQUEST
        responsemsg.errcodedes = "无效的请求！"
        msghelper:send_resmsgto_client(fd, "DownloadCfgReq", responsemsg)
        return
    end
    if request.resconfinfos == nil then
        filelog.sys_error("------resconfinfos------invald args !!!")
        responsemsg.errcode = EErrCode.ERR_INVALID_REQUEST
        responsemsg.errcodedes = "请求参数无效"
        msghelper:send_resmsgto_client(fd, "DownloadCfgReq", responsemsg)
        return
    end
    responsemsg.reqconfinfos = {}
    for _,value in pairs(request.resconfinfos) do
        local getconf = configdao.deepcopy_business_conf(request.version.platform,request.version.channel,value.confname)
        if getconf and confchtime ~= value.changetime then
            local baseTab = {}
            baseTab.changetime = confchtime
            baseTab.confname = value.confname
            baseTab.confcontent = json.encode(getconf)
            table.insert(responsemsg.reqconfinfos, baseTab)
        end
    end

    msghelper:send_resmsgto_client(fd, "DownloadCfgRes", responsemsg)
end

return DownClientCfg


