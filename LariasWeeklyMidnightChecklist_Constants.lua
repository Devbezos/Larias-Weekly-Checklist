-- PATCH / SEASON UPDATE NOTES
--
-- When a WoW patch/season drops, these are the only places you should usually need to edit:
--
-- 1) Interface versions:
--    - Update the supported Interface numbers in the .toc if the addon shows as "out of date".
--
-- 2) Currency IDs / caps:
--    - If Blizzard changes currency IDs or weekly caps, update the IDs in TRACKING profiles below.
--    - Quick sanity check in-game:
--      `/dump C_CurrencyInfo.GetCurrencyInfo(<id>)` and confirm `name`, `quantity`, and caps.
--
-- 3) Crest achievements:
--    - If crest "unlocked" logic breaks, achievement IDs may have changed.
--
-- 4) Weekly quest tracking:
--    - Set quest IDs in TRACKING profiles (Wowhead quest IDs).
--    - Unknown IDs can be left as 0 (row will stay hidden).

local addonName = ...

local Addon = _G[addonName] or {}
_G[addonName] = Addon

function Addon:InitConstants(name)
    name = name or addonName

    local L = self.L or {}

    -- Group core constants into objects (tables) while keeping legacy fields for compatibility.
    self.CONSTANTS = self.CONSTANTS or {}
    self.CONSTANTS.names = self.CONSTANTS.names or {}
    local names = self.CONSTANTS.names

    if names.displayName == nil then names.displayName = L.DISPLAY_NAME or name end
    if names.dbName == nil then names.dbName = "LariasWeeklyMidnightChecklistDBPC" end
    if names.accountDbName == nil then names.accountDbName = "LariasWeeklyMidnightChecklistDB" end
    if names.listDataKey == nil then names.listDataKey = (name .. "_LIST_DATA") end

    self.DISPLAY_NAME = self.DISPLAY_NAME or names.displayName
    self._DB_NAME = self._DB_NAME or names.dbName
    self._ACCOUNT_DB_NAME = self._ACCOUNT_DB_NAME or names.accountDbName
    self._LIST_DATA_KEY = self._LIST_DATA_KEY or names.listDataKey

    self.CONSTANTS.theme = self.CONSTANTS.theme or self.THEME or {
        bg      = { r = 0.10, g = 0.10, b = 0.10, a = 0.65 },
        border  = { r = 0.30, g = 0.30, b = 0.30, a = 0.90 },
        header  = { r = 1.00, g = 0.82, b = 0.00, a = 1.00 },
        text    = { r = 1.00, g = 1.00, b = 1.00, a = 1.00 },
        textDim = { r = 1.00, g = 1.00, b = 1.00, a = 0.85 },
    }
    self.THEME = self.THEME or self.CONSTANTS.theme

    self.CONSTANTS.ui = self.CONSTANTS.ui or self.UI or {
        frameW = 520,
        frameH = 650,
        padOuterX = 14,
        padOuterTop = 10,
        closeInset = 4,
        topRowH = 26,
        topRowRightInset = 34,
        scrollTop = 44,
        scrollBottom = 16,
        scrollRight = 30,
        sectionGap = 10,
        sectionTopPad = 10,
        headerMinH = 22,
        headerBottomPad = 4,
        headerTextExtraW = 28,
        itemMinH = 24,
        itemTextPad = 8,
        itemTextWidth = 420,
        sectionInsetX = 14,
        trackH = 210,
        trackTopPad = 10,
    }
    self.UI = self.UI or self.CONSTANTS.ui

    self.CONSTANTS.tracking = self.CONSTANTS.tracking or self.TRACKING or {}
    self.TRACKING = self.TRACKING or self.CONSTANTS.tracking

    self.TRACKING.profiles = self.TRACKING.profiles or {}
    -- Friendly labels for profiles (used by UI/debug helpers).
    self.TRACKING.profileDisplayNames = self.TRACKING.profileDisplayNames or {
        tww = "tww",
        midnight = "midnight",
    }

    if self.TRACKING.midnightMinLevel == nil then
        self.TRACKING.midnightMinLevel = 90
    end

    local function EnsureProfile(key)
        local p = self.TRACKING.profiles[key]
        if type(p) ~= "table" then
            p = {}
            self.TRACKING.profiles[key] = p
        end
        p.questIDs = p.questIDs or {}
        return p
    end

    local tww = EnsureProfile("tww")
    if type(tww.crestCurrencyIDs) ~= "table" then
        tww.crestCurrencyIDs = {
            3284,
            3286,
            3288,
            3290,
        }
    end
    if type(tww.crestAchievementIDs) ~= "table" then
        tww.crestAchievementIDs = {
            41886,
            41887,
            41888,
            41892,
        }
    end
    if tww.sparkCurrencyID == nil then tww.sparkCurrencyID = 3141 end
    if tww.catalystCurrencyID == nil then tww.catalystCurrencyID = 3269 end
    -- Crest trade-up tuple: { lower, higher } (e.g. {45, 15}).
    if tww.crestTradeBatch == nil then tww.crestTradeBatch = { 45, 15 } end
    if tww.questIDs.delversBounty == nil then tww.questIDs.delversBounty = 86371 end
    if tww.questIDs.weeklyPrey == nil then tww.questIDs.weeklyPrey = 0 end

    local midnight = EnsureProfile("midnight")
    if type(midnight.crestCurrencyIDs) ~= "table" then
        midnight.crestCurrencyIDs = {
            3383,
            3341,
            3343,
            3345,
            3347,
        }
    end
    if type(midnight.crestAchievementIDs) ~= "table" then
        midnight.crestAchievementIDs = {
            61809,
            42767,
            72768,
            42769,
            42770,
        }
    end
    if midnight.sparkCurrencyID == nil then midnight.sparkCurrencyID = 0 end
    if midnight.catalystCurrencyID == nil then midnight.catalystCurrencyID = 0 end
    if midnight.crestTradeBatch == nil then midnight.crestTradeBatch = { 45, 15 } end
    if midnight.questIDs.delversBounty == nil then midnight.questIDs.delversBounty = 0 end
    if midnight.questIDs.weeklyPrey == nil then midnight.questIDs.weeklyPrey = 0 end

end

Addon:InitConstants(addonName)
