-- LariasWeeklyChecklist_CraftingWarning.lua
-- Warns the player when they are about to craft a weapon whose primary stat
-- does not match their current specialization (e.g. crafting an Agility weapon
-- as an Intellect spec). The panel is shown over the Professions UI and can be
-- permanently dismissed from the Options panel.
local addonName = ...
local Addon = _G[addonName]
if not Addon then return end

local L = Addon.L or {}

-- ── Spec → primary stat lookup ───────────────────────────────────────────────
-- primaryStat values returned by GetSpecializationInfo: 1=STR, 2=AGI, 3=INT.
local PRIMARY_STAT_MAP = { [1]="STR", [2]="AGI", [3]="INT" }

-- Human-readable display names used in the warning message.
local STAT_NAMES = { STR="Strength", AGI="Agility", INT="Intellect" }

-- ── Module state ─────────────────────────────────────────────────────────────
local _warn             -- cached warn panel { holder, label }
local _pendingItemID    -- item whose data hasn't loaded yet; retried on ITEM_DATA_LOAD_RESULT
local _currentRecipeID  -- recipe currently open in the Professions UI
local _hookedForms = {} -- tracks which SchematicForm/Form frames we've already hooked
local _scanTip          -- hidden GameTooltip used as a fallback for stat scanning

-- ── Stat detection ───────────────────────────────────────────────────────────

-- Returns "STR", "AGI", "INT", or nil by scanning the item's tooltip lines.
-- Prefers the C_TooltipInfo API (no frame required); falls back to a hidden
-- GameTooltip when that API is unavailable.
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
    -- Fallback: scan a hidden GameTooltip for the stat text.
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

-- Returns "STR", "AGI", "INT", or nil for the player's active specialization.
local function GetPlayerPrimaryStat()
    if not GetSpecialization then return nil end
    local idx = GetSpecialization()
    if not idx then return nil end
    local _, _, _, _, _, primaryStat = GetSpecializationInfo(idx)
    return PRIMARY_STAT_MAP[primaryStat]
end

-- ── Professions frame hooking ────────────────────────────────────────────────

-- Hooks a single SchematicForm/Form so we know when a new recipe is loaded.
-- Guarded by _hookedForms to ensure we never double-hook the same frame.
local function HookForm(form, label)
    if not form or _hookedForms[form] then return end
    if not form.Init then return end
    _hookedForms[form] = true
    hooksecurefunc(form, "Init", function(_, info)
        -- Customer orders pass {spellID, itemID, ...}; normal crafting uses {recipeID, ...}.
        _currentRecipeID = info and (info.recipeID or info.spellID) or nil
        _pendingItemID   = (info and (info.itemID or 0) > 0) and info.itemID or nil
        C_Timer.After(0, function() Addon:CheckCraftingWarning() end)
    end)
    -- Hide the warning when the form closes.
    form:HookScript("OnHide", function()
        if _warn then _warn.holder:Hide() end
        _pendingItemID = nil ; _currentRecipeID = nil
    end)
end

-- Hooks all known SchematicForm/Form sub-frames inside a root Professions frame
-- and adds an OnHide guard on the root itself.
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
    -- Also hide on root close in case no sub-form fires OnHide first.
    root:HookScript("OnHide", function()
        if _warn then _warn.holder:Hide() end
        _pendingItemID = nil ; _currentRecipeID = nil
    end)
end

-- ── Warning panel ────────────────────────────────────────────────────────────

-- Builds the warning panel the first time it is needed (lazy init).
-- The panel is anchored below whichever Professions frame is currently open.
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

    -- Warning text: shown in red so it's hard to miss.
    local label = holder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT",  holder, "TOPLEFT",  PAD_W, -PAD_W)
    label:SetPoint("TOPRIGHT", holder, "TOPRIGHT", -PAD_W,-PAD_W)
    label:SetJustifyH("CENTER") ; label:SetTextColor(1, 0.4, 0.4) ; label:SetWordWrap(true)

    -- "Hide warning" button: sets craftWarnDisabled and refreshes options UI.
    local btn = CreateFrame("Button", nil, holder, "UIPanelButtonTemplate")
    btn:SetSize(180, BTN_H) ; btn:SetPoint("TOP", label, "BOTTOM", 0, -6)
    btn:SetText(L.CRAFT_WARN_DISABLE_BTN or "Hide Crafting Warning")
    btn:SetScript("OnClick", function()
        Addon:EnsurePrefs().craftWarnDisabled = true ; holder:Hide()
        if Addon.RefreshSettingsCheckboxes then Addon:RefreshSettingsCheckboxes() end
        if Addon.SyncGearPopup then Addon:SyncGearPopup() end
    end)
    _warn = { holder=holder, label=label }
end

-- ── Core check ───────────────────────────────────────────────────────────────

-- Called whenever a recipe is opened or item data becomes available.
-- Resolves the output item, checks it against the player's primary stat, and
-- shows or hides the warning panel accordingly.
function Addon:CheckCraftingWarning()
    if _warn then _warn.holder:Hide() end
    if self:EnsurePrefs().craftWarnDisabled then return end

    local itemID, itemLink
    if _pendingItemID and _pendingItemID > 0 then
        -- A specific item was passed directly (e.g. from a customer order form).
        itemID = _pendingItemID
        _, itemLink = GetItemInfo(itemID)
    elseif _currentRecipeID and C_TradeSkillUI and C_TradeSkillUI.GetRecipeSchematic then
        -- Derive the output item from the recipe schematic.
        local ok, sc = pcall(C_TradeSkillUI.GetRecipeSchematic, _currentRecipeID, false)
        if ok and sc then
            local gco = sc.guaranteedCraftingOutput
            if type(gco) == "table" and gco[1] then
                local e = gco[1]
                if e.item and e.item.GetItemID then itemID = e.item:GetItemID()
                elseif type(e.itemID) == "number" and e.itemID > 0 then itemID = e.itemID end
            end
            -- Some recipes expose outputItemID directly on the schematic.
            if not (itemID and itemID > 0) and (sc.outputItemID or 0) > 0 then itemID = sc.outputItemID end
            if itemID and itemID > 0 then _, itemLink = GetItemInfo(itemID) end
        end
    end

    if not itemID then return end

    -- Only warn for items in the addon's curated craftingWarnItemIDs set.
    local constants = _G[addonName .. "_CONSTANTS"]
    local warnIDs = constants and constants.craftingWarnItemIDs
    if not warnIDs or not warnIDs[itemID] then return end

    if not itemLink then
        -- Item data hasn't loaded yet; store the ID and wait for ITEM_DATA_LOAD_RESULT.
        _pendingItemID = itemID
        if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(itemID) end
        return
    end

    local itemStat   = GetItemMainStat(itemLink)
    local playerStat = GetPlayerPrimaryStat()
    if not itemStat or not playerStat then return end
    if itemStat == playerStat then return end  -- stats match, no warning needed

    EnsureWarnPanel()
    if not _warn then return end

    -- Re-anchor every time in case the player switched between crafting frames.
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

-- ── Event handling ───────────────────────────────────────────────────────────

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")          -- hook Professions frames when their UI loads
ev:RegisterEvent("TRADE_SKILL_DETAILS_UPDATE") -- fires when the active recipe changes
ev:RegisterEvent("ITEM_DATA_LOAD_RESULT") -- fires when a previously-missing item finishes loading
ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        -- Hook frames as soon as the Blizzard Professions UI modules are loaded.
        if arg1 == "Blizzard_ProfessionsUI" and ProfessionsFrame then
            SetupFrame(ProfessionsFrame, "ProfessionsFrame")
        elseif arg1 == "Blizzard_ProfessionsCustomerOrders" and ProfessionsCustomerOrdersFrame then
            SetupFrame(ProfessionsCustomerOrdersFrame, "ProfessionsCustomerOrdersFrame")
        end
    elseif event == "TRADE_SKILL_DETAILS_UPDATE" then
        _currentRecipeID = arg1 or _currentRecipeID
        C_Timer.After(0, function() Addon:CheckCraftingWarning() end)
    elseif event == "ITEM_DATA_LOAD_RESULT" then
        -- Retry the check now that the pending item's data is available.
        if tonumber(arg1) == _pendingItemID then
            Addon:CheckCraftingWarning()
        end
    end
end)

-- Handle UI reload: the Professions frames may already exist before ADDON_LOADED fires.
if ProfessionsFrame then SetupFrame(ProfessionsFrame, "ProfessionsFrame") end
if ProfessionsCustomerOrdersFrame then SetupFrame(ProfessionsCustomerOrdersFrame, "ProfessionsCustomerOrdersFrame") end
