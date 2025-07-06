--[[
T-RestedXP - addon for tracking 100% rested XP in WoW 1.12
T-RestedXP - аддон для отслеживания 100% rested XP в WoW 1.12

Addon GitHub link: https://github.com/whtmst/t-restedxp

Author: Mikhail Palagin (Wht Mst)
Website: https://band.link/whtmst

Compatibility:
- Designed for Turtle WoW server
--]]

-- SETTINGS / НАСТРОЙКИ
local fullRestedMsg = "=== 100% RESTED XP / 100% ОТДЫХА ==="  -- 100% rested XP message alert / Сообщение при 100% rested XP
local noRestedMsg = "=== NO RESTED XP / НЕТ ОТДЫХА ==="      -- 0% rested XP message alert / Сообщение при 0% rested XP
local chatChannel = "EMOTE"                       -- Announce channel / Канал анонса ("EMOTE", "SAY", "PARTY", "RAID", "GUILD" или "YELL")
local notifyIntervalFull = 60                    -- Interval between 100% alerts (seconds) / Интервал между оповещениями о 100% (сек)
local notifyIntervalZero = 20                    -- Interval between 0% alerts (seconds) / Интервал между оповещениями о 0% (сек)
local notifyCountZero = 3                        -- Max 0% alerts in a row / Максимум оповещений о 0% подряд
local playSound = true                           -- Play sound on alert / Воспроизводить звук при оповещении
local soundName = "LEVELUP"                      -- Sound name / Имя звука
local showCenter = true                          -- Show alert in center / Показывать оповещение по центру экрана
local maxLevel = 60                              -- Max player level / Максимальный уровень игрока

-- INTERNAL STATE / ВНУТРЕННЕЕ СОСТОЯНИЕ
local lastFullRestedTime = 0
local lastZeroRestedTime = 0
local zeroRestedCount = 0
local wasFullRested = false
local wasZeroRested = false

-- Returns true if player is max level / Возвращает true, если игрок максимального уровня
local function IsPlayerMaxLevel()
    return UnitLevel("player") >= maxLevel
end

-- Returns rested XP percent (0-100), or nil if not available / Возвращает % rested XP (0-100), или nil если нет
local function GetRestedXPPercent()
    local exhaustion = GetXPExhaustion()
    local maxXP = UnitXPMax("player")
    if exhaustion and maxXP and maxXP > 0 then
        return (exhaustion / (maxXP * 1.5)) * 100
    end
    return nil
end

-- Send alert to chat and/or center / Отправить оповещение в чат и/или по центру
local function SendRestedAlert(msg)
    if chatChannel == "SELF" then
        DEFAULT_CHAT_FRAME:AddMessage(msg)
    else
        SendChatMessage(msg, chatChannel)
    end
    if showCenter and UIErrorsFrame then
        UIErrorsFrame:AddMessage(msg, 1, 1, 0, 1, 3)
    end
    if playSound and soundName then
        PlaySound(soundName)
    end
end

-- Main event handler / Основная обработка событий
local function CheckRestedXP()
    if IsPlayerMaxLevel() then return end

    local percent = GetRestedXPPercent()
    local now = GetTime()

    if percent == nil then
        wasFullRested = false
        wasZeroRested = false
        zeroRestedCount = 0
        return
    end

    -- 100% rested XP
    if percent >= 99.9 then
        if not wasFullRested or (now - lastFullRestedTime) >= notifyIntervalFull then
            SendRestedAlert(fullRestedMsg)
            lastFullRestedTime = now
            wasFullRested = true
        end
        wasZeroRested = false
        zeroRestedCount = 0
        return
    end

    -- 0% rested XP
    if percent <= 0.1 then
        if not wasZeroRested then
            zeroRestedCount = 0
        end
        if zeroRestedCount < notifyCountZero and (now - lastZeroRestedTime) >= notifyIntervalZero then
            SendRestedAlert(noRestedMsg)
            lastZeroRestedTime = now
            zeroRestedCount = zeroRestedCount + 1
        end
        wasZeroRested = true
        wasFullRested = false
        return
    end

    -- Reset state if in between / Сброс состояния если между 0% и 100%
    wasFullRested = false
    wasZeroRested = false
    zeroRestedCount = 0
end

-- Event frame setup / Создание фрейма событий
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_XP_UPDATE")
frame:RegisterEvent("UPDATE_EXHAUSTION")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:SetScript("OnEvent", function()
    CheckRestedXP()
end)

-- Slash command for manual check / Слэш-команда для ручной проверки
SLASH_TRESTEDXP1 = "/trestedxp"
SlashCmdList["TRESTEDXP"] = function()
    local percent = GetRestedXPPercent()
    local msg
    if percent then
        msg = string.format("Rested XP: %.1f%% / Отдых: %.1f%%", percent, percent)
        DEFAULT_CHAT_FRAME:AddMessage(msg)
        if showCenter and UIErrorsFrame then
            UIErrorsFrame:AddMessage(msg, 1, 1, 0, 1, 3)
        end
    else
        msg = "NO RESTED XP / НЕТ ОТДЫХА"
        DEFAULT_CHAT_FRAME:AddMessage(msg)
        if showCenter and UIErrorsFrame then
            UIErrorsFrame:AddMessage(msg, 1, 0, 0, 1, 3)
        end
    end
end

-- ПРАВИЛЬНО
-- Slash command for test 0% rested XP / Слэш-команда для теста 0% rested XP
SLASH_TRESTEDXPTESTZERO1 = "/trestedxp-test-0"
SlashCmdList["TRESTEDXPTESTZERO"] = function()
    local oldGetRestedXPPercent = GetRestedXPPercent
    GetRestedXPPercent = function() return 0 end
    CheckRestedXP()
    GetRestedXPPercent = oldGetRestedXPPercent
    DEFAULT_CHAT_FRAME:AddMessage("Test: forced 0% rested XP / Тест: принудительно 0% отдыха")
end

-- Slash command for test 100% rested XP / Слэш-команда для теста 100% rested XP
SLASH_TRESTEDXPTESTFULL1 = "/trestedxp-test-100"
SlashCmdList["TRESTEDXPTESTFULL"] = function()
    local oldGetRestedXPPercent = GetRestedXPPercent
    GetRestedXPPercent = function() return 100 end
    CheckRestedXP()
    GetRestedXPPercent = oldGetRestedXPPercent
    DEFAULT_CHAT_FRAME:AddMessage("Test: forced 100% rested XP / Тест: принудительно 100% отдыха")
end

-- End of file / Конец