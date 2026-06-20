-- LariasWeeklyChecklist_Tracking.lua
-- Owns tracking events, update coalescing, and snapshot persistence.
local addonName = ...
local Addon = _G[addonName]
if not Addon then return end

local trackingEventFrame
local trackingUIParent
local backgroundTrackingEnabled
local trackingBucketRegistered
local scheduledUpdates = {}

local function SafeRegisterEvent(frame, eventName)
    if not (frame and eventName) then return false end
    return pcall(frame.RegisterEvent, frame, eventName)
end

local function IsShown(frame)
    return frame and frame.IsShown and frame:IsShown()
end

function Addon:HasTrackingSnapshot()
    if not (self.db and self.db.global) then return false end
    local ownKey = self:GetCurrentProfileKey()
    local charDB = self.db.global.chars and self.db.global.chars[ownKey]
    local snap = charDB and charDB.trackingSnapshot
    return type(snap) == "table" and (snap.leftLines ~= nil or snap.rightRows ~= nil)
end

function Addon:ConfigureTrackingEvents(parentFrame, showGreatVault, showCurrency)
    trackingEventFrame = trackingEventFrame or CreateFrame("Frame")
    trackingEventFrame:UnregisterAllEvents()
    if parentFrame then
        trackingUIParent = parentFrame
    else
        backgroundTrackingEnabled = (showGreatVault or showCurrency) and true or false
    end

    local trackGreatVault = backgroundTrackingEnabled or showGreatVault
    local trackCurrency = backgroundTrackingEnabled or showCurrency
    if not (trackGreatVault or trackCurrency) then return end

    trackingEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    if trackGreatVault then
        trackingEventFrame:RegisterEvent("WEEKLY_REWARDS_UPDATE")
    end
    if trackCurrency then
        trackingEventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
        trackingEventFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
        trackingEventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
        trackingEventFrame:RegisterEvent("QUEST_TURNED_IN")
        SafeRegisterEvent(trackingEventFrame, "CATALYST_CHARGES_UPDATED")
        SafeRegisterEvent(trackingEventFrame, "CATALYST_UPDATE")
        SafeRegisterEvent(trackingEventFrame, "ITEM_INTERACTION_ITEM_SELECTION_UPDATED")
    end

    trackingEventFrame:SetScript("OnEvent", function()
        if IsShown(trackingUIParent) and IsShown(Addon._trackingFrame) then
            Addon:RequestTrackingUpdate()
        else
            Addon:RequestBackgroundSnapshotUpdate()
        end
    end)
end

function Addon:SuspendTrackingUI()
    trackingUIParent = nil
end

local function ScheduleOnce(updateKey, callback)
    local state = scheduledUpdates[updateKey]
    if not state then
        state = {}
        scheduledUpdates[updateKey] = state
    end
    if state.pending then return end
    state.pending = true
    if not state.runner then
        state.runner = function()
            state.pending = false
            callback(Addon)
        end
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0.2, state.runner)
    else
        state.runner()
    end
end

function Addon:RequestBackgroundSnapshotUpdate()
    ScheduleOnce("background", function(addon)
        addon:UpdateSnapshotBackground()
    end)
end

function Addon:StartBackgroundTracking()
    self:ConfigureTrackingEvents(nil, true, true)
    self:RequestBackgroundSnapshotUpdate()

    -- Login APIs settle asynchronously; these passes replace incomplete early
    -- captures without requiring the checklist window to be opened.
    if C_Timer and C_Timer.After then
        for _, delay in ipairs({ 2, 5 }) do
            C_Timer.After(delay, function()
                Addon:RequestBackgroundSnapshotUpdate()
            end)
        end
    end
end

function Addon:SaveTrackingSnapshot(db)
    if not db then return nil end
    local snap = db.trackingSnapshot
    if type(snap) ~= "table" then
        snap = {}
        db.trackingSnapshot = snap
    end
    self:BuildTrackingSnapshot(snap)
    snap.updatedAt = time()
    return snap
end

function Addon:UpdateSnapshotBackground()
    -- EnsureDB normally follows the selected alt; background capture always
    -- belongs to the character currently logged in.
    local viewedCharacter = self._viewingChar
    self._viewingChar = nil
    local db = self:EnsureDB()
    self._viewingChar = viewedCharacter
    self:SaveTrackingSnapshot(db)
end

function Addon:RequestTrackingUpdate()
    if not self.RegisterBucketMessage then
        local aceBucket = LibStub and LibStub("AceBucket-3.0", true)
        if aceBucket then aceBucket:Embed(self) end
    end
    if self.RegisterBucketMessage and self.SendMessage then
        if not trackingBucketRegistered then
            trackingBucketRegistered = true
            self:RegisterBucketMessage("LWMC_TRACKING_UPDATE", 0.2, function()
                if Addon.UpdateTracking then Addon:UpdateTracking() end
            end)
        end
        self:SendMessage("LWMC_TRACKING_UPDATE")
        return
    end

    ScheduleOnce("panel", function(addon)
        if addon.UpdateTracking then addon:UpdateTracking() end
    end)
end
