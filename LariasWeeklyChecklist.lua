-- Main addon entry point.
-- Responsibilities:
-- - Initialize locale registry + apply locale overlay.
-- - Load tracking/constants.
-- - Build and refresh the checklist UI (list + options + tracking panel).
--
-- Design goal: keep runtime behavior event-driven and avoid per-frame work.
local addonName = ...
-- NOTE: AceComm-3.0 and AceBucket-3.0 are intentionally NOT listed here.
-- Embedding them at NewAddon time causes a hard Lua error if the library is
-- missing or overshadowed by another addon's Ace3 build that omits them,
-- which prevents the entire file from loading (including slash commands).
-- AceComm is embedded conditionally in CommsOnEnable instead.
local Addon = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceEvent-3.0", "AceConsole-3.0", "AceTimer-3.0")
_G[addonName] = Addon

-- Shared global registry used by both the main addon and the optional
-- localization companion addon. Locale files register into this table.
local LOCALE_REGISTRY_KEY = "LARIASWEEKLYCHECKLIST_LOCALE_REGISTRY"

-- Ensure the global locale registry exists and has the expected shape.
-- reg.strings[locale] = localized UI strings
-- reg.data[locale] = checklist dataset
local function GetLocaleRegistry()
    local reg = _G[LOCALE_REGISTRY_KEY]
    if type(reg) ~= "table" then
        reg = {}
        _G[LOCALE_REGISTRY_KEY] = reg
    end
    if type(reg.strings) ~= "table" then reg.strings = {} end
    if type(reg.data) ~= "table" then reg.data = {} end
    return reg
end

-- Safe frame visibility check (works across different object shapes).
local function IsFrameShown(frameObj)
    return frameObj and frameObj.IsShown and frameObj:IsShown()
end

Addon.L = Addon.L or {}
local L = Addon.L

do
    local reg = GetLocaleRegistry()
    Addon.LOCALES = reg.strings
    Addon.LIST_DATA = reg.data

    -- Seed `Addon.L` with enUS immediately so early UI (and things like
    -- CreateFrame called before DB init) never needs hardcoded English fallbacks.
    local seed = reg.strings and reg.strings.enUS
    if type(seed) == "table" then
        for k, v in pairs(seed) do
            Addon.L[k] = v
        end
    end
end

-- Initialize all constants on the new Addon object
do
    -- Deep copy with cycle detection.
    -- Used to avoid mutating the exported constants table by accident.
    local function DeepCopyTable(src, seen)
        if type(src) ~= "table" then return src end
        seen = seen or {}
        if seen[src] then return seen[src] end

        local dst = {}
        seen[src] = dst
        for k, v in pairs(src) do
            dst[DeepCopyTable(k, seen)] = DeepCopyTable(v, seen)
        end
        return dst
    end

    -- Load tracking/constants from the constants file and apply defaults.
    -- NOTE: this intentionally replaces Addon.TRACKING as a whole to make
    -- "remove a key" edits in the constants file take effect immediately.
    function Addon:InitConstants(addonNameInput)
        addonNameInput = addonNameInput or addonName

        local locale = self.L or {}

        -- Group core constants into objects (tables).
        self.CONSTANTS = self.CONSTANTS or {}
        self.CONSTANTS.names = self.CONSTANTS.names or {}
        local names = self.CONSTANTS.names

        if names.displayName == nil then names.displayName = locale.DISPLAY_NAME or addonNameInput end
        if names.accountDbName == nil then names.accountDbName = "LariasWeeklyChecklistDB" end

        self.DISPLAY_NAME = self.DISPLAY_NAME or names.displayName
        self._ACCOUNT_DB_NAME = self._ACCOUNT_DB_NAME or names.accountDbName

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
            scrollTop = 38,
            scrollBottom = 16,
            scrollRight = 30,
            sectionGap = 10,
            sectionTopPad = 10,
            headerMinH = 22,
            headerBottomPad = 4,
            headerTextExtraW = 28,
            itemMinH = 24,
            itemTextPad = 8,
            itemTextWidth = 358,
            sectionInsetX = 14,
            trackH = 250,
            trackTopPad = 10,
            sliderH = 20,
            sliderBottomPad = 4,
            sliderTopPad = 4,
        }
        self.UI = self.UI or self.CONSTANTS.ui

        self.TRACKING = self.TRACKING or {}

        -- Tracking IDs are sourced from `LariasWeeklyChecklist_Constants.lua`.
        -- This keeps one obvious edit spot for currency/achievement/quest IDs.

        -- Optional user overrides (IDs, tracking settings, etc.)
        -- Loaded from `LariasWeeklyChecklist_Constants.lua` via _G["<addonName>_CONSTANTS"].
        local constantsKey = tostring(addonNameInput or addonName) .. "_CONSTANTS"
        local constants = _G and _G[constantsKey]
        local trackingConstants
        if type(constants) == "table" then
            trackingConstants = constants
        end

        if type(trackingConstants) == "table" then
            -- Constants are authoritative: replace the whole tracking table.
            -- This makes "remove a key" (e.g. commenting out an ID) take effect immediately.
            self.TRACKING = DeepCopyTable(trackingConstants)
            -- Feature flags live inside the constants file so there is one edit spot.
            self.FEATURE_FLAGS = type(trackingConstants.featureFlags) == "table"
                and DeepCopyTable(trackingConstants.featureFlags)
                or {}
        else
            -- If the constants file is missing or failed to load, we don't silently invent IDs.
            -- Leave defaults as-is and print a single warning.
            self.FEATURE_FLAGS = self.FEATURE_FLAGS or {}
            if not self._warnedMissingConstants then
                self._warnedMissingConstants = true
                if self.Print then
                    self:Print("Warning: constants file missing; tracking IDs not loaded.")
                end
            end
        end

        -- Optional keys may be missing; the tracking UI tolerates that.
    end

    Addon:InitConstants(addonName)
end

-- Now that InitConstants has run, we can safely reference THEME and UI
local frame
local scrollFrame
local scrollChild
local type, tostring = type, tostring
local pairs, ipairs, next = pairs, ipairs, next
local max = math.max
local min = math.min
local tinsert, tremove, tconcat = table.insert, table.remove, table.concat
local CreateFrame = CreateFrame

Addon._debugRate = Addon._debugRate or {}

-- Debug is an opt-in flag stored in per-character saved variables.
function Addon:IsDebugEnabled()
    if not (self.db and self.db.global) then return false end
    local ownKey = self:GetCurrentProfileKey()
    local cdb = self.db.global.chars and self.db.global.chars[ownKey]
    return cdb and cdb.debug and true or false
end

-- Rate-limited printf-style debug output.
-- rateKey: if provided, suppress repeats for ~2s.
function Addon:Debugf(rateKey, fmt, ...)
    if not self:IsDebugEnabled() then return end

    local msg
    if type(fmt) == "string" then
        local ok, formatted = pcall(string.format, fmt, ...)
        msg = ok and formatted or fmt
    else
        msg = tostring(fmt)
    end

    local now = (GetTime and GetTime()) or 0
    if rateKey then
        rateKey = tostring(rateKey)
        local last = tonumber(self._debugRate[rateKey] or 0) or 0
        if (now - last) < 2.0 then
            return
        end
        self._debugRate[rateKey] = now
    end

    if self.Print then
        self:Print("[debug] " .. msg)
    end
end

local LOCALIZATION_ADDON_NAME = "LariasWeeklyChecklist_Localization"
Addon.LOCALIZATION_COMPANION_HINT_TEXT = Addon.LOCALIZATION_COMPANION_HINT_TEXT
    or "Tip: For non-English translations, install the optional addon 'LariasWeeklyChecklist: Localization'."

function Addon:IsLocalizationCompanionLoaded()
    if type(C_AddOns) == "table" and type(C_AddOns.IsAddOnLoaded) == "function" then
        return C_AddOns.IsAddOnLoaded(LOCALIZATION_ADDON_NAME)
    end
    if type(IsAddOnLoaded) == "function" then
        return IsAddOnLoaded(LOCALIZATION_ADDON_NAME)
    end
    return false
end

function Addon:HasNonEnUSLocaleTables()
    local reg = GetLocaleRegistry()
    local strings = reg and reg.strings or nil
    local data = reg and reg.data or nil

    if type(strings) == "table" then
        for k, v in pairs(strings) do
            if k ~= "enUS" and type(v) == "table" then
                return true
            end
        end
    end
    if type(data) == "table" then
        for k, v in pairs(data) do
            if k ~= "enUS" and type(v) == "table" then
                return true
            end
        end
    end

    return false
end

function Addon:ShouldShowLocalizationCompanionHint()
    local client = (GetLocale and GetLocale()) or "enUS"
    if tostring(client) == "enUS" then return false end
    if self:IsLocalizationCompanionLoaded() then return false end
    if self:HasNonEnUSLocaleTables() then return false end
    return true
end

-- Session-only locale override set by slash command.
-- This intentionally does NOT persist across /reload or relog.
-- Addon._sessionLocaleOverride is set by the /larias locale command.

-- Default values applied to each character's data block on first access.
-- Keys with false/nil defaults are omitted here; the inline logic in EnsureDB
-- uses "if == nil" checks to stay concise.
local CHAR_DEFAULTS = {
    hideCompletedSections = true,
    showGreatVault        = true,
    showCurrency          = true,
    showChangeWeekBtn     = true,
    showIlvlRefBtn        = true,
    showCharPickerBtn     = true,
    showScaleSlider       = true,
    debug                 = false,
    startAtSectionId      = "",
}

-- Set up database with AceDB
local function SetupAddonDB()
    if Addon.db then return end

    local defaults = {
        profile = {},  -- intentionally empty; all data lives in global
        global = {
            _newestSeenRemoteVersion = "",
            _newestSeenRemoteSender  = "",
            _dismissedRemoteVersion  = "",
            -- Account-wide UI state (shared across all characters on this account).
            mainFramePos  = false,
            mainFrameWin  = false,  -- LibWindow-1.1 position+scale storage
            mainFrameSize = false,
            ilvlRefPos    = false,
            ilvlRefSize   = false,
            uiScalePct    = 100,
            minimap       = {},  -- LibDBIcon position/hide state (account-wide)
            charClasses   = {},  -- [profileKey] = classToken (e.g. "WARRIOR")
            hiddenChars   = {},  -- [profileKey] = true (hidden from char picker dropdown)
            -- Per-character data, each keyed by "CharName - Realm".
            -- Holds checked items, collapsed sections, preferences, snapshot, etc.
            chars = {},
        },
    }

    -- nil default: AceDB still gives each character their own profile slot
    -- (used only for sv.profileKeys enumeration). All actual data is in global.chars.
    Addon.db = LibStub("AceDB-3.0"):New(addonName .. "DB", defaults)
end

-- One-time migration: copy per-character data from the old AceDB profile system
-- into the new global.chars[profileKey] structure.
-- Stores a _migrated=true sentinel inside each character's chars entry so each
-- character is migrated exactly once regardless of who logs in first.
-- IMPORTANT: must be called before any EnsureDB() call so that the chars entry
-- doesn't already exist from EnsureDB's inline-defaults path.
local function MigrateProfileDataToGlobalChars()
    if not (Addon.db and Addon.db.global) then return end
    local ownKey = Addon:GetCurrentProfileKey()
    if ownKey == "" then return end

    local chars = Addon.db.global.chars
    if not chars then return end

    -- Per-character sentinel: already migrated if the flag is set.
    chars[ownKey] = chars[ownKey] or {}
    local cdb = chars[ownKey]
    if cdb._migrated then return end
    cdb._migrated = true

    -- Pull whatever is in the old profile for this character.
    local oldProf = Addon.db and Addon.db.profile
    if not oldProf then return end

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
    -- Preferences
    for _, k in ipairs({ "hideCompletedSections", "showGreatVault", "showCurrency",
                         "showChangeWeekBtn", "showIlvlRefBtn", "showCharPickerBtn", "debug" }) do
        if oldProf[k] ~= nil then cdb[k] = oldProf[k] end
    end

    -- Wipe old profile data now that everything has been copied to global.chars.
    -- This prevents duplicate storage in SavedVariables.
    oldProf.checked           = nil
    oldProf.collapsedSections = nil
    oldProf.startAtSectionId  = nil
    oldProf.trackingSnapshot  = nil
    oldProf.hideCompletedSections = nil
    oldProf.showGreatVault    = nil
    oldProf.showCurrency      = nil
    oldProf.showChangeWeekBtn = nil
    oldProf.showIlvlRefBtn    = nil
    oldProf.showCharPickerBtn = nil
    oldProf.debug             = nil
end

-- Set up LibDataBroker and LibDBIcon for minimap icon
local function SetupMinimapIcon()
    local LDB = LibStub("LibDataBroker-1.1")
    local icon = LibStub("LibDBIcon-1.0")
    
    local dataObject = LDB:NewDataObject(addonName, {
        type = "data source",
        text = addonName,
        icon = "Interface\\AddOns\\LariasWeeklyChecklist\\Media\\icon",
        OnClick = function(self_, button)
            if button == "LeftButton" then
                if Addon.CreateFrame then
                    Addon:CreateFrame()
                end
                Addon:Toggle()
            elseif button == "RightButton" then
                -- Open the gear popup anchored to the minimap button.
                if Addon.ToggleGearPopup then
                    Addon:ToggleGearPopup(self_)
                end
            elseif button == "MiddleButton" then
                if Addon.ToggleIlvlRefWindow then
                    Addon:ToggleIlvlRefWindow()
                end
            end
        end,
        OnTooltipShow = function(tooltip)
            if not tooltip then return end
            tooltip:AddLine(L.DISPLAY_NAME or addonName, 1, 0.82, 0)
            tooltip:AddLine(L.MINIMAP_TOOLTIP_LEFT_CLICK_TOGGLE or "", 1, 1, 1)
            tooltip:AddLine(L.MINIMAP_TOOLTIP_RIGHT_CLICK_OPTIONS or "", 1, 1, 1)
            tooltip:AddLine(L.MINIMAP_TOOLTIP_MIDDLE_CLICK_ILVL or "Middle-click: toggle ilvl refs", 1, 1, 1)

            if Addon.ShouldShowLocalizationCompanionHint and Addon:ShouldShowLocalizationCompanionHint() then
                tooltip:AddLine(" ")
                tooltip:AddLine(Addon.LOCALIZATION_COMPANION_HINT_TEXT, 0.9, 0.9, 0.9)
            end
        end,
    })
    
    -- Store minimap config in the global DB so LibDBIcon persists the icon
    -- position and hide-state across sessions, and so Reset List never touches it.
    local gdb = Addon.db and Addon.db.global
    if gdb then
        gdb.minimap = gdb.minimap or {}
    end
    local minimapCfg = (gdb and gdb.minimap) or {}
    icon:Register(addonName, dataObject, minimapCfg)
end

-- Initialize AceDB and minimap icon on addon load
function Addon:OnInitialize()
    SetupAddonDB()
    if self.ApplyLocaleOverride then
        self:ApplyLocaleOverride()
    end
    SetupMinimapIcon()
    -- Register the Blizzard Interface Options panel early so it appears
    -- in the Interface → AddOns list even before the window is opened.
    if self.CreateBlizzOptionsPanel then
        self:CreateBlizzOptionsPanel()
    end
end

-- Handle player login event
function Addon:OnEnable()
    -- Register console commands
    self:RegisterConsoleCommands()

    -- If the localization companion addon loads after us for any reason,
    -- re-apply locale as soon as it becomes available.
    if self.RegisterEvent and not self._listeningForAddonLoaded then
        self._listeningForAddonLoaded = true
        self:RegisterEvent("ADDON_LOADED", "OnAddonLoaded")
    end
    
    if self.CommsOnEnable then
        self:CommsOnEnable()
    end

    -- Re-apply locale after login to handle any late-loaded localization tables.
    if self.ApplyLocaleOverride then
        self._dataSig = ""
        self._cachedListLocaleCode = nil
        self._cachedListData = nil
        self:ApplyLocaleOverride()
    end

    -- One-time migration: move old AceDB profile data into global.chars[ownKey].
    -- Must run BEFORE PruneObsoleteSavedState (which calls EnsureDB and creates
    -- the chars entry, which would make the migration think it already ran).
    MigrateProfileDataToGlobalChars()

    if self.PruneObsoleteSavedState then
        self:PruneObsoleteSavedState()
    end

    -- If this character already has snapshot data from a previous session,
    -- register tracking events immediately so their snapshot stays current
    -- even if they never open the addon this session.
    if self.ConfigureTrackingEvents and self.HasTrackingSnapshot and self:HasTrackingSnapshot() then
        self:ConfigureTrackingEvents(nil, true, true)
    end

    -- Version announce happens in CommsOnEnable.
end

-- Called when *any* addon loads; we only care about the localization companion.
function Addon:OnAddonLoaded(_, loadedName)
    if loadedName ~= LOCALIZATION_ADDON_NAME then return end

    -- Refresh strings/data now that locale addon is in memory.
    if self.ApplyLocaleOverride then
        self._dataSig = ""
        self._cachedListLocaleCode = nil
        self._cachedListData = nil
        self:ApplyLocaleOverride()
    end

    -- If UI is visible, refresh it immediately.
    if IsFrameShown(frame) then
        if self.RequestRefresh then
            self:RequestRefresh()
        elseif self.Refresh then
            self:Refresh()
        end
    end
end

local function Wipe(tableToWipe)
    if not tableToWipe then return end
    if wipe then
        wipe(tableToWipe)
        return
    end
    for key in pairs(tableToWipe) do
        tableToWipe[key] = nil
    end
end

Addon._sectionPool = Addon._sectionPool or {}
Addon._checkboxPool = Addon._checkboxPool or {}
Addon._activeSections = Addon._activeSections or {}

Addon._dataSig = Addon._dataSig or ""
Addon._sectionsById = Addon._sectionsById or {}
Addon._order = Addon._order or {}
Addon._sectionsIndexById = Addon._sectionsIndexById or {}

-- Returns a stable per-character key: always "CharName - RealmName".
-- Lives in the main file so it is available before any module loads.
function Addon:GetCurrentProfileKey()
    local name  = (UnitName    and UnitName("player"))   or ""
    local realm = (GetRealmName and GetRealmName())      or ""
    if name ~= "" and realm ~= "" then return name .. " - " .. realm end
    if name ~= "" then return name end
    return ""
end

function Addon:EnsureDB()
    if not self.db then
        SetupAddonDB()
    end
    -- All per-character data lives in db.global.chars[key].  When viewing
    -- another character (_viewingChar is set) return their data; otherwise
    -- return the logged-in character's data.
    local key   = self._viewingChar or self:GetCurrentProfileKey()
    local chars = self.db.global.chars
    if not chars[key] then chars[key] = {} end
    local cdb = chars[key]
    -- Apply defaults on first access only; guard with a flag so the pairs loop
    -- does not run on every EnsureDB() call (it is called per-section on refresh).
    if not cdb._lariasDefaultsApplied then
        for k, v in pairs(CHAR_DEFAULTS) do
            if cdb[k] == nil then cdb[k] = v end
        end
        cdb._lariasDefaultsApplied = true
    end
    if cdb.checked           == nil then cdb.checked           = {} end
    if cdb.collapsedSections == nil then cdb.collapsedSections = {} end
    if cdb.trackingSnapshot  == nil then cdb.trackingSnapshot  = {} end
    return cdb
end

-- Remove stale saved-state entries (checked items / collapsed sections) that no longer
-- correspond to any known section/item IDs in the current dataset.
-- This keeps SavedVariables from accumulating garbage across data/ID refactors.
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

    local removedChecked = 0
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

-- Pick the best locale code to use (session override first, else client locale).
-- If the requested locale has no registered strings/data, fall back to enUS.
function Addon:GetEffectiveLocaleCode()
    local override = tostring(self._sessionLocaleOverride or "auto")

    local code
    if override ~= "auto" and override ~= "" then
        code = override
    else
        code = (GetLocale and GetLocale()) or "enUS"
    end

    local reg = GetLocaleRegistry()
    local hasData = reg and type(reg.data) == "table" and type(reg.data[code]) == "table"
    local hasStrings = reg and type(reg.strings) == "table" and type(reg.strings[code]) == "table"
    if hasData or hasStrings then
        return code
    end
    return "enUS"
end

-- Apply the effective locale to Addon.L.
-- Strategy: enUS base + selected overlay; never leave Addon.L empty.
function Addon:ApplyLocaleOverride()
    local reg = GetLocaleRegistry()
    local strings = reg and reg.strings
    if type(strings) ~= "table" then strings = {} end

    -- Defensive: never leave `self.L` empty due to missing/late-loaded locale files.
    local previous = {}
    if type(self.L) == "table" then
        for k, v in pairs(self.L) do
            previous[k] = v
        end
    end

    local selected = self:GetEffectiveLocaleCode()

    Wipe(self.L)

    local fallback = strings.enUS
    if type(fallback) == "table" then
        for k, v in pairs(fallback) do
            self.L[k] = v
        end
    end

    local overlay = strings[selected]
    if type(overlay) == "table" then
        for k, v in pairs(overlay) do
            self.L[k] = v
        end
    end

    -- If locale tables weren't available for some reason, restore the prior strings.
    if next(self.L) == nil and next(previous) ~= nil then
        for k, v in pairs(previous) do
            self.L[k] = v
        end
    end

    if self.L and self.L.DISPLAY_NAME then
        self.DISPLAY_NAME = self.L.DISPLAY_NAME
    end

    if self.UpdateLocalizedUI then
        self:UpdateLocalizedUI()
    end
end

-- Set a session-only locale override (does not persist to SavedVariables).
function Addon:SetLocaleOverride(value)
    value = tostring(value or "auto")
    if value == "" then value = "auto" end

    -- Session-only: do not persist to SavedVariables.
    if value == "auto" then
        self._sessionLocaleOverride = nil
    else
        self._sessionLocaleOverride = value
    end

    self:ApplyLocaleOverride()

    self._dataSig = ""
    self._cachedListLocaleCode = nil
    self._cachedListData = nil

    if IsFrameShown(frame) then
        if self.RequestRefresh then
            self:RequestRefresh()
        elseif self.Refresh then
            self:Refresh()
        end
    end
end

-- Opens the Blizzard Interface Options panel to the addon's category.
-- Right-click on the minimap icon calls this.
function Addon:OpenOptions()
    if self.CreateBlizzOptionsPanel then
        self:CreateBlizzOptionsPanel()
    end
    if self._blizzOptCategory and Settings and Settings.OpenToCategory then
        local catId = self._blizzOptCategory.GetID and self._blizzOptCategory:GetID() or self._blizzOptCategory
        Settings.OpenToCategory(catId)
    elseif InterfaceOptionsFrame_OpenToCategory and self._blizzOptPanel then
        InterfaceOptionsFrame_OpenToCategory(self._blizzOptPanel)
    elseif InterfaceOptionsFrame then
        InterfaceOptionsFrame:Show()
    end
end

-- Options tab removed; SelectMainTab is kept as a no-op stub for call-site safety.
function Addon:SelectMainTab(tabId)
    self:CreateFrame()
    if not frame then return end
    if scrollFrame and scrollFrame.SetShown then
        scrollFrame:SetShown(true)
    end
    if self.ApplyTrackingPanelOptions then
        self:ApplyTrackingPanelOptions()
    elseif self.UpdateTracking then
        self:UpdateTracking()
    end
    if self.RequestRefresh then
        self:RequestRefresh()
    elseif self.Refresh then
        self:Refresh()
    end
end

-- Return the checklist dataset for the current effective locale.
-- This is cached by locale code because the dataset is static per session.
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

-- Update UI elements whose text depends on locale.
-- Called after locale is (re)applied and after frame creation.
function Addon:UpdateLocalizedUI()
    if not frame then return end

    if self.UpdateOptionsLocalizedUI then
        self:UpdateOptionsLocalizedUI()
    end

    if self.RebuildIlvlRefWindow then
        self:RebuildIlvlRefWindow()
    end

    local changeWeekBtn = frame._lariasChangeWeekBtn
    if changeWeekBtn then
        -- Change week button shows the current week label; re-run layout to refresh it.
        if self.LayoutHeaderButtons then self:LayoutHeaderButtons() end
    end

    local ilvlRefBtn = frame._lariasIlvlRefBtn
    if ilvlRefBtn and ilvlRefBtn.SetText then
        ilvlRefBtn:SetText(L.ILVLREF_BUTTON or "View Item Levels")
    end

    local trackingFrame = self._trackingFrame
    if trackingFrame then
        if trackingFrame._lariasLeftTitle and trackingFrame._lariasLeftTitle.SetText then
            trackingFrame._lariasLeftTitle:SetText(L.TRACKING_GREAT_VAULT_TITLE or "Great Vault")
        end
        if trackingFrame._lariasRightTitle and trackingFrame._lariasRightTitle.SetText then
            trackingFrame._lariasRightTitle:SetText(L.TRACKING_CURRENCY_TITLE or "Currency")
        end
    end
end

-- Apply the shared theme backdrop to a frame.
-- Also mixes in BackdropTemplateMixin when the frame lacks SetBackdrop, so
-- callers don't need a separate Mixin guard before calling this.
function Addon:ApplyTheme(frameObj)
    if not frameObj then return end
    if not frameObj.SetBackdrop and BackdropTemplateMixin and Mixin then
        Mixin(frameObj, BackdropTemplateMixin)
    end
    if not frameObj.SetBackdrop then return end
    frameObj:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        edgeSize = 1,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frameObj:SetBackdropColor(Addon.THEME.bg.r, Addon.THEME.bg.g, Addon.THEME.bg.b, Addon.THEME.bg.a)
    frameObj:SetBackdropBorderColor(Addon.THEME.border.r, Addon.THEME.border.g, Addon.THEME.border.b, Addon.THEME.border.a)
end

-- Create a new Frame, apply BackdropTemplate if available, and theme it.
-- name is optional (nil = anonymous). parent defaults to UIParent.
function Addon:NewThemedFrame(name, parent)
    local f
    if BackdropTemplateMixin then
        f = CreateFrame("Frame", name, parent or UIParent, "BackdropTemplate")
    else
        f = CreateFrame("Frame", name, parent or UIParent)
    end
    self:ApplyTheme(f)
    return f
end

-- Recompute the scroll frame anchors.
-- The list needs to shift upward when the tracking panel is visible.
function Addon:ApplyScrollLayout()
    if not (frame and scrollFrame) then return end
    local db = self:EnsureDB()

    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", Addon.UI.padOuterX, -Addon.UI.scrollTop)

    local extra = 0
    if (db.showGreatVault or db.showCurrency) and IsFrameShown(self._trackingFrame) then
        local trackingHeight = (self._trackingFrame.GetHeight and self._trackingFrame:GetHeight()) or Addon.UI.trackH
        trackingHeight = tonumber(trackingHeight) or Addon.UI.trackH
        local sf           = self._inFrameScaleSlider
        local sliderShown  = sf and sf.IsShown and sf:IsShown()
        local sliderH      = sliderShown and (Addon.UI.sliderH         or 0) or 0
        local sliderBotPad = sliderShown and (Addon.UI.sliderBottomPad or 0) or 0
        local sliderTopPad = sliderShown and (Addon.UI.sliderTopPad    or 0) or 0
        extra = trackingHeight + Addon.UI.trackTopPad
              + sliderH + sliderBotPad + sliderTopPad - Addon.UI.scrollBottom
    end

    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -Addon.UI.scrollRight, Addon.UI.scrollBottom + extra)

    -- Recompute itemTextWidth from the live frame width so text never over-runs
    -- or wastes space after a resize. Frame and all children share the same
    -- coordinate space (frame:SetScale scales visually without changing logical sizes).
    local currentFrameW = frame:GetWidth() or Addon.UI.frameW
    local newTextW = math.max(120, math.floor(
        currentFrameW
        - Addon.UI.padOuterX
        - Addon.UI.scrollRight
        - 2 * Addon.UI.sectionInsetX
        - 38
    ))
    if newTextW ~= Addon.UI.itemTextWidth then
        Addon.UI.itemTextWidth = newTextW
        -- Apply directly to all live text labels immediately — SyncCheckboxesForSection
        -- only runs when data changes, so we can't rely on a queued Refresh for this.
        local headerTextW = newTextW + (Addon.UI.headerTextExtraW or 0)
        for _, sectionFrame in ipairs(Addon._activeSections or {}) do
            -- Update section header text width.
            if sectionFrame._title and sectionFrame._title.SetWidth then
                sectionFrame._title:SetWidth(headerTextW)
            end
            -- Update each checkbox's text label.
            local checkboxes = sectionFrame._checkboxes or {}
            for j = 1, #checkboxes do
                local cb = checkboxes[j]
                local textLabel = cb.text or cb.Text
                if textLabel and textLabel.SetWidth then
                    textLabel:SetWidth(newTextW)
                end
            end
        end
    end

    if self._trackingFrame and self.ResizeTrackingCols then
        self:ResizeTrackingCols()
    end
end

function Addon:GetUIScale()
    local pct = (self.db and self.db.global and tonumber(self.db.global.uiScalePct)) or 100
    return math.max(0.5, math.min(1.5, pct / 100))
end

function Addon:ApplyUIScale()
    local scale = self:GetUIScale()
    if frame and frame.SetScale then
        -- Scale around the visual center: capture screen-absolute center coords
        -- before scaling, apply SetScale, then re-anchor so the same screen pixel
        -- sits at the center of the (now larger/smaller) frame.
        -- Finally call LW.SavePosition so LibWindow's storage matches.
        local oldScale = frame:GetScale()
        local fl = frame:GetLeft()
        local fb = frame:GetBottom()
        local fw = frame:GetWidth()
        local fh = frame:GetHeight()
        if fl and fb and fw and fh then
            local screenCX = (fl + fw / 2) * oldScale
            local screenCY = (fb + fh / 2) * oldScale
            local parent   = frame:GetParent() or UIParent
            frame:SetScale(scale)
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", parent, "CENTER",
                (screenCX - parent:GetWidth()  / 2) / scale,
                (screenCY - parent:GetHeight() / 2) / scale)
            local LW = LibStub("LibWindow-1.1", true)
            if LW then LW.SavePosition(frame) end
        else
            local LW = LibStub("LibWindow-1.1", true)
            if LW then LW.SetScale(frame, scale) else frame:SetScale(scale) end
        end
    end
    -- The ilvl ref window is parented to UIParent; scale it independently.
    local iw = self._ilvlRefWindow
    if iw and iw.SetScale then iw:SetScale(scale) end
    if iw and iw._ilvlReflow then iw._ilvlReflow() end
    -- Re-anchor scroll frame (text width recompute, tracking panel offset).
    if self.ApplyScrollLayout then self:ApplyScrollLayout() end
    -- Keep in-frame slider in sync with whatever changed the value.
    local sf = self._inFrameScaleSlider
    if sf and sf.Sync then sf.Sync() end
end

function Addon:ApplyScaleSliderVisibility()
    local sf = self._inFrameScaleSlider
    if not sf then return end
    local db   = self:EnsureDB()
    local show = db.showScaleSlider ~= false
    sf:SetShown(show)
    -- Re-anchor the tracking panel bottom so it fills the freed space when
    -- the slider is hidden, and retreats above the slider when visible.
    local tf = self._trackingFrame
    if tf then
        local inset = Addon.UI.sectionInsetX or 14
        local botY  = show
            and ((Addon.UI.sliderBottomPad or 4) + (Addon.UI.sliderH or 20) + (Addon.UI.sliderTopPad or 4))
            or  (Addon.UI.sliderBottomPad or 4)
        tf:ClearAllPoints()
        tf:SetPoint("BOTTOMLEFT",  tf:GetParent(), "BOTTOMLEFT",  inset,  botY)
        tf:SetPoint("BOTTOMRIGHT", tf:GetParent(), "BOTTOMRIGHT", -inset, botY)
        -- Do NOT force SetHeight here — ResizeTrackingPanelToContent already sized
        -- the frame to fit its content.  Resetting to trackH would create empty
        -- space at the bottom whenever the content is shorter than the default.
    end
    if self.ApplyScrollLayout then self:ApplyScrollLayout() end
end

local function Key(sectionId, itemId)
    -- Stable key for SavedVariables.checked.
    -- Kept as a string so it's easy to inspect/clear in SV files.
    if type(sectionId) == "string" and type(itemId) == "string" then
        return sectionId .. ":" .. itemId
    end
    return tostring(sectionId) .. ":" .. tostring(itemId)
end

local function IsItemChecked(sectionId, itemId, db)
    -- Query persisted checked state for an item.
    db = db or Addon:EnsureDB()
    return db.checked[Key(sectionId, itemId)] and true or false
end

local function IsSectionCollapsed(sectionId, db)
    -- Query persisted collapsed state for a section.
    db = db or Addon:EnsureDB()
    return db.collapsedSections[sectionId] or false
end

local function SetSectionCollapsed(sectionId, collapsed, db)
    -- Persist collapse state.
    db = db or Addon:EnsureDB()
    db.collapsedSections[sectionId] = collapsed and true or nil
end

local function IsSectionCompleteById(sectionId, db)
    -- A section is complete if every item is checked.
    local section = Addon._sectionsById[sectionId]
    if not section then return false end

    db = db or Addon:EnsureDB()
    local checked = db.checked
    local items = section.items or {}
    -- Pre-build the constant prefix once instead of Key(sectionId, id) per item.
    local prefix = tostring(sectionId) .. ":"
    for i = 1, #items do
        if not checked[prefix .. tostring(items[i].id)] then
            return false
        end
    end
    return true
end

-- UI pooling: we reuse section frames and checkboxes to avoid allocations during refresh.
local function AcquireSectionFrame()
    local sectionFrame = tremove(Addon._sectionPool)
    if sectionFrame then
        sectionFrame:Show()
        return sectionFrame
    end

    sectionFrame = CreateFrame("Frame", nil, scrollChild)
    sectionFrame:SetWidth(1)
    sectionFrame._checkboxes = {}

    local header = CreateFrame("Button", nil, sectionFrame)
    header:SetPoint("TOPLEFT", sectionFrame, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", sectionFrame, "TOPRIGHT", 0, 0)
    header:SetHeight(Addon.UI.headerMinH)
    if header.RegisterForClicks then
        header:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    end
    sectionFrame._header = header

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", header, "LEFT", 6, 0)  -- 6px left indent: 3px accent bar + 3px gap
    title:SetTextColor(Addon.THEME.header.r, Addon.THEME.header.g, Addon.THEME.header.b, Addon.THEME.header.a)
    title:SetJustifyH("LEFT")
    if title.SetWordWrap then title:SetWordWrap(true) end
    sectionFrame._title = title

    -- Colored left-edge accent bar that spans the full header height.
    local accentBar = header:CreateTexture(nil, "BORDER")
    accentBar:SetWidth(3)
    accentBar:SetPoint("TOPLEFT",    header, "TOPLEFT",    0, 0)
    accentBar:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
    accentBar:SetColorTexture(Addon.THEME.header.r, Addon.THEME.header.g, Addon.THEME.header.b, 0.80)
    sectionFrame._accentBar = accentBar

    return sectionFrame
end

local function ReleaseSectionFrame(sectionFrame)
    -- Return a section frame (and its checkboxes) to the pool.
    if not sectionFrame then return end
    sectionFrame:Hide()
    sectionFrame:ClearAllPoints()
    sectionFrame._sectionId = nil
    sectionFrame._index = nil

    if sectionFrame._checkboxes then
        for i = #sectionFrame._checkboxes, 1, -1 do
            local checkbox = sectionFrame._checkboxes[i]
            checkbox:Hide()
            checkbox:ClearAllPoints()
            checkbox._sectionId = nil
            checkbox._itemId = nil
            checkbox._dbKey = nil
            checkbox:SetScript("OnClick", nil)
            tinsert(Addon._checkboxPool, checkbox)
            sectionFrame._checkboxes[i] = nil
        end
    end

    sectionFrame._header:SetScript("OnClick", nil)
    tinsert(Addon._sectionPool, sectionFrame)
end

local function AcquireCheckbox(parentSectionFrame)
    -- Acquire (or create) a fully addon-themed checkbox row for an item.
    local checkbox = tremove(Addon._checkboxPool)
    if checkbox then
        checkbox:SetParent(parentSectionFrame)
        checkbox:Show()
    else
        checkbox = Addon.Controls.NewCheckBox(parentSectionFrame, nil, 32)
    end

    local textLabel = checkbox.text or checkbox.Text
    if textLabel then
        textLabel:SetJustifyH("LEFT")
        if textLabel.SetWordWrap then textLabel:SetWordWrap(true) end
        if textLabel.SetTextColor then
            textLabel:SetTextColor(Addon.THEME.text.r, Addon.THEME.text.g, Addon.THEME.text.b, Addon.THEME.text.a)
        end
    end

    return checkbox
end
local UpdateSectionVisuals

local function ComputeHeaderHeight(sectionFrame, headerTextWidth)
    -- Header height is dynamic based on text wrapping.
    sectionFrame._title:SetWidth(headerTextWidth)
    local textHeight = 0
    if sectionFrame._title.GetStringHeight then
        textHeight = sectionFrame._title:GetStringHeight() or 0
    end
    local headerHeight = max(Addon.UI.headerMinH, textHeight + 6)
    sectionFrame._header:SetHeight(headerHeight)
    sectionFrame._headerBlockHeight = headerHeight + Addon.UI.headerBottomPad
end

local function LayoutItems(sectionFrame, collapsed)
    -- Stack item rows under the header; hide when collapsed.
    local posY = -(sectionFrame._headerBlockHeight or (Addon.UI.headerMinH + Addon.UI.headerBottomPad))
    local totalHeight = 0
    local checkboxes = sectionFrame._checkboxes
    for i = 1, #checkboxes do
        local checkbox = checkboxes[i]
        checkbox:ClearAllPoints()
        checkbox:SetPoint("TOPLEFT", sectionFrame, "TOPLEFT", 0, posY)
        local rowHeight = checkbox:GetHeight() or Addon.UI.itemMinH
        posY = posY - rowHeight
        totalHeight = totalHeight + rowHeight
        checkbox:SetShown(not collapsed)
    end
    sectionFrame._itemsHeight = totalHeight
end

local function UpdateSectionHeight(sectionFrame, collapsed)
    -- Section height is header + optional items height.
    local totalHeight = (sectionFrame._headerBlockHeight or (Addon.UI.headerMinH + Addon.UI.headerBottomPad))
    if not collapsed then
        totalHeight = totalHeight + (sectionFrame._itemsHeight or 0)
    end
    sectionFrame:SetHeight(totalHeight)
end

local function LayoutFrom(startIndex)
    -- Re-anchor sections starting at startIndex to avoid O(n) layout on every click.
    local posY = -Addon.UI.sectionTopPad
    local paddingX = Addon.UI.sectionInsetX
    -- Hoist sectionGap: avoids two table lookups (Addon → UI → sectionGap) per visible section.
    local sectionGap = Addon.UI.sectionGap
    local activeSections = Addon._activeSections

    for i = 1, #activeSections do
        local sectionFrame = activeSections[i]
        if sectionFrame:IsShown() then
            if i < startIndex then
                posY = posY - sectionFrame:GetHeight() - sectionGap
            else
                sectionFrame:ClearAllPoints()
                sectionFrame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", paddingX, posY)
                sectionFrame:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -paddingX, posY)
                posY = posY - sectionFrame:GetHeight() - sectionGap
            end
        end
    end

    local scrollHeight = max(1, -posY + Addon.UI.sectionGap)
    scrollChild:SetHeight(scrollHeight)
end

function Addon:IsListComplete(db)
    db = db or self:EnsureDB()

    -- Ensure we have up-to-date section indexes for current dataset.
    if not self._order or #self._order == 0 then
        return false
    end

    for i = 1, #self._order do
        local sectionId = self._order[i]
        if not IsSectionCompleteById(sectionId, db) then
            return false
        end
    end

    return true
end

function Addon:UpdateCompletionEasterEgg(db)
    -- Fun cosmetic: show pig icon when everything is done.
    -- Also hides the scrollbar when the list is complete.
    if not (frame and scrollFrame) then return end

    db = db or self:EnsureDB()
    local isComplete = self:IsListComplete(db)

    local visibleSections = 0
    if self._activeSections then
        for i = 1, #self._activeSections do
            local sectionFrame = self._activeSections[i]
            if IsFrameShown(sectionFrame) then
                visibleSections = visibleSections + 1
                break
            end
        end
    end

    local showPig = isComplete and (visibleSections == 0)

    local pig = frame._lariasPigTexture
    if pig and pig.SetShown then
        pig:SetShown(showPig)
        if showPig and scrollFrame and scrollFrame.GetWidth and scrollFrame.GetHeight then
            local scrollWidth = tonumber(scrollFrame:GetWidth()) or 0
            local scrollHeight = tonumber(scrollFrame:GetHeight()) or 0
            local size = math.min(scrollWidth > 0 and scrollWidth or 260, scrollHeight > 0 and scrollHeight or 260)
            size = math.max(120, size)
            if pig.SetSize then
                pig:SetSize(size, size)
            end
        end
    end

    local sb = scrollFrame.ScrollBar
    if sb and sb.SetShown then
        sb:SetShown(not isComplete)
    elseif sb and isComplete and sb.Hide then
        sb:Hide()
    elseif sb and (not isComplete) and sb.Show then
        sb:Show()
    end
end

local function CalcDataSig(data)
    if type(data) ~= "table" then return 0 end

    -- Cache the signature on the dataset table.
    -- NOTE: This assumes list data doesn't mutate in-place without clearing __lariasSig.
    local cached = rawget(data, "__lariasSig")
    if type(cached) == "number" then
        return cached
    end

    -- Memory-friendly signature: numeric hash, no big temp tables / concatenated strings.
    -- (Collision risk is extremely low for our static dataset; acceptable for change detection.)
    local MOD = 2147483647
    local hash = 5381

    local function MixInt(x)
        x = tonumber(x) or 0
        hash = (hash * 33 + x) % MOD
    end

    local function MixString(s)
        if type(s) ~= "string" then
            s = tostring(s or "")
        end
        for k = 1, #s do
            hash = (hash * 33 + (string.byte(s, k) or 0)) % MOD
        end
    end

    MixInt(#data)
    for i = 1, #data do
        local section = data[i]
        if type(section) == "table" then
            MixString(section.id)
            local items = section.items
            if type(items) == "table" then
                MixInt(#items)
                for j = 1, #items do
                    local item = items[j]
                    if type(item) == "table" then
                        MixString(item.id)
                    else
                        MixString(item)
                    end
                end
            else
                MixInt(0)
            end
        else
            MixString(section)
            MixInt(0)
        end
    end

    data.__lariasSig = hash
    return hash
end

local function SetHeaderText(sectionFrame, sectionId, complete)
    -- Compose the section header text; uses locale strings for DONE prefix.
    local section = Addon._sectionsById[sectionId]
    if complete == nil then
        complete = IsSectionCompleteById(sectionId)
    end
    local titleText = tostring((section and section.title) or sectionId)
    if complete then titleText = (L.DONE_PREFIX or "") .. titleText end
    sectionFrame._title:SetText(titleText)
end

-- Sets the checklist item label colour based on checked state.
-- Called after every SetChecked() so the text stays in sync with the box.
local function RefreshItemTextColor(checkbox)
    local lbl = checkbox.text or checkbox.Text
    if not lbl then return end
    if checkbox:GetChecked() then
        lbl:SetTextColor(0.45, 0.45, 0.45, 0.85)
    else
        -- THEME is always populated before any checkbox exists; avoid the
        -- guarded lookup and the potential table allocation on every call.
        local t = Addon.THEME.text
        lbl:SetTextColor(t.r, t.g, t.b, t.a)
    end
end

local function OnCheckboxClick(selfBtn)
    -- Item click handler: update saved state, collapse/hide completed sections, relayout.
    -- Custom Button (not CheckButton) doesn't auto-toggle; flip state manually first so
    -- GetChecked() returns the new value for the rest of this handler.
    selfBtn:SetChecked(not selfBtn:GetChecked())
    local database = Addon:EnsureDB()
    local checked = selfBtn:GetChecked() and true or nil
    database.checked[selfBtn._dbKey or Key(selfBtn._sectionId, selfBtn._itemId)] = checked
    RefreshItemTextColor(selfBtn)

    local sectionId = selfBtn._sectionId
    local secCompleteNow = IsSectionCompleteById(sectionId, database)
    if secCompleteNow then
        SetSectionCollapsed(sectionId, true, database)
    end

    -- Auto-advance: when the user manually completes the current active week,
    -- advance startAtSectionId to the next week so explicit navigation stays in sync.
    -- Also repopulate the picker unconditionally so the ">" marker refreshes.
    if secCompleteNow then
        local order    = Addon._order or {}
        local curStart = tostring(database.startAtSectionId or "")
        -- Only update startAtSectionId when it's explicitly set (i.e. the user
        -- navigated via the picker). When it's "" the picker computes current
        -- dynamically from completion state, so no write is needed.
        if curStart ~= "" then
            local curId = curStart
            if tostring(sectionId) == curId then
                for i = 1, #order do
                    if tostring(order[i]) == curId then
                        local nextId = order[i + 1]
                        if nextId then
                            database.startAtSectionId = tostring(nextId)
                        end
                        break
                    end
                end
            end
        end
        -- Refresh picker ">" regardless of how currentId is derived.
        if Addon._PopulateHeaderPicker then
            Addon._PopulateHeaderPicker()
        end
    end

    local sectionFrame = Addon._activeSections[Addon._sectionsIndexById[sectionId]]
    if not sectionFrame then return end

    local hideDone = database.hideCompletedSections and true or false

    SetHeaderText(sectionFrame, sectionId, secCompleteNow)
    ComputeHeaderHeight(sectionFrame, Addon.UI.itemTextWidth + Addon.UI.headerTextExtraW)

    local collapsed = IsSectionCollapsed(sectionId, database) or false
    if secCompleteNow then collapsed = true end

    LayoutItems(sectionFrame, collapsed)
    UpdateSectionHeight(sectionFrame, collapsed)

    if hideDone and secCompleteNow then
        sectionFrame:Hide()
    else
        sectionFrame:Show()
    end

    LayoutFrom(sectionFrame._index or 1)

    if Addon.UpdateCompletionEasterEgg then
        Addon:UpdateCompletionEasterEgg(database)
    end
end

local function OnHeaderClick(header)
    -- Header click handler toggles collapsed state and relayouts.
    local sectionFrame = header and header._sectionFrame
    if not sectionFrame then return end
    local sectionId = sectionFrame._sectionId
    SetSectionCollapsed(sectionId, not IsSectionCollapsed(sectionId))
    if UpdateSectionVisuals then
        UpdateSectionVisuals(sectionFrame, sectionId)
    end
    LayoutFrom(sectionFrame._index or 1)
end

local function SyncCheckboxesForSection(sectionFrame, sectionId, db)
    -- Ensure the section frame has exactly one checkbox per item.
    -- This is only called when data changes or when new frames are created.
    local section = Addon._sectionsById[sectionId]
    local items = (section and section.items) or {}

    local want = #items
    local have = #sectionFrame._checkboxes

    if have > want then
        for i = have, want + 1, -1 do
            local checkbox = sectionFrame._checkboxes[i]
            checkbox:Hide()
            checkbox:ClearAllPoints()
            checkbox._sectionId = nil
            checkbox._itemId = nil
            checkbox:SetScript("OnClick", nil)
            tinsert(Addon._checkboxPool, checkbox)
            sectionFrame._checkboxes[i] = nil
        end
    elseif have < want then
        for i = have + 1, want do
            sectionFrame._checkboxes[i] = AcquireCheckbox(sectionFrame)
        end
    end

    -- Hoist loop-invariant UI constants so they are not re-looked-up per item.
    local itemTextWidth  = Addon.UI.itemTextWidth
    local itemTextPad    = Addon.UI.itemTextPad or 0
    local minRowHeight   = max(32, Addon.UI.itemMinH or 0)
    local checkedMap     = db.checked

    for i = 1, want do
        local item = items[i]
        local checkbox = sectionFrame._checkboxes[i]

        checkbox._sectionId = sectionId
        checkbox._itemId = item.id
        -- Compute once; reuse below instead of calling IsItemChecked (which
        -- would call Key() a second time for the same sectionId/itemId pair).
        local dbKey = Key(sectionId, item.id)
        checkbox._dbKey = dbKey

        local textLabel = checkbox.text or checkbox.Text
        if textLabel then
            textLabel:SetWidth(itemTextWidth)
            textLabel:SetText(tostring(item.text or item.id))

            local textHeight = 0
            if textLabel.GetStringHeight then
                textHeight = textLabel:GetStringHeight() or 0
            end
            checkbox:SetHeight(max(minRowHeight, textHeight + itemTextPad))
        else
            checkbox:SetHeight(minRowHeight)
        end

        checkbox:SetChecked(checkedMap[dbKey] and true or false)
        RefreshItemTextColor(checkbox)

        checkbox:SetScript("OnClick", OnCheckboxClick)
    end
end

UpdateSectionVisuals = function(sectionFrame, sectionId)
    local database = Addon:EnsureDB()

    -- Optional filter: hide everything before a selected header.
    local startId = tostring(database.startAtSectionId or "")
    if startId ~= "" then
        local startIndex = Addon._sectionsIndexById and Addon._sectionsIndexById[startId]
        if type(startIndex) == "number" and type(sectionFrame._index) == "number" and sectionFrame._index < startIndex then
            sectionFrame:Hide()
            return
        end
    end

    local complete = IsSectionCompleteById(sectionId, database)

    local hideDone = database.hideCompletedSections and true or false
    if hideDone and complete then
        sectionFrame:Hide()
        return
    end

    sectionFrame:Show()

    if complete then
        SetSectionCollapsed(sectionId, true, database)
    end

    SetHeaderText(sectionFrame, sectionId, complete)
    ComputeHeaderHeight(sectionFrame, Addon.UI.itemTextWidth + Addon.UI.headerTextExtraW)

    local collapsed = IsSectionCollapsed(sectionId, database) or false
    if complete then collapsed = true end

    local checkedMap = database.checked
    for i = 1, #sectionFrame._checkboxes do
        local checkbox = sectionFrame._checkboxes[i]
        -- Use the pre-built _dbKey instead of re-calling Key() inside IsItemChecked.
        if checkbox and checkbox._dbKey ~= nil then
            checkbox:SetChecked(checkedMap[checkbox._dbKey] and true or false)
            RefreshItemTextColor(checkbox)
        end
    end

    LayoutItems(sectionFrame, collapsed)
    UpdateSectionHeight(sectionFrame, collapsed)
end

-- Picker layout constants. Defined at file scope so any layout change
-- is a single edit rather than a hunt through PopulateHeaderPicker.
local PICKER_PAD        = 8   -- padding inside the picker frame (px)
local PICKER_ROW_HEIGHT = 24  -- height of each week-row button (px)
local PICKER_ROW_WIDTH  = 160 -- initial button width; deferred resize will widen to fit

-- Strips the "current week" indicator prefix and returns only the date range
-- portion before the first hyphen separator (e.g. "Jan 1" from "Jan 1 - Jan 7").
-- Pure function: no upvalue dependencies, safe to call from any scope.
local function ExtractMonthRangeLabel(label)
    label = tostring(label or "")
    local s = label:gsub("^%s*>%s*", ""):gsub("^%s+", "")
    if s == "" then return label end
    -- Everything before the first hyphen (" - " preferred, else first "-").
    local hyphenA = s:find("%s%-%s") or s:find("%-")
    if not hyphenA then return s end
    local out = s:sub(1, hyphenA - 1):gsub("%s+$", "")
    return out ~= "" and out or s
end

-- Sets the text colour on a picker row button. Defined once at file scope rather
-- than as an anonymous closure per button so no extra allocation happens on reuse.
-- Pure function: no upvalue dependencies.
local function SetPickerButtonTextColor(btn, color)
    local tr = btn.Text or (btn.GetFontString and btn:GetFontString())
    if tr and tr.SetTextColor and color then
        tr:SetTextColor(color.r, color.g, color.b, color.a or 1)
    end
end

-- Rebuilds _sectionsById, _order, and _dataSig when the dataset signature
-- changes. Releases all active section frames so SyncSectionPool starts clean.
-- Returns true if the data changed (callers use this to decide checkbox resync).
local function RebuildDataIndex(data, sig)
    local changed = (Addon._dataSig ~= sig)
                 or (not Addon._sectionsById)
                 or (not next(Addon._sectionsById))
    if not changed then return false end

    Addon._sectionsById = {}
    Addon._order        = {}
    for i = 1, #data do
        local section = data[i]
        Addon._sectionsById[section.id] = section
        Addon._order[i]                 = section.id
    end

    for i = #Addon._activeSections, 1, -1 do
        ReleaseSectionFrame(Addon._activeSections[i])
        Addon._activeSections[i] = nil
    end
    Addon._dataSig = sig

    if frame and frame._lariasHeaderPicker and Addon._PopulateHeaderPicker then
        Addon._PopulateHeaderPicker()
    end
    return true
end

-- Acquires or releases pooled section frames so _activeSections has exactly
-- 'want' entries. 'haveBefore' is the count before this call (used by the
-- caller to decide which frames need a full checkbox resync).
local function SyncSectionPool(want, haveBefore)
    local have = haveBefore
    if have > want then
        for i = have, want + 1, -1 do
            ReleaseSectionFrame(Addon._activeSections[i])
            Addon._activeSections[i] = nil
        end
    elseif have < want then
        for i = have + 1, want do
            Addon._activeSections[i] = AcquireSectionFrame()
        end
    end
end

-- Binds each active section frame to its section ID, syncs checkboxes for
-- new/changed sections, and applies collapsed/complete/hidden visuals.
-- child: the scroll child frame, passed explicitly to avoid an implicit upvalue.
local function ApplySectionVisuals(want, haveBefore, dataChanged, database, child)
    local needCheckboxResync = dataChanged
    for i = 1, want do
        local sectionId    = Addon._order[i]
        local sectionFrame = Addon._activeSections[i]
        sectionFrame:SetParent(child)
        sectionFrame._sectionId             = sectionId
        sectionFrame._index                 = i
        Addon._sectionsIndexById[sectionId] = i

        if needCheckboxResync or i > haveBefore then
            SyncCheckboxesForSection(sectionFrame, sectionId, database)
        end

        sectionFrame._header._sectionFrame = sectionFrame
        sectionFrame._header:SetScript("OnClick", OnHeaderClick)

        UpdateSectionVisuals(sectionFrame, sectionId)
    end
end

local function SyncAllDataAndFrames()
    local database = Addon:EnsureDB()
    local data     = Addon:GetListData()
    if not data then return end  -- data not ready yet (addon still initialising)
    local sig         = CalcDataSig(data)
    local dataChanged = RebuildDataIndex(data, sig)

    Wipe(Addon._sectionsIndexById)
    local want       = #Addon._order
    local haveBefore = #Addon._activeSections

    SyncSectionPool(want, haveBefore)
    ApplySectionVisuals(want, haveBefore, dataChanged, database, scrollChild)
end

function Addon:RequestRefresh()
    -- Queue a refresh to run soon (next tick). Multiple requests coalesce.
    if not frame then return end
    if self._refreshQueued then return end
    self._refreshQueued = true

    if not self._refreshRunner then
        self._refreshRunner = function()
            self._refreshQueued = nil
            if self.Refresh then
                self:Refresh()
            end
        end
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0, self._refreshRunner)
    else
        self._refreshRunner()
    end
end

function Addon:Refresh()
    -- Refresh visible UI: list layout, completion state, and tracking panel.
    if not frame then return end
    if not IsFrameShown(frame) then return end

    if self.ApplyScrollLayout then
        self:ApplyScrollLayout()
    end

    if self.LayoutHeaderButtons then self:LayoutHeaderButtons() end

    SyncAllDataAndFrames()

    -- Re-run after SyncAllDataAndFrames so _sectionsById is fully populated and
    -- the change-week button shows the real current week from the very first load.
    if self.LayoutHeaderButtons then self:LayoutHeaderButtons() end

    local posY = -Addon.UI.sectionTopPad
    local paddingX = Addon.UI.sectionInsetX

    for i = 1, #self._activeSections do
        local sectionFrame = self._activeSections[i]
        if sectionFrame:IsShown() then
            sectionFrame:ClearAllPoints()
            sectionFrame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", paddingX, posY)
            sectionFrame:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -paddingX, posY)
            posY = posY - sectionFrame:GetHeight() - Addon.UI.sectionGap
        end
    end

    scrollChild:SetHeight(max(1, -posY + Addon.UI.sectionGap))

    self:ApplyScrollLayout()

    if self.UpdateCompletionEasterEgg then
        self:UpdateCompletionEasterEgg()
    end

    if self.UpdateTracking then
        self:UpdateTracking()
    end
end

function Addon:CreateFrame()
    -- Lazily build the UI (created on first toggle/open).
    if frame then return end

    frame = CreateFrame("Frame", "LariasWeeklyChecklistFrame", UIParent)
    self._mainFrame = frame

    frame:SetSize(Addon.UI.frameW, Addon.UI.frameH)
    frame:SetClampedToScreen(true)
    -- Position and drag: LibWindow-1.1 saves/restores x/y/point/scale automatically.
    -- RegisterConfig binds a db storage table; MakeDraggable wires OnDragStart/Stop
    -- (which call SavePosition on drop); RestorePosition re-anchors to the saved spot.
    local LW = LibStub("LibWindow-1.1")
    Addon.db.global.mainFrameWin = Addon.db.global.mainFrameWin or {}
    LW.RegisterConfig(frame, Addon.db.global.mainFrameWin)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    LW.MakeDraggable(frame)
    LW.RestorePosition(frame)
    -- Hide the week picker whenever the main frame is hidden (close button,
    -- Toggle(), ESC, or any other dismiss path). The picker is parented to
    -- UIParent so it won't hide automatically when the main frame does.
    frame:SetScript("OnHide", function()
        local picker = frame._lariasHeaderPicker
        if picker and picker.IsShown and picker:IsShown() then
            picker:Hide()
        end
        if Addon._ilvlRefWindow and Addon._ilvlRefWindow.IsShown and Addon._ilvlRefWindow:IsShown() then
            Addon._ilvlRefWindow:Hide()
        end
    end)
    -- Record this character's class the first time the list is opened so the
    -- character picker can colour-code entries. Intentionally deferred from
    -- OnEnable so we never write shared global data before the user opens the
    -- addon for the first time.
    if self.db and self.db.global then
        local _, classToken = UnitClass("player")
        local profileKey    = self:GetCurrentProfileKey()   -- "CharName - Realm"
        if classToken and profileKey and profileKey ~= "" then
            self.db.global.charClasses = self.db.global.charClasses or {}
            self.db.global.charClasses[profileKey] = classToken
        end
        -- Remove stale generic-profile entries (e.g. "Default") that don't match
        -- the "CharName - Realm" format; they cause wrong class colours in the picker.
        local classes = self.db.global.charClasses
        if classes then
            for k in pairs(classes) do
                if not tostring(k):find(" %- ") then
                    classes[k] = nil
                end
            end
        end
    end

    frame:Hide()

    -- Register with UISpecialFrames so ESC closes this frame without needing
    -- the protected SetPropagateKeyboardInput (which triggers ADDON_ACTION_BLOCKED).
    tinsert(UISpecialFrames, "LariasWeeklyChecklistFrame")

    self:ApplyTheme(frame)

    -- Close button: branded ✕ via the shared Controls factory.
    local C = Addon.Controls
    local closeBtn = C.NewCloseButton(frame, function() frame:Hide() end)
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -Addon.UI.closeInset, -Addon.UI.closeInset)

    -- Gear / settings button: branded square matching the close button.
    local gearBtn = C.NewIconButton(frame, "Interface\\Buttons\\UI-OptionsButton", nil, L.TAB_OPTIONS or "Options")
    gearBtn:SetPoint("RIGHT", closeBtn, "LEFT", -2, 0)
    gearBtn:SetScript("OnClick", function()
        if Addon.ToggleGearPopup then Addon:ToggleGearPopup(gearBtn) end
    end)
    frame._lariasGearBtn = gearBtn

    local frameName = frame.GetName and frame:GetName() or nil

    local function StyleMainTabButton(tabButton)
        -- Strip Blizzard textures and apply our theme colors.
        -- Some client builds error if SetNormalTexture(nil) is used, so we hide textures instead.
        if not tabButton then return end

        Addon:ApplyTheme(tabButton)
        -- Tab buttons use a slightly lower bg alpha so section text shows through.
        if tabButton.SetBackdropColor then
            tabButton:SetBackdropColor(Addon.THEME.bg.r, Addon.THEME.bg.g, Addon.THEME.bg.b, max(0, (tonumber(Addon.THEME.bg.a) or 1) - 0.28))
        end

        local function ClearAndHideTexture(texture)
            if not texture then return end
            if texture.SetTexture then texture:SetTexture(nil) end
            if texture.SetAlpha then texture:SetAlpha(0) end
            if texture.Hide then texture:Hide() end
        end

        -- Some client builds error if SetNormalTexture(nil) is used. Hide existing textures instead.
        if tabButton.GetNormalTexture then ClearAndHideTexture(tabButton:GetNormalTexture()) end
        if tabButton.GetPushedTexture then ClearAndHideTexture(tabButton:GetPushedTexture()) end
        if tabButton.GetDisabledTexture then ClearAndHideTexture(tabButton:GetDisabledTexture()) end
        if tabButton.GetHighlightTexture then ClearAndHideTexture(tabButton:GetHighlightTexture()) end

        -- UIPanelButtonTemplate uses these regions for its default art.
        if tabButton.Left and tabButton.Left.Hide then tabButton.Left:Hide() end
        if tabButton.Middle and tabButton.Middle.Hide then tabButton.Middle:Hide() end
        if tabButton.Right and tabButton.Right.Hide then tabButton.Right:Hide() end

        -- Ensure the label sits centered with even vertical padding.
        if tabButton.SetTextInsets then
            tabButton:SetTextInsets(12, 12, 4, 4)
        end

        local textRegion = tabButton.Text or (tabButton.GetFontString and tabButton:GetFontString())
        if textRegion then
            if textRegion.SetJustifyV then textRegion:SetJustifyV("MIDDLE") end
            if textRegion.ClearAllPoints and textRegion.SetPoint then
                textRegion:ClearAllPoints()
                textRegion:SetPoint("CENTER", tabButton, "CENTER", 0, 0)
            end
            if textRegion.SetTextColor then textRegion:SetTextColor(1, 1, 1, 1) end
        end

        if tabButton.CreateTexture and not tabButton._lariasCustomHighlight then
            local highlight = tabButton:CreateTexture(nil, "HIGHLIGHT")
            highlight:SetAllPoints(tabButton)
            highlight:SetColorTexture(Addon.THEME.text.r, Addon.THEME.text.g, Addon.THEME.text.b, 0.06)
            tabButton._lariasCustomHighlight = highlight
        end

        tabButton._lariasTabStyled = true
    end
    Addon._styleActionButton = StyleMainTabButton

    -- Header buttons are created lazily so they use no memory when disabled.
    local changeWeekBtn
    local ilvlRefBtn

    -- Initialise character picker UI (defined in LariasWeeklyChecklist_CharPicker.lua).
    if Addon.InitCharPickerUI then
        Addon:InitCharPickerUI(frame, StyleMainTabButton)
    end

    local function EnsureCharPickerBtn_()
        if Addon._cpEnsureBtn then return Addon._cpEnsureBtn() end
    end

    local function EnsureChangeWeekBtn_()
        if changeWeekBtn then return changeWeekBtn end
        local btn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        btn:SetSize(108, 22)
        StyleMainTabButton(btn)
        changeWeekBtn              = btn
        frame._lariasChangeWeekBtn = btn
        return btn
    end

    local function EnsureIlvlRefBtn_()
        if ilvlRefBtn then return ilvlRefBtn end
        local btn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        btn:SetSize(140, 22)
        StyleMainTabButton(btn)
        btn:SetText(L.ILVLREF_BUTTON or "View Item Levels")
        btn:SetScript("OnClick", function() Addon:ToggleIlvlRefWindow() end)
        ilvlRefBtn              = btn
        frame._lariasIlvlRefBtn = btn
        return btn
    end

    -- Header picker: lets users jump to any week. Selecting a future week auto-checks
    -- all sections before it (they're "done"). Selecting a past week auto-unchecks
    -- sections between the new and old start (so you can redo them).
    -- Implemented WITHOUT a scrollframe — buttons sit directly on the picker frame
    -- so nothing intercepts mouse clicks.
    -- ExtractMonthRangeLabel and SetPickerButtonTextColor are file-level locals
    -- (defined above SyncAllDataAndFrames) because they have no closure dependencies.

    local function EnsureHeaderPicker()
        if frame._lariasHeaderPicker then
            return frame._lariasHeaderPicker
        end

        local picker = Addon.Controls.NewPopupPanel("HIGH", 0.15)
        picker._buttons    = {}
        picker._buttonPool = {}
        frame._lariasHeaderPicker = picker
        return picker
    end

    local function ReleasePickerButtons(picker)
        if not (picker and picker._buttons and picker._buttonPool) then return end
        for i = #picker._buttons, 1, -1 do
            local btn = picker._buttons[i]
            picker._buttons[i] = nil
            if btn then
                btn:Hide()
                btn:ClearAllPoints()
                btn:SetScript("OnClick",  nil)
                btn:SetScript("OnEnter", nil)
                btn:SetScript("OnLeave", nil)
                tinsert(picker._buttonPool, btn)
            end
        end
    end

    local function AcquirePickerButton(picker)
        local btn = tremove(picker._buttonPool)
        if not btn then
            -- Parent directly to picker (no scroll child) so nothing intercepts clicks.
            btn = CreateFrame("Button", nil, picker, "UIPanelButtonTemplate")
            -- HIGH matches the picker strata; set once at creation (not inherited automatically).
            btn:SetFrameStrata("HIGH")
            StyleMainTabButton(btn)
            if btn.SetTextInsets then btn:SetTextInsets(10, 10, 0, 0) end
            local tr = btn.Text or (btn.GetFontString and btn:GetFontString())
            if tr then
                if tr.SetJustifyH then tr:SetJustifyH("LEFT") end
                if tr.SetJustifyV then tr:SetJustifyV("MIDDLE") end
            end
        end
        -- Frame level can shift between reuses (picker level may change), so always refresh it.
        if picker.GetFrameLevel and btn.SetFrameLevel then
            btn:SetFrameLevel((tonumber(picker:GetFrameLevel()) or 200) + 1)
        end
        if btn.Enable       then btn:Enable() end
        if btn.EnableMouse  then btn:EnableMouse(true) end
        btn:Show()

        -- Text colour: white normally, yellow on hover.
        SetPickerButtonTextColor(btn, Addon.THEME.text)
        btn:SetScript("OnEnter", function() SetPickerButtonTextColor(btn, Addon.THEME.header) end)
        btn:SetScript("OnLeave", function() SetPickerButtonTextColor(btn, Addon.THEME.text) end)

        return btn
    end

    -- Applies a week jump: checks+collapses sections going forward, or
    -- unchecks+expands them going backward. Extracted from PopulateHeaderPicker
    -- so it can be read and reasoned about independently.
    -- sf: the main scroll frame, passed explicitly to avoid an implicit upvalue.
    local function HandlePick(sectionId, sf)
        local db       = Addon:EnsureDB()
        local picker   = EnsureHeaderPicker()
        local order    = Addon._order or {}
        local oldStart = tostring(db.startAtSectionId or "")
        local newStart = tostring(sectionId or "")

        local oldIdx, newIdx = 0, 0
        for i = 1, #order do
            if order[i] == oldStart then oldIdx = i end
            if order[i] == newStart then newIdx = i end
        end

        -- An empty startAtSectionId means the user is implicitly on week 1.
        -- Clamp oldIdx to 1 so navigation is consistent with what the ">" marker shows.
        if oldIdx == 0 and #order > 0 then oldIdx = 1 end

        -- Going forward → check + collapse everything before the new start.
        -- Going backward → uncheck + expand everything from new start through
        -- the old start (inclusive, so a completed current week is also cleared).
        if newIdx > oldIdx then
            -- Ensure both tables exist once before the loop, not on every iteration.
            if type(db.checked)          ~= "table" then db.checked          = {} end
            if type(db.collapsedSections) ~= "table" then db.collapsedSections = {} end
            for i = oldIdx, newIdx - 1 do
                local secId  = order[i]
                local secDef = Addon._sectionsById and Addon._sectionsById[secId]
                local items  = secDef and secDef.items or {}
                for _, item in ipairs(items) do
                    db.checked[secId .. ":" .. tostring(item.id)] = true
                end
                db.collapsedSections[secId] = true
            end
        elseif newIdx <= oldIdx then
            -- Hoist existence checks: if either table is absent there is nothing to clear.
            local checked   = type(db.checked)          == "table" and db.checked          or nil
            local collapsed = type(db.collapsedSections) == "table" and db.collapsedSections or nil
            local fromIdx   = (newIdx == 0 and 1 or newIdx)
            for i = fromIdx, oldIdx do
                local secId  = order[i]
                local secDef = Addon._sectionsById and Addon._sectionsById[secId]
                local items  = secDef and secDef.items or {}
                if checked then
                    for _, item in ipairs(items) do
                        checked[secId .. ":" .. tostring(item.id)] = nil
                    end
                end
                if collapsed then collapsed[secId] = nil end
            end
        end

        db.startAtSectionId = newStart

        if picker and picker.Hide then picker:Hide() end
        if sf and sf.SetVerticalScroll then
            sf:SetVerticalScroll(0)
        end
        -- Switch to list tab in case the user was on the Options tab.
        if Addon.SelectMainTab then Addon:SelectMainTab(1) end
        if Addon.RequestRefresh then
            Addon:RequestRefresh()
        elseif Addon.Refresh then
            Addon:Refresh()
        end
    end

    local function PopulateHeaderPicker()
        local picker = EnsureHeaderPicker()
        ReleasePickerButtons(picker)

        local data = Addon.GetListData and Addon:GetListData() or {}
        local posY = -PICKER_PAD

        -- Determine the current week: use the stored start if explicitly set,
        -- otherwise scan for the first incomplete section so that manually
        -- checked sections are reflected without needing an explicit navigation.
        local db0         = Addon:EnsureDB()
        local storedStart = tostring(db0.startAtSectionId or "")
        local currentId
        if storedStart ~= "" then
            currentId = storedStart
        else
            -- Find first section that isn't fully checked yet.
            local order = Addon._order or {}
            for i = 1, #order do
                if not IsSectionCompleteById(order[i], db0) then
                    currentId = tostring(order[i])
                    break
                end
            end
            -- Fallback: everything is done (or no data), point to first section.
            if not currentId and Addon._order and Addon._order[1] then
                currentId = tostring(Addon._order[1])
            end
        end

        if type(data) == "table" then
            for i = 1, #data do
                local section = data[i]
                if type(section) == "table" then
                    local id    = section.id
                    local isCurrent = (tostring(id or "") == currentId)
                    local label = ExtractMonthRangeLabel(section.title or id or "")
                    if label == "" then label = tostring(id or i) end
                    if isCurrent then label = "> " .. label end

                    local btn = AcquirePickerButton(picker)
                    btn:ClearAllPoints()
                    btn:SetPoint("TOPLEFT", picker, "TOPLEFT", PICKER_PAD, posY)
                    btn:SetHeight(PICKER_ROW_HEIGHT)
                    btn:SetText(label)
                    btn:SetEnabled(true)
                    local capturedId = id
                    btn:SetScript("OnClick", function() HandlePick(capturedId, scrollFrame) end)

                    -- Dim the current-week button slightly so it reads as an indicator.
                    if isCurrent then
                        SetPickerButtonTextColor(btn, Addon.THEME.textDim or Addon.THEME.text)
                        btn:SetScript("OnEnter", function() SetPickerButtonTextColor(btn, Addon.THEME.header) end)
                        btn:SetScript("OnLeave", function() SetPickerButtonTextColor(btn, Addon.THEME.textDim or Addon.THEME.text) end)
                    end

                    tinsert(picker._buttons, btn)
                    posY = posY - PICKER_ROW_HEIGHT
                end
            end
        end

        local totalH = -posY + PICKER_PAD
        picker:SetHeight(max(40, totalH))

        -- WoW does not compute FontString widths until the frame has been laid out
        -- on-screen for at least one frame tick; calling GetStringWidth immediately
        -- after Show() returns 0. Deferring via C_Timer.After(0, ...) lets the
        -- engine perform its layout pass first so we get real pixel widths.
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                if not (picker and picker.IsShown and picker:IsShown()) then return end
                local bestW = 120
                for _, b in ipairs(picker._buttons) do
                    local tr = b.Text or (b.GetFontString and b:GetFontString())
                    local w
                    if tr then
                        if tr.GetUnboundedStringWidth then
                            w = tonumber(tr:GetUnboundedStringWidth())
                        elseif tr.GetStringWidth then
                            w = tonumber(tr:GetStringWidth())
                        end
                    end
                    if (not w or w <= 0) and b.GetTextWidth then
                        w = tonumber(b:GetTextWidth())
                    end
                    if w and w > bestW then bestW = w end
                end

                local newW = max(160, min(520, math.ceil(bestW + PICKER_PAD * 4 + 24)))
                picker:SetWidth(newW)
                for _, b in ipairs(picker._buttons) do
                    if b.SetWidth then b:SetWidth(newW - PICKER_PAD * 2) end
                end
            end)
        end

        -- Apply initial button widths too (before deferred resize).
        for _, b in ipairs(picker._buttons) do
            if b.SetWidth then b:SetWidth(PICKER_ROW_WIDTH) end
        end
    end

    -- Allow refresh routines to repopulate the headers panel when list data changes.
    Addon._PopulateHeaderPicker = PopulateHeaderPicker

    -- LayoutHeaderButtons_: creates buttons on demand (zero memory if option
    -- is disabled at load time) and positions them relative to closeBtn.
    -- Exposed as Addon:LayoutHeaderButtons() for the Options tab callbacks.
    local function LayoutHeaderButtons_()
        if Addon._inLayoutHeaderButtons then return end
        Addon._inLayoutHeaderButtons = true
        local dbLocal = Addon:EnsureDB()
        local showCW  = dbLocal.showChangeWeekBtn  ~= false
        local showIR  = dbLocal.showIlvlRefBtn     ~= false
        local showCP  = dbLocal.showCharPickerBtn  ~= false
                    and (Addon.FEATURE_FLAGS and Addon.FEATURE_FLAGS.ENABLE_CHAR_SELECTOR) ~= false

        -- Also hide the char picker when there is nothing to pick from: no other
        -- characters in the dropdown and we are not currently viewing one.
        if showCP then
            if Addon.HasPickableChars then
                showCP = Addon:HasPickableChars()
            end
        end

        -- charPickerBtn sits in the TOP row (above changeWeekBtn).  Position it first
        -- so changeWeekBtn and ilvlRefBtn can anchor to it.
        local cpBtn = EnsureCharPickerBtn_()
        if cpBtn then
            if showCP then
                cpBtn:SetScript("OnClick", function()
                    if Addon._cpOnClick then Addon._cpOnClick() end
                end)
                cpBtn:ClearAllPoints()
                -- Sit at the bottom-right of the frame, vertically aligned with the
                -- scale slider on the opposite (left) side.
                cpBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT",
                    -(Addon.UI.sectionInsetX or 14), Addon.UI.sliderBottomPad or 4)
                if Addon._cpUpdateLabel then Addon._cpUpdateLabel() end
                cpBtn:Show()
            else
                -- Return to own character before hiding the picker.
                -- Inline reset instead of SetViewingChar() to avoid re-entering
                -- LayoutHeaderButtons (SetViewingChar now calls LayoutHeaderButtons).
                if Addon._viewingChar then
                    Addon._viewingChar = nil
                    if Addon._cpUpdateLabel then Addon._cpUpdateLabel() end
                    if Addon.RequestRefresh then Addon:RequestRefresh() else Addon:Refresh() end
                end
                cpBtn:Hide()
            end
        end

        -- changeWeekBtn sits below cpBtn when both are visible, otherwise in the top row.
        if showCW then
            local btn = EnsureChangeWeekBtn_()
            -- Show the current week's short label (e.g. "Mar 17") so the button
            -- acts as a status indicator. The action name goes in the tooltip.
            local cwWeekLabel
            do
                local db0 = Addon:EnsureDB()
                local storedStart = tostring(db0.startAtSectionId or "")
                local currentId
                if storedStart ~= "" then
                    currentId = storedStart
                else
                    local order = Addon._order or {}
                    for i = 1, #order do
                        if not IsSectionCompleteById(order[i], db0) then
                            currentId = tostring(order[i])
                            break
                        end
                    end
                    if not currentId and Addon._order and Addon._order[1] then
                        currentId = tostring(Addon._order[1])
                    end
                end
                local section  = currentId and Addon._sectionsById and Addon._sectionsById[currentId]
                local extracted = ExtractMonthRangeLabel((section and section.title) or currentId or "")
                cwWeekLabel = (extracted ~= "") and extracted or (L.CHANGE_WEEK_BUTTON or "Change Week")
            end
            btn:SetText(cwWeekLabel .. " |TInterface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up:10:10|t")
            local cwTip = L.CHANGE_WEEK_BUTTON or "Change Week"
            btn:SetScript("OnEnter", function(self_)
                GameTooltip:SetOwner(self_, "ANCHOR_BOTTOMLEFT")
                GameTooltip:SetText(cwTip, 1, 1, 1, 1, true)
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
            -- Auto-size button width to fit the label text.
            -- Deferred one frame so WoW has performed its layout pass
            -- and GetStringWidth returns real pixel widths.
            if C_Timer and C_Timer.After then
                C_Timer.After(0, function()
                    if not (btn and btn.IsShown and btn:IsShown()) then return end
                    local fs = btn.GetFontString and btn:GetFontString()
                    local w  = 0
                    if fs then
                        if fs.GetUnboundedStringWidth then
                            w = tonumber(fs:GetUnboundedStringWidth()) or 0
                        end
                        if w <= 0 and fs.GetStringWidth then
                            w = tonumber(fs:GetStringWidth()) or 0
                        end
                    end
                    if w <= 0 and btn.GetTextWidth then
                        w = tonumber(btn:GetTextWidth()) or 0
                    end
                    btn:SetWidth(max(108, math.ceil(w) + 24))
                end)
            end
            btn:SetScript("OnClick", function()
                local p = EnsureHeaderPicker()
                if p and p.IsShown and p:IsShown() then
                    p:Hide()
                    return
                end
                p:ClearAllPoints()
                p:SetPoint("TOPLEFT", changeWeekBtn, "BOTTOMLEFT", 0, -6)
                p:Show()
                if C_Timer and C_Timer.After then
                    C_Timer.After(0, PopulateHeaderPicker)
                else
                    PopulateHeaderPicker()
                end
            end)
            btn:ClearAllPoints()
            -- Pin to top-left of the frame, where the tab row used to live.
            local cwInsetX = (Addon.UI.padOuterX or 14) + (Addon.UI.sectionInsetX or 14)
            btn:SetPoint("TOPLEFT", frame, "TOPLEFT", cwInsetX, -(Addon.UI.padOuterTop or 10) - 2)
            btn:Show()
        elseif changeWeekBtn then
            changeWeekBtn:Hide()
        end

        -- ilvlRefBtn anchors left of gearBtn always (cpBtn is now at the bottom, not the header).
        if showIR then
            local btn = EnsureIlvlRefBtn_()
            btn:ClearAllPoints()
            btn:SetPoint("TOPRIGHT", gearBtn, "TOPLEFT", -4, 0)
            btn:Show()
        elseif ilvlRefBtn then
            ilvlRefBtn:Hide()
            if Addon._ilvlRefWindow and Addon._ilvlRefWindow.IsShown and Addon._ilvlRefWindow:IsShown() then
                Addon._ilvlRefWindow:Hide()
            end
        end

        -- Minimum width: left side has inset + changeWeekBtn; right side has close + gear + cpBtn + ilvlRef.
        local _insetX = (Addon.UI.padOuterX or 14) + (Addon.UI.sectionInsetX or 14)
        local _leftW  = _insetX + (showCW and (108 + 6) or 0)
        local _rightW = (Addon.UI.closeInset or 4) + 32 + 2 + 20  -- close + gear
        if showIR then _rightW = _rightW + 4 + 140 end
        local _minW = _leftW + 20 + _rightW  -- 20px breathing room between sides
        -- Never go below the 80/120% design bounds, regardless of button layout.
        local _absMinW = math.floor(Addon.UI.frameW * 0.8)
        local _absMinH = math.floor(Addon.UI.frameH * 0.8)
        local _maxW2   = math.floor(Addon.UI.frameW * 1.0)
        local _maxH2   = math.floor(Addon.UI.frameH * 1.0)
        _minW = math.max(_minW, _absMinW)
        -- Snap existing width up if it's already narrower than the new minimum.
        local currentW = frame:GetWidth()
        if currentW < _minW then
            frame:SetWidth(_minW)
            local _gdb = Addon.db and Addon.db.global
            if _gdb and _gdb.mainFrameSize then
                _gdb.mainFrameSize.w = _minW
            end
        end
        Addon._inLayoutHeaderButtons = nil
    end  -- LayoutHeaderButtons_

    Addon.LayoutHeaderButtons = function(self) LayoutHeaderButtons_() end
    LayoutHeaderButtons_()

    scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", Addon.UI.padOuterX, -Addon.UI.scrollTop)

    do
        local pig = scrollFrame:CreateTexture(nil, "ARTWORK")
        pig:SetPoint("CENTER", scrollFrame, "CENTER", 0, 0)
        pig:SetTexture("Interface\\Icons\\INV_Pig")
        if pig.SetTexCoord then
            pig:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end
        pig:SetAlpha(0.95)
        pig:Hide()
        frame._lariasPigTexture = pig
    end

    scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(1, 1)
    scrollFrame:SetScrollChild(scrollChild)

    local db = self:EnsureDB()
    if (db.showGreatVault or db.showCurrency) and self.CreateTrackingPanel and not self._trackingFrame then
        self:CreateTrackingPanel(frame)
    end

    if self.UpdateLocalizedUI then
        self:UpdateLocalizedUI()
    end

    -- Restore persisted scale immediately so the frame never shows at 100%
    -- on first open after a reload before the slider is touched.
    if self.ApplyUIScale then self:ApplyUIScale() end

    if scrollFrame then scrollFrame:Show() end
end

function Addon:Toggle()
    -- Main entry point for showing/hiding the addon window.
    self:CreateFrame()
    if frame:IsShown() then
        frame:Hide()
    else
        self._updatePopupShownThisOpen = nil
        self:BroadcastVersion(false)
        self:RequestVersions(false)
        if self.SelectMainTab then
            self:SelectMainTab(1)
        end
        if self.RequestRefresh then
            self:RequestRefresh()
        else
            self:Refresh()
        end
        self:ShowUpdatePopupIfNeeded()
        frame:Show()
    end
end

-- Register slash commands.
-- NOTE: We intentionally register /lcl as a second alias of the *same* command
-- name to avoid collisions with other addons that may use a generic "LCL"
-- SlashCmdList entry.
function Addon:RegisterConsoleCommands()
    if type(SlashCmdList) ~= "table" then
        return
    end

    SLASH_LARIASWEEKLYCHECKLIST1 = "/larias"
    SLASH_LARIASWEEKLYCHECKLIST2 = "/lcl"

    local addon = self
    SlashCmdList["LARIASWEEKLYCHECKLIST"] = function(input)
        addon:ToggleCommand(input)
    end
end

function Addon:ToggleCommand(input)
    -- Slash command parser.
    input = tostring(input or "")
    input = input:gsub("^%s+", ""):gsub("%s+$", "")

    if input == "" then
        self:Toggle()
        return
    end

    local cmd, arg = input:match("^(%S+)%s*(.-)%s*$")
    cmd = tostring(cmd or ""):lower()
    arg = tostring(arg or ""):gsub("^%s+", ""):gsub("%s+$", "")

    if cmd == "debug" then
        local db = self:EnsureDB()
        local v = arg:lower()
        if v == "on" or v == "1" or v == "true" then
            db.debug = true
        elseif v == "off" or v == "0" or v == "false" then
            db.debug = false
        end
        self:Print(("Debug: %s"):format(db.debug and "ON" or "OFF"))
        return
    end

    if cmd == "locale" or cmd == "lang" then
        if not self.SetLocaleOverride then
            self:Print("Locale override is not available in this build.")
            return
        end

        -- Locale overrides are intended to work with the optional localization companion addon.
        -- If it's not installed, the command would appear to do nothing, so explain why.
        if self.IsLocalizationCompanionLoaded and self.HasNonEnUSLocaleTables
            and (not self:IsLocalizationCompanionLoaded())
            and (not self:HasNonEnUSLocaleTables()) then
            self:Print("Locale overrides require the optional companion addon 'LariasWeeklyChecklist_Localization' to be installed.")
            return
        end

        if arg:lower() == "status" or arg == "?" then
            local client = (GetLocale and GetLocale()) or ""
            local reg = GetLocaleRegistry()
            local strings = reg and reg.strings
            local data = reg and reg.data
            local function HasTable(t, key)
                return type(t) == "table" and type(t[key]) == "table"
            end
            local override = tostring(self._sessionLocaleOverride or "auto")
            local effective = (self.GetEffectiveLocaleCode and self:GetEffectiveLocaleCode()) or ""

            self:Print(("Locale status: client=%s override=%s effective=%s"):format(tostring(client), tostring(override), tostring(effective)))
            self:Print(("Locale status: strings.esMX=%s data.esMX=%s strings.enUS=%s data.enUS=%s"):format(
                tostring(HasTable(strings, "esMX")),
                tostring(HasTable(data, "esMX")),
                tostring(HasTable(strings, "enUS")),
                tostring(HasTable(data, "enUS"))
            ))
            return
        end

        if arg == "" then
            self:Print(L.SLASH_USAGE_LOCALE or "Usage: /larias locale auto|enUS|esMX")
            return
        end

        -- Keep it simple: accept common casing, normalize.
        local value = arg
        if value:lower() == "auto" then value = "auto" end
        if value:lower() == "enus" then value = "enUS" end
        if value:lower() == "esmx" then value = "esMX" end

        self:SetLocaleOverride(value)
        local effective = (self.GetEffectiveLocaleCode and self:GetEffectiveLocaleCode()) or ""
        self:Print((L.SLASH_LOCALE_SET_FMT or "Locale override set to %s (effective: %s)"):format(tostring(value), tostring(effective)))
        return
    end

    -- Unknown args: show help.
    self:Print(L.SLASH_USAGE_TOGGLE or "Usage: /larias or /lcl to toggle the checklist")
    self:Print(L.SLASH_USAGE_LOCALE or "Usage: /larias locale auto|enUS|esMX")
end
