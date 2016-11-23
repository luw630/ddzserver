local skynet = require "skynet"
local filelog = require "filelog"
local msghelper = require "loggerobjhelper"
local base = require "base"
local serverbase = require "serverbase"
require "enum"
local params = ...

local loggerobj = serverbase:new({
    loggerIndex = 0,
    loggerpath = "",
    loggerbuffers = {},
    loggerconf = nil,
    loggertestIndex = 500,
})


function loggerobj:tostring()
    return "loggerobj"
end

local function agent_to_string()
    return loggerobj:tostring()
end

function  loggerobj:init()
    msghelper:init(loggerobj)
    self.eventmng.init(loggerobj)
    self.eventmng.add_eventbyname("cmd","loggerobjcmd")
    self.eventmng.add_eventbyname("notice", "loggerobjnotice")
    self.eventmng.add_eventbyname("timer","loggertimer")

    loggerobj.__tostring = agent_to_string
end

skynet.start(function()
    if params == nil then
        loggerobj:start()
    else
        loggerobj:start(table.unpack(base.strsplit(params, ",")))
    end
end)

