local skynet = require "skynet"
local filelog = require "filelog"
local msghelper = require "loggerobjhelper"
local logicmng = require "logicmng"
local timer = require "timer"
local base = require "base"
local tabletool = require "tabletool"
require "enum"

local filename = "loggertimer.lua"

local LoggerTimer = {}

function LoggerTimer.process(session, source, event, ...)
    local f = LoggerTimer[event]
    if f == nil then
        filelog.sys_error(filename.." LoggerTimer.process invalid event:"..event)
        return nil
    end
    f(...)
end

return LoggerTimer

