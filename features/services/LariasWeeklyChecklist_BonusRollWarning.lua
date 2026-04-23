-- LariasWeeklyChecklist_BonusRollWarning.lua
-- Warns the player when the Bonus Roll window opens, giving them a moment
-- to reconsider before spending a bonus roll token.
--
-- The panel is anchored below BonusRollFrame and can be permanently dismissed
-- from the Options panel.
--
-- Option: prefs.bonusRollWarnDisabled  (bool, default false = warnings enabled)
local addonName = ...
local Addon = _G[addonName]
if not Addon then return end

local L = Addon.L or {}

-- ── Debug logger ─────────────────────────────────────────────────────────────
-- Dumps everything knowable about BonusRollFrame and related APIs to chat.
-- Called once each time the frame becomes visible. Remove when done exploring.
local function DebugDumpBonusRoll()
    local function p(msg) print("|cff00ccff[BonusRoll]|r " .. tostring(msg)) end
    local function dump(label, val)
        local t = type(val)
        if t == "table" then
            p(label .. " = <table>")
            for k, v in pairs(val) do
                p("  ." .. tostring(k) .. " = " .. tostring(v))
            end
        else
            p(label .. " = " .. tostring(val) .. "  (" .. t .. ")")
        end
    end

    p("───── BonusRollFrame opened ─────")

    -- 1. Top-level frame fields (strings, numbers, booleans only)
    if BonusRollFrame then
        local skip = { ["0"] = true }  -- skip numeric widget children
        for k, v in pairs(BonusRollFrame) do
            local t = type(v)
            if t ~= "function" and t ~= "userdata" and not skip[tostring(k)] then
                p("BonusRollFrame." .. tostring(k) .. " = " .. tostring(v))
            end
        end
    else
        p("BonusRollFrame = nil")
    end

    -- 2. C_BonusRoll namespace
    if C_BonusRoll then
        p("C_BonusRoll exists:")
        for k, v in pairs(C_BonusRoll) do
            p("  C_BonusRoll." .. tostring(k) .. " = " .. tostring(v))
        end
        -- Try common query calls safely
        local calls = {
            "GetActiveLootSpec",
            "GetNumBonusRollTokens",
        }
        for _, name in ipairs(calls) do
            if type(C_BonusRoll[name]) == "function" then
                local ok, r1, r2, r3 = pcall(C_BonusRoll[name])
                p("  C_BonusRoll." .. name .. "() => ok=" .. tostring(ok) .. " r1=" .. tostring(r1) .. " r2=" .. tostring(r2) .. " r3=" .. tostring(r3))
            end
        end
    else
        p("C_BonusRoll = nil")
    end

    -- 3. GetLootSpecialization / loot-related globals
    if GetLootSpecialization then
        local ok, v = pcall(GetLootSpecialization)
        p("GetLootSpecialization() = " .. tostring(ok) .. " / " .. tostring(v))
    end

    -- 4. EJ (Encounter Journal) — current encounter
    if EJ_GetCurrentInstance then
        local ok, instID = pcall(EJ_GetCurrentInstance)
        p("EJ_GetCurrentInstance() = " .. tostring(ok) .. " / " .. tostring(instID))
    end
    if EJ_GetEncounterInfo then
        -- Try to get current encounter from the frame itself
        local encID = BonusRollFrame and BonusRollFrame.encounterID
        if encID then
            local ok, name = pcall(EJ_GetEncounterInfo, encID)
            p("EJ_GetEncounterInfo(" .. tostring(encID) .. ") = " .. tostring(ok) .. " / " .. tostring(name))
        else
            p("BonusRollFrame.encounterID = nil")
        end
    end

    -- 5. BONUS_ROLL_STARTED event args are not available here (already fired),
    --    but check if the frame stores them
    local fields = { "encounterID", "uiTextureKit", "currencyID", "currencyAmount",
                     "rollType", "lootSpec", "itemID", "numRolls" }
    for _, f in ipairs(fields) do
        local v = BonusRollFrame and BonusRollFrame[f]
        if v ~= nil then p("BonusRollFrame." .. f .. " = " .. tostring(v)) end
    end

    -- 6. Currency token balance
    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        -- Common bonus roll currency IDs (Timewarped Badge, various seals)
        local tryIDs = { 1166, 1273, 1274, 1275, 1276, 1721, 2032, 2815 }
        for _, id in ipairs(tryIDs) do
            local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, id)
            if ok and info and (info.quantity or 0) > 0 then
                p("Currency[" .. id .. "] " .. tostring(info.name) .. " = " .. tostring(info.quantity))
            end
        end
    end

    -- 7. BONUS_ROLL events registered on the frame
    p("Registered events on BonusRollFrame:")
    if BonusRollFrame.GetNumEvents then  -- not standard; just guard
        p("  (GetNumEvents not available)")
    end

    p("───── end dump ─────")
end

-- ── Module state ─────────────────────────────────────────────────────────────
local _warn            -- cached warn panel { holder, label, dismissBtn }
local _hooksInstalled  -- guard against double-hooking on UI reload

-- ── Addon:CheckBonusRollWarning ───────────────────────────────────────────────
--- Called whenever BonusRollFrame becomes visible.
--- Shows the warning panel unless the player has permanently dismissed it.
function Addon:CheckBonusRollWarning()
    if _warn then _warn.holder:Hide() end
    return -- warning temporarily disabled

    -- local prefs = self:EnsurePrefs()
    -- if prefs.bonusRollWarnDisabled then return end
    -- if not _warn then return end

    -- local msg = L.BONUS_ROLL_WARN_MSG or "|cffff6600Warning:|r Are you sure you want to use a bonus roll?"
    -- local msg = L.BONUS_ROLL_WARN_MSG or "|cffff6600Warning:|r Bonus rolls are currently bugged.\nIt is recommended to not use them."
    -- _warn.label:SetText(msg)
    -- _warn.holder:Show()
end

-- ── Deferred setup ────────────────────────────────────────────────────────────
-- BonusRollFrame is part of the base UI but may not exist until the bonus-roll
-- UI has been initialised for the first time this session.  We hook it lazily.

local function SetupHooks()
    if _hooksInstalled then return end
    if not BonusRollFrame then return end
    _hooksInstalled = true

    -- ── Warning panel (themed backdrop matching the addon's windows) ─────────
    local PAD_W   = 10
    local BODY_H  = 42   -- two explicit lines of GameFontNormal (~17 px each + line spacing)
    local BTN_H   = 22
    local PANEL_H = PAD_W + BODY_H + 6 + BTN_H + PAD_W

    local holder = Addon:NewThemedFrame(nil, UIParent)
    holder:SetFrameStrata("DIALOG")
    holder:SetFrameLevel(200)
    holder:SetSize(320, PANEL_H)
    holder:SetClampedToScreen(true)
    holder:EnableMouse(true)
    -- Anchor directly below BonusRollFrame, horizontally centred.
    holder:SetPoint("TOP", BonusRollFrame, "BOTTOM", 0, -6)
    local bg = Addon.THEME.bg
    holder:SetBackdropColor(bg.r, bg.g, bg.b, 1.0)
    if holder.SetBackdropBorderColor then
        local bdr = Addon.THEME.border
        holder:SetBackdropBorderColor(bdr.r, bdr.g, bdr.b, bdr.a or 1)
    end
    holder:Hide()

    -- Warning message.
    local label = holder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT",  holder, "TOPLEFT",  PAD_W,  -PAD_W)
    label:SetPoint("TOPRIGHT", holder, "TOPRIGHT", -PAD_W, -PAD_W)
    label:SetJustifyH("CENTER")
    label:SetTextColor(1, 0.4, 0.4)
    label:SetWordWrap(true)

    -- "Hide" button — permanently silences this warning.
    local dismissBtn = CreateFrame("Button", nil, holder, "UIPanelButtonTemplate")
    dismissBtn:SetSize(200, BTN_H)
    dismissBtn:SetPoint("TOP", label, "BOTTOM", 0, -6)
    dismissBtn:SetText(L.BONUS_ROLL_WARN_DISABLE_BTN or "Hide Bonus Roll Warning")
    dismissBtn:SetScript("OnEnter", function(self)
        Addon.AddonUtils.SetTooltip(self, L.BONUS_ROLL_WARN_DISABLE_TOOLTIP or "There is no duplicate protection.", "ANCHOR_BOTTOM")
    end)
    dismissBtn:SetScript("OnLeave", Addon.AddonUtils.HideTooltip)
    dismissBtn:SetScript("OnClick", function()
        Addon:EnsurePrefs().bonusRollWarnDisabled = true
        holder:Hide()
        if Addon.RefreshSettingsCheckboxes then Addon:RefreshSettingsCheckboxes() end
        if Addon.SyncGearPopup then Addon:SyncGearPopup() end
    end)

    _warn = { holder = holder, label = label, dismissBtn = dismissBtn }

    -- Show the warning one frame after BonusRollFrame becomes visible so that
    -- the frame has finished its own OnShow layout.
    hooksecurefunc(BonusRollFrame, "Show", function()
        C_Timer.After(0, function()
            DebugDumpBonusRoll()
            Addon:CheckBonusRollWarning()
        end)
    end)
    hooksecurefunc(BonusRollFrame, "Hide", function()
        if _warn then _warn.holder:Hide() end
    end)
end

-- BonusRollFrame may already be loaded (UI reload) or appear later.
if BonusRollFrame then
    SetupHooks()
else
    local setupFrame = CreateFrame("Frame")
    setupFrame:RegisterEvent("ADDON_LOADED")
    setupFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    setupFrame:SetScript("OnEvent", function(self, event, arg1)
        -- Blizzard may ship the bonus-roll UI as a standalone addon or inline.
        -- Check both the addon-load event and a deferred world-entry check.
        if event == "ADDON_LOADED" and arg1 ~= "Blizzard_BonusRollUI" then return end
        if BonusRollFrame then
            self:UnregisterAllEvents()
            SetupHooks()
        end
    end)
end

-- ── Locale key reference (for translators) ────────────────────────────────────
-- L.BONUS_ROLL_WARN_MSG              — Warning text shown in the panel body.
-- L.BONUS_ROLL_WARN_DISABLE_BTN      — Label for the inline Hide button.
-- L.BONUS_ROLL_WARN_DISABLE_TOOLTIP  — Tooltip for the Hide button.
-- L.OPTIONS_DISABLE_BONUS_ROLL_WARN  — Label for the Settings panel checkbox.
