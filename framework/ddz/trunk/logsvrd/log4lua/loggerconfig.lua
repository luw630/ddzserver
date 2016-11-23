local logger = require("log4lua.logger")
local console = require("log4lua.appenders.console")
local file = require("log4lua.appenders.file")
local config = {}

config["ROOT"] = logger.new(console.new(), "ROOT", logger.FATAL)
config["foo"] = logger.new(file.new("foo-%s.log", "%Y-%m-%d"), "foo", logger.INFO)
config["bar"] = logger.new(file.new("bar.log", nil, "%LEVEL: %MESSAGE\n"), "bar", logger.INFO)

return config