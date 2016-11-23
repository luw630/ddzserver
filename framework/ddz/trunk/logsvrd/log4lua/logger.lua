
-- Class definition
local skynet = require "skynet"

local Logger = {}
Logger.__index = Logger

local _module = Logger

local console = require "log4lua.appenders.console"
local file = require "log4lua.appenders.file"
local utils = require "log4lua.utils"

--- Level constants.
_module.DEBUG = "DEBUG"
--- Level constants.
_module.INFO = "INFO"
--- Level constants.
_module.WARN = "WARN"
--- Level constants.
_module.ERROR = "ERROR"
--- Level constants.
_module.FATAL = "FATAL"
--- Level constants.
_module.OFF = "OFF"

_module.LOG_LEVELS = {
    DEBUG = 1,
    INFO = 2,
    WARN = 3,
    ERROR = 4,
    FATAL = 5,
    OFF = 6
}

-- Default pattern used for all appenders.
_module.DEFAULT_PATTERN = "[%DATE] [%LEVEL] [%COUNTRY] %MESSAGE at %FILE:%LINE(%METHOD)\n"
_module.DEFAULT_PATTERN = "[%DATE] %MESSAGE \n"

-- Name of the environment variable that holds the path to the default config file.
local ENV_LOGGING_CONFIG_FILE = "LOG4LUA_CONFIG_FILE"

-- Map containing all configured loggers (key is category).
local _loggers = nil

-- Load default configuration found in environment variable.
local function initConfig()
    if (_loggers == nil) then
        local configFile = os.getenv(ENV_LOGGING_CONFIG_FILE)
        if (configFile ~= nil) then
            _module.loadConfig(configFile)
        else
            -- We need at least a root logger.
            _loggers = {}
            _loggers["ROOT"] = Logger.new(console.new(), "ROOT", _module.INFO)
        end
    end
end

--- Main method that returns a fully configured logger for the given category.<br />
-- The correct logger is found as follows:
-- <ul>
--    <li>If there is a configured logger with the exact category then use this.</li>
--    <li>Otherwise search for loggers with matching category.
--        Example: If there is a configured logger for category "test" then it is used for category "test.whatever", "testinger" etc.</li>
--    <li>Otherwise use the root category.</li>
-- </ul>
-- @param category the category of the desired logger.
function _module.getLogger(category)
	initConfig()
    local log = nil
    if (category ~= nil) then
        log = _loggers[category]
        if (log == nil) then
            for loggerCategory, logger in pairs(_loggers) do
                if (string.find(category, loggerCategory, 1, true) == 1) then
                    log = logger
                    break
                end
            end
        end
    end
    if (log == nil) then
        log = _loggers["ROOT"]
    end
    assert(log, "Logger cannot be empty. Check your configuration!")
    return log
end

--- Load a configuration file.
-- @param fileName path to a configuration file written in lua. The lua code must return a map (table) with loggers configured for each category.
function _module.loadConfig(fileName)
    local result, errorMsg = loadfile(fileName)

    if (result) then
		local loadedLoggers = result()
        assert(loadedLoggers ~= nil and loadedLoggers["ROOT"] ~= nil, "At least a log category 'ROOT' must be specified.")
        _loggers = loadedLoggers
    else
		-- Default configuration if no config file has been specified or it could not be loaded.
		_loggers = {}
        _loggers["ROOT"] = Logger.new(console.new(), "ROOT", _module.INFO)
        _module.getLogger("ROOT"):info("No logging configuration found in file '" .. fileName .. "' (Error: " .. tostring(errorMsg) .. "). Using default (INFO to console).",nil,"chinaness")
    end
end

function _module.loadCategory(category,fileobj)
    if (not category) or (not fileobj) then
        _loggers = {}
        _loggers["ROOT"] = Logger.new(console.new(), "ROOT", _module.INFO)
        _module.getLogger("ROOT"):info("No logging configuration found in file '" .. fileName .. "' (Error: " .. tostring(errorMsg) .. "). Using default (INFO to console).",nil,"chinaness")
    else
		-- Default configuration if no config file has been specified or it could not be loaded.
		if _loggers == nil then
            _loggers = {}
        end
        _loggers[category] = fileobj
    end
end

--- Constructor.
-- @param appenders a single function or a table of functions taking a string as parameter that is responsible for writing the log message.
-- @param category the category (== name) of this logger
-- @param level the threshold level. Only messages for equal or higher levels will be logged.
function Logger.new(appenders, category, level)
    local self = {}
    setmetatable(self, Logger)
    assert(appenders ~= nil and (type(appenders) == "function" or type(appenders) == "table"), "Invalid value for appenders.")
    if (type(appenders) == "function") then
        appenders = {appenders}
    end
    for _, appender in ipairs(appenders) do
        assert(type(appender) == "function", "First parameter (the appender) must be a function.")
    end
    assert(category ~= nil, "Category not set.")
    self._appenders = appenders
    self._level = level or _module.INFO
    self._category = category

    return self
end

--- Set the log level threshold.
function Logger:setLevel(level)
    assert(_module.LOG_LEVELS[level] ~= nil, "Unknown log level '" .. level .. "'")
    self._level = level
end

--- Log the given message at the given level.
function Logger:log(level, message, exception, country)
	assert(_module.LOG_LEVELS[level] ~= nil, "Unknown log level '" .. level .. "'")
    if (_module.LOG_LEVELS[level] >= _module.LOG_LEVELS[self._level] and level ~= _module.OFF) then
        for _, appender in ipairs(self._appenders) do
			appender(self, level, message, exception, country)
        end
    end
end

--- Test whether the given level is enabled.
-- @return true if messages of the given level will be logged.
function Logger:isLevel(level)
    local levelPos = _module.LOG_LEVELS[level]
    assert(levelPos, "Invalid level '" .. tostring(level) .. "'")
    return levelPos >= _module.LOG_LEVELS[self._level]
end

--- Log message at DEBUG level.
function Logger:debug(message, exception, country)
    self:log(_module.DEBUG, message, exception, country)
end

--- Log message at INFO level.
function Logger:info(message, exception, country)
    self:log(_module.INFO, message, exception, country)
end

--- Log message at WARN level.
function Logger:warn(message, exception, country)
    self:log(_module.WARN, message, exception, country)
end

--- Log message at ERROR level.
function Logger:error(message, exception, country)
    self:log(_module.ERROR, message, exception, country)
end

--- Log message at FATAL level.
function Logger:fatal(message, exception, country)
    self:log(_module.FATAL, message, exception, country)
end

function Logger:formatMessage(pattern, level, message, exception, country)
    local result = pattern or _module.DEFAULT_PATTERN
    if (type(message) == "table") then
        message = utils.convertTableToString(message, 5)
    end
    message = string.gsub(tostring(message), "%%", "%%%%")

    -- If the pattern contains any traceback relevant placeholders process them.
    if (
        string.match(result, "%%PATH")
        or string.match(result, "%%FILE")
        or string.match(result, "%%LINE")
        or string.match(result, "%%METHOD")
        or string.match(result, "%%STACKTRACE")
    ) then
        -- Take no risk - format the stacktrace using pcall to prevent ugly errors.
        _, result = pcall(Logger._formatStackTrace, self, result)
    end

	-- Test CCurrentGameState existance, this script may run from pure LUA without HOI3 bindings
	local inGameDate = ""
    local timeseconds, millseconds = math.modf(skynet.time())
    local datestring = os.date("%Y-%m-%d %H:%M:%S", timeseconds)
    inGameDate = inGameDate..datestring.."."..tostring(math.floor(millseconds*100))

    result = string.gsub(result, "%%DATE", inGameDate)
	result = string.gsub(result, "%%RDATE", tostring(os.date()))
    result = string.gsub(result, "%%LEVEL", level)
    result = string.gsub(result, "%%MESSAGE", message)
	result = string.gsub(result, "%%COUNTRY", country)
    -- tweak for AIIP (log4lua is bugged)
	if exception ~= nil then
		result = string.gsub(result, "%%ERROR", exception)
	end

    return result
end

-- Format stack trace.
function Logger:_formatStackTrace(pattern)
    local result = pattern

    -- Handle stack trace and method.
    local stackTrace = debug.traceback()

    for line in string.gmatch(stackTrace, "[^\\n]-\\.lua:%d+: in [^\\n]+") do
        if 	not string.match(line, ".-log4lua.-\\.lua:%d+:") and
			-- AIIP added utils.lua in list not to refer to wrapper
			not string.match(line, "utils\\.lua") and
			not string.match(line, ".-dtools.-\\.lua:%d+:")
		then
            local _, _, sourcePath, sourceLine, sourceMethod = string.find(line, "(.-):(%d+): in (.*)")
			local _, _, sourceFile = string.find(sourcePath or "n/a", ".*\\(.*)")

			result = string.gsub(result, "%%PATH", sourcePath or "n/a")
			result = string.gsub(result, "%%FILE", sourceFile or "n/a")
			result = string.gsub(result, "%%LINE", sourceLine or "n/a")
			result = string.gsub(result, "%%METHOD", sourceMethod or "n/a")
            break
        end
    end
	
	result = string.gsub(result, "%%STACKTRACE", stackTrace)

    return result
end

return _module
