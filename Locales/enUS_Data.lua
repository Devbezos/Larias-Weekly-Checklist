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
        id = "03316bcb",
        title = "Week 1 - Aug 11?? - Pre-Season",
        items = {
            { id = "facfee6f", text = "I've published a new guide outlining what's coming. Week by Week advice will be added closer to season launch" },
        },
    },
    {
        id = "fe096bf2",
        title = "Week 2 on - Aug 18?? - Season starts",
        items = {
            { id = "a55dc6cf", text = "TBD - check guide" },
        },
    },
}

reg.data[LOCALE] = DATASET
