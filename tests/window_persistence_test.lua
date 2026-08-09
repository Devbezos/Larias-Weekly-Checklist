local Test = _G.LWMC_TEST
local Harness = _G.LWMC_HARNESS

Test.case("LibWindow drag stop saves and restores frame placement", function()
    Harness.installGlobals()
    local libWindow = Harness.loadLibWindow()
    local storage = {}
    local original = Harness.newFrame(_G.UIParent)
    original:SetSize(300, 200)
    original.left, original.right = 240, 540
    original.bottom, original.top = 180, 380
    libWindow.RegisterConfig(original, storage)
    libWindow.MakeDraggable(original)

    original:GetScript("OnDragStart")(original)
    original:GetScript("OnDragStop")(original)
    Test.truthy(storage.point)
    Test.truthy(storage.x)
    Test.truthy(storage.y)
    Test.equal(storage.scale, 1)

    local restored = Harness.newFrame(_G.UIParent)
    restored:SetSize(300, 200)
    libWindow.RegisterConfig(restored, storage)
    libWindow.RestorePosition(restored)
    local point, parent, relativePoint, x, y = restored:GetPoint()
    Test.equal(point, storage.point)
    Test.equal(parent, _G.UIParent)
    Test.equal(relativePoint, storage.point)
    Test.equal(x, storage.x)
    Test.equal(y, storage.y)
end)

Test.case("full reset clears reusable window storage and live positions", function()
    local addon = Harness.newAddon()
    local libWindow = Harness.loadLibWindow()
    local global = {
        chars = {
            ["Tester - Realm"] = {
                checked = { item = true },
                collapsedSections = { section = true },
                sectionCompleted = { section = true },
            },
        },
        mainFrameWin = {},
        altSummaryWin = { point = "TOP", x = 10, y = -20, scale = 1 },
        currencyConfigWin = { point = "LEFT", x = 30, y = 40, scale = 1 },
        crestConvertWin = { point = "RIGHT", x = -30, y = 40, scale = 1 },
        themeColors = { bgR = 0.2 },
        uiScalePct = 120,
        uiOpacityPct = 90,
    }
    addon.db = { global = global }
    addon.GetCurrentProfileKey = function() return "Tester - Realm" end
    addon.ApplyThemeColors = function() end
    addon.ApplyUIScale = function() end
    addon.ApplyOpacity = function() end
    addon.RequestRefresh = function() end

    local main = Harness.newFrame(_G.UIParent)
    main:SetSize(500, 400)
    main.left, main.right, main.bottom, main.top = 200, 700, 100, 500
    libWindow.RegisterConfig(main, global.mainFrameWin)
    addon._mainFrame = main
    addon._altsSummaryFrame = Harness.newFrame(_G.UIParent)
    addon._altsSummaryFrame._wasMoved = true
    addon._currencyConfigPopup = Harness.newFrame(_G.UIParent)
    addon._crestConvertPanel = Harness.newFrame(_G.UIParent)

    Harness.load(addon, "features/services/general/LariasWeeklyChecklist_Popups.lua")
    addon:PerformFullReset()

    Test.equal(next(global.altSummaryWin), nil)
    Test.equal(next(global.currencyConfigWin), nil)
    Test.equal(next(global.crestConvertWin), nil)
    Test.equal(global.uiScalePct, 100)
    Test.equal(global.uiOpacityPct, 65)
    Test.equal(rawget(addon._altsSummaryFrame, "_wasMoved"), nil)
    Test.equal(addon._altsSummaryFrame:GetPoint(), "CENTER")
    Test.equal(addon._currencyConfigPopup:GetPoint(), "CENTER")
    Test.truthy(global.mainFrameWin.point)
    Test.equal(main:GetPoint(), global.mainFrameWin.point)
    Test.equal(next(global.chars["Tester - Realm"].checked), nil)
end)
