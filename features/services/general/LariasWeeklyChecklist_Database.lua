-- LariasWeeklyChecklist_Database.lua
-- SavedVariables and per-character/account-wide database helpers.
--
-- This module owns AceDB setup, display preferences, and hidden-row state used
-- by the tracking panels.

local addonName = ...
local Addon = _G[addonName]
if not Addon then return end

local type, tostring = type, tostring
local pairs, next = pairs, next
local table_sort = table.sort

-- Default values applied to each character's data block on first access.
-- Display-preference defaults live in db.global so they are shared across all
-- characters; keys with false/nil defaults are intentionally omitted.
local CHAR_DEFAULTS = {
    startAtSectionId = "",
}

local function HasLegacyProfilePayload(profile)
    if type(profile) ~= "table" then return false end
    if type(profile.checked) == "table" and next(profile.checked) then return true end
    if type(profile.collapsedSections) == "table" and next(profile.collapsedSections) then return true end
    if type(profile.trackingSnapshot) == "table" and next(profile.trackingSnapshot) then return true end
    if type(profile.startAtSectionId) == "string" and profile.startAtSectionId ~= "" then return true end
    for _, key in ipairs({
        "hideCompletedSections", "showGreatVault", "showCurrency",
        "showChangeWeekBtn", "showIlvlRefBtn", "debug",
    }) do
        if profile[key] ~= nil then return true end
    end
    return false
end

local function MigrateProfileDataToGlobalChars(self)
    if not (self and self.db and self.db.global) then return end

    local ownKey = self:GetCurrentProfileKey()
    if ownKey == "" then return end

    local chars = self.db.global.chars
    if type(chars) ~= "table" then return end

    chars[ownKey] = chars[ownKey] or {}
    local cdb = chars[ownKey]
    if cdb._migrated then return end
    cdb._migrated = true

    local oldProf = self.db and self.db.profile
    if not HasLegacyProfilePayload(oldProf) then return end

    local function shallowCopy(src, dest)
        if type(src) ~= "table" then return end
        for k, v in pairs(src) do dest[k] = v end
    end

    if type(oldProf.checked) == "table" and next(oldProf.checked) then
        cdb.checked = {}
        shallowCopy(oldProf.checked, cdb.checked)
    end
    if type(oldProf.collapsedSections) == "table" and next(oldProf.collapsedSections) then
        cdb.collapsedSections = {}
        shallowCopy(oldProf.collapsedSections, cdb.collapsedSections)
    end
    if type(oldProf.startAtSectionId) == "string" and oldProf.startAtSectionId ~= "" then
        cdb.startAtSectionId = oldProf.startAtSectionId
    end
    if type(oldProf.trackingSnapshot) == "table" and next(oldProf.trackingSnapshot) then
        cdb.trackingSnapshot = {}
        shallowCopy(oldProf.trackingSnapshot, cdb.trackingSnapshot)
    end
    for _, key in ipairs({
        "hideCompletedSections", "showGreatVault", "showCurrency",
        "showChangeWeekBtn", "showIlvlRefBtn", "debug",
    }) do
        if oldProf[key] ~= nil then cdb[key] = oldProf[key] end
    end

    oldProf.checked = nil
    oldProf.collapsedSections = nil
    oldProf.startAtSectionId = nil
    oldProf.trackingSnapshot = nil
    oldProf.hideCompletedSections = nil
    oldProf.showGreatVault = nil
    oldProf.showCurrency = nil
    oldProf.showChangeWeekBtn = nil
    oldProf.showIlvlRefBtn = nil
    oldProf.debug = nil
end

function Addon:SetupAddonDB()
    if self.db then return end

    local defaults = {
        profile = {},  -- intentionally empty; all data lives in global
        global = {
            _newestSeenRemoteVersion = "",
            _newestSeenRemoteSender  = "",
            -- Account-wide UI state (shared across all characters on this account).
            mainFramePos  = false,
            mainFrameWin  = false,  -- LibWindow-1.1 position+scale storage
            mainFrameSize = false,
            ilvlRefPos    = false,
            ilvlRefSize   = false,
            uiScalePct    = 100,
            uiOpacityPct  = 65,
            themeColors   = {},  -- { bgR, bgG, bgB, textR, textG, textB }
            minimap       = {},  -- LibDBIcon position/hide state
            charClasses   = {},  -- [profileKey] = classToken (e.g. "WARRIOR")
            charLevels    = {},  -- [profileKey] = player level at last login
            hiddenChars   = {},  -- [profileKey] = true
            -- Account-wide display preferences.
            hideCompletedSections = true,
            showGreatVault        = true,
            showCurrency          = true,
            showChangeWeekBtn     = false,
            showIlvlRefBtn        = true,
            showCharPickerBtn     = true,
            showAltSummaryBtn     = true,
            showScaleSlider       = true,
            showOpacitySlider     = true,
            hideUpdateNotice      = false,
            localeOverride        = "",  -- "" = auto
            -- Per-character data, keyed by "CharName - Realm".
            chars = {},
        },
    }

    -- AceDB still gives each character a profile slot for profileKeys
    -- enumeration, but all actual addon data lives in global.chars.
    self.db = LibStub("AceDB-3.0"):New(addonName .. "DB", defaults)
    MigrateProfileDataToGlobalChars(self)
end

local function RefreshAfterHiddenChange(self)
    if self.RequestTrackingUpdate then self:RequestTrackingUpdate() end
    if self.RefreshAltsSummary    then self:RefreshAltsSummary()    end
    if self.SyncGearPopup         then self:SyncGearPopup()         end
    if self._restoreHiddenFrame and self._restoreHiddenFrame:IsShown() then
        self:OpenRestoreHiddenCurrencies(nil)
    end
end

local function GetActiveCharKey(self)
    return self._viewingChar or self:GetCurrentProfileKey()
end

local function ReadCharDB(self)
    local key = GetActiveCharKey(self)
    local gdb = self.db and self.db.global
    return gdb and gdb.chars and gdb.chars[key]
end

local function GetOrCreateCharDB(self)
    local key = GetActiveCharKey(self)
    if not (key and key ~= "") then return nil end
    local gdb = self.db and self.db.global
    if not gdb then
        return nil
    end
    gdb.chars      = gdb.chars      or {}
    gdb.chars[key] = gdb.chars[key] or {}
    return gdb.chars[key]
end

function Addon:IsCurrencyHidden(currencyID)
    if not currencyID then return false end
    local cdb = ReadCharDB(self)
    return cdb and cdb.hiddenCurrencies and cdb.hiddenCurrencies[tostring(currencyID)] == true
end

function Addon:SetCurrencyHidden(currencyID, hidden)
    local cdb = GetOrCreateCharDB(self)
    if not cdb then return end
    cdb.hiddenCurrencies = cdb.hiddenCurrencies or {}
    cdb.hiddenCurrencies[tostring(currencyID)] = hidden or nil
    RefreshAfterHiddenChange(self)
end

function Addon:IsQuestHidden(questKey)
    if not questKey then return false end
    local cdb = ReadCharDB(self)
    return cdb and cdb.hiddenQuests and cdb.hiddenQuests[questKey] == true
end

function Addon:SetQuestHidden(questKey, hidden)
    local cdb = GetOrCreateCharDB(self)
    if not cdb then return end
    cdb.hiddenQuests = cdb.hiddenQuests or {}
    cdb.hiddenQuests[questKey] = hidden or nil
    RefreshAfterHiddenChange(self)
end

function Addon:IsItemHidden(itemID)
    itemID = tonumber(itemID)
    if not itemID then return false end
    local cdb = ReadCharDB(self)
    return cdb and cdb.hiddenItems and cdb.hiddenItems[tostring(itemID)] == true
end

function Addon:SetItemHidden(itemID, hidden)
    itemID = tonumber(itemID)
    if not itemID then return end
    local cdb = GetOrCreateCharDB(self)
    if not cdb then return end
    cdb.hiddenItems = cdb.hiddenItems or {}
    cdb.hiddenItems[tostring(itemID)] = hidden or nil
    RefreshAfterHiddenChange(self)
end

function Addon:GetHiddenQuestList()
    local cdb = ReadCharDB(self)
    local hidden = cdb and cdb.hiddenQuests
    if not hidden then return {} end
    local L = self.L or {}
    local questNames = {
        delversBounty  = L.TRACKING_QUEST_DELVERS_BOUNTY  or "Trovehunter's Bounty",
        weeklyPrey     = L.TRACKING_QUEST_WEEKLY_PREY     or "Weekly Prey",
        nullaeusSpoils = L.TRACKING_QUEST_NULLAEUS_SPOILS or "Spoils of Nullaeus",
    }
    local result = {}
    for qKey in pairs(hidden) do
        result[#result + 1] = { key = qKey, name = questNames[qKey] or qKey }
    end
    table_sort(result, function(a, b) return a.name < b.name end)
    return result
end

function Addon:GetHiddenCurrencyList()
    local cdb = ReadCharDB(self)
    local hidden = cdb and cdb.hiddenCurrencies
    if not hidden then return {} end
    local result = {}
    for idStr in pairs(hidden) do
        local id = tonumber(idStr)
        if id then
            local name = idStr
            if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
                local info = C_CurrencyInfo.GetCurrencyInfo(id)
                if info and info.name then name = info.name end
            end
            result[#result + 1] = { id = id, name = name }
        end
    end
    table_sort(result, function(a, b) return a.name < b.name end)
    return result
end

function Addon:GetHiddenItemList()
    local cdb = ReadCharDB(self)
    local hidden = cdb and cdb.hiddenItems
    if not hidden then return {} end
    local result = {}
    for idStr in pairs(hidden) do
        local id = tonumber(idStr)
        if id then
            local name = idStr
            local itemName = GetItemInfo and GetItemInfo(id)
            if itemName then name = itemName end
            result[#result + 1] = { id = id, name = name }
        end
    end
    table_sort(result, function(a, b) return a.name < b.name end)
    return result
end

local GV_BLOCK_NAMES = { "Raid", "Dungeons", "World" }

function Addon:IsGVBlockHidden(blockIdx)
    if not blockIdx then return false end
    local cdb = ReadCharDB(self)
    return cdb and cdb.hiddenGVBlocks and cdb.hiddenGVBlocks[tostring(blockIdx)] == true
end

function Addon:SetGVBlockHidden(blockIdx, hidden)
    local cdb = GetOrCreateCharDB(self)
    if not cdb then return end
    cdb.hiddenGVBlocks = cdb.hiddenGVBlocks or {}
    cdb.hiddenGVBlocks[tostring(blockIdx)] = hidden or nil
    RefreshAfterHiddenChange(self)
end

function Addon:GetHiddenGVBlockList()
    local cdb = ReadCharDB(self)
    local hidden = cdb and cdb.hiddenGVBlocks
    if not hidden then return {} end
    local result = {}
    for idxStr in pairs(hidden) do
        local idx = tonumber(idxStr)
        if idx and GV_BLOCK_NAMES[idx] then
            result[#result + 1] = { idx = idx, name = GV_BLOCK_NAMES[idx] }
        end
    end
    table_sort(result, function(a, b) return a.idx < b.idx end)
    return result
end

function Addon:EnsureDB()
    if not self.db then
        self:SetupAddonDB()
    end

    local key = GetActiveCharKey(self)
    local chars = self.db.global.chars
    if not chars[key] then chars[key] = {} end

    local cdb = chars[key]
    if not cdb._lariasDefaultsApplied then
        for k, v in pairs(CHAR_DEFAULTS) do
            if cdb[k] == nil then cdb[k] = v end
        end
        if cdb.checked           == nil then cdb.checked           = {} end
        if cdb.collapsedSections == nil then cdb.collapsedSections = {} end
        if cdb.trackingSnapshot  == nil then cdb.trackingSnapshot  = {} end
        if cdb.sectionCompleted  == nil then cdb.sectionCompleted  = {} end
        cdb._lariasDefaultsApplied = true
    end

    return cdb
end

function Addon:EnsurePrefs()
    if not self.db then
        self:SetupAddonDB()
    end

    return self.db.global
end
