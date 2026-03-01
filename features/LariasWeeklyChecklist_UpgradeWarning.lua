-- LariasWeeklyChecklist_UpgradeWarning.lua
-- Watches the item-upgrade UI and warns the player when they are about to
-- upgrade an item that is still at rank 1 of its upgrade track.
--
-- Option: prefs.upgradeWarnDisabled  (bool, default false = warnings enabled)
-- The player can silence the warning via the inline "Disable future warnings"
-- button, or via Interface → Larias's Weekly Checklist.
local addonName = ...
local Addon = _G[addonName]
if not Addon then return end

local L = Addon.L or {}

-- DEV is true when the TOC version contains a hyphen (e.g. "2.1.2-dev").
-- Evaluated lazily on first use so it reads the fully-loaded TOC metadata.
local _devChecked, _devValue
local function IsDevBuild()
    if not _devChecked then
        _devChecked = true
        local getMeta = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
        local ver = (getMeta and getMeta(addonName, "Version")) or ""
        _devValue = ver:find("-") ~= nil
    end
    return _devValue
end
local _warn  -- { holder, label, disableBtn }

-- ── Crest name helpers ───────────────────────────────────────────────────────
local CREST_LOCALE_KEYS = {
    "ILVLREF_CREST_ADV",
    "ILVLREF_CREST_VET",
    "ILVLREF_CREST_CHAMP",
    "ILVLREF_CREST_HERO",
    "ILVLREF_CREST_MYTH",
}

local function GetCrestShort(tierIdx)
    local tracking    = Addon.TRACKING
    local crestColors = tracking and tracking.crestColors or {}
    local name = L[CREST_LOCALE_KEYS[tierIdx]] or CREST_LOCALE_KEYS[tierIdx]
    local hex  = crestColors[tierIdx]
    -- strip any trailing period WoW may append to the global string
    name = name:gsub("%.$", "")
    return hex and ("|cFF" .. hex .. name .. "|r") or name
end

-- ── Core check ────────────────────────────────────────────────────────────────

--- Called whenever the item upgrade frame shows or a new item is slotted.
--- Shows a warning when item is at rank 1 on a track that has a cheaper
--- previous track (Veteran, Champion, Hero, or Myth — not Adventurer).
function Addon:CheckUpgradeWarning()
    if _warn then _warn.holder:Hide() end

    local prefs = self:EnsurePrefs()
    if prefs.upgradeWarnDisabled then return end

    if not (C_ItemUpgrade and C_ItemUpgrade.GetItemUpgradeItemInfo) then return end

    local info = C_ItemUpgrade.GetItemUpgradeItemInfo()
    if not info then return end

    local currentLevel = tonumber(info.currUpgrade)
    local maxLevel     = tonumber(info.maxUpgrade)
    if not (currentLevel and maxLevel) then return end

    -- Only warn when item is at rank 1 out of 2+ ranks.
    if maxLevel < 2 or currentLevel > 1 then return end

    -- Identify the upgrade track by matching the next-step currency ID against
    -- our known crest currency IDs (1=Adv, 2=Vet, 3=Champ, 4=Hero, 5=Myth).
    local tracking = Addon.TRACKING
    local crestIDs = tracking and tracking.crestCurrencyIDs
    if not crestIDs then return end

    local upgradeCurrencyID
    local upgradeCount
    local lvlInfos = info.upgradeLevelInfos
    local step = lvlInfos and (lvlInfos[currentLevel + 1] or lvlInfos[currentLevel])
    local costs = step and step.currencyCostsToUpgrade
    if costs and costs[1] then
        upgradeCurrencyID = costs[1].currencyID
        upgradeCount      = costs[1].cost
    end
    if not upgradeCurrencyID and not IsDevBuild() then return end

    local tierIdx
    if upgradeCurrencyID then
        for i, id in ipairs(crestIDs) do
            if id == upgradeCurrencyID then tierIdx = i; break end
        end
    end

    -- In release mode only warn for tracks that have a cheaper previous track
    -- (Veteran and above). Adventurer has no previous track so nothing to save.
    if not IsDevBuild() and (not tierIdx or tierIdx < 2) then return end
    if not tierIdx then tierIdx = 1 end

    local upgradeCost = upgradeCount or 0
    local currentName = GetCrestShort(tierIdx)
    local prevName    = GetCrestShort(math.max(tierIdx - 1, 1))

    if _warn then
        local fmt = L.UPGRADE_WARN_MSG or "You can save %d %s crests by upgrading a %s item instead"
        _warn.label:SetText(string.format(fmt, upgradeCost, currentName, prevName))
        _warn.holder:Show()
    end
end

-- ── Deferred setup ────────────────────────────────────────────────────────────
-- C_ItemUpgrade and ItemUpgradeFrame only exist after Blizzard_ItemUpgradeUI
-- loads on demand. We wait for it via ADDON_LOADED, then hook in.

local function SetupHooks()
    if ItemUpgradeFrame then
        -- ── Warning holder ───────────────────────────────────────────────────
        local ROW_H = 22
        local GAP   = 4
        local TOTAL = ROW_H * 2 + GAP   -- 48px

        -- Parent to ItemUpgradeFrame so it follows the window.
        local holder = CreateFrame("Frame", "LWCUpgradeWarnHolder", ItemUpgradeFrame)
        holder:SetFrameStrata("DIALOG")
        holder:SetSize(ItemUpgradeFrame:GetWidth() or 350, TOTAL)
        holder:EnableMouse(false)
        holder:Hide()

        -- Anchor between the item-slot row and the "Upgrade To:" dropdown.
        -- Try known Blizzard child names for the track dropdown; fall back to
        -- a fixed offset below the item button.
        local function PositionHolder()
            holder:ClearAllPoints()
            local lpanel = ItemUpgradeFrame.LeftItemPreviewFrame
            local rpanel = ItemUpgradeFrame.RightItemPreviewFrame
            if lpanel and rpanel then
                holder:SetPoint("BOTTOMLEFT",  lpanel, "TOPLEFT",  0, 2)
                holder:SetPoint("BOTTOMRIGHT", rpanel, "TOPRIGHT", 0, 2)
            elseif lpanel then
                holder:SetPoint("BOTTOM", ItemUpgradeFrame, "CENTER", 0, lpanel:GetTop() - ItemUpgradeFrame:GetBottom() + 2)
            else
                holder:SetPoint("TOP", ItemUpgradeFrame, "TOP", 0, -150)
            end
        end
        PositionHolder()

        -- Disable button — centered in the top row.
        local disableBtn = CreateFrame("Button", nil, holder, "UIPanelButtonTemplate")
        disableBtn:SetSize(120, ROW_H)
        disableBtn:SetPoint("TOP", holder, "TOP", 0, 0)
        disableBtn:SetText(L.UPGRADE_WARN_DISABLE_BTN or "Disable Warning")
        if Addon._styleActionButton then Addon._styleActionButton(disableBtn) end
        disableBtn:SetScript("OnClick", function()
            Addon:EnsurePrefs().upgradeWarnDisabled = true
            holder:Hide()
        end)
        disableBtn:SetScript("OnEnter", function(self_)
            GameTooltip:SetOwner(self_, "ANCHOR_TOP")
            GameTooltip:SetText(L.UPGRADE_WARN_DISABLE_TOOLTIP or "Check Laria's guide for more information.", 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        disableBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- Dynamic message — full-width row at the bottom.
        local label = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalMed2")
        label:SetPoint("BOTTOMLEFT",  holder, "BOTTOMLEFT",  0, 0)
        label:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, 0)
        label:SetJustifyH("CENTER")
        label:SetTextColor(1, 0.15, 0.15)
        label:SetWordWrap(false)

        _warn = { holder = holder, label = label, disableBtn = disableBtn }

        -- Delay one frame after Show so item data is populated before we read it.
        hooksecurefunc(ItemUpgradeFrame, "Show", function()
            C_Timer.After(0, function()
                if Addon.CheckUpgradeWarning then Addon:CheckUpgradeWarning() end
            end)
        end)
        hooksecurefunc(ItemUpgradeFrame, "Hide", function()
            if _warn then _warn.holder:Hide() end
        end)
    end

    -- Also fire when the player swaps the item in the upgrade slot.
    local slotFrame = CreateFrame("Frame")
    slotFrame:RegisterEvent("ITEM_UPGRADE_MASTER_SET_ITEM")
    slotFrame:SetScript("OnEvent", function()
        if Addon.CheckUpgradeWarning then Addon:CheckUpgradeWarning() end
    end)
end

-- ItemUpgradeFrame only exists after Blizzard_ItemUpgradeUI loads on demand.
-- C_ItemUpgrade is always available as a native namespace so it cannot be used
-- to detect whether the UI has actually loaded; use ItemUpgradeFrame instead.
if ItemUpgradeFrame then
    -- UI reload: Blizzard_ItemUpgradeUI was already loaded.
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
-- L.UPGRADE_WARN_MSG             — Warning sentence shown above the upgrade button.
-- L.UPGRADE_WARN_DISABLE_BTN     — Label for the inline Disable button.
-- L.UPGRADE_WARN_DISABLE_TOOLTIP — Tooltip for the Disable button.
-- L.OPTIONS_DISABLE_UPGRADE_WARN — Label for the Settings panel checkbox.
