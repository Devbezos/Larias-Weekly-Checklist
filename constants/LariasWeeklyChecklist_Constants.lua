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
    cofferKeysCurrencyID = 3310,
    crestTradeBatch = { 45, 15 },
    questIDs = {
        delversBounty = 0,
        weeklyPrey = 0,
    },
    -- Item level reference data (index-matched to crestCurrencyIDs tier order).
    -- ilvlBases: the rank-1 ilvl for each crest tier (Adv, Vet, Champ, Hero, Myth).
    -- ilvlRankOffsets: added to ilvlBases to get the final ilvl at ranks 1-6.
    ilvlBases = { 220, 233, 246, 259, 272 },
    ilvlRankOffsets = { 0, 4, 7, 10, 13, 17 },
    -- Crest tier display colors as 6-digit hex RGB (index-matched to crest tier order).
    -- Used by the ilvl reference window to color each tier's rows.
    crestColors = {
        "1EFF00",  -- Adventurer  (green)
        "0070DD",  -- Veteran     (blue)
        "A335EE",  -- Champion    (purple)
        "FF8000",  -- Hero        (orange)
        "FFD100",  -- Myth/Gilded (gold)
    },
    -- Atlas names for the crafting quality tier icons (Tier1 = lowest, Tier5 = highest).
    -- IlvlRef wraps these in |A:name:14:14|a when rendering the crafted ilvl table.
    craftingQualityIcons = {
        "Professions-Icon-Quality-Tier1",
        "Professions-Icon-Quality-Tier2",
        "Professions-Icon-Quality-Tier3",
        "Professions-Icon-Quality-Tier4",
        "Professions-Icon-Quality-Tier5",
    },
    -- ── Feature flags ──────────────────────────────────────────────────────
    -- Master switches for optional UI features.  Set a flag to false to
    -- completely disable that feature (no button, no gear-popup checkbox).
    featureFlags = {
    },
}

_G[constantsKey] = tracking
