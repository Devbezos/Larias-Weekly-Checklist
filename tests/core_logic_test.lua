local Test = _G.LWMC_TEST
local Core = _G.LWMC_TEST_ADDON.CoreLogic

Test.case("generated locale data parses", function()
    local chunk, loadError = loadfile("Locales/enUS_Data.lua")
    Test.truthy(chunk, loadError)
end)

Test.case("dirty domains map events and merge bursts", function()
    local dirty = {}
    Core.MergeDirtyDomains(dirty, "WEEKLY_REWARDS_UPDATE")
    Core.MergeDirtyDomains(dirty, "PLAYER_EQUIPMENT_CHANGED")
    Test.truthy(dirty.vault)
    Test.truthy(dirty.gear)
    Test.truthy(dirty.currency)
    Test.falsy(dirty.full)
end)

Test.case("unknown and initial events request a full refresh", function()
    local unknown = Core.MergeDirtyDomains({}, "SOME_FUTURE_EVENT")
    local initial = Core.MergeDirtyDomains({}, "PLAYER_ENTERING_WORLD")
    local explicit = Core.MergeDirtyDomains({}, nil)
    Test.truthy(unknown.full)
    Test.truthy(initial.full)
    Test.truthy(explicit.full)
end)

Test.case("snapshot refresh plans preserve gear currency dependency", function()
    local vault, gear, currency = Core.GetSnapshotRefreshPlan({ gear = true })
    Test.falsy(vault)
    Test.truthy(gear)
    Test.truthy(currency)

    vault, gear, currency = Core.GetSnapshotRefreshPlan({ vault = true })
    Test.truthy(vault)
    Test.falsy(gear)
    Test.falsy(currency)

    vault, gear, currency = Core.GetSnapshotRefreshPlan(nil)
    Test.truthy(vault)
    Test.truthy(gear)
    Test.truthy(currency)
end)

Test.case("pruning rejects empty or partial datasets", function()
    local sections = Core.BuildValidChecklistKeys({})
    Test.equal(sections, nil)

    sections = Core.BuildValidChecklistKeys({ { id = "weekly", items = {} } })
    Test.equal(sections, nil)

    sections = Core.BuildValidChecklistKeys({ { items = { { id = "boss" } } } })
    Test.equal(sections, nil)
end)

Test.case("pruning builds only valid section and item keys", function()
    local sections, items = Core.BuildValidChecklistKeys({
        { id = "raid", items = { { id = "boss-1" }, { id = 42 } } },
        { id = "vault", items = { { id = "slot-1" } } },
        "invalid",
    })
    Test.truthy(sections.raid)
    Test.truthy(sections.vault)
    Test.truthy(items["raid:boss-1"])
    Test.truthy(items["vault:slot-1"])
    Test.equal(items["raid:42"], nil)
end)

Test.case("legacy migration copies payload and clears old profile", function()
    local checked = { ["raid:boss"] = true }
    local snapshot = { season = 12 }
    local profile = {
        checked = checked,
        collapsedSections = { raid = true },
        trackingSnapshot = snapshot,
        startAtSectionId = "raid",
        showCurrency = false,
        debug = true,
    }
    local destination = { keep = true }

    Test.truthy(Core.MigrateLegacyProfile(profile, destination))
    Test.truthy(destination.checked["raid:boss"])
    Test.truthy(destination.collapsedSections.raid)
    Test.equal(destination.startAtSectionId, "raid")
    Test.equal(destination.showCurrency, false)
    Test.truthy(destination.debug)
    Test.truthy(destination.keep)
    Test.falsy(destination.checked == checked, "checked table must be copied")
    Test.falsy(destination.trackingSnapshot == snapshot, "snapshot table must be copied")
    Test.equal(profile.checked, nil)
    Test.equal(profile.showCurrency, nil)
end)

Test.case("empty legacy profiles are not migrated", function()
    local destination = { keep = true }
    Test.falsy(Core.MigrateLegacyProfile({}, destination))
    Test.truthy(destination.keep)
    Test.equal(destination.checked, nil)
end)

Test.case("versions compare numerically and normalize tags", function()
    Test.equal(Core.CompareVersions("1.0.10", "1.0.2"), 1)
    Test.equal(Core.CompareVersions("v2.1.0", "2.1"), 0)
    Test.equal(Core.CompareVersions("2.0.0+build.7", "1.9.9"), 1)
    Test.equal(Core.CompareVersions("", "1.0.0"), -1)
    Test.equal(Core.NormalizeVersionString("  V2.3.4 notes "), "2.3.4")
    Test.truthy(Core.IsLiveVersion("2.3.4+build.1"))
    Test.falsy(Core.IsLiveVersion("2.3.4-alpha"))
end)

Test.case("crest plans cascade produced balances in tier order", function()
    local tierTwo = { sourceTier = 2, destTier = 3, costPer = 30, gainPer = 10 }
    local tierOne = { sourceTier = 1, destTier = 2, costPer = 30, gainPer = 10 }
    local balances = { [1] = 90, [2] = 0, [3] = 0 }
    local plan = Core.BuildCascadingConversionPlan({ tierTwo, tierOne }, function(tier)
        return balances[tier] or 0
    end)

    Test.equal(#plan, 2)
    Test.equal(plan[1].action, tierOne)
    Test.equal(plan[1].count, 3)
    Test.equal(plan[2].action, tierTwo)
    Test.equal(plan[2].count, 1)
end)

Test.case("crest plans ignore invalid and unaffordable actions", function()
    local plan = Core.BuildCascadingConversionPlan({
        { sourceTier = 1, destTier = 2, costPer = 0, gainPer = 10 },
        { sourceTier = 2, destTier = 3, costPer = 30, gainPer = 10 },
    }, function() return 0 end)
    Test.equal(#plan, 0)
end)

Test.case("conversion runner buys sequentially and completes", function()
    local actions = {
        { merchantIdx = 1, itemID = 10 },
        { merchantIdx = 2, itemID = 20 },
    }
    local available = { [1] = 3, [2] = 1 }
    local purchases = {}
    local timers = {}
    local completed = 0
    Core.RunConversionPlan({
        { action = actions[1], count = 3 },
        { action = actions[2], count = 2 },
    }, {
        isActionValid = function() return true end,
        getAvailableCount = function(action) return available[action.merchantIdx] end,
        buy = function(action, count) purchases[#purchases + 1] = { action.merchantIdx, count } end,
        schedule = function(_, callback) timers[#timers + 1] = callback end,
        onComplete = function() completed = completed + 1 end,
    })
    while #timers > 0 do table.remove(timers, 1)() end
    Test.same(purchases, { { 1, 3 }, { 2, 1 } })
    Test.equal(completed, 1)
end)

Test.case("conversion runner retries delayed balances", function()
    local attempts = 0
    local purchases = 0
    local timers = {}
    Core.RunConversionPlan({ { action = { merchantIdx = 1 }, count = 2 } }, {
        getAvailableCount = function()
            attempts = attempts + 1
            return attempts >= 3 and 2 or 0
        end,
        buy = function(_, count) purchases = purchases + count end,
        schedule = function(_, callback) timers[#timers + 1] = callback end,
    })
    while #timers > 0 do table.remove(timers, 1)() end
    Test.equal(attempts, 3)
    Test.equal(purchases, 2)
end)

Test.case("conversion runner cancels pending steps", function()
    local cancelled = false
    local purchases = 0
    local timers = {}
    Core.RunConversionPlan({
        { action = { merchantIdx = 1 }, count = 1 },
        { action = { merchantIdx = 2 }, count = 1 },
    }, {
        isCancelled = function() return cancelled end,
        getAvailableCount = function() return 1 end,
        buy = function() purchases = purchases + 1; cancelled = true end,
        schedule = function(_, callback) timers[#timers + 1] = callback end,
    })
    while #timers > 0 do table.remove(timers, 1)() end
    Test.equal(purchases, 1)
end)

Test.case("conversion runner aborts changed merchant actions", function()
    local purchases, aborted = 0, 0
    Core.RunConversionPlan({ { action = { merchantIdx = 1, itemID = 10 }, count = 1 } }, {
        isActionValid = function() return false end,
        getAvailableCount = function() error("must validate before reading balance") end,
        buy = function() purchases = purchases + 1 end,
        onAbort = function(reason) if reason == "invalid_action" then aborted = aborted + 1 end end,
    })
    Test.equal(purchases, 0)
    Test.equal(aborted, 1)
end)

Test.case("list pruning fails closed and retries when data becomes valid", function()
    local Addon = _G.LWMC_TEST_ADDON
    local chunk, loadError = loadfile("features/body/LariasWeeklyChecklist_ListData.lua")
    if not chunk then error(loadError) end
    chunk("LWMC_TEST_ADDON")

    local database = {
        checked = { ["raid:boss"] = true, ["removed:item"] = true },
        collapsedSections = { raid = true, removed = true },
        sectionCompleted = { removed = true },
    }
    local listData = {}
    Addon._svPrunedThisSession = nil
    Addon.EnsureDB = function() return database end
    Addon.GetListData = function() return listData end
    Addon.GetLocaleRegistry = function() return { sheet_version = "test" } end

    Addon:PruneObsoleteSavedState()
    Test.falsy(Addon._svPrunedThisSession)
    Test.truthy(database.checked["removed:item"])

    listData = { { id = "raid", items = { { id = "boss" } } } }
    Addon:PruneObsoleteSavedState()
    Test.truthy(Addon._svPrunedThisSession)
    Test.truthy(database.checked["raid:boss"])
    Test.equal(database.checked["removed:item"], nil)
    Test.equal(database.collapsedSections.removed, nil)
    Test.equal(database.sectionCompleted.removed, nil)
end)

Test.case("database setup migrates legacy profile data once", function()
    local Addon = _G.LWMC_TEST_ADDON
    local oldLibStub = _G.LibStub
    local capturedDefaults
    local database = {
        global = { chars = {} },
        profile = {
            checked = { ["weekly:item"] = true },
            startAtSectionId = "weekly",
        },
    }
    local aceDB = {
        New = function(_, _, defaults)
            capturedDefaults = defaults
            return database
        end,
    }
    _G.LibStub = function(name)
        Test.equal(name, "AceDB-3.0")
        return aceDB
    end
    Addon.db = nil
    Addon.GetCurrentProfileKey = function() return "Tester - Realm" end

    local chunk, loadError = loadfile("features/services/general/LariasWeeklyChecklist_Database.lua")
    if not chunk then error(loadError) end
    chunk("LWMC_TEST_ADDON")
    Addon:SetupAddonDB()
    _G.LibStub = oldLibStub

    local migrated = database.global.chars["Tester - Realm"]
    Test.truthy(migrated._migrated)
    Test.truthy(migrated.checked["weekly:item"])
    Test.equal(migrated.startAtSectionId, "weekly")
    Test.equal(database.profile.checked, nil)
    Test.equal(capturedDefaults.global.currencyConfigWin, false)
    Test.equal(capturedDefaults.global.crestConvertWin, false)
end)
