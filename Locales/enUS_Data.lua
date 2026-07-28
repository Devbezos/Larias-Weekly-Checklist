--[[
English (enUS) checklist data for Larias' Weekly Checklist

NOTE: This is the canonical enUS dataset; other locales must keep IDs identical
so completion tracking stays consistent across locales.
]]

-- @sheet-version: 1

local LOCALE = "enUS"

local LOCALE_REGISTRY_KEY = "LARIASWEEKLYCHECKLIST_LOCALE_REGISTRY"

local reg = _G[LOCALE_REGISTRY_KEY]
if type(reg) ~= "table" then
    reg = {}
    _G[LOCALE_REGISTRY_KEY] = reg
end
if type(reg.data) ~= "table" then reg.data = {} end
reg.sheet_version = "1"

local DATASET = {

    {
        id = "e509045c",
        title = "Week 0 - Before Aug 11/18 - Prep for Season 2",
        items = {
            { id = "30b4da39", text = "These are things that you should do now, on all your characters, before season launch" },
            { id = "1799862a", text = "Recraft any embellishments to cloak/bracers/boots so that you can keep the power of the embellishments as you upgrade more important slots and to let you hold off crafting as long as possible. Look for loot for your armor type from the Tidebound Grotto and the first 2 bosses of Venomous Abyss to pick which slots to craft in." },
            { id = "1222989f", text = "Complete the campaign that is currently on the live servers - this is required to enter the new zones in Season 2!" },
            { id = "89973dea", text = "Finish your Omnium Foil questline - this power lasts through the entire expansion" },
            { id = "abbe6f81", text = "Optional degenerate crest save character strategy - check guide for more info" },
            { id = "facfee6f", text = "I've published a new guide outlining what's coming. Week by Week advice will be added closer to season launch" },
        },
    },
    {
        id = "4f758212",
        title = "Week 2 on - Aug 18/25?? - Season starts",
        items = {
            { id = "a55dc6cf", text = "TBD - check guide" },
        },
    },
}

reg.data[LOCALE] = DATASET
