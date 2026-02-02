--[[
Localization (strings)

To add your language:
1) Copy this file to Locales\\<locale>.lua (example: Locales\\deDE.lua)
2) In the copy, change the locale check to match your language (example: "deDE")
3) Translate the L.* values
4) Add the new file to LariasWeeklyMidnightChecklist.toc AFTER Locales\\enUS.lua

Common locale codes: enUS, enGB, frFR, deDE, esES, esMX, itIT, ptBR, ruRU, koKR, zhCN, zhTW
]]

local addonName = ...

local locale = (GetLocale and GetLocale()) or nil

local Addon = _G[addonName] or {}
_G[addonName] = Addon

Addon.L = Addon.L or {}
local L = Addon.L

local function SetDefault(key, value)

    if locale == "enUS" or L[key] == nil then
        L[key] = value
    end
end
SetDefault("DISPLAY_NAME", "Larias Weekly Midnight Checklist")

SetDefault("OPTIONS_SHOW_GREAT_VAULT", "Show Great Vault")
SetDefault("OPTIONS_SHOW_CURRENCY", "Show Currency")

SetDefault("HIDE_COMPLETED_WEEKS", "Hide completed weeks")
SetDefault("OPTIONS_BUTTON", "Options")
SetDefault("RESET_BUTTON", "Reset")
SetDefault("DONE_PREFIX", "[Done] ")

SetDefault("TRACKING_GREAT_VAULT_TITLE", "Great Vault")
SetDefault("TRACKING_CURRENCY_TITLE", "Currency")
SetDefault("TRACKING_GV_RAID", "Raid")
SetDefault("TRACKING_GV_DUNGEONS", "Dungeons")
SetDefault("TRACKING_NA", "N/A")

SetDefault("TRACKING_SPARKS_LABEL", "Sparks:")
SetDefault("TRACKING_DONE", "Done")
SetDefault("TRACKING_NOT_DONE", "Not done")

SetDefault("TRACKING_QUEST_DELVERS_BOUNTY", "Delver's Bounty:")
SetDefault("TRACKING_QUEST_WEEKLY_PREY", "Weekly Prey:")

SetDefault("TRACKING_CREST_LABEL", "Crest:")
SetDefault("TRACKING_CREST_ID_LABEL_FMT", "Crest %s:")
SetDefault("TRACKING_NO_ID", "No ID")
SetDefault("TRACKING_TRADE_UP_SUFFIX", " Trade Up)")

SetDefault("TRACKING_CATALYST_LABEL", "Catalyst:")

SetDefault("TRACKING_CURRENCY_FALLBACK_PREFIX", "Currency ")
SetDefault("TRACKING_CREST_MATCH_SUBSTRING", "crest")
SetDefault("TRACKING_INF", "INF")
