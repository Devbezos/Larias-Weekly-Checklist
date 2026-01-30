-- Constants.lua
local addonName = ...

local Addon = _G[addonName] or {}
_G[addonName] = Addon

function Addon:InitConstants(name)
    name = name or addonName

    -- Per-character DB (each toon has its own checklist).
    self._DB_NAME = self._DB_NAME or "LariasWeeklyMidnightChecklistDBPC"
    -- Legacy account-wide DB name (kept for one-time migration).
    self._ACCOUNT_DB_NAME = self._ACCOUNT_DB_NAME or "LariasWeeklyMidnightChecklistDB"
    self._LIST_DATA_KEY = self._LIST_DATA_KEY or (name .. "_LIST_DATA")

    self.THEME = self.THEME or {
        bg      = { r = 0.10, g = 0.10, b = 0.10, a = 0.65 },
        border  = { r = 0.30, g = 0.30, b = 0.30, a = 0.90 },
        header  = { r = 1.00, g = 0.82, b = 0.00, a = 1.00 },
        text    = { r = 1.00, g = 1.00, b = 1.00, a = 1.00 },
        textDim = { r = 1.00, g = 1.00, b = 1.00, a = 0.85 },
    }

    self.UI = self.UI or {
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

        -- tracking reservation (Currency.lua uses it)
        trackH = 210,
        trackTopPad = 10,
    }

    self.TRACKING = self.TRACKING or {
        crestCurrencyIDs = { 
            weathered = 3284, 
            carved = 3286, 
            runed = 3288, 
            gilded = 3290 },
        crestAchievementIDs = {
            weathered = 41886,
            carved = 41887,
            runed = 41888,
            gilded = 41892,
        },
        sparkCurrencyID = 3141,
        catalystCurrencyID = 3269,
    }
end

Addon:InitConstants(addonName)
