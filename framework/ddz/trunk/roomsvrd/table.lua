local skynet = require "skynet"
local filelog = require "filelog"
local msghelper = require "tablehelper"
local serverbase = require "serverbase"
local base = require "base"
local tableobj = require "object.tableobj"
local ddzgamelogic = require "ddzgamelogic"
local table = table

local params = ...

local Table = serverbase:new({
	table_data = tableobj:new({
		cur_watch_playernum = 0,
		--添加桌子的变量
		delete_table_timer_id = -1,
		retain_to_time = 0,    --桌子保留到的时间(linux时间擢)
		action_seat_index = 0, --当前操作玩家的座位号
		action_to_time = 0,    --当前操作玩家的到期时间
		ddzgame = nil, 		   ---ddzgamelogic:new(), --棋牌
		action_type = 0,       --玩家当前操作类型
		dz_seat_index = 0,     --记录当前的地主座位号
		initCards = nil,	   --牌池
		baseTimes = 1,		   --
		jzdbegin_index = 0,    ---
		CardsHeaps = nil, 		---保存玩家出过的牌的牌堆
		noputsCardsNum = 0,		---一个出牌回合里,没有出牌的玩家数,不出+1，出牌则置0
		iswilldelete = 0, 		---在游戏中如果收到删除指令,则置1,游戏结束再处理
		gamerecords = nil,		----记录战绩
		ischuntian = 0,         ----是否是春天
		backofconf = nil,       ----缓存更新的配置文件
	}),

	logicmng = require("logicmng")
})

function Table:tostring()
	return "Table"
end

local function table_to_sring()
	return Table:tostring()
end

function Table:init()
	msghelper:init(Table)
	self.eventmng.init(Table)
	self.eventmng.add_eventbyname("cmd", "tablecmd")
	self.eventmng.add_eventbyname("request", "tablerequest")
	self.eventmng.add_eventbyname("notice", "tablenotice")
	self.eventmng.add_eventbyname("timer", "tabletimer")
	Table.__tostring = table_to_sring

	self.logicmng.add_logic("roomtablelogic")
	self.logicmng.add_logic("roomseatlogic")
	self.logicmng.add_logic("roomgamelogic")
	self.logicmng.add_logic("roomfndgamelogic")
end 

skynet.start(function()  
	if params == nil then
		Table:start()
	else		
		Table:start(table.unpack(base.strsplit(params, ",")))
	end	
end)