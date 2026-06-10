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
    local name = L[CREST_LOCALE_KEYS[tierIdx]] or CREST_LOCALE_KEYS[tierIdx]
    -- strip any trailing period WoW may append to the global string
    name = name:gsub("%.$", "")
    return Addon.IlvlUtils.GetEscapePrefix(tierIdx) .. name .. "|r"
end

-- ── Guild check ─────────────────────────────────────────────────────────────
-- Special behaviour: members of <Refined> on Zul'jin-NA cannot proceed with
-- a bad upgrade, because they really should know better by now.
-- We match only on guild name; realm apostrophe encoding varies by client.
-- local function IsInRefinedGuild()
--     local guildName = GetGuildInfo("player")
--     return guildName == "Refined"
-- end

-- ── Core check ────────────────────────────────────────────────────────────────

--- Called whenever the item upgrade frame shows or a new item is slotted.
--- Shows a warning when item is at rank 1 on a track that has a cheaper
--- previous track (Veteran, Champion, Hero, or Myth — not Adventurer).
function Addon:CheckUpgradeWarning()
    if _warn then _warn.holder:Hide() end

    local prefs = self:EnsurePrefs()
    if prefs.upgradeWarnDisabled then return end
    -- Panel hasn't been built yet (Blizzard_ItemUpgradeUI not loaded); nothing to show.
    if not _warn then return end

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

    local isDev = IsDevBuild()
    if not upgradeCurrencyID and not isDev then return end

    local tierIdx
    if upgradeCurrencyID then
        for i, id in ipairs(crestIDs) do
            if id == upgradeCurrencyID then tierIdx = i; break end
        end
    end

    -- In release mode only warn for tracks that have a cheaper previous track
    -- (Veteran and above). Adventurer has no previous track so nothing to save.
    if not isDev and (not tierIdx or tierIdx < 2) then return end
    if not tierIdx then tierIdx = 1 end

    local upgradeCost = upgradeCount or 0
    if upgradeCost <= 0 then return end  -- no crest cost, nothing to warn about
    local currentName = GetCrestShort(tierIdx)
    local prevName    = GetCrestShort(math.max(tierIdx - 1, 1))

    local fmt = L.UPGRADE_WARN_MSG or "Upgrading a 1/6 %s item is a waste of %d crests.\nYou should upgrade a 5/6 %s item instead"
    _warn.label:SetText(string.format(fmt, currentName, upgradeCost, prevName))
    _warn.holder:Show()
end

-- ── Deferred setup ────────────────────────────────────────────────────────────
-- C_ItemUpgrade and ItemUpgradeFrame only exist after Blizzard_ItemUpgradeUI
-- loads on demand. We wait for it via ADDON_LOADED, then hook in.

local function SetupHooks()
    if ItemUpgradeFrame then
        -- ── Warning panel (themed backdrop matching the addon's windows) ─────
        local PAD_W   = 10
        local BODY_H  = 34   -- two wrapped lines of GameFontNormal (~17px each)
        local BTN_H   = 22
        local PANEL_H = PAD_W + BODY_H + 6 + BTN_H + PAD_W

        local holder = Addon:NewThemedFrame(nil, UIParent)
        holder:SetFrameStrata("DIALOG")
        holder:SetFrameLevel(200)
        holder:SetSize(410, PANEL_H)
        holder:SetClampedToScreen(true)
        holder:EnableMouse(true)
        -- Anchor directly below the ItemUpgradeFrame, horizontally centered.
        holder:SetPoint("TOP", ItemUpgradeFrame, "BOTTOM", 0, -6)
        Addon:ApplyOpaquePopupTheme(holder)
        holder:Hide()

        -- Warning message (wraps to ~2 lines).
        local label = holder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT",  holder, "TOPLEFT",  PAD_W,  -PAD_W)
        label:SetPoint("TOPRIGHT", holder, "TOPRIGHT", -PAD_W, -PAD_W)
        label:SetJustifyH("CENTER")
        label:SetTextColor(1, 0.4, 0.4)
        label:SetWordWrap(true)

        -- "Hide" button — clearly styled as a clickable button.
        local disableBtn = CreateFrame("Button", nil, holder, "UIPanelButtonTemplate")
        disableBtn:SetSize(160, BTN_H)
        disableBtn:SetPoint("TOP", label, "BOTTOM", 0, -6)
        disableBtn:SetText(L.UPGRADE_WARN_DISABLE_BTN or "Hide Upgrade Warning")
        if Addon.Controls and Addon.Controls.StyleButton then
            Addon.Controls.StyleButton(disableBtn)
        end
        disableBtn:SetScript("OnEnter", function(self)
            Addon.AddonUtils.SetTooltip(self, L.UPGRADE_WARN_DISABLE_TOOLTIP or "Check Larias's guide for more information.", "ANCHOR_BOTTOM")
        end)
        disableBtn:SetScript("OnLeave", Addon.AddonUtils.HideTooltip)
        disableBtn:SetScript("OnClick", function()
            Addon:EnsurePrefs().upgradeWarnDisabled = true
            holder:Hide()
            if Addon.RefreshSettingsCheckboxes then Addon:RefreshSettingsCheckboxes() end
            if Addon.SyncGearPopup then Addon:SyncGearPopup() end
        end)

        _warn = { holder = holder, label = label, disableBtn = disableBtn }

        -- Delay one frame after Show so item data is populated before we read it.
        hooksecurefunc(ItemUpgradeFrame, "Show", function()
            C_Timer.After(0, function()
                Addon:CheckUpgradeWarning()
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
        Addon:CheckUpgradeWarning()
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
-- L.UPGRADE_WARN_MSG             — Warning sentence shown in the panel body.
-- L.UPGRADE_WARN_DISABLE_BTN     — Label for the inline Hide button.
-- L.UPGRADE_WARN_DISABLE_TOOLTIP — Tooltip for the Disable button.
-- L.OPTIONS_DISABLE_UPGRADE_WARN — Label for the Settings panel checkbox.
