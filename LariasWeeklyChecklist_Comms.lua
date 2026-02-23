local addonName = ...
local Addon = _G[addonName]
if not Addon then return end

Addon.COMM_PREFIX = Addon.COMM_PREFIX or "LWMC"

local BROADCAST_THROTTLE_SECONDS = 30
local REPLY_THROTTLE_SECONDS = 5

local AceSerializer = LibStub and LibStub("AceSerializer-3.0", true)
local COMM_SERIAL_PREFIX = "S:"

local broadcastTimerActive = false
local replyTimerActive = false
local queryTimerActive = false

local function Trim(s)
    return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function SerializeCommMessage(tbl)
    if not (AceSerializer and AceSerializer.Serialize) then return nil end
    if type(tbl) ~= "table" then return nil end

    local ok, serialized = pcall(AceSerializer.Serialize, AceSerializer, tbl)
    if not ok or type(serialized) ~= "string" or serialized == "" then
        return nil
    end
    return COMM_SERIAL_PREFIX .. serialized
end

local function DeserializeCommMessage(message)
    if type(message) ~= "string" then return nil end

    if message:sub(1, #COMM_SERIAL_PREFIX) == COMM_SERIAL_PREFIX and AceSerializer and AceSerializer.Deserialize then
        local payload = message:sub(#COMM_SERIAL_PREFIX + 1)
        local ok, success, decoded = pcall(AceSerializer.Deserialize, AceSerializer, payload)
        if ok and success and type(decoded) == "table" then
            return decoded
        end
    end

    -- Back-compat with old wire format.
    if message == "Q" then
        return { t = "Q" }
    end
    if message:sub(1, 2) == "V:" then
        local v = Trim(message:sub(3))
        if v ~= "" then
            return { t = "V", v = v }
        end
    end

    return nil
end

local function SafeSendCommMessage(msg, channel)
    if not channel or channel == "" then return end
    if Addon and Addon.SendCommMessage then
        pcall(Addon.SendCommMessage, Addon, Addon.COMM_PREFIX, msg, channel)
    end
end

local function GetGroupChannel()
    local instCat = (LE_PARTY_CATEGORY_INSTANCE ~= nil) and LE_PARTY_CATEGORY_INSTANCE or 2
    if IsInGroup and IsInGroup(instCat) then return "INSTANCE_CHAT" end
    if IsInRaid and IsInRaid() then return "RAID" end
    if IsInGroup and IsInGroup() then return "PARTY" end
    return nil
end

local function GetAddonVersion(name)
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        return tostring(C_AddOns.GetAddOnMetadata(name, "Version") or "")
    end
    if GetAddOnMetadata then
        return tostring(GetAddOnMetadata(name, "Version") or "")
    end
    return ""
end

function Addon:GetMyVersion()
    return self._myVersion or ""
end

local function IsVersionNewer(versionA, versionB)
    versionA = Trim(versionA)
    versionB = Trim(versionB)
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

    local L = self.L or {}

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

    local L = self.L or {}

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

function Addon:BroadcastVersion(force)
    if not force then
        if broadcastTimerActive then
            return
        end
    end

    local myVersion = self:GetMyVersion()
    if myVersion == "" then return end

    local payloadLegacy = "V:" .. myVersion
    local payloadStructured = SerializeCommMessage({ t = "V", v = myVersion })

    local channel = GetGroupChannel()
    if channel then
        SafeSendCommMessage(payloadLegacy, channel)
        if payloadStructured then
            SafeSendCommMessage(payloadStructured, channel)
        end
    end
    if IsInGuild and IsInGuild() then
        SafeSendCommMessage(payloadLegacy, "GUILD")
        if payloadStructured then
            SafeSendCommMessage(payloadStructured, "GUILD")
        end
    end

    if not force then
        broadcastTimerActive = true
        self:ScheduleTimer(function() broadcastTimerActive = false end, BROADCAST_THROTTLE_SECONDS)
    end
end

function Addon:RequestVersions(force)
    if not force then
        if queryTimerActive then
            return
        end
    end

    local payloadLegacy = "Q"
    local payloadStructured = SerializeCommMessage({ t = "Q" })

    local channel = GetGroupChannel()
    if channel then
        SafeSendCommMessage(payloadLegacy, channel)
        if payloadStructured then
            SafeSendCommMessage(payloadStructured, channel)
        end
    end
    if IsInGuild and IsInGuild() then
        SafeSendCommMessage(payloadLegacy, "GUILD")
        if payloadStructured then
            SafeSendCommMessage(payloadStructured, "GUILD")
        end
    end

    if not force then
        queryTimerActive = true
        self:ScheduleTimer(function() queryTimerActive = false end, BROADCAST_THROTTLE_SECONDS)
    end
end

function Addon:OnAddonMessage(prefix, message, sender)
    if prefix ~= self.COMM_PREFIX then return end
    if type(message) ~= "string" then return end

    local decoded = DeserializeCommMessage(message)
    if not decoded then
        return
    end

    if decoded.t == "Q" then
        if replyTimerActive then
            return
        end

        replyTimerActive = true
        self:ScheduleTimer(function() replyTimerActive = false end, REPLY_THROTTLE_SECONDS)

        local delay = (math.random() * 2.0)
        self:ScheduleTimer(function()
            self:BroadcastVersion(true)
        end, delay)
        return
    end

    if decoded.t ~= "V" then
        return
    end

    local remoteVersion = Trim(decoded.v)
    if remoteVersion == "" then return end

    local myVersion = self:GetMyVersion()
    if myVersion == "" then return end

    if sender and sender ~= "" and UnitName then
        local me = UnitName("player")
        if me and me ~= "" then
            local senderName = sender
            if Ambiguate then
                senderName = Ambiguate(sender, "none")
            end
            if senderName == me then
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

function Addon:OnCommReceived(prefix, messageText, _, sender)
    self:OnAddonMessage(prefix, messageText, sender)
end

function Addon:CommsOnEnable()
    self._myVersion = GetAddonVersion(addonName)

    if self.RegisterComm then
        self:RegisterComm(self.COMM_PREFIX)
    end

    self:BroadcastVersion(true)
end
