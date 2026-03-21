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
local LOCALE_REGISTRY_KEY = Addon.LOCALE_REGISTRY_KEY
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

    -- Backfill: seed sectionCompleted for sections that were fully checked in
    -- db.checked, so the sticky flag works after upgrades.  Re-runs whenever
    -- the sheet version changes so renamed items (which regenerate hash IDs
    -- via sheet_to_lua) don't break already-completed weeks.
    --
    -- Two signals are combined to handle the three common update patterns:
    --   (a) items renamed  → old IDs pruned, new IDs added; checkedCount stays
    --       the same but matchCount drops.  checkedCount >= currentCount catches
    --       this when item counts don't change net, and the 90% threshold below
    --       helps when a couple of new items were also added.
    --   (b) items removed  → currentCount shrinks; checkedCount >= currentCount
    --       still holds.
    --   (c) items added to an already-complete section (e.g. items moved in
    --       from a deleted section) → checkedCount < currentCount but the ratio
    --       is still high; the 90% threshold catches this.
    local currentSheetVer = (function()
        local r = GetLocaleRegistry()
        return r and tostring(r.sheet_version or "") or ""
    end)()
    -- v2 sentinel: forces one extra run for saves that already had the v1
    -- sentinel written (which used strict >= and missed the 90% threshold).
    if (db._sectionCompletedSeedVer2 or "") ~= currentSheetVer and
       type(db.checked) == "table" then
        db._sectionCompletedSeedVer2 = currentSheetVer
        if type(db.sectionCompleted) ~= "table" then db.sectionCompleted = {} end
        -- Count checked entries per section prefix (format: "sectionId:itemId").
        local checkedBySection = {}
        for key in pairs(db.checked) do
            local colonPos = string.find(key, ":", 1, true)
            if colonPos and colonPos > 1 then
                local sid = string.sub(key, 1, colonPos - 1)
                checkedBySection[sid] = (checkedBySection[sid] or 0) + 1
            end
        end
        for _, section in ipairs(data) do
            local sid = section.id
            if type(sid) == "string" and type(section.items) == "table" and
               #section.items > 0 then
                local currentCount = #section.items
                local checkedCount = checkedBySection[sid] or 0
                if checkedCount == 0 then
                    -- Nothing was ever checked in this section; skip.
                else
                    -- Threshold: 90% of current items must be covered by old
                    -- checked entries.  math.max(1,…) avoids a zero floor for
                    -- single-item sections.  This is intentionally slightly
                    -- lenient so that a section completed at the previous
                    -- version survives even if 1-2 new items were added to it.
                    local threshold = math.max(1, math.floor(currentCount * 0.9))
                    if checkedCount >= threshold then
                        db.sectionCompleted[sid] = true
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

    if type(db.sectionCompleted) == "table" then
        for k in pairs(db.sectionCompleted) do
            if not validSections[k] then
                db.sectionCompleted[k] = nil
            end
        end
    end

    if (removedChecked > 0 or removedCollapsed > 0) and self.Debugf then
        self:Debugf("sv_prune", "Pruned SV: checked=%d collapsed=%d", removedChecked, removedCollapsed)
    end
end
