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
    -- Rare NPC IDs, grouped by zone.
    -- Each entry is { id=<npcID>, name=<displayName> }.
    -- These have a weekly per-character lockout; killing grants zone Renown.
    -- Source: https://www.wowhead.com/guide/midnight/eversong-woods-rares-treasures-locations-tips-rewards
    rares = {
        eversongWoods = {
            { id = 246332, name = "Warden of Weeds"        },
            { id = 240129, name = "Overfester Hydra"        },
            { id = 250719, name = "Cre'van"                 },
            { id = 250754, name = "Lady Liminus"            },
            { id = 250841, name = "Bad Zed"                 },
            { id = 250826, name = "Banuran"                 },
            { id = 255302, name = "Duskburn"                },
            { id = 255348, name = "Dame Bloodshed"          },
            { id = 246633, name = "Harried Hawkstrider"     },
            { id = 250582, name = "Bloated Snapdragon"      },
            { id = 250683, name = "Coralfang"               },
            { id = 250876, name = "Terrinor"                },
            { id = 250780, name = "Waverly"                 },
            { id = 250788, name = "Lovely Sunflower"        },
            { id = 250806, name = "Lost Guardian"           },
            { id = 255329, name = "Malfunctioning Construct"},
        },
        -- TODO: add harandar = { ... }, voidstorm = { ... }, etc. as guides release
    },

    -- ────────────────────────────────────────────────────────────────────────
    -- Treasure object IDs, grouped by zone.
    -- Each entry is { id=<objectID>, name=<displayName> }.
    -- One-time loots per character; grant Renown and zone-specific items.
    -- Source: https://www.wowhead.com/guide/midnight/eversong-woods-rares-treasures-locations-tips-rewards
    treasures = {
        eversongWoods = {
            { id = 617881, name = "Rookery Cache"                 },
            { id = 613697, name = "Gift of the Phoenix"           },
            { id = 617534, name = "Gilded Armillary Sphere"       },
            { id = 613267, name = "Farstrider's Lost Quiver"      },
            { id = 555351, name = "Burbling Paint Pot"            },
            { id = 613252, name = "Triple-Locked Safebox"         },
            { id = 617432, name = "Forgotten Ink and Quill"       },
            { id = 613242, name = "Antique Nobleman's Signet Ring"},
            { id = 587307, name = "Stone Vat"                     },
        },
        -- TODO: add harandar = { ... }, voidstorm = { ... }, etc. as guides release
    },

    -- ── Feature flags ──────────────────────────────────────────────────────
    -- Master switches for optional UI features.  Set a flag to false to
    -- completely disable that feature (no button, no gear-popup checkbox).
    featureFlags = {
        ENABLE_CHAR_SELECTOR = false,   -- character-switcher button + dropdown
    },
}

_G[constantsKey] = tracking
