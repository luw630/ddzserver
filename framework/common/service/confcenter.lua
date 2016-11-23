local skynet = require "skynet"
local configmng = require "configmng"
local filelog = require "filelog"
local sharedata = require "sharedata"
local configtool = require "configtool"
local base = require "base"
require "skynet.manager"
local filename = "confcenter.lua"
local sharedataname = "cfgmng"
local sharedataname_svrs = "cfgsvrs"
local sharedataname_dbhash = "cfgdbhash"
local sharedataname_cluster = "cfgclusters"
local cfgcenter
local cfgsvrs
local cfgdbhash
local cfgclusters

local CMD = {}
function  CMD.init(...)	
	configmng.init()
	cfgcenter = configmng.get_cfgcenter()
	cfgsvrs = configtool.load_config(skynet.getenv("svrs_config"))
	if cfgsvrs == nil then
		filelog.sys_error("[BASIC_CONFCENTER] load svrs_config failed")
		skynet.exit()
	end 

	cfgdbhash = configtool.load_config(skynet.getenv("dbhash_config"))
	if cfgdbhash == nil then
		filelog.sys_error("[BASIC_CONFCENTER] load dbhash_config failed")
		skynet.exit()
	end

	cfgclusters = configtool.load_config(skynet.getenv("cluster"))
	if cfgclusters == nil then
		filelog.sys_error("[BASIC_CONFCENTER] load config_clusters failed")
		skynet.exit()
	end
	sharedata.new(sharedataname, cfgcenter)
	sharedata.new(sharedataname_svrs, cfgsvrs)
	sharedata.new(sharedataname_dbhash, cfgdbhash)
	sharedata.new(sharedataname_cluster, cfgclusters)
end


function CMD.reload(...)
	if configmng.reload() then
		cfgcenter = configmng.get_cfgcenter()		
		sharedata.update(sharedataname, cfgcenter)
	end

	cfgsvrs = configtool.load_config(skynet.getenv("svrs_config"))
	if cfgsvrs ~= nil then
		sharedata.update(sharedataname_svrs, cfgsvrs)		
	end

	cfgdbhash = configtool.load_config(skynet.getenv("dbhash_config"))
	if cfgsvrs ~= nil then
		sharedata.update(sharedataname_dbhash, cfgdbhash)		
	end

	cfgclusters = configtool.load_config(skynet.getenv("cluster"))
	if cfgclusters ~= nil then
		sharedata.update(sharedataname_cluster, cfgclusters)		
	end
	base.skynet_retpack(true)
end 

function CMD.exit(...)
	sharedata.delete(sharedataname)
	sharedata.delete(sharedataname_svrs)
	sharedata.delete(sharedataname_dbhash)
	sharedata.delete(sharedataname_cluster)
	cfgcentermng = nil
	cfgsvrs = nil
	cfgdbhash = nil
	cfgclusters = nil
	skynet.exit()
end 

function CMD.start(...)
	CMD.init(...)
	base.skynet_retpack(true)
end

skynet.dispatch("lua", function(_, address,  cmd, ...)
	    local f = CMD[cmd]
		if f ~= nil then
            f(...)
        else
            filelog.sys_error(filename.." [BASIC_CONFCENTER] skynet.dispatch invalid func "..cmd)
        end
end)

skynet.start(function()
    skynet.register ".confcenter"
end)