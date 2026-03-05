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

-- Support resource URLs displayed in the Support section of the gear popup.
local SUPPORT_LINKS = {
    { label = "Guide Doc",  url = "https://docs.google.com/document/d/e/2PACX-1vTGkZ2Cjr0jlv90XqW9vy9VXsVucd-yMCgHdyCvX_kQfOrexNDAC7Lf3LifuhqxrcWqJ0W3zIhvK3ii/pub" },
    { label = "Checklist",  url = "https://docs.google.com/spreadsheets/d/1iK2SZUcz_ljnkdTG7KW6pqfzaUDuSgnlh1HupcLrkus/edit?gid=53744607#gid=53744607" },
    { label = "Discord",    url = "https://discord.gg/postnerfclarity" },
}

-- Creates a small 16×16 colored swatch button.  Call swatch:SetColor(r,g,b).
local function MakePopupSwatch(parent)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(16, 16)
    local border = btn:CreateTexture(nil, "ARTWORK", nil, 0)
    border:SetPoint("TOPLEFT",     btn, "TOPLEFT",     -1,  1)
    border:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT",  1, -1)
    border:SetColorTexture(0.55, 0.55, 0.55, 1)
    local fill = btn:CreateTexture(nil, "ARTWORK", nil, 1)
    fill:SetAllPoints(btn)
    fill:SetColorTexture(1, 1, 1, 1)
    btn._fill = fill
    function btn:SetColor(r, g, b) self._fill:SetColorTexture(r, g, b, 1) end
    return btn
end

-- Shared color-key / default table used by both creation and sync.
-- Each entry carries get() → r,g,b and save(r,g,b) closures so callers
-- don't need to reproduce the db-access boilerplate inline.
local function makeGearColorDef(labelKey, labelFallback, rk, gk, bk, dr, dg, db_)
    local def = { labelKey = labelKey, label = labelFallback, rk = rk, gk = gk, bk = bk, dr = dr, dg = dg, db = db_ }
    function def.get()
        local tc = (Addon.db and Addon.db.global and Addon.db.global.themeColors) or {}
        local r = (tc[rk] ~= nil) and tc[rk] or dr
        local g = (tc[gk] ~= nil) and tc[gk] or dg
        local b = (tc[bk] ~= nil) and tc[bk] or db_
        return r, g, b
    end
    function def.save(r, g, b)
        local gdb = Addon.db and Addon.db.global
        if not gdb then return end
        gdb.themeColors = gdb.themeColors or {}
        gdb.themeColors[rk] = r; gdb.themeColors[gk] = g; gdb.themeColors[bk] = b
        if Addon.ApplyThemeColors then Addon:ApplyThemeColors() end
    end
    return def
end
local GEAR_COLOR_DEFS = {
    makeGearColorDef("COLOR_PICKER_BG",   "Background", "bgR",     "bgG",     "bgB",     0.10, 0.10, 0.10),
    makeGearColorDef("COLOR_PICKER_TEXT", "Text",       "textR",   "textG",   "textB",   1.00, 1.00, 1.00),
    makeGearColorDef("COLOR_PICKER_HDR",  "Header",     "headerR", "headerG", "headerB", 1.00, 0.82, 0.00),
}

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
    Sync(p._cbHideCompletedTasks, db.hideCompletedTasks and true or false,
         L.OPTIONS_HIDE_COMPLETED_TASKS or "Hide Completed Tasks")
    Sync(p._cbHideCompleted,    db.hideCompletedSections and true or false,
         L.HIDE_FINISHED_WEEKS or "Hide Finished Weeks")
    -- Dim the "Hide Finished Weeks" row when "Hide Completed Tasks" is active.
    do
        local cb = p._cbHideCompleted
        if cb then
            local dim = db.hideCompletedTasks and true or false
            local a = dim and 0.40 or 1.00
            if cb._label then cb._label:SetAlpha(a) end
            if cb._box   then cb._box:SetAlpha(a)   end
            if cb._tick  then cb._tick:SetAlpha(a)  end
            if cb.EnableMouse then cb:EnableMouse(not dim) end
            if cb._hit and cb._hit.EnableMouse then cb._hit:EnableMouse(not dim) end
        end
    end
    Sync(p._cbHideGreatVault,   not db.showGreatVault,
         L.OPTIONS_HIDE_GREAT_VAULT  or "Hide Great Vault")
    Sync(p._cbHideCurrency,     not db.showCurrency,
         L.OPTIONS_HIDE_CURRENCY     or "Hide Currency")
    Sync(p._cbHideChangeWeek,   db.showChangeWeekBtn == false,
         L.OPTIONS_HIDE_CHANGE_WEEK_BTN or "Hide Week Selector")
    Sync(p._cbHideIlvlRef,      db.showIlvlRefBtn == false,
         L.OPTIONS_HIDE_ILVL_REF_BTN or "Hide Item Level Popup")
    Sync(p._cbHideUpdateNotice, db.hideUpdateNotice and true or false,
         L.OPTIONS_HIDE_UPDATE_NOTICE or "Hide Update Warnings")
    local _minimap = Addon.db and Addon.db.global and Addon.db.global.minimap
    Sync(p._cbHideMinimapBtn, _minimap and _minimap.hide and true or false,
         L.OPTIONS_HIDE_MINIMAP_BTN or "Hide Minimap Button")
    Sync(p._cbDisableUpgradeWarn, db.upgradeWarnDisabled and true or false,
         L.OPTIONS_DISABLE_UPGRADE_WARN or "Hide Upgrade Warnings")

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

    -- Language toggle: show only for non-English WoW clients.
    -- Button says "English" when they're in their native language, or their
    -- native language name when they've previously switched to English.
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

    -- Recalculate popup height based on visible content.
    do
        -- Layout is 2-column (5 left + 4 right); height uses 5 rows (the taller column).
        local PAD     = 10
        local TILE_H  = 34
        local cbsY    = 47  -- PAD(10) + reset(22) + 6 + div(1) + 8
        -- VER_PAD covers slider section + color section + support links + credit/ver + lang btn (30 if visible).
        local VER_PAD = showLangToggle and 202 or 172
        local totalH  = cbsY + 5 * TILE_H + PAD + VER_PAD
        p:SetHeight(totalH)
    end

    -- Re-apply custom styling after all SetText / SetEnabled calls above, which
    -- can trigger UIPanelButtonTemplate's OnDisable/OnEnable handlers and restore
    -- Blizzard's default grey text and art regions.
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
            if sw then sw:SetColor(def.get()) end
        end
    end
end

function Addon:ToggleGearPopup(anchor, growRight)
    local p = self._gearPopup
    -- Guard: the outside-click catcher records GetTime() when it closes the panel;
    -- if that propagated click reaches the gear button within 50 ms we treat it as
    -- "the same event" and suppress the reopen.  A timestamp is used so a stale
    -- flag from a click-elsewhere never permanently blocks a later toggle.
    if p and p._lariasClosedAt and (GetTime() - p._lariasClosedAt) < 0.20 then p._lariasClosedAt = nil; return end
    if p and p.IsShown and p:IsShown() then
        p:Hide()
        return
    end

    -- Create lazily.
    if not p then
        p = Addon.Controls.NewPopupPanel("DIALOG", 0.12)
        if p.SetBackdropBorderColor then p:SetBackdropBorderColor(Addon.THEME.border.r, Addon.THEME.border.g, Addon.THEME.border.b, 1) end
        p:SetSize(340, 10)   -- height set after rows are placed

        -- Layout constants.
        local PAD    = 10

        -- ── Reset List button (top of popup) ───────────────────────────────
        local rstStartY = PAD          -- px from popup top
        local resetBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
        resetBtn:SetPoint("TOPLEFT",  p, "TOPLEFT",  PAD,  -rstStartY)
        resetBtn:SetPoint("TOPRIGHT", p, "TOPRIGHT", -PAD, -rstStartY)
        resetBtn:SetHeight(22)
        if Addon._styleActionButton then Addon._styleActionButton(resetBtn) end
        resetBtn:SetScript("OnClick", function()
            -- Reset only the current character's list data (checked items,
            -- collapsed sections, week pointer). Display preferences (hide
            -- great vault, currency, etc.) and UI scale are intentionally kept.
            local currentKey = Addon.GetCurrentProfileKey and Addon:GetCurrentProfileKey()
            if currentKey then
                local chars = Addon.db and Addon.db.global and Addon.db.global.chars
                if chars and chars[currentKey] then
                    local cdb = chars[currentKey]
                    if wipe then
                        wipe(cdb.checked or {})
                        wipe(cdb.collapsedSections or {})
                    else
                        cdb.checked = {}
                        cdb.collapsedSections = {}
                    end
                    cdb.startAtSectionId = ""
                end
            end
            -- Reset main frame position, size, UI scale, and theme colors back to defaults.
            local gdb = Addon.db and Addon.db.global
            if gdb then
                gdb.mainFramePos  = nil
                gdb.mainFrameSize = nil
                gdb.uiScalePct    = 100
                gdb.uiOpacityPct  = 65
                if gdb.themeColors then wipe(gdb.themeColors) end
            end
            if Addon.ApplyThemeColors then Addon:ApplyThemeColors() end
            if Addon.ApplyUIScale  then Addon:ApplyUIScale()  end
            if Addon.ApplyOpacity  then Addon:ApplyOpacity()  end
            local mf = Addon._mainFrame
            if mf then
                mf:ClearAllPoints()
                mf:SetPoint("CENTER")
                mf:SetSize(Addon.UI.frameW, Addon.UI.frameH)
                if Addon.ApplyScrollLayout then Addon:ApplyScrollLayout() end
            end
            if Addon.LayoutHeaderButtons then Addon:LayoutHeaderButtons() end
            if Addon.SyncGearPopup        then Addon:SyncGearPopup()        end
            if Addon.RequestRefresh then Addon:RequestRefresh() else Addon:Refresh() end
        end)
        p._gearResetBtn = resetBtn

        -- ── Divider after Reset ────────────────────────────────────────────
        local div1StartY = rstStartY + 22 + 6
        Addon.Controls.NewDivider(p, -div1StartY, PAD, PAD)

        -- ── 8 Checkboxes ──────────────────────────────────────────────────
        local checks = {
            { key = "_cbHideCompletedTasks",   tooltipKey = "OPTIONS_TOOLTIP_HIDE_COMPLETED_TASKS" },
            { key = "_cbHideCompleted",         tooltipKey = "OPTIONS_TOOLTIP_HIDE_FINISHED_WEEKS"  },
            { key = "_cbHideGreatVault",        tooltipKey = "OPTIONS_TOOLTIP_HIDE_GREAT_VAULT"     },
            { key = "_cbHideCurrency",          tooltipKey = "OPTIONS_TOOLTIP_HIDE_CURRENCY"        },
            { key = "_cbHideChangeWeek",        tooltipKey = "OPTIONS_TOOLTIP_HIDE_CHANGE_WEEK_BTN" },
            { key = "_cbHideIlvlRef",           tooltipKey = "OPTIONS_TOOLTIP_HIDE_ILVL_REF_BTN"    },
            { key = "_cbHideUpdateNotice",      tooltipKey = "OPTIONS_TOOLTIP_HIDE_UPDATE_NOTICE"   },
            { key = "_cbHideMinimapBtn",        tooltipKey = "OPTIONS_TOOLTIP_HIDE_MINIMAP_BTN"     },
            { key = "_cbDisableUpgradeWarn",    tooltipKey = "OPTIONS_TOOLTIP_DISABLE_UPGRADE_WARN" },
        }
        local callbacks = {
            _cbHideCompletedTasks = function(checked)
                local db = Addon:EnsurePrefs()
                db.hideCompletedTasks = checked
                -- "Hide Completed Tasks" implies "Hide Finished Weeks" — force it on
                -- so completed sections are also hidden and the week label stays correct.
                if checked then db.hideCompletedSections = true end
                if Addon.SyncGearPopup then Addon:SyncGearPopup() end
                if Addon.LayoutHeaderButtons then Addon:LayoutHeaderButtons() end
                if Addon.RequestRefresh then Addon:RequestRefresh() else Addon:Refresh() end
            end,
            _cbHideCompleted  = function(checked)
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
            _cbHideCurrency   = function(checked)
                local db = Addon:EnsurePrefs()
                db.showCurrency = not checked
                if Addon.RequestRefresh then Addon:RequestRefresh() else Addon:Refresh() end
            end,
            _cbHideChangeWeek = function(checked)
                local db = Addon:EnsurePrefs()
                db.showChangeWeekBtn = not checked
                if Addon.LayoutHeaderButtons then Addon:LayoutHeaderButtons() end
            end,
            _cbHideIlvlRef    = function(checked)
                local db = Addon:EnsurePrefs()
                db.showIlvlRefBtn = not checked
                if Addon.LayoutHeaderButtons then Addon:LayoutHeaderButtons() end
            end,
            _cbHideUpdateNotice = function(checked)
                local db = Addon:EnsurePrefs()
                db.hideUpdateNotice = checked
                if not checked then
                    -- Re-query peers so the banner can repopulate if version data was cleared.
                    if Addon.RequestVersions then Addon:RequestVersions(false) end
                end
                if Addon.UpdateStatusBanner then Addon:UpdateStatusBanner() end
            end,
            _cbDisableUpgradeWarn = function(checked)
                local db = Addon:EnsurePrefs()
                db.upgradeWarnDisabled = checked or nil
                if Addon.CheckUpgradeWarning then Addon:CheckUpgradeWarning() end
            end,
            _cbHideMinimapBtn = function(checked)
                local gdb = Addon.db and Addon.db.global
                if gdb then
                    gdb.minimap = gdb.minimap or {}
                    gdb.minimap.hide = checked or nil
                end
                local ok, icon = pcall(function() return LibStub("LibDBIcon-1.0") end)
                if ok and icon then
                    if checked then
                        icon:Hide(addonName)
                    else
                        icon:Show(addonName)
                    end
                end
            end,
        }

        local TILE_H     = 34    -- total tile height (box + padding)
        local cbsY       = div1StartY + 1 + 8   -- checkboxes section top (px from popup top)
        local COL_W      = math.floor((p:GetWidth() - 2 * PAD) / 2)  -- half inner width

        for i, info in ipairs(checks) do
            local col      = (i <= 5) and 0 or 1              -- 0 = left, 1 = right
            local ri       = (i <= 5) and (i - 1) or (i - 6) -- row within column
            local colX     = PAD + col * COL_W
            local tileTopY = -(cbsY + ri * TILE_H)

            local _key = info.key
            local cb = Addon.Controls.NewCheckBox(p, function(newState)
                callbacks[_key](newState)
                if Addon.SyncGearPopup then Addon:SyncGearPopup() end
            end)
            cb:SetPoint("TOPLEFT", p, "TOPLEFT", colX, tileTopY)
            cb:SetHeight(TILE_H)
            cb._label:SetPoint("RIGHT", p, "TOPLEFT", colX + COL_W - 4, 0)
            p[info.key] = cb

            local _tooltipKey = info.tooltipKey
            if _tooltipKey then
                cb:SetScript("OnEnter", function(self_)
                    local tip = Addon.L and Addon.L[_tooltipKey]
                    if tip then
                        GameTooltip:SetOwner(self_, "ANCHOR_RIGHT")
                        GameTooltip:SetText(tip, nil, nil, nil, nil, true)
                        GameTooltip:Show()
                    end
                end)
                cb:SetScript("OnLeave", function()
                    GameTooltip:Hide()
                end)
            end

            local hit = cb._hit
            hit:SetPoint("TOPLEFT",  p, "TOPLEFT", colX,          tileTopY)
            hit:SetPoint("TOPRIGHT", p, "TOPLEFT", colX + COL_W,  tileTopY)
            hit:SetHeight(TILE_H)
        end

        -- ── Version + credit ───────────────────────────────────────────────
        local _getMeta = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
        local _ver     = (_getMeta and _getMeta(addonName, "Version")) or ""
        local _locReg  = _G["LARIASWEEKLYCHECKLIST_LOCALE_REGISTRY"]
        local _dataVer = (_locReg and type(_locReg.sheet_version) == "string" and _locReg.sheet_version) or ""

        -- ── Compact color swatches – beside sliders (right column) ──────────
        -- colorSectionDiv divides the slider+color zone from the credit block.
        local COLOR_DIV_Y = 72   -- divider bottom (px from popup BOTTOMLEFT); accounts for the support link section below
        local colorSectionDiv = p:CreateTexture(nil, "ARTWORK")
        colorSectionDiv:SetColorTexture(0.3, 0.3, 0.3, 0.5)
        colorSectionDiv:SetHeight(1)
        colorSectionDiv:SetPoint("BOTTOMLEFT",  p, "BOTTOMLEFT",  PAD,  COLOR_DIV_Y)
        colorSectionDiv:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -PAD, COLOR_DIV_Y)

        -- ── Scale & Opacity (left) + Colors (right) in one row ─────────────
        local SROW_H_P   = (Addon.UI.sliderLabelH or 14) + 2 + math.max(16, Addon.UI.sliderH or 20)
        local OPAC_BOT   = COLOR_DIV_Y + 8
        local SCALE_BOT  = OPAC_BOT + SROW_H_P + 8
        local SDIV_BOT   = SCALE_BOT + SROW_H_P + 8

        -- Divider above the combined zone.
        local sliderSectionDiv = p:CreateTexture(nil, "ARTWORK")
        sliderSectionDiv:SetColorTexture(0.3, 0.3, 0.3, 0.5)
        sliderSectionDiv:SetHeight(1)
        sliderSectionDiv:SetPoint("BOTTOMLEFT",  p, "BOTTOMLEFT",  PAD,  SDIV_BOT)
        sliderSectionDiv:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -PAD, SDIV_BOT)

        local SLIDER_W    = 190                  -- left column: slider width
        local COLOR_COL_X = PAD + SLIDER_W + 10  -- right column: x from popup left

        -- Opacity slider (left column).
        local opacPaneP = CreateFrame("Frame", nil, p)
        opacPaneP:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", PAD, OPAC_BOT)
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

        local scalePaneP = CreateFrame("Frame", nil, p)
        scalePaneP:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", PAD, SCALE_BOT)
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

        -- ── Right column: 3 compact [swatch] Label rows ──────────────────────
        -- Zone height = the same 2-slider span; stack rows centered within it.
        local SW_H      = 16
        local SW_GAP    = 6
        local zoneH     = 2 * SROW_H_P + 8            -- matches OPAC_BOT..top of scale
        local nColors   = #GEAR_COLOR_DEFS
        local stackH    = nColors * SW_H + (nColors - 1) * SW_GAP
        local colorBase = OPAC_BOT + math.floor((zoneH - stackH) / 2)

        p._gearColorSwatches = {}
        p._gearColorLabels   = {}
        for si, sd in ipairs(GEAR_COLOR_DEFS) do
            local rowBotY = colorBase + (nColors - si) * (SW_H + SW_GAP)
            local _L = Addon.L or {}

            local sw = MakePopupSwatch(p)
            sw:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", COLOR_COL_X, rowBotY)
            sw:SetColor(sd.get())
            sw:SetScript("OnClick", function()
                local cr, cg, cb = sd.get()
                OpenPopupColorPicker(cr, cg, cb,
                    function(nr, ng, nb) sd.save(nr, ng, nb); sw:SetColor(nr, ng, nb) end,
                    function(pr, pg, pb) sd.save(pr, pg, pb); sw:SetColor(pr, pg, pb) end
                )
            end)
            p._gearColorSwatches[si] = sw

            local lbl = p:CreateFontString(nil, "OVERLAY")
            lbl:SetFont("Fonts\\FRIZQT__.TTF", 9, "")
            lbl:SetText(_L[sd.labelKey] or sd.label)
            lbl:SetTextColor(0.70, 0.70, 0.70, 1)
            lbl:SetPoint("LEFT", sw, "RIGHT", 4, 0)
            p._gearColorLabels[si] = lbl
        end

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
            if _dataVer ~= "" then parts[#parts + 1] = "Data: " .. _dataVer end
            verLabel:SetText(table.concat(parts, "  \226\128\162  "))
        end
        verLabel:SetTextColor(0.45, 0.45, 0.45, 0.6)

        -- ── Support links (Guide Doc / Checklist / Discord) ─────────────────────
        local suppDiv = p:CreateTexture(nil, "ARTWORK")
        suppDiv:SetColorTexture(0.3, 0.3, 0.3, 0.5)
        suppDiv:SetHeight(1)
        suppDiv:SetPoint("BOTTOMLEFT",  p, "BOTTOMLEFT",  PAD,  33)
        suppDiv:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -PAD, 33)

        local suppTitleLbl = p:CreateFontString(nil, "OVERLAY")
        suppTitleLbl:SetFont("Fonts\\FRIZQT__.TTF", 9, "")
        suppTitleLbl:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", PAD + 2, 36)
        suppTitleLbl:SetText("Support")
        suppTitleLbl:SetTextColor(0.60, 0.60, 0.60, 1)

        local SUPP_BTN_W = math.floor((p:GetWidth() - 2 * PAD - 8) / 3)
        for si, sl in ipairs(SUPPORT_LINKS) do
            local _url = sl.url
            local sx   = PAD + (si - 1) * (SUPP_BTN_W + 4)
            local sbtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
            sbtn:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", sx, 48)
            sbtn:SetSize(SUPP_BTN_W, 22)
            sbtn:SetText(sl.label)
            if Addon._styleActionButton then Addon._styleActionButton(sbtn) end
            sbtn:SetScript("OnClick", function()
                if C_Browser and C_Browser.OpenLink then
                    C_Browser.OpenLink(_url)
                else
                    StaticPopup_Show("LARIAS_COPY_LINK", nil, nil, _url)
                end
            end)
        end

        -- ── Language toggle button (non-English clients only) ────────────────────
        -- Sits above the slider section divider when visible.
        --   SDIV_BOT≈168  ->  lang btn bottom=173, lang divider bottom=199
        --   VER_PAD grows from 172 to 202 when this button is visible.
        local langDivider = p:CreateTexture(nil, "ARTWORK")
        langDivider:SetColorTexture(0.3, 0.3, 0.3, 0.5)
        langDivider:SetHeight(1)
        langDivider:SetPoint("BOTTOMLEFT",  p, "BOTTOMLEFT",  PAD,  199)
        langDivider:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -PAD, 199)
        langDivider:Hide()
        p._gearLangDiv = langDivider

        local langBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
        langBtn:SetPoint("BOTTOMLEFT",  p, "BOTTOMLEFT",  PAD,  173)
        langBtn:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -PAD, 173)
        langBtn:SetHeight(22)
        langBtn:Hide()
        if Addon._styleActionButton then Addon._styleActionButton(langBtn) end
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

        self._gearPopup = p
        -- Apply saved opacity to the new popup (it was created with alpha=1.0).
        if self.ApplyOpacity then self:ApplyOpacity() end
    end

    -- Sync current values and labels (includes hidden chars trigger label).
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
