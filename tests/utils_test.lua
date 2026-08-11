local Test = _G.LWMC_TEST
local Harness = _G.LWMC_HARNESS

local function loadUtilities()
    local addon = Harness.newAddon()
    Harness.load(addon, "features/utils/LariasWeeklyChecklist_AddonUtils.lua")
    Harness.load(addon, "features/utils/LariasWeeklyChecklist_IlvlUtils.lua")
    return addon, addon.AddonUtils, addon.IlvlUtils
end

Test.case("color wrapper emits WoW escape codes", function()
    local _, utils = loadUtilities()
    Test.equal(utils.ColorWrap("ffffffff", "Text"), "|cffffffffText|r")
end)

Test.case("non-empty text ignores color escapes and whitespace", function()
    local _, utils = loadUtilities()
    Test.falsy(utils.IsNonEmptyText("  |r  "))
    Test.truthy(utils.IsNonEmptyText("|cffffffffValue|r"))
    Test.falsy(utils.IsNonEmptyText(nil))
end)

Test.case("progress formatting handles capped and uncapped values", function()
    local _, utils = loadUtilities()
    Test.equal(utils.FormatXY(3, 8), "3/8")
    Test.equal(utils.FormatXY(3, 0), "3")
    Test.equal(utils.FormatXY(nil, nil), "0")
end)

Test.case("progress colors cover empty partial and complete", function()
    local _, utils = loadUtilities()
    Test.equal(utils.ColorForXY(0, 10), utils.COLORS.red)
    Test.equal(utils.ColorForXY(5, 10), utils.COLORS.yellow)
    Test.equal(utils.ColorForXY(10, 10), utils.COLORS.green)
end)

Test.case("currency helpers validate IDs and return API fields", function()
    local _, utils = loadUtilities()
    Harness.currencyInfo[101] = { name = "Veteran Crest", iconFileID = 999 }
    Test.equal(utils.GetCurrencyName(101), "Veteran Crest")
    Test.equal(utils.GetCurrencyIcon("101"), 999)
    Test.equal(utils.GetCurrencyInfo(0), nil)
end)

Test.case("item helper validates IDs and returns item names", function()
    local _, utils = loadUtilities()
    Harness.itemInfo[55] = { name = "Test Item" }
    Test.equal(utils.GetItemName(55), "Test Item")
    Test.equal(utils.GetItemName("bad"), nil)
end)

Test.case("array movement handles forward and backward moves", function()
    local _, utils = loadUtilities()
    local values = { "a", "b", "c" }
    utils.MoveArrayEntry(values, 1, 3)
    Test.same(values, { "b", "c", "a" })
    utils.MoveArrayEntry(values, 3, 1)
    Test.same(values, { "a", "b", "c" })
end)

Test.case("array movement clamps invalid indexes", function()
    local _, utils = loadUtilities()
    local values = { "a", "b", "c" }
    utils.MoveArrayEntry(values, -10, 99)
    Test.same(values, { "b", "c", "a" })
    Test.equal(utils.MoveArrayEntry("bad", 1, 2), "bad")
end)

Test.case("cursor offsets account for frame scale", function()
    local _, utils = loadUtilities()
    local frame = Harness.newFrame()
    frame.left, frame.top, frame.scale = 10, 60, 2
    Test.equal(utils.GetFrameCursorOffset(frame, "x"), 15)
    Test.equal(utils.GetFrameCursorOffset(frame, "y"), 22.5)
end)

Test.case("drag controller rejects missing state and cursor", function()
    local _, utils = loadUtilities()
    local controller = utils.CreateDragReorderController({}, {
        getCursorValue = function() return nil end,
    })
    Test.falsy(controller:Begin(nil))
    Test.falsy(controller:Begin({ sourceIdx = 1 }))
end)

Test.case("drag controller stays inactive below threshold", function()
    local _, utils = loadUtilities()
    local cursor = 10
    local activated = false
    local controller = utils.CreateDragReorderController({}, {
        threshold = 5,
        getCursorValue = function() return cursor end,
        isDragButtonDown = function() return true end,
        onActivate = function() activated = true end,
    })
    Test.truthy(controller:Begin({ sourceIdx = 1 }))
    cursor = 13
    controller:Update()
    Test.falsy(activated)
end)

Test.case("drag controller activates and commits changed target", function()
    local _, utils = loadUtilities()
    local cursor = 10
    local committed
    local controller = utils.CreateDragReorderController({}, {
        threshold = 2,
        getCursorValue = function() return cursor end,
        isDragButtonDown = function() return true end,
        getDropIndex = function() return 3 end,
        onCommit = function(_, state, target) committed = { state.sourceIdx, target } end,
    })
    controller:Begin({ sourceIdx = 1 })
    cursor = 20
    controller:Update()
    local _, didCommit = controller:Finish()
    Test.truthy(didCommit)
    Test.same(committed, { 1, 3 })
end)

Test.case("drag controller clears when mouse is released", function()
    local _, utils = loadUtilities()
    local restored = 0
    local controller = utils.CreateDragReorderController({}, {
        getCursorValue = function() return 10 end,
        isDragButtonDown = function() return false end,
        restoreDragVisual = function() restored = restored + 1 end,
    })
    controller:Begin({ sourceIdx = 1 })
    controller:Update()
    Test.equal(controller:GetState(), nil)
    Test.equal(restored, 1)
end)

Test.case("item-level tiers use configured boundaries", function()
    local _, _, ilvl = loadUtilities()
    Test.equal(ilvl.GetTier(99), 1)
    Test.equal(ilvl.GetTier(100), 1)
    Test.equal(ilvl.GetTier(110), 2)
    Test.equal(ilvl.GetTier(140), 5)
    Test.equal(ilvl.GetTier(0), nil)
end)

Test.case("item-level ranks use configured offsets", function()
    local _, _, ilvl = loadUtilities()
    Test.equal(ilvl.GetRank(100, 1), 1)
    Test.equal(ilvl.GetRank(104, 1), 3)
    Test.equal(ilvl.GetRank(110, 1), 6)
    Test.equal(ilvl.GetRank(110, nil), nil)
end)

Test.case("item-level color helpers fall back safely", function()
    local addon, _, ilvl = loadUtilities()
    Test.equal(ilvl.GetColorHex(110), "ff0088ff")
    Test.equal(ilvl.GetEscapePrefix(3), "|cFFaa00ff")
    addon.TRACKING.crestColors = nil
    Test.equal(ilvl.GetColorHex(110), "ffffffff")
    Test.equal(ilvl.GetEscapePrefix(3), "|cFFFFFFFF")
end)

Test.case("track labels use the first currency-name word", function()
    local _, _, ilvl = loadUtilities()
    Harness.currencyInfo[103] = { name = "Champion Dawncrest" }
    Test.equal(ilvl.GetCrestTrackName(3), "Champion")
    Test.equal(ilvl.GetTrackLabel(124), "Champion 3")
    Harness.currencyInfo[103] = nil
    Test.equal(ilvl.GetTrackLabel(124), nil)
end)
