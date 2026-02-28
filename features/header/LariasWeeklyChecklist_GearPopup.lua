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
        return tc[rk] or dr, tc[gk] or dg, tc[bk] or db_
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
    Sync(p._cbHideCompleted,    db.hideCompletedSections and true or false,
         L.HIDE_COMPLETED           or "Hide Completed")
    Sync(p._cbHideGreatVault,   not db.showGreatVault,
         L.OPTIONS_HIDE_GREAT_VAULT  or "Hide Great Vault")
    Sync(p._cbHideCurrency,     not db.showCurrency,
         L.OPTIONS_HIDE_CURRENCY     or "Hide Currency")
    Sync(p._cbHideWeeklies,     db.showInlineWeeklies == false,
         L.OPTIONS_HIDE_WEEKLIES     or "Hide Weeklies")
    Sync(p._cbHideChangeWeek,   db.showChangeWeekBtn == false,
         L.OPTIONS_HIDE_CHANGE_WEEK_BTN or "Hide Week Selector")
    Sync(p._cbHideIlvlRef,      db.showIlvlRefBtn == false,
         L.OPTIONS_HIDE_ILVL_REF_BTN or "Hide Item Level Popup")
    Sync(p._cbHideCharPicker,   db.showCharPickerBtn == false,
         L.OPTIONS_HIDE_CHAR_SELECT  or "Hide Character Selector")
    Sync(p._cbHideSliders, db.showScaleSlider == false,
         L.OPTIONS_HIDE_SLIDERS or "Hide Sliders")
    Sync(p._cbHideUpdateNotice, db.hideUpdateNotice and true or false,
         L.OPTIONS_HIDE_UPDATE_NOTICE or "Hide Update Warnings")
    local _minimap = Addon.db and Addon.db.global and Addon.db.global.minimap
    Sync(p._cbHideMinimapBtn, _minimap and _minimap.hide and true or false,
         L.OPTIONS_HIDE_MINIMAP_BTN or "Hide Minimap Button")

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

    -- Determine visibility of char-selector-related rows.
    -- Hidden when: feature flag off, or no pickable chars, or the user hid the char picker button.
    local featureOn      = (Addon.FEATURE_FLAGS and Addon.FEATURE_FLAGS.ENABLE_CHAR_SELECTOR) ~= false
    local hasChars       = featureOn and (Addon.HasPickableChars and Addon:HasPickableChars())
    local charPickerOn   = featureOn and hasChars and (db.showCharPickerBtn ~= false)
    local showCharRow    = hasChars   -- show the checkbox itself only when there are chars
    local showHiddenSect = charPickerOn  -- hidden-chars section tracks whether the button is on

    -- Char picker checkbox row.
    local cb = p._cbHideCharPicker
    if cb then
        cb:SetShown(showCharRow and true or false)
        if cb._label then cb._label:SetShown(showCharRow and true or false) end
        if cb._hit   then cb._hit:SetShown(showCharRow and true or false) end
    end

    -- Hidden chars divider + trigger.
    if p._gearHiddenCharsDiv     then p._gearHiddenCharsDiv:SetShown(showHiddenSect and true or false) end
    if p._gearHiddenCharsTrigger then p._gearHiddenCharsTrigger:SetShown(showHiddenSect and true or false) end
    if not showHiddenSect and self._hiddenCharsPicker then
        local pk = self._hiddenCharsPicker
        if pk.IsShown and pk:IsShown() then pk:Hide() end
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

    -- Recalculate popup height based on visible content, and reposition any rows
    -- below the (possibly-hidden) char picker slot so no gap is left behind.
    do
        local PAD      = 10
        local TILE_H   = 34   -- tile height
        local N_TOTAL  = 10
        local rstStartY  = PAD
        local div1StartY = rstStartY + 22 + 6
        local cbsY       = div1StartY + 1 + 8
        -- Slots 1-6 always present; slot 7 = char picker (conditional);
        -- slot 8 = sliders (combined); slot 9 = update notice; slot 10 = minimap btn.
        -- When char picker is hidden, slots 8-10 each shift up by one.
        local SLIDERS_IDX        = 8
        local UPDATE_NOTICE_IDX  = 9
        local MINIMAP_BTN_IDX    = 10
        local slidersVisIdx      = showCharRow and SLIDERS_IDX       or (SLIDERS_IDX       - 1)
        local updateNoticeVisIdx = showCharRow and UPDATE_NOTICE_IDX  or (UPDATE_NOTICE_IDX  - 1)
        local minimapBtnVisIdx   = showCharRow and MINIMAP_BTN_IDX    or (MINIMAP_BTN_IDX    - 1)
        local function ReflowCb(cb, visIdx)
            if not cb then return end
            local tileTopY = -(cbsY + (visIdx - 1) * TILE_H)
            cb:ClearAllPoints()
            cb:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, tileTopY)
            cb:SetHeight(TILE_H)
            if cb._hit then
                cb._hit:ClearAllPoints()
                cb._hit:SetPoint("TOPLEFT",  p, "TOPLEFT",  0, tileTopY)
                cb._hit:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, tileTopY)
            end
        end
        ReflowCb(p._cbHideSliders,       slidersVisIdx)
        ReflowCb(p._cbHideUpdateNotice,  updateNoticeVisIdx)
        ReflowCb(p._cbHideMinimapBtn,    minimapBtnVisIdx)

        local nVisible = showCharRow and N_TOTAL or (N_TOTAL - 1)
        -- Reposition the hidden-chars divider and trigger to follow the last checkbox.
        local div2StartY = cbsY + nVisible * TILE_H + 6
        local hidStartY  = div2StartY + 1 + 8
        if p._gearHiddenCharsDiv then
            p._gearHiddenCharsDiv:ClearAllPoints()
            p._gearHiddenCharsDiv:SetPoint("TOPLEFT",  p, "TOPLEFT",  PAD,  -div2StartY)
            p._gearHiddenCharsDiv:SetPoint("TOPRIGHT", p, "TOPRIGHT", -PAD, -div2StartY)
        end
        if p._gearHiddenCharsTrigger then
            p._gearHiddenCharsTrigger:ClearAllPoints()
            p._gearHiddenCharsTrigger:SetPoint("TOPLEFT",  p, "TOPLEFT",  PAD,  -hidStartY)
            p._gearHiddenCharsTrigger:SetPoint("TOPRIGHT", p, "TOPRIGHT", -PAD, -hidStartY)
        end

        -- When the language toggle button is visible, add 30 px for it + divider + padding.
        local VER_PAD = showLangToggle and 134 or 104
        local totalH
        if showHiddenSect then
            totalH = hidStartY + 22 + PAD + VER_PAD
        else
            totalH = cbsY + nVisible * TILE_H + PAD + VER_PAD
        end
        p:SetHeight(totalH)
    end

    -- Hidden chars trigger label — delegate to RefreshHiddenCharsList which
    -- owns the button-text logic (including the OPTIONS_HIDDEN_CHARS_NONE key).
    if self.RefreshHiddenCharsList then self:RefreshHiddenCharsList() end

    -- Re-apply custom styling after all SetText / SetEnabled calls above, which
    -- can trigger UIPanelButtonTemplate's OnDisable/OnEnable handlers and restore
    -- Blizzard's default grey text and art regions.
    if Addon._styleActionButton then
        if p._gearResetBtn              then Addon._styleActionButton(p._gearResetBtn)              end
        if p._gearHiddenCharsTrigger    then Addon._styleActionButton(p._gearHiddenCharsTrigger)    end
    end

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
    if p and p.IsShown and p:IsShown() then
        p:Hide()
        return
    end

    -- Create lazily.
    if not p then
        p = Addon.Controls.NewPopupPanel("DIALOG", 0.12)
        if p.SetBackdropBorderColor then p:SetBackdropBorderColor(Addon.THEME.border.r, Addon.THEME.border.g, Addon.THEME.border.b, 1) end
        p:SetSize(230, 10)   -- height set after rows are placed

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
            local currentKey = Addon._viewingChar or (Addon.GetCurrentProfileKey and Addon:GetCurrentProfileKey())
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
            { key = "_cbHideCompleted",   },
            { key = "_cbHideGreatVault",  },
            { key = "_cbHideCurrency",    },
            { key = "_cbHideWeeklies",    },
            { key = "_cbHideChangeWeek",  },
            { key = "_cbHideIlvlRef",     },
            { key = "_cbHideCharPicker",  },
            { key = "_cbHideSliders",     },
            { key = "_cbHideUpdateNotice", },
            { key = "_cbHideMinimapBtn",  },
        }
        local callbacks = {
            _cbHideCompleted  = function(checked)
                local db = Addon:EnsurePrefs()
                db.hideCompletedSections = checked
                if Addon.RequestRefresh then Addon:RequestRefresh() else Addon:Refresh() end
                if Addon._inlineWeeklies and Addon._inlineWeeklies.Refresh then
                    Addon._inlineWeeklies.Refresh()
                end
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
            _cbHideWeeklies = function(checked)
                local db = Addon:EnsurePrefs()
                db.showInlineWeeklies = not checked
                if Addon.ApplyInlineWeekliesVisibility then
                    Addon:ApplyInlineWeekliesVisibility()
                end
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
            _cbHideCharPicker = function(checked)
                local db = Addon:EnsurePrefs()
                db.showCharPickerBtn = not checked
                if Addon.LayoutHeaderButtons        then Addon:LayoutHeaderButtons()        end
                if Addon.ApplyScaleSliderVisibility then Addon:ApplyScaleSliderVisibility() end
            end,
            _cbHideSliders = function(checked)
                local db = Addon:EnsurePrefs()
                db.showScaleSlider  = not checked
                db.showOpacitySlider = not checked
                if Addon.ApplyScaleSliderVisibility then Addon:ApplyScaleSliderVisibility() end
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

        local N          = #checks
        local TILE_H     = 34    -- total tile height (box + padding)
        local cbsY       = div1StartY + 1 + 8   -- checkboxes section top (px from popup top)

        for i, info in ipairs(checks) do
            local tileTopY = -(cbsY + (i - 1) * TILE_H)

            local _key = info.key
            local cb = Addon.Controls.NewCheckBox(p, function(newState)
                callbacks[_key](newState)
                if Addon.SyncGearPopup then Addon:SyncGearPopup() end
            end)
            -- Span the full tile height so the box centers vertically even
            -- when the label wraps to multiple lines.
            cb:SetPoint("TOPLEFT",  p, "TOPLEFT",  PAD, tileTopY)
            cb:SetHeight(TILE_H)
            cb._label:SetPoint("RIGHT", p, "RIGHT", -PAD, 0)
            p[info.key] = cb

            -- Wire the pre-created _hit to span the full tile width.
            local hit = cb._hit
            hit:SetPoint("TOPLEFT",  p, "TOPLEFT",  0, tileTopY)
            hit:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, tileTopY)
            hit:SetHeight(TILE_H)
        end

        -- ── Divider before Hidden Characters ──────────────────────────────
        local div2StartY = cbsY + N * TILE_H + 6
        local div2 = Addon.Controls.NewDivider(p, -div2StartY, PAD, PAD)
        p._gearHiddenCharsDiv = div2

        -- ── Hidden Characters trigger ──────────────────────────────────────
        local hidStartY = div2StartY + 1 + 8
        local hiddenTrigger = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
        hiddenTrigger:SetPoint("TOPLEFT",  p, "TOPLEFT",  PAD,  -hidStartY)
        hiddenTrigger:SetPoint("TOPRIGHT", p, "TOPRIGHT", -PAD, -hidStartY)
        hiddenTrigger:SetHeight(22)
        if Addon._styleActionButton then Addon._styleActionButton(hiddenTrigger) end
        hiddenTrigger:SetScript("OnClick", function()
            if Addon.ToggleHiddenCharsDropdown then Addon:ToggleHiddenCharsDropdown() end
        end)
        p._gearHiddenCharsTrigger  = hiddenTrigger
        Addon._gearHiddenCharsTrigger = hiddenTrigger

        -- ── Version + credit ───────────────────────────────────────────────
        local _getMeta = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
        local _ver     = (_getMeta and _getMeta(addonName, "Version")) or ""
        local _locReg  = _G["LARIASWEEKLYCHECKLIST_LOCALE_REGISTRY"]
        local _dataVer = (_locReg and type(_locReg.sheet_version) == "string" and _locReg.sheet_version) or ""

        -- ── Compact color swatches – 3 in a row above the version block ──────
        -- Layout: label row sits above the swatch row, both anchored from popup bottom.
        -- COLOR_BOT_Y = swatch bottom; labels sit 20 px above that.
        local COLOR_BOT_Y = 48   -- bottom of swatch row (px from popup BOTTOMLEFT)
        local COLOR_DIV_Y = COLOR_BOT_Y + 36  -- divider sits above label+swatch stack
        local POPUP_INNER_W = 230 - 2 * PAD   -- 210 px
        local SW_SLOT_W     = math.floor(POPUP_INNER_W / 3)  -- ~70 px per slot

        local colorSectionDiv = p:CreateTexture(nil, "ARTWORK")
        colorSectionDiv:SetColorTexture(0.3, 0.3, 0.3, 0.5)
        colorSectionDiv:SetHeight(1)
        colorSectionDiv:SetPoint("BOTTOMLEFT",  p, "BOTTOMLEFT",  PAD,  COLOR_DIV_Y)
        colorSectionDiv:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -PAD, COLOR_DIV_Y)

        p._gearColorSwatches = {}
        p._gearColorLabels   = {}
        for si, sd in ipairs(GEAR_COLOR_DEFS) do
            local slotX = PAD + (si - 1) * SW_SLOT_W
            local _L = Addon.L or {}

            local lbl = p:CreateFontString(nil, "OVERLAY")
            lbl:SetFont("Fonts\\FRIZQT__.TTF", 9, "")
            lbl:SetText(_L[sd.labelKey] or sd.label)
            lbl:SetTextColor(0.70, 0.70, 0.70, 1)
            lbl:SetWidth(SW_SLOT_W)
            lbl:SetJustifyH("CENTER")
            lbl:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", slotX, COLOR_BOT_Y + 20)
            p._gearColorLabels[si] = lbl

            local sw = MakePopupSwatch(p)
            sw:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", slotX + math.floor((SW_SLOT_W - 16) / 2), COLOR_BOT_Y)
            sw:SetColor(sd.get())
            sw:SetScript("OnClick", function()
                local cr, cg, cb = sd.get()
                OpenPopupColorPicker(cr, cg, cb,
                    function(nr, ng, nb) sd.save(nr, ng, nb); sw:SetColor(nr, ng, nb) end,
                    function(pr, pg, pb) sd.save(pr, pg, pb); sw:SetColor(pr, pg, pb) end
                )
            end)
            p._gearColorSwatches[si] = sw
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

        -- ── Language toggle button (non-English clients only) ────────────────────
        -- Anchored from popup BOTTOM above the color section. Constants:
        --   COLOR_DIV_Y=84  ->  lang btn bottom=89, lang divider bottom=115
        --   VER_PAD grows from 104 to 134 when this button is visible.
        local langDivider = p:CreateTexture(nil, "ARTWORK")
        langDivider:SetColorTexture(0.3, 0.3, 0.3, 0.5)
        langDivider:SetHeight(1)
        langDivider:SetPoint("BOTTOMLEFT",  p, "BOTTOMLEFT",  PAD,  115)
        langDivider:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -PAD, 115)
        langDivider:Hide()
        p._gearLangDiv = langDivider

        local langBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
        langBtn:SetPoint("BOTTOMLEFT",  p, "BOTTOMLEFT",  PAD,  89)
        langBtn:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -PAD, 89)
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
