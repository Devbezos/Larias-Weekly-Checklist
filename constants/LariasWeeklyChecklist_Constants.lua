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
    -- Individual Prey target quest IDs (30 total, need 4 for the weekly cache).
    preyQuestIDs = {
        91095, 91096, 91097, 91098, 91099, 91100,
        91101, 91102, 91103, 91104, 91105, 91106,
        91107, 91108, 91109, 91110, 91111, 91112,
        91113, 91114, 91115, 91116, 91117, 91118,
        91119, 91120, 91121, 91122, 91123, 91124,
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
    -- ────────────────────────────────────────────────────────────────────────
    -- Rare NPC IDs, grouped by zone (plain arrays of creature IDs).
    -- Names are resolved at runtime via the WoW creature cache / tooltip API.
    -- Weekly per-character lockout; killing grants zone Renown.
    -- Sources:
    --   eversongWoods : wowhead.com/guide/midnight/eversong-woods-rares-treasures-locations-tips-rewards
    --   zulaman       : wowhead.com/guide/midnight/zulaman-rares-treasures-locations-tips-rewards
    --   harandar      : wowhead.com/guide/midnight/harandar-rares-treasures-locations-tips-rewards
    --   voidstorm     : wowhead.com/guide/midnight/voidstorm-rares-treasures-locations-tips-rewards
    rares = {
        eversongWoods = {
            246332, 240129, 250719, 250754, 250841, 250826,
            255302, 255348, 246633, 250582, 250683, 250876,
            250780, 250788, 250806, 255329,
        },
        zulaman = {
            242023, 242025, 245975, 242031, 242033, 242035,
            242027, 242024, 242028, 247976, 242032, 242034,
            242026, 245692, 245691, 246122,
        },
        harandar = {
            248741, 249849, 249962, 250226, 250246, 250321,
            249844, 249902, 249997, 250180, 250231, 250347,
            250086, 250358, 250317,
        },
        voidstorm = {
            244272, 241443, 256923, 256925, 256770, 245044,
            238498, 256922, 256924, 256926, 245182, 257027,
            256808, 256821,
        },
    },

    -- ────────────────────────────────────────────────────────────────────────
    -- Treasure object IDs, grouped by zone (plain arrays of object IDs).
    -- Names are resolved at runtime via the WoW object cache / tooltip API.
    -- One-time loot per character; grants Renown and zone-specific items.
    treasures = {
        eversongWoods = {
            617881, 613697, 617534, 613267, 555351,
            613252, 617432, 613242, 587307,
        },
        zulaman = {
            539047, 617659, 539050, 539052,
            613727, 539049, 539051, 539053,
        },
        harandar = {
            572958, 573050, 573307, 572998, 614483, 616052,
            573095, 590789, 589202, 588929, 615908, 615907,
        },
        voidstorm = {
            605169, 612891, 613368, 613351, 613317, 572819,
            572893, 555250, 612270, 613358, 613852,
        },
    },

    -- ── Feature flags ──────────────────────────────────────────────────────
    -- Master switches for optional UI features.  Set a flag to false to
    -- completely disable that feature (no button, no gear-popup checkbox).
    featureFlags = {
        ENABLE_CHAR_SELECTOR = false,   -- character-switcher button + dropdown
    },
}

_G[constantsKey] = tracking
