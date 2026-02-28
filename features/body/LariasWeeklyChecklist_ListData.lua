--[[
    LariasWeeklyChecklist_ListData.lua
    features/body/

    List-content layer: retrieves the weekly checklist dataset from the shared
    locale registry and prunes any stale SavedVariables keys that no longer
    correspond to known sections or items.
]]

local addonName = ...
local Addon = _G[addonName]
if not Addon then return end

-- ── GetLocaleRegistry ─────────────────────────────────────────────────────────
-- Returns the shared locale registry table written by enUS_Data.lua and the
-- localization companion addon. Kept local so it doesn't pollute globals.
local LOCALE_REGISTRY_KEY = "LARIASWEEKLYCHECKLIST_LOCALE_REGISTRY"
local function GetLocaleRegistry()
    return _G[LOCALE_REGISTRY_KEY]
end

-- ── Addon:GetListData ─────────────────────────────────────────────────────────
-- Return the checklist dataset for the current effective locale.
-- Cached by locale code because the dataset is static per session.
function Addon:GetListData()
    local reg = GetLocaleRegistry()
    local dataByLocale = reg and reg.data
    if type(dataByLocale) ~= "table" then return {} end

    local localeCode = self:GetEffectiveLocaleCode()

    if self._cachedListLocaleCode == localeCode and type(self._cachedListData) == "table" then
        return self._cachedListData
    end

    local data = dataByLocale[localeCode]
    if type(data) == "table" then
        self._cachedListLocaleCode = localeCode
        self._cachedListData = data
        return data
    end

    data = dataByLocale.enUS
    if type(data) == "table" then
        self._cachedListLocaleCode = "enUS"
        self._cachedListData = data
        return data
    end

    return {}
end

-- ── Addon:PruneObsoleteSavedState ─────────────────────────────────────────────
-- Walks the saved checked/collapsed tables and removes any keys that no longer
-- correspond to a section or item in the current dataset. Runs once per session.
function Addon:PruneObsoleteSavedState()
    if self._svPrunedThisSession then return end
    self._svPrunedThisSession = true

    local db = self:EnsureDB()
    if type(db) ~= "table" then return end
    if type(db.checked) ~= "table" and type(db.collapsedSections) ~= "table" then
        return
    end

    if type(self.GetListData) ~= "function" then return end
    local data = self:GetListData()
    if type(data) ~= "table" then return end

    local validSections = {}
    local validItemKeys = {}

    local function MakeKey(sectionId, itemId)
        return tostring(sectionId) .. ":" .. tostring(itemId)
    end

    for _, section in ipairs(data) do
        if type(section) == "table" and type(section.id) == "string" then
            validSections[section.id] = true
            local items = section.items
            if type(items) == "table" then
                for _, item in ipairs(items) do
                    if type(item) == "table" and type(item.id) == "string" then
                        validItemKeys[MakeKey(section.id, item.id)] = true
                    end
                end
            end
        end
    end

    local removedChecked   = 0
    local removedCollapsed = 0

    if type(db.checked) == "table" then
        for k in pairs(db.checked) do
            if not validItemKeys[k] then
                db.checked[k] = nil
                removedChecked = removedChecked + 1
            end
        end
    end

    if type(db.collapsedSections) == "table" then
        for k in pairs(db.collapsedSections) do
            if not validSections[k] then
                db.collapsedSections[k] = nil
                removedCollapsed = removedCollapsed + 1
            end
        end
    end

    if (removedChecked > 0 or removedCollapsed > 0) and self.Debugf then
        self:Debugf("sv_prune", "Pruned SV: checked=%d collapsed=%d", removedChecked, removedCollapsed)
    end
end
