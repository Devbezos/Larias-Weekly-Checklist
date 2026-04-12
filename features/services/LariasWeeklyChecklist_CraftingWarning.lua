-- LariasWeeklyChecklist_CraftingWarning.lua
local addonName = ...
local Addon = _G[addonName]
if not Addon then return end

local L = Addon.L or {}

local SPEC_STAT = {
    [71]="STR",[72]="STR",[73]="STR",
    [65]="INT",[66]="STR",[70]="STR",
    [253]="AGI",[254]="AGI",[255]="AGI",
    [259]="AGI",[260]="AGI",[261]="AGI",
    [256]="INT",[257]="INT",[258]="INT",
    [250]="STR",[251]="STR",[252]="STR",
    [262]="INT",[263]="AGI",[264]="INT",
    [62]="INT",[63]="INT",[64]="INT",
    [265]="INT",[266]="INT",[267]="INT",
    [268]="AGI",[269]="AGI",[270]="INT",
    [102]="INT",[103]="AGI",[104]="AGI",[105]="INT",
    [577]="AGI",[581]="AGI",
    [1467]="INT",[1468]="INT",[1473]="INT",
}
local STAT_NAMES = { STR="Strength", AGI="Agility", INT="Intellect" }

local _warn
local _pendingItemID
local _currentRecipeID
local _hookedForms = {}
local _scanTip

-- Returns "STR", "AGI", "INT", or nil by scanning the item tooltip

local function GetItemMainStat(itemLink)
    if not itemLink then return nil end
    if C_TooltipInfo and C_TooltipInfo.GetHyperlink then
        local data = C_TooltipInfo.GetHyperlink(itemLink)
        if data and data.lines then
            for _, line in ipairs(data.lines) do
                local t = line.leftText or ""
                if t:find("Strength")  then return "STR" end
                if t:find("Agility")   then return "AGI" end
                if t:find("Intellect") then return "INT" end
            end
        end
    end
    -- Fallback: hidden GameTooltip scan
    if not _scanTip then
        _scanTip = CreateFrame("GameTooltip", "LWCCraftWarnScanTip", UIParent, "GameTooltipTemplate")
        _scanTip:SetOwner(UIParent, "ANCHOR_NONE")
    end
    _scanTip:ClearLines()
    _scanTip:SetHyperlink(itemLink)
    for i = 1, _scanTip:NumLines() do
        local left = _G["LWCCraftWarnScanTipTextLeft" .. i]
        local t = left and left:GetText() or ""
        if t:find("Strength")  then return "STR" end
        if t:find("Agility")   then return "AGI" end
        if t:find("Intellect") then return "INT" end
    end
    return nil
end

local function GetPlayerPrimaryStat()
    if not GetSpecialization then return nil end
    local idx = GetSpecialization()
    if not idx then return nil end
    local specID = select(1, GetSpecializationInfo(idx))
    return specID and SPEC_STAT[specID]
end

-- Hook a schematic form instance

local function HookForm(form, label)
    if not form or _hookedForms[form] then return end
    if not form.Init then return end
    _hookedForms[form] = true
    hooksecurefunc(form, "Init", function(_, info)
        -- Customer orders form: {spellID, itemID, ...}; normal crafting: {recipeID, ...}
        _currentRecipeID = info and (info.recipeID or info.spellID) or nil
        _pendingItemID   = (info and (info.itemID or 0) > 0) and info.itemID or nil
        C_Timer.After(0, function() Addon:CheckCraftingWarning() end)
    end)
    form:HookScript("OnHide", function()
        if _warn then _warn.holder:Hide() end
        _pendingItemID = nil ; _currentRecipeID = nil
    end)
end

local function SetupFrame(root, rootName)
    if not root then return end
    if root.SchematicForm then HookForm(root.SchematicForm, rootName .. ".SchematicForm") end
    if root.Form          then HookForm(root.Form,          rootName .. ".Form")          end
    if root.CraftingPage  then
        if root.CraftingPage.SchematicForm then HookForm(root.CraftingPage.SchematicForm, rootName .. ".CraftingPage.SchematicForm") end
        if root.CraftingPage.Form          then HookForm(root.CraftingPage.Form,          rootName .. ".CraftingPage.Form")          end
    end
    if root.OrdersPage then
        if root.OrdersPage.SchematicForm then HookForm(root.OrdersPage.SchematicForm, rootName .. ".OrdersPage.SchematicForm") end
        if root.OrdersPage.Form          then HookForm(root.OrdersPage.Form,          rootName .. ".OrdersPage.Form")          end
    end
    root:HookScript("OnHide", function()
        if _warn then _warn.holder:Hide() end
        _pendingItemID = nil ; _currentRecipeID = nil
    end)
end

-- Warn panel (built lazily on first mismatch)

local function EnsureWarnPanel()
    if _warn then return end
    local anchor = (ProfessionsFrame and ProfessionsFrame:IsShown() and ProfessionsFrame)
                or (ProfessionsCustomerOrdersFrame and ProfessionsCustomerOrdersFrame:IsShown() and ProfessionsCustomerOrdersFrame)
                or UIParent

    local PAD_W=10 ; local BODY_H=34 ; local BTN_H=22
    local PANEL_H = PAD_W + BODY_H + 6 + BTN_H + PAD_W

    local holder = Addon:NewThemedFrame(nil, UIParent)
    holder:SetFrameStrata("DIALOG") ; holder:SetFrameLevel(200)
    holder:SetSize(410, PANEL_H) ; holder:SetClampedToScreen(true) ; holder:EnableMouse(true)
    holder:SetPoint("TOP", anchor, "BOTTOM", 0, -6)
    local bg = Addon.THEME.bg
    holder:SetBackdropColor(bg.r, bg.g, bg.b, 1.0)
    if holder.SetBackdropBorderColor then
        local bdr = Addon.THEME.border
        holder:SetBackdropBorderColor(bdr.r, bdr.g, bdr.b, bdr.a or 1)
    end
    holder:Hide()

    local label = holder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT",  holder, "TOPLEFT",  PAD_W, -PAD_W)
    label:SetPoint("TOPRIGHT", holder, "TOPRIGHT", -PAD_W,-PAD_W)
    label:SetJustifyH("CENTER") ; label:SetTextColor(1, 0.4, 0.4) ; label:SetWordWrap(true)

    local btn = CreateFrame("Button", nil, holder, "UIPanelButtonTemplate")
    btn:SetSize(180, BTN_H) ; btn:SetPoint("TOP", label, "BOTTOM", 0, -6)
    btn:SetText(L.CRAFT_WARN_DISABLE_BTN or "Hide Crafting Warning")
    btn:SetScript("OnEnter", function(self)
        Addon.AddonUtils.SetTooltip(self, L.CRAFT_WARN_DISABLE_TOOLTIP or "Check Larias's guide for more information.", "ANCHOR_BOTTOM")
    end)
    btn:SetScript("OnLeave", Addon.AddonUtils.HideTooltip)
    btn:SetScript("OnClick", function()
        Addon:EnsurePrefs().craftWarnDisabled = true ; holder:Hide()
        if Addon.RefreshSettingsCheckboxes then Addon:RefreshSettingsCheckboxes() end
        if Addon.SyncGearPopup then Addon:SyncGearPopup() end
    end)
    _warn = { holder=holder, label=label }
end

-- Core check

function Addon:CheckCraftingWarning()
    if _warn then _warn.holder:Hide() end
    if self:EnsurePrefs().craftWarnDisabled then return end

    local itemID, itemLink
    if _pendingItemID and _pendingItemID > 0 then
        itemID = _pendingItemID
        _, itemLink = GetItemInfo(itemID)
    elseif _currentRecipeID and C_TradeSkillUI and C_TradeSkillUI.GetRecipeSchematic then
        local ok, sc = pcall(C_TradeSkillUI.GetRecipeSchematic, _currentRecipeID, false)
        if ok and sc then
            local gco = sc.guaranteedCraftingOutput
            if type(gco) == "table" and gco[1] then
                local e = gco[1]
                if e.item and e.item.GetItemID then itemID = e.item:GetItemID()
                elseif type(e.itemID) == "number" and e.itemID > 0 then itemID = e.itemID end
            end
            if not (itemID and itemID > 0) and (sc.outputItemID or 0) > 0 then itemID = sc.outputItemID end
            if itemID and itemID > 0 then _, itemLink = GetItemInfo(itemID) end
        end
    end

    if not itemID then return end

    -- Only warn for known Midnight craftable weapons
    local constants = _G[addonName .. "_CONSTANTS"]
    local warnIDs = constants and constants.craftingWarnItemIDs
    if not warnIDs or not warnIDs[itemID] then return end

    if not itemLink then
        _pendingItemID = itemID
        if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(itemID) end
        return
    end

    local itemStat   = GetItemMainStat(itemLink)
    local playerStat = GetPlayerPrimaryStat()
    if not itemStat or not playerStat then return end
    if itemStat == playerStat then return end

    EnsureWarnPanel()
    if not _warn then return end

    local anchor = (ProfessionsFrame and ProfessionsFrame:IsShown() and ProfessionsFrame)
                or (ProfessionsCustomerOrdersFrame and ProfessionsCustomerOrdersFrame:IsShown() and ProfessionsCustomerOrdersFrame)
                or UIParent
    _warn.holder:ClearAllPoints()
    _warn.holder:SetPoint("TOP", anchor, "BOTTOM", 0, -6)

    local itemName = GetItemInfo(itemLink) or (L.CRAFT_WARN_UNKNOWN_ITEM or "this item")
    local fmt = L.CRAFT_WARN_MSG or "Warning: %s has %s, but your spec uses %s.\nYou may be crafting the wrong weapon."
    _warn.label:SetText(string.format(fmt, itemName, STAT_NAMES[itemStat] or itemStat, STAT_NAMES[playerStat] or playerStat))
    _warn.holder:Show()
end

-- Events

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("TRADE_SKILL_DETAILS_UPDATE")
ev:RegisterEvent("ITEM_DATA_LOAD_RESULT")
ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == "Blizzard_ProfessionsUI" and ProfessionsFrame then
            SetupFrame(ProfessionsFrame, "ProfessionsFrame")
        elseif arg1 == "Blizzard_ProfessionsCustomerOrders" and ProfessionsCustomerOrdersFrame then
            SetupFrame(ProfessionsCustomerOrdersFrame, "ProfessionsCustomerOrdersFrame")
        end
    elseif event == "TRADE_SKILL_DETAILS_UPDATE" then
        _currentRecipeID = arg1 or _currentRecipeID
        C_Timer.After(0, function() Addon:CheckCraftingWarning() end)
    elseif event == "ITEM_DATA_LOAD_RESULT" then
        if tonumber(arg1) == _pendingItemID then
            Addon:CheckCraftingWarning()
        end
    end
end)

-- Handle UI reload (frames already exist)
if ProfessionsFrame then SetupFrame(ProfessionsFrame, "ProfessionsFrame") end
if ProfessionsCustomerOrdersFrame then SetupFrame(ProfessionsCustomerOrdersFrame, "ProfessionsCustomerOrdersFrame") end
