-- LariasWeeklyChecklist_Settings.lua
-- Registers a panel under Interface → AddOns using WoW's native Settings API
-- (retail 10.x+) with InterfaceOptions_AddCategory as a classic fallback.
-- No extra libraries required. Mirrors every option from the in-world gear popup.
local addonName = ...
local Addon = _G[addonName]
if not Addon then return end

-- ── Layout constants ──────────────────────────────────────────────────────────
local PAD    = 16   -- outer horizontal padding (px)
local ROW_H  = 28   -- checkbox row height
local ROW_GAP = 4   -- gap between rows
local STEP   = ROW_H + ROW_GAP
local BTN_H  = 24   -- action button height

-- ── Internal state ────────────────────────────────────────────────────────────
local panelFrame         -- outer canvas WoW hosts
local _checkboxes = {}   -- { cb, row }
local _colorSwatches = {} -- { swatch, def }
local _langDropdownBtn   -- reference to locale dropdown button; synced in OnShow
local _settingsScaleSync  -- Sync() closure for the settings-panel Scale slider
local _settingsOpacSync   -- Sync() closure for the settings-panel Opacity slider
-- Holds the URL for the most-recently clicked support button so the
-- LARIAS_COPY_LINK popup can reliably display it (self.data can be nil
-- on some client builds when the popup fires before WoW assigns it).
-- _pendingCopyUrl lives on Addon so GearPopup can set it too.
-- Initialise only if not already set (file may reload).
Addon._pendingCopyUrl = Addon._pendingCopyUrl or ""

local AU = Addon.AddonUtils
local OpenColorPicker = Addon.Controls.OpenColorPicker

-- Reload-prompt shown after the player picks a different language.
-- Defined once at load time so StaticPopup_Show can reference it anywhere.
StaticPopupDialogs["LARIAS_LOCALE_RELOAD"] = StaticPopupDialogs["LARIAS_LOCALE_RELOAD"] or {
    text      = (Addon.L or {}).LOCALE_RELOAD_TEXT      or "Language change saved. Reload UI to apply the new language.",
    button1   = (Addon.L or {}).LOCALE_RELOAD_BTN_NOW   or "Reload Now",
    button2   = (Addon.L or {}).LOCALE_RELOAD_BTN_LATER or "Later",
    OnAccept  = function() ReloadUI() end,
    timeout   = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- (GetSupportLinks removed; use Addon:GetSupportLinks() instead.)

-- Generic "copy link" popup used when C_Browser.OpenLink is unavailable.
-- Always redefined (no `or` guard) so the OnShow closure always captures
-- the current Addon reference and _pendingCopyUrl logic.
StaticPopupDialogs["LARIAS_COPY_LINK"] = {
    text         = (Addon.L or {}).COPY_LINK_POPUP_TEXT or "Press |cffffffffCtrl+C|r to copy, then close:",
    button1      = CLOSE or "Close",
    hasEditBox   = true,
    editBoxWidth = 320,
    timeout      = 0,
    whileDead    = true,
    hideOnEscape = true,
    preferredIndex = 5,
    OnShow = function(self)
        -- Defer one frame: WoW positions the editBox *after* calling OnShow.
        C_Timer.After(0, function()
            local eb = self.editBox or _G[self:GetName() and (self:GetName() .. "EditBox")]
            if not eb then return end
            eb:SetText(Addon._pendingCopyUrl or "")
            eb:SetFocus()
            eb:HighlightText()
            eb:SetScript("OnKeyDown", function(_, key)
                if key == "C" and IsControlKeyDown() then
                    C_Timer.After(0.05, function()
                        StaticPopup_Hide("LARIAS_COPY_LINK")
                    end)
                end
            end)
        end)
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    OnAccept = function() end,
}

--- Shared helper: opens a URL in the browser, or falls back to the copy-link
--- popup. Call this from any button in any file instead of duplicating the logic.
function Addon.OpenSupportLink(url)
    if not url or url == "" then return end
    if C_Browser and C_Browser.OpenLink then
        C_Browser.OpenLink(url)
    else
        Addon._pendingCopyUrl = url
        StaticPopup_Show("LARIAS_COPY_LINK", nil, nil, url)
    end
end

-- (MakeSwatch removed; use Addon.Controls.NewSwatch(parent, 22) instead.)

-- ── Interaction helpers ──────────────────────────────────────────────────────
local _finishedWeeksEntry  -- cached after building checkboxes; used by "hide completed tasks"

local function SetRowEnabled(entry, enabled)
    Addon.Controls.SetCheckEnabled(entry and entry.cb, enabled)
end

-- ── Build the panel (lazy, called once) ───────────────────────────────────────
local function BuildPanel()
    if panelFrame then return panelFrame end

    local L = Addon.L or {}

    panelFrame      = CreateFrame("Frame")
    panelFrame.name = L.DISPLAY_NAME or "Larias's Weekly Checklist"

    -- Inner canvas ─ WoW's Settings API sizes this for us; we just place widgets.
    local canvas = CreateFrame("Frame", nil, panelFrame)
    canvas:SetPoint("TOPLEFT")
    canvas:SetPoint("TOPRIGHT")

    local curY = -PAD   -- running Y (negative = downward from top)

    -- ── Page title ────────────────────────────────────────────────────────────
    local titleFS = canvas:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    titleFS:SetPoint("TOPLEFT", canvas, "TOPLEFT", PAD, curY)
    titleFS:SetText(L.DISPLAY_NAME or "Larias's Weekly Checklist")
    curY = curY - 32

    -- ── "Actions" section ─────────────────────────────────────────────────────
    local secActions = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    secActions:SetPoint("TOPLEFT", canvas, "TOPLEFT", PAD, curY)
    secActions:SetText(L.SETTINGS_SECTION_ACTIONS or "Actions")
    curY = curY - 20 - 4

    local resetBtn = Addon.Controls.NewActionButton(canvas, 160, BTN_H)
    resetBtn:SetPoint("TOPLEFT", canvas, "TOPLEFT", PAD, curY)
    resetBtn:SetText(L.RESET_BUTTON or "Reset List")
    resetBtn:SetScript("OnClick", function() Addon:PerformFullReset() end)
    curY = curY - BTN_H - 14

    -- ── Divider ───────────────────────────────────────────────────────────────
    Addon.Controls.NewDivider(canvas, curY, PAD, PAD)
    curY = curY - 8

    -- ── "Display" section ─────────────────────────────────────────────────────
    local secDisplay = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    secDisplay:SetPoint("TOPLEFT", canvas, "TOPLEFT", PAD, curY)
    secDisplay:SetText(L.SETTINGS_SECTION_DISPLAY or "Display")
    curY = curY - 20 - 4

    -- Two-column checkbox layout (5 rows per column).
    local CB_COL_W   = 255
    local CB_COL_GAP = 8
    local LEFT_CB_X  = PAD
    local RIGHT_CB_X = PAD + CB_COL_W + CB_COL_GAP

    -- Row definitions: { label, getVal(db) → bool, onChange(v) }
    local rows = {
        {
            label   = L.OPTIONS_HIDE_COMPLETED_TASKS or "Hide Completed Tasks",
            tooltip = L.OPTIONS_TOOLTIP_HIDE_COMPLETED_TASKS or "Hides individual checked-off tasks from all weeks.",
            getVal   = function(d) return d.hideCompletedTasks and true or false end,
            onChange = function(v)
                Addon:EnsurePrefs().hideCompletedTasks = v
                SetRowEnabled(_finishedWeeksEntry, not v)
                if Addon.RequestRefresh then Addon:RequestRefresh() else Addon:Refresh() end
            end,
        },
        {
            _isFinishedWeeks = true,
            label   = L.HIDE_FINISHED_WEEKS or "Hide Finished Weeks",
            tooltip = L.OPTIONS_TOOLTIP_HIDE_FINISHED_WEEKS or "Hides entire week sections once all tasks in them are completed.",
            getVal   = function(d) return d.hideCompletedSections and true or false end,
            onChange = function(v)
                Addon:EnsurePrefs().hideCompletedSections = v
                if Addon.RequestRefresh then Addon:RequestRefresh() else Addon:Refresh() end
            end,
        },
        {
            label   = L.OPTIONS_HIDE_GREAT_VAULT or "Hide Great Vault",
            tooltip = L.OPTIONS_TOOLTIP_HIDE_GREAT_VAULT or "Hides the Great Vault progress tracker panel.",
            getVal   = function(d) return not d.showGreatVault end,
            onChange = function(v)
                Addon:EnsurePrefs().showGreatVault = not v
                if Addon.RequestRefresh then Addon:RequestRefresh() else Addon:Refresh() end
            end,
        },
        {
            label   = L.OPTIONS_HIDE_CURRENCY or "Hide Currency",
            tooltip = L.OPTIONS_TOOLTIP_HIDE_CURRENCY or "Hides the crests and currency tracker panel.",
            getVal   = function(d) return not d.showCurrency end,
            onChange = function(v)
                Addon:EnsurePrefs().showCurrency = not v
                if Addon.RequestRefresh then Addon:RequestRefresh() else Addon:Refresh() end
            end,
        },
        {
            label   = L.OPTIONS_HIDE_CHANGE_WEEK_BTN or "Hide Week Selector",
            tooltip = L.OPTIONS_TOOLTIP_HIDE_CHANGE_WEEK_BTN or "Hides the Change Week button in the header.",
            getVal   = function(d) return d.showChangeWeekBtn == false end,
            onChange = function(v)
                Addon:EnsurePrefs().showChangeWeekBtn = not v
                if Addon.LayoutHeaderButtons then Addon:LayoutHeaderButtons() end
            end,
        },
        {
            label   = L.OPTIONS_HIDE_ILVL_REF_BTN or "Hide Ilvl Reference",
            tooltip = L.OPTIONS_TOOLTIP_HIDE_ILVL_REF_BTN or "Hides the item level reference popup button in the header.",
            getVal   = function(d) return d.showIlvlRefBtn == false end,
            onChange = function(v)
                Addon:EnsurePrefs().showIlvlRefBtn = not v
                if Addon.LayoutHeaderButtons then Addon:LayoutHeaderButtons() end
            end,
        },
        {
            label   = L.OPTIONS_HIDE_UPDATE_NOTICE or "Hide Update Notices",
            tooltip = L.OPTIONS_TOOLTIP_HIDE_UPDATE_NOTICE or "Hides the banner shown when a new spreadsheet version is available.",
            getVal   = function(d) return d.hideUpdateNotice and true or false end,
            onChange = function(v)
                Addon:EnsurePrefs().hideUpdateNotice = v
                if not v then
                    -- Re-query peers so the banner can repopulate if version data was cleared.
                    if Addon.RequestVersions then Addon:RequestVersions(false) end
                end
                if Addon.UpdateStatusBanner then Addon:UpdateStatusBanner() else Addon:Refresh() end
            end,
        },
        {
            label   = L.OPTIONS_DISABLE_UPGRADE_WARN or "Hide Upgrade Warnings",
            tooltip = L.OPTIONS_TOOLTIP_DISABLE_UPGRADE_WARN or "Hides the popup warning shown when upgrading an item at 1/6 instead of 5/6.",
            getVal   = function(d) return d.upgradeWarnDisabled and true or false end,
            onChange = function(v)
                Addon:EnsurePrefs().upgradeWarnDisabled = v
                if Addon.CheckUpgradeWarning then Addon:CheckUpgradeWarning() end
            end,
        },
        {
            label   = L.OPTIONS_DISABLE_CRAFT_WARN or "Hide Crafting Warnings",
            tooltip = L.OPTIONS_TOOLTIP_DISABLE_CRAFT_WARN or "Hides the warning shown when crafting a weapon whose main stat doesn't match your specialisation.",
            getVal   = function(d) return d.craftWarnDisabled and true or false end,
            onChange = function(v)
                Addon:EnsurePrefs().craftWarnDisabled = v
                if Addon.CheckCraftingWarning then Addon:CheckCraftingWarning() end
            end,
        },
        {
            label   = L.OPTIONS_DISABLE_BONUS_ROLL_WARN or "Hide Bonus Roll Warnings",
            tooltip = L.OPTIONS_TOOLTIP_DISABLE_BONUS_ROLL_WARN or "Hides the warning shown when the bonus roll window opens.",
            getVal   = function(d) return d.bonusRollWarnDisabled and true or false end,
            onChange = function(v)
                Addon:EnsurePrefs().bonusRollWarnDisabled = v
                if Addon.CheckBonusRollWarning then Addon:CheckBonusRollWarning() end
            end,
        },
        {
            label   = L.OPTIONS_HIDE_MINIMAP_BTN or "Hide Minimap Button",
            tooltip = L.OPTIONS_TOOLTIP_HIDE_MINIMAP_BTN or "Hides the minimap button.\nYou can still open the checklist with /larias.",
            getVal   = function(_d)
                local g = Addon.db and Addon.db.global
                return g and g.minimap and g.minimap.hide and true or false
            end,
            onChange = function(v)
                local g = Addon.db and Addon.db.global
                if g then
                    g.minimap      = g.minimap or {}
                    g.minimap.hide = v or nil
                end
                local ok, icon = pcall(function() return LibStub("LibDBIcon-1.0") end)
                if ok and icon then
                    if v then icon:Hide(addonName) else icon:Show(addonName) end
                end
            end,
        },
    }

    _checkboxes = {}
    for i, row in ipairs(rows) do
        local _row  = row
        local col   = (i <= 6) and 0 or 1              -- 0 = left column, 1 = right column
        local ri    = (i <= 6) and (i - 1) or (i - 7)  -- 0-based row index within column
        local colX  = (col == 0) and LEFT_CB_X or RIGHT_CB_X
        local rowY  = curY - ri * STEP
        local cb = Addon.Controls.NewCheckBox(canvas, function(newState)
            _row.onChange(newState)
            if Addon.SyncGearPopup then Addon:SyncGearPopup() end
        end)
        cb:SetPoint("TOPLEFT", canvas, "TOPLEFT", colX, rowY)
        cb:SetHeight(ROW_H)
        if cb._label then
            cb._label:SetPoint("RIGHT", canvas, "TOPLEFT", colX + CB_COL_W, 0)
            cb._label:SetText(_row.label)
            if cb._label.SetTextColor and Addon.THEME and Addon.THEME.text then
                local t = Addon.THEME.text
                cb._label:SetTextColor(t.r, t.g, t.b, t.a or 1)
            end
        end
        if _row.tooltip then
            local _tip = _row.tooltip
            cb:SetScript("OnEnter", function(self_) AU.SetTooltip(self_, _tip) end)
            cb:SetScript("OnLeave", AU.HideTooltip)
        end
        if cb._hit then
            cb._hit:SetPoint("TOPLEFT",  canvas, "TOPLEFT", colX,           rowY)
            cb._hit:SetPoint("TOPRIGHT", canvas, "TOPLEFT", colX + CB_COL_W, rowY)
            cb._hit:SetHeight(ROW_H)
        end
        _checkboxes[#_checkboxes + 1] = { cb = cb, row = _row }
    end

    -- Cache the "hide finished weeks" entry so the "hide completed tasks" onChange
    -- can dim/enable it without searching every time.
    for _, entry in ipairs(_checkboxes) do
        if entry.row._isFinishedWeeks then _finishedWeeksEntry = entry end
    end

    curY = curY - 6 * STEP   -- 6 rows in the left column (the taller one)

    -- ── Divider ───────────────────────────────────────────────────────────────
    Addon.Controls.NewDivider(canvas, curY, PAD, PAD)
    curY = curY - 8

    -- ── Scale & Opacity (left) + Colors (right) ──────────────────────────────
    local SROW_H       = (Addon.UI.sliderLabelH or 14) + 2 + math.max(16, Addon.UI.sliderH or 20)
    local SLIDER_COL_W = 220
    local COLOR_COL_X  = PAD + SLIDER_COL_W + 14   -- right column start

    -- Section titles share the same baseline.
    local secSliders = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    secSliders:SetPoint("TOPLEFT", canvas, "TOPLEFT", PAD, curY)
    secSliders:SetText(L.SETTINGS_SECTION_SLIDERS or "Scale & Opacity")

    local secColors = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    secColors:SetPoint("TOPLEFT", canvas, "TOPLEFT", COLOR_COL_X, curY)
    secColors:SetText(L.SETTINGS_SECTION_COLORS or "Colors")

    curY = curY - 20 - 4

    -- Left: Scale slider
    local scalePaneS = CreateFrame("Frame", nil, canvas)
    scalePaneS:SetSize(SLIDER_COL_W, SROW_H)
    scalePaneS:SetPoint("TOPLEFT", canvas, "TOPLEFT", PAD, curY)
    scalePaneS:EnableMouse(true)
    _settingsScaleSync = Addon:CreateSliderWidget(scalePaneS, {
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
        minLabel   = L.UI_SCALE_MIN_LABEL   or "50%",
        maxLabel   = L.UI_SCALE_MAX_LABEL   or "150%",
        fmtFn      = function(v) return math.floor(v + 0.5) .. "%" end,
        titleLabel = L.UI_SCALE_LABEL       or "Scale",
    })

    -- Left: Opacity slider (below Scale)
    local opacPaneS = CreateFrame("Frame", nil, canvas)
    opacPaneS:SetSize(SLIDER_COL_W, SROW_H)
    opacPaneS:SetPoint("TOPLEFT", canvas, "TOPLEFT", PAD, curY - SROW_H - 8)
    opacPaneS:EnableMouse(true)
    _settingsOpacSync = Addon:CreateSliderWidget(opacPaneS, {
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
        minLabel   = L.UI_OPACITY_MIN_LABEL or "10%",
        maxLabel   = L.UI_OPACITY_MAX_LABEL or "100%",
        fmtFn      = function(v) return math.floor(v + 0.5) .. "%" end,
        titleLabel = L.UI_OPACITY_LABEL     or "Opacity",
        liveApply  = true,
    })

    -- Right: 3 color rows stacked vertically — [swatch] [label ... reset]
    local COLOR_ROW_H   = 24
    local COLOR_ROW_GAP = 6

    -- Shared color definitions (owned by the main file).
    local colorDefs = Addon.THEME_COLOR_DEFS

    _colorSwatches = {}
    for i, def in ipairs(colorDefs) do
        local _def = def
        local rowY = curY - (i - 1) * (COLOR_ROW_H + COLOR_ROW_GAP)

        local swatch = Addon.Controls.NewSwatch(canvas, 22)
        swatch:SetPoint("TOPLEFT", canvas, "TOPLEFT", COLOR_COL_X, rowY - 1)
        local cr, cg, cb = _def:get()
        swatch:SetColor(cr, cg, cb)
        swatch:SetScript("OnClick", function()
            local r, g, b = _def:get()
            OpenColorPicker(r, g, b,
                function(nr, ng, nb) _def:save(nr, ng, nb); swatch:SetColor(nr, ng, nb) end,
                function(pr, pg, pb) _def:save(pr, pg, pb); swatch:SetColor(pr, pg, pb) end
            )
        end)

        local resetColorBtn = Addon.Controls.NewActionButton(canvas, 60, COLOR_ROW_H)
        resetColorBtn:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", -PAD, rowY)
        resetColorBtn:SetText(L.SETTINGS_COLOR_RESET or "Reset")
        resetColorBtn:SetScript("OnClick", function()
            _def:reset()
            local dr, dg, db = _def:get()
            swatch:SetColor(dr, dg, db)
        end)

        local lbl = canvas:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        lbl:SetPoint("TOPLEFT",  swatch,        "TOPRIGHT", 6,  0)
        lbl:SetPoint("TOPRIGHT", resetColorBtn, "TOPLEFT",  -4, 0)
        lbl:SetJustifyH("LEFT")
        lbl:SetText(L[_def.labelKey] or _def.label)

        _colorSwatches[#_colorSwatches + 1] = { swatch = swatch, def = _def }
    end

    -- Advance curY past the taller of the two columns.
    local sliderBodyH = SROW_H + 8 + SROW_H
    local colorBodyH  = #colorDefs * COLOR_ROW_H + (#colorDefs - 1) * COLOR_ROW_GAP
    curY = curY - math.max(sliderBodyH, colorBodyH) - 14

    -- ── Divider ─────────────────────────────────────────────────────────────────────────────
    Addon.Controls.NewDivider(canvas, curY, PAD, PAD)
    curY = curY - 8

    -- ── "Language" section ───────────────────────────────────────────────────────────────
    local secLang = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    secLang:SetPoint("TOPLEFT", canvas, "TOPLEFT", PAD, curY)
    secLang:SetText(L.SETTINGS_SECTION_LANGUAGE or "Language")
    curY = curY - 20 - 4

    -- Ordered list of locales with friendly display names.
    local LOCALE_OPTIONS = {
        { code = "auto", name = L.SETTINGS_LANGUAGE_AUTO or "Auto (Client Default)" },
        { code = "enUS", name = "English"        },
        { code = "deDE", name = "Deutsch"        },
        { code = "esES", name = "Español (EU)"   },
        { code = "esMX", name = "Español (MX)"   },
        { code = "frFR", name = "Français"       },
        { code = "itIT", name = "Italiano"       },
        { code = "koKR", name = "한국어"           },
        { code = "ptBR", name = "Português (BR)" },
        { code = "ruRU", name = "Русский"        },
        { code = "trTR", name = "Türkçe"         },
    }

    local function GetLocaleFriendlyName(code)
        for _, opt in ipairs(LOCALE_OPTIONS) do
            if opt.code == code then return opt.name end
        end
        return code
    end

    -- Dropdown-style button showing the current selection.
    local langDropBtn = Addon.Controls.NewActionButton(canvas, 220, BTN_H)
    langDropBtn:SetPoint("TOPLEFT", canvas, "TOPLEFT", PAD, curY)

    -- Floating option-list popup (created lazily on first click).
    local langPopup
    local LANG_ITEM_H = 24
    local LANG_PAD    = 6

    local function GetOrBuildLangPopup()
        if langPopup then return langPopup end
        langPopup = Addon.Controls.NewPopupPanel("HIGH", 0.10)
        langPopup:SetWidth(220)
        langPopup:SetHeight(LANG_PAD * 2 + #LOCALE_OPTIONS * LANG_ITEM_H)
        for idx, opt in ipairs(LOCALE_OPTIONS) do
            local _code = opt.code
            local _name = opt.name
            local row = CreateFrame("Button", nil, langPopup)
            row:SetPoint("TOPLEFT",  langPopup, "TOPLEFT",  LANG_PAD, -(LANG_PAD + (idx - 1) * LANG_ITEM_H))
            row:SetPoint("TOPRIGHT", langPopup, "TOPRIGHT", -LANG_PAD, -(LANG_PAD + (idx - 1) * LANG_ITEM_H))
            row:SetHeight(LANG_ITEM_H)
            local rowHL = row:CreateTexture(nil, "HIGHLIGHT")
            rowHL:SetAllPoints(row)
            rowHL:SetColorTexture(1, 1, 1, 0.08)
            local rowLbl = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            rowLbl:SetPoint("LEFT", row, "LEFT", 4, 0)
            rowLbl:SetText(_name)
            row:SetScript("OnClick", function()
                langPopup:Hide()
                -- Save to db only; the change takes effect on the next reload.
                local gdb = Addon.db and Addon.db.global
                if gdb then
                    gdb.localeOverride = (_code == "auto") and "" or _code
                end
                langDropBtn:SetText(GetLocaleFriendlyName(_code))
                Addon.Controls.StyleButton(langDropBtn)
                StaticPopup_Show("LARIAS_LOCALE_RELOAD")
            end)
        end
        return langPopup
    end

    langDropBtn:SetScript("OnClick", function()
        local p = GetOrBuildLangPopup()
        if p._lariasClosedAt and (GetTime() - p._lariasClosedAt) < 0.20 then p._lariasClosedAt = nil; return end
        if p:IsShown() then p:Hide(); return end
        p:ClearAllPoints()
        p:SetPoint("TOPLEFT", langDropBtn, "BOTTOMLEFT", 0, -2)
        p:Show()
    end)

    -- Store reference so OnShow can sync the button text.
    _langDropdownBtn = langDropBtn

    curY = curY - BTN_H - 14

    -- ── Divider above link buttons ────────────────────────────────────────────
    Addon.Controls.NewDivider(canvas, curY, PAD, PAD)
    curY = curY - 8

    local SUPP_BTN_W   = 150
    local SUPP_BTN_GAP = 8

    -- MakeSuppBtn: create a fixed-width support button at xOff from canvas TOPLEFT.
    -- Clicking it calls OpenSupportLink, which tries C_Browser first and falls
    -- back to the LARIAS_COPY_LINK clipboard popup.
    local function MakeSuppBtn(label, url, xOff)
        local btn = Addon.Controls.NewActionButton(canvas, SUPP_BTN_W, BTN_H)
        btn:SetPoint("TOPLEFT", canvas, "TOPLEFT", xOff, curY)
        btn:SetText(label)
        btn:SetScript("OnClick", function() Addon.OpenSupportLink(url) end)
    end
    for si, sl in ipairs(Addon:GetSupportLinks()) do
        MakeSuppBtn(sl.label, sl.url, PAD + (si - 1) * (SUPP_BTN_W + SUPP_BTN_GAP))
    end
    curY = curY - BTN_H - PAD

    canvas:SetHeight(math.abs(curY) + PAD)

    -- Sync all controls every time the panel is shown.
    panelFrame:SetScript("OnShow", function()
        local d = Addon:EnsurePrefs()
        for _, entry in ipairs(_checkboxes) do
            entry.cb:SetChecked(entry.row.getVal(d))
        end
        SetRowEnabled(_finishedWeeksEntry, not d.hideCompletedTasks)
        for _, entry in ipairs(_colorSwatches) do
            local r, g, b = entry.def:get()
            entry.swatch:SetColor(r, g, b)
        end
        -- Sync slider thumbs to current saved values.
        if _settingsScaleSync then _settingsScaleSync() end
        if _settingsOpacSync  then _settingsOpacSync()  end
        -- Sync language dropdown to the persisted override value.
        if _langDropdownBtn then
            local savedCode = (Addon.db and Addon.db.global and Addon.db.global.localeOverride) or "auto"
            if savedCode == "" then savedCode = "auto" end
            _langDropdownBtn:SetText(GetLocaleFriendlyName(savedCode))
            if Addon._styleActionButton then Addon._styleActionButton(_langDropdownBtn) end
        end
    end)

    return panelFrame
end

-- ── Public API ────────────────────────────────────────────────────────────────

--- Refreshes all color swatch buttons in the Settings panel to match the
--- current saved (or default) theme colors.  Safe to call at any time;
--- no-op if the panel hasn't been built yet.
function Addon:RefreshSettingsSwatches()
    for _, entry in ipairs(_colorSwatches) do
        local r, g, b = entry.def:get()
        entry.swatch:SetColor(r, g, b)
    end
end

--- Re-syncs all checkboxes in the Settings panel to the current saved prefs.
--- Safe to call at any time; no-op if the panel hasn't been built yet.
function Addon:RefreshSettingsCheckboxes()
    local d = Addon:EnsurePrefs()
    for _, entry in ipairs(_checkboxes) do
        entry.cb:SetChecked(entry.row.getVal(d))
    end
    SetRowEnabled(_finishedWeeksEntry, not d.hideCompletedTasks)
end

--- Called from OnEnable to register the panel with the WoW UI.
function Addon:RegisterSettingsPanel()
    local ok, result = pcall(BuildPanel)
    if not ok then
        -- Print the error so it surfaces in the WoW chat frame for diagnosis.
        -- (panelFrame is left nil so we skip registration gracefully.)
        print("|cffff4444Laria's Checklist|r Settings panel error: " .. tostring(result))
        return
    end
    local frame = result
    if not frame then return end

    if Settings and Settings.RegisterCanvasLayoutCategory then
        -- Retail 10.0+ native Settings API.
        local cat = Settings.RegisterCanvasLayoutCategory(frame, frame.name)
        Settings.RegisterAddOnCategory(cat)
        Addon._settingsCategory = cat
    elseif InterfaceOptions_AddCategory then
        -- Classic / pre-10.0 fallback.
        InterfaceOptions_AddCategory(frame)
    end
end

--- Opens the panel programmatically (e.g. from a slash command).
function Addon:OpenSettingsPanel()
    if Addon._settingsCategory and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(Addon._settingsCategory:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(panelFrame and panelFrame.name)
    end
end
