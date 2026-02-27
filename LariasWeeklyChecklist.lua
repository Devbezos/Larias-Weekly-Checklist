-- Main addon entry point.
-- Responsibilities:
-- - Initialize locale registry + apply locale overlay.
-- - Load tracking/constants.
-- - Build and refresh the checklist UI (list + options + tracking panel).
--
-- Design goal: keep runtime behavior event-driven and avoid per-frame work.
local addonName = ...

-- On dev/pre-release builds (version contains "-", e.g. "2.1.0-alpha", "2.0.6-1"),
-- automatically enable all locales for this session so every translation can be
-- tested without changing the WoW client language.
do
    local ver = (GetAddOnMetadata and GetAddOnMetadata(addonName, "Version")) or ""
    if ver:find("%-") then
        _G["LARIASWEEKLYCHECKLIST_LOAD_ALL_LOCALES"] = true
    end
end

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
            frameH = 737,
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
            sliderLabelH = 14,
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
    showOpacitySlider     = true,
    hideUpdateNotice      = false,
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
            uiOpacityPct  = 65,
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
        icon = "Interface\\AddOns\\LariasWeeklyChecklist\\assets\\icon",
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
    -- in the Interface -> AddOns list even before the window is opened.
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

    -- Register the Interface → AddOns settings panel.
    if self.RegisterSettingsPanel then
        self:RegisterSettingsPanel()
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
-- PruneObsoleteSavedState → features/body/LariasWeeklyChecklist_ListData.lua

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
function Addon:OpenOptions()
    if self.CreateBlizzOptionsPanel then
        self:CreateBlizzOptionsPanel()
    end
    if self._blizzOptCategory and Settings and Settings.OpenToCategory then
        local catId = self._blizzOptCategory.GetID and self._blizzOptCategory:GetID() or self._blizzOptCategory
        Settings.OpenToCategory(catId)
    end
end

-- Forces the main list panel to re-render; kept for call-site compatibility.
function Addon:SelectMainTab()
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

-- GetListData → features/body/LariasWeeklyChecklist_ListData.lua

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

    -- Update tracking panel title FontStrings directly when the panel already exists.
    local trackingFrame = self._trackingFrame
    if trackingFrame then
        if trackingFrame._lariasLeftTitle and trackingFrame._lariasLeftTitle.SetText then
            trackingFrame._lariasLeftTitle:SetText(L.TRACKING_GREAT_VAULT_TITLE or "Great Vault")
        end
        if trackingFrame._lariasRightTitle and trackingFrame._lariasRightTitle.SetText then
            trackingFrame._lariasRightTitle:SetText(L.TRACKING_CURRENCY_TITLE or "Currency")
        end
        -- Update the three GV section row headers (Raid / Dungeons / World).
        local gvKeysByIndex = { "TRACKING_GV_RAID", "TRACKING_GV_DUNGEONS", "TRACKING_GV_WORLD" }
        local gvFallbacks   = { "Raid", "Dungeons", "World" }
        local grids = trackingFrame._lariasGvGrids
        if type(grids) == "table" then
            for bi = 1, 3 do
                local grid = grids[bi]
                if grid and grid.header and grid.header.SetText then
                    grid.header:SetText(L[gvKeysByIndex[bi]] or gvFallbacks[bi])
                end
            end
        end
    end
    -- Always request a tracking re-render so currency row labels (quest Done/Not
    -- done, trade-up suffix, crest fallback names, etc.) pick up the new strings
    -- from L.  RequestTrackingUpdate is safe to call even when the panel hasn't
    -- been lazily created yet -- UpdateTracking handles that case internally.
    if self.RequestTrackingUpdate then self:RequestTrackingUpdate() end

    -- Refresh scale/opacity slider labels.
    local sf = self._inFrameScaleSlider
    if sf then
        if sf._scaleTitleLbl and sf._scaleTitleLbl.SetText then
            sf._scaleTitleLbl:SetText(L.UI_SCALE_LABEL or "Scale")
        end
        if sf._opacTitleLbl and sf._opacTitleLbl.SetText then
            sf._opacTitleLbl:SetText(L.UI_OPACITY_LABEL or "Opacity")
        end
    end

    -- Refresh the status banner text (locale strings may have changed).
    if self.UpdateStatusBanner then self:UpdateStatusBanner() end
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
        local sliderRowH   = (Addon.UI.sliderH or 0) + (Addon.UI.sliderLabelH or 0) + 2
        local sliderH      = sliderShown and sliderRowH                     or 0
        -- Banner row always occupies space (frame is permanently visible).
        local bannerExtra  = self._statusBanner
            and ((self._statusBannerH or 14) + (self._statusBannerPad or 3))
            or 0
        -- Banner always occupies space; include its height even when sliders are hidden.
        local sliderBotPad = (sliderShown and (Addon.UI.sliderBottomPad or 0) or 0) + bannerExtra
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
        -- Apply directly to all live text labels immediately -- SyncCheckboxesForSection
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

-- Shared helper: pin the frame's TOPLEFT to the same screen pixel after a
-- scale change.  Before scaling we capture the TOPLEFT in screen-space pixels
-- (frame-local coords * current scale).  After SetScale we re-anchor TOPLEFT
-- so that same pixel stays fixed -- the window expands down and to the right
-- only, with zero drift.  Returns true if it was able to re-anchor.
local function PinTopLeftScale(f, newScale)
    if not (f and f.SetScale) then return false end
    local oldScale   = f:GetScale() or 1
    local screenLeft = f:GetLeft()
    local screenTop  = f:GetTop()
    if not (screenLeft and screenTop) then
        f:SetScale(newScale)
        return false
    end
    -- Convert to UIParent-relative screen pixels.
    screenLeft = screenLeft * oldScale
    screenTop  = screenTop  * oldScale
    f:SetScale(newScale)
    f:ClearAllPoints()
    -- TOPLEFT offset from UIParent BOTTOMLEFT (WoW's default anchor origin).
    f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT",
        screenLeft / newScale,
        screenTop  / newScale)
    return true
end

-- Live-preview variant: pin TOPLEFT, no LibWindow save.
-- Called on every drag tick so there is no positional bounce.
function Addon:ApplyUIScaleLive()
    local scale = self:GetUIScale()
    PinTopLeftScale(self._mainFrame, scale)
    local iw = self._ilvlRefWindow
    if iw and iw.SetScale then iw:SetScale(scale) end
end

function Addon:ApplyUIScale()
    local scale = self:GetUIScale()
    if frame then
        local reanchored = PinTopLeftScale(frame, scale)
        if not reanchored then
            -- Fallback: delegate to LibWindow if PinTopLeftScale couldn't read coords.
            local LW = LibStub("LibWindow-1.1", true)
            if LW then LW.SetScale(frame, scale) else frame:SetScale(scale) end
        end
        -- Persist position so LibWindow restores correctly on next login.
        local LW = LibStub("LibWindow-1.1", true)
        if LW then LW.SavePosition(frame) end
    end
    -- The ilvl ref window is parented to UIParent; scale it independently.
    local iw = self._ilvlRefWindow
    if iw and iw.SetScale then iw:SetScale(scale) end
    if iw and iw._ilvlReflow then iw._ilvlReflow() end
    -- Do NOT call ApplyScrollLayout here.  SetScale only changes the visual
    -- size of the root frame; the logical frame dimensions are unchanged, so
    -- there is nothing to reflow.  ClearAllPoints+SetPoint inside
    -- ApplyScrollLayout causes the scroll frame to collapse for one frame
    -- (the snap/bounce the user sees), even when the values are identical.
    -- Keep in-frame slider in sync with whatever changed the value.
    local sf = self._inFrameScaleSlider
    if sf and sf.Sync then sf.Sync() end
end

-- Footer methods are defined in features/footer/LariasWeeklyChecklist_Footer.lua.
-- (CreateStatusBanner, UpdateStatusBanner, ApplyScaleSliderVisibility, ApplyOpacity)


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
-- Expose for use by the Header module (PopulateHeaderPicker, LayoutHeaderButtons_).
Addon._IsSectionCompleteById = IsSectionCompleteById

local function HasAnySectionItemChecked(sectionId, db)
    -- Returns true if at least one item in the section has been checked.
    local section = Addon._sectionsById[sectionId]
    if not section then return false end
    db = db or Addon:EnsureDB()
    local checked = db.checked
    local items = section.items or {}
    local prefix = tostring(sectionId) .. ":"
    for i = 1, #items do
        if checked[prefix .. tostring(items[i].id)] then
            return true
        end
    end
    return false
end
-- Expose for the Header module so the picker can track the last actively-worked week.
Addon._HasAnySectionItemChecked = HasAnySectionItemChecked

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
    title:SetPoint("LEFT", header, "LEFT", 3, 0)
    title:SetTextColor(Addon.THEME.header.r, Addon.THEME.header.g, Addon.THEME.header.b, Addon.THEME.header.a)
    title:SetJustifyH("LEFT")
    if title.SetWordWrap then title:SetWordWrap(true) end
    sectionFrame._title = title

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
    -- Hoist sectionGap: avoids two table lookups (Addon -> UI -> sectionGap) per visible section.
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
    -- The week-picker dropdown already shows the part before the first " - "
    -- (e.g. "Week 3"), so strip that prefix from the list header to avoid
    -- repeating it.  Falls back to the full title if there's no " - " at all.
    titleText = titleText:match("^.-%s%-%s(.+)$") or titleText
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

    -- Refresh the picker ">" marker whenever a section completes.
    -- We no longer auto-advance startAtSectionId here: the picker fallback
    -- already tracks the most-recently-active week via HasAnySectionItemChecked,
    -- so advancing on completion would jump to the following week too soon.
    if secCompleteNow then
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

-- Picker constants, ExtractMonthRangeLabel, and SetPickerButtonTextColor were moved
-- to features/header/LariasWeeklyChecklist_Header.lua.

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

    -- Size the change-week button to fit the widest week label in the dataset.
    if self._calcChangeWeekBtnWidth then self._calcChangeWeekBtnWidth() end

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

    -- Sync the change-week button label to whatever section is at the top of
    -- the viewport after the list has been (re)built and laid out.
    if self._refreshChangeWeekLabel and C_Timer and C_Timer.After then
        C_Timer.After(0, self._refreshChangeWeekLabel)
    elseif self._refreshChangeWeekLabel then
        self._refreshChangeWeekLabel()
    end
end

function Addon:CreateFrame()
    -- Lazily build the UI (created on first toggle/open).
    if frame then return end

    frame = CreateFrame("Frame", "LariasWeeklyChecklistFrame", UIParent)
    self._mainFrame = frame

    frame:SetSize(Addon.UI.frameW, Addon.UI.frameH)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("MEDIUM")
    frame:SetFrameLevel(100)
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
        -- Close all floating panels attached to the addon.
        local picker = frame._lariasHeaderPicker
        if picker and picker.IsShown and picker:IsShown() then
            picker:Hide()
        end
        if Addon._ilvlRefWindow and Addon._ilvlRefWindow.IsShown and Addon._ilvlRefWindow:IsShown() then
            Addon._ilvlRefWindow:Hide()
        end
        if Addon._gearPopup and Addon._gearPopup.IsShown and Addon._gearPopup:IsShown() then
            Addon._gearPopup:Hide()
        end
        if Addon._hiddenCharsPicker and Addon._hiddenCharsPicker.IsShown and Addon._hiddenCharsPicker:IsShown() then
            Addon._hiddenCharsPicker:Hide()
        end
        if Addon._cpClose then Addon._cpClose() end
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
    -- Replace the backdrop fill with a dedicated texture so opacity changes only
    -- affect the background, not child widgets. The backdrop edge/border is kept.
    do
        -- Use BORDER layer (above BACKGROUND) so external UI elements don't bleed
        -- between the bg texture and the frame content when dragging.
        local bg = frame:CreateTexture(nil, "BORDER", nil, -8)
        bg:SetAllPoints(frame)
        bg:SetColorTexture(Addon.THEME.bg.r, Addon.THEME.bg.g, Addon.THEME.bg.b, 1)
        frame._lariaBgTex = bg
        -- Suppress the backdrop bgFile fill; use our texture instead.
        if frame.SetBackdropColor then
            frame:SetBackdropColor(0, 0, 0, 0)
        end
    end
    -- Header: close/gear/change-week/ilvl-ref/char-picker buttons + week-picker popup.
    -- Defined in features/header/LariasWeeklyChecklist_Header.lua.
    self:CreateHeader(frame)

    scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", Addon.UI.padOuterX, -Addon.UI.scrollTop)

    do
        -- Easter egg: "touch grass" trio -- hand + plus + grass icons.
        local egg = CreateFrame("Frame", nil, scrollFrame)
        egg:SetPoint("CENTER", scrollFrame, "CENTER", 0, 0)
        egg:SetSize(1, 1)
        egg:Hide()

        local handTex = egg:CreateTexture(nil, "ARTWORK")
        handTex:SetTexture("Interface\\Icons\\Spell_Holy_LayOnHands")
        if handTex.SetTexCoord then handTex:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
        handTex:SetAlpha(0.95)

        local plusFS = egg:CreateFontString(nil, "OVERLAY")
        plusFS:SetFont("Fonts\\FRIZQT__.TTF", 32, "OUTLINE")
        plusFS:SetText("+")
        plusFS:SetTextColor(1, 1, 1, 0.95)
        plusFS:SetJustifyH("CENTER")
        plusFS:SetJustifyV("MIDDLE")

        local grassTex = egg:CreateTexture(nil, "ARTWORK")
        grassTex:SetTexture("Interface\\Icons\\Ability_Druid_Flourish")
        if grassTex.SetTexCoord then grassTex:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
        grassTex:SetAlpha(0.95)

        -- Override SetSize so the three elements reflow whenever the caller
        -- resizes the container (icons scale with available scroll area).
        local _rawSetSize = egg.SetSize
        function egg:SetSize(w, h)
            local iconSize = math.max(32, math.min(160, math.floor(h * 0.43)))
            local gap      = math.max(4,  math.floor(iconSize * 0.10))
            local plusW    = math.max(16, math.floor(iconSize * 0.45))
            local totalW   = iconSize + gap + plusW + gap + iconSize
            _rawSetSize(self, totalW, iconSize)

            handTex:SetSize(iconSize, iconSize)
            handTex:ClearAllPoints()
            handTex:SetPoint("LEFT", self, "LEFT", 0, 0)

            plusFS:SetSize(plusW, iconSize)
            plusFS:ClearAllPoints()
            plusFS:SetPoint("LEFT", handTex, "RIGHT", gap, 0)
            plusFS:SetFont("Fonts\\FRIZQT__.TTF",
                math.max(14, math.floor(iconSize * 0.55)), "OUTLINE")

            grassTex:SetSize(iconSize, iconSize)
            grassTex:ClearAllPoints()
            grassTex:SetPoint("LEFT", plusFS, "RIGHT", gap, 0)
        end

        frame._lariasPigTexture = egg
    end

    scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(1, 1)
    scrollFrame:SetScrollChild(scrollChild)

    -- Expose scroll frame for the header module's deferred closures.
    Addon._scrollFrame = scrollFrame
    -- Wire scroll-event hooks that were defined by CreateHeader.
    if Addon._wireScrollHeaderHooks then
        Addon._wireScrollHeaderHooks(scrollFrame)
    end


    local db = self:EnsureDB()
    if (db.showGreatVault or db.showCurrency) and self.CreateTrackingPanel and not self._trackingFrame then
        self:CreateTrackingPanel(frame)
    end

    if self.UpdateLocalizedUI then
        self:UpdateLocalizedUI()
    end

    -- Restore persisted scale immediately so the frame never shows at 100%
    -- on first open after a reload before the slider is touched.
    if self.ApplyUIScale  then self:ApplyUIScale()  end
    if self.ApplyOpacity  then self:ApplyOpacity()  end

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
            -- List available locales dynamically from the registry.
            local reg2     = GetLocaleRegistry()
            local strings2 = reg2 and reg2.strings or {}
            local data2    = reg2 and reg2.data    or {}
            local seen2, list2 = {}, {}
            for k in pairs(strings2) do if not seen2[k] then seen2[k]=true; tinsert(list2,k) end end
            for k in pairs(data2)   do if not seen2[k] then seen2[k]=true; tinsert(list2,k) end end
            table.sort(list2)
            local available = (#list2 > 0) and table.concat(list2, "|") or "enUS"
            self:Print("Available locales: auto|" .. available)
            return
        end

        -- Normalize casing: do a case-insensitive match against all registered locales
        -- plus the special "auto" token.
        local raw   = arg
        local lower = raw:lower()
        local value

        if lower == "auto" then
            value = "auto"
        else
            -- Scan registry for a case-insensitive match.
            local reg2    = GetLocaleRegistry()
            local strings2 = reg2 and reg2.strings or {}
            local data2    = reg2 and reg2.data    or {}
            for k in pairs(strings2) do
                if k:lower() == lower then value = k; break end
            end
            if not value then
                for k in pairs(data2) do
                    if k:lower() == lower then value = k; break end
                end
            end
        end

        if not value then
            -- Build a sorted list of available locale codes from the registry.
            local reg2    = GetLocaleRegistry()
            local strings2 = reg2 and reg2.strings or {}
            local data2    = reg2 and reg2.data    or {}
            local seen2, list2 = {}, {}
            for k in pairs(strings2) do if not seen2[k] then seen2[k]=true; tinsert(list2,k) end end
            for k in pairs(data2)   do if not seen2[k] then seen2[k]=true; tinsert(list2,k) end end
            table.sort(list2)
            local available = (#list2 > 0) and table.concat(list2, "|")
                              or "enUS"
            self:Print((L.SLASH_LOCALE_NOT_FOUND
                or "Unknown locale '%s'. Available: auto|%s"):format(tostring(raw), available))
            return
        end

        self:SetLocaleOverride(value)
        local effective = (self.GetEffectiveLocaleCode and self:GetEffectiveLocaleCode()) or ""
        self:Print((L.SLASH_LOCALE_SET_FMT or "Locale override set to %s (effective: %s)"):format(tostring(value), tostring(effective)))
        return
    end

    -- Unknown args: show help.
    self:Print(L.SLASH_USAGE_TOGGLE or "Usage: /larias or /lcl to toggle the checklist")
    self:Print(L.SLASH_USAGE_LOCALE or "Usage: /larias locale auto|enUS|esMX")
end
