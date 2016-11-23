local filelog = require "filelog"

local filename = "configtool.lua"

local ConfigTool = {}

function ConfigTool.load_config(config_filename)
    if config_filename == nil then
    	filelog.sys_error(filename, " [BASIC_CONFIGTOOL] ConfigTool.load_config config_filename == nil")
        return nil, nil
    end

    local f = io.open(config_filename)
    if f == nil then
    	filelog.sys_error(filename, " [BASIC_CONFIGTOOL] ConfigTool.load_config open "..config_filename.." failed")
        return nil, nil
    end

    local source = f:read "*a"
    f:close()
    if source == nil then
    	filelog.sys_error(filename, " [BASIC_CONFIGTOOL] read ConfigTool.load_config "..config_filename.." failed")
        return nil, nil
    end

    local tmp = {}
    local ftmp, err
    local success, err
    local suffix = string.sub(config_filename, -4, -1)
    if suffix == ".lua" then
        ftmp, err = load(source, "@"..config_filename, "bt")
        if ftmp == nil then
            filelog.sys_error(filename.." [BASIC_CONFIGTOOL] ConfigTool.load_config load "..config_filename.." failed", err)
            return nil, nil
        end
        return ftmp(), source
    end
    
    ftmp, err = load(source, "@"..config_filename, "bt", tmp)
    if ftmp == nil then
        filelog.sys_error(filename.." [BASIC_CONFIGTOOL] ConfigTool.load_config load "..config_filename.." failed", err)
        return nil, nil
    end

    local success, err = pcall(ftmp)
    if not success then
        filelog.sys_error(filename.." [BASIC_CONFIGTOOL] ConfigTool.load_config call "..config_filename.." failed", err)
        return nil, nil
    end
    return tmp, source
end

return ConfigTool


