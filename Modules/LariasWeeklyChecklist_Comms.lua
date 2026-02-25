-- Addon communications + update notice logic.
--
-- Message format:
-- - Structured tables serialized via AceSerializer and prefixed with "S:".
-- - t = message type ("Q" query, "V" version)
--
-- Performance:
-- - Broadcast/query/reply are throttled (timers) to avoid chat spam.
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

-- Trim helper for metadata/version parsing.
local function Trim(s)
    return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

-- Version handling notes:
-- - We only care about prompting updates for "live" releases.
-- - Remote prerelease versions (e.g. "1.0.18-alpha") are ignored for prompting.
-- - Numeric comparison is required (string compare breaks: "1.0.10" vs "1.0.2").
local function NormalizeVersionString(v)
    v = Trim(v)
    -- Drop any trailing metadata after whitespace (e.g., "1.0.0 (foo)").
    v = v:gsub("%s.*$", "")
    -- Common tag prefix.
    if v:match("^[vV]%d") then
        v = v:sub(2)
    end
    return v
end

local function StripBuildAndPrerelease(v)
    v = NormalizeVersionString(v)
    if v == "" then return "" end
    -- Ignore build metadata and prerelease suffixes for ordering.
    v = v:match("^([^+]+)") or v
    local main = v:match("^(.-)%-") or v
    return main
end

local function IsLiveVersion(v)
    v = NormalizeVersionString(v)
    if v == "" then return false end
    v = v:match("^([^+]+)") or v
    return not v:find("%-")
end

local function ParseVersionNumbers(v)
    local main = StripBuildAndPrerelease(v)
    if main == "" then return nil end
    local nums = {}
    for n in tostring(main):gmatch("%d+") do
        nums[#nums + 1] = tonumber(n) or 0
    end
    if #nums == 0 then return nil end
    return nums
end

local function CompareVersions(versionA, versionB)
    -- Compare only numeric components of the *live* versions.
    -- (Prereleases are filtered out earlier, and build metadata is ignored.)
    local aNums = ParseVersionNumbers(versionA)
    local bNums = ParseVersionNumbers(versionB)
    if not aNums and not bNums then return 0 end
    if not aNums then return -1 end
    if not bNums then return 1 end

    local maxLen = (#aNums > #bNums) and #aNums or #bNums
    for i = 1, maxLen do
        local av = aNums[i] or 0
        local bv = bNums[i] or 0
        if av ~= bv then
            return (av > bv) and 1 or -1
        end
    end
    return 0
end

local function SerializeCommMessage(tbl)
    -- Serialize a structured payload and prepend a small discriminator.
    -- Returns nil if serialization fails (or AceSerializer missing).
    if not (AceSerializer and AceSerializer.Serialize) then return nil end
    if type(tbl) ~= "table" then return nil end

    local ok, serialized = pcall(AceSerializer.Serialize, AceSerializer, tbl)
    if not ok or type(serialized) ~= "string" or serialized == "" then
        return nil
    end
    return COMM_SERIAL_PREFIX .. serialized
end

local function DeserializeCommMessage(message)
    -- Parse a structured payload produced by SerializeCommMessage.
    if type(message) ~= "string" then return nil end

    if message:sub(1, #COMM_SERIAL_PREFIX) == COMM_SERIAL_PREFIX and AceSerializer and AceSerializer.Deserialize then
        local payload = message:sub(#COMM_SERIAL_PREFIX + 1)
        local ok, success, decoded = pcall(AceSerializer.Deserialize, AceSerializer, payload)
        if ok and success and type(decoded) == "table" then
            return decoded
        end
    end
    return nil
end

local function SafeSendCommMessage(msg, channel)
    -- Guarded send: comms should never hard-error.
    if not channel or channel == "" then return end
    if Addon and Addon.SendCommMessage then
        pcall(Addon.SendCommMessage, Addon, Addon.COMM_PREFIX, msg, channel)
    end
end

local function GetGroupChannel()
    -- Prefer instance chat when applicable; otherwise raid/party.
    local instCat = (LE_PARTY_CATEGORY_INSTANCE ~= nil) and LE_PARTY_CATEGORY_INSTANCE or 2
    if IsInGroup and IsInGroup(instCat) then return "INSTANCE_CHAT" end
    if IsInRaid and IsInRaid() then return "RAID" end
    if IsInGroup and IsInGroup() then return "PARTY" end
    return nil
end

local function GetAddonVersion(name)
    -- Read version from addon metadata.
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        return tostring(C_AddOns.GetAddOnMetadata(name, "Version") or "")
    end
    if GetAddOnMetadata then
        return tostring(GetAddOnMetadata(name, "Version") or "")
    end
    return ""
end

function Addon:GetMyVersion()
    -- Cached in CommsOnEnable.
    return self._myVersion or ""
end

local function IsVersionNewer(versionA, versionB)
    return CompareVersions(versionA, versionB) > 0
end

function Addon:ShouldShowUpdateNotice()
    -- Update notice is driven by the newest *live* version seen on comms.
    local database = self:EnsureDB()
    local myVersion = self:GetMyVersion()
    -- If the user is on a prerelease build, don't nag about updates.
    if myVersion == "" or not IsLiveVersion(myVersion) then return false end
    local newestSeenVersion = tostring(database._newestSeenRemoteVersion or "")
    if newestSeenVersion == "" or myVersion == "" then return false end
    if not IsVersionNewer(newestSeenVersion, myVersion) then return false end
    if tostring(database._dismissedRemoteVersion or "") == newestSeenVersion then return false end
    return true
end

function Addon:DismissUpdateNotice()
    -- Remember the newest seen version as dismissed (until a newer one is seen).
    local database = self:EnsureDB()
    database._dismissedRemoteVersion = tostring(database._newestSeenRemoteVersion or "")
end

function Addon:EnsureUpdatePopup()
    -- Register the StaticPopup dialog once.
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
    -- Show at most once per window-open to avoid spam.
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
    -- Broadcast our version to group/guild.
    -- force=true bypasses the broadcast throttle.
    if not force then
        if broadcastTimerActive then
            return
        end
    end

    local myVersion = self:GetMyVersion()
    if myVersion == "" then return end
    local payloadStructured = SerializeCommMessage({ t = "V", v = myVersion })
    if not payloadStructured then return end

    local channel = GetGroupChannel()
    if channel then
        SafeSendCommMessage(payloadStructured, channel)
    end
    if IsInGuild and IsInGuild() then
        SafeSendCommMessage(payloadStructured, "GUILD")
    end

    if not force then
        broadcastTimerActive = true
        self:ScheduleTimer(function() broadcastTimerActive = false end, BROADCAST_THROTTLE_SECONDS)
    end
end

function Addon:RequestVersions(force)
    -- Ask others to reply with their version (they reply after a small random delay).
    if not force then
        if queryTimerActive then
            return
        end
    end

    local payloadStructured = SerializeCommMessage({ t = "Q" })
    if not payloadStructured then return end

    local channel = GetGroupChannel()
    if channel then
        SafeSendCommMessage(payloadStructured, channel)
    end
    if IsInGuild and IsInGuild() then
        SafeSendCommMessage(payloadStructured, "GUILD")
    end

    if not force then
        queryTimerActive = true
        self:ScheduleTimer(function() queryTimerActive = false end, BROADCAST_THROTTLE_SECONDS)
    end
end

function Addon:OnAddonMessage(prefix, message, sender)
    -- AceComm entry point (also used by OnCommReceived).
    -- We ignore non-structured messages to avoid legacy/backcompat complexity.
    if prefix ~= self.COMM_PREFIX then return end
    if type(message) ~= "string" then return end

    local decoded = DeserializeCommMessage(message)
    if not decoded then
        return
    end

    if decoded.t == "Q" then
        -- Query received: reply with version (throttled; delay jitter to avoid bursts).
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

    local remoteVersion = NormalizeVersionString(decoded.v)
    if remoteVersion == "" then return end

    -- Only consider live (non-prerelease) remote versions for update prompting.
    if not IsLiveVersion(remoteVersion) then
        return
    end

    local myVersion = self:GetMyVersion()
    if myVersion == "" then return end

    if sender and sender ~= "" and UnitName then
        -- Ignore our own messages ("player" name can be realm-qualified).
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
    -- AceComm callback signature includes an unused distribution parameter.
    self:OnAddonMessage(prefix, messageText, sender)
end

function Addon:CommsOnEnable()
    -- Called from Addon:OnEnable.
    self._myVersion = GetAddonVersion(addonName)

    -- Embed AceComm-3.0 now if it is available.  We defer this from NewAddon
    -- so a missing or overridden library does not crash the main chunk and
    -- break slash commands for everyone.
    local aceComm = LibStub and LibStub("AceComm-3.0", true)
    if aceComm and not self.RegisterComm then
        aceComm:Embed(self)
    end

    if self.RegisterComm then
        self:RegisterComm(self.COMM_PREFIX)
    end

    self:BroadcastVersion(true)
end
