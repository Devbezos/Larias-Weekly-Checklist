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
    -- ── Work-order warning ────────────────────────────────────────────────────
    -- Fixed primary stat for each craftable weapon item.  Used by the work-order
    -- warning feature to alert a customer when the ordered item doesn't match
    -- their spec's primary stat.
    -- Stat values mirror GetSpecializationInfo primaryStat: 1=STR, 2=AGI, 4=INT.
    -- Special value 3 = "PHYS" — item has AGI+STR but no INT; only warns casters.
    workOrderItemStats = {
        -- Blacksmithing — Midnight expansion (ilvl 246 base / 650 max quality)
        [237837] = 2,    -- Farstrider's Mercy         (Dagger,     AGI)
        [237838] = 4,    -- Magister's Ritual Knife    (Dagger,     INT)
        [237839] = 3,    -- Spellbreaker's Blade       (1H Sword,   AGI+STR)
        [237840] = 4,    -- Spellbreaker's Warglaive   (Warglaive,  INT)
        [237841] = 3,    -- Spellbreaker's Ultimatum   (1H Mace,    AGI+STR)
        [237842] = 3,    -- Bloomforged Greataxe       (2H Axe,     AGI+STR)
        [237843] = 4,    -- Magister's Mana Sword      (1H Sword,   INT)
        [237844] = 4,    -- Magister's Cleaver         (1H Axe,     INT)
        [237845] = 3,    -- Bloomforged Claw           (Fist,       AGI+STR)
        [237846] = 1,    -- Blood Knight's Warblade    (2H Sword,   STR)
        [237847] = 3,    -- Blood Knight's Impetus     (Polearm,    AGI+STR)
        [237848] = 3,    -- Blood Knight's Mercy       (2H Mace,    AGI+STR)
        [237849] = 4,    -- Magister's Valediction     (2H Mace,    INT)
        [237850] = 3,    -- Farstrider's Chopper       (1H Axe,     AGI+STR)
        [244679] = 2,    -- Murder Row Fishhook        (Dagger,     AGI)
        [268477] = 2,    -- P.O.W. x3                  (Gun,        AGI)
    },
    -- ── Feature flags ──────────────────────────────────────────────────────
    -- Master switches for optional UI features.  Set a flag to false to
    -- completely disable that feature (no button, no gear-popup checkbox).
    featureFlags = {
    },
}

_G[constantsKey] = tracking
