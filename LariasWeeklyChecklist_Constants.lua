-- Constants for Larias's Weekly Checklist.
--
-- This file is the single source of truth for tracking IDs.
-- Edit values here as you discover new IDs; the addon reads them during startup.
--
-- The addon looks for:  _G["<addonName>_CONSTANTS"].TRACKING
-- (It also accepts the older key <addonName>_USER_CONSTANTS for backward compatibility.)
--
-- Notes:
-- - Use 0 for "unknown / disabled" IDs.
-- - Array-like tables (e.g. crestCurrencyIDs lists) are replaced as a whole.

local addonName = ...
local constantsKey = tostring(addonName or "") .. "_CONSTANTS"
local legacyKey = tostring(addonName or "") .. "_USER_CONSTANTS"

local constants = {
    TRACKING = {
        -- If this min-level changes in the future, update it here.
        midnightMinLevel = 90,

        profileDisplayNames = {
            tww = "tww",
            midnight = "midnight",
        },

        profiles = {
            -- "tww" profile (The War Within)
            tww = {
                crestCurrencyIDs = {
                    3284,
                    3286,
                    3288,
                    3290,
                },
                crestAchievementIDs = {
                    41886,
                    41887,
                    41888,
                    41892,
                },
                sparkCurrencyID = 3141,
                catalystCurrencyID = 3269,
                crestTradeBatch = { 45, 15 },
                questIDs = {
                    delversBounty = 86371,
                    weeklyPrey = 0,
                },
            },

            -- "midnight" profile
            midnight = {
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
                sparkCurrencyID = 0,
                catalystCurrencyID = 0,
                crestTradeBatch = { 45, 15 },
                questIDs = {
                    delversBounty = 0,
                    weeklyPrey = 0,
                },
            },
        },
    },
}

_G[constantsKey] = constants
_G[legacyKey] = constants
