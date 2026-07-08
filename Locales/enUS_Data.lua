--[[
English (enUS) checklist data for Larias' Weekly Checklist

NOTE: This is the canonical enUS dataset; other locales must keep IDs identical
so completion tracking stays consistent across locales.
]]

-- @sheet-version: 30

local LOCALE = "enUS"

local LOCALE_REGISTRY_KEY = "LARIASWEEKLYCHECKLIST_LOCALE_REGISTRY"

local reg = _G[LOCALE_REGISTRY_KEY]
if type(reg) ~= "table" then
    reg = {}
    _G[LOCALE_REGISTRY_KEY] = reg
end
if type(reg.data) ~= "table" then reg.data = {} end
reg.sheet_version = "30"

local DATASET = {

    {
        id = "067d2566",
        title = "Week 5 - Apr 14 - Done with Heroic Crests",
        items = {
            { id = "9375e497", text = "Open vault (272+ myth item)" },
            { id = "83fd4310", text = "Complete weekly world event quest for spark from Lady Liadrin" },
            { id = "1db5f946", text = "Farm +10s for vault + crests" },
            { id = "da97880d", text = "Catch up the Voidforge storyline so you can get bonus rolls next week" },
            { id = "f9978f0e", text = "Do not craft if you can get vault items higher than 1/6" },
        },
    },
    {
        id = "599ab6a0",
        title = "Week 6 - Apr 21 - Bonus Rolls Unlock",
        items = {
            { id = "f9978f0e", text = "Do not craft if you can get vault items higher than 1/6" },
            { id = "66e83cc1", text = "Upgrade Mythic items as you get them, preferring to jump them to 289 for the +4 jump" },
            { id = "90409a11", text = "Complete Blizzard's Voidforge storyline quest to unlock bonus rolls - check guide on best use of Bonus rolls going forward" },
            { id = "f9978f0e", text = "Do not craft if you can get vault items higher than 1/6" },
        },
    },
}

reg.data[LOCALE] = DATASET
