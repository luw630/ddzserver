
local filelog = require "filelog"
local msghelper = require "loggerobjhelper"
local base = require "base"
local configdao = require "configdao"
require "enum"

local LoggerobjNotice = {}
function LoggerobjNotice.process(session, source, event, ...)
    local f = LoggerobjNotice[event]
    if f == nil then
        filelog.sys_error(filename.." TableNotice.process invalid event:"..event)
        return nil
    end
    f(...)
end

return LoggerobjNotice


