local skynet = require "skynet"
local filelog = require "filelog"
local configdao = require "configdao"

skynet.start(function()
    print("Server start")
    skynet.newservice("systemlog")
    local confcentersvr = skynet.newservice("confcenter")
    skynet.call(confcentersvr, "lua", "start")
    print("confcenter start success")    

    local rechargedbsvrs = configdao.get_svrs("rechargedbsvrs")
    if rechargedbsvrs == nil then
        print("rechargedbsvrd start failed rechargedbsvrs == nil")
        skynet.exit()
    end
    local rechargedbsvr = rechargedbsvrs[skynet.getenv("svr_id")]
    if rechargedbsvr == nil then
        print("rechargedbsvrd start failed rechargedbsvr == nil", skynet.getenv("svr_id"))
        skynet.exit()           
    end


    local proxys = configdao.get_svrs("proxys")
    if proxys ~= nil then
        for id, conf in pairs(proxys) do
            local svr = skynet.uniqueservice("proxy", id)
            conf.svr_id = skynet.getenv("svr_id")
            skynet.call(svr, "lua", "init", conf)            
        end 
    end

    skynet.newservice("debug_console", rechargedbsvr.debug_console_port)
    
    --[[local mongologs = configdao.get_svrs("mongologs")
    if mongologs ~= nil then
        for id, conf in pairs(mongologs) do
            local svr = skynet.newservice("mongolog", id)
            skynet.call(svr, "lua", "init", conf)            
        end
    end]]
    
    local params = ",,,,,"..skynet.getenv("svr_id")
    local watchdog = skynet.newservice("rechargedbsvrd", params)
    skynet.call(watchdog, "lua", "cmd", "start", rechargedbsvr)
    print("rechargedbsvrd success ")
    skynet.exit()   
end)
