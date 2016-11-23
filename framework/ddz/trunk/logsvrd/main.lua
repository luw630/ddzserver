local skynet = require "skynet"
local filelog = require "filelog"
local configdao = require "configdao"

skynet.start(function()
	print("logserver start!!!")
	skynet.newservice("systemlog")
    local confcentersvr = skynet.newservice("confcenter")
    skynet.call(confcentersvr, "lua", "start")
    print("confcenter start success")

    local logsvrs = configdao.get_svrs("logsvrs")

    if logsvrs == nil then
        print("logsvrs start failed logsvrs == nil")
        skynet.exit()
    end
    local logsvr = logsvrs[skynet.getenv("svr_id")]
    if logsvr == nil then
        print("logsvr start failed logsvr == nil", skynet.getenv("svr_id"))
        skynet.exit()           
    end

    local proxys = configdao.get_svrs("proxys")
    if proxys ~= nil then
        for id, conf in pairs(proxys) do
            local svr = skynet.newservice("proxy", id)
            conf.svr_id = logsvr
            skynet.call(svr, "lua", "init", conf)            
        end 
    end

    skynet.newservice("debug_console", logsvr.debug_console_port)
    local params = ",,,,,"..skynet.getenv("svr_id")
    local watchdog = skynet.newservice("logsvrd", params)
    skynet.call(watchdog, "lua", "cmd", "start", logsvr)
	print("logsvrd start success")
	skynet.exit()
end)
