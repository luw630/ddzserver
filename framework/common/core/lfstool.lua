--
-- Created by IntelliJ IDEA.
-- User: juzhong
-- Date: 2016/11/7
-- Time: 17:12
-- To change this template use File | Settings | File Templates.
--
local skynet = require "skynet"
local lfs = require "lfs"
local filelog = require "filelog"

local LfsTool = {}

function LfsTool.getfileattr(dir)
    if dir == nil then
        return
    end
    local fileattr = lfs.attributes(dir)
    return (fileattr), fileattr
end

function LfsTool.getfilesize(dir)
    local fileattr = lfs.attributes(dir)
    if not fileattr then
        return false
    end
    return true, fileattr.size
end

function LfsTool.get_file_changetime(dir)
    local fileattr = lfs.attributes(dir)
    if not fileattr then
        return false
    end
    return true, fileattr.modification
end

return LfsTool


