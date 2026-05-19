-- Gear popup: small floating panel with the 8 display toggles.
-- Appears when the gear icon in the main window header is clicked.
local addonName = ...
local Addon = _G[addonName]
if not Addon then return end

local function SetCheckText(checkButton, text)
    if not checkButton then return end
    local lbl = checkButton._label
    if lbl then
        lbl:SetText(text or "")
        local txt = Addon.THEME and Addon.THEME.text
        if lbl.SetTextColor and txt then
            lbl:SetTextColor(txt.r, txt.g, txt.b, txt.a or 1)
        end
    end
end

local OpenPopupColorPicker = Addon.Controls.OpenColorPicker

-- Native language names for the locale toggle button shown to non-English clients.
local LOCALE_NATIVE_NAMES = {
    deDE = "Deutsch",
    esES = "Español",
    esMX = "Español",
    frFR = "Français",
    itIT = "Italiano",
    koKR = "한국어",
    ptBR = "Português",
    ruRU = "Русский",
    trTR = "Türkçe",
}

-- (GetSupportLinks and MakePopupSwatch removed; use Addon:GetSupportLinks() and Addon.Controls.NewSwatch)

-- Shared color definitions (owned by the main file; GearPopup is a consumer).
local GEAR_COLOR_DEFS = Addon.THEME_COLOR_DEFS

function Addon:SyncGearPopup()
    local p = self._gearPopup
    if not p then return end
    local db = self:EnsurePrefs()
    local L  = self.L or {}
    local function Sync(cb, checked, label)
        if cb then
            cb:SetChecked(checked)
            SetCheckText(cb, label)
        end
    end

    -- Pane 1: Display
    Sync(p._cbHideCompletedTasks, db.hideCompletedTasks and true or false,
         L.OPTIONS_HIDE_COMPLETED_TASKS or "Hide Completed Tasks")
    Sync(p._cbHideCompleted,    db.hideCompletedSections and true or false,
         L.HIDE_FINISHED_WEEKS or "Hide Finished Weeks")
    -- Dim the "Hide Finished Weeks" row when "Hide Completed Tasks" is active.
    do
        local dim = db.hideCompletedTasks and true or false
        Addon.Controls.SetCheckEnabled(p._cbHideCompleted, not dim)
    end
    Sync(p._cbHideGreatVault,   not db.showGreatVault,
         L.OPTIONS_HIDE_GREAT_VAULT  or "Hide Great Vault")
    Sync(p._cbHideCurrency,     not db.showCurrency,
         L.OPTIONS_HIDE_CURRENCY     or "Hide Currency")
    Sync(p._cbHideChangeWeek,   db.showChangeWeekBtn == false,
         L.OPTIONS_HIDE_CHANGE_WEEK_BTN or "Hide Week Selector")
    Sync(p._cbHideIlvlRef,      db.showIlvlRefBtn == false,
         L.OPTIONS_HIDE_ILVL_REF_BTN or "Hide Item Level Popup")
    local _minimap = Addon.db and Addon.db.global and Addon.db.global.minimap
    Sync(p._cbHideMinimapBtn, _minimap and _minimap.hide and true or false,
         L.OPTIONS_HIDE_MINIMAP_BTN or "Hide Minimap Button")
    Sync(p._cbHideCharPicker,   db.showCharPickerBtn == false,
         "Hide Swap Profile")
    Sync(p._cbHideAltSummary,   db.showAltSummaryBtn == false,
         "Hide Alt Summary")

    -- Pane 2: Warnings
    Sync(p._cbHideUpdateNotice, db.hideUpdateNotice and true or false,
         L.OPTIONS_HIDE_UPDATE_NOTICE or "Hide Update Warnings")
    Sync(p._cbDisableUpgradeWarn, db.upgradeWarnDisabled and true or false,
         L.OPTIONS_DISABLE_UPGRADE_WARN or "Hide Upgrade Warnings")
    Sync(p._cbDisableCraftWarn, db.craftWarnDisabled and true or false,
         L.OPTIONS_DISABLE_CRAFT_WARN or "Hide Crafting Warnings")

    -- Refresh color swatch labels in case locale changed since popup was built.
    if p._gearColorLabels then
        for si, sd in ipairs(GEAR_COLOR_DEFS) do
            local lbl = p._gearColorLabels[si]
            if lbl then lbl:SetText(L[sd.labelKey] or sd.label) end
        end
    end

    -- Reset button label.
    if p._gearResetBtn then
        p._gearResetBtn:SetText(L.RESET_BUTTON or "Reset List")
    end

    -- Restore Hidden button.
    do
        local nCur    = Addon.GetHiddenCurrencyList and #Addon:GetHiddenCurrencyList() or 0
        local nGV     = Addon.GetHiddenGVBlockList  and #Addon:GetHiddenGVBlockList()  or 0
        local nQuest  = Addon.GetHiddenQuestList    and #Addon:GetHiddenQuestList()    or 0
        local nHidden = nCur + nGV + nQuest
        if p._restoreHiddenBtn then
            p._restoreHiddenBtn:SetShown(nHidden > 0)
            if nHidden > 0 then
                local s = nHidden == 1 and "1 Hidden Row" or (nHidden .. " Hidden Rows")
                p._restoreHiddenBtn:SetText("Restore " .. s)
                if Addon._styleActionButton then Addon._styleActionButton(p._restoreHiddenBtn) end
            end
        end
    end

    -- Language toggle: show only for non-English WoW clients.
    local _wowLocale     = (GetLocale and GetLocale()) or "enUS"
    local _effLocale     = (self.GetEffectiveLocaleCode and self:GetEffectiveLocaleCode()) or "enUS"
    local showLangToggle = _wowLocale ~= "enUS"
    if p._gearLangBtn and p._gearLangDiv then
        p._gearLangBtn:SetShown(showLangToggle)
        p._gearLangDiv:SetShown(showLangToggle)
        if showLangToggle then
            if _effLocale ~= "enUS" then
                p._gearLangBtn:SetText("English")
            else
                p._gearLangBtn:SetText(LOCALE_NATIVE_NAMES[_wowLocale] or _wowLocale)
            end
            if Addon._styleActionButton then Addon._styleActionButton(p._gearLangBtn) end
        end
    end

    -- Re-apply custom styling after all SetText / SetEnabled calls above.
    if Addon._styleActionButton then
        if p._gearResetBtn then Addon._styleActionButton(p._gearResetBtn) end
    end

    -- Sync slider thumbs to current saved values.
    if p._scaleSync then p._scaleSync() end
    if p._opacSync  then p._opacSync()  end

    -- Sync the compact color swatch colors to current saved values.
    if p._gearColorSwatches then
        for i, def in ipairs(GEAR_COLOR_DEFS) do
            local sw = p._gearColorSwatches[i]
            if sw then sw:SetColor(def:get()) end
        end
    end

    -- Re-apply tab colours (active tab gets header colour, others are dimmed).
    if p._ShowTab then p._ShowTab(p._activeTab or 1) end
end

function Addon:ToggleGearPopup(anchor, growRight)
    local p = self._gearPopup
    -- Guard: suppress reopen if the outside-click catcher closed us within 200 ms.
    if p and p._lariasClosedAt and (GetTime() - p._lariasClosedAt) < 0.20 then p._lariasClosedAt = nil; return end
    if p and p.IsShown and p:IsShown() then
        p:Hide()
        return
    end

    -- Create lazily.
    if not p then
        p = Addon.Controls.NewPopupPanel("DIALOG", 0.12)
        if p.SetBackdropBorderColor then p:SetBackdropBorderColor(Addon.THEME.border.r, Addon.THEME.border.g, Addon.THEME.border.b, 1) end

        -- ── Layout constants ─────────────────────────────────────────────────
        local POPUP_W     = 340
        local POPUP_H     = 330
        local PAD         = 10
        local BTN_H       = 22
        local TILE_H      = 28    -- checkbox tile height (box + padding)
        local TAB_BTN_H   = 22
        local TAB_GAP     = 6     -- gap between tab-button row and pane content
        local PANE_TOP    = PAD + TAB_BTN_H + TAB_GAP   -- 38 px from popup top
        local BOTTOM_H    = 80    -- px reserved at bottom for support links + credit
        local NUM_TABS    = 3
        local TAB_GAP_BTN = 4     -- gap between adjacent tab buttons
        local TAB_W       = math.floor((POPUP_W - 2 * PAD - (NUM_TABS - 1) * TAB_GAP_BTN) / NUM_TABS)

        p:SetSize(POPUP_W, POPUP_H)

        -- ── Tab buttons ──────────────────────────────────────────────────────
        local TAB_LABELS = { "Display", "Warnings", "Appearance" }
        p._tabs  = {}
        p._panes = {}

        for i = 1, NUM_TABS do
            local tx = PAD + (i - 1) * (TAB_W + TAB_GAP_BTN)
            local tb = Addon.Controls.NewActionButton(p, TAB_W, TAB_BTN_H)
            tb:SetPoint("TOPLEFT", p, "TOPLEFT", tx, -PAD)
            tb:SetText(TAB_LABELS[i])
            local _i = i
            tb:SetScript("OnClick", function()
                if p._ShowTab then p._ShowTab(_i) end
            end)
            -- Active indicator: thin gold bar at the bottom of the active tab button.
            local bar = tb:CreateTexture(nil, "OVERLAY")
            bar:SetColorTexture(Addon.THEME.header.r, Addon.THEME.header.g, Addon.THEME.header.b, 1)
            bar:SetPoint("BOTTOMLEFT",  tb, "BOTTOMLEFT",  2, 1)
            bar:SetPoint("BOTTOMRIGHT", tb, "BOTTOMRIGHT", -2, 1)
            bar:SetHeight(2)
            bar:Hide()
            tb._activeBar = bar
            p._tabs[i] = tb
        end

        -- ── Pane frames (one per tab, fills between tab row and bottom section) ──
        for i = 1, NUM_TABS do
            local pane = CreateFrame("Frame", nil, p)
            pane:SetPoint("TOPLEFT",     p, "TOPLEFT",     0, -PANE_TOP)
            pane:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 0,  BOTTOM_H)
            pane:Hide()
            p._panes[i] = pane
        end
        local pane1, pane2, pane3 = p._panes[1], p._panes[2], p._panes[3]

        -- ── ShowTab helper ───────────────────────────────────────────────────
        local function ShowTab(tabIdx)
            p._activeTab = tabIdx
            local hdr = Addon.THEME.header
            for i = 1, NUM_TABS do
                local tb = p._tabs[i]
                local pn = p._panes[i]
                local tr = Addon.Controls.GetButtonFontString(tb)
                if i == tabIdx then
                    if tr then tr:SetTextColor(hdr.r, hdr.g, hdr.b, 1) end
                    if tb._activeBar then tb._activeBar:Show() end
                    if pn then pn:Show() end
                else
                    if tr then tr:SetTextColor(0.5, 0.5, 0.5, 1) end
                    if tb._activeBar then tb._activeBar:Hide() end
                    if pn then pn:Hide() end
                end
            end
        end
        p._ShowTab = ShowTab

        -- ── Callbacks ────────────────────────────────────────────────────────
        local callbacks = {
            _cbHideCompletedTasks = function(checked)
                local db = Addon:EnsurePrefs()
                db.hideCompletedTasks = checked
                if checked then db.hideCompletedSections = true end
                if Addon.SyncGearPopup then Addon:SyncGearPopup() end
                if Addon.LayoutHeaderButtons then Addon:LayoutHeaderButtons() end
                if Addon.RequestRefresh then Addon:RequestRefresh() else Addon:Refresh() end
            end,
            _cbHideCompleted = function(checked)
                local db = Addon:EnsurePrefs()
                db.hideCompletedSections = checked
                if Addon.LayoutHeaderButtons then Addon:LayoutHeaderButtons() end
                if Addon.RequestRefresh then Addon:RequestRefresh() else Addon:Refresh() end
            end,
            _cbHideGreatVault = function(checked)
                local db = Addon:EnsurePrefs()
                db.showGreatVault = not checked
                if Addon.RequestRefresh then Addon:RequestRefresh() else Addon:Refresh() end
            end,
            _cbHideCurrency = function(checked)
                local db = Addon:EnsurePrefs()
                db.showCurrency = not checked
                if Addon.RequestRefresh then Addon:RequestRefresh() else Addon:Refresh() end
            end,
            _cbHideChangeWeek = function(checked)
                local db = Addon:EnsurePrefs()
                db.showChangeWeekBtn = not checked
                if Addon.LayoutHeaderButtons then Addon:LayoutHeaderButtons() end
            end,
            _cbHideIlvlRef = function(checked)
                local db = Addon:EnsurePrefs()
                db.showIlvlRefBtn = not checked
                if Addon.LayoutHeaderButtons then Addon:LayoutHeaderButtons() end
            end,
            _cbHideMinimapBtn = function(checked)
                local gdb = Addon.db and Addon.db.global
                if gdb then
                    gdb.minimap = gdb.minimap or {}
                    gdb.minimap.hide = checked or nil
                end
                local ok, icon = pcall(function() return LibStub("LibDBIcon-1.0") end)
                if ok and icon then
                    if checked then icon:Hide(addonName) else icon:Show(addonName) end
                end
            end,
            _cbHideCharPicker = function(checked)
                local db = Addon:EnsurePrefs()
                db.showCharPickerBtn = not checked
                if Addon.LayoutHeaderButtons then Addon:LayoutHeaderButtons() end
            end,
            _cbHideAltSummary = function(checked)
                local db = Addon:EnsurePrefs()
                db.showAltSummaryBtn = not checked
                if Addon.CharPicker and Addon.CharPicker.Populate then Addon.CharPicker.Populate() end
            end,
            _cbHideUpdateNotice = function(checked)
                local db = Addon:EnsurePrefs()
                db.hideUpdateNotice = checked
                if not checked then
                    if Addon.RequestVersions then Addon:RequestVersions(false) end
                end
                if Addon.UpdateStatusBanner then Addon:UpdateStatusBanner() end
            end,
            _cbDisableUpgradeWarn = function(checked)
                local db = Addon:EnsurePrefs()
                db.upgradeWarnDisabled = checked or nil
                if Addon.CheckUpgradeWarning then Addon:CheckUpgradeWarning() end
            end,
            _cbDisableCraftWarn = function(checked)
                local db = Addon:EnsurePrefs()
                db.craftWarnDisabled = checked or nil
                if Addon.CheckCraftingWarning then Addon:CheckCraftingWarning() end
            end,
        }

        -- ── Pane 1: Display ──────────────────────────────────────────────────
        do
            -- Reset List button.
            local resetBtn = Addon.Controls.NewActionButton(pane1, nil, BTN_H)
            resetBtn:SetPoint("TOPLEFT",  pane1, "TOPLEFT",  PAD,  -PAD)
            resetBtn:SetPoint("TOPRIGHT", pane1, "TOPRIGHT", -PAD, -PAD)
            resetBtn:SetScript("OnClick", function() Addon:PerformFullReset() end)
            p._gearResetBtn = resetBtn

            -- Divider below reset button.
            Addon.Controls.NewDivider(pane1, -(PAD + BTN_H + 4), PAD, PAD)

            -- 9 checkboxes: left col 5 rows, right col 4 rows.
            local DISPLAY_CHECKS = {
                { key = "_cbHideCompletedTasks", tooltipKey = "OPTIONS_TOOLTIP_HIDE_COMPLETED_TASKS" },
                { key = "_cbHideCompleted",       tooltipKey = "OPTIONS_TOOLTIP_HIDE_FINISHED_WEEKS"  },
                { key = "_cbHideGreatVault",      tooltipKey = "OPTIONS_TOOLTIP_HIDE_GREAT_VAULT"     },
                { key = "_cbHideCurrency",        tooltipKey = "OPTIONS_TOOLTIP_HIDE_CURRENCY"        },
                { key = "_cbHideChangeWeek",      tooltipKey = "OPTIONS_TOOLTIP_HIDE_CHANGE_WEEK_BTN" },
                { key = "_cbHideIlvlRef",         tooltipKey = "OPTIONS_TOOLTIP_HIDE_ILVL_REF_BTN"    },
                { key = "_cbHideMinimapBtn",      tooltipKey = "OPTIONS_TOOLTIP_HIDE_MINIMAP_BTN"     },
                { key = "_cbHideCharPicker",      tooltipKey = nil                                    },
                { key = "_cbHideAltSummary",      tooltipKey = nil                                    },
            }
            local cbsY  = PAD + BTN_H + 4 + 1 + 6   -- 43 px from pane1 top to first tile
            local COL_W = math.floor((POPUP_W - 2 * PAD) / 2)

            for i, info in ipairs(DISPLAY_CHECKS) do
                local col      = (i <= 5) and 0 or 1
                local ri       = (i <= 5) and (i - 1) or (i - 6)
                local colX     = PAD + col * COL_W
                local tileTopY = -(cbsY + ri * TILE_H)
                local _key     = info.key

                local cb = Addon.Controls.NewCheckBox(pane1, function(newState)
                    callbacks[_key](newState)
                    if Addon.SyncGearPopup then Addon:SyncGearPopup() end
                end)
                cb:SetPoint("TOPLEFT", pane1, "TOPLEFT", colX, tileTopY)
                cb:SetHeight(TILE_H)
                cb._label:SetPoint("RIGHT", pane1, "TOPLEFT", colX + COL_W - 4, 0)
                p[_key] = cb

                if info.tooltipKey then
                    local _tooltipKey = info.tooltipKey
                    cb:SetScript("OnEnter", function(self_)
                        local tip = Addon.L and Addon.L[_tooltipKey]
                        if tip then Addon.AddonUtils.SetTooltip(self_, tip) end
                    end)
                    cb:SetScript("OnLeave", Addon.AddonUtils.HideTooltip)
                end

                local hit = cb._hit
                hit:SetPoint("TOPLEFT",  pane1, "TOPLEFT", colX,         tileTopY)
                hit:SetPoint("TOPRIGHT", pane1, "TOPLEFT", colX + COL_W, tileTopY)
                hit:SetHeight(TILE_H)
            end

            -- Restore Hidden Currencies button (below the 5-row left column).
            local restoreY = cbsY + 5 * TILE_H + 4   -- 187 px from pane1 top
            local restoreBtn = Addon.Controls.NewActionButton(pane1, nil, BTN_H)
            restoreBtn:SetPoint("TOPLEFT",  pane1, "TOPLEFT",  PAD,  -restoreY)
            restoreBtn:SetPoint("TOPRIGHT", pane1, "TOPRIGHT", -PAD, -restoreY)
            restoreBtn:SetScript("OnClick", function()
                Addon:ToggleRestoreHiddenCurrencies(p)
            end)
            restoreBtn:Hide()
            p._restoreHiddenBtn = restoreBtn
        end

        -- ── Pane 2: Warnings ─────────────────────────────────────────────────
        do
            local WARN_CHECKS = {
                { key = "_cbHideUpdateNotice",   tooltipKey = "OPTIONS_TOOLTIP_HIDE_UPDATE_NOTICE"    },
                { key = "_cbDisableUpgradeWarn", tooltipKey = "OPTIONS_TOOLTIP_DISABLE_UPGRADE_WARN"  },
                { key = "_cbDisableCraftWarn",   tooltipKey = "OPTIONS_TOOLTIP_DISABLE_CRAFT_WARN"    },
            }
            for i, info in ipairs(WARN_CHECKS) do
                local tileTopY = -(PAD + (i - 1) * TILE_H)
                local _key     = info.key

                local cb = Addon.Controls.NewCheckBox(pane2, function(newState)
                    callbacks[_key](newState)
                    if Addon.SyncGearPopup then Addon:SyncGearPopup() end
                end)
                cb:SetPoint("TOPLEFT", pane2, "TOPLEFT", PAD, tileTopY)
                cb:SetHeight(TILE_H)
                cb._label:SetPoint("RIGHT", pane2, "TOPRIGHT", -PAD, 0)
                p[_key] = cb

                if info.tooltipKey then
                    local _tooltipKey = info.tooltipKey
                    cb:SetScript("OnEnter", function(self_)
                        local tip = Addon.L and Addon.L[_tooltipKey]
                        if tip then Addon.AddonUtils.SetTooltip(self_, tip) end
                    end)
                    cb:SetScript("OnLeave", Addon.AddonUtils.HideTooltip)
                end

                local hit = cb._hit
                hit:SetPoint("TOPLEFT",  pane2, "TOPLEFT",  PAD,  tileTopY)
                hit:SetPoint("TOPRIGHT", pane2, "TOPRIGHT", -PAD, tileTopY)
                hit:SetHeight(TILE_H)
            end
        end

        -- ── Pane 3: Appearance ────────────────────────────────────────────────
        do
            local SROW_H_P    = (Addon.UI.sliderLabelH or 14) + 2 + math.max(16, Addon.UI.sliderH or 20)
            local SLIDER_W    = 190
            local COLOR_COL_X = PAD + SLIDER_W + 10   -- x of color swatch column from pane3 left

            -- Scale slider.
            local scalePaneP = CreateFrame("Frame", nil, pane3)
            scalePaneP:SetPoint("TOPLEFT", pane3, "TOPLEFT", PAD, -PAD)
            scalePaneP:SetSize(SLIDER_W, SROW_H_P)
            scalePaneP:EnableMouse(true)
            p._scaleSync = Addon:CreateSliderWidget(scalePaneP, {
                minV       = 50, maxV = 150, stepV = 1,
                getVal     = function()
                    local gdb = Addon.db and Addon.db.global
                    return (gdb and tonumber(gdb.uiScalePct)) or 100
                end,
                applyFn    = function(pct)
                    local gdb = Addon.db and Addon.db.global
                    if gdb then gdb.uiScalePct = pct end
                    if Addon.ApplyUIScale then Addon:ApplyUIScale() end
                end,
                minLabel   = (Addon.L or {}).UI_SCALE_MIN_LABEL or "50%",
                maxLabel   = (Addon.L or {}).UI_SCALE_MAX_LABEL or "150%",
                fmtFn      = function(v) return math.floor(v + 0.5) .. "%" end,
                titleLabel = (Addon.L or {}).UI_SCALE_LABEL     or "Scale",
            })

            -- Opacity slider.
            local opacPaneP = CreateFrame("Frame", nil, pane3)
            opacPaneP:SetPoint("TOPLEFT", pane3, "TOPLEFT", PAD, -(PAD + SROW_H_P + 8))
            opacPaneP:SetSize(SLIDER_W, SROW_H_P)
            opacPaneP:EnableMouse(true)
            p._opacSync = Addon:CreateSliderWidget(opacPaneP, {
                minV       = 10, maxV = 100, stepV = 5,
                getVal     = function()
                    local gdb = Addon.db and Addon.db.global
                    return (gdb and tonumber(gdb.uiOpacityPct)) or 65
                end,
                applyFn    = function(pct)
                    local gdb = Addon.db and Addon.db.global
                    if gdb then gdb.uiOpacityPct = pct end
                    if Addon.ApplyOpacity then Addon:ApplyOpacity() end
                end,
                minLabel   = (Addon.L or {}).UI_OPACITY_MIN_LABEL or "10%",
                maxLabel   = (Addon.L or {}).UI_OPACITY_MAX_LABEL or "100%",
                fmtFn      = function(v) return math.floor(v + 0.5) .. "%" end,
                titleLabel = (Addon.L or {}).UI_OPACITY_LABEL     or "Opacity",
                liveApply  = true,
            })

            -- Divider below both sliders.
            local colorDivY = PAD + SROW_H_P + 8 + SROW_H_P + 8
            Addon.Controls.NewDivider(pane3, -colorDivY, PAD, PAD)

            -- Three compact color swatches stacked below the divider.
            local swatchStartY = colorDivY + 1 + 8
            p._gearColorSwatches = {}
            p._gearColorLabels   = {}
            for si, sd in ipairs(GEAR_COLOR_DEFS) do
                local swTopY = -(swatchStartY + (si - 1) * 20)
                local _L     = Addon.L or {}

                local sw = Addon.Controls.NewSwatch(pane3, 16)
                sw:SetPoint("TOPLEFT", pane3, "TOPLEFT", COLOR_COL_X, swTopY)
                sw:SetColor(sd:get())
                sw:SetScript("OnClick", function()
                    local cr, cg, cb = sd:get()
                    OpenPopupColorPicker(cr, cg, cb,
                        function(nr, ng, nb) sd:save(nr, ng, nb); sw:SetColor(nr, ng, nb) end,
                        function(pr, pg, pb) sd:save(pr, pg, pb); sw:SetColor(pr, pg, pb) end
                    )
                end)
                p._gearColorSwatches[si] = sw

                local lbl = pane3:CreateFontString(nil, "OVERLAY")
                lbl:SetFont("Fonts\\FRIZQT__.TTF", 9, "")
                lbl:SetText(_L[sd.labelKey] or sd.label)
                lbl:SetTextColor(0.70, 0.70, 0.70, 1)
                lbl:SetPoint("LEFT", sw, "RIGHT", 4, 0)
                p._gearColorLabels[si] = lbl
            end

            -- Language toggle (shown only for non-English WoW clients).
            local langDivY    = swatchStartY + 3 * 20 + 8
            local langDivider = Addon.Controls.NewDivider(pane3, -langDivY, PAD, PAD)
            langDivider:Hide()
            p._gearLangDiv = langDivider

            local langBtnY = langDivY + 1 + 6
            local langBtn  = Addon.Controls.NewActionButton(pane3, nil, BTN_H)
            langBtn:SetPoint("TOPLEFT",  pane3, "TOPLEFT",  PAD,  -langBtnY)
            langBtn:SetPoint("TOPRIGHT", pane3, "TOPRIGHT", -PAD, -langBtnY)
            langBtn:Hide()
            langBtn:SetScript("OnClick", function()
                if not Addon.SetLocaleOverride then return end
                local eff = (Addon.GetEffectiveLocaleCode and Addon:GetEffectiveLocaleCode()) or "enUS"
                if eff ~= "enUS" then
                    Addon:SetLocaleOverride("enUS")
                else
                    Addon:SetLocaleOverride("auto")
                end
                if Addon.SyncGearPopup then Addon:SyncGearPopup() end
                if Addon.RequestRefresh then Addon:RequestRefresh() else Addon:Refresh() end
            end)
            p._gearLangBtn = langBtn
        end

        -- ── Bottom section (always visible): divider, support links, credit ──
        do
            local _getMeta = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
            local _ver     = (_getMeta and _getMeta(addonName, "Version")) or ""
            local _locReg  = _G["LARIASWEEKLYCHECKLIST_LOCALE_REGISTRY"]
            local _dataVer = (_locReg and type(_locReg.sheet_version) == "string" and _locReg.sheet_version) or ""

            local creditLabel = p:CreateFontString(nil, "OVERLAY")
            creditLabel:SetFont("Fonts\\FRIZQT__.TTF", 9, "")
            creditLabel:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 8, 5)
            creditLabel:SetJustifyH("LEFT")
            creditLabel:SetText("Built by Dev  \226\128\162  Approved by Larias")
            creditLabel:SetTextColor(0.45, 0.45, 0.45, 0.6)

            local verLabel = p:CreateFontString(nil, "OVERLAY")
            verLabel:SetFont("Fonts\\FRIZQT__.TTF", 9, "")
            verLabel:SetPoint("BOTTOMLEFT", creditLabel, "TOPLEFT", 0, 2)
            verLabel:SetJustifyH("LEFT")
            do
                local parts = {}
                if _ver     ~= "" then parts[#parts + 1] = "v" .. _ver          end
                if _dataVer ~= "" then parts[#parts + 1] = "Spreadsheet v" .. _dataVer end
                verLabel:SetText(table.concat(parts, "  \226\128\162  "))
            end
            verLabel:SetTextColor(0.45, 0.45, 0.45, 0.6)

            -- Divider above support buttons.
            Addon.Controls.NewDivider(p, 76, PAD, PAD, "BOTTOM")

            -- Three support link buttons.
            local SUPP_BTN_W = math.floor((POPUP_W - 2 * PAD - 8) / 3)
            for si, sl in ipairs(Addon:GetSupportLinks()) do
                local _url = sl.url
                local sx   = PAD + (si - 1) * (SUPP_BTN_W + 4)
                local sbtn = Addon.Controls.NewActionButton(p, SUPP_BTN_W, 22)
                sbtn:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", sx, 48)
                sbtn:SetText(sl.label)
                sbtn:SetScript("OnClick", function() Addon.OpenSupportLink(_url) end)
            end
        end

        self._gearPopup = p
        -- Apply saved opacity to the new popup (created with alpha=1.0).
        if self.ApplyOpacity then self:ApplyOpacity() end
    end

    -- Sync current values and labels (also calls ShowTab(1) to set initial state).
    self:SyncGearPopup()

    -- Position below the anchor or center if no anchor.
    -- growRight=true  → popup grows rightward (TOPLEFT anchored to anchor BOTTOMLEFT)
    -- growRight=false → popup grows leftward  (TOPRIGHT anchored to anchor BOTTOMRIGHT)
    p:ClearAllPoints()
    if anchor then
        if growRight then
            p:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
        else
            p:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -4)
        end
    else
        p:SetPoint("CENTER", UIParent, "CENTER")
    end
    p:Show()
end

--- Opens (or rebuilds) the restore-hidden-currencies panel anchored to `anchor`.
--- If `anchor` is nil, keeps the panel's current position.
function Addon:OpenRestoreHiddenCurrencies(anchor)
    -- Build a unified list: hidden currencies then hidden GV blocks.
    local combined = {}
    for _, e in ipairs(self:GetHiddenCurrencyList()) do
        local _id = e.id
        combined[#combined + 1] = {
            name      = e.name,
            onRestore = function() Addon:SetCurrencyHidden(_id, false) end,
        }
    end
    for _, e in ipairs(self:GetHiddenGVBlockList()) do
        local _idx = e.idx
        combined[#combined + 1] = {
            name      = e.name .. " |cff808080(Vault)|r",
            onRestore = function() Addon:SetGVBlockHidden(_idx, false) end,
        }
    end
    for _, e in ipairs(self:GetHiddenQuestList()) do
        local _qk = e.key
        combined[#combined + 1] = {
            name      = e.name .. " |cff808080(Quest)|r",
            onRestore = function() Addon:SetQuestHidden(_qk, false) end,
        }
    end
    if #combined == 0 then
        if self._restoreHiddenFrame then self._restoreHiddenFrame:Hide() end
        return
    end

    local f = self._restoreHiddenFrame
    local ROW_H, PAD, BTN_W = 22, 8, 70

    if not f then
        f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        f:SetFrameStrata("DIALOG")
        f:SetClampedToScreen(true)
        -- Close button
        local xClose = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        xClose:SetSize(18, 18)
        xClose:SetPoint("TOPRIGHT", f, "TOPRIGHT", 2, 2)
        xClose:SetScript("OnClick", function() f:Hide() end)
        f._rowFrames = {}
        self._restoreHiddenFrame = f
    end

    -- Apply theme backdrop.
    self:ApplyTheme(f)
    local bg = self.THEME and self.THEME.bg
    if bg then f:SetBackdropColor(bg.r, bg.g, bg.b, 1.0) end

    -- Title
    if not f._titleFS then
        f._titleFS = f:CreateFontString(nil, "OVERLAY")
        f._titleFS:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
        f._titleFS:SetPoint("TOPLEFT",  f, "TOPLEFT",  PAD, -PAD)
        f._titleFS:SetPoint("TOPRIGHT", f, "TOPRIGHT", -20, -PAD)
        f._titleFS:SetHeight(16)
        f._titleFS:SetJustifyH("LEFT")
    end
    local hdr = self.THEME and self.THEME.header
    if hdr then f._titleFS:SetTextColor(hdr.r, hdr.g, hdr.b, 1) end
    f._titleFS:SetText("Restore Hidden Currencies")

    -- Hide old row frames and rebuild.
    for _, rf in ipairs(f._rowFrames) do rf:Hide() end
    f._rowFrames = {}

    local th = self.THEME and self.THEME.text
    for ri, entry in ipairs(combined) do
        local rowY = -(PAD + 16 + 4 + (ri - 1) * ROW_H)
        local rf   = CreateFrame("Frame", nil, f)
        rf:SetPoint("TOPLEFT",  f, "TOPLEFT",  PAD, rowY)
        rf:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, rowY)
        rf:SetHeight(ROW_H)

        local nameFS = rf:CreateFontString(nil, "OVERLAY")
        nameFS:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
        nameFS:SetPoint("LEFT",  rf, "LEFT",  0, 0)
        nameFS:SetPoint("RIGHT", rf, "RIGHT", -(BTN_W + 4), 0)
        nameFS:SetJustifyH("LEFT")
        nameFS:SetJustifyV("MIDDLE")
        nameFS:SetText(entry.name)
        if th then nameFS:SetTextColor(th.r, th.g, th.b, 0.9) end

        local btn = Addon.Controls.NewActionButton(rf, nil, 18)
        btn:SetWidth(BTN_W)
        btn:SetPoint("RIGHT", rf, "RIGHT", 0, 0)
        btn:SetText("Restore")
        btn:SetScript("OnClick", function()
            entry.onRestore()
        end)
        if Addon._styleActionButton then Addon._styleActionButton(btn) end

        f._rowFrames[ri] = rf
    end

    local totalH = PAD + 16 + 4 + #combined * ROW_H + PAD
    f:SetSize(240, totalH)

    if anchor then
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 4, 0)
    elseif not (f.GetNumPoints and f:GetNumPoints() > 0) then
        f:SetPoint("CENTER")
    end
    f:Show()
end

--- Toggles the restore-hidden-currencies panel.
function Addon:ToggleRestoreHiddenCurrencies(anchor)
    local f = self._restoreHiddenFrame
    if f and f.IsShown and f:IsShown() then
        f:Hide()
    else
        self:OpenRestoreHiddenCurrencies(anchor)
    end
end
