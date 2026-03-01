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
        weeklyPrey    = 0,
        -- Season 1 weekly quests (Midnight).
        abundance           = 89507,
        lostLegends         = 89268,
        highEsteem          = 91629,
        -- Fortify the Runestones has 4 player-assigned variants; any one counts.
        fortifyRunestones   = { 90575, 90576, 90574, 90573 },
        standYourGround     = 94581,
    },
    -- Individual Prey target quest IDs (30 per difficulty tier, need 4 for the weekly cache).
    -- Normal (L80): available from Early Access / Pre-Season.
    preyQuestIDs = {
        91095, 91096, 91097, 91098, 91099, 91100,
        91101, 91102, 91103, 91104, 91105, 91106,
        91107, 91108, 91109, 91110, 91111, 91112,
        91113, 91114, 91115, 91116, 91117, 91118,
        91119, 91120, 91121, 91122, 91123, 91124,
    },
    -- Hard (L90): unlocks Pre-Season Week 1 (Mar 3, 2026). Rewards Veteran gear.
    -- IDs interleave with Nightmare: Hard = even offsets from 91210, Nightmare = odd.
    preyHardQuestIDs = {
        91210, 91212, 91214, 91216, 91218, 91220,
        91222, 91224, 91226, 91228, 91230, 91232,
        91234, 91236, 91238, 91240, 91242, 91244,
        91246, 91248, 91250, 91252, 91254, 91256,
        91258, 91260, 91262, 91264, 91266, 91268,
    },
    -- Nightmare (L90): unlocks Season 1 Week 1 (Mar 17, 2026). Rewards Champion gear.
    preyNightmareQuestIDs = {
        91211, 91213, 91215, 91217, 91219, 91221,
        91223, 91225, 91227, 91229, 91231, 91233,
        91235, 91237, 91239, 91241, 91243, 91245,
        91247, 91249, 91251, 91253, 91255, 91257,
        91259, 91261, 91263, 91265, 91267, 91269,
    },
    preyQuestGoal = 4,
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
        ENABLE_CHAR_SELECTOR = false,   -- character-switcher button + dropdown
    },
}

_G[constantsKey] = tracking
