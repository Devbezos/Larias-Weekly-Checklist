local Test = _G.LWMC_TEST
local Harness = _G.LWMC_HARNESS

local function loadDatabase()
    local addon = Harness.newAddon()
    addon.db = {
        global = {
            chars = {},
            trackedLootChars = {},
            altSummaryCharOrder = {},
            altSummarySectionOrder = {},
            altSummaryRowOrder = {},
        },
        sv = { profileKeys = {} },
    }
    addon.GetCurrentProfileKey = function() return "Tester - Realm" end
    addon.RequestTrackingUpdate = function(self) self.refreshCount = (self.refreshCount or 0) + 1 end
    addon.RequestRefresh = function(self) self.listRefreshCount = (self.listRefreshCount or 0) + 1 end
    Harness.load(addon, "features/services/general/LariasWeeklyChecklist_Database.lua")
    return addon
end

Test.case("EnsureDB creates character defaults once", function()
    local addon = loadDatabase()
    local first = addon:EnsureDB()
    local second = addon:EnsureDB()
    Test.equal(first, second)
    Test.equal(first.startAtSectionId, "")
    Test.truthy(first.checked)
    Test.truthy(first.collapsedSections)
    Test.truthy(first.trackingSnapshot)
    Test.truthy(first.sectionCompleted)
end)

Test.case("EnsureDB follows the viewed character", function()
    local addon = loadDatabase()
    addon._viewingChar = "Alt - Realm"
    local database = addon:EnsureDB()
    Test.equal(database, addon.db.global.chars["Alt - Realm"])
end)

Test.case("currency hidden state is character-specific", function()
    local addon = loadDatabase()
    addon:SetCurrencyHidden(101, true)
    Test.truthy(addon:IsCurrencyHidden(101))
    addon._viewingChar = "Alt - Realm"
    Test.falsy(addon:IsCurrencyHidden(101))
    addon:SetCurrencyHidden(101, true)
    Test.truthy(addon:IsCurrencyHidden(101))
end)

Test.case("unhiding currency removes its saved key", function()
    local addon = loadDatabase()
    addon:SetCurrencyHidden(101, true)
    addon:SetCurrencyHidden(101, false)
    Test.falsy(addon:IsCurrencyHidden(101))
    Test.equal(addon.db.global.chars["Tester - Realm"].hiddenCurrencies["101"], nil)
end)

Test.case("delve boss quest compatibility key stays synchronized", function()
    local addon = loadDatabase()
    addon:SetQuestHidden("delveBoss", true)
    local hidden = addon.db.global.chars["Tester - Realm"].hiddenQuests
    Test.truthy(hidden.delveBoss)
    Test.truthy(hidden.nullaeusSpoils)
    addon:SetQuestHidden("delveBoss", false)
    Test.falsy(addon:IsQuestHidden("delveBoss"))
end)

Test.case("legacy delve quest key is recognized", function()
    local addon = loadDatabase()
    addon:EnsureDB().hiddenQuests = { nullaeusSpoils = true }
    Test.truthy(addon:IsQuestHidden("delveBoss"))
end)

Test.case("item hidden state validates numeric IDs", function()
    local addon = loadDatabase()
    addon:SetItemHidden("55", true)
    addon:SetItemHidden("bad", true)
    Test.truthy(addon:IsItemHidden(55))
    Test.falsy(addon:IsItemHidden("bad"))
end)

Test.case("hidden currency list resolves names and sorts", function()
    local addon = loadDatabase()
    Harness.currencyInfo[101] = { name = "Zulu" }
    Harness.currencyInfo[102] = { name = "Alpha" }
    local database = addon:EnsureDB()
    database.hiddenCurrencies = { ["101"] = true, ["102"] = true }
    local result = addon:GetHiddenCurrencyList()
    Test.equal(result[1].name, "Alpha")
    Test.equal(result[2].name, "Zulu")
end)

Test.case("hidden item list falls back to ID and sorts", function()
    local addon = loadDatabase()
    Harness.itemInfo[20] = { name = "Alpha Item" }
    local database = addon:EnsureDB()
    database.hiddenItems = { ["20"] = true, ["10"] = true }
    local result = addon:GetHiddenItemList()
    Test.equal(result[1].name, "10")
    Test.equal(result[2].name, "Alpha Item")
end)

Test.case("hidden quest list uses localized labels", function()
    local addon = loadDatabase()
    addon.L.TRACKING_QUEST_WEEKLY_PREY = "Localized Prey"
    addon:EnsureDB().hiddenQuests = { weeklyPrey = true }
    Test.equal(addon:GetHiddenQuestList()[1].name, "Localized Prey")
end)

Test.case("own character cannot be tracked as alt loot", function()
    local addon = loadDatabase()
    addon:SetLootCharTracked("tester - realm", true)
    Test.equal(next(addon.db.global.trackedLootChars), nil)
end)

Test.case("tracked loot characters sort by item level then name", function()
    local addon = loadDatabase()
    addon.db.global.trackedLootChars = {
        ["Beta - Realm"] = true,
        ["Alpha - Realm"] = true,
        ["Low - Realm"] = true,
    }
    addon.db.global.chars = {
        ["Beta - Realm"] = { ilvl = 600 },
        ["Alpha - Realm"] = { ilvl = 600 },
        ["Low - Realm"] = { ilvl = 500 },
    }
    Test.same(addon:GetTrackedLootCharKeys(), {
        "Alpha - Realm", "Beta - Realm", "Low - Realm",
    })
end)

Test.case("alt character order removes duplicates and preserves omitted entries", function()
    local addon = loadDatabase()
    addon.db.global.altSummaryCharOrder = { "A", "B", "A" }
    Test.same(addon:GetAltSummaryCharOrder(), { "A", "B" })
    addon:SetAltSummaryCharOrder({ "B", "C", "B" })
    Test.same(addon.db.global.altSummaryCharOrder, { "B", "C", "A" })
end)

Test.case("alt section order removes invalid keys", function()
    local addon = loadDatabase()
    addon.db.global.altSummarySectionOrder = { "raid", "", 4, "vault", "raid" }
    Test.same(addon:GetAltSummarySectionOrder(), { "raid", "vault" })
end)

Test.case("alt row order is isolated by section", function()
    local addon = loadDatabase()
    addon:SetAltSummaryRowOrder("raid", { "boss2", "boss1", "boss2" })
    addon:SetAltSummaryRowOrder("vault", { "slot1" })
    Test.same(addon:GetAltSummaryRowOrder("raid"), { "boss2", "boss1" })
    Test.same(addon:GetAltSummaryRowOrder("vault"), { "slot1" })
    Test.same(addon:GetAltSummaryRowOrder(""), {})
end)

Test.case("Great Vault hidden blocks validate and sort", function()
    local addon = loadDatabase()
    addon:SetGVBlockHidden(3, true)
    addon:SetGVBlockHidden(1, true)
    addon:EnsureDB().hiddenGVBlocks["9"] = true
    local result = addon:GetHiddenGVBlockList()
    Test.equal(result[1].name, "Raid")
    Test.equal(result[2].name, "World")
    Test.equal(#result, 2)
end)

Test.case("database setup prunes deprecated season one currencies", function()
    local addon = Harness.newAddon()
    addon.GetCurrentProfileKey = function() return "Tester - Realm" end
    Harness.load(addon, "features/services/general/LariasWeeklyChecklist_Database.lua")

    _G.LibStub = function(name)
        if name ~= "AceDB-3.0" then return nil end
        return {
            New = function(_, _, defaults)
                defaults.global.trackedCurrencyConfig = {
                    { id = 3383, enabled = true },
                    { id = 3442, enabled = true },
                    { id = 3418, enabled = true },
                    { id = 9999, enabled = true, source = "custom" },
                }
                defaults.global.chars = {
                    ["Tester - Realm"] = {
                        hiddenCurrencies = {
                            ["3341"] = true,
                            ["3443"] = true,
                        },
                    },
                }
                return {
                    global = defaults.global,
                    profile = {},
                    sv = { profileKeys = {} },
                }
            end,
        }
    end

    addon:SetupAddonDB()

    Test.same(addon.db.global.trackedCurrencyConfig, {
        { id = 3442, enabled = true },
        { id = 9999, enabled = true, source = "custom" },
    })
    Test.equal(addon.db.global.chars["Tester - Realm"].hiddenCurrencies["3341"], nil)
    Test.truthy(addon.db.global.chars["Tester - Realm"].hiddenCurrencies["3443"])
end)

local function loadCharacterPicker()
    local addon = loadDatabase()
    Harness.load(addon, "features/footer/LariasWeeklyChecklist_CharPicker.lua")
    return addon
end

Test.case("character picker merges profile and character keys", function()
    local addon = loadCharacterPicker()
    addon.db.sv.profileKeys = {
        ["Beta - Realm"] = "Beta - Realm",
        invalid = "invalid",
    }
    addon.db.global.chars = { ["Alpha - Realm"] = {}, ["Beta - Realm"] = {} }
    Test.same(addon:GetCharProfileKeys(), { "Alpha - Realm", "Beta - Realm" })
end)

Test.case("character picker prunes malformed metadata keys", function()
    local addon = loadCharacterPicker()
    addon.db.global.charClasses = { invalid = "MAGE", ["Alt - Realm"] = "WARRIOR" }
    addon.db.global.charLevels = { invalid = 80, ["Alt - Realm"] = 80 }
    addon:GetCharProfileKeys()
    Test.equal(addon.db.global.charClasses.invalid, nil)
    Test.equal(addon.db.global.charLevels.invalid, nil)
    Test.equal(addon.db.global.charClasses["Alt - Realm"], "WARRIOR")
end)

Test.case("max-level character check uses current expansion cap", function()
    local addon = loadCharacterPicker()
    addon.db.global.charLevels = { ["Max - Realm"] = 80, ["Low - Realm"] = 79 }
    Test.truthy(addon:IsMaxLevelChar("Max - Realm"))
    Test.falsy(addon:IsMaxLevelChar("Low - Realm"))
end)

Test.case("pickable characters require class level and snapshot data", function()
    local addon = loadCharacterPicker()
    addon.db.global.charLevels = { ["Alt - Realm"] = 80 }
    addon.db.global.charClasses = { ["Alt - Realm"] = "WARRIOR" }
    addon.db.global.chars = { ["Alt - Realm"] = { trackingSnapshot = { rightRows = { { qty = 1 } } } } }
    addon.db.sv.profileKeys = { ["Alt - Realm"] = true }
    Test.truthy(addon:HasPickableChars())
    addon.db.global.hiddenChars = { ["Alt - Realm"] = true }
    Test.falsy(addon:HasPickableChars())
end)

Test.case("view switching updates state and requests refresh", function()
    local addon = loadCharacterPicker()
    local selected
    addon.SelectMainTab = function(_, tab) selected = tab end
    addon:SetViewingChar("Alt - Realm")
    Test.equal(addon._viewingChar, "Alt - Realm")
    Test.equal(selected, 1)
    Test.equal(addon.listRefreshCount, 1)
    addon:SetViewingChar("Tester - Realm")
    Test.equal(addon._viewingChar, nil)
end)
