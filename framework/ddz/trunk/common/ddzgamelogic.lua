
local math = math
local pairs = pairs
local ipairs = ipairs
local type = type
local table = table
local tabletool = require "tabletool"
local timetool = require "timetool"
local base = require "base"
local filelog = require "filelog"
require "enum"
local DDZGameLogic = {}
local MaxCardNum = 54
local PlayerMaxNum = 3
---54张牌编码
local CardsKey = {
    0,1,2,3,
    4,5,6,7,
    8,9,10,11,
    12,13,14,15,
    16,17,18,19,
    20,21,22,23,
    24,25,26,27,
    28,29,30,31,
    32,33,34,35,
    36,37,38,39,
    40,41,42,43,
    44,45,46,47,
    48,49,50,51,
    52,53
}
---编码对应的牌
local  CardsValue = {
    3,3,3,3,
    4,4,4,4,
    5,5,5,5,
    6,6,6,6,
    7,7,7,7,
    8,8,8,8,
    9,9,9,9,
    10,10,10,10,
    11,11,11,11,---J
    12,12,12,12,---Q
    13,13,13,13,---K
    14,14,14,14,---A
    15,15,15,15,---2
    16,17
}
---编码对应的花色
---0,1,2,3 黑桃,红桃,草花,方片
local CardsColor = {
    0,1,2,3,
    0,1,2,3,
    0,1,2,3,
    0,1,2,3,
    0,1,2,3,
    0,1,2,3,
    0,1,2,3,
    0,1,2,3,
    0,1,2,3,
    0,1,2,3,
    0,1,2,3,
    0,1,2,3,
    0,1,2,3,
    0,1
}
---- 主动出牌时，筛选手牌的优先级
local PutsCardsOrder = {
    ECardType.DDZ_CARD_TYPE_ONE_STRAIGHT,----顺子
    ECardType.DDZ_CARD_TYPE_THREE_WING_PAIR, ----- 飞机带双
    ECardType.DDZ_CARD_TYPE_THREE_WING_ONE, -----飞机带单
    ECardType.DDZ_CARD_TYPE_THREE_STRAIGHT, -----飞机不带
    ECardType.DDZ_CARD_TYPE_TWO_STRAIGHT, -----连对
    ECardType.DDZ_CARD_TYPE_FOUR_TWO_PAIR, ------四带两对
    ECardType.DDZ_CARD_TYPE_FOUR_TWO_ONE, ----四带二
    ECardType.DDZ_CARD_TYPE_THREE_PAIR,   ---三带二
    ECardType.DDZ_CARD_TYPE_BOMB,         ---炸弹
    ECardType.DDZ_CARD_TYPE_THREE_ONE,      ---三带一
    ECardType.DDZ_CARD_TYPE_THREE,          ----三条
    ECardType.DDZ_CARD_TYPE_ROCKET,         ----王炸
    ECardType.DDZ_CARD_TYPE_PAIR,           ----对子
    ECardType.DDZ_CARD_TYPE_SINGLE,         ----单张

}
local CardHelper = {
    m_nLen = 0,
    m_eCardType = ECardType.DDZ_CARD_TYPE_UNKNOWN,
    m_keyMaxValue = 0,
}
local CardRuler = {
    ---1.单张
    [ECardType.DDZ_CARD_TYPE_SINGLE] = {
        isMatched = function(CardsObject)
            ---判断张数不是一张就返回
            if CardsObject.m_nLen ~= 1 then
                return false,ECardType.DDZ_CARD_TYPE_UNKNOWN
            end
            ---检测牌是否合法
            if CardsKey[CardsObject[1]+1] == nil then
                return false, ECardType.DDZ_CARD_TYPE_UNKNOWN
            end
            CardsObject.m_keyMaxValue = CardsValue[CardsObject[1]+1]
            return true, ECardType.DDZ_CARD_TYPE_SINGLE
        end,
        isBigThan = function(lparam,rparam)
            ----本牌必须是单牌类型，否则,对牌可以是炸弹，可以类型不同返回
            if lparam.m_eCardType ~= ECardType.DDZ_CARD_TYPE_SINGLE or not
                (rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_SINGLE or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_BOMB or rparam.m_eCardType==ECardType.DDZ_CARD_TYPE_ROCKET
                    or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_SOFTBOMB or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_TIANBOMB) then
                return false
            end
            if lparam.m_eCardType == ECardType.DDZ_CARD_TYPE_SINGLE and rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_SINGLE
                    and lparam.m_keyMaxValue < rparam.m_keyMaxValue then
                return true
            end
            ---如果对面的牌是各种炸弹,则对面的牌大
            if rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_BOMB or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_ROCKET
                    or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_SOFTBOMB or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_TIANBOMB then
                return true
            end
            return false
        end
    },
    ---2.对子
    [ECardType.DDZ_CARD_TYPE_PAIR] = {
        isMatched = function(CardsObject)
            ---判断张数不是两张就返回
            if CardsObject.m_nLen ~= 2 then
                return false,ECardType.DDZ_CARD_TYPE_UNKNOWN
            end
            ---牌值要一致
            if CardsKey[CardsObject[1]+1] == nil or CardsKey[CardsObject[2]+1] == nil or CardsValue[CardsObject[1]+1] ~= CardsValue[CardsObject[2]+1] then
                return false, ECardType.DDZ_CARD_TYPE_UNKNOWN
            end
            CardsObject.m_keyMaxValue = CardsValue[CardsObject[1]+1]

            return true, ECardType.DDZ_CARD_TYPE_PAIR
        end,
        isBigThan = function(lparam,rparam)
            ----类型不同返回
            if lparam.m_eCardType ~= ECardType.DDZ_CARD_TYPE_PAIR or not
                (rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_PAIR or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_BOMB or rparam.m_eCardType==ECardType.DDZ_CARD_TYPE_ROCKET
                    or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_SOFTBOMB or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_TIANBOMB) then
                return false
            end

            if lparam.m_eCardType == ECardType.DDZ_CARD_TYPE_PAIR and rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_PAIR
                and lparam.m_keyMaxValue < rparam.m_keyMaxValue then
                return true
            end
            ---如果对面的牌是各种炸弹,则对面的牌大
            if rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_BOMB or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_ROCKET
                    or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_SOFTBOMB or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_TIANBOMB then
                return true
            end
            return false
        end
    },
    ---3.三张
    [ECardType.DDZ_CARD_TYPE_THREE] = {
        isMatched = function(CardsObject)
            if CardsObject.m_nLen ~= 3 then
                return false, ECardType.DDZ_CARD_TYPE_UNKNOWN
            end
            if CardsKey[CardsObject[1]+1] == nil or CardsKey[CardsObject[2]+1] == nil or CardsKey[CardsObject[3]+1] == nil then
                return false, ECardType.DDZ_CARD_TYPE_UNKNOWN
            end
            if CardsValue[CardsObject[1]+1] ~= CardsValue[CardsObject[2]+1] or CardsValue[CardsObject[1]+1] ~= CardsValue[CardsObject[3]+1] then
                return false, ECardType.DDZ_CARD_TYPE_UNKNOWN
            end
            CardsObject.m_keyMaxValue = CardsValue[CardsObject[1]+1]
            return true, ECardType.DDZ_CARD_TYPE_THREE
        end,
        getBigger = function(cardscontainer,srcbeg,srclen,isdibomb)
            local status, recards = DDZGameLogic.getBiggerCards(cardscontainer,srcbeg,3)
            if status == true then
                return status, recards
            end
        end,
        isBigThan = function(lparam,rparam)
            ----类型不同返回
            if lparam.m_eCardType ~= ECardType.DDZ_CARD_TYPE_THREE or not
            (rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_THREE or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_BOMB or rparam.m_eCardType==ECardType.DDZ_CARD_TYPE_ROCKET
                    or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_SOFTBOMB or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_TIANBOMB) then
                return false
            end
            if lparam.m_eCardType == ECardType.DDZ_CARD_TYPE_THREE and rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_THREE
                    and lparam.m_keyMaxValue < rparam.m_keyMaxValue then
                return true
            end
            ---如果对面的牌是各种炸弹,则对面的牌大
            if rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_BOMB or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_ROCKET
                    or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_SOFTBOMB or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_TIANBOMB then
                return true
            end
            return false
        end
    },
    ---4.炸弹
    [ECardType.DDZ_CARD_TYPE_BOMB] = {
        isMatched = function(CardsObject)
            if CardsObject.m_nLen ~= 4 then
                return false, ECardType.DDZ_CARD_TYPE_UNKNOWN
            end
            ---牌值要一致
            for k,v in ipairs(CardsObject) do
                if CardsKey[v+1] == nil then return false, ECardType.DDZ_CARD_TYPE_UNKNOWN end
            end
            if CardsValue[CardsObject[1]+1] ~= CardsValue[CardsObject[2]+1] or CardsValue[CardsObject[1]+1] ~= CardsValue[CardsObject[3]+1]
                or CardsValue[CardsObject[1]+1] ~= CardsValue[CardsObject[4]+1] then
                return false, ECardType.DDZ_CARD_TYPE_UNKNOWN
            end
            CardsObject.m_keyMaxValue = CardsValue[CardsObject[1]+1]
            return true, ECardType.DDZ_CARD_TYPE_BOMB
        end,
        isBigThan = function(lparam,rparam)
            ----类型不同返回
            if lparam.m_eCardType ~= ECardType.DDZ_CARD_TYPE_BOMB or not
                (rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_BOMB or rparam.m_eCardType==ECardType.DDZ_CARD_TYPE_ROCKET
                    or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_SOFTBOMB or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_TIANBOMB) then
                return false
            end

            if lparam.m_eCardType == ECardType.DDZ_CARD_TYPE_BOMB and rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_BOMB
                and lparam.m_keyMaxValue < rparam.m_keyMaxValue then
                return true
            end
            if rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_ROCKET or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_TIANBOMB then
                return true
            end
            return false
        end
    },
    ---5.火箭(王炸)
    [ECardType.DDZ_CARD_TYPE_ROCKET] = {
        isMatched = function(CardsObject)
            if CardsObject.m_nLen ~= 2 then
                return false, ECardType.DDZ_CARD_TYPE_UNKNOWN
            end
            if CardsKey[CardsObject[1]+1] == nil or CardsKey[CardsObject[2]+1] == nil then
                return false, ECardType.DDZ_CARD_TYPE_UNKNOWN
            end
            if not ((CardsValue[CardsObject[1]+1] == 16 and CardsValue[CardsObject[2]+1] == 17) or (CardsValue[CardsObject[1]+1] == 17 and CardsValue[CardsObject[2]+1] == 16)) then
                return false, ECardType.DDZ_CARD_TYPE_UNKNOWN
            end
            CardsObject.m_keyMaxValue = 17
            return true, ECardType.DDZ_CARD_TYPE_ROCKET
        end,
        getWangzha = function(cards)
            local isfind = false
            local recards = {}
            for i = #cards,1,-1 do
                if CardsValue[cards[i]+1] > 15 then
                    table.insert(recards,cards[i])
                end
            end
            if #recards == 2 then isfind = true end
            return isfind, recards
        end,
        isBigThan = function(lparam,rparam)
            ----类型不同返回
            if lparam.m_eCardType ~= ECardType.DDZ_CARD_TYPE_ROCKET or rparam.m_eCardType ~= (ECardType.DDZ_CARD_TYPE_ROCKET or ECardType.DDZ_CARD_TYPE_TIANBOMB) then
                return false
            end
            if rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_TIANBOMB then
                return true
            end
            return false
        end
    },
    ---6.单顺
    [ECardType.DDZ_CARD_TYPE_ONE_STRAIGHT] = {
        isMatched = function(CardsObject)
            if CardsObject.m_nLen < 5 or CardsObject.m_nLen > 12 then
                return false, ECardType.DDZ_CARD_TYPE_UNKNOWN
            end
            for i = 1,CardsObject.m_nLen do
                local CardValue = CardsValue[CardsObject[i]+1]
                if CardsObject[i+1] == nil then break end
                local CardValueNext = CardsValue[CardsObject[i+1]+1]
                if CardValue and CardValueNext then
                    if (CardValue==15 or CardValue==16 or CardValue==17) or (CardValueNext==15 or CardValueNext==16 or CardValueNext==17) then
                        return false, ECardType.DDZ_CARD_TYPE_UNKNOWN
                    end
                    if CardValue ~= CardValueNext + 1 then
                        return false, ECardType.DDZ_CARD_TYPE_UNKNOWN
                    end
                end
            end
            CardsObject.m_keyMaxValue = CardsValue[CardsObject[1]+1]
            return true, ECardType.DDZ_CARD_TYPE_ONE_STRAIGHT
        end,
        getBigger = function(cards,srcbeg,srclen, isdibomb) ----从cards的手牌中筛选出一个顺子
            if not cards or #cards <= 0 or not srcbeg or not srclen then return false end
            if #cards < srclen then return false end
            local len_src = (srclen == 0) and #cards or srclen
            local basevalue = srcbeg
            local bigger_cards = {}
            local isFind = true
            for i = #cards,1,-1  do
                if CardsValue[cards[i]+1] > basevalue and CardsValue[cards[i]+1] < 15 then
                    if #bigger_cards == 0 then
                        table.insert(bigger_cards,cards[i])
                    elseif #bigger_cards > 0 and #bigger_cards < len_src then
                        if CardsValue[bigger_cards[#bigger_cards]+1] + 1 == CardsValue[cards[i]+1] then
                            table.insert(bigger_cards,cards[i])
                        else
                            if srclen == 0 and #bigger_cards >= 5 then return isFind,bigger_cards end
                            bigger_cards = {}
                        end
                    end
                    basevalue = CardsValue[cards[i]+1]
                end
            end
            if #bigger_cards < 5 then
                isFind = false
                bigger_cards = {}
            end
            return isFind,bigger_cards
        end,
        isBigThan = function(lparam,rparam)
            if lparam.m_eCardType ~= ECardType.DDZ_CARD_TYPE_ONE_STRAIGHT or not
                (rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_ONE_STRAIGHT or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_BOMB or rparam.m_eCardType==ECardType.DDZ_CARD_TYPE_ROCKET
                    or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_SOFTBOMB or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_TIANBOMB) then
                return false
            end
            if rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_BOMB or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_ROCKET
                    or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_SOFTBOMB or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_TIANBOMB then
                return true
            end
            if lparam.m_eCardType == rparam.m_eCardType then
                if lparam.m_nLen ~= rparam.m_nLen then
                    return false
                else
                    if lparam.m_keyMaxValue < rparam.m_keyMaxValue then
                        return true
                    else
                        return false
                    end
                end
            end
            return false
        end
    },
    ---7.连对
    [ECardType.DDZ_CARD_TYPE_TWO_STRAIGHT] = {
        isMatched = function(CardsObject)
            if CardsObject.m_nLen < 6 or CardsObject.m_nLen % 2 ~= 0 then
                return false, ECardType.DDZ_CARD_TYPE_UNKNOWN
            end
            for i = 1,CardsObject.m_nLen,2 do
                local CardValue = CardsValue[CardsObject[i]+1]
                if CardsObject[i+1] == nil then break end
                local CardValueNext = CardsValue[CardsObject[i+1]+1]
                if CardValue and CardValueNext then
                    if (CardValue==15 or CardValue==16 or CardValue==17) or (CardValueNext==15 or CardValueNext==16 or CardValueNext==17) or (CardValue ~= CardValueNext) then
                        return false, ECardType.DDZ_CARD_TYPE_UNKNOWN
                    end
                    if CardsObject[i+2] and CardsValue[CardsObject[i+2]+1] then
                        if CardValue ~= CardsValue[CardsObject[i+2]+1] + 1 then return false, ECardType.DDZ_CARD_TYPE_UNKNOWN end
                    end
                else
                    return false, ECardType.DDZ_CARD_TYPE_UNKNOWN
                end
            end
            CardsObject.m_keyMaxValue = CardsValue[CardsObject[1]+1]
            return true, ECardType.DDZ_CARD_TYPE_TWO_STRAIGHT
        end,
        getBigger = function(cardscontainer,srcbeg,srclen,isdibomb)
            if not cardscontainer or #cardscontainer.pair <= 0 or not srcbeg or not srclen then return false end
            if #cardscontainer.pair < srclen then return false end
            local len_src = (srclen == 0) and #cardscontainer.pair or srclen
            local basevalue = srcbeg
            local bigger_cards = {}
            local isFind = true
            for i = #cardscontainer.pair,1,-2 do
                if CardsValue[cardscontainer.pair[i]+1] > basevalue then
                    if #bigger_cards == 0 then
                        table.insert(bigger_cards,cardscontainer.pair[i])
                        table.insert(bigger_cards,cardscontainer.pair[i-1])
                    elseif #bigger_cards > 0 and #bigger_cards < len_src then
                        if CardsValue[bigger_cards[#bigger_cards]+1] + 1 == CardsValue[cardscontainer.pair[i]+1] then
                            table.insert(bigger_cards,cardscontainer.pair[i])
                            table.insert(bigger_cards,cardscontainer.pair[i-1])
                        else
                            if srclen == 0 and #bigger_cards >= 6 then return isFind,bigger_cards end
                            bigger_cards = {}
                        end
                    end
                    basevalue = CardsValue[cardscontainer.pair[i]+1]
                end
            end
            if #bigger_cards < 6 then
                isFind = false
                bigger_cards = {}
            end
            return isFind,bigger_cards
        end,
        isBigThan = function(lparam,rparam)
            if lparam.m_eCardType ~= ECardType.DDZ_CARD_TYPE_TWO_STRAIGHT or not
                (rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_TWO_STRAIGHT or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_BOMB or rparam.m_eCardType==ECardType.DDZ_CARD_TYPE_ROCKET
                    or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_SOFTBOMB or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_TIANBOMB) then
                return false
            end
            if rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_BOMB or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_ROCKET
                    or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_SOFTBOMB or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_TIANBOMB then
                return true
            end
            if lparam.m_eCardType == rparam.m_eCardType then
                if lparam.m_nLen ~= rparam.m_nLen then
                    return false
                else
                    if lparam.m_keyMaxValue < rparam.m_keyMaxValue then
                        return true
                    else
                        return false
                    end
                end
            end
            return false
        end
    },
    ---8.三顺
    [ECardType.DDZ_CARD_TYPE_THREE_STRAIGHT] = {
        isMatched = function(CardsObject)
            if CardsObject.m_nLen < 6 or CardsObject.m_nLen % 3 ~= 0 then
                return false, ECardType.DDZ_CARD_TYPE_UNKNOWN
            end
            for i = 1, CardsObject.m_nLen, 3 do
                if CardsValue[CardsObject[i]+1] and CardsValue[CardsObject[i+1]+1] and CardsValue[CardsObject[i+2]+1] then
                    if CardsValue[CardsObject[i]+1] ~= CardsValue[CardsObject[i+1]+1] or CardsValue[CardsObject[i]+1] ~= CardsValue[CardsObject[i+2]+1] then
                        return false, ECardType.DDZ_CARD_TYPE_UNKNOWN
                    end
                    if CardsValue[CardsObject[i]+1] >= 15 or CardsValue[CardsObject[i+1]+1] >= 15 or CardsValue[CardsObject[i+2]+1] >= 15 then
                        return false, ECardType.DDZ_CARD_TYPE_UNKNOWN
                    end
                    if CardsObject[i+3] and CardsValue[CardsObject[i+3]+1] then
                        if CardsValue[CardsObject[i]+1] ~= CardsValue[CardsObject[i+3]+1] + 1 then return false, ECardType.DDZ_CARD_TYPE_UNKNOWN end
                    end
                else
                    return false, ECardType.DDZ_CARD_TYPE_UNKNOWN
                end
            end
            CardsObject.m_keyMaxValue = CardsValue[CardsObject[1]+1]
            return true, ECardType.DDZ_CARD_TYPE_THREE_STRAIGHT
        end,
        getBigger = function(cardscontainer,srcbeg,srclen,isdibomb)
            if not cardscontainer or #cardscontainer.three <= 0 or not srcbeg or not srclen then return false end
            if #cardscontainer.three < srclen then return false end
            local len_src = (srclen == 0) and #cardscontainer.three or srclen
            local basevalue = srcbeg
            local bigger_cards = {}
            local isFind = true
            for i = #cardscontainer.three,1,-3 do
                if CardsValue[cardscontainer.three[i]+1] > basevalue then
                    if #bigger_cards == 0 then
                        table.insert(bigger_cards,cardscontainer.three[i])
                        table.insert(bigger_cards,cardscontainer.three[i-1])
                        table.insert(bigger_cards,cardscontainer.three[i-2])
                    elseif #bigger_cards > 0 and #bigger_cards < len_src then
                        if CardsValue[bigger_cards[#bigger_cards]+1] + 1 == CardsValue[cardscontainer.three[i]+1] then
                            table.insert(bigger_cards,cardscontainer.three[i])
                            table.insert(bigger_cards,cardscontainer.three[i-1])
                            table.insert(bigger_cards,cardscontainer.three[i-2])
                        else
                            if srclen == 0 and #bigger_cards >= 6 then return isFind,bigger_cards end
                            bigger_cards = {}
                        end
                    end
                    basevalue = CardsValue[cardscontainer.three[i]+1]
                end
            end
            if #bigger_cards < 6 then
                isFind = false
                bigger_cards = {}
            end
            return isFind,bigger_cards
        end,
        isBigThan = function(lparam,rparam)
            if lparam.m_eCardType ~= ECardType.DDZ_CARD_TYPE_THREE_STRAIGHT or not
                (rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_THREE_STRAIGHT or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_BOMB or rparam.m_eCardType==ECardType.DDZ_CARD_TYPE_ROCKET
                    or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_SOFTBOMB or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_TIANBOMB) then
                return false
            end
            if rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_BOMB or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_ROCKET
                    or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_SOFTBOMB or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_TIANBOMB then
                return true
            end
            if lparam.m_eCardType == rparam.m_eCardType then
                if lparam.m_nLen ~= rparam.m_nLen then
                    return false
                else
                    if lparam.m_keyMaxValue < rparam.m_keyMaxValue then
                        return true
                    else
                        return false
                    end
                end
            end
            return false
        end
    },
    ---9.三带一
    [ECardType.DDZ_CARD_TYPE_THREE_ONE] = {
        isMatched = function(CardsObject)
            if CardsObject.m_nLen ~= 4 then
                return false, ECardType.DDZ_CARD_TYPE_UNKNOWN
            end
            if CardsValue[CardsObject[1]+1] == CardsValue[CardsObject[2]+1] and CardsValue[CardsObject[1]+1] == CardsValue[CardsObject[3]+1]
                        and CardsValue[CardsObject[1]+1] ~= CardsValue[CardsObject[4]+1] then
                CardsObject.m_keyMaxValue = CardsValue[CardsObject[1]+1]
                return true,ECardType.DDZ_CARD_TYPE_THREE_ONE
            elseif CardsValue[CardsObject[2]+1] == CardsValue[CardsObject[3]+1] and CardsValue[CardsObject[2]+1] == CardsValue[CardsObject[4]+1]
                    and CardsValue[CardsObject[1]+1] ~= CardsValue[CardsObject[2]+1] then
                CardsObject.m_keyMaxValue = CardsValue[CardsObject[2]+1]
                return true,ECardType.DDZ_CARD_TYPE_THREE_ONE
            end
            return false, ECardType.DDZ_CARD_TYPE_UNKNOWN
        end,
        getBigger = function(cardscontainer,srcbeg,srclen,isdibomb)
            local status, recards = DDZGameLogic.getBiggerCards(cardscontainer,srcbeg,3)
            if status == true then
                local substatus, subrecards = DDZGameLogic.getSubCards(cardscontainer,1,recards)
                if substatus == true then
                    for key,value in ipairs(subrecards) do
                        table.insert(recards,value)
                    end
                    if srclen ~= 0 and srclen ~= #recards then
                        substatus = false
                    end
                    return substatus, recards
                end
            end
        end,
        isBigThan = function(lparam,rparam)
            if lparam.m_eCardType ~= ECardType.DDZ_CARD_TYPE_THREE_ONE or not
                (rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_THREE_ONE or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_BOMB or rparam.m_eCardType==ECardType.DDZ_CARD_TYPE_ROCKET
                    or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_SOFTBOMB or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_TIANBOMB) then
                return false
            end
            if rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_BOMB or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_ROCKET
                    or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_SOFTBOMB or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_TIANBOMB then
                return true
            end
            if lparam.m_eCardType == rparam.m_eCardType then
                if lparam.m_nLen ~= rparam.m_nLen then
                    return false
                else
                    if lparam.m_keyMaxValue < rparam.m_keyMaxValue then
                        return true
                    else
                        return false
                    end
                end
            end
            return false
        end
    },
    ----10.三带二
    [ECardType.DDZ_CARD_TYPE_THREE_PAIR] = {
        isMatched = function(CardsObject)
            if CardsObject.m_nLen ~= 5 then
                return false, ECardType.DDZ_CARD_TYPE_UNKNOWN
            end
            if(CardsValue[CardsObject[1]+1] == CardsValue[CardsObject[2]+1] and CardsValue[CardsObject[1]+1] == CardsValue[CardsObject[3]+1]
                and CardsValue[CardsObject[4]+1] == CardsValue[CardsObject[5]+1]) or (CardsValue[CardsObject[1]+1] == CardsValue[CardsObject[2]+1] and
                    CardsValue[CardsObject[3]+1] == CardsValue[CardsObject[4]+1] and CardsValue[CardsObject[3]+1] == CardsValue[CardsObject[5]+1]) then
                CardsObject.m_keyMaxValue = CardsValue[CardsObject[3]+1]
                return true, ECardType.DDZ_CARD_TYPE_THREE_PAIR
            end
            return false, ECardType.DDZ_CARD_TYPE_UNKNOWN
        end,
        getBigger = function(cardscontainer,srcbeg,srclen,isdibomb)
            local status, recards = DDZGameLogic.getBiggerCards(cardscontainer,srcbeg,3)
            if status == true then
                local substatus, subrecards = DDZGameLogic.getSubCards(cardscontainer,2,recards)
                if substatus == true then
                    for key,value in ipairs(subrecards) do
                        table.insert(recards,value)
                    end
                    if srclen ~= 0 and srclen ~= #recards then
                        substatus = false
                    end
                    return substatus, recards
                end
            end
        end,
        isBigThan = function(lparam,rparam)
            if lparam.m_eCardType ~= ECardType.DDZ_CARD_TYPE_THREE_PAIR or not
                (rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_THREE_PAIR or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_BOMB or rparam.m_eCardType==ECardType.DDZ_CARD_TYPE_ROCKET
                    or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_SOFTBOMB or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_TIANBOMB) then
                return false
            end
            if rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_BOMB or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_ROCKET
                    or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_SOFTBOMB or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_TIANBOMB then
                return true
            end
            if lparam.m_eCardType == rparam.m_eCardType then
                if lparam.m_nLen ~= rparam.m_nLen then
                    return false
                else
                    if lparam.m_keyMaxValue < rparam.m_keyMaxValue then
                        return true
                    else
                        return false
                    end
                end
            end
            return false
        end
    },
    ----11.飞机带翅膀(单)
    [ECardType.DDZ_CARD_TYPE_THREE_WING_ONE] = {
        isMatched = function(CardsObject)
            if CardsObject.m_nLen < 8 or CardsObject.m_nLen % 4 ~= 0 then
                return false, ECardType.DDZ_CARD_TYPE_UNKNOWN
            end
            local mainValue = {}
            local num = math.floor(CardsObject.m_nLen / 4)
            for i = 2,CardsObject.m_nLen do
                if CardsObject[i] and CardsObject[i-1] and CardsObject[i-2] and (CardsValue[CardsObject[i]+1] == CardsValue[CardsObject[i-1]+1]
                        and CardsValue[CardsObject[i]+1] == CardsValue[CardsObject[i-2]+1]) then
                    local flag = CardHelper:isContainInCards({CardsValue[CardsObject[i]+1]},mainValue)
                    if flag == false then table.insert(mainValue,CardsValue[CardsObject[i]+1]) end
                end
            end
            table.sort(mainValue,function(a,b) return a>b end)
            for i = 1,#mainValue do
                local flag = true
                for j = 1,num-1 do
                    local target = mainValue[i] - j
                    flag = CardHelper:isContainInCards({target},mainValue)
                    if flag == false then break end
                end
                if flag == true then
                    CardsObject.m_keyMaxValue = mainValue[1]
                    return true, ECardType.DDZ_CARD_TYPE_THREE_WING_ONE
                end
            end
            return false, ECardType.DDZ_CARD_TYPE_UNKNOWN
        end,
        getBigger = function(cardscontainer,srcbeg,srclen,isdibomb)
            if not cardscontainer or #cardscontainer.three <= 0 or not srcbeg or not srclen then return false end
            ----if #cardscontainer.three < srclen then return false end
            local len_src = (srclen == 0) and #cardscontainer.three or srclen
            local basevalue = srcbeg
            local bigger_cards = {}
            local sub_cards = {}
            local isFind = true
            for i = #cardscontainer.three,1,-3 do
                if CardsValue[cardscontainer.three[i]+1] > basevalue then
                    if #bigger_cards == 0 then
                        local status, recards = DDZGameLogic.getSubCards(cardscontainer,1,sub_cards)
                        if status == true then
                            table.insert(sub_cards,recards[1])
                            table.insert(bigger_cards,cardscontainer.three[i])
                            table.insert(bigger_cards,cardscontainer.three[i-1])
                            table.insert(bigger_cards,cardscontainer.three[i-2])
                        end
                    elseif #bigger_cards > 0 and #bigger_cards < len_src then
                        if CardsValue[bigger_cards[#bigger_cards]+1] + 1 == CardsValue[cardscontainer.three[i]+1] then
                            local status, recards = DDZGameLogic.getSubCards(cardscontainer,1,sub_cards)
                            if status == true then
                                table.insert(sub_cards,recards[1])
                                table.insert(bigger_cards,cardscontainer.three[i])
                                table.insert(bigger_cards,cardscontainer.three[i-1])
                                table.insert(bigger_cards,cardscontainer.three[i-2])
                            end
                        else
                            if srclen == 0 and #bigger_cards >= 6 then break end
                            bigger_cards = {}
                            sub_cards = {}
                        end
                    end
                    basevalue = CardsValue[cardscontainer.three[i]+1]
                end
            end
            if #bigger_cards < 6 then
                isFind = false
                bigger_cards = {}
                sub_cards = {}
            end
            for k,v in ipairs(sub_cards) do
                table.insert(bigger_cards,v)
            end
            if srclen > 0 then
                if #bigger_cards ~= srclen or #bigger_cards < 8 then isFind = false bigger_cards = {} end
            end
            return isFind, bigger_cards
        end,
        isBigThan = function(lparam, rparam)
            if lparam.m_eCardType ~= ECardType.DDZ_CARD_TYPE_THREE_WING_ONE or not
            (rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_THREE_WING_ONE or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_BOMB or rparam.m_eCardType==ECardType.DDZ_CARD_TYPE_ROCKET
                    or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_SOFTBOMB or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_TIANBOMB) then
                return false
            end
            if rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_BOMB or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_ROCKET
                    or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_SOFTBOMB or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_TIANBOMB then
                return true
            end
            if lparam.m_eCardType == rparam.m_eCardType then
                if lparam.m_nLen ~= rparam.m_nLen then
                    return false
                else
                    if lparam.m_keyMaxValue < rparam.m_keyMaxValue then
                        return true
                    else
                        return false
                    end
                end
            end
            return false
        end
    },
    ----12.飞机带翅膀(双)
    [ECardType.DDZ_CARD_TYPE_THREE_WING_PAIR] = {
        isMatched = function(CardsObject)
            if CardsObject.m_nLen < 10 or CardsObject.m_nLen % 5 ~= 0 then
                return false, ECardType.DDZ_CARD_TYPE_UNKNOWN
            end
            local mainValue = {}
            local num = math.floor(CardsObject.m_nLen / 5)
            local sub = {}
            for i = 2, CardsObject.m_nLen do
                if CardsObject[i] and CardsObject[i-1] and CardsObject[i-2] and (CardsValue[CardsObject[i]+1] == CardsValue[CardsObject[i-1]+1]
                        and CardsValue[CardsObject[i]+1] == CardsValue[CardsObject[i-2]+1] and CardsValue[CardsObject[i]+1] ~= 15) then
                    local flag = false
                    local idx = -1
                    for j = 1, num do
                        if mainValue[i] == CardsValue[CardsObject[i]+1] then
                            flag = true
                            idx = j
                            break
                        end
                    end
                    if flag == false then
                        table.insert(mainValue,CardsValue[CardsObject[i]+1])
                    else
                        table.remove(mainValue,idx)
                    end
                end
            end
            for i = 1,CardsObject.m_nLen do
                local flag = CardHelper:isContainInCards({CardsValue[CardsObject[i]+1]},mainValue)
                if flag == false then
                    table.insert(sub,CardsValue[CardsObject[i]+1])
                end
            end
            table.sort(sub,function(a,b) return a>b  end)
            for i = 1, #sub,2 do
                if sub[i] and sub[i+1] and sub[i+1] ~= sub[i] then
                    return false, ECardType.DDZ_CARD_TYPE_UNKNOWN
                end
            end
            table.sort(mainValue,function(a,b) return a>b end)
            for i = 1, #mainValue do
                local flag = true
                for j = 1, num-1 do
                    local target = mainValue[i] - j
                    flag = CardHelper:isContainInCards({target},mainValue)
                    if flag == false then break end
                end
                if flag == true then
                    CardsObject.m_keyMaxValue = mainValue[1]
                    return true, ECardType.DDZ_CARD_TYPE_THREE_WING_PAIR
                end
            end
            return false, ECardType.DDZ_CARD_TYPE_UNKNOWN
        end,
        getBigger = function(cardscontainer,srcbeg,srclen,isdibomb)
            if not cardscontainer or #cardscontainer.three <= 0 or not srcbeg or not srclen then return false end
            ---if #cardscontainer.three < srclen then return false end
            local len_src = (srclen == 0) and #cardscontainer.three or srclen
            local basevalue = srcbeg
            local bigger_cards = {}
            local sub_cards = {}
            local isFind = true
            for i = #cardscontainer.three,1,-3 do
                if CardsValue[cardscontainer.three[i]+1] > basevalue then
                    if #bigger_cards == 0 then
                        local status, recards = DDZGameLogic.getSubCards(cardscontainer,2,sub_cards)
                        if status == true then
                            for k,v in ipairs(recards) do
                                table.insert(sub_cards,v)
                            end
                            table.insert(bigger_cards,cardscontainer.three[i])
                            table.insert(bigger_cards,cardscontainer.three[i-1])
                            table.insert(bigger_cards,cardscontainer.three[i-2])
                        end
                    elseif #bigger_cards > 0 and #bigger_cards < len_src then
                        if CardsValue[bigger_cards[#bigger_cards]+1] + 1 == CardsValue[cardscontainer.three[i]+1] then
                            local status, recards = DDZGameLogic.getSubCards(cardscontainer,2,sub_cards)
                            if status == true then
                                for k,v in ipairs(recards) do
                                    table.insert(sub_cards,v)
                                end
                                table.insert(bigger_cards,cardscontainer.three[i])
                                table.insert(bigger_cards,cardscontainer.three[i-1])
                                table.insert(bigger_cards,cardscontainer.three[i-2])
                            end
                        else
                            if srclen == 0 and #bigger_cards >= 6 then break end
                            bigger_cards = {}
                            sub_cards = {}
                        end
                    end
                    basevalue = CardsValue[cardscontainer.three[i]+1]
                end
            end
            if #bigger_cards < 6 then
                isFind = false
                bigger_cards = {}
                sub_cards = {}
            end
            for k,v in ipairs(sub_cards) do
                table.insert(bigger_cards,v)
            end
            if srclen > 0 then
                if #bigger_cards ~= srclen or #bigger_cards < 10 then isFind = false bigger_cards = {} end
            end
            return isFind, bigger_cards
        end,
        isBigThan = function(lparam,rparam)
            if lparam.m_eCardType ~= ECardType.DDZ_CARD_TYPE_THREE_WING_PAIR or not
            (rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_THREE_WING_PAIR or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_BOMB or rparam.m_eCardType==ECardType.DDZ_CARD_TYPE_ROCKET
                    or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_SOFTBOMB or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_TIANBOMB) then
                return false
            end
            if rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_BOMB or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_ROCKET
                    or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_SOFTBOMB or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_TIANBOMB then
                return true
            end
            if lparam.m_eCardType == rparam.m_eCardType then
                if lparam.m_nLen ~= rparam.m_nLen then
                    return false
                else
                    if lparam.m_keyMaxValue < rparam.m_keyMaxValue then
                        return true
                    else
                        return false
                    end
                end
            end
            return false
        end
    },
    -----13.四带二张
    [ECardType.DDZ_CARD_TYPE_FOUR_TWO_ONE] = {
        isMatched = function(CardsObject)
            if CardsObject.m_nLen ~= 6 then
                return false, ECardType.DDZ_CARD_TYPE_UNKNOWN
            end
            for i = 1,3 do
                if (CardsValue[CardsObject[i]+1] == CardsValue[CardsObject[i+1]+1] and CardsValue[CardsObject[i]+1] == CardsValue[CardsObject[i+2]+1]
                    and CardsValue[CardsObject[i]+1] == CardsValue[CardsObject[i+3]+1]) then
                    CardsObject.m_keyMaxValue = CardsValue[CardsObject[i]+1]
                    return true, ECardType.DDZ_CARD_TYPE_FOUR_TWO_ONE
                end
            end
            return false, ECardType.DDZ_CARD_TYPE_UNKNOWN
        end,
        getBigger = function(cardscontainer,srcbeg,srclen,isdibomb)
            local status, recards = DDZGameLogic.getBiggerCards(cardscontainer,srcbeg,4)
            if status == true then
                local substatus, subrecards = DDZGameLogic.getSubCards(cardscontainer,1,recards)
                if substatus == true then
                    table.insert(recards,subrecards[1])
                    local subsec, subsecrecards = DDZGameLogic.getSubCards(cardscontainer,1,recards)
                    if subsec == true then
                        table.insert(recards,subsecrecards[1])
                        if #recards ~= 6 then subsec = false end
                        return subsec, recards
                    end
                else
                    local substatus, subrecards = DDZGameLogic.getSubCards(cardscontainer, 2, recards)
                    if substatus == true then
                        for k,v in pairs(subrecards) do
                            table.insert(recards,v)
                        end
                        if #recards ~= 6 then substatus = false end
                        return substatus, recards
                    end
                end
            end
            return false
        end,
        isBigThan = function(lparam, rparam)
            if lparam.m_eCardType ~= ECardType.DDZ_CARD_TYPE_FOUR_TWO_ONE or not
            (rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_FOUR_TWO_ONE or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_BOMB or rparam.m_eCardType==ECardType.DDZ_CARD_TYPE_ROCKET
                    or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_SOFTBOMB or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_TIANBOMB) then
                return false
            end
            if rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_BOMB or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_ROCKET
                    or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_SOFTBOMB or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_TIANBOMB then
                return true
            end
            if lparam.m_eCardType == rparam.m_eCardType then
                if lparam.m_nLen ~= rparam.m_nLen then
                    return false
                else
                    if lparam.m_keyMaxValue < rparam.m_keyMaxValue then
                        return true
                    else
                        return false
                    end
                end
            end
            return false
        end
    },
    -----14.四代两对
    [ECardType.DDZ_CARD_TYPE_FOUR_TWO_PAIR] = {
        isMatched = function(CardsObject)
            if CardsObject.m_nLen ~= 8 then
                return false, ECardType.DDZ_CARD_TYPE_UNKNOWN
            end
            local mainValue = {}
            local tempValue = {}
            for i = 1,5 do
                if (CardsValue[CardsObject[i]+1] == CardsValue[CardsObject[i+1]+1] and CardsValue[CardsObject[i]+1] == CardsValue[CardsObject[i+2]+1]
                    and CardsValue[CardsObject[i]+1] == CardsValue[CardsObject[i+3]+1]) then
                    table.insert(mainValue,CardsValue[CardsObject[i]+1])
                end
            end
            if #mainValue == 1 then
                for i = 1, CardsObject.m_nLen do
                    if mainValue[1] ~= CardsValue[CardsObject[i]+1] then table.insert(tempValue,CardsValue[CardsObject[i]+1]) end
                end
                for i = 1, #tempValue,2 do
                    if tempValue[i] and tempValue[i+1] and tempValue[i] ~= tempValue[i+1] then
                        return false, ECardType.DDZ_CARD_TYPE_UNKNOWN
                    end
                end
                CardsObject.m_keyMaxValue = mainValue[1]
                return true, ECardType.DDZ_CARD_TYPE_FOUR_TWO_PAIR
            elseif #mainValue == 2 then
                CardsObject.m_keyMaxValue = (mainValue[1] > mainValue[2]) and mainValue[1] or mainValue[2]
                return true, ECardType.DDZ_CARD_TYPE_FOUR_TWO_PAIR
            end
            return false, ECardType.DDZ_CARD_TYPE_UNKNOWN
        end,
        getBigger = function(cardscontainer,srcbeg,srclen,isdibomb)
            local status, recards = DDZGameLogic.getBiggerCards(cardscontainer,srcbeg,4)
            if status == true then
                local firstatus, firrecards = DDZGameLogic.getSubCards(cardscontainer,2,recards)
                if firstatus == true then
                    for k,v in ipairs(firrecards) do
                        table.insert(recards,v)
                    end
                    local secstatus, secrecards = DDZGameLogic.getSubCards(cardscontainer,2,recards)
                    if secstatus == true then
                        for k,v in ipairs(secrecards) do
                            table.insert(recards,v)
                        end
                        if #recards ~= 8 then secstatus = false end
                        return secstatus, recards
                    end
                end
            end
            return false
        end,
        isBigThan = function(lparam, rparam)
            if lparam.m_eCardType ~= ECardType.DDZ_CARD_TYPE_FOUR_TWO_PAIR or not
                (rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_FOUR_TWO_PAIR or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_BOMB or rparam.m_eCardType==ECardType.DDZ_CARD_TYPE_ROCKET
                    or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_SOFTBOMB or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_TIANBOMB) then
                return false
            end
            if rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_BOMB or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_ROCKET
                    or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_SOFTBOMB or rparam.m_eCardType == ECardType.DDZ_CARD_TYPE_TIANBOMB then
                return true
            end
            if lparam.m_eCardType == rparam.m_eCardType then
                if lparam.m_nLen ~= rparam.m_nLen then
                    return false
                else
                    if lparam.m_keyMaxValue < rparam.m_keyMaxValue then
                        return true
                    else
                        return false
                    end
                end
            end
            return false
        end
    },
}

function CardHelper:new(obj)
    obj = obj or {}
    setmetatable(obj, self)
    self.__index = self
    --self.__newindex = self
    return obj
end
function CardHelper:sortCards(cardsObj)
    if not cardsObj or type(cardsObj) ~= "table" or #cardsObj == 0 then return end
    table.sort(cardsObj,
        function(lobj,robj)
            if CardsValue[lobj+1] and CardsValue[robj+1] then
                return CardsValue[lobj+1] > CardsValue[robj+1]
            end
        end)
end
function CardHelper:Init(cardsObj)
    ---对一个牌堆排序,大值在前
    CardHelper:sortCards(cardsObj)
    cardsObj.m_nLen = #cardsObj
end


function CardHelper:GetCardsType(cardsObj)
    for k,v in ipairs(CardRuler) do
        local success,cardType = v.isMatched(cardsObj)
        if success then
            cardsObj.m_eCardType = cardType
            break
        end
    end
end
function CardHelper:isContainInCards(cardsObj, Contain)
    if #cardsObj > #Contain then return false end
    local equalNum = 0
    for key,value in ipairs(cardsObj) do
        for m,n in ipairs(Contain) do
            if value == n then equalNum = equalNum + 1 end
        end
    end
    if equalNum > 0 and equalNum == #cardsObj then
        return true
    else
        return false
    end
end
function CardHelper:CompareCards(lCards, rCards)
    if lCards.m_eCardType == ECardType.DDZ_CARD_TYPE_UNKNOWN then CardHelper:GetCardsType(lCards) end
    if rCards.m_eCardType == ECardType.DDZ_CARD_TYPE_UNKNOWN then CardHelper:GetCardsType(rCards) end
    local reflag = false
    reflag = CardRuler[lCards.m_eCardType].isBigThan(lCards,rCards)
    return reflag
end


function DDZGameLogic:new(obj)
    obj = obj or {}
    setmetatable(obj, self)
    self.__index = self
    return obj
end
function DDZGameLogic.InitCards(gameobj)
    ----生成牌池
    if gameobj.initCards == nil then
        gameobj.initCards = tabletool.deepcopy(CardsKey)
    end
end
function DDZGameLogic.Riffle(gameobj)
    ----对牌池中的牌洗牌
    if #gameobj.initCards ~= MaxCardNum then return end
    local tableid = gameobj.id
    local tmp_seed = base.RNG()
    if tmp_seed == nil then
        tmp_seed = timetool.get_10ms_time() + (tableid or 0)
    end
    math.randomseed(tmp_seed)

    for i = 1,#gameobj.initCards do
        local ranOne = base.get_random(1,#gameobj.initCards+1-i)
        gameobj.initCards[ranOne], gameobj.initCards[#gameobj.initCards+1-i] = gameobj.initCards[#gameobj.initCards+1-i],gameobj.initCards[ranOne]
    end
end
function DDZGameLogic.PostCards(gameobj, beginseatindex)
    if #gameobj.initCards ~= MaxCardNum then return end
    local sendtoIndex = beginseatindex
    for i = 1,MaxCardNum do
        if gameobj.initCards[1] then
            if gameobj.seats[sendtoIndex].cards == nil then gameobj.seats[sendtoIndex].cards = {} end
            if gameobj.seats[sendtoIndex] and #gameobj.seats[sendtoIndex].cards < 17 then
                table.insert(gameobj.seats[sendtoIndex].cards,gameobj.initCards[1])
                table.remove(gameobj.initCards, 1)
            end
            if #gameobj.seats[sendtoIndex].cards >= 17 then
                if sendtoIndex == 1 then
                    sendtoIndex = 2
                elseif sendtoIndex == 2 then
                    sendtoIndex = 3
                elseif sendtoIndex == 3 then
                    sendtoIndex = 1
                end
            end
        end
    end
    for k,v in ipairs(gameobj.seats) do
        CardHelper:sortCards(v.cards)
    end
end
function DDZGameLogic.CreateCardsHelper(cards)
    local cardsHelper = CardHelper:new(cards)
    CardHelper:Init(cardsHelper)
    return cardsHelper
end
function DDZGameLogic.SortCards(cards)
    CardHelper:sortCards(cards)
end

function DDZGameLogic.extract(cards)
    local count = 0
    local container = {
        single = {},
        pair   = {},
        three  = {},
        sitiao = {}
    }
    for i = 1,#cards do
        for m = 1,#cards do
            if CardsValue[cards[i]+1] == CardsValue[cards[m]+1] then
                count = count + 1
            end
        end
        if count == 1 then
            table.insert(container.single,cards[i])
        elseif count == 2 then
            table.insert(container.pair,cards[i])
        elseif count == 3 then
            table.insert(container.three,cards[i])
        elseif count == 4 then
            table.insert(container.sitiao,cards[i])
        end
        count = 0
    end
    for key,value in pairs(container) do
        CardHelper:sortCards(value)
    end
    return container
end
---
-- @param container
-- @param m_keyMaxValue
-- @param m_nLen
--
function DDZGameLogic.getBiggerCards(container,m_keyMaxValue,m_nLen)
    local cardsre = {}
    if not container then return false end
    if m_nLen <= 1 then
        if not container.single or #container.single == 0 then return false end
        local status, recards = CardRuler[ECardType.DDZ_CARD_TYPE_ROCKET].getWangzha(container.single)
        for i = #container.single,1,-1 do
            if CardsValue[container.single[i]+1] > m_keyMaxValue then
                if status == true and CardsValue[container.single[i]+1] < 16 then
                    table.insert(cardsre,container.single[i])
                else
                    table.insert(cardsre,container.single[i])
                end
                return true, cardsre
            end
        end 
    elseif m_nLen == 2 then
        if not container.pair or #container.pair == 0 then return false end
        for i = #container.pair,1,-1 do
            if CardsValue[container.pair[i]+1] > m_keyMaxValue then
                for m = 1,m_nLen do
                    table.insert(cardsre,container.pair[i-m+1])
                end
                return true, cardsre
            end
        end
    elseif m_nLen == 3 then
        if not container.three or #container.three == 0 then return false end
        for i = #container.three,1,-1 do
            if CardsValue[container.three[i]+1] > m_keyMaxValue then
                for m = 1, m_nLen do
                    table.insert(cardsre,container.three[i-m+1])
                end
                return true, cardsre
            end
        end
    elseif m_nLen == 4 then
        if not container.sitiao or #container.sitiao == 0 then return false end
        for i = #container.sitiao,1,-1 do
            if CardsValue[container.sitiao[i]+1] > m_keyMaxValue then
                for m = 1, m_nLen do
                    table.insert(cardsre,container.sitiao[i-m+1])
                end
                return true, cardsre
            end
        end
    end
    return false
end

---@ 从container中取一组辅牌, 单牌/对子/三条;
---@ container = {single:{},pair:{},three:{},sitiao:{}}
---@ len:1/2/3, 单牌/对子/三条, 类型长度;
---@ excludes: 需要排除的数值,
---@ return false,nil (true, recards)
function DDZGameLogic.getSubCards(container, len, excludes)
    -- body
    local recards = {}
    if not container or len <= 0 then return false end
    if len == 1 then
        local hastwojk = false
        if #container.single <= 0 then 
            return false 
        elseif #container.single >=2 then
            if CardsValue[container.single[1]+1] >=16 and CardsValue[container.single[2]+1] >= 16 then hastwojk = true end
        end
        for k = #container.single,1,-1 do
            if hastwojk then
                if CardsValue[container.single[k]+1] < 16 then
                    local flag = CardHelper:isContainInCards({container.single[k]},excludes)
                    if flag == false then
                        table.insert(recards,container.single[k])
                        return true, recards
                    end
                end
            else
                local flag = CardHelper:isContainInCards({container.single[k]},excludes)
                if flag == false then
                    table.insert(recards,container.single[k])
                    return true, recards
                end
            end
        end
    elseif len == 2 then
        if #container.pair == 0 then return false end
        for k = #container.pair,1,-1 do
            local flag = CardHelper:isContainInCards({container.pair[k]},excludes)
            if flag == false then
                for m = 1,len do
                    table.insert(recards,container.pair[k-m+1])
                end
            end
            if #recards == 2 then return true, recards end
        end
    elseif len == 3 then
        if #container.three == 0 then return false end
        for k = #container.three,1,-1 do
            for m = 1, len do
                local flag = CardHelper:isContainInCards({container.three[k-m+1]},excludes)
                if flag == false then table.insert(recards,container.three[k-m+1]) end
            end
            return true, recards
        end
    end
    return false 
end

----根据上一家玩家出的牌,从手牌中筛选出能大得过上一家的牌
----@@ cards 手牌 playercards 上一家玩家出的牌 isfindbomb 是否找炸弹
function DDZGameLogic.getCardsbyCardType(cards, playercards, isfindbomb)
    if playercards.m_eCardType == nil or playercards.m_eCardType == ECardType.DDZ_CARD_TYPE_UNKNOWN 
        or playercards.m_eCardType == ECardType.DDZ_CARD_TYPE_ROCKET then
        return false
    end
    local cardscontainer = DDZGameLogic.extract(cards)
    if playercards.m_eCardType == ECardType.DDZ_CARD_TYPE_SINGLE then       ---单牌
        local status, recards = DDZGameLogic.getBiggerCards(cardscontainer,playercards.m_keyMaxValue,playercards.m_nLen)
        if status == true then return true, recards end
    elseif playercards.m_eCardType == ECardType.DDZ_CARD_TYPE_PAIR then     ----对子
        local status, recards = DDZGameLogic.getBiggerCards(cardscontainer,playercards.m_keyMaxValue,playercards.m_nLen)
        if status == true then return true, recards end
    elseif playercards.m_eCardType == ECardType.DDZ_CARD_TYPE_THREE then    ------三不带
        local status, recards = CardRuler[ECardType.DDZ_CARD_TYPE_THREE].getBigger(cardscontainer,playercards.m_keyMaxValue,playercards.m_nLen,1)
        if status == true then return true, recards end
    elseif playercards.m_eCardType == ECardType.DDZ_CARD_TYPE_BOMB then     ------炸弹
        local status, recards = DDZGameLogic.getBiggerCards(cardscontainer,playercards.m_keyMaxValue,playercards.m_nLen)
        if status == true then return true, recards end
    elseif playercards.m_eCardType == ECardType.DDZ_CARD_TYPE_ONE_STRAIGHT then ---顺子
        local status, recards = CardRuler[ECardType.DDZ_CARD_TYPE_ONE_STRAIGHT].getBigger(cards,playercards.m_keyMaxValue,playercards.m_nLen,1)
        if status == true then return true, recards end
    elseif playercards.m_eCardType == ECardType.DDZ_CARD_TYPE_TWO_STRAIGHT then  ---连对
        local status, recards = CardRuler[ECardType.DDZ_CARD_TYPE_TWO_STRAIGHT].getBigger(cardscontainer,playercards.m_keyMaxValue,playercards.m_nLen,1)
        if status == true then return status, recards end
    elseif playercards.m_eCardType == ECardType.DDZ_CARD_TYPE_THREE_STRAIGHT then   ----飞机不带
        local status, recards = CardRuler[ECardType.DDZ_CARD_TYPE_THREE_STRAIGHT].getBigger(cardscontainer,playercards.m_keyMaxValue,playercards.m_nLen,1)
        if status == true then return status, recards end
    elseif playercards.m_eCardType == ECardType.DDZ_CARD_TYPE_THREE_WING_ONE then   -----飞机带单
        local status, recards = CardRuler[ECardType.DDZ_CARD_TYPE_THREE_WING_ONE].getBigger(cardscontainer,playercards.m_keyMaxValue,playercards.m_nLen,1)
        if status == true then return status, recards end
    elseif playercards.m_eCardType == ECardType.DDZ_CARD_TYPE_THREE_WING_PAIR then   ----飞机带对
        local status, recards = CardRuler[ECardType.DDZ_CARD_TYPE_THREE_WING_PAIR].getBigger(cardscontainer,playercards.m_keyMaxValue,playercards.m_nLen,1)
        if status == true then return status, recards end
    elseif playercards.m_eCardType == ECardType.DDZ_CARD_TYPE_THREE_ONE then        -----三带一
        if playercards.m_nLen ~= 4 then return false end
        local status, recards = CardRuler[ECardType.DDZ_CARD_TYPE_THREE_ONE].getBigger(cardscontainer,playercards.m_keyMaxValue,playercards.m_nLen,1)
        if status == true then return status, recards end
    elseif playercards.m_eCardType == ECardType.DDZ_CARD_TYPE_THREE_PAIR then       ----三带一对
        if playercards.m_nLen ~= 5 then return false end
        local status, recards = CardRuler[ECardType.DDZ_CARD_TYPE_THREE_PAIR].getBigger(cardscontainer,playercards.m_keyMaxValue,playercards.m_nLen,1)
        if status == true then return status, recards end
    elseif playercards.m_eCardType == ECardType.DDZ_CARD_TYPE_FOUR_TWO_ONE then  -----四带二
        if playercards.m_nLen ~= 6 then return false end
        local status, recards = CardRuler[ECardType.DDZ_CARD_TYPE_FOUR_TWO_ONE].getBigger(cardscontainer,playercards.m_keyMaxValue,playercards.m_nLen,1)
        if status == true then return status, recards end
    elseif playercards.m_eCardType == ECardType.DDZ_CARD_TYPE_FOUR_TWO_PAIR then  -----四带两对
        if playercards.m_nLen ~= 8 then return false end
        local status, recards = CardRuler[ECardType.DDZ_CARD_TYPE_FOUR_TWO_PAIR].getBigger(cardscontainer,playercards.m_keyMaxValue,playercards.m_nLen,1)
        if status == true then return status, recards end
    elseif playercards.m_eCardType == ECardType.DDZ_CARD_TYPE_SOFTBOMB then

    elseif playercards.m_eCardType == ECardType.DDZ_CARD_TYPE_TIANBOMB then

    end
    if isfindbomb == true then
        local status, recards = DDZGameLogic.getBiggerCards(cardscontainer,0,4)
        if status == true then return status, recards end
        local ststatus, strecords = CardRuler[ECardType.DDZ_CARD_TYPE_ROCKET].getWangzha(cardscontainer.single)
        if ststatus == true then  return ststatus, strecords  end
    end
    return false 
end

------该玩家出牌时主动为玩家挑选牌
------@cards 玩家手牌
------@isbomb 是否拆炸弹
function DDZGameLogic.activePutsCards(cards,isbomb)
    if not cards or #cards == 0 then return false end
    local cardscontainer = DDZGameLogic.extract(cards)
    for key, value in ipairs(PutsCardsOrder) do
        if value == ECardType.DDZ_CARD_TYPE_ONE_STRAIGHT then ----顺子
            if #cards >= 5 then
                local status, records = CardRuler[ECardType.DDZ_CARD_TYPE_ONE_STRAIGHT].getBigger(cards,0,0,isbomb)
                if status == true then return status, records end
            end
        elseif value == ECardType.DDZ_CARD_TYPE_THREE_WING_PAIR then ----- 飞机带双
            if #cards >= 10 then
                local status, records = CardRuler[ECardType.DDZ_CARD_TYPE_THREE_WING_PAIR].getBigger(cardscontainer,0,0,isbomb)
                if status == true then return status, records end
            end
        elseif value == ECardType.DDZ_CARD_TYPE_THREE_WING_ONE then  ---- 飞机带单
            if #cards >= 8 then
                local status, recards = CardRuler[ECardType.DDZ_CARD_TYPE_THREE_WING_ONE].getBigger(cardscontainer,0,0,isbomb)
                if status == true then return status, recards end
            end
        elseif value == ECardType.DDZ_CARD_TYPE_THREE_STRAIGHT then  ----飞机不带
            if #cards >= 6 then
                local status, recards = CardRuler[ECardType.DDZ_CARD_TYPE_THREE_STRAIGHT].getBigger(cardscontainer,0,0,isbomb)
                if status == true then return status, recards end
            end
        elseif value == ECardType.DDZ_CARD_TYPE_TWO_STRAIGHT then  ----- 连对
            if #cards >= 6 then
                local status, recards = CardRuler[ECardType.DDZ_CARD_TYPE_TWO_STRAIGHT].getBigger(cardscontainer,0,0,isbomb)
                if status == true then return status, recards end
            end
        elseif value == ECardType.DDZ_CARD_TYPE_FOUR_TWO_PAIR then ----- 四带两对
            if #cards >= 8 then
                local status, recards = CardRuler[ECardType.DDZ_CARD_TYPE_FOUR_TWO_PAIR].getBigger(cardscontainer,0,0,isbomb)
                if status == true then return status, recards end
            end
        elseif value == ECardType.DDZ_CARD_TYPE_FOUR_TWO_ONE then -----四带二
            if #cards >= 6 then
                local status, recards = CardRuler[ECardType.DDZ_CARD_TYPE_FOUR_TWO_ONE].getBigger(cardscontainer,0,0,1)
                if status == true then return status, recards end
            end
        elseif value == ECardType.DDZ_CARD_TYPE_THREE_PAIR then  ---- 三带二
            if #cards >= 5 then
                local status, recards = CardRuler[ECardType.DDZ_CARD_TYPE_THREE_PAIR].getBigger(cardscontainer,0,0,1)
                if status == true then return status, recards end
            end
        elseif value == ECardType.DDZ_CARD_TYPE_BOMB    then   ----- 炸弹
            if #cards >= 4 then
                local status, recards = DDZGameLogic.getBiggerCards(cardscontainer,0,4)
                if status == true then
                    return status, recards
                end
            end
        elseif value == ECardType.DDZ_CARD_TYPE_THREE_ONE then ----- 三带一
            if #cards >= 4 then
                local status, recards = CardRuler[ECardType.DDZ_CARD_TYPE_THREE_ONE].getBigger(cardscontainer,0,0,1)
                if status == true then return status, recards end
            end
        elseif value == ECardType.DDZ_CARD_TYPE_THREE then   ----三条
            if #cards >= 3 then
                local status, recards = CardRuler[ECardType.DDZ_CARD_TYPE_THREE].getBigger(cardscontainer,0,0,1)
                if status == true then return status, recards end
            end
        elseif value == ECardType.DDZ_CARD_TYPE_ROCKET then  ----王炸
            if #cards >= 2 then
                local status, recards = CardRuler[ECardType.DDZ_CARD_TYPE_ROCKET].getWangzha(cardscontainer.single)
                if status == true then
                    return status, recards
                end
            end
        elseif value == ECardType.DDZ_CARD_TYPE_PAIR  then  -----对子
            if #cards >= 2 then
                local status, recards = DDZGameLogic.getBiggerCards(cardscontainer,0,2)
                if status == true then
                    return status, recards
                end
            end
        elseif value == ECardType.DDZ_CARD_TYPE_SINGLE  then  -----单张
            if #cards >= 1 then
                local status, recards = DDZGameLogic.getBiggerCards(cardscontainer,0,1)
                if status == true then
                    return status, recards
                end
            end
        end
    end
    return false
end


return DDZGameLogic