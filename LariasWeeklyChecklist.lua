local addonName = ...
local Addon = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceEvent-3.0", "AceHook-3.0", "AceConsole-3.0", "AceTimer-3.0")
_G[addonName] = Addon

local LOCALE_REGISTRY_KEY = "LARIASWEEKLYCHECKLIST_LOCALE_REGISTRY"

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
    function Addon:InitConstants(addonNameInput)
        addonNameInput = addonNameInput or addonName

        local locale = self.L or {}

        -- Group core constants into objects (tables) while keeping legacy fields for compatibility.
        self.CONSTANTS = self.CONSTANTS or {}
        self.CONSTANTS.names = self.CONSTANTS.names or {}
        local names = self.CONSTANTS.names

        if names.displayName == nil then names.displayName = locale.DISPLAY_NAME or addonNameInput end
        if names.dbName == nil then names.dbName = "LariasWeeklyChecklistDBPC" end
        if names.accountDbName == nil then names.accountDbName = "LariasWeeklyChecklistDB" end
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
local aceHost
local AceGUI
local aceTabGroup
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
                local mainFrame = _G["LariasWeeklyChecklistFrame"]
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
            tooltip:AddLine(L.MINIMAP_TOOLTIP_LEFT_CLICK_TOGGLE or "", 1, 1, 1)
            tooltip:AddLine(L.MINIMAP_TOOLTIP_RIGHT_CLICK_OPTIONS or "", 1, 1, 1)
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

    StaticPopupDialogs["LARIASWEEKLYCHECKLIST_UPDATE"] = {
        text = "%s",
        button1 = (OKAY or (L.BUTTON_OK or "")),
        button2 = (CANCEL or (L.BUTTON_CANCEL or "")),
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
        popupText = (L.UPDATE_AVAILABLE_TEXT or L.UPDATE_AVAILABLE_TITLE or "")
    end

    StaticPopup_Show("LARIASWEEKLYCHECKLIST_UPDATE", popupText)
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

local LOCALE_NAME_KEYS = {
    enUS = "LOCALE_NAME_ENUS",
    frFR = "LOCALE_NAME_FRFR",
    esES = "LOCALE_NAME_ESES",
    esMX = "LOCALE_NAME_ESMX",
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
    local key = LOCALE_NAME_KEYS[code]
    local pretty = (key and L[key]) or code
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

    if aceTabGroup then
        aceTabGroup:SelectTab((tabId == 2) and "options" or "list")
    end

    -- Keep tracking panel aligned with List-only behavior.
    if self.ApplyTrackingPanelOptions then
        self:ApplyTrackingPanelOptions()
    end

    if tabId == 1 then
        if self.RequestRefresh then self:RequestRefresh() end
    else
        if self.ApplyScrollLayout then self:ApplyScrollLayout() end
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

    if aceTabGroup then
        aceTabGroup:SetTabs({
            { text = L.TAB_LIST or "", value = "list" },
            { text = L.TAB_OPTIONS or "", value = "options" },
        })
    end

    if self.RequestRefresh then
        self:RequestRefresh()
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
    if not (frame and aceHost) then return end
    aceHost:ClearAllPoints()
    aceHost:SetPoint("TOPLEFT", frame, "TOPLEFT", Addon.UI.padOuterX, -Addon.UI.scrollTop)

    aceHost:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -Addon.UI.scrollRight, Addon.UI.scrollBottom)

    if aceTabGroup and aceTabGroup.frame and aceTabGroup.frame.SetAllPoints then
        aceTabGroup.frame:ClearAllPoints()
        aceTabGroup.frame:SetAllPoints(aceHost)
    end
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

local function IsSectionComplete(section, db)
    if type(section) ~= "table" then return false end
    local sectionId = section.id
    if not sectionId then return false end
    db = db or Addon:EnsureDB()
    local items = section.items or {}
    for i = 1, #items do
        local item = items[i]
        local itemId = type(item) == "table" and item.id or item
        if itemId and not db.checked[Key(sectionId, itemId)] then
            return false
        end
    end
    return true
end

local AceGUI
function Addon:GetAceGUI()
    if AceGUI ~= nil then return AceGUI end
    if LibStub then
        AceGUI = LibStub("AceGUI-3.0", true)
    end
    return AceGUI
end

function Addon:_AceRenderList(container)
    local ace = self:GetAceGUI()
    if not ace then return end

    container:SetLayout("Fill")

    local scroll = ace:Create("ScrollFrame")
    scroll:SetLayout("List")
    container:AddChild(scroll)

    if self.AceRenderTracking then
        self:AceRenderTracking(scroll)
    end

    local db = self:EnsureDB()
    local data = self:GetListData() or {}

    for i = 1, #data do
        local section = data[i]
        if type(section) == "table" then
            local sectionId = tostring(section.id or i)
            local complete = IsSectionComplete(section, db)

            if not (db.hideCompletedSections and complete) then
                local collapsed = complete or IsSectionCollapsed(sectionId, db)
                local titleText = tostring(section.title or sectionId)
                if complete then
                    titleText = (L.DONE_PREFIX or "") .. titleText
                end

                local headerBtn = ace:Create("Button")
                headerBtn:SetFullWidth(true)
                headerBtn:SetText(((collapsed and "+ ") or "- ") .. titleText)
                headerBtn:SetCallback("OnClick", function()
                    SetSectionCollapsed(sectionId, not collapsed, db)
                    Addon:RequestRefresh()
                end)
                scroll:AddChild(headerBtn)

                if not collapsed then
                    local items = section.items or {}
                    for j = 1, #items do
                        local item = items[j]
                        local itemId = type(item) == "table" and (item.id or j) or item
                        itemId = tostring(itemId)
                        local label = type(item) == "table" and item.text or itemId

                        local check = ace:Create("CheckBox")
                        check:SetFullWidth(true)
                        check:SetLabel(tostring(label or itemId))
                        check:SetValue(IsItemChecked(sectionId, itemId, db))
                        check:SetCallback("OnValueChanged", function(_, _, val)
                            SetItemChecked(sectionId, itemId, val and true or false, db)
                            if val and IsSectionComplete(section, db) then
                                SetSectionCollapsed(sectionId, true, db)
                            end
                            Addon:RequestRefresh()
                        end)
                        scroll:AddChild(check)
                    end
                end

                local spacer = ace:Create("Label")
                spacer:SetFullWidth(true)
                spacer:SetText(" ")
                scroll:AddChild(spacer)
            end
        end
    end
end

function Addon:_AceRenderOptions(container)
    if not container then return end

    local dialog = LibStub and LibStub("AceConfigDialog-3.0", true)
    local registry = LibStub and LibStub("AceConfigRegistry-3.0", true)
    if not (dialog and registry) then return end

    if not self._aceOptionsRegistered then
        local function HasOtherLocales()
            local codes = Addon.GetSupportedLocaleCodes and Addon:GetSupportedLocaleCodes() or {}
            for i = 1, #codes do
                if codes[i] ~= "enUS" then return true end
            end
            return false
        end

        local function LocaleValues()
            local codes = Addon.GetSupportedLocaleCodes and Addon:GetSupportedLocaleCodes() or {}
            local list = {}
            list.auto = (L.OPTIONS_LANGUAGE_AUTO or "") .. " (" .. tostring((GetLocale and GetLocale()) or "enUS") .. ")"
            for i = 1, #codes do
                local code = tostring(codes[i])
                list[code] = Addon:GetLocaleDisplayName(code)
            end
            return list
        end

        local options = {
            type = "group",
            name = L.TAB_OPTIONS or "",
            args = {
                showGreatVault = {
                    type = "toggle",
                    name = L.OPTIONS_SHOW_GREAT_VAULT or "",
                    order = 10,
                    get = function() return Addon:EnsureDB().showGreatVault and true or false end,
                    set = function(_, val)
                        local db = Addon:EnsureDB()
                        db.showGreatVault = val and true or false
                        if Addon.ApplyTrackingPanelOptions then Addon:ApplyTrackingPanelOptions() end
                        Addon:RequestRefresh()
                    end,
                },
                showCurrency = {
                    type = "toggle",
                    name = L.OPTIONS_SHOW_CURRENCY or "",
                    order = 20,
                    get = function() return Addon:EnsureDB().showCurrency and true or false end,
                    set = function(_, val)
                        local db = Addon:EnsureDB()
                        db.showCurrency = val and true or false
                        if Addon.ApplyTrackingPanelOptions then Addon:ApplyTrackingPanelOptions() end
                        Addon:RequestRefresh()
                    end,
                },
                hideCompleted = {
                    type = "toggle",
                    name = L.HIDE_COMPLETED_WEEKS or "",
                    order = 30,
                    get = function() return Addon:EnsureDB().hideCompletedSections and true or false end,
                    set = function(_, val)
                        Addon:EnsureDB().hideCompletedSections = val and true or false
                        Addon:RequestRefresh()
                    end,
                },
                reset = {
                    type = "execute",
                    name = L.RESET_BUTTON or "",
                    order = 40,
                    func = function()
                        local db = Addon:EnsureDB()
                        if wipe then
                            wipe(db.checked)
                            wipe(db.collapsedSections)
                        else
                            db.checked = {}
                            db.collapsedSections = {}
                        end
                        db.hideCompletedSections = true
                        Addon:RequestRefresh()
                    end,
                },
                language = {
                    type = "select",
                    name = L.OPTIONS_LANGUAGE or "",
                    order = 50,
                    values = LocaleValues,
                    hidden = function() return not HasOtherLocales() end,
                    get = function()
                        return tostring((Addon:EnsureDB().localeOverride) or "auto")
                    end,
                    set = function(_, val)
                        Addon:SetLocaleOverride(val)
                    end,
                },
            },
        }

        registry:RegisterOptionsTable(addonName, options)
        self._aceOptionsRegistered = true
    end

    container:SetLayout("Fill")
    dialog:Open(addonName, container)
end

local function AceOnGroupSelected(widget, _, group)
    widget:ReleaseChildren()

    if group == "options" then
        if frame then frame._lariasSelectedTab = 2 end
        Addon:_AceRenderOptions(widget)
    else
        if frame then frame._lariasSelectedTab = 1 end
        Addon:_AceRenderList(widget)
    end

    if Addon.ApplyTrackingPanelOptions then
        Addon:ApplyTrackingPanelOptions()
    end

    if Addon.ApplyScrollLayout then
        Addon:ApplyScrollLayout()
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
    if self.ApplyScrollLayout then self:ApplyScrollLayout() end

    if aceTabGroup and aceTabGroup.frame then
        -- Force a rebuild of the currently selected tab UI.
        local selected = tonumber(frame._lariasSelectedTab) or 1
        if selected == 2 then
            aceTabGroup:SelectTab("options")
        else
            aceTabGroup:SelectTab("list")
        end
    end
end

function Addon:CreateFrame()
    if frame then return end

    frame = CreateFrame("Frame", "LariasWeeklyChecklistFrame", UIParent)
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

    -- Host frame for AceGUI widgets.
    aceHost = CreateFrame("Frame", nil, frame)

    local ace = self:GetAceGUI()
    if not ace then
        -- If AceGUI isn't available for some reason, keep the window closable but avoid errors.
        frame._lariasSelectedTab = 1
        return
    end

    aceTabGroup = ace:Create("TabGroup")
    aceTabGroup:SetLayout("Flow")
    aceTabGroup:SetTabs({
        { text = L.TAB_LIST or "", value = "list" },
        { text = L.TAB_OPTIONS or "", value = "options" },
    })
    aceTabGroup:SetCallback("OnGroupSelected", AceOnGroupSelected)
    aceTabGroup.frame:SetParent(aceHost)

    frame._lariasSelectedTab = 1

    if self.UpdateLocalizedUI then self:UpdateLocalizedUI() end
    if self.ApplyScrollLayout then self:ApplyScrollLayout() end

    aceTabGroup:SelectTab("list")
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
        self:Print(L.SLASH_USAGE_TOGGLE or "")
    else
        self:Toggle()
    end
end
