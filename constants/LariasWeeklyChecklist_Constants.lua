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

-- ══════════════════════════════════════════════════════════════════════════════
-- SEASON DATA  —  update these every new season
-- ══════════════════════════════════════════════════════════════════════════════
local tracking = { -- https://www.wowhead.com/currencies/season-1
    -- Crest currencies, index 1 (lowest) → 5 (highest).
    crestCurrencyIDs = {
        3383,  -- wowhead.com/currency=3383  Adventurer Dawncrest
        3341,  -- wowhead.com/currency=3341  Veteran Dawncrest
        3343,  -- wowhead.com/currency=3343  Champion Dawncrest
        3345,  -- wowhead.com/currency=3345  Hero Dawncrest
        3347,  -- wowhead.com/currency=3347  Myth Dawncrest
    },
    -- Achievement IDs for each crest tier (earn-X-crests achievements), same order.
    crestAchievementIDs = {
        61809,  -- wowhead.com/achievement=61809  Adventurer
        42767,  -- wowhead.com/achievement=42767  Veteran
        42768,  -- wowhead.com/achievement=42768  Champion
        42769,  -- wowhead.com/achievement=42769  Hero
        42770,  -- wowhead.com/achievement=42770  Myth
    },
    sparkCurrencyID              = 3212,   -- wowhead.com/currency=3212  Radiant Spark Dust
    sparkItemID                  = 232875, -- wowhead.com/item=232875    Spark of Radiance (reagent)
    sparkQuestID                 = 95245,  -- wowhead.com/quest=95245    Midnight: World Tour
    catalystCurrencyID           = 3378,   -- wowhead.com/currency=3378  Dawnlight Manaflux
    cofferKeysCurrencyID         = 3310,   -- wowhead.com/currency=3310  Coffer Key Shards
    cofferKeysDisplayCurrencyID  = 3028,   -- wowhead.com/currency=3028  Restored Coffer Key (icon/name source)
    miscCurrencyIDs = {
        3418,  -- wowhead.com/currency=3418  Resonance Crystals
    },
    questIDs = {
        delversBounty  = 86371,  -- wowhead.com/quest=86371   (unverified: not found on Wowhead; may be A Gnawing Void of Curiosity)
        weeklyPrey     = 0,
        nullaeusSpoils = 0,      -- TODO: fill in quest ID for Spoils of Nullaeus
    },
    questItemIDs = {
        delversBounty  = 252415,  -- wowhead.com/item=252415   Trovehunter's Bounty
        weeklyPrey     = 0,
        nullaeusSpoils = 254253,  -- wowhead.com/item=254253   Spoils of Nullaeus
    },
    -- Starting ilvl for rank 1 of the lowest crest tier (Adventurer).
    -- Each tier's base = ilvlBase + ilvlTrackStep * (tierIndex - 1).
    ilvlBase      = 220,
    ilvlTrackStep = 13,   -- a new track starts every 13 ilvls (rank-5 of each track)

-- ══════════════════════════════════════════════════════════════════════════════
-- STABLE DATA  —  unlikely to change between seasons
-- ══════════════════════════════════════════════════════════════════════════════

    -- How many crests trade up to the next tier and how many are produced.
    crestTradeBatch = { 30, 10 },

    -- Crests required per single rank upgrade, indexed by crest tier (1=Adventurer → 5=Myth).
    -- Adjust if Blizzard changes upgrade costs mid-season.
    crestUpgradeCostPerStep = {20, 20, 20, 20, 20},

    -- Reduced crest cost per step when the character has the upgrade cost reduction
    -- (account-wide or character-specific discount — toggled per character in Alt Summary).
    crestUpgradeCostReduced = {10, 10, 10, 10, 10},

    -- Free rank upgrades per tier granted account-wide (e.g. 2 = first 2 ranks cost 0 crests).
    -- Set to the appropriate value when Blizzard activates alt-upgrade discounts.
    crestUpgradeFreeRanks = {0, 0, 0, 0, 0},

    -- Per-rank ilvl offsets within any track (rank 1 = +0, rank 6 = +17).
    -- Gaps: 4, 3, 3, 3, 4 — constant across all seasons and tiers.
    ilvlRankOffsets = { 0, 4, 7, 10, 13, 17 },

    -- Equipment slot IDs captured for the gear popup and upgrade-cost rows.
    -- Slot 4 (shirt) and ranged/ammo slots are intentionally excluded.
    gearSlotIDs = {1,2,3,5,6,7,8,9,10,11,12,13,14,15,16,17},

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
    -- Support / social links shown in the gear popup and settings panel.
    supportLinks = {
        doc       = "https://docs.google.com/document/d/e/2PACX-1vTGkZ2Cjr0jlv90XqW9vy9VXsVucd-yMCgHdyCvX_kQfOrexNDAC7Lf3LifuhqxrcWqJ0W3zIhvK3ii/pub",
        checklist = "https://docs.google.com/spreadsheets/d/1iK2SZUcz_ljnkdTG7KW6pqfzaUDuSgnlh1HupcLrkus",
        discord   = "https://discord.gg/postnerfclarity",
    },
    -- Master switches for optional UI features.  Set a flag to false to
    -- completely disable that feature (no button, no gear-popup checkbox).
    featureFlags = {
    },
}

_G[constantsKey] = tracking
