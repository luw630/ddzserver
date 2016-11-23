local skynet = require "skynet"
local filelog = require "filelog"
local configdao = require "configdao"

skynet.start(function()
	print("Server start")
	skynet.newservice("systemlog")
    local confcentersvr = skynet.newservice("confcenter")
    skynet.call(confcentersvr, "lua", "start")


    local rechargesvrs = configdao.get_svrs("rechargesvrs")
    if rechargesvrs == nil then
        print("rechargesvrd start failed rechargesvrs == nil")
        skynet.exit()
    end
    local rechargesvr = rechargesvrs[skynet.getenv("svr_id")]
    if rechargesvr == nil then
        print("rechargesvrd start failed rechargesvr == nil", skynet.getenv("svr_id"))
        skynet.exit()           
    end

   skynet.newservice("debug_console", rechargesvr.debug_console_port)
 
    local proxys = configdao.get_svrs("proxys")
    if proxys ~= nil then
        for id, conf in pairs(proxys) do
            local svr = skynet.newservice("proxy", id)
            conf.svr_id = rechargesvr
            skynet.call(svr, "lua", "init", conf)            
        end 
    end
 
    local params = ",,,,,"..skynet.getenv("svr_id")    
    local watchdog = skynet.newservice("rechargesvrd", params)
    skynet.call(watchdog, "lua", "cmd", "start", rechargesvr)
    
	print("rechargesvrd start success")
	skynet.exit()
end)
