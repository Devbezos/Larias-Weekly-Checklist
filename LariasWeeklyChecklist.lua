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
Addon.LOCALE_REGISTRY_KEY = LOCALE_REGISTRY_KEY

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
Addon.GetLocaleRegistry = GetLocaleRegistry

-- Safe frame visibility check (works across different object shapes).
-- NOTE: AddonUtils defines an identical helper, but AddonUtils loads *after* this
-- file in the TOC, so this local copy is required for code that runs during file load.
local function IsFrameShown(frameObj)
    return frameObj and frameObj.IsShown and frameObj:IsShown()
end

Addon.L = Addon.L or {}
local L = Addon.L
Addon.PLACEHOLDER_DASH = Addon.PLACEHOLDER_DASH or "\226\128\148"

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
            check   = { r = 0.19, g = 0.83, b = 0.19, a = 1.00 },  -- checkmark tick
        }
        self.THEME = self.THEME or self.CONSTANTS.theme
        -- Ensure check color exists for sessions that loaded before it was added.
        if not self.THEME.check then
            self.THEME.check = { r = 0.19, g = 0.83, b = 0.19, a = 1.00 }
        end

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

Addon.VISUAL_STYLE = Addon.VISUAL_STYLE or {
    panelBorderA     = 0.62,
    popupBorderA     = 0.56,
    buttonBgA        = 0.30,
    buttonBorderA    = 0.48,
    buttonHighlightA = 0.05,
    iconButtonBgA    = 0.72,
    dividerA         = 0.24,
    strongDividerA   = 0.40,
    sectionBandA     = 0.10,
    sectionAccentA   = 0.32,
    trackingBorderA  = 0.38,
    trackingInnerA   = 0.18,
}

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

-- Addon._sessionLocaleOverride is set by SetLocaleOverride.

-- Database setup, EnsureDB/EnsurePrefs, and hidden-row APIs live in
-- features/services/general/LariasWeeklyChecklist_Database.lua.

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
                -- Dismiss any visible tooltip so it doesn't overlap the popup.
                if GameTooltip then GameTooltip:Hide() end
                -- Open the gear popup anchored to the minimap button.
                if Addon.ToggleGearPopup then
                    Addon:ToggleGearPopup(self_)
                end
            elseif button == "MiddleButton" then
                if IsShiftKeyDown() then
                    if Addon.ToggleIlvlRefWindow then Addon:ToggleIlvlRefWindow() end
                else
                    if Addon.ToggleAltsSummary then Addon:ToggleAltsSummary() end
                end
            end
        end,
        OnTooltipShow = function(tooltip)
            if not tooltip then return end
            tooltip:AddLine(L.DISPLAY_NAME or addonName, 1, 0.82, 0)
            tooltip:AddLine(L.MINIMAP_TOOLTIP_LEFT_CLICK_TOGGLE or "Left-click: Show Checklist", 1, 1, 1)
            tooltip:AddLine(L.MINIMAP_TOOLTIP_RIGHT_CLICK_OPTIONS or "Right-click: Show Options", 1, 1, 1)
            tooltip:AddLine(L.MINIMAP_TOOLTIP_MIDDLE_CLICK_ILVL or "Middle-click: Show Alt Summary",  1, 1, 1)
            tooltip:AddLine(L.MINIMAP_TOOLTIP_SHIFT_MIDDLE       or "Shift+Middle: Show Item Level Ref", 1, 1, 1)

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

-- Addon Compartment callbacks (registered via TOC AddonCompartmentFunc metadata).
-- Mirrors the minimap OnClick / OnTooltipShow behaviour so all three mouse
-- buttons work from the compartment the same way they do on the minimap icon.
local _compartmentFrame  -- cached from OnEnter so the click handler can anchor to it
-- Debounce table: defensive guard in case a future client version restores
-- dual down+up firing.  Process only the first event within 300 ms per button.
local _compartmentLastClick = {}
function LariasWeeklyChecklist_CompartmentClick(_, button, down)  -- luacheck: ignore 212
    local now = GetTime()
    if (now - (_compartmentLastClick[button] or 0)) < 0.30 then return end
    _compartmentLastClick[button] = now
    if button == "LeftButton" then
        if Addon.CreateFrame then Addon:CreateFrame() end
        Addon:Toggle()
    elseif button == "RightButton" then
        if GameTooltip then GameTooltip:Hide() end
        if Addon.ToggleGearPopup then
            -- Anchor to the persistent AddonCompartmentFrame minimap button rather
            -- than _compartmentFrame (the menu-item button), which is pooled and
            -- moves when the dropdown closes, dragging the popup with it via the
            -- live SetPoint anchor relationship.
            Addon:ToggleGearPopup(AddonCompartmentFrame or _compartmentFrame)
        end
    elseif button == "MiddleButton" then
        if IsShiftKeyDown() then
            if Addon.ToggleIlvlRefWindow then Addon:ToggleIlvlRefWindow() end
        else
            if Addon.ToggleAltsSummary then Addon:ToggleAltsSummary() end
        end
    end
end

function LariasWeeklyChecklist_CompartmentOnEnter(_, frame)
    _compartmentFrame = frame
    local L = Addon.L or {}
    GameTooltip:SetOwner(frame, "ANCHOR_TOP")
    GameTooltip:AddLine(L.DISPLAY_NAME or addonName, 1, 0.82, 0)
    GameTooltip:AddLine(L.MINIMAP_TOOLTIP_LEFT_CLICK_TOGGLE  or "Left-click: Show Checklist",   1, 1, 1)
    GameTooltip:AddLine(L.MINIMAP_TOOLTIP_RIGHT_CLICK_OPTIONS or "Right-click: Show Options",     1, 1, 1)
    GameTooltip:AddLine(L.MINIMAP_TOOLTIP_MIDDLE_CLICK_ILVL or "Middle-click: Show Alt Summary",       1, 1, 1)
    GameTooltip:AddLine(L.MINIMAP_TOOLTIP_SHIFT_MIDDLE       or "Shift+Middle: Show Item Level Ref",    1, 1, 1)
    GameTooltip:Show()
end

function LariasWeeklyChecklist_CompartmentOnLeave()
    GameTooltip:Hide()
end

-- ── Shared theme-color definitions ───────────────────────────────────────────
-- Single source of truth for background / text / header color entries.
-- Used by both GearPopup (compact swatches) and Settings (full-size swatches).
-- Each entry exposes :get() → r,g,b; :save(r,g,b); :reset() so callers
-- don't need to duplicate db-access logic.
Addon.THEME_COLOR_DEFS = {
    { labelKey = "COLOR_PICKER_BG",   label = "Background", rk = "bgR",     gk = "bgG",     bk = "bgB",     dr = 0.10, dg = 0.10, db = 0.10 },
    { labelKey = "COLOR_PICKER_TEXT", label = "Text",       rk = "textR",   gk = "textG",   bk = "textB",   dr = 1.00, dg = 1.00, db = 1.00 },
    { labelKey = "COLOR_PICKER_HDR",  label = "Header",     rk = "headerR", gk = "headerG", bk = "headerB", dr = 1.00, dg = 0.82, db = 0.00 },
}
for _, d in ipairs(Addon.THEME_COLOR_DEFS) do
    function d:get()
        local tc = (Addon.db and Addon.db.global and Addon.db.global.themeColors) or {}
        local r = (tc[self.rk] ~= nil) and tc[self.rk] or self.dr
        local g = (tc[self.gk] ~= nil) and tc[self.gk] or self.dg
        local b = (tc[self.bk] ~= nil) and tc[self.bk] or self.db
        return r, g, b
    end
    function d:save(r, g, b)
        local gdb = Addon.db and Addon.db.global
        if not gdb then return end
        gdb.themeColors = gdb.themeColors or {}
        gdb.themeColors[self.rk] = r; gdb.themeColors[self.gk] = g; gdb.themeColors[self.bk] = b
        if Addon.ApplyThemeColors then Addon:ApplyThemeColors() end
    end
    function d:reset()
        local gdb = Addon.db and Addon.db.global
        if gdb and gdb.themeColors then
            gdb.themeColors[self.rk] = nil; gdb.themeColors[self.gk] = nil; gdb.themeColors[self.bk] = nil
        end
        if Addon.ApplyThemeColors then Addon:ApplyThemeColors() end
    end
end

-- ── Shared support links ──────────────────────────────────────────────────────
-- Returns the three support resource entries as a table-of-tables so callers
-- can iterate without duplicating URL resolution.  Resolved lazily at call
-- time so changes to TRACKING.supportLinks (set during OnInitialize) are
-- reflected correctly.
function Addon:GetSupportLinks()
    local sl = self.TRACKING and self.TRACKING.supportLinks or {}
    local _L = self.L or {}
    return {
        { label = _L.SUPPORT_BTN_GUIDE_DOC or "Guide Doc",  url = sl.doc       or "" },
        { label = _L.SUPPORT_BTN_CHECKLIST  or "Checklist",  url = sl.checklist or "" },
        { label = _L.SUPPORT_BTN_DISCORD    or "Discord",    url = sl.discord   or "" },
    }
end

-- ── Context menu ────────────────────────────────────────────────────────────
-- Lightweight right-click context menu.  items = {{text=string, onClick=fn}, ...}
-- Re-uses a single singleton popup panel so only one menu is open at a time.
local _rcCtxPanel
local _rcCtxBtns = {}
function Addon:ShowContextMenu(anchor, items)
    if not (items and #items > 0) then return end
    if not _rcCtxPanel then
        _rcCtxPanel = Addon.Controls.NewPopupPanel("DIALOG", 0.10)
        _rcCtxPanel:SetWidth(180)
    end
    for _, b in ipairs(_rcCtxBtns) do b:Hide() end
    _rcCtxBtns = {}
    local ROW_H = 22
    local PAD   = 6
    local y     = -PAD
    for _, item in ipairs(items) do
        local btn = CreateFrame("Button", nil, _rcCtxPanel, "UIPanelButtonTemplate")
        btn:SetPoint("TOPLEFT",  _rcCtxPanel, "TOPLEFT",  PAD,  y)
        btn:SetPoint("TOPRIGHT", _rcCtxPanel, "TOPRIGHT", -PAD, y)
        btn:SetHeight(ROW_H)
        btn:SetText(item.text or "")
        if Addon.Controls and Addon.Controls.StyleButton then
            Addon.Controls.StyleButton(btn)
        end
        local _cb = item.onClick
        btn:SetScript("OnClick", function()
            _rcCtxPanel:Hide()
            if _cb then _cb() end
        end)
        btn:Show()
        y = y - ROW_H - 2
        tinsert(_rcCtxBtns, btn)
    end
    _rcCtxPanel:SetHeight(-y + PAD)
    _rcCtxPanel:ClearAllPoints()
    _rcCtxPanel:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
    _rcCtxPanel:Show()
end

-- ── Full addon reset ──────────────────────────────────────────────────────────
-- Resets the current character's list data (checked items, collapsed sections,
-- week pointer) AND all UI display settings (position, scale, opacity, theme
-- colors) back to their defaults.  Also clears every character's cached tracking
-- snapshot so stale gear/currency data is re-captured on next login.
-- Called by both the GearPopup and Settings panel reset buttons.
function Addon:PerformFullReset()
    local currentKey = self.GetCurrentProfileKey and self:GetCurrentProfileKey()
    if currentKey then
        local chars = self.db and self.db.global and self.db.global.chars
        if chars and chars[currentKey] then
            local cdb = chars[currentKey]
            if wipe then
                wipe(cdb.checked           or {})
                wipe(cdb.collapsedSections or {})
                wipe(cdb.sectionCompleted  or {})
            else
                cdb.checked           = {}
                cdb.collapsedSections = {}
                cdb.sectionCompleted  = {}
            end
            cdb.startAtSectionId = ""
        end
    end

    -- Nil every character's tracking snapshot so alt-summary shows "—" until
    -- each character logs in and a fresh snapshot is captured.
    local allChars = self.db and self.db.global and self.db.global.chars
    if allChars then
        for _, cdb in pairs(allChars) do
            if type(cdb) == "table" then
                cdb.trackingSnapshot = nil
            end
        end
    end
    local gdb = self.db and self.db.global
    if gdb then
        gdb.mainFramePos  = nil
        gdb.mainFrameSize = nil
        gdb.uiScalePct    = 100
        gdb.uiOpacityPct  = 65
        if gdb.themeColors then wipe(gdb.themeColors) end
    end
    if self.ApplyThemeColors then self:ApplyThemeColors() end
    if self.ApplyUIScale     then self:ApplyUIScale()     end
    if self.ApplyOpacity     then self:ApplyOpacity()     end
    local mf = self._mainFrame
    if mf then
        mf:ClearAllPoints()
        mf:SetPoint("CENTER")
        mf:SetSize(self.UI.frameW, self.UI.frameH)
        if self.ApplyScrollLayout then self:ApplyScrollLayout() end
    end
    if self.LayoutHeaderButtons then self:LayoutHeaderButtons() end
    if self.SyncGearPopup       then self:SyncGearPopup()       end
    if self.RequestRefresh then self:RequestRefresh() else self:Refresh() end
end

-- Restores _sessionLocaleOverride from SavedVariables if a valid override is saved.
-- Called on init (when companion is already loaded) and when companion loads late.
local function RestoreSavedLocaleOverride(self)
    local savedLocale = self.db and self.db.global and self.db.global.localeOverride
    if type(savedLocale) == "string" and savedLocale ~= "" and savedLocale ~= "auto" then
        self._sessionLocaleOverride = savedLocale
    end
end

-- Initialize AceDB and minimap icon on addon load
function Addon:OnInitialize()
    self:SetupAddonDB()
    -- Restore persisted locale override only if the localization companion is
    -- already loaded at this point. If it loads later, OnAddonLoaded handles it.
    if self.IsLocalizationCompanionLoaded and self:IsLocalizationCompanionLoaded() then
        RestoreSavedLocaleOverride(self)
    end
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

    if self.PruneObsoleteSavedState then
        self:PruneObsoleteSavedState()
    end

    -- Always register background tracking events so the snapshot is kept current
    -- even when the addon window is never opened this session.  Previously this
    -- was gated behind HasTrackingSnapshot(), which meant brand-new characters
    -- (or those with no prior snapshot) never got their data saved.
    if self.ConfigureTrackingEvents then
        self:ConfigureTrackingEvents(nil, true, true)
    end

    -- Record this character's class and level immediately on login so they
    -- appear in AltsSummary even if the main window is never opened.
    -- (Previously this only happened inside the CreateFrame callback.)
    do
        local _, classToken = UnitClass("player")
        local profileKey    = self:GetCurrentProfileKey()
        if classToken and profileKey and profileKey ~= "" then
            self.db.global.charClasses         = self.db.global.charClasses or {}
            self.db.global.charClasses[profileKey] = classToken
            self.db.global.charLevels          = self.db.global.charLevels  or {}
            self.db.global.charLevels[profileKey]  = UnitLevel("player")
        end
    end

    -- Apply saved theme-color overrides before anything else that uses THEME
    -- (e.g. RegisterSettingsPanel calls StyleButton during panel construction).
    if self.ApplyThemeColors then
        self:ApplyThemeColors()
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

    -- Companion just loaded: restore any saved locale override now that it is available.
    RestoreSavedLocaleOverride(self)

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

-- wipe() is always provided by the WoW Lua environment.
local function Wipe(tableToWipe)
    if tableToWipe then wipe(tableToWipe) end
end

Addon._sectionPool = Addon._sectionPool or {}
Addon._checkboxPool = Addon._checkboxPool or {}
Addon._activeSections = Addon._activeSections or {}
-- Tracks sections the user has explicitly expanded while complete, so
-- UpdateSectionVisuals does not immediately re-collapse them on click.
Addon._userExpandedCompleted = Addon._userExpandedCompleted or {}

Addon._dataSig = Addon._dataSig or ""
Addon._sectionsById = Addon._sectionsById or {}
Addon._order = Addon._order or {}
Addon._sectionsIndexById = Addon._sectionsIndexById or {}

-- Returns a stable per-character key: always "CharName - RealmName".
-- Lives in the main file so it is available before any module loads.
-- Cached after first successful resolution (UnitName/RealmName never change post-login).
local _cachedProfileKey
function Addon:GetCurrentProfileKey()
    if _cachedProfileKey then return _cachedProfileKey end
    local name  = UnitName("player") or ""
    local realm = GetRealmName()      or ""
    local key = (name ~= "" and realm ~= "") and (name .. " - " .. realm)
             or (name ~= "" and name)
             or ""
    if key ~= "" then _cachedProfileKey = key end
    return key
end

-- Database and hidden-row helpers live in features/services/general/LariasWeeklyChecklist_Database.lua.

-- Remove stale saved-state entries (checked items / collapsed sections) that no longer
-- correspond to any known section/item IDs in the current dataset.
-- This keeps SavedVariables from accumulating garbage across data/ID refactors.
-- PruneObsoleteSavedState → features/body/LariasWeeklyChecklist_ListData.lua

-- Pick the best locale code to use.
-- If the localization companion is loaded, check for a saved override first.
-- Without the companion, always use the WoW client language.
function Addon:GetEffectiveLocaleCode()
    local companionLoaded = self.IsLocalizationCompanionLoaded and self:IsLocalizationCompanionLoaded()

    local code
    if companionLoaded then
        local override = tostring(self._sessionLocaleOverride or "auto")
        if override ~= "auto" and override ~= "" then
            code = override
        end
    end
    if not code then
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

-- Set a locale override and persist it to SavedVariables so it survives /reload.
function Addon:SetLocaleOverride(value)
    value = tostring(value or "auto")
    if value == "" then value = "auto" end

    -- Persist to SavedVariables.
    local gdb = self.db and self.db.global
    if gdb then
        gdb.localeOverride = (value == "auto") and "" or value
    end

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
    if self.RegisterSettingsPanel then self:RegisterSettingsPanel() end
    local cat = self._settingsCategory
    if cat and Settings and Settings.OpenToCategory then
        local catId = cat.GetID and cat:GetID() or cat
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

-- Hoisted once: SetBackdrop is called per frame creation and per pool reuse,
-- so avoiding repeated table allocation here is worthwhile.
local BACKDROP_DEF = {
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    tile     = false,
    edgeSize = 1,
    insets   = { left = 3, right = 3, top = 3, bottom = 3 },
}

-- Apply the shared theme backdrop to a frame.
-- Also mixes in BackdropTemplateMixin when the frame lacks SetBackdrop, so
-- callers don't need a separate Mixin guard before calling this.
function Addon:ApplyTheme(frameObj)
    if not frameObj then return end
    if not frameObj.SetBackdrop and BackdropTemplateMixin and Mixin then
        Mixin(frameObj, BackdropTemplateMixin)
    end
    if not frameObj.SetBackdrop then return end
    local vs = Addon.VISUAL_STYLE or {}
    local borderA = math.min(tonumber(Addon.THEME.border.a) or 1, tonumber(vs.panelBorderA) or 1)
    frameObj:SetBackdrop(BACKDROP_DEF)
    frameObj:SetBackdropColor(Addon.THEME.bg.r, Addon.THEME.bg.g, Addon.THEME.bg.b, Addon.THEME.bg.a)
    frameObj:SetBackdropBorderColor(Addon.THEME.border.r, Addon.THEME.border.g, Addon.THEME.border.b, borderA)
end

function Addon:ApplyPopupBorder(frameObj)
    if not frameObj or not frameObj.SetBackdropBorderColor then return end
    local bdr = Addon.THEME and Addon.THEME.border
    if not bdr then return end
    local vs = Addon.VISUAL_STYLE or {}
    frameObj:SetBackdropBorderColor(bdr.r, bdr.g, bdr.b, vs.popupBorderA or bdr.a or 1)
end

function Addon:ApplyOpaquePopupTheme(frameObj)
    if not frameObj then return end
    self:ApplyTheme(frameObj)
    local bg = Addon.THEME and Addon.THEME.bg
    if bg and frameObj.SetBackdropColor then
        frameObj:SetBackdropColor(bg.r, bg.g, bg.b, 1.0)
    end
    self:ApplyPopupBorder(frameObj)
end

function Addon:ToggleGreatVault()
    if not WeeklyRewardsFrame and C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, "Blizzard_WeeklyRewards")
    end
    if not WeeklyRewardsFrame then return end
    if WeeklyRewardsFrame:IsShown() then WeeklyRewardsFrame:Hide()
    else WeeklyRewardsFrame:Show() end
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

-- Apply saved theme-color overrides from db.global.themeColors to Addon.THEME,
-- then re-apply the backdrop + repaint list items so changes are visible immediately.
-- Hardcoded defaults here must match the initial values in CONSTANTS.theme.
--- Pushes new backdrop/border colors into all open themed frames.
local function ApplyThemeBackdrops(self)
    if self._mainFrame then
        self:ApplyTheme(self._mainFrame)
        if self._mainFrame._lariaBgTex then
            local bg = self.THEME.bg
            self._mainFrame._lariaBgTex:SetColorTexture(bg.r, bg.g, bg.b, 1)
        end
    end
    if self._trackingFrame then self:ApplyTheme(self._trackingFrame) end
    -- Alt summary: both inline and standalone use the theme bg at uiOpacityPct alpha.
    -- Standalone also refreshes its title strip; inline hides the title strip.
    local _asf = self._altsSummaryFrame
    if _asf then
        local bg  = self.THEME.bg
        local bd  = self.THEME.border
        local pct = (self.db and self.db.global and tonumber(self.db.global.uiOpacityPct)) or 65
        local bgA = math.max(0, math.min(1.0, pct / 100))
        if _asf._lariaBgTex then
            _asf._lariaBgTex:SetColorTexture(bg.r, bg.g, bg.b, 1)
            _asf._lariaBgTex:SetAlpha(bgA)
            if _asf.SetBackdropColor then _asf:SetBackdropColor(0, 0, 0, 0) end
        elseif _asf.SetBackdropColor then
            _asf:SetBackdropColor(bg.r, bg.g, bg.b, bgA)
        end
        if _asf.SetBackdropBorderColor then
            local vs = self.VISUAL_STYLE or {}
            _asf:SetBackdropBorderColor(bd.r, bd.g, bd.b, vs.panelBorderA or bd.a)
        end
        if not _asf._inline then
            local h = self.THEME.header
            local vs = self.VISUAL_STYLE or {}
            if _asf._altsTitleBgTex then _asf._altsTitleBgTex:SetColorTexture(h.r, h.g, h.b, vs.sectionBandA or 0.09) end
            if _asf._altsTitleFS    then _asf._altsTitleFS:SetTextColor(h.r, h.g, h.b, 1)          end
        end
    end
    if self._gearPopup then
        self:ApplyTheme(self._gearPopup)
        self:ApplyPopupBorder(self._gearPopup)
    end
    if self.ApplyOpacity then self:ApplyOpacity() end
end

--- Applies header color to the tracking-panel column titles and GV row labels.
local function ApplyThemeTrackingLabels(self)
    local tf = self._trackingFrame
    if not tf then return end
    local h = self.THEME.header
    if tf._lariasLeftTitle  then tf._lariasLeftTitle:SetTextColor(h.r, h.g, h.b, h.a)  end
    if tf._lariasRightTitle then tf._lariasRightTitle:SetTextColor(h.r, h.g, h.b, h.a) end
    local grids = tf._lariasGvGrids
    if type(grids) == "table" then
        for i = 1, 3 do
            local g = grids[i]
            if g and g.header then g.header:SetTextColor(h.r, h.g, h.b, h.a) end
        end
    end
end

--- Recolors all active section titles and checkbox ticks with the current theme.
local function ApplyThemeSectionColors(self)
    local hdr = self.THEME.header
    local chk = self.THEME.check or hdr
    for _, sec in ipairs(self._activeSections or {}) do
        if sec._title then sec._title:SetTextColor(hdr.r, hdr.g, hdr.b, hdr.a) end
        for _, cb in ipairs(sec._checkboxes or {}) do
            if cb._tick then cb._tick:SetVertexColor(chk.r, chk.g, chk.b, 1) end
            if cb._box  then self:ApplyTheme(cb._box) end
        end
    end
end

function Addon:ApplyThemeColors()
    local gdb = self.db and self.db.global
    local tc  = gdb and gdb.themeColors

    -- Loads a THEME channel (a table with .r/.g/.b) from saved values,
    -- falling back to the compiled defaults when the key is absent.
    local function loadColor(ch, rk, gk, bk, dr, dg, db_)
        if tc and tc[rk] ~= nil then
            ch.r = tc[rk]; ch.g = tc[gk]; ch.b = tc[bk]
        else
            ch.r = dr;     ch.g = dg;     ch.b = db_
        end
    end

    loadColor(self.THEME.bg,     "bgR",     "bgG",     "bgB",     0.10, 0.10, 0.10)
    loadColor(self.THEME.text,   "textR",   "textG",   "textB",   1.00, 1.00, 1.00)
    loadColor(self.THEME.header, "headerR", "headerG", "headerB", 1.00, 0.82, 0.00)
    -- (Close button × glyph uses fixed colors — not refreshed here.)

    ApplyThemeBackdrops(self)
    ApplyThemeTrackingLabels(self)

    -- Refresh slider widget colors (title labels, min/max, thumb).
    local sf = self._inFrameScaleSlider
    if sf and sf.RefreshColors then sf.RefreshColors() end

    ApplyThemeSectionColors(self)

    -- Refresh Settings panel color swatches if the panel is open.
    if self.RefreshSettingsSwatches then self:RefreshSettingsSwatches() end

    -- Re-style the header buttons (Select Week / View Item Levels).
    local _mf = self._mainFrame
    if _mf and self._styleActionButton then
        if _mf._lariasChangeWeekBtn then self._styleActionButton(_mf._lariasChangeWeekBtn) end
        if _mf._lariasIlvlRefBtn    then self._styleActionButton(_mf._lariasIlvlRefBtn)    end
    end

    -- Refresh gear popup checkbox labels immediately (works whether the popup is shown or not).
    if self.SyncGearPopup then self:SyncGearPopup() end

    -- Rebuild the item-level reference window so its data rows reflect the new text color.
    -- The window is statically built, so a rebuild is the cleanest way to re-color it.
    if self._ilvlRefWindow and self.RebuildIlvlRefWindow then
        self:RebuildIlvlRefWindow()
    end

    -- Re-populate the week picker if it already exists so button labels reflect the new text color.
    -- Guard with _lariasHeaderPicker to avoid eagerly building the picker during color drags.
    local _pickerFrame = _mf and _mf._lariasHeaderPicker
    if _pickerFrame and self._PopulateHeaderPicker then self._PopulateHeaderPicker() end

    -- Repopulate Alt Summary so row/text colors refresh.
    -- Backdrop colors were already handled by ApplyThemeBackdrops above.
    if self._altsSummaryFrame and self.RefreshAltsSummary then
        self:RefreshAltsSummary()
    end

    -- Repaint list item labels with the new text color.
    if self.RequestRefresh then self:RequestRefresh() end
end

-- Recompute the scroll frame anchors.
-- The list needs to shift upward when the tracking panel is visible.
function Addon:ApplyScrollLayout()
    if not (frame and scrollFrame) then return end
    local db = self:EnsurePrefs()

    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", Addon.UI.padOuterX, -Addon.UI.scrollTop)

    -- Slider + banner space must always be reserved, even when the tracking panel
    -- is hidden (both Great Vault and Currency off).  Previously this block was
    -- inside the tracking-visible guard, so hiding both caused the scroll list
    -- to overlap the sliders.
    local sf          = self._inFrameScaleSlider
    local sliderShown = sf and sf.IsShown and sf:IsShown()
    local sliderRowH  = (Addon.UI.sliderH or 0) + (Addon.UI.sliderLabelH or 0) + 2
    local sliderH     = sliderShown and sliderRowH or 0
    -- Banner row always occupies space (frame is permanently visible).
    local bannerExtra = self._statusBanner
        and ((self._statusBannerH or 14) + (self._statusBannerPad or 3))
        or 0
    -- Banner always occupies space; include its height even when sliders are hidden.
    local sliderBotPad = (sliderShown and (Addon.UI.sliderBottomPad or 0) or 0) + bannerExtra
    local sliderTopPad = sliderShown and (Addon.UI.sliderTopPad or 0) or 0

    local extra = sliderH + sliderBotPad + sliderTopPad - Addon.UI.scrollBottom

    if (db.showGreatVault or db.showCurrency) and IsFrameShown(self._trackingFrame) then
        local trackingHeight = (self._trackingFrame.GetHeight and self._trackingFrame:GetHeight()) or Addon.UI.trackH
        trackingHeight = tonumber(trackingHeight) or Addon.UI.trackH
        extra = extra + trackingHeight + Addon.UI.trackTopPad
    end

    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -Addon.UI.scrollRight, Addon.UI.scrollBottom + extra)

    -- Keep the scroll child width in sync with the scroll frame so that
    -- section frames anchored TOPLEFT+TOPRIGHT to scrollChild get a real width.
    local scrollW = scrollFrame:GetWidth() or 0
    if scrollW > 1 then
        scrollChild:SetWidth(scrollW)
    end

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
    local gp = self._gearPopup
    if gp and gp.SetScale then gp:SetScale(scale) end
    -- Alt summary is parented to UIParent; scale it to match.
    local asf = self._altsSummaryFrame
    if asf and asf.SetScale then asf:SetScale(scale) end
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
    -- The gear popup is also parented to UIParent; scale it to match.
    local gp = self._gearPopup
    if gp and gp.SetScale then gp:SetScale(scale) end
    -- Alt summary is parented to UIParent; scale it to match.
    local asf = self._altsSummaryFrame
    if asf and asf.SetScale then asf:SetScale(scale) end
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
    -- Persist collapse state. Store false explicitly for expanded so callers
    -- can distinguish "user set expanded" from "never touched" (nil).
    db = db or Addon:EnsureDB()
    db.collapsedSections[sectionId] = collapsed and true or false
end

local function IsSectionCompleteById(sectionId, db)
    -- A section is complete if every item is checked, OR if the sticky-complete
    -- flag is set (written on first completion; survives addon updates that edit
    -- item text, regenerating IDs via sheet_to_lua, without un-hiding done weeks).
    local section = Addon._sectionsById[sectionId]
    if not section then return false end

    db = db or Addon:EnsureDB()
    local checked = db.checked
    local items = section.items or {}
    -- A section with no items at all is never considered complete.
    if #items == 0 then return false end
    -- Fast-path: sticky flag from a previous completion.
    if db.sectionCompleted and db.sectionCompleted[sectionId] then return true end
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
    local prefix = tostring(sectionId) .. ":"
    local items = section.items or {}
    for i = 1, #items do
        if checked[prefix .. tostring(items[i].id)] then return true end
    end
    return false
end
-- Expose for the Header module so the picker can track the last actively-worked week.
Addon._HasAnySectionItemChecked = HasAnySectionItemChecked

local function GetCurrentSectionId(db)
    -- Returns the sectionId that should start expanded. Mirrors Header's currentId:
    -- 1. startAtSectionId if explicitly set and valid
    -- 2. First section the user has actively worked (any item checked)
    -- 3. First incomplete section
    -- 4. First section in order
    db = db or Addon:EnsureDB()
    local stored = db.startAtSectionId and tostring(db.startAtSectionId) or ""
    if stored ~= "" and Addon._sectionsById and Addon._sectionsById[stored] then
        return stored
    end
    if Addon._order then
        for i = 1, #Addon._order do
            local sid = Addon._order[i]
            if HasAnySectionItemChecked(sid, db) then return sid end
        end
        for i = 1, #Addon._order do
            local sid = Addon._order[i]
            if not IsSectionCompleteById(sid, db) then return sid end
        end
        if Addon._order[1] then return tostring(Addon._order[1]) end
    end
    return nil
end

-- UI pooling: we reuse section frames and checkboxes to avoid allocations during refresh.
-- Must sit above third-party addon overlays (e.g. NaowhQOL UIWidgetPowerBarContainerFrame
-- sits at ~121) so header buttons can receive mouse clicks.
local SECTION_FRAME_LEVEL = 200

local function ApplySectionHeaderTint(sectionFrame)
    if not sectionFrame then return end
    local h = Addon.THEME.header
    local vs = Addon.VISUAL_STYLE or {}
    if sectionFrame._title then
        sectionFrame._title:SetTextColor(h.r, h.g, h.b, h.a)
    end
    if sectionFrame._headerBg then
        sectionFrame._headerBg:SetColorTexture(h.r, h.g, h.b, vs.sectionBandA or 0.10)
    end
    if sectionFrame._headerAccent then
        sectionFrame._headerAccent:SetColorTexture(h.r, h.g, h.b, vs.sectionAccentA or 0.32)
    end
end

local function AcquireSectionFrame()
    local sectionFrame = tremove(Addon._sectionPool)
    if sectionFrame then
        sectionFrame:Show()
        sectionFrame:SetFrameLevel(SECTION_FRAME_LEVEL)
        -- Re-apply header color in case THEME.header changed since last use.
        ApplySectionHeaderTint(sectionFrame)
        return sectionFrame
    end

    sectionFrame = CreateFrame("Frame", nil, scrollChild)
    sectionFrame:SetFrameLevel(SECTION_FRAME_LEVEL)
    sectionFrame:SetWidth(1)
    sectionFrame._checkboxes = {}

    local header = CreateFrame("Button", nil, sectionFrame)
    header:SetPoint("TOPLEFT", sectionFrame, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", sectionFrame, "TOPRIGHT", 0, 0)
    header:SetHeight(Addon.UI.headerMinH)
    header:EnableMouse(true)
    if header.RegisterForClicks then
        header:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    end
    sectionFrame._header = header

    local headerBg = header:CreateTexture(nil, "BACKGROUND")
    headerBg:SetAllPoints(header)
    sectionFrame._headerBg = headerBg

    local headerAccent = header:CreateTexture(nil, "ARTWORK")
    headerAccent:SetPoint("TOPLEFT", header, "TOPLEFT", 2, -1)
    headerAccent:SetPoint("TOPRIGHT", header, "TOPRIGHT", -2, -1)
    headerAccent:SetHeight(1)
    sectionFrame._headerAccent = headerAccent

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT",  header, "LEFT",  3, 0)
    title:SetPoint("RIGHT", header, "RIGHT", -3, 0)
    title:SetJustifyH("CENTER")
    if title.SetWordWrap then title:SetWordWrap(true) end
    sectionFrame._title = title
    ApplySectionHeaderTint(sectionFrame)

    -- Expand/collapse toggle button anchored to the right of the header.
    -- Parented to sectionFrame (not the Button header) so it is a sibling
    -- rather than a nested button, avoiding click-propagation issues.
    local expandBtn = Addon.Controls.NewExpandButton(
        sectionFrame, nil, true,
        L and L.EXPAND_SECTION  or "Expand section",
        L and L.COLLAPSE_SECTION or "Collapse section")
    expandBtn:SetPoint("RIGHT", sectionFrame._header, "RIGHT", -4, 0)
    sectionFrame._expandBtn = expandBtn

    -- Transparent hover zone covering only the title text (left of the expand button).
    -- Used to scope the "click to change week" tooltip to just the label area.
    local titleHover = CreateFrame("Frame", nil, sectionFrame)
    titleHover:SetPoint("TOPLEFT",    header,    "TOPLEFT",    0,  0)
    titleHover:SetPoint("BOTTOMRIGHT", expandBtn, "BOTTOMLEFT", -4, 0)
    titleHover:EnableMouse(false)  -- enabled only when this is the picker section
    sectionFrame._titleHover = titleHover

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
    sectionFrame._header:SetScript("OnEnter", nil)
    sectionFrame._header:SetScript("OnLeave", nil)
    if sectionFrame._expandBtn then
        sectionFrame._expandBtn:SetScript("OnClick", nil)
    end
    tinsert(Addon._sectionPool, sectionFrame)
end

local function AcquireCheckbox(parentSectionFrame)
    -- Acquire (or create) a fully addon-themed checkbox row for an item.
    local checkbox = tremove(Addon._checkboxPool)
    if checkbox then
        checkbox:SetParent(parentSectionFrame)
        checkbox:Show()
        -- Re-apply theme colors in case THEME changed since this checkbox was pooled.
        local h = Addon.THEME.check or Addon.THEME.header
        if checkbox._tick then checkbox._tick:SetVertexColor(h.r, h.g, h.b, 1) end
        if checkbox._box  then Addon:ApplyTheme(checkbox._box) end
    else
        checkbox = Addon.Controls.NewCheckBox(parentSectionFrame, nil, 32)
    end

    -- checkbox.text is always set by NewCheckBox; .Text fallback is dead code.
    local textLabel = checkbox.text
    if textLabel then
        textLabel:SetJustifyH("LEFT")
        textLabel:SetWordWrap(true)
        textLabel:SetTextColor(Addon.THEME.text.r, Addon.THEME.text.g, Addon.THEME.text.b, Addon.THEME.text.a)
    end

    return checkbox
end
local UpdateSectionVisuals

local function ComputeHeaderHeight(sectionFrame, headerTextWidth)
    -- Header height is dynamic based on text wrapping.
    sectionFrame._title:SetWidth(headerTextWidth)
    local textHeight = sectionFrame._title:GetStringHeight() or 0
    local headerHeight = max(Addon.UI.headerMinH, textHeight + 6)
    sectionFrame._header:SetHeight(headerHeight)
    sectionFrame._headerBlockHeight = headerHeight + Addon.UI.headerBottomPad
end

local function LayoutItems(sectionFrame, collapsed, hideCompletedTasks)
    -- Stack item rows under the header; hide when collapsed.
    -- When the "hide completed tasks" pref is active, skip checked items from
    -- the layout entirely so the section shrinks to fit only visible rows.
    -- hideCompletedTasks is passed as a parameter (rather than read from prefs
    -- here) so callers can hoist the single EnsurePrefs() call and avoid
    -- repeating it for every section on each layout pass.
    local posY        = -(sectionFrame._headerBlockHeight or (Addon.UI.headerMinH + Addon.UI.headerBottomPad))
    local totalHeight = 0
    local hideChecked = not collapsed and hideCompletedTasks
    local checkboxes  = sectionFrame._checkboxes
    for i = 1, #checkboxes do
        local checkbox = checkboxes[i]
        checkbox:ClearAllPoints()
        checkbox:SetPoint("TOPLEFT", sectionFrame, "TOPLEFT", 0, posY)
        checkbox:SetWidth(32) -- constrain the tick-box click-target; the text label inside is sized separately by UpdateItems
        local rowHeight = checkbox:GetHeight() or Addon.UI.itemMinH
        local show = not collapsed and not (hideChecked and checkbox:GetChecked())
        checkbox:SetShown(show)
        if show then
            posY        = posY        - rowHeight
            totalHeight = totalHeight + rowHeight
        end
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

    -- Hoist frame width query: scrollFrame:GetWidth() is a C call that returns
    -- the same value for every section in this pass, so computing it once avoids
    -- a redundant API call per visible section.
    local sectionW = math.max(1, (scrollFrame and scrollFrame:GetWidth() or Addon.UI.frameW) - 2 * paddingX)
    for i = 1, #activeSections do
        local sectionFrame = activeSections[i]
        if sectionFrame:IsShown() then
            if i < startIndex then
                posY = posY - sectionFrame:GetHeight() - sectionGap
            else
                sectionFrame:ClearAllPoints()
                sectionFrame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", paddingX, posY)
                sectionFrame:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -paddingX, posY)
                sectionFrame:SetWidth(sectionW)
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

local function EnsureCompletionPanel()
    if frame and frame._lariasCompletionPanel then
        return frame._lariasCompletionPanel
    end
    if not (frame and scrollChild) then return nil end

    local panel = CreateFrame("Frame", nil, scrollChild)
    panel:SetHeight(96)
    panel:Hide()

    local content = CreateFrame("Frame", nil, panel)
    content:SetSize(220, 60)
    content:SetPoint("CENTER", panel, "CENTER", 0, 0)
    panel._contentFrame = content

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", content, "TOP", 0, 0)
    title:SetText(L.COMPLETION_JOB_DONE or "Job's done.")
    panel._titleFS = title

    local btn = Addon.Controls and Addon.Controls.NewActionButton
        and Addon.Controls.NewActionButton(panel, 160, 24)
        or CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btn:SetSize(160, 24)
    btn:SetText(L.COMPLETION_OPEN_ALT_SUMMARY or L.ALT_SUMMARY_TITLE or "Open Alt Summary")
    btn:SetPoint("TOP", title, "BOTTOM", 0, -14)
    btn:SetScript("OnClick", function()
        if Addon.ToggleAltsSummary then
            Addon:ToggleAltsSummary(frame)
        end
    end)
    btn:SetScript("OnEnter", function(self_)
        if Addon.AddonUtils and Addon.AddonUtils.SetTooltip then
            Addon.AddonUtils.SetTooltip(self_, L.TOOLTIP_CLICK_TO_OPEN or "Click to open")
        end
    end)
    btn:SetScript("OnLeave", function()
        if Addon.AddonUtils and Addon.AddonUtils.HideTooltip then
            Addon.AddonUtils.HideTooltip()
        elseif GameTooltip then
            GameTooltip:Hide()
        end
    end)
    panel._altSummaryBtn = btn

    frame._lariasCompletionPanel = panel
    return panel
end

local function ShowCompletionPanel(show)
    local panel = EnsureCompletionPanel()
    if not panel then return end

    if not show then
        panel:Hide()
        return
    end

    local th = Addon.THEME or {}
    local header = th.header or { r = 1, g = 0.82, b = 0 }
    if panel._titleFS then
        panel._titleFS:SetText(L.COMPLETION_JOB_DONE or "Job's done.")
        panel._titleFS:SetTextColor(header.r, header.g, header.b, header.a or 1)
    end
    if panel._altSummaryBtn then
        panel._altSummaryBtn:SetText(L.COMPLETION_OPEN_ALT_SUMMARY or L.ALT_SUMMARY_TITLE or "Open Alt Summary")
        if Addon.Controls and Addon.Controls.StyleButton then
            Addon.Controls.StyleButton(panel._altSummaryBtn)
        end
    end

    local paddingX = Addon.UI.sectionInsetX
    local sectionW = math.max(1, (scrollFrame and scrollFrame:GetWidth() or Addon.UI.frameW) - 2 * paddingX)
    local scrollH = (scrollFrame and scrollFrame.GetHeight and tonumber(scrollFrame:GetHeight())) or 0
    local panelH = max(96, scrollH - (Addon.UI.sectionTopPad or 0) * 2)
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", paddingX, -Addon.UI.sectionTopPad)
    panel:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -paddingX, -Addon.UI.sectionTopPad)
    panel:SetWidth(sectionW)
    panel:SetHeight(panelH)
    if panel._contentFrame then
        panel._contentFrame:ClearAllPoints()
        panel._contentFrame:SetPoint("CENTER", panel, "CENTER", 0, 0)
    end
    panel:Show()
    scrollChild:SetHeight(max(scrollH, panelH + (Addon.UI.sectionTopPad or 0) * 2))
end

function Addon:UpdateCompletionEasterEgg(db)
    -- When the list is fully complete (no visible sections remain after
    -- hide-completed collapses them), show a compact completion message with
    -- a button that opens the normal Alt Summary popup.
    if not (frame and scrollFrame) then return end

    db = db or self:EnsureDB()
    local isComplete = self:IsListComplete(db)

    -- Only trigger the completion view once all section frames are hidden
    -- (i.e. hide-completed is on and every item is checked).
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

    local showComplete = isComplete and (visibleSections == 0)

    scrollFrame:Show()

    local sb = scrollFrame.ScrollBar
    if sb and sb.SetShown then
        sb:SetShown(not showComplete)
    elseif sb and showComplete and sb.Hide then
        sb:Hide()
    elseif sb and (not showComplete) and sb.Show then
        sb:Show()
    end

    local tf = self._trackingFrame
    local prefs = self:EnsurePrefs()
    if tf then
        if prefs.showGreatVault or prefs.showCurrency then
            tf:Show()
        else
            tf:Hide()
        end
    end
    -- Always resize tracking columns so Great Vault columns aren't shrunk in
    -- completion mode (ApplyScrollLayout was previously skipped when complete).
    if self.ApplyScrollLayout then self:ApplyScrollLayout() end

    ShowCompletionPanel(showComplete)

    -- If an older inline Alt Summary is visible from a previous complete-state
    -- refresh, close it and restore the normal main-window width.
    local asf = self._altsSummaryFrame
    if asf and asf._inline and asf.IsShown and asf:IsShown() then
        asf:Hide()
        local mf = self._mainFrame
        if mf then
            mf:SetWidth(Addon.UI.frameW)
            if self.ApplyScrollLayout then self:ApplyScrollLayout() end
        end
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
    -- Show a dropdown arrow on the current-week header so it's clear it's clickable.
    if sectionFrame._isPickerSection then
        titleText = titleText .. "  |TInterface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up:14:14|t"
    end
    sectionFrame._title:SetText(titleText)
end

-- Wraps any ALL-CAPS token (2+ consecutive uppercase letters, no lowercase)
-- Sets the checklist item label text colour based on checked state.
local function RefreshItemTextColor(checkbox)
    local lbl = checkbox.text or checkbox.Text
    if not lbl then return end
    if checkbox:GetChecked() then
        lbl:SetTextColor(0.45, 0.45, 0.45, 0.85)
    else
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
    local prefs    = Addon:EnsurePrefs()
    local checked = selfBtn:GetChecked() and true or nil
    database.checked[selfBtn._dbKey or Key(selfBtn._sectionId, selfBtn._itemId)] = checked
    RefreshItemTextColor(selfBtn)

    local sectionId = selfBtn._sectionId
    -- When the user explicitly unchecks an item, clear the sticky-complete flag
    -- first so IsSectionCompleteById re-evaluates item states honestly.
    if not checked then
        if type(database.sectionCompleted) == "table" then
            database.sectionCompleted[sectionId] = nil
        end
    end
    local secCompleteNow = IsSectionCompleteById(sectionId, database)
    if secCompleteNow then
        -- Persist completion so it survives future item-ID changes caused by
        -- developer text edits regenerating IDs via sheet_to_lua.
        if type(database.sectionCompleted) ~= "table" then database.sectionCompleted = {} end
        database.sectionCompleted[sectionId] = true
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

    local hideDone = prefs.hideCompletedSections and true or false

    SetHeaderText(sectionFrame, sectionId, secCompleteNow)
    ComputeHeaderHeight(sectionFrame, Addon.UI.itemTextWidth + Addon.UI.headerTextExtraW)

    local collapsed = IsSectionCollapsed(sectionId, database) or false
    if secCompleteNow then collapsed = true end

    LayoutItems(sectionFrame, collapsed, prefs.hideCompletedTasks)
    UpdateSectionHeight(sectionFrame, collapsed)

    if hideDone and secCompleteNow then
        sectionFrame:Hide()
    else
        sectionFrame:Show()
    end

    LayoutFrom(sectionFrame._index or 1)

    -- After a section completes, recompute the change-week button label from
    -- scratch (LayoutHeaderButtons re-derives currentId from the DB so it
    -- correctly reflects whichever week is now first-incomplete).
    -- For non-completing clicks, a scroll-position refresh is sufficient.
    if secCompleteNow then
        if Addon.LayoutHeaderButtons then Addon:LayoutHeaderButtons() end
    elseif Addon._refreshChangeWeekLabel then
        Addon._refreshChangeWeekLabel()
    end

    if Addon.UpdateCompletionEasterEgg then
        Addon:UpdateCompletionEasterEgg(database)
    end
end

-- ── Guide-link helpers ──────────────────────────────────────────────────────
-- GUIDE_URL: read from constants (same source as the Settings/GearPopup support buttons).
-- Resolved lazily at call time so it picks up Addon.TRACKING.supportLinks.doc after
-- OnInitialize has populated TRACKING from the constants file.
local GUIDE_URL_FALLBACK = "https://docs.google.com/document/d/e/2PACX-1vTGkZ2Cjr0jlv90XqW9vy9VXsVucd-yMCgHdyCvX_kQfOrexNDAC7Lf3LifuhqxrcWqJ0W3zIhvK3ii/pub"
local function GetGuideURL()
    return (Addon.TRACKING and Addon.TRACKING.supportLinks and Addon.TRACKING.supportLinks.doc)
           or GUIDE_URL_FALLBACK
end
local GUIDE_LINK = "|cffffd700|Hlarias:guide|h[CHECK GUIDE]|h|r"

-- FormatGuideText replaces "see guide" / "check guide" (any capitalisation)
-- with a gold inline hyperlink and returns the formatted string plus a boolean
-- indicating whether any replacement was made.  Combining detection and
-- formatting avoids a separate TextHasGuide pass with its own string allocation.
local function FormatGuideText(text)
    local n1, n2, result
    result, n1 = text:gsub("[Ss]ee [Gg]uide",   GUIDE_LINK)
    result, n2 = result:gsub("[Cc]heck [Gg]uide", GUIDE_LINK)
    return result, (n1 + n2) > 0
end

-- Shared hyperlink handlers — defined once at module level so no new closure
-- is allocated per row per sync call.
local function OnGuideHyperlinkClick(_, linkData)
    if linkData == "larias:guide" then
        Addon.OpenSupportLink(GetGuideURL())
    end
end
local function OnGuideHyperlinkEnter(self_)
    GameTooltip:SetOwner(self_, "ANCHOR_CURSOR")
    GameTooltip:SetText(L.GUIDE_LINK_HOVER_TOOLTIP or "Click to copy guide link", 1, 1, 1, 1, true)
    GameTooltip:Show()
end
local function OnGuideHyperlinkLeave()
    GameTooltip:Hide()
end

local function OnHeaderClick(header)
    -- Header click handler toggles collapsed state and relayouts.
    local sectionFrame = header and header._sectionFrame
    if not sectionFrame then return end
    local sectionId = sectionFrame._sectionId
    if not sectionId then return end
    local collapsed = not IsSectionCollapsed(sectionId)
    SetSectionCollapsed(sectionId, collapsed)
    -- Set/clear the explicit-expand flag BEFORE calling UpdateSectionVisuals.
    -- Without this, UpdateSectionVisuals would see complete==true and immediately
    -- re-collapse the section the user just opened.
    if not collapsed then
        Addon._userExpandedCompleted[sectionId] = true
    else
        Addon._userExpandedCompleted[sectionId] = nil
    end
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
            checkbox._isGuideRow = false  -- explicitly reset so a recycled checkbox doesn't carry stale guide-row state
            checkbox:SetScript("OnClick",          nil)
            checkbox:SetScript("OnEnter",          nil)
            checkbox:SetScript("OnLeave",          nil)
            checkbox:SetScript("OnHyperlinkClick",  nil)
            checkbox:SetScript("OnHyperlinkEnter", nil)
            checkbox:SetScript("OnHyperlinkLeave", nil)
            if checkbox.SetHyperlinksEnabled then checkbox:SetHyperlinksEnabled(false) end
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

        local itemText = tostring(item.text or item.id)
        local formattedText, isGuide = FormatGuideText(itemText)
        checkbox._isGuideRow = isGuide

        local textLabel = checkbox.text  -- always set by NewCheckBox
        if textLabel then
            textLabel:SetWidth(itemTextWidth)
            textLabel:SetText(formattedText)

            local textHeight = textLabel:GetStringHeight() or 0
            checkbox:SetHeight(max(minRowHeight, textHeight + itemTextPad))
        else
            checkbox:SetHeight(minRowHeight)
        end

        checkbox:SetChecked(checkedMap[dbKey] and true or false)
        RefreshItemTextColor(checkbox)

        -- Restore cb to normal checkbox behaviour for every row.
        checkbox:SetScript("OnClick",  OnCheckboxClick)
        checkbox:SetScript("OnEnter", nil)
        checkbox:SetScript("OnLeave", nil)

        if isGuide then
            if checkbox.SetHyperlinksEnabled then
                checkbox:SetHyperlinksEnabled(true)
            end
            checkbox:SetScript("OnHyperlinkClick",  OnGuideHyperlinkClick)
            checkbox:SetScript("OnHyperlinkEnter", OnGuideHyperlinkEnter)
            checkbox:SetScript("OnHyperlinkLeave", OnGuideHyperlinkLeave)
        else
            if checkbox.SetHyperlinksEnabled then
                checkbox:SetHyperlinksEnabled(false)
            end
            checkbox:SetScript("OnHyperlinkClick",  nil)
            checkbox:SetScript("OnHyperlinkEnter", nil)
            checkbox:SetScript("OnHyperlinkLeave", nil)
        end
    end
end

-- precomputedCurrentId: optional; pass from ApplySectionVisuals to avoid
-- calling GetCurrentSectionId once per section on first open.
UpdateSectionVisuals = function(sectionFrame, sectionId, precomputedCurrentId)
    local database = Addon:EnsureDB()
    local prefs    = Addon:EnsurePrefs()

    -- Optional filter: hide everything before a selected header.
    -- startAtSectionId is still per-character (stored in per-char db).
    local startId = tostring(database.startAtSectionId or "")
    if startId ~= "" then
        local startIndex = Addon._sectionsIndexById and Addon._sectionsIndexById[startId]
        if type(startIndex) == "number" and type(sectionFrame._index) == "number" and sectionFrame._index < startIndex then
            sectionFrame:Hide()
            return
        end
    end

    local complete = IsSectionCompleteById(sectionId, database)

    local hideDone = prefs.hideCompletedSections and true or false
    if hideDone and complete then
        sectionFrame:Hide()
        return
    end

    sectionFrame:Show()

    ApplySectionHeaderTint(sectionFrame)

    -- Only auto-collapse a completed section when the user has NOT explicitly
    -- expanded it (tracked via _userExpandedCompleted set in OnHeaderClick).
    local userExpanded = Addon._userExpandedCompleted and Addon._userExpandedCompleted[sectionId]
    if complete and not userExpanded then
        SetSectionCollapsed(sectionId, true, database)
    end

    SetHeaderText(sectionFrame, sectionId, complete)
    local headerTextW = Addon.UI.itemTextWidth + Addon.UI.headerTextExtraW
    if sectionFrame._expandBtn then headerTextW = headerTextW - 26 end
    ComputeHeaderHeight(sectionFrame, headerTextW)

    -- Default-collapse sections that have never been explicitly toggled,
    -- keeping only the current active section expanded.
    local explicitlySet = (database.collapsedSections[sectionId] ~= nil)
    local collapsed
    if complete and not userExpanded then
        collapsed = true
    elseif explicitlySet then
        collapsed = database.collapsedSections[sectionId] == true
    else
        -- First open: collapse everything except the current section.
        -- Use precomputedCurrentId when available to avoid re-walking _order
        -- once per section (ApplySectionVisuals pre-computes this).
        local currentId = precomputedCurrentId or GetCurrentSectionId(database)
        collapsed = (tostring(sectionId) ~= tostring(currentId or ""))
        SetSectionCollapsed(sectionId, collapsed, database)
    end

    local checkedMap = database.checked
    for i = 1, #sectionFrame._checkboxes do
        local checkbox = sectionFrame._checkboxes[i]
        -- Use the pre-built _dbKey instead of re-calling Key() inside IsItemChecked.
        if checkbox and checkbox._dbKey ~= nil then
            checkbox:SetChecked(checkedMap[checkbox._dbKey] and true or false)
            RefreshItemTextColor(checkbox)
        end
    end

    LayoutItems(sectionFrame, collapsed, prefs.hideCompletedTasks)
    UpdateSectionHeight(sectionFrame, collapsed)

    -- Sync the expand button's visual state.
    if sectionFrame._expandBtn then
        sectionFrame._expandBtn:Show()
        sectionFrame._expandBtn:SetExpanded(not collapsed)
    end
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
    -- Pre-compute once so UpdateSectionVisuals doesn't re-walk _order N times
    -- on the first open (when all collapsedSections entries are nil).
    local currentSectionId = GetCurrentSectionId(database)
    for i = 1, want do
        local sectionId    = Addon._order[i]
        local sectionFrame = Addon._activeSections[i]
        sectionFrame:SetParent(child)
        -- SetParent resets frame level to parent+1; re-apply so section frames
        -- sit above third-party overlay frames and headers receive mouse clicks.
        sectionFrame:SetFrameLevel(SECTION_FRAME_LEVEL)
        if sectionFrame._header then
            sectionFrame._header:SetFrameLevel(SECTION_FRAME_LEVEL + 1)
            sectionFrame._header:EnableMouse(true)
        end
        if sectionFrame._expandBtn then
            sectionFrame._expandBtn:SetFrameLevel(SECTION_FRAME_LEVEL + 2)
            -- Wire OnClick here (not at creation) because sectionId is now known.
            local capturedFrame   = sectionFrame
            local capturedSection = Addon._order[i]
            sectionFrame._expandBtn:SetScript("OnClick", function(self_)
                local coll = not IsSectionCollapsed(capturedSection)
                SetSectionCollapsed(capturedSection, coll)
                if not coll then
                    Addon._userExpandedCompleted[capturedSection] = true
                else
                    Addon._userExpandedCompleted[capturedSection] = nil
                end
                if UpdateSectionVisuals then
                    UpdateSectionVisuals(capturedFrame, capturedSection)
                end
                LayoutFrom(capturedFrame._index or 1)
            end)
        end
        sectionFrame._sectionId             = sectionId
        sectionFrame._index                 = i
        Addon._sectionsIndexById[sectionId] = i

        if needCheckboxResync or i > haveBefore then
            SyncCheckboxesForSection(sectionFrame, sectionId, database)
        end

        sectionFrame._header._sectionFrame = sectionFrame
        local isCurrentSec = (tostring(sectionId) == tostring(currentSectionId or ""))
        sectionFrame._isPickerSection = isCurrentSec
        if sectionFrame._expandBtn then
            sectionFrame._expandBtn:Show()
        end
        if isCurrentSec then
            -- Current/topmost week: clicking the section title opens the week picker.
            -- Expand/collapse still works via the expand button on the right.
            local _capturedSF = sectionFrame
            sectionFrame._header:SetScript("OnClick", function()
                local p = (Addon._EnsureHeaderPicker and Addon._EnsureHeaderPicker())
                       or (frame and frame._lariasHeaderPicker)
                if not p then return end
                if p._lariasClosedAt and (GetTime() - p._lariasClosedAt) < 0.20 then
                    p._lariasClosedAt = nil; return
                end
                if p.IsShown and p:IsShown() then p:Hide(); return end
                p:ClearAllPoints()
                p:SetPoint("TOPLEFT", _capturedSF._header, "BOTTOMLEFT", 0, -4)
                p:Show()
                if C_Timer and C_Timer.After then
                    C_Timer.After(0, Addon._PopulateHeaderPicker)
                elseif Addon._PopulateHeaderPicker then
                    Addon._PopulateHeaderPicker()
                end
            end)
            if sectionFrame._titleHover then
                sectionFrame._titleHover:EnableMouse(true)
                sectionFrame._titleHover:SetScript("OnEnter", function(self_)
                    Addon.AddonUtils.SetTooltip(self_, L.PICKER_HEADER_TOOLTIP or "Click to change week", "ANCHOR_BOTTOMLEFT")
                end)
                sectionFrame._titleHover:SetScript("OnLeave", Addon.AddonUtils.HideTooltip)
            end
        else
            sectionFrame._header:SetScript("OnClick", OnHeaderClick)
            if sectionFrame._titleHover then
                sectionFrame._titleHover:EnableMouse(false)
                sectionFrame._titleHover:SetScript("OnEnter", nil)
                sectionFrame._titleHover:SetScript("OnLeave", nil)
            end
        end

        UpdateSectionVisuals(sectionFrame, sectionId, currentSectionId)
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

    -- Pre-populate the full index BEFORE ApplySectionVisuals iterates the
    -- section frames. UpdateSectionVisuals looks up startAtSectionId in this
    -- index; if the target section comes later in the list, its entry wouldn't
    -- exist yet when earlier sections are processed, causing the hide-filter to
    -- silently fail and those earlier sections to remain visible.
    for i = 1, want do
        Addon._sectionsIndexById[Addon._order[i]] = i
    end

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

    SyncAllDataAndFrames()

    -- Size the change-week button to fit the widest week label in the dataset.
    if self._calcChangeWeekBtnWidth then self._calcChangeWeekBtnWidth() end

    -- Run after SyncAllDataAndFrames so _sectionsById is fully populated and
    -- the change-week button shows the real current week from the very first load.
    if self.LayoutHeaderButtons then self:LayoutHeaderButtons() end

    -- LayoutFrom(1) re-anchors all visible sections, sets their widths, and
    -- updates scrollChild:SetHeight — identical to the manual loop that was
    -- here before, but without the duplicate ApplyScrollLayout call.
    LayoutFrom(1)

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

--- Records class, level, and equipped ilvl for the current character into the global DB.
-- Called once from CreateFrame on first open; deferred from OnEnable so global data is
-- never written before the player has opened the addon for the first time.
local function RecordCharacterMetadata(self)
    if not (self.db and self.db.global) then return end
    local _, classToken = UnitClass("player")
    local profileKey    = self:GetCurrentProfileKey()
    local gdb           = self.db.global
    if classToken and profileKey and profileKey ~= "" then
        gdb.charClasses = gdb.charClasses or {}
        gdb.charClasses[profileKey] = classToken
        gdb.charLevels = gdb.charLevels or {}
        gdb.charLevels[profileKey] = UnitLevel("player") or 0
        if GetAverageItemLevel then
            local _, _, equipped = GetAverageItemLevel()
            local ilvl = math.floor(tonumber(equipped) or 0)
            if ilvl > 0 then
                gdb.chars = gdb.chars or {}
                gdb.chars[profileKey] = gdb.chars[profileKey] or {}
                gdb.chars[profileKey].ilvl = ilvl
            end
        end
    end
    -- Remove stale generic-profile entries (e.g. "Default") that lack the
    -- "CharName - Realm" format; they cause wrong class colours in the picker.
    local classes = gdb.charClasses
    if classes then
        for k in pairs(classes) do
            if not tostring(k):find(" %- ") then classes[k] = nil end
        end
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
        local altsSummary = Addon._altsSummaryFrame
        if altsSummary and altsSummary._inline and altsSummary.IsShown and altsSummary:IsShown() then
            altsSummary:Hide()
        end
        if Addon._restoreHiddenFrame and Addon._restoreHiddenFrame.IsShown and Addon._restoreHiddenFrame:IsShown() then
            Addon._restoreHiddenFrame:Hide()
        end
        if Addon.CharPicker and Addon.CharPicker.Close then Addon.CharPicker.Close() end
    end)
    -- Record this character's class, level, and ilvl on first open.
    RecordCharacterMetadata(self)

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

    -- Character picker dropdown (footer bar + right-click hide menu).
    -- Defined in features/footer/LariasWeeklyChecklist_CharPicker.lua.
    -- Initialized after the header so Controls.StyleButton is available.
    if self.InitCharPickerUI then
        self:InitCharPickerUI(frame, Addon.Controls.StyleButton)
        if self.LayoutHeaderButtons then self:LayoutHeaderButtons() end
    end

    scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", Addon.UI.padOuterX, -Addon.UI.scrollTop)

    scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(1, 1)
    scrollFrame:SetScrollChild(scrollChild)

    -- Expose scroll frame for the header module's deferred closures.
    Addon._scrollFrame = scrollFrame
    -- Wire scroll-event hooks that were defined by CreateHeader.
    if Addon._wireScrollHeaderHooks then
        Addon._wireScrollHeaderHooks(scrollFrame)
    end

    local db = self:EnsurePrefs()
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

    -- Re-apply saved theme colors to all just-created frame elements.
    -- ApplyThemeColors in OnEnable only updates Addon.THEME in memory because
    -- the frame doesn't exist yet; this call runs with _mainFrame set so the
    -- background texture, tracking-panel labels, and header buttons all receive
    -- the correct saved colors immediately on first open after a reload.
    if self.ApplyThemeColors then self:ApplyThemeColors() end

    if scrollFrame then scrollFrame:Show() end
end

function Addon:Toggle()
    -- Main entry point for showing/hiding the addon window.
    self:CreateFrame()
    if frame:IsShown() then
        frame:Hide()
    else
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

    -- Unknown args: show help.
    self:Print(L.SLASH_USAGE_TOGGLE or "Usage: /larias or /lcl to toggle the checklist")
end
