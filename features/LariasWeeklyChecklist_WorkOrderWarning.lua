-- LariasWeeklyChecklist_WorkOrderWarning.lua
-- Watches the Professions crafting frame and warns the player when the
-- selected recipe output is an item they cannot equip (wrong weapon type for
-- their class) or has a mismatched primary stat (e.g. an Agility player
-- crafting a Strength weapon).
local addonName = ...
local Addon = _G[addonName]
if not Addon then return end

local _woWarn  -- { holder, label, closeBtn }

-- ── Primary stat ─────────────────────────────────────────────────────────────
-- Item stats are defined in LariasWeeklyChecklist_Constants.lua under
-- `workOrderItemStats` and loaded into Addon.TRACKING at startup.
-- Stat values mirror GetSpecializationInfo primaryStat: 1=STR, 2=AGI, 4=INT.
-- Special value 3 = PHYS — item has AGI+STR but no INT; only warns casters.
local PHYS = 3  -- AGI + STR on item, no INT

local STAT_NAME = { [1]="Strength", [2]="Agility", [4]="Intellect" }

-- ── Core check ───────────────────────────────────────────────────────────────

local function GetPlayerSpecInfo()
    local specIdx = GetSpecialization and GetSpecialization()
    if not specIdx then return nil, nil end
    local _, specName, _, _, _, primaryStat = GetSpecializationInfo(specIdx)
    return primaryStat, specName
end

local function RunCheck(itemID)
    if not _woWarn then return end
    _woWarn.holder:Hide()

    if not itemID or itemID == 0 then return end

    local name, itemLink = GetItemInfo(itemID)
    if not name or not itemLink then
        -- Not cached yet; request and retry on load.
        C_Item.RequestLoadItemDataByID(itemID)
        local f = CreateFrame("Frame")
        f:RegisterEvent("GET_ITEM_INFO_RECEIVED")
        f:SetScript("OnEvent", function(_, _, loadedID, success)
            if loadedID == itemID then
                f:UnregisterAllEvents()
                if success then RunCheck(itemID) end
            end
        end)
        return
    end

    local warnings = {}

    -- ── Weapon type check ───────────────────────────────────────────────────
    -- IsEquippableItem checks class/weapon-type restrictions for the current player.
    -- Use itemLink rather than itemID for reliable results.
    if not IsEquippableItem(itemLink) then
        table.insert(warnings, "You can't equip this weapon.")
    end

    -- ── Primary stat check ──────────────────────────────────────────────────
    -- Most TWW/Midnight crafted weapons use optional reagents to pick AGI/STR
    -- at craft time, so GetItemStats returns nothing. Item stats are defined in
    -- LariasWeeklyChecklist_Constants.lua and loaded into Addon.TRACKING.
    local itemStats = (Addon.TRACKING or {}).workOrderItemStats or {}
    local fixedStat = itemStats[itemID]
    if fixedStat then
        local playerStat, specName = GetPlayerSpecInfo()
        if playerStat then
            local mismatch = false
            local itemStatName
            if fixedStat == PHYS then
                -- Item has AGI+STR but no INT — warn casters only
                if playerStat == 4 then
                    mismatch = true
                    itemStatName = "Agility/Strength"
                end
            elseif fixedStat ~= playerStat then
                mismatch = true
                itemStatName = STAT_NAME[fixedStat] or "unknown"
            end
            if mismatch then
                local spec = specName or "current"
                table.insert(warnings,
                    "You're currently in " .. spec .. " Spec.\nAre you sure you want to craft an " .. itemStatName .. " weapon?")
            end
        end
    end

    if #warnings == 0 then return end

    local msg = table.concat(warnings, "\n")
    _woWarn.label:SetText(msg)

    -- Resize to fit content.
    C_Timer.After(0, function()
        if not _woWarn then return end
        local labelH = math.max(_woWarn.label:GetStringHeight(), 17)
        local pad, btn = _woWarn.padW, _woWarn.btnH
        _woWarn.holder:SetHeight(pad + labelH + 6 + btn + pad)
    end)

    _woWarn.holder:Show()
end

local function GetCustomerOrderItemID()
    local f = ProfessionsCustomerOrdersFrame
    if not f then return nil end
    local form = f.Form
    if not form then return nil end
    local order = form.order
    if not order then return nil end
    local itemID = order.itemID
    if itemID and itemID ~= 0 then return itemID end
    return nil
end

function Addon:CheckWorkOrderWarning()
    local itemID = GetCustomerOrderItemID()
    RunCheck(itemID)
end

-- ── Deferred setup ────────────────────────────────────────────────────────────

local function SetupWorkOrderHooks()
    local anchor = ProfessionsCustomerOrdersFrame
    if not anchor then return end

    local PAD_W = 10
    local BTN_H = 22

    local holder = Addon:NewThemedFrame(nil, UIParent)
    holder:SetFrameStrata("DIALOG")
    holder:SetFrameLevel(200)
    holder:SetSize(380, 80)  -- initial height; resized dynamically after text wraps
    holder:SetClampedToScreen(true)
    holder:EnableMouse(true)
    holder:SetPoint("TOP", anchor, "BOTTOM", 0, -6)
    local bg = Addon.THEME.bg
    holder:SetBackdropColor(bg.r, bg.g, bg.b, 1.0)
    if holder.SetBackdropBorderColor then
        local bdr = Addon.THEME.border
        holder:SetBackdropBorderColor(bdr.r, bdr.g, bdr.b, bdr.a or 1)
    end
    holder:Hide()

    local label = holder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT",  holder, "TOPLEFT",  PAD_W,  -PAD_W)
    label:SetPoint("TOPRIGHT", holder, "TOPRIGHT", -PAD_W, -PAD_W)
    label:SetJustifyH("CENTER")
    label:SetTextColor(1, 0.4, 0.4)
    label:SetWordWrap(true)

    local closeBtn = CreateFrame("Button", nil, holder, "UIPanelButtonTemplate")
    closeBtn:SetSize(120, BTN_H)
    closeBtn:SetPoint("TOP", label, "BOTTOM", 0, -6)
    closeBtn:SetText("Got it")
    closeBtn:SetScript("OnClick", function() holder:Hide() end)

    _woWarn = { holder = holder, label = label, closeBtn = closeBtn, padW = PAD_W, btnH = BTN_H }

    anchor:HookScript("OnHide", function()
        if _woWarn then _woWarn.holder:Hide() end
    end)

    -- CRAFTINGORDERS_CAN_REQUEST fires whenever the customer order form updates
    -- (item selected, reagents changed, etc.) — exactly when we want to re-check.
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("CRAFTINGORDERS_CAN_REQUEST")
    eventFrame:SetScript("OnEvent", function()
        C_Timer.After(0, function() Addon:CheckWorkOrderWarning() end)
    end)
end

-- ProfessionsCustomerOrdersFrame loads on demand via Blizzard_ProfessionsCustomerOrders.
if ProfessionsCustomerOrdersFrame then
    SetupWorkOrderHooks()
else
    local setupFrame = CreateFrame("Frame")
    setupFrame:RegisterEvent("ADDON_LOADED")
    setupFrame:SetScript("OnEvent", function(_, _, loadedAddon)
        if loadedAddon ~= "Blizzard_ProfessionsCustomerOrders" then return end
        setupFrame:UnregisterAllEvents()
        SetupWorkOrderHooks()
    end)
end
