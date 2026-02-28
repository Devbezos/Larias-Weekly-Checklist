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

local OpenColorPicker = Addon.Controls.OpenColorPicker

-- Creates a small colored swatch button on `parent`.
-- Call swatch:SetColor(r,g,b) to update the display color.
local function MakeSwatch(parent)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(22, 22)
    -- Thin border layer (below the color fill)
    local border = btn:CreateTexture(nil, "ARTWORK", nil, 0)
    border:SetPoint("TOPLEFT",     btn, "TOPLEFT",     -1,  1)
    border:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT",  1, -1)
    border:SetColorTexture(0.55, 0.55, 0.55, 1)
    -- Colored fill
    local fill = btn:CreateTexture(nil, "ARTWORK", nil, 1)
    fill:SetAllPoints(btn)
    fill:SetColorTexture(1, 1, 1, 1)
    btn._fill = fill
    function btn:SetColor(r, g, b)
        self._fill:SetColorTexture(r, g, b, 1)
    end
    return btn
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
    secActions:SetText("Actions")
    curY = curY - 20 - 4

    local resetBtn = CreateFrame("Button", nil, canvas, "UIPanelButtonTemplate")
    resetBtn:SetPoint("TOPLEFT", canvas, "TOPLEFT", PAD, curY)
    resetBtn:SetSize(160, BTN_H)
    resetBtn:SetText(L.RESET_BUTTON or "Reset List")
    if Addon._styleActionButton then Addon._styleActionButton(resetBtn) end
    resetBtn:SetScript("OnClick", function()
        local currentKey = Addon._viewingChar
            or (Addon.GetCurrentProfileKey and Addon:GetCurrentProfileKey())
        if currentKey then
            local chars = Addon.db and Addon.db.global and Addon.db.global.chars
            if chars and chars[currentKey] then
                local cdb = chars[currentKey]
                if wipe then
                    wipe(cdb.checked           or {})
                    wipe(cdb.collapsedSections or {})
                else
                    cdb.checked           = {}
                    cdb.collapsedSections = {}
                end
                cdb.startAtSectionId = ""
            end
        end
        local gdb = Addon.db and Addon.db.global
        if gdb then
            gdb.mainFramePos  = nil
            gdb.mainFrameSize = nil
            gdb.uiScalePct    = 100
            gdb.uiOpacityPct  = 65
            gdb.themeColors   = {}   -- clear all color overrides → revert to defaults
        end
        if Addon.ApplyUIScale      then Addon:ApplyUIScale()      end
        if Addon.ApplyOpacity      then Addon:ApplyOpacity()      end
        if Addon.ApplyThemeColors  then Addon:ApplyThemeColors()  end
        -- Refresh swatch colors to reflect restored defaults.
        for _, entry in ipairs(_colorSwatches) do
            local r, g, b = entry.def.getColor()
            entry.swatch:SetColor(r, g, b)
        end
        local mf = Addon._mainFrame
        if mf then
            mf:ClearAllPoints()
            mf:SetPoint("CENTER")
            mf:SetSize(Addon.UI.frameW, Addon.UI.frameH)
            if Addon.ApplyScrollLayout then Addon:ApplyScrollLayout() end
        end
        if Addon.LayoutHeaderButtons then Addon:LayoutHeaderButtons() end
        if Addon.SyncGearPopup       then Addon:SyncGearPopup()       end
        if Addon.RequestRefresh then Addon:RequestRefresh() else Addon:Refresh() end
    end)
    curY = curY - BTN_H - 14

    -- ── Divider ───────────────────────────────────────────────────────────────
    local div = canvas:CreateTexture(nil, "ARTWORK")
    div:SetColorTexture(0.3, 0.3, 0.3, 0.6)
    div:SetHeight(1)
    div:SetPoint("TOPLEFT",  canvas, "TOPLEFT",  PAD,  curY)
    div:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", -PAD, curY)
    curY = curY - 8

    -- ── "Display" section ─────────────────────────────────────────────────────
    local secDisplay = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    secDisplay:SetPoint("TOPLEFT", canvas, "TOPLEFT", PAD, curY)
    secDisplay:SetText("Display")
    curY = curY - 20 - 4

    -- Row definitions: { label, getVal(db) → bool, onChange(v) }
    local rows = {
        {
            label    = L.HIDE_COMPLETED_WEEKS or "Hide Completed Weeks",
            getVal   = function(d) return d.hideCompletedSections and true or false end,
            onChange = function(v)
                Addon:EnsurePrefs().hideCompletedSections = v
                if Addon.RequestRefresh then Addon:RequestRefresh() else Addon:Refresh() end
            end,
        },
        {
            label    = L.OPTIONS_HIDE_GREAT_VAULT or "Hide Great Vault",
            getVal   = function(d) return not d.showGreatVault end,
            onChange = function(v)
                Addon:EnsurePrefs().showGreatVault = not v
                if Addon.RequestRefresh then Addon:RequestRefresh() else Addon:Refresh() end
            end,
        },
        {
            label    = L.OPTIONS_HIDE_CURRENCY or "Hide Currency",
            getVal   = function(d) return not d.showCurrency end,
            onChange = function(v)
                Addon:EnsurePrefs().showCurrency = not v
                if Addon.RequestRefresh then Addon:RequestRefresh() else Addon:Refresh() end
            end,
        },
        {
            label    = L.OPTIONS_HIDE_CHANGE_WEEK_BTN or "Hide Week Selector",
            getVal   = function(d) return d.showChangeWeekBtn == false end,
            onChange = function(v)
                Addon:EnsurePrefs().showChangeWeekBtn = not v
                if Addon.LayoutHeaderButtons then Addon:LayoutHeaderButtons() end
            end,
        },
        {
            label    = L.OPTIONS_HIDE_ILVL_REF_BTN or "Hide Ilvl Reference",
            getVal   = function(d) return d.showIlvlRefBtn == false end,
            onChange = function(v)
                Addon:EnsurePrefs().showIlvlRefBtn = not v
                if Addon.LayoutHeaderButtons then Addon:LayoutHeaderButtons() end
            end,
        },
        {
            label    = L.OPTIONS_HIDE_SIDE_WEEKLIES or "Side: Hide Weeklies",
            getVal   = function(d) return d.showSidePanelWeeklies == false end,
            onChange = function(v)
                Addon:EnsurePrefs().showSidePanelWeeklies = not v
                if Addon.RebuildSidePanel then Addon:RebuildSidePanel() end
            end,
        },
        {
            label    = L.OPTIONS_HIDE_SIDE_RARES or "Side: Hide Rares",
            getVal   = function(d) return d.showSidePanelRares == false end,
            onChange = function(v)
                Addon:EnsurePrefs().showSidePanelRares = not v
                if Addon.RebuildSidePanel then Addon:RebuildSidePanel() end
            end,
        },
        {
            label    = L.OPTIONS_HIDE_SIDE_TREASURES or "Side: Hide Treasures",
            getVal   = function(d) return d.showSidePanelTreasures == false end,
            onChange = function(v)
                Addon:EnsurePrefs().showSidePanelTreasures = not v
                if Addon.RebuildSidePanel then Addon:RebuildSidePanel() end
            end,
        },
        {
            label    = L.OPTIONS_HIDE_CHAR_SELECT or "Hide Character Selector",
            getVal   = function(d) return d.showCharPickerBtn == false end,
            onChange = function(v)
                Addon:EnsurePrefs().showCharPickerBtn = not v
                if Addon.LayoutHeaderButtons        then Addon:LayoutHeaderButtons()        end
                if Addon.ApplyScaleSliderVisibility then Addon:ApplyScaleSliderVisibility() end
            end,
        },
        {
            label    = L.OPTIONS_HIDE_SLIDERS or "Hide Sliders",
            getVal   = function(d) return d.showScaleSlider == false end,
            onChange = function(v)
                local d = Addon:EnsurePrefs()
                d.showScaleSlider   = not v
                d.showOpacitySlider = not v
                if Addon.ApplyScaleSliderVisibility then Addon:ApplyScaleSliderVisibility() end
            end,
        },
        {
            label    = L.OPTIONS_HIDE_UPDATE_NOTICE or "Hide Update Notices",
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
            label    = L.OPTIONS_HIDE_MINIMAP_BTN or "Hide Minimap Button",
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
    for _, row in ipairs(rows) do
        local _row = row   -- upvalue capture
        local cb = Addon.Controls.NewCheckBox(canvas, function(newState)
            _row.onChange(newState)
            if Addon.SyncGearPopup then Addon:SyncGearPopup() end
        end)
        cb:SetPoint("TOPLEFT", canvas, "TOPLEFT", PAD, curY)
        cb:SetHeight(ROW_H)

        -- Stretch the label to the right edge so the hit-area covers the row.
        if cb._label then
            cb._label:SetPoint("RIGHT", canvas, "RIGHT", -PAD, 0)
            cb._label:SetText(_row.label)
            if cb._label.SetTextColor and Addon.THEME and Addon.THEME.text then
                local t = Addon.THEME.text
                cb._label:SetTextColor(t.r, t.g, t.b, t.a or 1)
            end
        end
        if cb._hit then
            cb._hit:SetPoint("TOPLEFT",  canvas, "TOPLEFT",  0, curY)
            cb._hit:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", 0, curY)
            cb._hit:SetHeight(ROW_H)
        end

        _checkboxes[#_checkboxes + 1] = { cb = cb, row = _row }
        curY = curY - STEP
    end

    -- ── Divider ───────────────────────────────────────────────────────────────
    local div2 = canvas:CreateTexture(nil, "ARTWORK")
    div2:SetColorTexture(0.3, 0.3, 0.3, 0.6)
    div2:SetHeight(1)
    div2:SetPoint("TOPLEFT",  canvas, "TOPLEFT",  PAD,  curY)
    div2:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", -PAD, curY)
    curY = curY - 8

    -- ── "Colors" section ──────────────────────────────────────────────────────
    local secColors = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    secColors:SetPoint("TOPLEFT", canvas, "TOPLEFT", PAD, curY)
    secColors:SetText("Colors")
    curY = curY - 20 - 4

    -- Factory: builds a color-row definition from key names and hard defaults.
    -- getColor() → r, g, b (saved value or default)
    -- saveColor(r,g,b) → writes to db.global.themeColors and re-applies theme
    -- resetColor()     → clears saved value and re-applies theme
    local function makeColorDef(label, rk, gk, bk, dr, dg, db_)
        return {
            label = label,
            getColor = function()
                local gdb = Addon.db and Addon.db.global
                local tc  = gdb and gdb.themeColors
                if tc and tc[rk] ~= nil then return tc[rk], tc[gk], tc[bk] end
                return dr, dg, db_
            end,
            saveColor = function(r, g, b)
                local gdb = Addon.db and Addon.db.global
                if not gdb then return end
                gdb.themeColors = gdb.themeColors or {}
                gdb.themeColors[rk] = r
                gdb.themeColors[gk] = g
                gdb.themeColors[bk] = b
                if Addon.ApplyThemeColors then Addon:ApplyThemeColors() end
            end,
            resetColor = function()
                local gdb = Addon.db and Addon.db.global
                if gdb and gdb.themeColors then
                    gdb.themeColors[rk] = nil
                    gdb.themeColors[gk] = nil
                    gdb.themeColors[bk] = nil
                end
                if Addon.ApplyThemeColors then Addon:ApplyThemeColors() end
            end,
        }
    end

    local colorDefs = {
        makeColorDef("Background", "bgR",     "bgG",     "bgB",     0.10, 0.10, 0.10),
        makeColorDef("List Text",  "textR",   "textG",   "textB",   1.00, 1.00, 1.00),
        makeColorDef("Header Text","headerR", "headerG", "headerB", 1.00, 0.82, 0.00),
    }

    _colorSwatches = {}
    for _, def in ipairs(colorDefs) do
        local _def = def   -- upvalue capture

        -- Label
        local lbl = canvas:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        lbl:SetPoint("TOPLEFT", canvas, "TOPLEFT", PAD, curY - (ROW_H - 12) / 2)
        lbl:SetText(_def.label)

        -- Colored swatch button
        local swatch = MakeSwatch(canvas)
        swatch:SetPoint("TOPLEFT", canvas, "TOPLEFT", 140, curY - (ROW_H - 22) / 2)
        local cr, cg, cb = _def.getColor()
        swatch:SetColor(cr, cg, cb)
        swatch:SetScript("OnClick", function()
            local r, g, b = _def.getColor()
            OpenColorPicker(r, g, b,
                -- onUpdate: live preview while dragging
                function(nr, ng, nb)
                    _def.saveColor(nr, ng, nb)
                    swatch:SetColor(nr, ng, nb)
                end,
                -- onCancel: restore previous color on X
                function(pr, pg, pb)
                    _def.saveColor(pr, pg, pb)
                    swatch:SetColor(pr, pg, pb)
                end
            )
        end)

        -- Per-color Reset button
        local resetColorBtn = CreateFrame("Button", nil, canvas, "UIPanelButtonTemplate")
        resetColorBtn:SetPoint("TOPLEFT", canvas, "TOPLEFT", 170, curY - (ROW_H - BTN_H) / 2)
        resetColorBtn:SetSize(60, BTN_H)
        resetColorBtn:SetText("Reset")
        if Addon._styleActionButton then Addon._styleActionButton(resetColorBtn) end
        resetColorBtn:SetScript("OnClick", function()
            _def.resetColor()
            local dr, dg, db = _def.getColor()
            swatch:SetColor(dr, dg, db)
        end)

        _colorSwatches[#_colorSwatches + 1] = { swatch = swatch, def = _def }
        curY = curY - STEP
    end

    canvas:SetHeight(math.abs(curY) + PAD)

    -- Sync checkbox states and swatch colors every time the panel is shown.
    panelFrame:SetScript("OnShow", function()
        local d = Addon:EnsurePrefs()
        for _, entry in ipairs(_checkboxes) do
            entry.cb:SetChecked(entry.row.getVal(d))
        end
        for _, entry in ipairs(_colorSwatches) do
            local r, g, b = entry.def.getColor()
            entry.swatch:SetColor(r, g, b)
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
        local r, g, b = entry.def.getColor()
        entry.swatch:SetColor(r, g, b)
    end
end

--- Called from OnEnable to register the panel with the WoW UI.
function Addon:RegisterSettingsPanel()
    local frame = BuildPanel()
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
