local addonName = ...
local Addon = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceEvent-3.0", "AceHook-3.0", "AceConsole-3.0", "AceTimer-3.0")
_G[addonName] = Addon

local LOCALE_REGISTRY_KEY = "LARIASWEEKLYMIDNIGHTCHECKLIST_LOCALE_REGISTRY"

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

Addon.L = Addon.L or {}
local L = Addon.L

do
    local reg = GetLocaleRegistry()
    Addon.LOCALES = reg.strings
    Addon.LIST_DATA = reg.data
end

-- Initialize all constants on the new Addon object
do
    function Addon:InitConstants(addonNameInput)
        addonNameInput = addonNameInput or addonName

        local locale = self.L or {}

        -- Group core constants into objects (tables) while keeping legacy fields for compatibility.
        self.CONSTANTS = self.CONSTANTS or {}
        self.CONSTANTS.names = self.CONSTANTS.names or {}
        local names = self.CONSTANTS.names

        if names.displayName == nil then names.displayName = locale.DISPLAY_NAME or addonNameInput end
        if names.dbName == nil then names.dbName = "LariasWeeklyMidnightChecklistDBPC" end
        if names.accountDbName == nil then names.accountDbName = "LariasWeeklyMidnightChecklistDB" end
        if names.listDataKey == nil then names.listDataKey = (addonNameInput .. "_LIST_DATA") end

        self.DISPLAY_NAME = self.DISPLAY_NAME or names.displayName
        self._DB_NAME = self._DB_NAME or names.dbName
        self._ACCOUNT_DB_NAME = self._ACCOUNT_DB_NAME or names.accountDbName
        self._LIST_DATA_KEY = self._LIST_DATA_KEY or names.listDataKey

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

        self.CONSTANTS.tracking = self.CONSTANTS.tracking or self.TRACKING or {}
        self.TRACKING = self.TRACKING or self.CONSTANTS.tracking

        self.TRACKING.profiles = self.TRACKING.profiles or {}
        self.TRACKING.profileDisplayNames = self.TRACKING.profileDisplayNames or {
            tww = "tww",
            midnight = "midnight",
        }

        if self.TRACKING.midnightMinLevel == nil then
            self.TRACKING.midnightMinLevel = 90
        end

        local function EnsureProfile(key)
            local profile = self.TRACKING.profiles[key]
            if type(profile) ~= "table" then
                profile = {}
                self.TRACKING.profiles[key] = profile
            end
            profile.questIDs = profile.questIDs or {}
            return profile
        end

        local twwProfile = EnsureProfile("tww")
        if type(twwProfile.crestCurrencyIDs) ~= "table" then
            twwProfile.crestCurrencyIDs = {
                3284,
                3286,
                3288,
                3290,
            }
        end
        if type(twwProfile.crestAchievementIDs) ~= "table" then
            twwProfile.crestAchievementIDs = {
                41886,
                41887,
                41888,
                41892,
            }
        end
        if twwProfile.sparkCurrencyID == nil then twwProfile.sparkCurrencyID = 3141 end
        if twwProfile.catalystCurrencyID == nil then twwProfile.catalystCurrencyID = 3269 end
        if twwProfile.crestTradeBatch == nil then twwProfile.crestTradeBatch = { 45, 15 } end
        if twwProfile.questIDs.delversBounty == nil then twwProfile.questIDs.delversBounty = 86371 end
        if twwProfile.questIDs.weeklyPrey == nil then twwProfile.questIDs.weeklyPrey = 0 end

        local midnightProfile = EnsureProfile("midnight")
        if type(midnightProfile.crestCurrencyIDs) ~= "table" then
            midnightProfile.crestCurrencyIDs = {
                3383,
                3341,
                3343,
                3345,
                3347,
            }
        end
        if type(midnightProfile.crestAchievementIDs) ~= "table" then
            midnightProfile.crestAchievementIDs = {
                61809,
                42767,
                72768,
                42769,
                42770,
            }
        end
        if midnightProfile.sparkCurrencyID == nil then midnightProfile.sparkCurrencyID = 0 end
        if midnightProfile.catalystCurrencyID == nil then midnightProfile.catalystCurrencyID = 0 end
        if midnightProfile.crestTradeBatch == nil then midnightProfile.crestTradeBatch = { 45, 15 } end
        if midnightProfile.questIDs.delversBounty == nil then midnightProfile.questIDs.delversBounty = 0 end
        if midnightProfile.questIDs.weeklyPrey == nil then midnightProfile.questIDs.weeklyPrey = 0 end
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

local COMM_PREFIX = "LWMC"
local BROADCAST_THROTTLE_SECONDS = 30
local REPLY_THROTTLE_SECONDS = 5

-- Throttle timers for version communication
local broadcastTimerActive = false
local replyTimerActive = false
local queryTimerActive = false

-- Set up database with AceDB
local function SetupAddonDB()
    if Addon.db then return end
    
    local defaults = {
        profile = {
            hideCompletedSections = true,
            showGreatVault = true,
            showCurrency = true,
            localeOverride = "auto",
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
                local mainFrame = _G["LariasWeeklyMidnightChecklistFrame"]
                if mainFrame and mainFrame.IsShown and mainFrame:IsShown() and tonumber(mainFrame._lariasSelectedTab) == 2 then
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
            tooltip:AddLine("Left-click: Toggle checklist", 1, 1, 1)
            tooltip:AddLine("Right-click: Options", 1, 1, 1)
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

local function GetAddonVersion(name)
    name = name or addonName
    local versionString
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        versionString = C_AddOns.GetAddOnMetadata(name, "Version")
    elseif GetAddOnMetadata then
        versionString = GetAddOnMetadata(name, "Version")
    end
    versionString = tostring(versionString or "")
    versionString = versionString:gsub("^%s+", ""):gsub("%s+$", "")
    return versionString
end

function Addon:GetMyVersion()
    if self._myVersion == nil then
        self._myVersion = GetAddonVersion(addonName)
    end
    return self._myVersion or ""
end

local function IsVersionNewer(versionA, versionB)
    if versionA == versionB then return false end
    if versionA == "" then return false end
    if versionB == "" then return true end

    local iterA = tostring(versionA):gmatch("%d+")
    local iterB = tostring(versionB):gmatch("%d+")
    
    while true do
        local numA = iterA()
        local numB = iterB()
        
        if not numA and not numB then break end
        
        local valA = tonumber(numA) or 0
        local valB = tonumber(numB) or 0
        
        if valA ~= valB then
            return valA > valB
        end
    end

    return versionA > versionB
end

function Addon:ShouldShowUpdateNotice()
    local database = self:EnsureDB()
    local myVersion = self:GetMyVersion()
    local newestSeenVersion = tostring(database._newestSeenRemoteVersion or "")
    if newestSeenVersion == "" or myVersion == "" then return false end
    if not IsVersionNewer(newestSeenVersion, myVersion) then return false end
    if tostring(database._dismissedRemoteVersion or "") == newestSeenVersion then return false end
    return true
end

function Addon:DismissUpdateNotice()
    local database = self:EnsureDB()
    database._dismissedRemoteVersion = tostring(database._newestSeenRemoteVersion or "")
end

function Addon:EnsureUpdatePopup()
    if self._updatePopupRegistered then return end
    self._updatePopupRegistered = true

    if not StaticPopupDialogs then return end

    StaticPopupDialogs["LARIASWEEKLYMIDNIGHTCHECKLIST_UPDATE"] = {
        text = "%s",
        button1 = (OKAY or "OK"),
        button2 = (CANCEL or "Later"),
        OnAccept = function()
            Addon:DismissUpdateNotice()
        end,
        OnCancel = function()
            -- Keep pending; we'll remind next time they open the list.
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end

function Addon:ShowUpdatePopupIfNeeded()
    if not self:ShouldShowUpdateNotice() then return end
    if self._updatePopupShownThisOpen then return end

    self:EnsureUpdatePopup()
    if not (StaticPopup_Show and StaticPopupDialogs) then return end

    local displayName = (self.DISPLAY_NAME or (L and L.DISPLAY_NAME) or addonName)
    local popupText
    if type(L.UPDATE_AVAILABLE_FMT) == "string" and L.UPDATE_AVAILABLE_FMT ~= "" then
        popupText = string.format(L.UPDATE_AVAILABLE_FMT, tostring(displayName))
    else
        popupText = (L.UPDATE_AVAILABLE_TEXT or L.UPDATE_AVAILABLE_TITLE or "New version available")
    end

    StaticPopup_Show("LARIASWEEKLYMIDNIGHTCHECKLIST_UPDATE", popupText)
    self._updatePopupShownThisOpen = true
end

local function SafeRegisterPrefix(prefix)
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        pcall(C_ChatInfo.RegisterAddonMessagePrefix, prefix)
    elseif RegisterAddonMessagePrefix then
        pcall(RegisterAddonMessagePrefix, prefix)
    end
end

local function SafeSendAddonMessage(prefix, msg, channel)
    if not channel or channel == "" then return end
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        pcall(C_ChatInfo.SendAddonMessage, prefix, msg, channel)
        return
    end
    if SendAddonMessage then
        pcall(SendAddonMessage, prefix, msg, channel)
    end
end

local function GetGroupChannel()
    local instCat = (LE_PARTY_CATEGORY_INSTANCE ~= nil) and LE_PARTY_CATEGORY_INSTANCE or 2
    if IsInGroup and IsInGroup(instCat) then return "INSTANCE_CHAT" end
    if IsInRaid and IsInRaid() then return "RAID" end
    if IsInGroup and IsInGroup() then return "PARTY" end
    return nil
end

function Addon:BroadcastVersion(force)
    -- Use AceTimer to throttle broadcasts
    if not force then
        if broadcastTimerActive then
            return
        end
    end

    local myVersion = self:GetMyVersion()
    if myVersion == "" then return end
    local payload = "V:" .. myVersion

    local channel = GetGroupChannel()
    if channel then
        SafeSendAddonMessage(COMM_PREFIX, payload, channel)
    end
    if IsInGuild and IsInGuild() then
        SafeSendAddonMessage(COMM_PREFIX, payload, "GUILD")
    end

    -- Start throttle timer
    if not force then
        broadcastTimerActive = true
        self:ScheduleTimer(function() broadcastTimerActive = false end, BROADCAST_THROTTLE_SECONDS)
    end
end

function Addon:RequestVersions(force)
    -- Use AceTimer to throttle version requests
    if not force then
        if queryTimerActive then
            return
        end
    end

    local channel = GetGroupChannel()
    if channel then
        SafeSendAddonMessage(COMM_PREFIX, "Q", channel)
    end
    if IsInGuild and IsInGuild() then
        SafeSendAddonMessage(COMM_PREFIX, "Q", "GUILD")
    end

    -- Start throttle timer
    if not force then
        queryTimerActive = true
        self:ScheduleTimer(function() queryTimerActive = false end, BROADCAST_THROTTLE_SECONDS)
    end
end

function Addon:OnAddonMessage(prefix, message, sender)
    if prefix ~= COMM_PREFIX then return end
    if type(message) ~= "string" then return end

    if message == "Q" then
        -- Use AceTimer-based throttle for replies
        if replyTimerActive then
            return
        end
        
        replyTimerActive = true
        self:ScheduleTimer(function() replyTimerActive = false end, REPLY_THROTTLE_SECONDS)
        
        -- Add random jitter (0 to 2 seconds) to prevent synchronized packet bursts
        local delay = (math.random() * 2.0)
        self:ScheduleTimer(function() 
            self:BroadcastVersion(true) 
        end, delay)
        return
    end

    if message:sub(1, 2) ~= "V:" then return end

    local remoteVersion = message:sub(3) or ""
    remoteVersion = tostring(remoteVersion):gsub("^%s+", ""):gsub("%s+$", "")
    if remoteVersion == "" then return end

    local myVersion = self:GetMyVersion()
    if myVersion == "" then return end

    if sender and sender ~= "" and UnitName then
        local me = UnitName("player")
        if me and me ~= "" then
            local s = sender
            if Ambiguate then
                s = Ambiguate(sender, "none")
            end
            if s == me then
                return
            end
        end
    end

    if IsVersionNewer(remoteVersion, myVersion) then
        local database = self:EnsureDB()
        local newestSeenVersion = tostring(database._newestSeenRemoteVersion or "")
        if newestSeenVersion == "" or IsVersionNewer(remoteVersion, newestSeenVersion) then
            database._newestSeenRemoteVersion = remoteVersion
            database._newestSeenRemoteSender = tostring(sender or "")
        end
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
    SafeRegisterPrefix(COMM_PREFIX)
    Addon._myVersion = GetAddonVersion(addonName)
    
    -- Register console commands
    self:RegisterConsoleCommands()
    
    -- Register events using AceEvent
    self:RegisterEvent("CHAT_MSG_ADDON")
    
    -- Announce once on login so others can compare
    Addon:BroadcastVersion(true)
end

-- Handle chat message addon event
function Addon:CHAT_MSG_ADDON(_, prefix, messageText, _, _, sender)
    Addon:OnAddonMessage(prefix, messageText, sender)
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

function Addon:DB()
    if self.db then
        return self.db.profile
    end
    return _G[self._DB_NAME]
end

function Addon:EnsureDB()
    if not self.db then
        SetupAddonDB()
    end
    return self.db.profile
end

local function WipeTableInPlace(t)
    if type(t) ~= "table" then return end
    for k in pairs(t) do
        t[k] = nil
    end
end

local LOCALE_DISPLAY_NAMES = {
    enUS = "English",
    frFR = "Français",
    esES = "Español (ES)",
    esMX = "Español (MX)",
}

function Addon:GetSupportedLocaleCodes()
    local reg = GetLocaleRegistry()
    local data = reg and reg.data

    local out = {}
    local seen = {}

    if type(data) == "table" then
        for code, dataset in pairs(data) do
            if type(code) == "string" and type(dataset) == "table" then
                out[#out + 1] = code
                seen[code] = true
            end
        end
    end

    if not seen.enUS then
        out[#out + 1] = "enUS"
    end

    table.sort(out, function(a, b)
        if a == b then return false end
        if a == "enUS" then return true end
        if b == "enUS" then return false end
        return tostring(a) < tostring(b)
    end)

    return out
end

function Addon:GetLocaleDisplayName(code)
    code = tostring(code or "")
    local pretty = LOCALE_DISPLAY_NAMES[code] or code
    return ("%s (%s)"):format(pretty, code)
end

function Addon:GetEffectiveLocaleCode()
    local db = self:EnsureDB()
    local override = tostring(db.localeOverride or "auto")

    local code
    if override ~= "auto" and override ~= "" then
        code = override
    else
        code = (GetLocale and GetLocale()) or "enUS"
    end

    local reg = GetLocaleRegistry()
    if reg and type(reg.data) == "table" and type(reg.data[code]) == "table" then
        return code
    end
    return "enUS"
end

function Addon:ApplyLocaleOverride()
    local db = self:EnsureDB()
    if db.localeOverride == nil or db.localeOverride == "" then
        db.localeOverride = "auto"
    end

    local reg = GetLocaleRegistry()
    local strings = reg and reg.strings
    if type(strings) ~= "table" then strings = {} end

    local selected = self:GetEffectiveLocaleCode()

    WipeTableInPlace(self.L)

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

    if self.L and self.L.DISPLAY_NAME then
        self.DISPLAY_NAME = self.L.DISPLAY_NAME
    end

    if self.UpdateLocalizedUI then
        self:UpdateLocalizedUI()
    end
end

function Addon:SetLocaleOverride(value)
    local db = self:EnsureDB()
    value = tostring(value or "auto")
    if value == "" then value = "auto" end

    db.localeOverride = value

    self:ApplyLocaleOverride()

    self._dataSig = ""
    self._cachedListLocaleCode = nil
    self._cachedListData = nil

    if frame and frame.IsShown and frame:IsShown() then
        if self.RequestRefresh then
            self:RequestRefresh()
        elseif self.Refresh then
            self:Refresh()
        end
    end
end

function Addon:OpenOptions()
    self:CreateFrame()

    if frame and frame.IsShown and frame:IsShown() and tonumber(frame._lariasSelectedTab) == 2 then
        frame:Hide()
        return
    end

    if frame and frame.IsShown and not frame:IsShown() then
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

function Addon:SyncOptionsTabControls()
    if not frame then return end
    local db = self:EnsureDB()

    local showGreatVaultCheck = frame._lariasOptShowGreatVault
    if showGreatVaultCheck and showGreatVaultCheck.SetChecked then
        showGreatVaultCheck:SetChecked(db.showGreatVault and true or false)
    end

    local showCurrencyCheck = frame._lariasOptShowCurrency
    if showCurrencyCheck and showCurrencyCheck.SetChecked then
        showCurrencyCheck:SetChecked(db.showCurrency and true or false)
    end

    local hideCompletedCheck = frame._lariasOptHideCompleted
    if hideCompletedCheck and hideCompletedCheck.SetChecked then
        hideCompletedCheck:SetChecked(db.hideCompletedSections and true or false)
    end

    if self.UpdateLocalizedUI then
        self:UpdateLocalizedUI()
    end
end

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

function Addon:UpdateLocalizedUI()
    if not frame then return end

    local showLocaleDropdown = false
    do
        local codes = self.GetSupportedLocaleCodes and self:GetSupportedLocaleCodes() or {}
        for i = 1, #codes do
            if codes[i] ~= "enUS" then
                showLocaleDropdown = true
                break
            end
        end
    end

    local function SetShownCompat(region, shown)
        if not region then return end
        if region.SetShown then
            region:SetShown(shown and true or false)
            return
        end
        if shown then
            if region.Show then region:Show() end
        else
            if region.Hide then region:Hide() end
        end
    end

    local function SetCheckText(checkButton, text)
        if not checkButton then return end
        local textRegion = checkButton.text or checkButton.Text
        if textRegion and textRegion.SetText then
            textRegion:SetText(text)
            if textRegion.SetTextColor then
                textRegion:SetTextColor(Addon.THEME.text.r, Addon.THEME.text.g, Addon.THEME.text.b, Addon.THEME.text.a)
            end
        end
    end

    SetCheckText(frame._lariasOptShowGreatVault, L.OPTIONS_SHOW_GREAT_VAULT or "Show Great Vault")
    SetCheckText(frame._lariasOptShowCurrency, L.OPTIONS_SHOW_CURRENCY or "Show Currency")
    SetCheckText(frame._lariasOptHideCompleted, L.HIDE_COMPLETED_WEEKS or "Hide Completed Weeks")

    local optionsTab = frame._lariasTabOptions
    if optionsTab and optionsTab.SetText then
        optionsTab:SetText(L.OPTIONS_BUTTON or "Options")
    end

    local resetBtn = frame._lariasOptResetBtn
    if resetBtn and resetBtn.SetText then
        resetBtn:SetText(L.RESET_BUTTON or "Reset")
    end

    local localeLabel = frame._lariasOptLocaleLabel
    if localeLabel and localeLabel.SetText then
        SetShownCompat(localeLabel, showLocaleDropdown)
        if showLocaleDropdown then
            localeLabel:SetText(L.OPTIONS_LANGUAGE or "Language")
            if localeLabel.SetTextColor then
                localeLabel:SetTextColor(Addon.THEME.text.r, Addon.THEME.text.g, Addon.THEME.text.b, Addon.THEME.text.a)
            end
        end
    end

    local dropdown = frame._lariasOptLocaleDropdown
    if dropdown and UIDropDownMenu_SetText and UIDropDownMenu_SetSelectedValue then
        SetShownCompat(dropdown, showLocaleDropdown)
        if showLocaleDropdown then
            local db = self:EnsureDB()
            local selectedValue = tostring(db.localeOverride or "auto")
            UIDropDownMenu_SetSelectedValue(dropdown, selectedValue)
            if selectedValue == "auto" then
                UIDropDownMenu_SetText(dropdown, (L.OPTIONS_LANGUAGE_AUTO or "Auto") .. " (" .. tostring((GetLocale and GetLocale()) or "enUS") .. ")")
            else
                UIDropDownMenu_SetText(dropdown, self:GetLocaleDisplayName(selectedValue))
            end
        end
    end

    local trackingFrame = self._trackingFrame
    if trackingFrame and trackingFrame.IsShown and trackingFrame:IsShown() then
        if trackingFrame._lariasLeftTitle and trackingFrame._lariasLeftTitle.SetText then
            trackingFrame._lariasLeftTitle:SetText(L.TRACKING_GREAT_VAULT_TITLE or "")
        end
        if trackingFrame._lariasRightTitle and trackingFrame._lariasRightTitle.SetText then
            trackingFrame._lariasRightTitle:SetText(L.TRACKING_CURRENCY_TITLE or "")
        end
    end
end

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
function Addon:ApplyScrollLayout()
    if not (frame and scrollFrame) then return end
    local db = self:EnsureDB()

    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", Addon.UI.padOuterX, -Addon.UI.scrollTop)

    local extra = 0
    if (db.showGreatVault or db.showCurrency) and self._trackingFrame and self._trackingFrame.IsShown and self._trackingFrame:IsShown() then
        local h = (self._trackingFrame.GetHeight and self._trackingFrame:GetHeight()) or Addon.UI.trackH
        h = tonumber(h) or Addon.UI.trackH
        extra = h + Addon.UI.trackTopPad
    end

    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -Addon.UI.scrollRight, Addon.UI.scrollBottom + extra)
end

local function Key(sectionId, itemId)
    if type(sectionId) == "string" and type(itemId) == "string" then
        return sectionId .. ":" .. itemId
    end
    return tostring(sectionId) .. ":" .. tostring(itemId)
end

local function IsItemChecked(sectionId, itemId, db)
    db = db or Addon:EnsureDB()
    return db.checked[Key(sectionId, itemId)] and true or false
end

local function SetItemChecked(sectionId, itemId, checked, db)
    db = db or Addon:EnsureDB()
    db.checked[Key(sectionId, itemId)] = checked and true or nil
end

local function IsSectionCollapsed(sectionId, db)
    db = db or Addon:EnsureDB()
    return db.collapsedSections[sectionId] or false
end

local function SetSectionCollapsed(sectionId, collapsed, db)
    db = db or Addon:EnsureDB()
    db.collapsedSections[sectionId] = collapsed and true or nil
end

local function IsSectionCompleteById(sectionId, db)
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
    local checkbox = tremove(Addon._checkboxPool)
    if checkbox then
        checkbox:SetParent(parentSectionFrame)
        checkbox:Show()
        return checkbox
    end

    checkbox = CreateFrame("CheckButton", nil, parentSectionFrame, "UICheckButtonTemplate")
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
    local totalHeight = (sectionFrame._headerBlockHeight or (Addon.UI.headerMinH + Addon.UI.headerBottomPad))
    if not collapsed then
        totalHeight = totalHeight + (sectionFrame._itemsHeight or 0)
    end
    sectionFrame:SetHeight(totalHeight)
end

local function LayoutFrom(startIndex)
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
    if not (frame and scrollFrame) then return end

    db = db or self:EnsureDB()
    local isComplete = self:IsListComplete(db)

    local visibleSections = 0
    if self._activeSections then
        for i = 1, #self._activeSections do
            local sectionFrame = self._activeSections[i]
            if sectionFrame and sectionFrame.IsShown and sectionFrame:IsShown() then
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
            local w = tonumber(scrollFrame:GetWidth()) or 0
            local h = tonumber(scrollFrame:GetHeight()) or 0
            local size = math.min(w > 0 and w or 260, h > 0 and h or 260)
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
    if not frame then return end

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
    if frame then return end

    frame = CreateFrame("Frame", "LariasWeeklyMidnightChecklistFrame", UIParent)
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
        local n = frame:GetName()
        if n and n ~= "" then
            local exists = false
            for i = 1, #UISpecialFrames do
                if UISpecialFrames[i] == n then
                    exists = true
                    break
                end
            end
            if not exists then
                tinsert(UISpecialFrames, n)
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
    listTab:SetText("List")
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
    optionsTab:SetText("Options")
    optionsTab:SetSize(120, 28)
    optionsTab:ClearAllPoints()
    optionsTab:SetPoint("LEFT", listTab, "RIGHT", 6, 0)
    StyleMainTabButton(optionsTab)
    optionsTab:SetScript("OnClick", function(selfBtn)
        Addon:SelectMainTab(selfBtn:GetID())
    end)

    frame._lariasTabList = listTab
    frame._lariasTabOptions = optionsTab

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

    local db = self:EnsureDB()

    local showGreatVaultCheck = CreateFrame("CheckButton", nil, optionsPanel, "UICheckButtonTemplate")
    showGreatVaultCheck:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 6, -6)
    do
        local textRegion = showGreatVaultCheck.text or showGreatVaultCheck.Text
        if textRegion then
            textRegion:SetText(L.OPTIONS_SHOW_GREAT_VAULT or "Show Great Vault")
            if textRegion.SetTextColor then
                textRegion:SetTextColor(Addon.THEME.text.r, Addon.THEME.text.g, Addon.THEME.text.b, Addon.THEME.text.a)
            end
        end
    end
    showGreatVaultCheck:SetChecked(db.showGreatVault and true or false)
    showGreatVaultCheck:SetScript("OnClick", function(selfBtn)
        local d = Addon:EnsureDB()
        d.showGreatVault = selfBtn:GetChecked() and true or false
        if Addon.RequestRefresh then
            Addon:RequestRefresh()
        else
            Addon:Refresh()
        end
    end)
    frame._lariasOptShowGreatVault = showGreatVaultCheck

    local showCurrencyCheck = CreateFrame("CheckButton", nil, optionsPanel, "UICheckButtonTemplate")
    showCurrencyCheck:SetPoint("TOPLEFT", showGreatVaultCheck, "BOTTOMLEFT", 0, -8)
    do
        local textRegion = showCurrencyCheck.text or showCurrencyCheck.Text
        if textRegion then
            textRegion:SetText(L.OPTIONS_SHOW_CURRENCY or "Show Currency")
            if textRegion.SetTextColor then
                textRegion:SetTextColor(Addon.THEME.text.r, Addon.THEME.text.g, Addon.THEME.text.b, Addon.THEME.text.a)
            end
        end
    end
    showCurrencyCheck:SetChecked(db.showCurrency and true or false)
    showCurrencyCheck:SetScript("OnClick", function(selfBtn)
        local d = Addon:EnsureDB()
        d.showCurrency = selfBtn:GetChecked() and true or false
        if Addon.RequestRefresh then
            Addon:RequestRefresh()
        else
            Addon:Refresh()
        end
    end)
    frame._lariasOptShowCurrency = showCurrencyCheck

    local hideCompletedCheck = CreateFrame("CheckButton", nil, optionsPanel, "UICheckButtonTemplate")
    hideCompletedCheck:SetPoint("TOPLEFT", showCurrencyCheck, "BOTTOMLEFT", 0, -8)
    do
        local textRegion = hideCompletedCheck.text or hideCompletedCheck.Text
        if textRegion then
            textRegion:SetText(L.HIDE_COMPLETED_WEEKS or "Hide Completed Weeks")
            if textRegion.SetTextColor then
                textRegion:SetTextColor(Addon.THEME.text.r, Addon.THEME.text.g, Addon.THEME.text.b, Addon.THEME.text.a)
            end
        end
    end
    hideCompletedCheck:SetChecked(db.hideCompletedSections and true or false)
    hideCompletedCheck:SetScript("OnClick", function(selfBtn)
        local d = Addon:EnsureDB()
        d.hideCompletedSections = selfBtn:GetChecked() and true or false
        if Addon.RequestRefresh then
            Addon:RequestRefresh()
        else
            Addon:Refresh()
        end
    end)
    frame._lariasOptHideCompleted = hideCompletedCheck

    local resetBtn = CreateFrame("Button", nil, optionsPanel, "GameMenuButtonTemplate")
    resetBtn:SetPoint("TOPLEFT", hideCompletedCheck, "BOTTOMLEFT", 0, -12)
    resetBtn:SetSize(120, 24)
    resetBtn:SetText(L.RESET_BUTTON or "Reset")
    resetBtn:SetScript("OnClick", function()
        local d = Addon:EnsureDB()
        if wipe then
            wipe(d.checked)
            wipe(d.collapsedSections)
        else
            d.checked = {}
            d.collapsedSections = {}
        end
        d.hideCompletedSections = true

        if Addon.SyncOptionsTabControls then
            Addon:SyncOptionsTabControls()
        end

        if Addon.RequestRefresh then
            Addon:RequestRefresh()
        else
            Addon:Refresh()
        end
    end)

    frame._lariasOptResetBtn = resetBtn

    local localeLabel = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    localeLabel:SetPoint("TOPLEFT", resetBtn, "BOTTOMLEFT", 0, -18)
    localeLabel:SetText(L.OPTIONS_LANGUAGE or "Language")
    localeLabel:SetTextColor(Addon.THEME.text.r, Addon.THEME.text.g, Addon.THEME.text.b, Addon.THEME.text.a)
    frame._lariasOptLocaleLabel = localeLabel

    if UIDropDownMenu_Initialize and UIDropDownMenu_CreateInfo and UIDropDownMenu_AddButton then
        local localeDropdown = CreateFrame("Frame", nil, optionsPanel, "UIDropDownMenuTemplate")
        localeDropdown:SetPoint("TOPLEFT", localeLabel, "BOTTOMLEFT", -16, -6)
        if UIDropDownMenu_SetWidth then UIDropDownMenu_SetWidth(localeDropdown, 190) end

        UIDropDownMenu_Initialize(localeDropdown, function(_, level)
            level = level or 1

            local d = Addon:EnsureDB()
            local current = tostring(d.localeOverride or "auto")

            local function AddItem(value, text)
                local info = UIDropDownMenu_CreateInfo()
                info.text = text
                info.value = value
                info.checked = (current == value)
                info.func = function()
                    Addon:SetLocaleOverride(value)
                end
                UIDropDownMenu_AddButton(info, level)
            end

            local autoText = (L.OPTIONS_LANGUAGE_AUTO or "Auto") .. " (" .. tostring((GetLocale and GetLocale()) or "enUS") .. ")"
            AddItem("auto", autoText)

            local codes = Addon:GetSupportedLocaleCodes()
            for i = 1, #codes do
                local code = codes[i]
                AddItem(code, Addon:GetLocaleDisplayName(code))
            end
        end)

        frame._lariasOptLocaleDropdown = localeDropdown
    end

    if (db.showGreatVault or db.showCurrency) and self.CreateTrackingPanel and not self._trackingFrame then
        self:CreateTrackingPanel(frame)
    end

    if self.UpdateLocalizedUI then
        self:UpdateLocalizedUI()
    end

    self:SelectMainTab(1)
end

function Addon:Toggle()
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

-- Register console commands using AceConsole
function Addon:RegisterConsoleCommands()
    self:RegisterChatCommand("larias", "ToggleCommand")
    self:RegisterChatCommand("lcl", "ToggleCommand")
end

function Addon:ToggleCommand(input)
    if input and input ~= "" then
        self:Print("Usage: /larias or /lcl to toggle the checklist")
    else
        self:Toggle()
    end
end
