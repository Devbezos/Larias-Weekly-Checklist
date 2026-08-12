local Test = _G.LWMC_TEST
local Harness = _G.LWMC_HARNESS

local function loadFeatureAddon()
    local addon = Harness.newAddon()
    Harness.load(addon, "features/utils/LariasWeeklyChecklist_AddonUtils.lua")
    Harness.load(addon, "features/utils/LariasWeeklyChecklist_IlvlUtils.lua")
    Harness.load(addon, "features/body/LariasWeeklyChecklist_Currency.lua")
    return addon
end

local function loadAltSummaryAddon()
    local addon = loadFeatureAddon()
    Harness.load(addon, "features/services/general/LariasWeeklyChecklist_Snapshot.lua")
    Harness.load(addon, "features/body/LariasWeeklyChecklist_AltsSummary.lua")
    return addon
end

Test.case("weapon upgrade configuration has safe defaults", function()
    local addon = loadFeatureAddon()
    Test.equal(addon:GetWeaponUpgradeCombinedItemID(), 0)
    Test.equal(addon:GetWeaponUpgradeShardItemID(), 0)
    Test.equal(addon:GetWeaponUpgradeMaxItemLevel(), 0)
    Test.equal(addon:GetWeaponUpgradeShardsPerCombined(), 1)
    Test.same(addon:GetWeaponUpgradeSlotIDs(), {})
end)

Test.case("weapon upgrade configuration returns tracking values", function()
    local addon = loadFeatureAddon()
    addon.TRACKING.weaponUpgrade = {
        combinedItemID = "20", shardItemID = 21, maxItemLevel = 298,
        shardsPerCombined = 3, slotIDs = { 13, 14 },
    }
    Test.equal(addon:GetWeaponUpgradeCombinedItemID(), 20)
    Test.equal(addon:GetWeaponUpgradeShardItemID(), 21)
    Test.equal(addon:GetWeaponUpgradeMaxItemLevel(), 298)
    Test.equal(addon:GetWeaponUpgradeShardsPerCombined(), 3)
    Test.same(addon:GetWeaponUpgradeSlotIDs(), { 13, 14 })
end)

Test.case("upgrade gear slots prefer best known watermark gear", function()
    local addon = loadFeatureAddon()
    local best = { [1] = { ilvl = 120 } }
    local equipped = { [1] = { ilvl = 110 } }
    Test.equal(addon:GetUpgradeGearSlots({ bestGearSlots = best, gearSlots = equipped }), best)
    Test.equal(addon:GetEquippedUpgradeGearSlots({ bestGearSlots = best, gearSlots = equipped }), equipped)
    Test.equal(addon:GetUpgradeGearSlots({ gearSlots = equipped }), equipped)
    Test.equal(addon:GetEquippedUpgradeGearSlots({ bestGearSlots = best }), best)
    Test.equal(addon:GetUpgradeGearSlots(nil), nil)
    Test.equal(addon:GetEquippedUpgradeGearSlots(nil), nil)
end)

Test.case("item upgrade watermark uses the larger account value", function()
    local addon = loadFeatureAddon()
    _G.C_ItemUpgrade = { GetHighWatermarkForItem = function() return 112, 124 end }
    Test.equal(addon:GetItemUpgradeHighWatermark("item:1"), 124)
end)

Test.case("item upgrade watermark contains API failures", function()
    local addon = loadFeatureAddon()
    _G.C_ItemUpgrade = { GetHighWatermarkForItem = function() error("unavailable") end }
    Test.equal(addon:GetItemUpgradeHighWatermark("item:1"), 0)
    Test.equal(addon:GetItemUpgradeHighWatermark(nil), 0)
end)

Test.case("crest cost parsing selects the highest matching tier", function()
    local addon = loadFeatureAddon()
    local tier, id, cost = addon:GetCrestTierFromCosts({
        { currencyID = 999, cost = 1 },
        { currencyID = 102, cost = 15 },
        { currencyID = 104, cost = 20 },
    })
    Test.equal(tier, 4)
    Test.equal(id, 104)
    Test.equal(cost, 20)
end)

Test.case("crest cost parsing rejects malformed inputs", function()
    local addon = loadFeatureAddon()
    Test.equal(addon:GetCrestTierFromCosts(nil), nil)
    Test.equal(addon:GetCrestTierFromCosts({ { currencyID = 999 } }), nil)
end)

Test.case("captured remaining crest cost takes priority", function()
    local addon = loadFeatureAddon()
    local cost = addon:GetCrestSlotUpgradeCost(1, {
        rank = 2, maxRank = 6, upgradeCostRemaining = 37,
    }, {}, 2, 6)
    Test.equal(cost, 37)
end)

Test.case("normal crest cost multiplies remaining ranks", function()
    local addon = loadFeatureAddon()
    addon.TRACKING.crestUpgradeCostPerStep = { 10, 20, 30 }
    addon.IsCrestDiscountUnlocked = function() return false end
    local cost = addon:GetCrestSlotUpgradeCost(1, {
        rank = 2, maxRank = 6, ilvl = 112, link = "item:1",
    }, {}, 2, 6)
    Test.equal(cost, 80)
end)

Test.case("crest discounts apply only through the high watermark", function()
    local addon = loadFeatureAddon()
    addon.TRACKING.crestUpgradeCostPerStep = { 20, 20, 20 }
    addon.TRACKING.crestUpgradeCostReduced = { 10, 10, 10 }
    addon.IsCrestDiscountUnlocked = function() return true end
    local cost = addon:GetCrestSlotUpgradeCost(1, {
        rank = 1, maxRank = 6, ilvl = 110, link = "item:1",
    }, {
        bestGearSlots = {
            [1] = { tierIdx = 2, rank = 4, maxRank = 6 },
        },
    }, 2, 6)
    Test.equal(cost, 70)
end)

Test.case("effective max rank repairs stale true max values", function()
    local addon = loadFeatureAddon()
    local slot = { rank = 4, maxRank = 6, trueMaxRank = 3 }
    Test.equal(addon:GetSlotEffectiveMax(slot), 6)
    Test.equal(slot.trueMaxRank, nil)
    Test.equal(addon:GetSlotEffectiveMax({ rank = 4, maxRank = 6, trueMaxRank = 5 }), 5)
end)

Test.case("limited crafted gear includes embellishments and rank caps", function()
    local addon = loadFeatureAddon()
    Test.truthy(addon:IsSlotLimitedCrafted({ isEmbellished = true, maxRank = 6 }, 6))
    Test.truthy(addon:IsSlotLimitedCrafted({ maxRank = 6 }, 4))
    Test.falsy(addon:IsSlotLimitedCrafted({ maxRank = 6 }, 6))
end)

Test.case("tier upgrade total uses equipped gear and excludes other tiers and limited gear", function()
    local addon = loadFeatureAddon()
    addon.IsTrackingSnapshotCurrentSeason = function() return true end
    addon.GetCrestSlotUpgradeCost = function(_, slotID) return slotID * 10 end
    local snap = { gearSlots = {
        [1] = { tierIdx = 2, rank = 1, maxRank = 6 },
        [2] = { tierIdx = 3, rank = 1, maxRank = 6 },
        [3] = { tierIdx = 2, rank = 1, maxRank = 6, isEmbellished = true },
    } }
    Test.equal(addon:CalcTierUpgradeCost(snap, 2), 10)
end)

Test.case("tier upgrade total ignores equipped item when slot watermark is already maxed", function()
    local addon = loadFeatureAddon()
    addon.IsTrackingSnapshotCurrentSeason = function() return true end
    addon.GetCrestSlotUpgradeCost = function(_, slotID) return slotID * 10 end
    local snap = {
        bestGearSlots = {
            [1] = { tierIdx = 2, rank = 6, maxRank = 6 },
        },
        gearSlots = {
            [1] = { tierIdx = 2, rank = 1, maxRank = 6 },
        },
    }
    Test.equal(addon:CalcTierUpgradeCost(snap, 2), 0)
end)

Test.case("tier upgrade total ignores lower-track equipped item when slot watermark is higher", function()
    local addon = loadFeatureAddon()
    addon.IsTrackingSnapshotCurrentSeason = function() return true end
    addon.GetCrestSlotUpgradeCost = function(_, slotID) return slotID * 10 end
    local snap = {
        bestGearSlots = {
            [1] = { tierIdx = 3, rank = 1, maxRank = 6 },
        },
        gearSlots = {
            [1] = { tierIdx = 2, rank = 4, maxRank = 6 },
        },
    }
    Test.equal(addon:CalcTierUpgradeCost(snap, 2), 0)
end)

Test.case("tier upgrade total does not guess costs when snapshot has exact upgrade details", function()
    local addon = loadFeatureAddon()
    addon.IsTrackingSnapshotCurrentSeason = function() return true end
    addon.IsCrestDiscountUnlocked = function() return false end
    local snap = {
        upgradeDetailsAvailable = true,
        gearSlots = {
            [1] = { tierIdx = 2, rank = 1, maxRank = 6, upgradeCostRemaining = 60 },
            [2] = { tierIdx = 2, rank = 6, maxRank = 6 },
            [3] = { tierIdx = 3, rank = 1, maxRank = 6 },
        },
    }
    Test.equal(addon:CalcTierUpgradeCost(snap, 2), 60)
end)

Test.case("tier upgrade total discounts ranks covered by slot watermark", function()
    local addon = loadFeatureAddon()
    addon.IsTrackingSnapshotCurrentSeason = function() return true end
    addon.IsCrestDiscountUnlocked = function() return true end
    addon.TRACKING.crestUpgradeCostPerStep = 20
    addon.TRACKING.crestUpgradeCostReduced = 10
    local snap = {
        gearSlots = {
            [1] = { tierIdx = 4, rank = 1, maxRank = 6 },
        },
        bestGearSlots = {
            [1] = { tierIdx = 4, rank = 3, maxRank = 6 },
        },
    }
    Test.equal(addon:CalcTierUpgradeCost(snap, 4), 80)
end)

Test.case("tier achievement cost uses watermark gear instead of equipped gear", function()
    local addon = loadFeatureAddon()
    addon.IsTrackingSnapshotCurrentSeason = function() return true end
    addon.IsCrestDiscountUnlocked = function() return false end
    addon.TRACKING.crestUpgradeCostPerStep = 20
    local watermarks = {}
    for slot = 0, 16 do watermarks[slot] = 0 end
    watermarks[0] = 124
    watermarks[1] = 128
    watermarks[2] = 131
    local snap = {
        itemUpgradeWatermarks = watermarks,
        itemUpgradeWatermarksCaptured = true,
        gearSlots = {
            [1] = { tierIdx = 2, rank = 4, maxRank = 6 },
        },
        bestGearSlots = {
            [1] = { tierIdx = 3, rank = 3, maxRank = 6 },
        },
    }
    Test.equal(addon:CalcTierAchievementCost(snap, 2), 0)
    Test.equal(addon:CalcTierAchievementCost(snap, 3), 80)
end)

Test.case("tier achievement cost uses redundancy slots and cheapest weapon watermark group", function()
    local addon = loadFeatureAddon()
    addon.IsTrackingSnapshotCurrentSeason = function() return true end
    addon.IsCrestDiscountUnlocked = function() return false end
    addon.TRACKING.ilvlBase = 266
    addon.TRACKING.ilvlTrackStep = 13
    addon.TRACKING.ilvlRankOffsets = { 0, 3, 6, 10, 13, 16 }
    addon.TRACKING.crestCurrencyIDs = { 3442, 3443, 3444, 3445, 3446 }
    addon.TRACKING.crestUpgradeCostPerStep = 20

    local watermarks = {}
    for slot = 0, 12 do watermarks[slot] = 318 end
    watermarks[13] = 0
    watermarks[14] = 0
    watermarks[15] = 0
    watermarks[16] = 0

    Test.equal(addon:CalcTierAchievementCost({
        itemUpgradeWatermarks = watermarks,
        itemUpgradeWatermarksCaptured = true,
    }, 5), 780)
end)

Test.case("tier achievement average item level uses watermark buckets", function()
    local addon = loadFeatureAddon()
    addon.TRACKING.ilvlBase = 266
    addon.TRACKING.ilvlTrackStep = 13
    addon.TRACKING.ilvlRankOffsets = { 0, 3, 6, 10, 13, 16 }
    addon.TRACKING.crestCurrencyIDs = { 3442, 3443, 3444, 3445, 3446 }
    addon.TRACKING.crestUpgradeCostPerStep = 20
    addon.IsCrestDiscountUnlocked = function() return false end

    local watermarks = {}
    for slot = 0, 11 do watermarks[slot] = 318 end
    watermarks[12] = 321
    watermarks[13] = 321
    watermarks[14] = 334
    watermarks[15] = 318
    watermarks[16] = 321

    local average = addon:CalcCrestAchievementAverageItemLevel({
        itemUpgradeWatermarks = watermarks,
        itemUpgradeWatermarksCaptured = true,
    }, 5)

    Test.equal(("%.2f"):format(average), "319.47")
end)

Test.case("tier achievement average item level ignores equipped physical slots", function()
    local addon = loadFeatureAddon()
    addon.TRACKING.ilvlBase = 266
    addon.TRACKING.ilvlTrackStep = 13
    addon.TRACKING.ilvlRankOffsets = { 0, 3, 6, 10, 13, 16 }
    addon.TRACKING.crestCurrencyIDs = { 3442, 3443, 3444, 3445, 3446 }
    addon.TRACKING.crestUpgradeCostPerStep = 20
    addon.IsCrestDiscountUnlocked = function() return false end

    local watermarks = {}
    for slot = 0, 16 do watermarks[slot] = 318 end
    local snap = {
        itemUpgradeWatermarks = watermarks,
        itemUpgradeWatermarksCaptured = true,
        gearSlots = {
            [11] = { ilvl = 321, itemUpgradeHighWatermark = 334 },
            [12] = { ilvl = 318, itemUpgradeHighWatermark = 334 },
            [13] = { ilvl = 318, itemUpgradeHighWatermark = 321 },
            [14] = { ilvl = 321, itemUpgradeHighWatermark = 321 },
            [16] = { ilvl = 328, itemUpgradeHighWatermark = 328 },
            [17] = { ilvl = 315, itemUpgradeHighWatermark = 328 },
        },
        bestGearSlots = {
            [11] = { itemUpgradeHighWatermark = 321 },
            [12] = { itemUpgradeHighWatermark = 334 },
            [13] = { itemUpgradeHighWatermark = 318 },
            [14] = { itemUpgradeHighWatermark = 321 },
            [16] = { itemUpgradeHighWatermark = 328 },
            [17] = { itemUpgradeHighWatermark = 315 },
        },
    }

    Test.equal(addon:CalcTierAchievementCost(snap, 5), 780)
    Test.equal(("%.2f"):format(addon:CalcCrestAchievementAverageItemLevel(snap, 5)), "318.00")
end)

Test.case("tier achievement cost ignores watermarks below displayed item levels", function()
    local addon = loadFeatureAddon()
    addon.IsTrackingSnapshotCurrentSeason = function() return true end
    addon.IsCrestDiscountUnlocked = function() return false end
    addon.TRACKING.crestUpgradeCostPerStep = 20
    addon.TRACKING.ilvlBase = 100
    local snap = {
        itemUpgradeWatermarks = {
            [0] = 0,
            [1] = 80,
            [2] = 132,
        },
        itemUpgradeWatermarksCaptured = true,
    }
    Test.equal(addon:CalcTierAchievementCost(snap, 3), 0)
end)

Test.case("tier achievement breakpoints derive from the item level ladder", function()
    local addon = loadFeatureAddon()
    addon.TRACKING.ilvlBase = 266
    addon.TRACKING.ilvlTrackStep = 13
    addon.TRACKING.ilvlRankOffsets = { 0, 3, 6, 10, 13, 16 }
    addon.TRACKING.crestCurrencyIDs = { 3442, 3443, 3444, 3445, 3446 }
    Test.same(addon:GetCrestAchievementBreakpoints(1), { 272, 276, 279, 282 })
    Test.same(addon:GetCrestAchievementBreakpoints(2), { 285, 289, 292, 295 })
    Test.same(addon:GetCrestAchievementBreakpoints(3), { 298, 302, 305, 308 })
    Test.same(addon:GetCrestAchievementBreakpoints(4), { 311, 315, 318, 321 })
    Test.same(addon:GetCrestAchievementBreakpoints(5), { 324, 328, 331 })
end)

Test.case("tier achievement cost uses reduced steps after discount achievement is earned", function()
    local addon = loadFeatureAddon()
    addon.IsTrackingSnapshotCurrentSeason = function() return true end
    addon.IsCrestDiscountUnlocked = function() return true end
    addon.TRACKING.crestUpgradeCostPerStep = 20
    addon.TRACKING.crestUpgradeCostReduced = 10
    local watermarks = {}
    for slot = 0, 16 do watermarks[slot] = 0 end
    watermarks[0] = 124
    watermarks[1] = 128
    local snap = {
        itemUpgradeWatermarks = watermarks,
        itemUpgradeWatermarksCaptured = true,
    }
    Test.equal(addon:CalcTierAchievementCost(snap, 3), 40)
end)

Test.case("tier achievement cost falls back to best gear when slot watermarks are missing", function()
    local addon = loadFeatureAddon()
    addon.IsTrackingSnapshotCurrentSeason = function() return true end
    addon.IsCrestDiscountUnlocked = function() return false end
    addon.TRACKING.crestUpgradeCostPerStep = 20
    local snap = {
        gearSlots = {
            [1] = { tierIdx = 2, rank = 4, maxRank = 6 },
        },
        bestGearSlots = {
            [1] = { tierIdx = 3, rank = 3, maxRank = 6, ilvl = 124 },
        },
    }
    Test.equal(addon:CalcTierAchievementCost(snap, 2), 0)
    Test.equal(addon:CalcTierAchievementCost(snap, 3), 60)
end)

Test.case("tier achievement cost falls back when watermarks were not captured", function()
    local addon = loadFeatureAddon()
    addon.IsTrackingSnapshotCurrentSeason = function() return true end
    addon.IsCrestDiscountUnlocked = function() return false end
    addon.TRACKING.crestUpgradeCostPerStep = 20
    local snap = {
        itemUpgradeWatermarks = {},
        itemUpgradeWatermarksCaptured = false,
        bestGearSlots = {
            [1] = { tierIdx = 3, rank = 3, maxRank = 6, ilvl = 124 },
        },
    }
    Test.equal(addon:CalcTierAchievementCost(snap, 3), 60)
end)

Test.case("tier achievement cost falls back when captured watermarks are incomplete", function()
    local addon = loadFeatureAddon()
    addon.IsTrackingSnapshotCurrentSeason = function() return true end
    addon.IsCrestDiscountUnlocked = function() return false end
    addon.TRACKING.crestUpgradeCostPerStep = 20
    local snap = {
        itemUpgradeWatermarks = { [0] = 124 },
        itemUpgradeWatermarksCaptured = true,
        bestGearSlots = {
            [1] = { tierIdx = 3, rank = 3, maxRank = 6, ilvl = 124 },
        },
    }
    Test.equal(addon:CalcTierAchievementCost(snap, 3), 60)
end)

Test.case("tier achievement fallback ignores overlapping rank two cost", function()
    local addon = loadFeatureAddon()
    addon.IsTrackingSnapshotCurrentSeason = function() return true end
    addon.IsCrestDiscountUnlocked = function() return false end
    addon.TRACKING.crestUpgradeCostPerStep = 20
    local snap = {
        bestGearSlots = {
            [1] = { tierIdx = 3, rank = 1, maxRank = 6, ilvl = 120 },
        },
    }
    Test.equal(addon:CalcTierAchievementCost(snap, 3), 80)
end)

Test.case("tier upgrade total rejects stale season snapshots", function()
    local addon = loadFeatureAddon()
    addon.IsTrackingSnapshotCurrentSeason = function() return false end
    Test.equal(addon:CalcTierUpgradeCost({ bestGearSlots = {} }, 2), 0)
end)

Test.case("crest availability combines held and tradeup amounts", function()
    local addon = loadFeatureAddon()
    local held, tradeup, total, earnable = addon:GetCrestAvailabilityForTier({ rightRows = {
        { type = "crest", id = 102, qty = "15", tradeup = 6, earned = 20, cap = 100 },
    } }, 2)
    Test.equal(held, 15)
    Test.equal(tradeup, 6)
    Test.equal(total, 101)
    Test.equal(earnable, 80)
end)

Test.case("crest tradeups use separate unlock achievements from displayed rows", function()
    local addon = loadFeatureAddon()
    addon.TRACKING.crestCurrencyIDs = { 101, 102 }
    addon.TRACKING.crestAchievementIDs = { [2] = 62411 }
    addon.TRACKING.crestTradeupAchievementIDs = { 62410, 62411 }
    addon.GetTrackedCurrencyEntries = function()
        return {
            { type = addon.SNAP_TYPES.CREST, id = 101, crestIdx = 1 },
            { type = addon.SNAP_TYPES.CREST, id = 102, crestIdx = 2 },
        }
    end
    _G.GetAchievementInfo = function(id)
        return nil, nil, nil, false, nil, nil, nil, nil, nil, nil, nil, nil, id == 62410
    end
    Harness.currencyInfo[101] = {
        name = "Adventurer Crest",
        iconFileID = 1,
        quantity = 30,
        maxQuantity = 100,
        totalEarned = 30,
        quality = 4,
    }
    Harness.currencyInfo[102] = {
        name = "Veteran Crest",
        iconFileID = 2,
        quantity = 0,
        maxQuantity = 100,
        totalEarned = 0,
        quality = 4,
    }

    local snap = { rightRows = {} }
    addon:FillCurrencySnapshot(snap)

    Test.equal(snap.rightRows[2].tradeup, 10)
end)

Test.case("crest achievement cap weeks subtract current and earnable crests", function()
    local addon = loadFeatureAddon()
    Test.equal(addon:CalcCrestAchievementCapWeeksNeeded(350, 70, 30, 100), 2)
    Test.equal(addon:CalcCrestAchievementCapWeeksNeeded(350, 250, 25, 100), 0)
end)

Test.case("currency snapshots store crest caps for earnable availability", function()
    local addon = loadFeatureAddon()
    Harness.currencyInfo[102] = {
        name = "Weathered Crest",
        iconFileID = 1,
        quantity = 15,
        maxQuantity = 100,
        totalEarned = 20,
        quality = 4,
    }
    addon.GetTrackedCurrencyEntries = function()
        return { { type = addon.SNAP_TYPES.CREST, id = 102, crestIdx = 2 } }
    end

    local snap = { rightRows = {} }
    addon:FillCurrencySnapshot(snap)

    Test.equal(snap.rightRows[1].cap, 100)
    local _, _, total, earnable = addon:GetCrestAvailabilityForTier(snap, 2)
    Test.equal(total, 95)
    Test.equal(earnable, 80)
end)

Test.case("currency panel keeps fallback rows for unknown currency ids", function()
    local addon = loadFeatureAddon()
    addon.TRACKING.crestCurrencyIDs = { 101, 999 }
    addon.GetTrackedCurrencyConfig = function()
        return {
            { id = 101, enabled = true },
            { id = 999, enabled = true },
        }
    end
    addon.IsQuestHidden = function() return true end
    addon.IsItemHidden = function() return false end
    Harness.currencyInfo[101] = {
        name = "Weathered Crest",
        iconFileID = 1,
        quantity = 3,
        maxQuantity = 90,
        totalEarned = 3,
        quality = 4,
    }

    local rows = addon:GetCurrencyPanelRows()
    Test.equal(#rows, 2)
    Test.equal(rows[1].currencyID, 101)
    Test.equal(rows[2].currencyID, 999)
end)

Test.case("currency panel shows cap zero crests as not earnable yet", function()
    local addon = loadFeatureAddon()
    addon.L.TRACKING_NOT_EARNABLE_YET = "Not earnable yet"
    addon.TRACKING.crestCurrencyIDs = { 3445 }
    addon.GetTrackedCurrencyConfig = function()
        return {
            { id = 3445, enabled = true },
        }
    end
    addon.IsQuestHidden = function() return true end
    addon.IsItemHidden = function() return false end
    Harness.currencyInfo[3445] = {
        name = "Heroic Crest",
        iconFileID = 1,
        quantity = 0,
        maxQuantity = 0,
        totalEarned = 0,
        quality = 4,
    }

    local rows = addon:GetCurrencyPanelRows()
    Test.equal(#rows, 1)
    Test.equal(rows[1].currencyID, 3445)
    Test.truthy(rows[1].amountTooltipText)
    Test.equal(rows[1].amountTooltipText[1].text, "Not earnable yet")
end)

Test.case("currency snapshot keeps unknown currency ids", function()
    local addon = loadFeatureAddon()
    addon.TRACKING.crestCurrencyIDs = { 101, 999 }
    addon.GetTrackedCurrencyConfig = function()
        return {
            { id = 101, enabled = true },
            { id = 999, enabled = true },
        }
    end
    Harness.currencyInfo[101] = {
        name = "Weathered Crest",
        iconFileID = 1,
        quantity = 3,
        maxQuantity = 90,
        totalEarned = 3,
        quality = 4,
    }

    local snap = {}
    addon:FillCurrencySnapshot(snap)
    Test.equal(#snap.rightRows, 2)
    Test.equal(snap.rightRows[1].id, 101)
    Test.equal(snap.rightRows[2].id, 999)
end)

Test.case("currency snapshots store alt crest amounts with caps", function()
    local addon = loadFeatureAddon()
    addon.TRACKING.crestCurrencyIDs = { 101 }
    addon.GetTrackedCurrencyConfig = function()
        return {
            { id = 101, enabled = true },
        }
    end
    Harness.currencyInfo[101] = {
        name = "Heroic Crest",
        iconFileID = 1,
        quantity = 7,
        maxQuantity = 90,
        totalEarned = 7,
        quality = 4,
    }

    local snap = {}
    addon:FillCurrencySnapshot(snap)
    Test.equal(#snap.rightRows, 1)
    Test.equal(snap.rightRows[1].qty, 7)
    Test.equal(snap.rightRows[1].earned, 7)
    Test.equal(snap.rightRows[1].cap, 90)
end)

Test.case("alt summary resets all currencies when a saved cap is above current cap", function()
    local addon = loadAltSummaryAddon()
    addon.TRACKING.crestCurrencyIDs = { 3445 }
    addon.TRACKING.sparkCurrencyID = 3509
    Harness.currencyInfo[3445] = {
        name = "Heroic Crest",
        iconFileID = 1,
        quantity = 0,
        maxQuantity = 0,
        totalEarned = 0,
        quality = 4,
    }
    Harness.currencyInfo[3509] = {
        name = "Spark",
        iconFileID = 2,
        quantity = 0,
        maxQuantity = 1,
        totalEarned = 0,
        quality = 4,
    }
    Harness.currencyInfo[1234] = {
        name = "Old Spark",
        iconFileID = 3,
        quantity = 0,
        maxQuantity = 24,
        totalEarned = 0,
        quality = 4,
    }

    local sd = addon:_ExtractAltSummarySnapDataForTest({
        rightRows = {
            { type = addon.SNAP_TYPES.CREST, id = 3445, qty = 11, earned = 11, cap = 90, tradeup = 5 },
            { type = addon.SNAP_TYPES.SPARKS, id = 1234, qty = 8, held = 8, cap = 24 },
        },
    }, { 3445 })

    Test.equal(sd.crestQtys[1], 0)
    Test.equal(sd.crestEarneds[1], 0)
    Test.equal(sd.crestCaps[1], 0)
    Test.equal(sd.crestTradeups[1], 0)
    Test.equal(sd.sprkQty, 0)
    Test.equal(sd.sprkCap, 1)
end)

Test.case("alt summary resets capless currencies from stale season snapshots", function()
    local addon = loadAltSummaryAddon()
    addon.TRACKING._activeSeasonNumber = 2
    addon.TRACKING.crestCurrencyIDs = { 3445 }
    addon.TRACKING.sparkCurrencyID = 3509
    Harness.currencyInfo[3445] = {
        name = "Heroic Crest",
        iconFileID = 1,
        quantity = 0,
        maxQuantity = 0,
        totalEarned = 0,
        quality = 4,
    }
    Harness.currencyInfo[3509] = {
        name = "Spark",
        iconFileID = 2,
        quantity = 0,
        maxQuantity = 1,
        totalEarned = 0,
        quality = 4,
    }

    local sd = addon:_ExtractAltSummarySnapDataForTest({
        seasonKey = "mplus:1",
        rightRows = {
            { type = addon.SNAP_TYPES.CREST, id = 3445, qty = 11, earned = 11, tradeup = 5 },
            { type = addon.SNAP_TYPES.SPARKS, id = 3509, qty = 8, held = 8 },
        },
    }, { 3445 })

    Test.equal(sd.crestQtys[1], 0)
    Test.equal(sd.crestEarneds[1], 0)
    Test.equal(sd.crestTradeups[1], 0)
    Test.equal(sd.sprkQty, 0)
    Test.equal(sd.sprkCap, 1)
end)

Test.case("alt summary does not clamp crest tradeup to current cap", function()
    local addon = loadAltSummaryAddon()
    addon.TRACKING.crestCurrencyIDs = { 3445 }
    Harness.currencyInfo[3445] = {
        name = "Heroic Crest",
        iconFileID = 1,
        quantity = 0,
        maxQuantity = 0,
        totalEarned = 0,
        quality = 4,
    }

    local sd = addon:_ExtractAltSummarySnapDataForTest({
        rightRows = {
            { type = addon.SNAP_TYPES.CREST, id = 3445, qty = 0, earned = 0, tradeup = 10 },
        },
    }, { 3445 })

    Test.equal(sd.crestQtys[1], 0)
    Test.equal(sd.crestEarneds[1], 0)
    Test.equal(sd.crestCaps[1], 0)
    Test.equal(sd.crestTradeups[1], 10)
end)

Test.case("alt summary clamps season misc currencies when current cap is zero", function()
    local addon = loadAltSummaryAddon()
    addon.TRACKING.bonusRollCurrencyID = 3418
    Harness.currencyInfo[3418] = {
        name = "Nebulous Voidcore",
        iconFileID = 1,
        quantity = 0,
        maxQuantity = 0,
        totalEarned = 0,
        quality = 4,
    }

    local sd = addon:_ExtractAltSummarySnapDataForTest({
        rightRows = {
            { type = addon.SNAP_TYPES.MISC, id = 3418, qty = 26, held = 26, cap = 90 },
        },
    }, {})

    Test.equal(sd.miscQtys[3418], 0)
    Test.equal(sd.miscCaps[3418], 0)
end)

local function loadVaultAddon()
    local addon = Harness.newAddon()
    Harness.load(addon, "features/utils/LariasWeeklyChecklist_AddonUtils.lua")
    Harness.load(addon, "features/utils/LariasWeeklyChecklist_IlvlUtils.lua")
    Harness.load(addon, "features/body/LariasWeeklyChecklist_GreatVault.lua")
    return addon
end

Test.case("great vault returns nine fallback lines without API data", function()
    local addon = loadVaultAddon()
    _G.C_WeeklyRewards = nil
    local grid, lines = addon:GetGVData()
    Test.equal(grid, nil)
    Test.equal(#lines, 9)
    Test.contains(lines[1], "Raid")
    Test.contains(lines[4], "Dungeons")
    Test.contains(lines[7], "World")
end)

Test.case("great vault groups all three activity types", function()
    local addon = loadVaultAddon()
    _G.GetDetailedItemLevelInfo = function(link) return tonumber(link:match("ilvl:(%d+)")) end
    _G.C_WeeklyRewards = {
        GetActivities = function()
            return {
                { id = 1, type = 3, progress = 2, threshold = 2 },
                { id = 2, type = 1, isComplete = true },
                { id = 3, type = 6, progress = { current = 1, required = 2 } },
            }
        end,
        GetExampleRewardItemHyperlinks = function(id) return "item:1:ilvl:" .. tostring(100 + id * 10) end,
    }
    local grid = addon:GetGVData()
    Test.equal(#grid, 3)
    Test.truthy(grid[1].available)
    Test.equal(grid[1].complete, 1)
    Test.equal(grid[2].complete, 1)
    Test.equal(grid[3].complete, 0)
    Test.equal(grid[3].slots[1].ilvl, 0)
end)

Test.case("snapshot season keys follow strongest available identity", function()
    local addon = Harness.newAddon()
    Harness.load(addon, "features/services/general/LariasWeeklyChecklist_Snapshot.lua")
    addon.TRACKING._activeSeasonNumber = 4
    addon.TRACKING._activeSeasonStartsAt = 100
    addon.TRACKING._activeSeasonName = "Midnight"
    Test.equal(addon:GetTrackingSeasonKey(), "mplus:4")
    addon.TRACKING._activeSeasonNumber = nil
    Test.equal(addon:GetTrackingSeasonKey(), "start:100")
    addon.TRACKING._activeSeasonStartsAt = nil
    Test.equal(addon:GetTrackingSeasonKey(), "name:Midnight")
end)

Test.case("snapshot season validation handles tagged and legacy data", function()
    local addon = Harness.newAddon()
    Harness.load(addon, "features/services/general/LariasWeeklyChecklist_Snapshot.lua")
    addon.TRACKING._activeSeasonNumber = 4
    Test.truthy(addon:IsTrackingSnapshotCurrentSeason({ seasonKey = "mplus:4" }))
    Test.falsy(addon:IsTrackingSnapshotCurrentSeason({ seasonKey = "mplus:3" }))
    Test.truthy(addon:IsTrackingSnapshotCurrentSeason({ rightRows = {
        { type = "crest", id = 101 },
    } }))
    Test.falsy(addon:IsTrackingSnapshotCurrentSeason({ rightRows = {
        { type = "crest", id = 999 },
    } }))
end)

Test.case("snapshot captures item upgrade watermarks by redundancy slot", function()
    local addon = loadFeatureAddon()
    Harness.load(addon, "features/services/general/LariasWeeklyChecklist_Snapshot.lua")
    addon.TRACKING.gearSlotIDs = {}
    addon.GetGVData = function() return nil, {} end
    addon.FillCurrencySnapshot = function() end
    addon.TrackingSnapshotAPI.ItemUpgrade = {
        GetHighWatermarkForSlot = function(slot)
            return 280 + slot
        end,
    }

    local snap = {}
    addon:BuildTrackingSnapshot(snap, { vault = false, gear = true, currency = false })
    Test.truthy(snap.itemUpgradeWatermarksCaptured)
    Test.equal(snap.itemUpgradeWatermarks[0], 280)
    Test.equal(snap.itemUpgradeWatermarks[16], 296)
end)

Test.case("snapshot stores item-specific high watermark on gear slots", function()
    local addon = loadFeatureAddon()
    Harness.load(addon, "features/services/general/LariasWeeklyChecklist_Snapshot.lua")
    addon.TRACKING.gearSlotIDs = { 11 }
    addon.GetGVData = function() return nil, {} end
    addon.FillCurrencySnapshot = function() end
    addon.TrackingSnapshotAPI.GetInventoryItemLink = function(_, slotID)
        return slotID == 11 and "item:ring" or nil
    end
    addon.TrackingSnapshotAPI.GetDetailedItemLevelInfo = function() return 318 end
    addon.TrackingSnapshotAPI.ItemUpgrade = {
        GetHighWatermarkForSlot = function(slot) return 280 + slot end,
        GetHighWatermarkForItem = function()
            return 321, 334
        end,
    }

    local snap = {}
    addon:BuildTrackingSnapshot(snap, { vault = false, gear = true, currency = false })
    Test.equal(snap.gearSlots[11].itemUpgradeHighWatermark, 334)
    Test.equal(snap.bestGearSlots[11].itemUpgradeHighWatermark, 334)
end)

Test.case("snapshot rejects incomplete item upgrade watermark capture", function()
    local addon = loadFeatureAddon()
    Harness.load(addon, "features/services/general/LariasWeeklyChecklist_Snapshot.lua")
    addon.TRACKING.gearSlotIDs = {}
    addon.GetGVData = function() return nil, {} end
    addon.FillCurrencySnapshot = function() end
    addon.TrackingSnapshotAPI.ItemUpgrade = {
        GetHighWatermarkForSlot = function(slot)
            if slot == 16 then return nil end
            return 280 + slot
        end,
    }

    local snap = {}
    addon:BuildTrackingSnapshot(snap, { vault = false, gear = true, currency = false })
    Test.falsy(snap.itemUpgradeWatermarksCaptured)
    Test.equal(snap.itemUpgradeWatermarks[16], nil)
end)

Test.case("snapshot item upgrade track string wins over cost currency tier correction", function()
    local addon = loadFeatureAddon()
    Harness.load(addon, "features/services/general/LariasWeeklyChecklist_Snapshot.lua")
    addon.TRACKING.crestCurrencyIDs = { 101, 102, 103, 104, 105 }
    addon.TRACKING.gearSlotIDs = { 1 }
    addon.TRACKING.ilvlBase = 100
    addon.TRACKING.ilvlTrackStep = 10
    addon.TRACKING.ilvlRankOffsets = { 0, 3, 6, 10, 13, 16 }
    addon.GetGVData = function() return nil, {} end
    addon.FillCurrencySnapshot = function() end
    addon.TrackingSnapshotAPI.GetInventoryItemLink = function(_, slotID)
        return slotID == 1 and "item:champion" or nil
    end
    addon.TrackingSnapshotAPI.GetDetailedItemLevelInfo = function() return 110 end
    addon.TrackingSnapshotAPI.Item = {
        GetItemUpgradeInfo = function()
            return { currentLevel = 1, maxLevel = 6, trackString = "Champion" }
        end,
    }
    addon.TrackingSnapshotAPI.ItemLocation = {
        CreateFromEquipmentSlot = function(slotID) return { slotID = slotID } end,
    }
    addon.TrackingSnapshotAPI.ItemUpgrade = {
        SetItemUpgradeFromLocation = function() end,
        GetItemUpgradeItemInfo = function()
            return {
                currUpgrade = 1,
                maxUpgrade = 6,
                upgradeLevelInfos = {
                    { currencyCostsToUpgrade = { { currencyID = 102, cost = 20 } } },
                },
            }
        end,
        ClearItemUpgrade = function() end,
    }

    local snap = {}
    addon:BuildTrackingSnapshot(snap, { vault = false, gear = true, currency = false })
    Test.equal(snap.gearSlots[1].tierIdx, 3)
    Test.equal(snap.gearSlots[1].rank, 1)
    Test.equal(snap.gearSlots[1].maxRank, 6)
    Test.truthy(snap.gearSlots[1].trackTierConfirmed)
end)

Test.case("snapshot parses upgrade track and rank from item tooltip", function()
    local addon = loadFeatureAddon()
    Harness.load(addon, "features/services/general/LariasWeeklyChecklist_Snapshot.lua")
    addon.TRACKING.crestCurrencyIDs = { 101, 102, 103, 104, 105 }
    addon.TRACKING.gearSlotIDs = { 1 }
    addon.TRACKING.ilvlBase = 100
    addon.TRACKING.ilvlTrackStep = 10
    addon.TRACKING.ilvlRankOffsets = { 0, 3, 6, 10, 13, 16 }
    addon.GetGVData = function() return nil, {} end
    addon.FillCurrencySnapshot = function() end
    addon.TrackingSnapshotAPI.GetInventoryItemLink = function(_, slotID)
        return slotID == 1 and "item:champion-tooltip" or nil
    end
    addon.TrackingSnapshotAPI.GetDetailedItemLevelInfo = function() return 110 end
    addon.TrackingSnapshotAPI.Item = {
        GetItemUpgradeInfo = function() return nil end,
    }
    addon.TrackingSnapshotAPI.TooltipInfo = {
        GetHyperlink = function()
            return {
                lines = {
                    { leftText = "Soulbound" },
                    { leftText = "|cffa335eeUpgrade Level: Champion 1/6|r" },
                },
            }
        end,
    }
    addon.TrackingSnapshotAPI.ItemLocation = {
        CreateFromEquipmentSlot = function(slotID) return { slotID = slotID } end,
    }
    addon.TrackingSnapshotAPI.ItemUpgrade = {
        SetItemUpgradeFromLocation = function() end,
        GetItemUpgradeItemInfo = function()
            return {
                currUpgrade = 1,
                maxUpgrade = 6,
                upgradeLevelInfos = {
                    { currencyCostsToUpgrade = { { currencyID = 102, cost = 20 } } },
                },
            }
        end,
        ClearItemUpgrade = function() end,
    }

    local snap = {}
    addon:BuildTrackingSnapshot(snap, { vault = false, gear = true, currency = false })
    Test.equal(snap.gearSlots[1].tierIdx, 3)
    Test.equal(snap.gearSlots[1].rank, 1)
    Test.equal(snap.gearSlots[1].maxRank, 6)
    Test.truthy(snap.gearSlots[1].trackTierConfirmed)
end)

Test.case("snapshot treats explicitly non-upgradeable tracked items as capped", function()
    local addon = loadFeatureAddon()
    Harness.load(addon, "features/services/general/LariasWeeklyChecklist_Snapshot.lua")
    addon.TRACKING.crestCurrencyIDs = { 101, 102, 103, 104, 105 }
    addon.TRACKING.gearSlotIDs = { 1 }
    addon.TRACKING.ilvlBase = 100
    addon.TRACKING.ilvlTrackStep = 10
    addon.TRACKING.ilvlRankOffsets = { 0, 3, 6, 10, 13, 16 }
    addon.GetGVData = function() return nil, {} end
    addon.FillCurrencySnapshot = function() end
    addon.TrackingSnapshotAPI.GetInventoryItemLink = function(_, slotID)
        return slotID == 1 and "item:veteran-capped" or nil
    end
    addon.TrackingSnapshotAPI.GetDetailedItemLevelInfo = function() return 120 end
    addon.TrackingSnapshotAPI.Item = {
        GetItemUpgradeInfo = function() return nil end,
    }
    addon.TrackingSnapshotAPI.TooltipInfo = {
        GetHyperlink = function()
            return {
                lines = {
                    { leftText = "Upgrade Level: Veteran 4/6" },
                },
            }
        end,
    }
    addon.TrackingSnapshotAPI.ItemLocation = {
        CreateFromEquipmentSlot = function(slotID) return { slotID = slotID } end,
    }
    addon.TrackingSnapshotAPI.ItemUpgrade = {
        SetItemUpgradeFromLocation = function() end,
        GetItemUpgradeItemInfo = function()
            return {
                itemUpgradeable = false,
                currUpgrade = 4,
                maxUpgrade = 6,
                upgradeLevelInfos = {},
            }
        end,
        ClearItemUpgrade = function() end,
    }

    local snap = {}
    addon:BuildTrackingSnapshot(snap, { vault = false, gear = true, currency = false })
    Test.equal(snap.gearSlots[1].tierIdx, 2)
    Test.equal(snap.gearSlots[1].rank, 4)
    Test.equal(snap.gearSlots[1].trueMaxRank, 4)
    Test.equal(snap.gearSlots[1].upgradeCostRemaining, 0)
    Test.equal(addon:CalcTierUpgradeCost(snap, 2), 0)
end)

local function loadFooterAddon()
    local addon = Harness.newAddon({ LOCALE_REGISTRY_KEY = "LWMC_TEST_LOCALES" })
    addon.EnsurePrefs = function(self)
        self.db = self.db or { global = {} }
        return self.db.global
    end
    addon.EnsureDB = function(self)
        self.charDb = self.charDb or {}
        return self.charDb
    end
    Harness.load(addon, "features/footer/LariasWeeklyChecklist_Footer.lua")
    return addon
end

Test.case("opacity clamps to supported range", function()
    local addon = loadFooterAddon()
    addon.db = { global = { uiOpacityPct = 10 } }
    Test.equal(addon:GetUIOpacityAlpha(), 0.5)
    addon.db.global.uiOpacityPct = 80
    Test.equal(addon:GetUIOpacityAlpha(), 0.8)
    addon.db.global.uiOpacityPct = 150
    Test.equal(addon:GetUIOpacityAlpha(), 1)
end)

Test.case("opacity refreshes surfaces banner and slider", function()
    local addon = loadFooterAddon()
    addon.db = { global = { uiOpacityPct = 75 } }
    addon._statusBanner = Harness.newFrame()
    local surfaces, slider = 0, 0
    addon.RefreshWindowSurfaces = function() surfaces = surfaces + 1 end
    addon._inFrameScaleSlider = { SyncOpacity = function() slider = slider + 1 end }
    addon:ApplyOpacity()
    Test.equal(addon._statusBanner:GetAlpha(), 0.75)
    Test.equal(surfaces, 1)
    Test.equal(slider, 1)
end)

Test.case("status banner gives sheet updates priority", function()
    local addon = loadFooterAddon()
    _G.LWMC_TEST_LOCALES = { sheet_version = "Week 2", strings = {} }
    addon.charDb = { _newestSeenRemoteSheetVersion = "Week 5" }
    addon.GetEffectiveLocaleCode = function() return "enUS" end
    addon.ShouldShowSheetUpdateNotice = function() return true end
    addon.ShouldShowUpdateNotice = function() return true end
    addon:CreateStatusBanner(Harness.newFrame())
    addon:UpdateStatusBanner()
    Test.contains(addon._statusBanner._label:GetText(), "3 version")
end)

Test.case("status banner clears when no notice applies", function()
    local addon = loadFooterAddon()
    addon.GetEffectiveLocaleCode = function() return "enUS" end
    addon.ShouldShowSheetUpdateNotice = function() return false end
    addon.ShouldShowUpdateNotice = function() return false end
    addon:CreateStatusBanner(Harness.newFrame())
    addon._statusBanner._label:SetText("old")
    addon:UpdateStatusBanner()
    Test.equal(addon._statusBanner._label:GetText(), "")
end)

local function loadReminderAddon()
    local addon = Harness.newAddon()
    local prefs = {}
    local modal = {
        holder = Harness.newFrame(), label = Harness.newFrame(), closeBtn = Harness.newFrame(),
        buttons = { Harness.newFrame() },
    }
    addon.EnsurePrefs = function() return prefs end
    addon.EnsureAddonModal = function() return modal end
    addon.ShowAddonModal = function(_, _, config) addon.shownReminder = config end
    addon.HideAddonModal = function() addon.hiddenReminder = true end
    Harness.load(addon, "features/warnings/LariasWeeklyChecklist_RaidBonusRollReminder.lua")
    return addon, prefs
end

Test.case("bonus roll reminder stays hidden outside supported instances", function()
    local addon, prefs = loadReminderAddon()
    addon:UpdateRaidBonusRollReminder()
    Test.equal(prefs.raidBonusRollReminderLastShownInstanceKey, nil)
    Test.truthy(addon.hiddenReminder)
    Test.equal(addon.shownReminder, nil)
end)

Test.case("bonus roll reminder shows once and persists its instance gate", function()
    local addon, prefs = loadReminderAddon()
    addon.TRACKING.bonusRollCurrencyID = 500
    Harness.currencyInfo[500] = {
        name = "Bonus Roll", quantity = 0, maxWeeklyQuantity = 2,
        maxQuantity = 2, quantityEarnedThisWeek = 1,
    }
    _G.IsInInstance = function() return true, "raid" end
    _G.GetInstanceInfo = function() return "Test Raid", "raid", 15, "Heroic", 0, 0, false, 77 end
    addon:UpdateRaidBonusRollReminder()
    Test.truthy(addon.shownReminder)
    Test.contains(prefs.raidBonusRollReminderLastShownInstanceKey, "raid:77:15")
    addon.shownReminder = nil
    addon:UpdateRaidBonusRollReminder()
    Test.equal(addon.shownReminder, nil)
end)

Test.case("bonus roll reminder suppresses complete weekly progress", function()
    local addon = loadReminderAddon()
    addon.TRACKING.bonusRollCurrencyID = 500
    Harness.currencyInfo[500] = {
        quantity = 0, maxWeeklyQuantity = 2, maxQuantity = 2,
        quantityEarnedThisWeek = 2,
    }
    _G.IsInInstance = function() return true, "party" end
    _G.GetInstanceInfo = function() return "Test Dungeon", "party", 8, "Mythic", 0, 0, false, 88 end
    addon:UpdateRaidBonusRollReminder()
    Test.equal(addon.shownReminder, nil)
    Test.truthy(addon.hiddenReminder)
end)

Test.case("disabled bonus roll reminder exits before instance checks", function()
    local addon, prefs = loadReminderAddon()
    prefs.raidBonusRollReminderDisabled = true
    _G.IsInInstance = function() error("should not run") end
    addon:UpdateRaidBonusRollReminder()
    Test.truthy(addon.hiddenReminder)
end)

local function loadUpgradeWarningAddon()
    local addon = loadFeatureAddon()
    local prefs = {}
    local holder = Harness.newFrame()
    addon.EnsurePrefs = function() return prefs end
    addon.NewThemedFrame = function() return holder end
    addon.ApplyWarningPanelTheme = function() return 40 end
    addon.Controls = {
        NewActionButton = function(parent) return Harness.newFrame(parent) end,
        StyleButton = function() end,
    }
    _G.ItemUpgradeFrame = Harness.newFrame()
    _G.hooksecurefunc = function() end
    Harness.load(addon, "features/warnings/LariasWeeklyChecklist_UpgradeWarning.lua")
    return addon, prefs, holder
end

Test.case("upgrade warning shows for rank-one higher-tier crest costs", function()
    local addon, _, holder = loadUpgradeWarningAddon()
    _G.C_ItemUpgrade = {
        GetItemUpgradeItemInfo = function()
            return {
                currUpgrade = 1,
                maxUpgrade = 6,
                upgradeLevelInfos = {
                    [2] = { currencyCostsToUpgrade = { { currencyID = 102, cost = 20 } } },
                },
            }
        end,
    }
    addon:CheckUpgradeWarning()
    Test.truthy(holder:IsShown())
end)

Test.case("upgrade warning ignores first-tier crest upgrades", function()
    local addon, _, holder = loadUpgradeWarningAddon()
    _G.C_ItemUpgrade = {
        GetItemUpgradeItemInfo = function()
            return {
                currUpgrade = 1,
                maxUpgrade = 6,
                upgradeLevelInfos = {
                    [2] = { currencyCostsToUpgrade = { { currencyID = 101, cost = 20 } } },
                },
            }
        end,
    }
    addon:CheckUpgradeWarning()
    Test.falsy(holder:IsShown())
end)

Test.case("disabled upgrade warning exits before reading upgrade APIs", function()
    local addon, prefs, holder = loadUpgradeWarningAddon()
    prefs.upgradeWarnDisabled = true
    _G.C_ItemUpgrade = {
        GetItemUpgradeItemInfo = function() error("should not run") end,
    }
    addon:CheckUpgradeWarning()
    Test.falsy(holder:IsShown())
end)
