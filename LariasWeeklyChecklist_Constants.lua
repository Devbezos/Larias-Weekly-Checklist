-- Constants for Larias's Weekly Checklist.
--
-- This file is the single source of truth for tracking IDs.
-- Edit values here as you discover new IDs; the addon reads them during startup.
--
-- The addon looks for:  _G["<addonName>_CONSTANTS"]
--
-- Notes:
-- - Use 0 for "unknown / disabled" IDs.
-- - Array-like tables (e.g. crestCurrencyIDs lists) are replaced as a whole.

local addonName = ...
local constantsKey = tostring(addonName or "") .. "_CONSTANTS"

local tracking = {
    crestCurrencyIDs = {
        3383,
        3341,
        3343,
        3345,
        3347,
    },
    crestAchievementIDs = {
        61809,
        42767,
        72768,
        42769,
        42770,
    },
    sparkCurrencyID = 3212,
    catalystCurrencyID = 3378,
    crestTradeBatch = { 45, 15 },
    questIDs = {
        delversBounty = 0,
        weeklyPrey = 0,
    },
}

_G[constantsKey] = tracking
