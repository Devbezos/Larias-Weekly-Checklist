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
        if names.dbName == nil then names.dbName = "LariasWeeklyChecklistDBPC" end
        if names.accountDbName == nil then names.accountDbName = "LariasWeeklyChecklistDB" end

        self.DISPLAY_NAME = self.DISPLAY_NAME or names.displayName
        self._DB_NAME = self._DB_NAME or names.dbName
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
            itemTextWidth = 420,
            sectionInsetX = 14,
            trackH = 210,
            trackTopPad = 10,
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
        else
            -- If the constants file is missing or failed to load, we don't silently invent IDs.
            -- Leave defaults as-is and print a single warning.
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

-- Debug is an opt-in flag stored in SavedVariables.
function Addon:IsDebugEnabled()
    return self.db and self.db.profile and self.db.profile.debug and true or false
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
Addon._sessionLocaleOverride = Addon._sessionLocaleOverride

-- Set up database with AceDB
local function SetupAddonDB()
    if Addon.db then return end
    
    local defaults = {
        profile = {
            hideCompletedSections = true,
            showGreatVault = true,
            showCurrency = true,
            debug = false,
            -- When set, only show sections at/after this sectionId in the list.
            -- Nil/empty means show all sections.
            startAtSectionId = "",
            collapsedSections = {},
            checked = {},
        },
        global = {
            _newestSeenRemoteVersion = "",
            _newestSeenRemoteSender = "",
            _dismissedRemoteVersion = "",
        },
    }
    
    Addon.db = LibStub("AceDB-3.0"):New(addonName .. "DB", defaults, true)
end

-- Set up LibDataBroker and LibDBIcon for minimap icon
local function SetupMinimapIcon()
    local LDB = LibStub("LibDataBroker-1.1")
    local icon = LibStub("LibDBIcon-1.0")
    
    local dataObject = LDB:NewDataObject(addonName, {
        type = "data source",
        text = addonName,
        icon = 135943, -- Gilded Crest icon
        OnClick = function(_, button)
            if button == "LeftButton" then
                -- If the addon is already open on the Options tab, left-click should
                -- take you back to the List tab (and keep the window open).
                if Addon.CreateFrame then
                    Addon:CreateFrame()
                end
                local mainFrame = _G["LariasWeeklyChecklistFrame"]
                if IsFrameShown(mainFrame) and tonumber(mainFrame._lariasSelectedTab) == 2 then
                    if Addon.SelectMainTab then
                        Addon:SelectMainTab(1)
                    end
                    return
                end

                Addon:Toggle()
            elseif button == "RightButton" then
                Addon:OpenOptions()
            end
        end,
        OnTooltipShow = function(tooltip)
            if not tooltip then return end
            tooltip:AddLine(L.DISPLAY_NAME or addonName, 1, 0.82, 0)
            tooltip:AddLine(L.MINIMAP_TOOLTIP_LEFT_CLICK_TOGGLE or "", 1, 1, 1)
            tooltip:AddLine(L.MINIMAP_TOOLTIP_RIGHT_CLICK_OPTIONS or "", 1, 1, 1)

            if Addon.ShouldShowLocalizationCompanionHint and Addon:ShouldShowLocalizationCompanionHint() then
                tooltip:AddLine(" ")
                tooltip:AddLine(Addon.LOCALIZATION_COMPANION_HINT_TEXT, 0.9, 0.9, 0.9)
            end
        end,
    })
    
    icon:Register(addonName, dataObject, (Addon.db and Addon.db.profile and Addon.db.profile.minimap) or {})
end

-- Enable minimap icon by default
local function EnsureMinimapIcon()
    if not Addon.db or not Addon.db.profile then return end
    if Addon.db.profile.minimap == nil then
        Addon.db.profile.minimap = { hide = false }
    end
end

-- Initialize AceDB and minimap icon on addon load
function Addon:OnInitialize()
    SetupAddonDB()
    if self.ApplyLocaleOverride then
        self:ApplyLocaleOverride()
    end
    EnsureMinimapIcon()
    SetupMinimapIcon()
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

    if self.PruneObsoleteSavedState then
        self:PruneObsoleteSavedState()
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

function Addon:EnsureDB()
    if not self.db then
        SetupAddonDB()
    end
    return self.db.profile
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

-- Show the main window and switch to Options tab.
function Addon:OpenOptions()
    self:CreateFrame()

    if IsFrameShown(frame) and tonumber(frame._lariasSelectedTab) == 2 then
        frame:Hide()
        return
    end

    if frame and not IsFrameShown(frame) then
        self._updatePopupShownThisOpen = nil
        self:BroadcastVersion(false)
        self:RequestVersions(false)
        self:ShowUpdatePopupIfNeeded()
        frame:Show()
    end

    if self.SelectMainTab then
        self:SelectMainTab(2)
    end
end

-- Tab switching for the main window.
-- tabId: 1 = list, 2 = options.
function Addon:SelectMainTab(tabId)
    self:CreateFrame()
    if not frame then return end

    tabId = tonumber(tabId) or 1
    if tabId ~= 2 then tabId = 1 end
    frame._lariasSelectedTab = tabId

    local listTab = frame._lariasTabList
    local optionsTab = frame._lariasTabOptions

    local function SetTabSelected(tabButton, selected)
        if not tabButton then return end
        if tabButton.SetEnabled then
            tabButton:SetEnabled(not selected)
        elseif selected and tabButton.Disable then
            tabButton:Disable()
        elseif tabButton.Enable then
            tabButton:Enable()
        end

        if tabButton._lariasTabStyled and tabButton.SetBackdropColor and tabButton.SetBackdropBorderColor then
            local bg = Addon.THEME.bg
            local baseAlpha = tonumber(bg.a) or 1
            local alpha
            if selected then
                alpha = min(1, baseAlpha + 0.18)
            else
                alpha = max(0, baseAlpha - 0.28)
            end
            tabButton:SetBackdropColor(bg.r, bg.g, bg.b, alpha)

            local borderColor = selected and Addon.THEME.header or Addon.THEME.border
            tabButton:SetBackdropBorderColor(borderColor.r, borderColor.g, borderColor.b, borderColor.a)
        end

        local textRegion = tabButton.Text or (tabButton.GetFontString and tabButton:GetFontString())
        if textRegion and textRegion.SetTextColor then
            if selected then
                textRegion:SetTextColor(Addon.THEME.header.r, Addon.THEME.header.g, Addon.THEME.header.b, Addon.THEME.header.a)
            else
                textRegion:SetTextColor(Addon.THEME.textDim.r, Addon.THEME.textDim.g, Addon.THEME.textDim.b, Addon.THEME.textDim.a)
            end
        end
    end

    SetTabSelected(listTab, tabId == 1)
    SetTabSelected(optionsTab, tabId == 2)

    local showList = (tabId == 1)
    if scrollFrame and scrollFrame.SetShown then
        scrollFrame:SetShown(showList)
    end

    local changeWeekBtn = frame._lariasChangeWeekBtn
    if changeWeekBtn and changeWeekBtn.SetShown then
        changeWeekBtn:SetShown(showList)
    end

    local picker = frame._lariasHeaderPicker
    if (not showList) and picker and picker.Hide then
        picker:Hide()
    end

    local optionsPanel = frame._lariasOptionsPanel
    if optionsPanel and optionsPanel.SetShown then
        optionsPanel:SetShown(not showList)
    end

    if not showList and self.SyncOptionsTabControls then
        self:SyncOptionsTabControls()
    end

    -- Force tracking panel to respect the selected tab (List only).
    if self.ApplyTrackingPanelOptions then
        self:ApplyTrackingPanelOptions()
    elseif self.UpdateTracking then
        self:UpdateTracking()
    end

    if showList then
        if self.RequestRefresh then
            self:RequestRefresh()
        elseif self.Refresh then
            self:Refresh()
        end
    else
        if self.ApplyScrollLayout then
            self:ApplyScrollLayout()
        end
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

    local optionsTab = frame._lariasTabOptions
    if optionsTab and optionsTab.SetText then
        optionsTab:SetText(L.TAB_OPTIONS or "Options")
    end

    local listTab = frame._lariasTabList
    if listTab and listTab.SetText then
        listTab:SetText(L.TAB_LIST or "List")
    end

    local changeWeekBtn = frame._lariasChangeWeekBtn
    if changeWeekBtn and changeWeekBtn.SetText then
        changeWeekBtn:SetText(L.CHANGE_WEEK_BUTTON or "Change Week")
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
function Addon:ApplyTheme(frameObj)
    if not frameObj or not frameObj.SetBackdrop then return end
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
        extra = trackingHeight + Addon.UI.trackTopPad
    end

    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -Addon.UI.scrollRight, Addon.UI.scrollBottom + extra)
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
    for i = 1, #items do
        if not checked[Key(sectionId, items[i].id)] then
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
    title:SetPoint("LEFT", header, "LEFT", 0, 0)
    title:SetTextColor(Addon.THEME.header.r, Addon.THEME.header.g, Addon.THEME.header.b, Addon.THEME.header.a)
    title:SetJustifyH("LEFT")
    if title.SetWordWrap then title:SetWordWrap(true) end
    sectionFrame._title = title

    local status = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    status:SetPoint("RIGHT", header, "RIGHT", 0, 0)
    status:SetTextColor(Addon.THEME.textDim.r, Addon.THEME.textDim.g, Addon.THEME.textDim.b, Addon.THEME.textDim.a)
    sectionFrame._status = status

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
    -- Acquire (or create) a checkbox row for an item.
    local checkbox = tremove(Addon._checkboxPool)
    if checkbox then
        checkbox:SetParent(parentSectionFrame)
        checkbox:Show()
    else
        checkbox = CreateFrame("CheckButton", nil, parentSectionFrame, "UICheckButtonTemplate")
    end

    do
        local boxSize = 32
        local function PinTexture(tex)
            if not tex then return end
            tex:ClearAllPoints()
            tex:SetSize(boxSize, boxSize)
            tex:SetPoint("LEFT", checkbox, "LEFT", 0, 0)
        end

        PinTexture(checkbox.GetNormalTexture and checkbox:GetNormalTexture())
        PinTexture(checkbox.GetPushedTexture and checkbox:GetPushedTexture())
        PinTexture(checkbox.GetHighlightTexture and checkbox:GetHighlightTexture())
        PinTexture(checkbox.GetCheckedTexture and checkbox:GetCheckedTexture())
        PinTexture(checkbox.GetDisabledTexture and checkbox:GetDisabledTexture())
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

    for i = 1, #Addon._activeSections do
        local sectionFrame = Addon._activeSections[i]
        if sectionFrame:IsShown() then
            if i < startIndex then
                posY = posY - sectionFrame:GetHeight() - Addon.UI.sectionGap
            else
                sectionFrame:ClearAllPoints()
                sectionFrame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", paddingX, posY)
                sectionFrame:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -paddingX, posY)
                posY = posY - sectionFrame:GetHeight() - Addon.UI.sectionGap
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
    sectionFrame._status:SetText("")
end

local function OnCheckboxClick(selfBtn)
    -- Item click handler: update saved state, collapse/hide completed sections, relayout.
    local database = Addon:EnsureDB()
    local checked = selfBtn:GetChecked() and true or nil
    database.checked[selfBtn._dbKey or Key(selfBtn._sectionId, selfBtn._itemId)] = checked

    local sectionId = selfBtn._sectionId
    local secCompleteNow = IsSectionCompleteById(sectionId, database)
    if secCompleteNow then
        SetSectionCollapsed(sectionId, true, database)
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

    for i = 1, want do
        local item = items[i]
        local checkbox = sectionFrame._checkboxes[i]

        checkbox._sectionId = sectionId
        checkbox._itemId = item.id
        checkbox._dbKey = Key(sectionId, item.id)

        local textLabel = checkbox.text or checkbox.Text
        local minRowHeight = max(32, Addon.UI.itemMinH or 0)
        if textLabel then
            textLabel:SetWidth(Addon.UI.itemTextWidth)
            textLabel:SetText(tostring(item.text or item.id))

            local textHeight = 0
            if textLabel.GetStringHeight then
                textHeight = textLabel:GetStringHeight() or 0
            end
            checkbox:SetHeight(max(minRowHeight, textHeight + (Addon.UI.itemTextPad or 0)))
        else
            checkbox:SetHeight(minRowHeight)
        end

        checkbox:SetChecked(IsItemChecked(sectionId, item.id, db))

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

    for i = 1, #sectionFrame._checkboxes do
        local checkbox = sectionFrame._checkboxes[i]
        if checkbox and checkbox._itemId ~= nil then
            checkbox:SetChecked(IsItemChecked(sectionId, checkbox._itemId, database))
        end
    end

    LayoutItems(sectionFrame, collapsed)
    UpdateSectionHeight(sectionFrame, collapsed)
end

local function SyncAllDataAndFrames()
    -- Core refresh routine:
    -- - Detect dataset changes (by signature)
    -- - Rebuild index tables if needed
    -- - Reuse pooled frames/checkboxes
    -- - Apply per-section visuals (collapsed/complete/hidden)
    local database = Addon:EnsureDB()

    local data = Addon:GetListData()
    local sig = CalcDataSig(data)

    local dataChanged = (Addon._dataSig ~= sig) or (not Addon._sectionsById) or (not next(Addon._sectionsById))
    if dataChanged then
        Addon._sectionsById = {}
        Addon._order = {}
        for i = 1, #data do
            local section = data[i]
            Addon._sectionsById[section.id] = section
            Addon._order[i] = section.id
        end

        for i = #Addon._activeSections, 1, -1 do
            ReleaseSectionFrame(Addon._activeSections[i])
            Addon._activeSections[i] = nil
        end
        Addon._dataSig = sig

        if frame and frame._lariasHeaderPicker and Addon._PopulateHeaderPicker then
            Addon._PopulateHeaderPicker()
        end
    end

    Wipe(Addon._sectionsIndexById)

    local want = #Addon._order
    local haveBefore = #Addon._activeSections
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

    local needCheckboxResync = dataChanged

    for i = 1, want do
        local sectionId = Addon._order[i]
        local sectionFrame = Addon._activeSections[i]
        sectionFrame:SetParent(scrollChild)
        sectionFrame._sectionId = sectionId
        sectionFrame._index = i
        Addon._sectionsIndexById[sectionId] = i

        if needCheckboxResync or i > haveBefore then
            SyncCheckboxesForSection(sectionFrame, sectionId, database)
        end

        sectionFrame._header._sectionFrame = sectionFrame
        sectionFrame._header:SetScript("OnClick", OnHeaderClick)

        UpdateSectionVisuals(sectionFrame, sectionId)

    end
end

function Addon:RequestRefresh()
    -- Queue a refresh to run soon (next tick). Multiple requests coalesce.
    if not frame then return end
    if self._refreshQueued then return end
    self._refreshQueued = true

    local function Run()
        self._refreshQueued = nil
        if self.Refresh then
            self:Refresh()
        end
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0, Run)
    else
        Run()
    end
end

function Addon:Refresh()
    -- Refresh visible UI: list layout, completion state, and tracking panel.
    if not frame then return end
    if not IsFrameShown(frame) then return end

    if self.ApplyScrollLayout then
        self:ApplyScrollLayout()
    end

    if tonumber(frame._lariasSelectedTab) ~= 1 then
        return
    end

    SyncAllDataAndFrames()

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
    if not frame.SetBackdrop and BackdropTemplateMixin and Mixin then
        Mixin(frame, BackdropTemplateMixin)
    end

    frame:SetSize(Addon.UI.frameW, Addon.UI.frameH)
    frame:SetClampedToScreen(true)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    if UISpecialFrames and frame.GetName then
        local frameNameForSpecialFrames = frame:GetName()
        if frameNameForSpecialFrames and frameNameForSpecialFrames ~= "" then
            local exists = false
            for i = 1, #UISpecialFrames do
                if UISpecialFrames[i] == frameNameForSpecialFrames then
                    exists = true
                    break
                end
            end
            if not exists then
                tinsert(UISpecialFrames, frameNameForSpecialFrames)
            end
        end
    end

    self:ApplyTheme(frame)

    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -Addon.UI.closeInset, -Addon.UI.closeInset)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    local frameName = frame.GetName and frame:GetName() or nil
    local tab1Name = frameName and (frameName .. "Tab1") or nil
    local tab2Name = frameName and (frameName .. "Tab2") or nil

    local function StyleMainTabButton(tabButton)
        -- Strip Blizzard textures and apply our theme colors.
        -- Some client builds error if SetNormalTexture(nil) is used, so we hide textures instead.
        if not tabButton then return end

        if not tabButton.SetBackdrop and BackdropTemplateMixin and Mixin then
            Mixin(tabButton, BackdropTemplateMixin)
        end

        if tabButton.SetBackdrop then
            tabButton:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                tile = false,
                edgeSize = 1,
                insets = { left = 3, right = 3, top = 3, bottom = 3 },
            })
            tabButton:SetBackdropBorderColor(Addon.THEME.border.r, Addon.THEME.border.g, Addon.THEME.border.b, Addon.THEME.border.a)
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
        end

        if tabButton.CreateTexture and not tabButton._lariasCustomHighlight then
            local highlight = tabButton:CreateTexture(nil, "HIGHLIGHT")
            highlight:SetAllPoints(tabButton)
            highlight:SetColorTexture(Addon.THEME.text.r, Addon.THEME.text.g, Addon.THEME.text.b, 0.06)
            tabButton._lariasCustomHighlight = highlight
        end

        tabButton._lariasTabStyled = true
    end

    local listTab = CreateFrame("Button", tab1Name, frame, "UIPanelButtonTemplate")
    listTab:SetID(1)
    listTab:SetText(L.TAB_LIST or "")
    listTab:SetSize(120, 28)
    listTab:ClearAllPoints()
    -- Tabs should sit *inside* the window.
    local tabInsetX = (Addon.UI.padOuterX or 0) + (Addon.UI.sectionInsetX or 0)
    listTab:SetPoint("TOPLEFT", frame, "TOPLEFT", tabInsetX, -Addon.UI.padOuterTop)
    StyleMainTabButton(listTab)
    listTab:SetScript("OnClick", function(selfBtn)
        Addon:SelectMainTab(selfBtn:GetID())
    end)

    local optionsTab = CreateFrame("Button", tab2Name, frame, "UIPanelButtonTemplate")
    optionsTab:SetID(2)
    optionsTab:SetText(L.TAB_OPTIONS or "")
    optionsTab:SetSize(120, 28)
    optionsTab:ClearAllPoints()
    optionsTab:SetPoint("LEFT", listTab, "RIGHT", 6, 0)
    StyleMainTabButton(optionsTab)
    optionsTab:SetScript("OnClick", function(selfBtn)
        Addon:SelectMainTab(selfBtn:GetID())
    end)

    frame._lariasTabList = listTab
    frame._lariasTabOptions = optionsTab

    local changeWeekBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    changeWeekBtn:SetSize(108, 22)
    changeWeekBtn:SetPoint("TOPRIGHT", closeBtn, "TOPLEFT", -6, -2)
    StyleMainTabButton(changeWeekBtn)
    changeWeekBtn:SetText(L.CHANGE_WEEK_BUTTON or "Change Week")
    frame._lariasChangeWeekBtn = changeWeekBtn

    -- Header picker: lets users jump to any week. Selecting a future week auto-checks
    -- all sections before it (they're "done"). Selecting a past week auto-unchecks
    -- sections between the new and old start (so you can redo them).
    -- Implemented WITHOUT a scrollframe — buttons sit directly on the picker frame
    -- so nothing intercepts mouse clicks.

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

    local function EnsureHeaderPicker()
        if frame._lariasHeaderPicker then
            return frame._lariasHeaderPicker
        end

        local picker
        if BackdropTemplateMixin then
            picker = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        else
            picker = CreateFrame("Frame", nil, UIParent)
        end
        if not picker.SetBackdrop and BackdropTemplateMixin and Mixin then
            Mixin(picker, BackdropTemplateMixin)
        end

        picker:SetFrameStrata("TOOLTIP")
        picker:SetClampedToScreen(true)
        picker:SetSize(200, 40)
        picker:Hide()
        if picker.SetToplevel then picker:SetToplevel(true) end
        -- Assign a very high frame level so it renders above the main window.
        if picker.SetFrameLevel then picker:SetFrameLevel(200) end

        Addon:ApplyTheme(picker)
        if picker.SetBackdropColor then
            picker:SetBackdropColor(Addon.THEME.bg.r, Addon.THEME.bg.g, Addon.THEME.bg.b, 1.0)
        end

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
                btn:SetScript("OnClick",    nil)
                btn:SetScript("OnMouseUp",  nil)
                btn:SetScript("OnEnter",    nil)
                btn:SetScript("OnLeave",    nil)
                tinsert(picker._buttonPool, btn)
            end
        end
    end

    local function AcquirePickerButton(picker)
        local btn = tremove(picker._buttonPool)
        if not btn then
            -- Parent directly to picker (no scroll child) so nothing intercepts clicks.
            btn = CreateFrame("Button", nil, picker, "UIPanelButtonTemplate")
            StyleMainTabButton(btn)
            if btn.SetTextInsets then btn:SetTextInsets(10, 10, 0, 0) end
            local tr = btn.Text or (btn.GetFontString and btn:GetFontString())
            if tr then
                if tr.SetJustifyH then tr:SetJustifyH("LEFT") end
                if tr.SetJustifyV then tr:SetJustifyV("MIDDLE") end
            end
        end
        btn:SetParent(picker)
        btn:SetFrameStrata("TOOLTIP")
        if picker.GetFrameLevel and btn.SetFrameLevel then
            btn:SetFrameLevel((tonumber(picker:GetFrameLevel()) or 200) + 1)
        end
        if btn.Enable       then btn:Enable() end
        if btn.EnableMouse  then btn:EnableMouse(true) end
        btn:Show()

        -- Text colour: white normally, yellow on hover.
        local function SetTextColor(color)
            local tr = btn.Text or (btn.GetFontString and btn:GetFontString())
            if tr and tr.SetTextColor and color then
                tr:SetTextColor(color.r, color.g, color.b, color.a or 1)
            end
        end
        SetTextColor(Addon.THEME.text)
        btn:SetScript("OnEnter", function() SetTextColor(Addon.THEME.header) end)
        btn:SetScript("OnLeave", function() SetTextColor(Addon.THEME.text) end)

        return btn
    end

    local function PopulateHeaderPicker()
        local picker = EnsureHeaderPicker()
        ReleasePickerButtons(picker)

        local db   = Addon:EnsureDB()
        local data = Addon.GetListData and Addon:GetListData() or {}

        local PAD  = 8
        local rowH = 24
        local posY = -PAD

        local function HandlePick(sectionId)
            -- Work out old and new positions in the section order.
            local order = Addon._order or {}
            local oldStart = tostring(db.startAtSectionId or "")
            local newStart = tostring(sectionId or "")

            local oldIdx, newIdx = 0, 0
            for i = 1, #order do
                if order[i] == oldStart then oldIdx = i end
                if order[i] == newStart then newIdx = i end
            end

            -- Going forward → check + collapse everything before the new start.
            -- Going backward → uncheck + expand everything from new start up to old start.
            if newIdx > oldIdx then
                for i = (oldIdx == 0 and 1 or oldIdx), newIdx - 1 do
                    local secId  = order[i]
                    local secDef = Addon._sectionsById and Addon._sectionsById[secId]
                    local items  = secDef and secDef.items or {}
                    if type(db.checked) ~= "table" then db.checked = {} end
                    for _, item in ipairs(items) do
                        db.checked[secId .. ":" .. tostring(item.id)] = true
                    end
                    -- Also mark collapsed so it renders correctly without a full refresh pass.
                    if type(db.collapsedSections) ~= "table" then db.collapsedSections = {} end
                    db.collapsedSections[secId] = true
                end
            elseif newIdx < oldIdx then
                -- Uncheck + expand every section from new start through the old start (inclusive),
                -- so a completed current week is also cleared when jumping backwards.
                local fromIdx = (newIdx == 0 and 1 or newIdx)
                for i = fromIdx, oldIdx do
                    local secId  = order[i]
                    local secDef = Addon._sectionsById and Addon._sectionsById[secId]
                    local items  = secDef and secDef.items or {}
                    -- Clear checked state.
                    if type(db.checked) == "table" then
                        for _, item in ipairs(items) do
                            db.checked[secId .. ":" .. tostring(item.id)] = nil
                        end
                    end
                    -- Clear collapsed state so the section expands and items are visible.
                    if type(db.collapsedSections) == "table" then
                        db.collapsedSections[secId] = nil
                    end
                end
            end

            db.startAtSectionId = newStart

            if picker and picker.Hide then picker:Hide() end
            if scrollFrame and scrollFrame.SetVerticalScroll then
                scrollFrame:SetVerticalScroll(0)
            end
            if Addon.RequestRefresh then
                Addon:RequestRefresh()
            elseif Addon.Refresh then
                Addon:Refresh()
            end
        end

        local rowW = 160  -- initial; will be widened to fit content below

        if type(data) == "table" then
            for i = 1, #data do
                local section = data[i]
                if type(section) == "table" then
                    local id    = section.id
                    local label = ExtractMonthRangeLabel(section.title or id or "")
                    if label == "" then label = tostring(id or i) end

                    local btn = AcquirePickerButton(picker)
                    btn:ClearAllPoints()
                    btn:SetPoint("TOPLEFT", picker, "TOPLEFT", PAD, posY)
                    btn:SetHeight(rowH)
                    btn:SetText(label)

                    local capturedId = id
                    btn:SetScript("OnClick", function() HandlePick(capturedId) end)

                    tinsert(picker._buttons, btn)
                    posY = posY - rowH
                end
            end
        end

        local totalH = -posY + PAD
        picker:SetHeight(max(40, totalH))

        -- Size width to longest label, deferred one frame so GetStringWidth is valid.
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

                local newW = max(160, min(520, math.ceil(bestW + PAD * 4 + 24)))
                picker:SetWidth(newW)
                for _, b in ipairs(picker._buttons) do
                    if b.SetWidth then b:SetWidth(newW - PAD * 2) end
                end
            end)
        end

        -- Apply initial button widths too (before deferred resize).
        for _, b in ipairs(picker._buttons) do
            if b.SetWidth then b:SetWidth(rowW) end
        end
    end

    -- Allow refresh routines to repopulate the headers panel when list data changes.
    Addon._PopulateHeaderPicker = PopulateHeaderPicker

    changeWeekBtn:SetScript("OnClick", function()
        local picker = EnsureHeaderPicker()
        if picker and picker.IsShown and picker:IsShown() then
            picker:Hide()
            return
        end
        picker:ClearAllPoints()
        picker:SetPoint("TOPRIGHT", changeWeekBtn, "BOTTOMRIGHT", 0, -6)
        picker:Show()

        -- Populate after show so widths are correct and buttons are fully clickable.
        if C_Timer and C_Timer.After then
            C_Timer.After(0, PopulateHeaderPicker)
        else
            PopulateHeaderPicker()
        end
    end)

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

    local optionsPanel = CreateFrame("Frame", nil, frame)
    optionsPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", Addon.UI.padOuterX, -Addon.UI.scrollTop)
    optionsPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -Addon.UI.padOuterX, Addon.UI.scrollBottom)
    optionsPanel:Hide()
    frame._lariasOptionsPanel = optionsPanel

    if self.InitOptionsTab then
        self:InitOptionsTab(frame, optionsPanel)
    end

    local db = self:EnsureDB()
    if (db.showGreatVault or db.showCurrency) and self.CreateTrackingPanel and not self._trackingFrame then
        self:CreateTrackingPanel(frame)
    end

    if self.UpdateLocalizedUI then
        self:UpdateLocalizedUI()
    end

    self:SelectMainTab(1)
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
