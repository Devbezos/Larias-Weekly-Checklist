-- LariasWeeklyChecklist_UpgradeWarning.lua
-- Watches the item-upgrade UI and warns the player when they are about to
-- upgrade an item that is still at 1/6 (the first upgrade rank).
-- Upgrading from 1/6 uses the most crests per ilvl gain; a quick visual
-- reminder helps avoid accidental inefficient upgrades.
--
-- Option: prefs.upgradeWarnDisabled  (bool, default false = warnings enabled)
-- The player can silence the warning via Interface → Larias's Weekly Checklist.
local addonName = ...
local Addon = _G[addonName]
if not Addon then return end

local L = Addon.L or {}

local _upgradeWarnLabel  -- FontString injected into ItemUpgradeFrame

-- ── Core check ────────────────────────────────────────────────────────────────

--- Called whenever the item upgrade frame shows or a new item is slotted.
--- Shows an alert if the item is at its first upgrade rank (e.g. 1/6).
function Addon:CheckUpgradeWarning()
    -- Always clear the label first so stale text never lingers.
    if _upgradeWarnLabel then _upgradeWarnLabel.holder:Hide() end

    local prefs = self:EnsurePrefs()
    if prefs.upgradeWarnDisabled then return end

    if not (C_ItemUpgrade and C_ItemUpgrade.GetItemUpgradeItemInfo) then return end

    local info = C_ItemUpgrade.GetItemUpgradeItemInfo()
    if not info then return end

    local currentLevel = tonumber(info.currUpgrade)
    local maxLevel     = tonumber(info.maxUpgrade)
    if not (currentLevel and maxLevel) then return end

    -- Only warn when item is at rank 1 (unupgraded) out of 2 or more ranks.
    if maxLevel < 2 or currentLevel > 1 then return end

    local body = string.format(
        L.UPGRADE_WARN_MSG or "Item is at %d/%d upgrades \226\128\148 upgrading now costs the most crests per ilvl.",
        currentLevel, maxLevel)

    if _upgradeWarnLabel then
        _upgradeWarnLabel.label:SetText(body)
        _upgradeWarnLabel.holder:ClearAllPoints()
        local btn = ItemUpgradeFrame and ItemUpgradeFrame.UpgradeButton
        if btn then
            _upgradeWarnLabel.holder:SetPoint("BOTTOM", btn, "TOP", 0, 8)
        else
            _upgradeWarnLabel.holder:SetPoint("BOTTOM", ItemUpgradeFrame, "BOTTOM", 0, 70)
        end
        print("|cFFFFAA00[LWC]|r showing label, btn=" .. tostring(btn ~= nil))
        _upgradeWarnLabel.holder:Show()
    end

    if UIErrorsFrame and UIErrorsFrame.AddMessage then
        UIErrorsFrame:AddMessage("|cFFFFAA00" .. body .. "|r", 1, 0.8, 0)
    end
end

-- ── Deferred setup ────────────────────────────────────────────────────────────
-- C_ItemUpgrade and ItemUpgradeFrame only exist after Blizzard_ItemUpgradeUI
-- loads on demand. We wait for it via ADDON_LOADED, then hook in.

local function SetupHooks()
    if ItemUpgradeFrame then
        -- Simple standalone warning frame parented to UIParent.
        local holder = CreateFrame("Frame", "LWCUpgradeWarnHolder", UIParent)
        holder:SetFrameStrata("DIALOG")
        holder:SetSize(400, 40)
        holder:Hide()
        local label = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalMed2")
        label:SetAllPoints()
        label:SetTextColor(1, 0.75, 0)
        label:SetJustifyH("CENTER")
        label:SetWordWrap(true)
        _upgradeWarnLabel = { holder = holder, label = label }

        hooksecurefunc(ItemUpgradeFrame, "Show", function()
            if Addon.CheckUpgradeWarning then Addon:CheckUpgradeWarning() end
        end)
        hooksecurefunc(ItemUpgradeFrame, "Hide", function()
            if _upgradeWarnLabel then _upgradeWarnLabel.holder:Hide() end
        end)
    end

    local slotFrame = CreateFrame("Frame")
    slotFrame:RegisterEvent("ITEM_UPGRADE_MASTER_SET_ITEM")
    slotFrame:SetScript("OnEvent", function()
        if Addon.CheckUpgradeWarning then Addon:CheckUpgradeWarning() end
    end)
end

-- Handle the case where Blizzard_ItemUpgradeUI was already loaded (UI reload).
if C_ItemUpgrade then
    SetupHooks()
else
    local setupFrame = CreateFrame("Frame")
    setupFrame:RegisterEvent("ADDON_LOADED")
    setupFrame:SetScript("OnEvent", function(_, _, loadedAddon)
        if loadedAddon ~= "Blizzard_ItemUpgradeUI" then return end
        setupFrame:UnregisterAllEvents()
        SetupHooks()
    end)
end

-- ── Locale key reference (for translators) ────────────────────────────────────
-- L.UPGRADE_WARN_MSG             — Full warning sentence shown in the error frame.
-- L.OPTIONS_DISABLE_UPGRADE_WARN — Label for the Settings panel checkbox.
