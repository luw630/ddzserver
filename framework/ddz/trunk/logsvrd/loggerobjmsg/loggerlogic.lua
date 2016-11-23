local skynet = require "skynet"
local base = require "base"
local tabletool = require "tabletool"
local msghelper = require "loggerobjhelper"
local filelog = require "filelog"
local lfs = require "lfs"
local logger = require "log4lua.logger"
local file = require("log4lua.appenders.file")

local loggerLogic = {}


function loggerLogic.init(conf,svr_id)
	local server = msghelper:get_server()
	if server.loggerconf == nil then
		server.loggerconf = tabletool.deepcopy(conf)
	end
    local nowpath = lfs.currentdir()
    local pathtable = base.strsplit(conf.logspath,"/")
    for key,value in ipairs(pathtable) do
        local status = lfs.chdir(tostring(value))
        if status == nil then 
            lfs.mkdir(tostring(value)) 
            lfs.chdir(tostring(value))
        end
    end
    lfs.chdir(nowpath)

    if server.loggerobj == nil then
    	local randonum = base.RNG()
        server.loggerpath = conf.logspath.."/"..string.format("%s-%s-%d.log",conf.logsname,os.date("%Y-%m-%d-%H:%M:%S"),randonum)
        logger.loadCategory(conf.logsname,logger.new(file.new(server.loggerpath), conf.logsname, logger.INFO))
        server.loggerobj = logger.getLogger(conf.logsname)
    end
    loggerLogic.start()
    ---向缓存池中插入测试日志
end

function loggerLogic.checkFileexist()
    -- body
    local server = msghelper:get_server()
    local conf = server.loggerconf
    if server.loggerpath ~= nil and server.loggerpath ~= "" then
        local status = base.is_file_exist(server.loggerpath) 
        if status == false then
            local nowpath = lfs.currentdir()
            local pathtable = base.strsplit(conf.logspath,"/")
            for key,value in ipairs(pathtable) do
                local status = lfs.chdir(tostring(value))
                if status == nil then 
                    lfs.mkdir(tostring(value)) 
                    lfs.chdir(tostring(value))
                end
            end
            lfs.chdir(nowpath)
            local randonum = base.RNG()
            server.loggerpath = conf.logspath.."/"..string.format("%s-%s-%d.log",conf.logsname,os.date("%Y-%m-%d-%H:%M:%S"),randonum)
            logger.loadCategory(conf.logsname,logger.new(file.new(server.loggerpath), conf.logsname, logger.INFO))
            server.loggerobj = logger.getLogger(conf.logsname)
        end
    end
end

function loggerLogic.run()
	-- body
	local server = msghelper:get_server()
	local conf = server.loggerconf
    while #server.loggerbuffers > 0 do
        loggerLogic.checkFileexist()
        local messagetab = table.remove(server.loggerbuffers,1)
    	---local writestring = string.format("write=========%d", i)
        server.loggerobj:info(messagetab,conf.logsname,"chinese")
        server.loggerIndex = server.loggerIndex + 1
        if server.loggerIndex >= server.loggertestIndex then
            server.loggerIndex = 0
            local attr = lfs.attributes(server.loggerpath)
            if attr.size > conf.splitfilesize then
        	   local randonum = base.RNG()
                server.loggerpath = conf.logspath.."/"..string.format("%s-%s-%d.log",conf.logsname,os.date("%Y-%m-%d-%H:%M:%S"),randonum)
                logger.loadCategory(conf.logsname,logger.new(file.new(server.loggerpath), conf.logsname, logger.INFO))
                server.loggerobj = logger.getLogger(conf.logsname)
            end
        end
    end
end



function loggerLogic.start()
	skynet.fork(
		function()
			while true do
				skynet.sleep(10)
				loggerLogic.run()
			end
		end)
end

return loggerLogic