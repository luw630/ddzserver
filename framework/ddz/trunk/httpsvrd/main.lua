local skynet = require "skynet"
local filelog = require "filelog"
local configdao = require "configdao"

skynet.start(function()
	print("Server start")
	skynet.newservice("systemlog")
    local confcentersvr = skynet.newservice("confcenter")
    skynet.call(confcentersvr, "lua", "start")
    print("confcenter start success")

    local httpsvrs = configdao.get_svrs("httpsvrs")
    if httpsvrs == nil then
        print("httpsvrd start failed httpsvrs == nil")
        skynet.exit()
    end
    local httpsvr = httpsvrs[skynet.getenv("svr_id")]
    if httpsvr == nil then
        print("httpsvrd start failed httpsvr == nil", skynet.getenv("svr_id"))
        skynet.exit()           
    end

    local proxys = configdao.get_svrs("proxys")
    if proxys ~= nil then
        for id, conf in pairs(proxys) do
            local svr = skynet.newservice("proxy", id)
            conf.svr_id = skynet.getenv("svr_id")
            skynet.call(svr, "lua", "init", conf)            
        end 
    end

    skynet.newservice("debug_console", httpsvr.debug_console_port)

    --[[local mongologs = configdao.get_svrs("mongologs")
    if mongologs ~= nil then
        for id, conf in pairs(mongologs) do
            local svr = skynet.newservice("mongolog", id)
            skynet.call(svr, "lua", "init", conf)            
        end
    end]]

    local params = ",,,,,"..skynet.getenv("svr_id")    
    local svr = skynet.newservice("httpsvrd", params)
    skynet.call(svr, "lua", "cmd", "start", httpsvr)

	print("httpsvrd start success")
	skynet.exit()
end)
