--[[
T-RestedXP - addon for tracking 100% rested XP in WoW 1.12
T-RestedXP - аддон для отслеживания 100% RESTED XP в WoW 1.12

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
local notifyIntervalZero = 20                    -- Interval between 0% alerts (seconds) / Интервал между оповещениями о 0% (сек)
local notifyCountZero = 3                        -- Max 0% alerts in a row / Максимум оповещений о 0% подряд
local playSound = true                           -- Play sound on alert / Воспроизводить звук при оповещении
local soundNameFull = "QUESTCOMPLETED"                -- Sound for 100% rested XP / Звук для 100%
local soundNameZero = "RaidWarning"         -- Sound for 0% rested XP / Звук для 0%
local showCenter = true                          -- Show alert in center / Показывать оповещение по центру экрана
local maxLevel = 60                              -- Max player level / Максимальный уровень игрока
local centerMessageTime = 3 -- Time to show center message (seconds) / Время показа сообщения по центру (сек)

-- INTERNAL STATE / ВНУТРЕННЕЕ СОСТОЯНИЕ
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
    if not exhaustion or not maxXP or maxXP <= 0 or exhaustion < 0 then
        return nil
    end
    local percent = (exhaustion / (maxXP * 1.5)) * 100
    return math.min(percent, 100) -- Защита от значений > 100%
end

-- Защита от повторного создания фрейма
if T_RestedXP_MessageFrame then
    T_RestedXP_MessageFrame:Hide()
    T_RestedXP_MessageFrame = nil
end

-- Custom center message frame / Кастомный фрейм для сообщений по центру
local restedXPMessageFrame = CreateFrame("Frame", "T_RestedXP_MessageFrame", UIParent)
restedXPMessageFrame:SetWidth(800)
restedXPMessageFrame:SetHeight(120)
restedXPMessageFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 180) -- поднято вверх
restedXPMessageFrame:Hide()

local restedXPFontString = restedXPMessageFrame:CreateFontString(nil, "OVERLAY")
-- Добавь проверку перед установкой шрифта
local fontPath = "Interface\\AddOns\\T-RestedXP\\fonts\\ARIALN.ttf"
if not restedXPFontString:SetFont(fontPath, 96, "OUTLINE") then
    -- Фоллбэк на стандартный шрифт
    restedXPFontString:SetFont("Fonts\\FRIZQT__.TTF", 96, "OUTLINE")
end
restedXPFontString:SetPoint("CENTER", restedXPMessageFrame, "CENTER", 0, 0)
restedXPFontString:SetTextColor(1, 1, 0)

local function ShowRestedXPMessage(msg)
    -- Сброс предыдущего состояния
    restedXPMessageFrame:SetScript("OnUpdate", nil)
    restedXPMessageFrame:Hide()
    
    -- Установка нового сообщения и состояния
    restedXPFontString:SetText(msg)
    restedXPMessageFrame:SetAlpha(1)
    restedXPMessageFrame:Show()

    -- Сохраняем время начала показа
    restedXPMessageFrame.startTime = GetTime()
    restedXPMessageFrame.showDuration = centerMessageTime
    restedXPMessageFrame.fadeDuration = 1

    restedXPMessageFrame:SetScript("OnUpdate", function(frame, elapsed)
        local currentTime = GetTime()
        local timeElapsed = currentTime - restedXPMessageFrame.startTime
        local totalDuration = restedXPMessageFrame.showDuration + restedXPMessageFrame.fadeDuration

        if timeElapsed >= totalDuration then
            -- Время вышло, скрываем фрейм
            restedXPMessageFrame:Hide()
            restedXPMessageFrame:SetScript("OnUpdate", nil)
            restedXPMessageFrame.startTime = nil
        elseif timeElapsed >= restedXPMessageFrame.showDuration then
            -- Фаза затухания
            local fadeProgress = (timeElapsed - restedXPMessageFrame.showDuration) / restedXPMessageFrame.fadeDuration
            restedXPMessageFrame:SetAlpha(1 - fadeProgress)
        end
    end)
end

-- Send alert to chat and/or center / Отправить оповещение в чат и/или по центру
local function SendRestedAlert(msg, soundName)
    if chatChannel == "SELF" then
        DEFAULT_CHAT_FRAME:AddMessage(msg)
    elseif chatChannel then
        -- Проверка на валидность канала
        local validChannels = {"EMOTE", "SAY", "PARTY", "RAID", "GUILD", "YELL"}
        local isValidChannel = false
        for _, channel in ipairs(validChannels) do
            if chatChannel == channel then
                isValidChannel = true
                break
            end
        end
        if isValidChannel then
            SendChatMessage(msg, chatChannel)
        else
            DEFAULT_CHAT_FRAME:AddMessage(msg)
        end
    end
    
    if showCenter then
        ShowRestedXPMessage(msg)
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

    -- 100% rested XP: only one alert on entering state / 100% rested XP: только одно оповещение при входе в состояние
    if percent >= 99.9 then
        if not wasFullRested then
            SendRestedAlert(fullRestedMsg, soundNameFull)
            wasFullRested = true
        end
        wasZeroRested = false
        zeroRestedCount = 0
        return
    end

    -- 0% rested XP: up to 3 alerts with interval, then no more until state changes / 0% rested XP: максимум 3 оповещения с интервалом, далее не оповещать до смены состояния
    if percent <= 0.1 then
        if not wasZeroRested then
            zeroRestedCount = 0
            lastZeroRestedTime = 0
        end
        if zeroRestedCount < notifyCountZero and (now - lastZeroRestedTime) >= notifyIntervalZero then
            SendRestedAlert(noRestedMsg, soundNameZero)
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

-- Cleanup при выгрузке аддона
local cleanupFrame = CreateFrame("Frame")
cleanupFrame:RegisterEvent("ADDON_LOADED")
cleanupFrame:RegisterEvent("PLAYER_LOGOUT")
cleanupFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "PLAYER_LOGOUT" or (event == "ADDON_LOADED" and addonName == "T-RestedXP") then
        if restedXPMessageFrame then
            restedXPMessageFrame:SetScript("OnUpdate", nil)
            restedXPMessageFrame:Hide()
        end
    end
end)

-- End of file / Конец файла