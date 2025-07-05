--[[
T-RestedXP - addon for tracking 100% rested XP in WoW 1.12
T-RestedXP - аддон для отслеживания 100% rested XP в WoW 1.12

Addon GitHub link: https://github.com/whtmst/t-restedxp

Author: Mikhail Palagin (Wht Mst)
Website: https://band.link/whtmst

Compatibility:
- Designed for Turtle WoW server
--]]

-- НАСТРОЙКИ
local fullRestedMsg = "=== 100% RESTED XP! ==="  -- 100% rested XP message alert / Сообщение при 100% rested XP
local noRestedMsg = "=== 0% RESTED XP! ==="  -- 0% rested XP message alert / Сообщение при 0% rested XP
local chatChannel = "SELF"  -- Announce channel / Канал анонса ("SELF", "SAY", "PARTY", "RAID", "GUILD" или "YELL")