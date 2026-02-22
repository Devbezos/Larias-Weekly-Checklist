local addonName = ...
local Addon = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceEvent-3.0", "AceHook-3.0", "AceConsole-3.0", "AceTimer-3.0")
_G[addonName] = Addon

-- Setup localization
if not Addon.L then
    local L = LibStub("AceLocale-3.0"):GetLocale(addonName, true)
    Addon.L = L
end
local L = Addon.L or {}

-- Initialize all constants on the new Addon object
do
    function Addon:InitConstants(name)
        name = name or addonName

        local L = self.L or {}

        -- Group core constants into objects (tables) while keeping legacy fields for compatibility.
        self.CONSTANTS = self.CONSTANTS or {}
        self.CONSTANTS.names = self.CONSTANTS.names or {}
        local names = self.CONSTANTS.names

        if names.displayName == nil then names.displayName = L.DISPLAY_NAME or name end
        if names.dbName == nil then names.dbName = "LariasWeeklyMidnightChecklistDBPC" end
        if names.accountDbName == nil then names.accountDbName = "LariasWeeklyMidnightChecklistDB" end
        if names.listDataKey == nil then names.listDataKey = (name .. "_LIST_DATA") end

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
            scrollTop = 44,
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
            local p = self.TRACKING.profiles[key]
            if type(p) ~= "table" then
                p = {}
                self.TRACKING.profiles[key] = p
            end
            p.questIDs = p.questIDs or {}
            return p
        end

        local tww = EnsureProfile("tww")
        if type(tww.crestCurrencyIDs) ~= "table" then
            tww.crestCurrencyIDs = {
                3284,
                3286,
                3288,
                3290,
            }
        end
        if type(tww.crestAchievementIDs) ~= "table" then
            tww.crestAchievementIDs = {
                41886,
                41887,
                41888,
                41892,
            }
        end
        if tww.sparkCurrencyID == nil then tww.sparkCurrencyID = 3141 end
        if tww.catalystCurrencyID == nil then tww.catalystCurrencyID = 3269 end
        if tww.crestTradeBatch == nil then tww.crestTradeBatch = { 45, 15 } end
        if tww.questIDs.delversBounty == nil then tww.questIDs.delversBounty = 86371 end
        if tww.questIDs.weeklyPrey == nil then tww.questIDs.weeklyPrey = 0 end

        local midnight = EnsureProfile("midnight")
        if type(midnight.crestCurrencyIDs) ~= "table" then
            midnight.crestCurrencyIDs = {
                3383,
                3341,
                3343,
                3345,
                3347,
            }
        end
        if type(midnight.crestAchievementIDs) ~= "table" then
            midnight.crestAchievementIDs = {
                61809,
                42767,
                72768,
                42769,
                42770,
            }
        end
        if midnight.sparkCurrencyID == nil then midnight.sparkCurrencyID = 0 end
        if midnight.catalystCurrencyID == nil then midnight.catalystCurrencyID = 0 end
        if midnight.crestTradeBatch == nil then midnight.crestTradeBatch = { 45, 15 } end
        if midnight.questIDs.delversBounty == nil then midnight.questIDs.delversBounty = 0 end
        if midnight.questIDs.weeklyPrey == nil then midnight.questIDs.weeklyPrey = 0 end
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
            hideCompletedSections = false,
            showGreatVault = true,
            showCurrency = true,
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
                Addon:Toggle()
            elseif button == "RightButton" then
                LibStub("AceConfigDialog-3.0"):Open(addonName)
            end
        end,
        OnTooltipShow = function(tooltip)
            if not tooltip then return end
            tooltip:AddLine(L.DISPLAY_NAME or addonName, 1, 0.82, 0)
            tooltip:AddLine("Left-click: Toggle checklist", 1, 1, 1)
            tooltip:AddLine("Right-click: Options", 1, 1, 1)
        end,
    })
    
    icon:Register(addonName, dataObject, Addon.db and Addon.db.profile or {})
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

local function IsVersionNewer(a, b)
    if a == b then return false end
    if a == "" then return false end
    if b == "" then return true end

    local function SplitNums(s)
        local out = {}
        for n in tostring(s):gmatch("%d+") do
            out[#out + 1] = tonumber(n) or 0
        end
        return out
    end

    local aParts = SplitNums(a)
    local bParts = SplitNums(b)
    local maxParts = max(#aParts, #bParts)
    for index = 1, maxParts do
        local aValue = aParts[index] or 0
        local bValue = bParts[index] or 0
        if aValue ~= bValue then
            return aValue > bValue
        end
    end

    return a > b
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
        self:BroadcastVersion(true)
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
    SetupMinimapIcon()
    EnsureMinimapIcon()
end

-- Handle player login event
function Addon:OnEnable()
    SafeRegisterPrefix(COMM_PREFIX)
    Addon._myVersion = GetAddonVersion(addonName)
    
    -- Register console commands
    self:RegisterConsoleCommands()
    
    -- Setup options panel with AceConfig
    self:SetupOptionsWithAceConfig()
    
    -- Register events using AceEvent
    self:RegisterEvent("CHAT_MSG_ADDON")
    
    -- Announce once on login so others can compare
    Addon:BroadcastVersion(true)
end

-- Handle chat message addon event
function Addon:CHAT_MSG_ADDON(_, prefix, messageText, _, _, sender)
    Addon:OnAddonMessage(prefix, messageText, sender)
end

local function Wipe(t)
    if not t then return end
    if wipe then
        wipe(t)
        return
    end
    for k in pairs(t) do
        t[k] = nil
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
    -- For backward compatibility, return the AceDB profile
    if self.db then
        return self.db.profile
    end
    return _G[self._DB_NAME]
end

local function CopyTableShallow(src)
    if type(src) ~= "table" then return {} end
    local dst = {}
    for k, v in pairs(src) do
        if type(v) == "table" then
            local child = {}
            for ck, cv in pairs(v) do
                child[ck] = cv
            end
            dst[k] = child
        else
            dst[k] = v
        end
    end
    return dst
end

function Addon:EnsureDB()
    -- Initialize AceDB if not already done
    if not self.db then
        SetupAddonDB()
    end
    
    -- Return the profile from AceDB for backward compatibility
    return self.db.profile
end

-- Set up AceConfig options
function Addon:SetupOptionsWithAceConfig()
    if self._optionsRegistered then return end
    self._optionsRegistered = true
    
    local ACR = LibStub("AceConfigRegistry-3.0")
    local ACD = LibStub("AceConfigDialog-3.0")
    
    local options = {
        name = L.DISPLAY_NAME or addonName,
        handler = self,
        type = "group",
        args = {
            general = {
                name = "General",
                type = "group",
                order = 1,
                args = {
                    showGreatVault = {
                        name = L.OPTIONS_SHOW_GREAT_VAULT or "Show Great Vault",
                        desc = "Display Great Vault tracking panel",
                        type = "toggle",
                        width = "full",
                        order = 1,
                        get = function() return self.db.profile.showGreatVault or false end,
                        set = function(info, value)
                            self.db.profile.showGreatVault = value
                            if self.UpdateTracking then self:UpdateTracking() end
                            self:ApplyScrollLayout()
                            self:Refresh()
                        end,
                    },
                    showCurrency = {
                        name = L.OPTIONS_SHOW_CURRENCY or "Show Currency",
                        desc = "Display currency tracking panel",
                        type = "toggle",
                        width = "full",
                        order = 2,
                        get = function() return self.db.profile.showCurrency or false end,
                        set = function(info, value)
                            self.db.profile.showCurrency = value
                            if self.UpdateTracking then self:UpdateTracking() end
                            self:ApplyScrollLayout()
                            self:Refresh()
                        end,
                    },
                    hideCompletedSections = {
                        name = L.HIDE_COMPLETED_WEEKS or "Hide Completed Weeks",
                        desc = "Hide weeks that are marked as complete",
                        type = "toggle",
                        width = "full",
                        order = 3,
                        get = function() return self.db.profile.hideCompletedSections or false end,
                        set = function(info, value)
                            self.db.profile.hideCompletedSections = value
                            self:Refresh()
                        end,
                    },
                },
            },
        },
    }
    
    ACR:RegisterOptionsTable(addonName, options)
    ACD:AddToBlizOptions(addonName, L.DISPLAY_NAME or addonName)
end

-- Legacy options panel method for compatibility
function Addon:EnsureOptionsPanel()
    self:SetupOptionsWithAceConfig()
    return nil
end

function Addon:OpenOptions()
    LibStub("AceConfigDialog-3.0"):Open(addonName)
end

function Addon:GetListData()
    local data = _G[self._LIST_DATA_KEY]
    if type(data) == "table" then return data end
    return {}
end

function Addon:ApplyTheme(f)
    if not f or not f.SetBackdrop then return end
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        edgeSize = 1,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(Addon.THEME.bg.r, Addon.THEME.bg.g, Addon.THEME.bg.b, Addon.THEME.bg.a)
    f:SetBackdropBorderColor(Addon.THEME.border.r, Addon.THEME.border.g, Addon.THEME.border.b, Addon.THEME.border.a)
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
    local sf = tremove(Addon._sectionPool)
    if sf then
        sf:Show()
        return sf
    end

    sf = CreateFrame("Frame", nil, scrollChild)
    sf:SetWidth(1)
    sf._checkboxes = {}

    local header = CreateFrame("Button", nil, sf)
    header:SetPoint("TOPLEFT", sf, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", sf, "TOPRIGHT", 0, 0)
    header:SetHeight(Addon.UI.headerMinH)
    sf._header = header

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", header, "LEFT", 0, 0)
    title:SetTextColor(Addon.THEME.header.r, Addon.THEME.header.g, Addon.THEME.header.b, Addon.THEME.header.a)
    title:SetJustifyH("LEFT")
    if title.SetWordWrap then title:SetWordWrap(true) end
    sf._title = title

    local status = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    status:SetPoint("RIGHT", header, "RIGHT", 0, 0)
    status:SetTextColor(Addon.THEME.textDim.r, Addon.THEME.textDim.g, Addon.THEME.textDim.b, Addon.THEME.textDim.a)
    sf._status = status

    return sf
end

local function ReleaseSectionFrame(sf)
    if not sf then return end
    sf:Hide()
    sf:ClearAllPoints()
    sf._sectionId = nil
    sf._index = nil

    if sf._checkboxes then
        for i = #sf._checkboxes, 1, -1 do
            local cb = sf._checkboxes[i]
            cb:Hide()
            cb:ClearAllPoints()
            cb._sectionId = nil
            cb._itemId = nil
            cb._dbKey = nil
            cb:SetScript("OnClick", nil)
            tinsert(Addon._checkboxPool, cb)
            sf._checkboxes[i] = nil
        end
    end

    sf._header:SetScript("OnClick", nil)
    tinsert(Addon._sectionPool, sf)
end

local function AcquireCheckbox(sf)
    local cb = tremove(Addon._checkboxPool)
    if cb then
        cb:SetParent(sf)
        cb:Show()
        return cb
    end

    cb = CreateFrame("CheckButton", nil, sf, "UICheckButtonTemplate")
    local txt = cb.text or cb.Text
    if txt then
        txt:SetJustifyH("LEFT")
        if txt.SetWordWrap then txt:SetWordWrap(true) end
        if txt.SetTextColor then
            txt:SetTextColor(Addon.THEME.text.r, Addon.THEME.text.g, Addon.THEME.text.b, Addon.THEME.text.a)
        end
    end
    return cb
end
local UpdateSectionVisuals

local function ComputeHeaderHeight(sf, headerTextWidth)
    sf._title:SetWidth(headerTextWidth)
    local th = 0
    if sf._title.GetStringHeight then
        th = sf._title:GetStringHeight() or 0
    end
    local hh = max(Addon.UI.headerMinH, th + 6)
    sf._header:SetHeight(hh)
    sf._headerBlockHeight = hh + Addon.UI.headerBottomPad
end

local function LayoutItems(sf, collapsed)
    local y = -(sf._headerBlockHeight or (Addon.UI.headerMinH + Addon.UI.headerBottomPad))
    local total = 0
    local boxes = sf._checkboxes
    for i = 1, #boxes do
        local cb = boxes[i]
        cb:ClearAllPoints()
        cb:SetPoint("TOPLEFT", sf, "TOPLEFT", 0, y)
        local rh = cb:GetHeight() or Addon.UI.itemMinH
        y = y - rh
        total = total + rh
        cb:SetShown(not collapsed)
    end
    sf._itemsHeight = total
end

local function UpdateSectionHeight(sf, collapsed)
    local h = (sf._headerBlockHeight or (Addon.UI.headerMinH + Addon.UI.headerBottomPad))
    if not collapsed then
        h = h + (sf._itemsHeight or 0)
    end
    sf:SetHeight(h)
end

local function LayoutFrom(startIndex)
    local y = -Addon.UI.sectionTopPad
    local paddingX = Addon.UI.sectionInsetX

    for i = 1, #Addon._activeSections do
        local sf = Addon._activeSections[i]
        if sf:IsShown() then
            if i < startIndex then
                y = y - sf:GetHeight() - Addon.UI.sectionGap
            else
                sf:ClearAllPoints()
                sf:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", paddingX, y)
                sf:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -paddingX, y)
                y = y - sf:GetHeight() - Addon.UI.sectionGap
            end
        end
    end

    local height = max(1, -y + Addon.UI.sectionGap)
    scrollChild:SetHeight(height)
end

local function CalcDataSig(data)
    if type(data) ~= "table" then return "" end
    if data.__lariasSig and data.__lariasSigN == #data then
        return data.__lariasSig
    end
    local parts = {}
    parts[#parts + 1] = tostring(#data)
    for i = 1, #data do
        local s = data[i]
        parts[#parts + 1] = tostring(s.id)
        local items = s.items or {}
        parts[#parts + 1] = tostring(#items)
        for j = 1, #items do
            parts[#parts + 1] = tostring(items[j].id)
        end
    end
    local sig = tconcat(parts, "|")
    data.__lariasSig = sig
    data.__lariasSigN = #data
    return sig
end

local function SetHeaderText(sf, sectionId, complete)
    local section = Addon._sectionsById[sectionId]
    if complete == nil then
        complete = IsSectionCompleteById(sectionId)
    end
    local titleText = tostring((section and section.title) or sectionId)
    if complete then titleText = (L.DONE_PREFIX or "") .. titleText end
    sf._title:SetText(titleText)
    sf._status:SetText("")
end

local function OnCheckboxClick(selfBtn)
    local db = Addon:EnsureDB()
    local checked = selfBtn:GetChecked() and true or nil
    db.checked[selfBtn._dbKey or Key(selfBtn._sectionId, selfBtn._itemId)] = checked

    local sid = selfBtn._sectionId
    local secCompleteNow = IsSectionCompleteById(sid, db)
    if secCompleteNow then
        SetSectionCollapsed(sid, true, db)
    end

    local sframe = Addon._activeSections[Addon._sectionsIndexById[sid]]
    if not sframe then return end

    local hideDone = db.hideCompletedSections and true or false

    SetHeaderText(sframe, sid, secCompleteNow)
    ComputeHeaderHeight(sframe, Addon.UI.itemTextWidth + Addon.UI.headerTextExtraW)

    local collapsed = IsSectionCollapsed(sid, db) or false
    if secCompleteNow then collapsed = true end

    LayoutItems(sframe, collapsed)
    UpdateSectionHeight(sframe, collapsed)

    if hideDone and secCompleteNow then
        sframe:Hide()
    else
        sframe:Show()
    end

    LayoutFrom(sframe._index or 1)
end

local function OnHeaderClick(header)
    local sf = header and header._sectionFrame
    if not sf then return end
    local sid = sf._sectionId
    SetSectionCollapsed(sid, not IsSectionCollapsed(sid))
    if UpdateSectionVisuals then
        UpdateSectionVisuals(sf, sid)
    end
    LayoutFrom(sf._index or 1)
end

local function SyncCheckboxesForSection(sf, sectionId, db)
    local section = Addon._sectionsById[sectionId]
    local items = (section and section.items) or {}

    local want = #items
    local have = #sf._checkboxes

    if have > want then
        for i = have, want + 1, -1 do
            local cb = sf._checkboxes[i]
            cb:Hide()
            cb:ClearAllPoints()
            cb._sectionId = nil
            cb._itemId = nil
            cb:SetScript("OnClick", nil)
            tinsert(Addon._checkboxPool, cb)
            sf._checkboxes[i] = nil
        end
    elseif have < want then
        for i = have + 1, want do
            sf._checkboxes[i] = AcquireCheckbox(sf)
        end
    end

    for i = 1, want do
        local item = items[i]
        local cb = sf._checkboxes[i]

        cb._sectionId = sectionId
        cb._itemId = item.id
        cb._dbKey = Key(sectionId, item.id)

        local txt = cb.text or cb.Text
        local minRowH = max(32, Addon.UI.itemMinH or 0)
        if txt then
            txt:SetWidth(Addon.UI.itemTextWidth)
            txt:SetText(tostring(item.text or item.id))

            local textHeight = 0
            if txt.GetStringHeight then
                textHeight = txt:GetStringHeight() or 0
            end
            cb:SetHeight(max(minRowH, textHeight + (Addon.UI.itemTextPad or 0)))
        else
            cb:SetHeight(minRowH)
        end

        cb:SetChecked(IsItemChecked(sectionId, item.id, db))

        cb:SetScript("OnClick", OnCheckboxClick)
    end
end

UpdateSectionVisuals = function(sf, sectionId)
    local db = Addon:EnsureDB()
    local complete = IsSectionCompleteById(sectionId, db)

    local hideDone = db.hideCompletedSections and true or false
    if hideDone and complete then
        sf:Hide()
        return
    end

    sf:Show()

    if complete then
        SetSectionCollapsed(sectionId, true, db)
    end

    SetHeaderText(sf, sectionId, complete)
    ComputeHeaderHeight(sf, Addon.UI.itemTextWidth + Addon.UI.headerTextExtraW)

    local collapsed = IsSectionCollapsed(sectionId, db) or false
    if complete then collapsed = true end

    for i = 1, #sf._checkboxes do
        local cb = sf._checkboxes[i]
        if cb and cb._itemId ~= nil then
            cb:SetChecked(IsItemChecked(sectionId, cb._itemId, db))
        end
    end

    LayoutItems(sf, collapsed)
    UpdateSectionHeight(sf, collapsed)
end

local function SyncAllDataAndFrames()
    local db = Addon:EnsureDB()

    local data = Addon:GetListData()
    local sig = CalcDataSig(data)

    if Addon._dataSig ~= sig or not Addon._sectionsById or not next(Addon._sectionsById) then
        Addon._sectionsById = {}
        Addon._order = {}
        for i = 1, #data do
            local s = data[i]
            Addon._sectionsById[s.id] = s
            Addon._order[i] = s.id
        end

        for i = #Addon._activeSections, 1, -1 do
            ReleaseSectionFrame(Addon._activeSections[i])
            Addon._activeSections[i] = nil
        end
        Addon._dataSig = sig
    end

    Wipe(Addon._sectionsIndexById)

    local want = #Addon._order
    local have = #Addon._activeSections

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

    for i = 1, want do
        local sectionId = Addon._order[i]
        local sf = Addon._activeSections[i]
        sf:SetParent(scrollChild)
        sf._sectionId = sectionId
        sf._index = i
        Addon._sectionsIndexById[sectionId] = i

        SyncCheckboxesForSection(sf, sectionId, db)

        sf._header._sectionFrame = sf
        sf._header:SetScript("OnClick", OnHeaderClick)

        UpdateSectionVisuals(sf, sectionId)

    end
end

function Addon:Refresh()
    if not frame then return end
    SyncAllDataAndFrames()

    local y = -Addon.UI.sectionTopPad
    local paddingX = Addon.UI.sectionInsetX

    for i = 1, #self._activeSections do
        local sf = self._activeSections[i]
        if sf:IsShown() then
            sf:ClearAllPoints()
            sf:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", paddingX, y)
            sf:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -paddingX, y)
            y = y - sf:GetHeight() - Addon.UI.sectionGap
        end
    end

    scrollChild:SetHeight(max(1, -y + Addon.UI.sectionGap))

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

    local topRow = CreateFrame("Frame", nil, frame)
    topRow:SetPoint("TOPLEFT", frame, "TOPLEFT", Addon.UI.padOuterX, -Addon.UI.padOuterTop)
    topRow:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -Addon.UI.topRowRightInset, -Addon.UI.padOuterTop)
    topRow:SetHeight(Addon.UI.topRowH)

    local hideDoneCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    hideDoneCheck:SetPoint("LEFT", topRow, "LEFT", Addon.UI.padOuterX, 0)
    local htxt = hideDoneCheck.text or hideDoneCheck.Text
    if htxt then
        htxt:SetText(L.HIDE_COMPLETED_WEEKS or "")
        if htxt.SetTextColor then
            htxt:SetTextColor(Addon.THEME.text.r, Addon.THEME.text.g, Addon.THEME.text.b, Addon.THEME.text.a)
        end
    end

    local db = self:EnsureDB()
    hideDoneCheck:SetChecked(db.hideCompletedSections)
    hideDoneCheck:SetScript("OnClick", function(selfBtn)
        local d = Addon:EnsureDB()
        d.hideCompletedSections = selfBtn:GetChecked() and true or false
        Addon:Refresh()
    end)

    local optionsBtn = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    optionsBtn:SetPoint("RIGHT", topRow, "RIGHT", 0, 0)
    optionsBtn:SetSize(90, Addon.UI.topRowH)
    optionsBtn:SetText(L.OPTIONS_BUTTON or "")
    optionsBtn:SetScript("OnClick", function()
        Addon:OpenOptions()
    end)

    local resetBtn = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    resetBtn:SetPoint("RIGHT", optionsBtn, "LEFT", -8, 0)
    resetBtn:SetSize(90, Addon.UI.topRowH)
    resetBtn:SetText(L.RESET_BUTTON or "")
    resetBtn:SetScript("OnClick", function()
        local d = Addon:EnsureDB()
        if wipe then
            wipe(d.checked)
            wipe(d.collapsedSections)
        else
            d.checked = {}
            d.collapsedSections = {}
        end
        d.hideCompletedSections = false
        hideDoneCheck:SetChecked(false)

        Addon:ApplyScrollLayout()
        Addon:Refresh()
    end)

    scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", Addon.UI.padOuterX, -Addon.UI.scrollTop)

    scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(1, 1)
    scrollFrame:SetScrollChild(scrollChild)

    if (db.showGreatVault or db.showCurrency) and self.CreateTrackingPanel and not self._trackingFrame then
        self:CreateTrackingPanel(frame)
    end

    self:ApplyScrollLayout()
    self:Refresh()
end

function Addon:Toggle()
    self:CreateFrame()
    if frame:IsShown() then
        frame:Hide()
    else
        self._updatePopupShownThisOpen = nil
        self:BroadcastVersion(false)
        self:RequestVersions(false)
        self:ApplyScrollLayout()
        self:Refresh()
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
        -- Handle subcommands if needed in the future
        self:Print("Usage: /larias or /lcl to toggle the checklist")
    else
        self:Toggle()
    end
end
