local Test = _G.LWMC_TEST
local Harness = _G.LWMC_HARNESS

local function loadComms(version)
    local addon = Harness.newAddon({ LOCALE_REGISTRY_KEY = "LWMC_TEST_LOCALE" })
    addon._myVersion = version or "2.1.0"
    addon.dbState = {
        _newestSeenRemoteVersion = "",
        _newestSeenRemoteSender = "",
        _newestSeenRemoteSheetVersion = "",
    }
    addon.EnsureDB = function(self) return self.dbState end
    _G.LWMC_TEST_LOCALE = { sheet_version = "Week 5" }
    Harness.load(addon, "features/services/comms/LariasWeeklyChecklist_Comms.lua")
    return addon
end

Test.case("update notice appears only for a newer live version", function()
    local addon = loadComms("2.1.0")
    addon.dbState._newestSeenRemoteVersion = "2.1.1"
    addon.dbState._newestSeenRemoteVersionAt = 123456
    Test.truthy(addon:ShouldShowUpdateNotice())
    addon.dbState._newestSeenRemoteVersion = "2.1.0"
    Test.falsy(addon:ShouldShowUpdateNotice())
    addon._myVersion = "2.1.2-alpha"
    Test.falsy(addon:ShouldShowUpdateNotice())
end)

Test.case("sheet notice compares extracted week numbers", function()
    local addon = loadComms()
    addon.dbState._newestSeenRemoteSheetVersion = "Week 7"
    addon.dbState._newestSeenRemoteSheetVersionAt = 123456
    Test.truthy(addon:ShouldShowSheetUpdateNotice())
    addon.dbState._newestSeenRemoteSheetVersion = "Week 4"
    Test.falsy(addon:ShouldShowSheetUpdateNotice())
end)

Test.case("stale prior-season sheet observations are cleared", function()
    local addon = loadComms()
    addon.dbState._newestSeenRemoteSheetVersion = "Week 20"
    addon.dbState._newestSeenRemoteSheetVersionAt = 123456
    Test.falsy(addon:ShouldShowSheetUpdateNotice())
    Test.equal(addon.dbState._newestSeenRemoteSheetVersion, "")
end)

Test.case("sheet versions prefer week numbers over calendar dates", function()
    local addon = loadComms()
    _G.LWMC_TEST_LOCALE.sheet_version = "Week 5 - Apr 14"
    addon.dbState._newestSeenRemoteSheetVersion = "Week 6 - Apr 21"
    addon.dbState._newestSeenRemoteSheetVersionAt = 123456
    Test.truthy(addon:ShouldShowSheetUpdateNotice())
end)

Test.case("newer addon messages update observed version and sender", function()
    local addon = loadComms("2.1.0")
    local banners = 0
    addon.UpdateStatusBanner = function() banners = banners + 1 end
    addon:OnAddonMessage("LWMC", "V\t2.2.0\tWeek 5", "Other-Realm")
    Test.equal(addon.dbState._newestSeenRemoteVersion, "2.2.0")
    Test.equal(addon.dbState._newestSeenRemoteSender, "Other-Realm")
    Test.equal(banners, 1)
end)

Test.case("older and prerelease addon messages are ignored", function()
    local addon = loadComms("2.1.0")
    addon:OnAddonMessage("LWMC", "V\t2.0.0\t", "Other")
    addon:OnAddonMessage("LWMC", "V\t3.0.0-alpha\t", "Other")
    Test.equal(addon.dbState._newestSeenRemoteVersion, "")
end)

Test.case("messages with wrong prefix or invalid shape are ignored", function()
    local addon = loadComms()
    addon:OnAddonMessage("OTHER", "V\t9.0.0\t", "Other")
    addon:OnAddonMessage("LWMC", "garbage", "Other")
    addon:OnAddonMessage("LWMC", nil, "Other")
    Test.equal(addon.dbState._newestSeenRemoteVersion, "")
end)

Test.case("messages reject malformed versions extra fields and oversize payloads", function()
    local addon = loadComms()
    addon:OnAddonMessage("LWMC", "V\t999beta\tWeek 5", "Other")
    addon:OnAddonMessage("LWMC", "V\t9.0.0\tWeek 5\textra", "Other")
    addon:OnAddonMessage("LWMC", "V\t9.0.0\t" .. string.rep("x", 200), "Other")
    Test.equal(addon.dbState._newestSeenRemoteVersion, "")
end)

Test.case("messages throttle repeated input from one sender", function()
    local addon = loadComms("2.1.0")
    local now = 100
    _G.time = function() return now end
    addon:OnAddonMessage("LWMC", "V\t2.2.0\tWeek 5", "Other-Realm")
    addon:OnAddonMessage("LWMC", "V\t2.3.0\tWeek 5", "Other-Realm")
    Test.equal(addon.dbState._newestSeenRemoteVersion, "2.2.0")
    now = 103
    addon:OnAddonMessage("LWMC", "V\t2.4.0\tWeek 5", "Other-Realm")
    Test.equal(addon.dbState._newestSeenRemoteVersion, "2.4.0")
end)

Test.case("expired remote observations are cleared", function()
    local addon = loadComms("2.1.0")
    addon.dbState._newestSeenRemoteVersion = "9.0.0"
    addon.dbState._newestSeenRemoteSender = "Old-Realm"
    addon.dbState._newestSeenRemoteVersionAt = 123456 - addon.COMM_OBSERVATION_TTL_SECONDS - 1
    Test.falsy(addon:ShouldShowUpdateNotice())
    Test.equal(addon.dbState._newestSeenRemoteVersion, "")
    Test.equal(addon.dbState._newestSeenRemoteSender, "")
end)

Test.case("self addon messages are ignored", function()
    local addon = loadComms("2.1.0")
    addon:OnAddonMessage("LWMC", "V\t2.2.0\t", "Tester-Realm")
    Test.equal(addon.dbState._newestSeenRemoteVersion, "")
end)

Test.case("query messages schedule one throttled reply", function()
    local addon = loadComms()
    local replies = 0
    addon.BroadcastVersion = function(_, force) if force then replies = replies + 1 end end
    addon:OnAddonMessage("LWMC", "Q", "Other")
    addon:OnAddonMessage("LWMC", "Q", "Another")
    Harness.runTimers(5)
    Test.equal(replies, 1)
end)

Test.case("broadcast sends version to active group and guild", function()
    local addon = loadComms("2.1.0")
    _G.IsInGroup = function(category) return category == nil end
    _G.IsInGuild = function() return true end
    addon:BroadcastVersion(true)
    Test.equal(#Harness.sentMessages, 2)
    Test.equal(Harness.sentMessages[1].channel, "PARTY")
    Test.equal(Harness.sentMessages[2].channel, "GUILD")
    Test.contains(Harness.sentMessages[1].message, "2.1.0")
end)

Test.case("version requests emit query payload", function()
    local addon = loadComms()
    _G.IsInRaid = function() return true end
    addon:RequestVersions(true)
    Test.equal(#Harness.sentMessages, 1)
    Test.equal(Harness.sentMessages[1].message, "Q")
    Test.equal(Harness.sentMessages[1].channel, "RAID")
end)

local function loadTracking()
    local addon = Harness.newAddon()
    addon.GetCurrentProfileKey = function() return "Tester - Realm" end
    Harness.load(addon, "features/services/general/LariasWeeklyChecklist_Tracking.lua")
    return addon
end

Test.case("tracking snapshot presence checks stored shape", function()
    local addon = loadTracking()
    addon.db = { global = { chars = { ["Tester - Realm"] = {} } } }
    Test.falsy(addon:HasTrackingSnapshot())
    addon.db.global.chars["Tester - Realm"].trackingSnapshot = { rightRows = {} }
    Test.truthy(addon:HasTrackingSnapshot())
end)

Test.case("tracking event configuration registers requested domains", function()
    local addon = loadTracking()
    local parent = Harness.newFrame()
    addon:ConfigureTrackingEvents(parent, true, false)
    local eventFrame = Harness.frames[#Harness.frames]
    Test.truthy(eventFrame:IsEventRegistered("PLAYER_ENTERING_WORLD"))
    Test.truthy(eventFrame:IsEventRegistered("WEEKLY_REWARDS_UPDATE"))
    Test.falsy(eventFrame:IsEventRegistered("CURRENCY_DISPLAY_UPDATE"))
end)

Test.case("tracking requests merge event bursts before rendering", function()
    local addon = loadTracking()
    local parent = Harness.newFrame(); parent.shown = true
    addon._trackingFrame = Harness.newFrame(); addon._trackingFrame.shown = true
    addon:ConfigureTrackingEvents(parent, true, true)
    local received
    addon.UpdateTracking = function(_, dirty) received = dirty end
    addon:RequestTrackingUpdate("WEEKLY_REWARDS_UPDATE")
    addon:RequestTrackingUpdate("CURRENCY_DISPLAY_UPDATE")
    Test.equal(#Harness.timers, 1)
    Harness.runTimers()
    Test.truthy(received.vault)
    Test.truthy(received.currency)
    Test.falsy(received.full)
end)

Test.case("unknown tracking events request a full refresh", function()
    local addon = loadTracking()
    local parent = Harness.newFrame(); parent.shown = true
    addon._trackingFrame = Harness.newFrame(); addon._trackingFrame.shown = true
    addon:ConfigureTrackingEvents(parent, true, true)
    local received
    addon.UpdateTracking = function(_, dirty) received = dirty end
    addon:RequestTrackingUpdate("FUTURE_EVENT")
    Harness.runTimers()
    Test.truthy(received.full)
end)

Test.case("non-player inventory events do not schedule updates", function()
    local addon = loadTracking()
    local parent = Harness.newFrame(); parent.shown = true
    addon._trackingFrame = Harness.newFrame(); addon._trackingFrame.shown = true
    addon:ConfigureTrackingEvents(parent, true, true)
    local eventFrame = Harness.frames[#Harness.frames]
    eventFrame:Fire("UNIT_INVENTORY_CHANGED", "party1")
    Test.equal(#Harness.timers, 0)
end)

Test.case("saving a snapshot stamps time and dirties Alt Summary", function()
    local addon = loadTracking()
    local marked = 0
    addon.BuildTrackingSnapshot = function(_, snap, dirty) snap.domain = dirty.currency and "currency" end
    addon.MarkAltsSummaryDirty = function() marked = marked + 1 end
    local database = {}
    local result = addon:SaveTrackingSnapshot(database, { currency = true })
    Test.equal(result.domain, "currency")
    Test.equal(result.updatedAt, 123456)
    Test.equal(marked, 1)
end)
