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

-- ── Armor type lookup ────────────────────────────────────────────────────────
-- Class → preferred armor subClassID (Cloth=1, Leather=2, Mail=3, Plate=4).
-- Mirrors WoW's armor specialisation that applies at level 50+.
local CLASS_ARMOR_SUBCLASS = {
    WARRIOR     = 4,  -- Plate
    PALADIN     = 4,
    DEATHKNIGHT = 4,
    DEMONHUNTER = 2,  -- Leather
    DRUID       = 2,
    MONK        = 2,
    EVOKER      = 3,  -- Mail
    ROGUE       = 2,
    HUNTER      = 3,  -- Mail
    SHAMAN      = 3,
    MAGE        = 1,  -- Cloth
    PRIEST      = 1,
    WARLOCK     = 1,
}

-- Class → set of allowed weapon subClassIDs.
-- Weapon subClassIDs: 0=Axe1H, 1=Axe2H, 2=Bow, 3=Gun, 4=Mace1H, 5=Mace2H,
-- 6=Polearm, 7=Sword1H, 8=Sword2H, 9=Warglaive, 10=Staff, 13=Fist,
-- 15=Dagger, 17=Crossbow, 18=Wand.
local CLASS_WEAPON_SUBCLASSES = {
    WARRIOR     = { [0]=true,[1]=true,[2]=true,[3]=true,[4]=true,[5]=true,
                    [6]=true,[7]=true,[8]=true,[10]=true,[13]=true,[15]=true,[17]=true },
    PALADIN     = { [0]=true,[1]=true,[4]=true,[5]=true,[6]=true,[7]=true,[8]=true },
    DEATHKNIGHT = { [0]=true,[1]=true,[4]=true,[5]=true,[6]=true,[7]=true,[8]=true },
    DRUID       = { [4]=true,[5]=true,[6]=true,[10]=true,[13]=true,[15]=true },
    HUNTER      = { [0]=true,[2]=true,[3]=true,[6]=true,[7]=true,[10]=true,
                    [13]=true,[15]=true,[17]=true },
    MAGE        = { [7]=true,[10]=true,[15]=true,[18]=true },
    MONK        = { [0]=true,[4]=true,[6]=true,[7]=true,[10]=true,[13]=true,[15]=true },
    PRIEST      = { [4]=true,[10]=true,[15]=true,[18]=true },
    ROGUE       = { [0]=true,[4]=true,[7]=true,[13]=true,[15]=true },
    SHAMAN      = { [0]=true,[1]=true,[4]=true,[5]=true,[6]=true,
                    [10]=true,[13]=true,[15]=true },
    WARLOCK     = { [7]=true,[10]=true,[15]=true,[18]=true },
    DEMONHUNTER = { [9]=true,[13]=true,[15]=true },
    EVOKER      = { [0]=true,[4]=true,[7]=true,[10]=true,[13]=true,[15]=true },
}

-- Returns the armor subClassID the player should be wearing, or nil.
local function GetPlayerPreferredArmorSubClass()
    local _, classFile = UnitClass("player")
    return classFile and CLASS_ARMOR_SUBCLASS[classFile]
end

-- Returns true if allowed or the class is unknown (fail open), false if not allowed.
local function PlayerCanUseWeaponSubClass(subClassID)
    local _, classFile = UnitClass("player")
    if not classFile then return true end
    local allowed = CLASS_WEAPON_SUBCLASSES[classFile]
    if not allowed then return true end
    return allowed[subClassID] == true
end

-- ── Module state ─────────────────────────────────────────────────────────────
local _warn             -- cached warn panel { holder, label }
local _pendingItemID    -- item whose data hasn't loaded yet; retried via timer
local _currentRecipeID  -- recipe currently open in the Professions UI
local _hookedForms = {} -- tracks which SchematicForm/Form frames we've already hooked
local _sparkReagentCache = {} -- [recipeID] = itemID or false
local _profAddonsSeen   = 0    -- unregister ADDON_LOADED once both professions UI addons have loaded

-- ── Event frame (early, so helpers below can close over it) ──────────────────
-- Only ADDON_LOADED is registered at startup.  TRADE_SKILL_DETAILS_UPDATE is
-- registered lazily when a crafting window opens and unregistered when it closes.
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")

local function OnCraftingWindowOpen()
    ev:RegisterEvent("TRADE_SKILL_DETAILS_UPDATE")
end

local function OnCraftingWindowClose()
    ev:UnregisterEvent("TRADE_SKILL_DETAILS_UPDATE")
    if _warn then _warn.holder:Hide() end
    _pendingItemID   = nil
    _currentRecipeID = nil
end

-- ── Stat detection ───────────────────────────────────────────────────────────

-- Returns "STR", "AGI", "INT", or nil for the item's primary stat.
-- Tries GetItemStats first, then falls back to C_TooltipInfo tooltip scanning.
-- The fallback is needed for crafted template items where GetItemStats returns
-- empty. Global strings (_G["ITEM_MOD_*_SHORT"]) are used so it works on all
-- client locales.
local function GetItemMainStat(itemLink)
    if not itemLink then return nil end

    if GetItemStats then
        local stats = {}
        GetItemStats(itemLink, stats)
        if (stats["ITEM_MOD_STRENGTH_SHORT"]  or 0) > 0 then return "STR" end
        if (stats["ITEM_MOD_AGILITY_SHORT"]   or 0) > 0 then return "AGI" end
        if (stats["ITEM_MOD_INTELLECT_SHORT"] or 0) > 0 then return "INT" end
    end

    -- Fallback: scan tooltip lines using localized stat names from global strings.
    if C_TooltipInfo and C_TooltipInfo.GetHyperlink then
        local strName = _G["ITEM_MOD_STRENGTH_SHORT"]  or "Strength"
        local agiName = _G["ITEM_MOD_AGILITY_SHORT"]   or "Agility"
        local intName = _G["ITEM_MOD_INTELLECT_SHORT"] or "Intellect"
        local data = C_TooltipInfo.GetHyperlink(itemLink)
        if data and data.lines then
            for _, line in ipairs(data.lines) do
                local t = line.leftText or ""
                if t:find(strName, 1, true) then return "STR" end
                if t:find(agiName, 1, true) then return "AGI" end
                if t:find(intName, 1, true) then return "INT" end
            end
        end
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

-- Checks whether the game has colored the item's type line red, which is exactly
-- what the client does when the player's class cannot use that item class/subclass.
-- itemClassID: 2 = Weapon, 4 = Armor.  Returns false if red (can't use), true if
-- another color (can use), or nil if the line wasn't found.
local function PlayerCanUseItemType(itemClassID, subClassID, itemLink)
    if not (itemLink and C_TooltipInfo and C_TooltipInfo.GetHyperlink and GetItemSubClassInfo) then
        return nil
    end
    local typeName = GetItemSubClassInfo(itemClassID, subClassID)
    if not typeName then return nil end
    local data = C_TooltipInfo.GetHyperlink(itemLink)
    if not (data and data.lines) then return nil end
    for _, line in ipairs(data.lines) do
        if line.leftText == typeName then
            local c = line.leftColor
            if c and c.r > 0.9 and (c.g or 0) < 0.1 and (c.b or 0) < 0.1 then
                return false  -- red = not proficient
            end
            return true
        end
    end
    return nil  -- line not found; skip the check
end

-- Fallback equip-restriction check for when PlayerCanUseItemType can't find
-- the type line (e.g. GetItemSubClassInfo returns "Staves" but tooltip says
-- "Staff"). Scans the first few tooltip lines for any red-colored entry;
-- WoW renders the weapon/armor type line red when the player's class can't
-- use that type. Lines 2-7 cover item level, type, and slot rows.
local function HasEarlyRedTooltipLine(itemLink)
    if not (itemLink and C_TooltipInfo and C_TooltipInfo.GetHyperlink) then return false end
    local data = C_TooltipInfo.GetHyperlink(itemLink)
    if not (data and data.lines) then return false end
    for i = 2, math.min(7, #data.lines) do
        local line = data.lines[i]
        local c    = line and line.leftColor
        if c and c.r > 0.9 and (c.g or 0) < 0.1 and (c.b or 0) < 0.1 then
            return true
        end
    end
    return false
end

-- ── Spark reagent detection ────────────────────────────────────────────────

-- Scans the recipe schematic for the configured spark item ID and returns
-- itemID, quantityRequired on success, or nil if the recipe has no spark slot.
-- Results are cached per recipeID for the session.
local function FindSparkForRecipe(recipeID)
    if not recipeID then return nil end
    local cached = _sparkReagentCache[recipeID]
    if cached ~= nil then
        return cached and cached[1] or nil, cached and cached[2] or nil
    end

    local sparkItemID = Addon.TRACKING and tonumber(Addon.TRACKING.sparkItemID)
    if not (sparkItemID and sparkItemID > 0) then
        _sparkReagentCache[recipeID] = false; return nil
    end

    if not (C_TradeSkillUI and C_TradeSkillUI.GetRecipeSchematic) then
        _sparkReagentCache[recipeID] = false; return nil
    end
    local ok, sc = pcall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false)
    if not ok or not sc then _sparkReagentCache[recipeID] = false; return nil end

    for _, slot in ipairs(sc.reagentSlotSchematics or {}) do
        local qty = tonumber(slot.quantityRequired) or 1
        for _, reagent in ipairs(slot.reagents or {}) do
            if tonumber(reagent.itemID) == sparkItemID then
                _sparkReagentCache[recipeID] = { sparkItemID, qty }
                return sparkItemID, qty
            end
        end
    end
    -- Recipe has no spark slot; cache so we don't re-scan.
    _sparkReagentCache[recipeID] = false
    return nil
end

-- ── Professions frame hooking ────────────────────────────────────────────────

-- Hooks a single SchematicForm/Form so we know when a new recipe is loaded.
-- Guarded by _hookedForms to ensure we never double-hook the same frame.
local function HookForm(form)
    if not form or _hookedForms[form] then return end
    if not form.Init then return end
    _hookedForms[form] = true
    hooksecurefunc(form, "Init", function(_, info)
        -- Customer orders pass {spellID, itemID, ...}; normal crafting uses {recipeID, ...}.
        _currentRecipeID = info and (info.recipeID or info.spellID) or nil
        _pendingItemID   = info and info.itemID and info.itemID > 0 and info.itemID or nil
        C_Timer.After(0, function() Addon:CheckCraftingWarning() end)
    end)
    -- Hide the warning when this schematic form closes (recipe deselected).
    form:HookScript("OnHide", function()
        if _warn then _warn.holder:Hide() end
        _pendingItemID = nil ; _currentRecipeID = nil
    end)
end

-- Hooks all known SchematicForm/Form sub-frames inside a root Professions frame
-- and adds an OnHide guard on the root itself.
local function SetupFrame(root)
    if not root then return end
    if root.SchematicForm then HookForm(root.SchematicForm) end
    if root.Form          then HookForm(root.Form)          end
    if root.CraftingPage  then
        if root.CraftingPage.SchematicForm then HookForm(root.CraftingPage.SchematicForm) end
        if root.CraftingPage.Form          then HookForm(root.CraftingPage.Form)          end
    end
    if root.OrdersPage then
        if root.OrdersPage.SchematicForm then HookForm(root.OrdersPage.SchematicForm) end
        if root.OrdersPage.Form          then HookForm(root.OrdersPage.Form)          end
    end
    -- Activate recipe/bag events when the window opens; tear down on close.
    root:HookScript("OnShow", OnCraftingWindowOpen)
    root:HookScript("OnHide", OnCraftingWindowClose)
end

-- ── Warning panel ────────────────────────────────────────────────────────────

-- Builds the warning panel the first time it is needed (lazy init).
-- Anchor is set dynamically each time the warning is shown, so no anchor here.
local function EnsureWarnPanel()
    if _warn then return end

    local PAD_W=10 ; local BODY_H=34 ; local BTN_H=22 ; local GAP=6
    local PANEL_H = PAD_W + BODY_H + GAP + BTN_H + PAD_W

    local holder = Addon:NewThemedFrame(nil, UIParent)
    holder:SetFrameStrata("DIALOG") ; holder:SetFrameLevel(200)
    holder:SetSize(410, PANEL_H) ; holder:SetClampedToScreen(true) ; holder:EnableMouse(true)
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
    btn:SetSize(180, BTN_H) ; btn:SetPoint("TOP", label, "BOTTOM", 0, -GAP)
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
    do return end -- crafting warning globally disabled

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

    if _currentRecipeID then
        local sparkItemID = FindSparkForRecipe(_currentRecipeID)
        if sparkItemID and GetItemCount(sparkItemID, true) < 1 then return end
    end

    if not itemLink then
        _pendingItemID = itemID
        if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(itemID) end
        C_Timer.After(0.5, function()
            if _pendingItemID == itemID then Addon:CheckCraftingWarning() end
        end)
        return
    end

    local itemName, _, _, _, _, _, _, _, itemEquipLoc, _, _, classID, subClassID = GetItemInfo(itemLink)
    itemName = itemName or L.CRAFT_WARN_UNKNOWN_ITEM or "this item"
    -- Cloaks/back items have subClassID=1 (Cloth) in the item DB but are equippable
    -- by all classes; skip armor-type checks for them entirely.
    local isCloak = (itemEquipLoc == "INVTYPE_CLOAK")
    local warnMsg

    if classID == 2 or classID == 4 then
        local cannotEquip = not IsEquippableItem(itemLink)
        if not cannotEquip and classID == 2 then
            -- Allowlist check is the primary gate: crafting item links are template
            -- links so IsEquippableItem and tooltip-color detection both return
            -- "can equip" even for weapons the player's class can never use.
            if not PlayerCanUseWeaponSubClass(subClassID) then
                cannotEquip = true
            else
                local typeResult = PlayerCanUseItemType(2, subClassID, itemLink)
                if typeResult == false then
                    cannotEquip = true
                elseif typeResult == nil then
                    cannotEquip = HasEarlyRedTooltipLine(itemLink)
                end
            end
        end
        if cannotEquip then
            warnMsg = string.format(
                L.CRAFT_WARN_EQUIP_MSG or "Warning: Your class cannot equip %s.\nYou may be crafting the wrong item.",
                itemName)
        end
    end

    if not warnMsg and not isCloak and classID == 4 and subClassID and subClassID >= 1 and subClassID <= 4 then
        local armorOk = PlayerCanUseItemType(4, subClassID, itemLink)
        if armorOk == false then
            local armorTypeName = (GetItemSubClassInfo and GetItemSubClassInfo(4, subClassID)) or tostring(subClassID)
            warnMsg = string.format(
                L.CRAFT_WARN_ARMOR_MSG or "Warning: %s is %s armor, but your class cannot wear it.\nYou may be crafting the wrong item.",
                itemName, armorTypeName)
        end
        -- Check: player is crafting armor of a lower type than their class wears.
        -- PlayerCanUseItemType only fires when the tooltip is red (can't equip at all);
        -- higher-armor-type classes (e.g. Plate) can equip lower types without a red
        -- tooltip, so we need an explicit class → preferred armor check here.
        if not warnMsg then
            local preferred = GetPlayerPreferredArmorSubClass()
            if preferred and subClassID ~= preferred then
                local craftedTypeName  = (GetItemSubClassInfo and GetItemSubClassInfo(4, subClassID)) or tostring(subClassID)
                local expectedTypeName = (GetItemSubClassInfo and GetItemSubClassInfo(4, preferred))  or tostring(preferred)
                warnMsg = string.format(
                    L.CRAFT_WARN_ARMOR_TYPE_MSG or "Warning: %s is %s armor, but your class wears %s.\nYou may be crafting the wrong item.",
                    itemName, craftedTypeName, expectedTypeName)
            end
        end
    end

    if not warnMsg and classID == 2 then
        local itemStat   = GetItemMainStat(itemLink)
        local playerStat = GetPlayerPrimaryStat()
        if itemStat and playerStat and itemStat ~= playerStat then
            warnMsg = string.format(
                L.CRAFT_WARN_MSG or "Warning: %s has %s, but your spec uses %s.\nYou may be crafting the wrong weapon.",
                itemName, STAT_NAMES[itemStat] or itemStat, STAT_NAMES[playerStat] or playerStat)
        end
    end

    if not warnMsg then return end

    EnsureWarnPanel()
    if not _warn then return end

    local anchor = (ProfessionsFrame and ProfessionsFrame:IsShown() and ProfessionsFrame)
                or (ProfessionsCustomerOrdersFrame and ProfessionsCustomerOrdersFrame:IsShown() and ProfessionsCustomerOrdersFrame)
                or UIParent
    _warn.holder:ClearAllPoints()
    _warn.holder:SetPoint("TOP", anchor, "BOTTOM", 0, -6)

    _warn.label:SetText(warnMsg)
    _warn.holder:Show()
end

-- ── Event handling ───────────────────────────────────────────────────────────
-- ev was created early in the file so OnCraftingWindowOpen/Close could close
-- over it.  Only ADDON_LOADED runs permanently (until both professions addons
-- are seen); TRADE_SKILL_DETAILS_UPDATE is activated only while a window is open.

ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        local hooked = false
        if arg1 == "Blizzard_ProfessionsUI" and ProfessionsFrame then
            SetupFrame(ProfessionsFrame)
            hooked = true
        elseif arg1 == "Blizzard_ProfessionsCustomerOrders" and ProfessionsCustomerOrdersFrame then
            SetupFrame(ProfessionsCustomerOrdersFrame)
            hooked = true
        end
        if hooked then
            _profAddonsSeen = _profAddonsSeen + 1
            if _profAddonsSeen >= 2 then ev:UnregisterEvent("ADDON_LOADED") end
        end
    elseif event == "TRADE_SKILL_DETAILS_UPDATE" then
        -- Only registered while a crafting window is open (see OnCraftingWindowOpen).
        _currentRecipeID = arg1 or _currentRecipeID
        C_Timer.After(0, function() Addon:CheckCraftingWarning() end)
    end
end)

-- Handle UI reload: frames may already exist before ADDON_LOADED fires.
-- SetupFrame adds the OnShow/OnHide hooks that manage active event registration.
if ProfessionsFrame then
    SetupFrame(ProfessionsFrame)
    _profAddonsSeen = _profAddonsSeen + 1
end
if ProfessionsCustomerOrdersFrame then
    SetupFrame(ProfessionsCustomerOrdersFrame)
    _profAddonsSeen = _profAddonsSeen + 1
end
if _profAddonsSeen >= 2 then ev:UnregisterEvent("ADDON_LOADED") end
