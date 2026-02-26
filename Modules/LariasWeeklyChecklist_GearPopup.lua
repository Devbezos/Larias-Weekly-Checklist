-- Gear popup: small floating panel with the 6 display toggles.
-- Appears when the gear icon in the main window header is clicked.
local addonName = ...
local Addon = _G[addonName]
if not Addon then return end

local function SetCheckText(checkButton, text)
    if not checkButton then return end
    -- Use the explicit _label FontString created alongside each checkbox.
    local lbl = checkButton._label
    if lbl then
        lbl:SetText(text or "")
        if lbl.SetTextColor and Addon.THEME and Addon.THEME.text then
            local t = Addon.THEME.text
            lbl:SetTextColor(t.r, t.g, t.b, t.a or 1)
        end
    end
end

-- Tints the standard UICheckButtonTemplate textures to match the dark theme.
-- Normal (unchecked box) → grey;  Checked mark → gold accent;  Hover → subtle white.
local function StyleCheckButton(cb)
    if not cb then return end
    local norm = cb.GetNormalTexture and cb:GetNormalTexture()
    if norm then norm:SetVertexColor(0.55, 0.55, 0.55, 1) end
    local chk = cb.GetCheckedTexture and cb:GetCheckedTexture()
    if chk then
        local th = Addon.THEME and Addon.THEME.header
        if th then chk:SetVertexColor(th.r, th.g, th.b, 1) end
    end
    local hi = cb.GetHighlightTexture and cb:GetHighlightTexture()
    if hi then hi:SetVertexColor(1, 1, 1, 0.12) end
end

function Addon:SyncGearPopup()
    local p = self._gearPopup
    if not p then return end
    local db = self:EnsureDB()
    local L  = self.L or {}
    local function Sync(cb, checked, label)
        if cb then
            cb:SetChecked(checked)
            SetCheckText(cb, label)
        end
    end
    Sync(p._cbHideCompleted,    db.hideCompletedSections and true or false,
         L.HIDE_COMPLETED_WEEKS      or "Hide completed weeks")
    Sync(p._cbHideGreatVault,   not db.showGreatVault,
         L.OPTIONS_HIDE_GREAT_VAULT  or "Hide Great Vault")
    Sync(p._cbHideCurrency,     not db.showCurrency,
         L.OPTIONS_HIDE_CURRENCY     or "Hide Currency")
    Sync(p._cbHideChangeWeek,   db.showChangeWeekBtn == false,
         L.OPTIONS_HIDE_CHANGE_WEEK_BTN or "Hide week selector")
    Sync(p._cbHideIlvlRef,      db.showIlvlRefBtn == false,
         L.OPTIONS_HIDE_ILVL_REF_BTN or "Hide ilvl references")
    Sync(p._cbHideCharPicker,   db.showCharPickerBtn == false,
         L.OPTIONS_HIDE_CHAR_SELECT  or "Hide character selector")
    Sync(p._cbHideScaleSlider,  db.showScaleSlider == false,
         L.OPTIONS_HIDE_SCALE_SLIDER or "Hide scale slider")

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

    -- Recalculate popup height based on visible content, and reposition any rows
    -- below the (possibly-hidden) char picker slot so no gap is left behind.
    do
        local PAD_   = 10
        local ROW_H_ = 26
        local TILE_H_= ROW_H_ + 8   -- 34
        local N_TOTAL = 7
        local rstStartY_  = PAD_
        local div1StartY_ = rstStartY_ + 22 + 6
        local cbsY_       = div1StartY_ + 1 + 8
        -- Char picker is always slot index 6; scale slider is always slot index 7.
        -- When char picker is hidden, slide the scale slider up into slot 6.
        local SLIDER_IDX  = 7
        local sliderVisIdx = showCharRow and SLIDER_IDX or (SLIDER_IDX - 1)
        local cbSlider = p._cbHideScaleSlider
        if cbSlider then
            local tileTopY = -(cbsY_ + (sliderVisIdx - 1) * TILE_H_)
            local cbOffY   = tileTopY - math.floor((TILE_H_ - ROW_H_) / 2)
            cbSlider:ClearAllPoints()
            cbSlider:SetPoint("TOPLEFT", p, "TOPLEFT", PAD_, cbOffY)
            if cbSlider._hit then
                cbSlider._hit:ClearAllPoints()
                cbSlider._hit:SetPoint("TOPLEFT",  p, "TOPLEFT",  0, tileTopY)
                cbSlider._hit:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, tileTopY)
            end
        end

        local nVisible    = showCharRow and N_TOTAL or (N_TOTAL - 1)
        -- Reposition the hidden-chars divider and trigger to follow the last checkbox.
        local div2StartY_ = cbsY_ + nVisible * TILE_H_ + 6
        local hidStartY_  = div2StartY_ + 1 + 8
        if p._gearHiddenCharsDiv then
            p._gearHiddenCharsDiv:ClearAllPoints()
            p._gearHiddenCharsDiv:SetPoint("TOPLEFT",  p, "TOPLEFT",  PAD_,  -div2StartY_)
            p._gearHiddenCharsDiv:SetPoint("TOPRIGHT", p, "TOPRIGHT", -PAD_, -div2StartY_)
        end
        if p._gearHiddenCharsTrigger then
            p._gearHiddenCharsTrigger:ClearAllPoints()
            p._gearHiddenCharsTrigger:SetPoint("TOPLEFT",  p, "TOPLEFT",  PAD_,  -hidStartY_)
            p._gearHiddenCharsTrigger:SetPoint("TOPRIGHT", p, "TOPRIGHT", -PAD_, -hidStartY_)
        end

        local totalH
        if showHiddenSect then
            totalH = hidStartY_ + 22 + PAD_
        else
            totalH = cbsY_ + nVisible * TILE_H_ + PAD_
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
end

function Addon:ToggleGearPopup(anchor)
    local p = self._gearPopup
    if p and p.IsShown and p:IsShown() then
        p:Hide()
        return
    end

    -- Create lazily.
    if not p then
        if BackdropTemplateMixin then
            p = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        else
            p = CreateFrame("Frame", nil, UIParent)
            if BackdropTemplateMixin and Mixin then Mixin(p, BackdropTemplateMixin) end
        end
        p:SetFrameStrata("DIALOG")
        p:SetClampedToScreen(true)
        p:SetSize(230, 10)   -- height set after rows are placed
        p:Hide()
        if p.SetToplevel   then p:SetToplevel(true)   end
        if p.SetFrameLevel then p:SetFrameLevel(200)  end

        -- Backdrop
        if p.SetBackdrop then
            p:SetBackdrop({
                bgFile   = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                tile = false, edgeSize = 1,
                insets = { left=1, right=1, top=1, bottom=1 },
            })
            if Addon.THEME then
                p:SetBackdropColor(Addon.THEME.bg.r, Addon.THEME.bg.g, Addon.THEME.bg.b, 1)
                p:SetBackdropBorderColor(Addon.THEME.border.r, Addon.THEME.border.g, Addon.THEME.border.b, 1)
            end
        end

        -- Outside-click catcher.
        local catcher = CreateFrame("Button", nil, UIParent)
        catcher:SetAllPoints(UIParent)
        catcher:SetFrameStrata("DIALOG")
        catcher:SetFrameLevel(p:GetFrameLevel() - 1)
        catcher:EnableMouse(true)
        catcher:Hide()
        -- Use OnMouseDown so the catcher hides before the click resolves,
        -- letting the MouseUp event pass through to whatever is underneath.
        -- OnClick would consume the full click, blocking the next action.
        catcher:SetScript("OnMouseDown", function() p:Hide() end)
        p:SetScript("OnHide", function() catcher:Hide() end)
        p:SetScript("OnShow", function()
            catcher:Show()
            if UIFrameFadeIn then UIFrameFadeIn(p, 0.12, 0, 1)
            else p:SetAlpha(1) end
        end)

        -- Layout constants.
        local PAD    = 10
        local ROW_H  = 26   -- UICheckButtonTemplate actual height

        -- ── Reset List button (top of popup) ───────────────────────────────
        local rstStartY = PAD          -- px from popup top
        local resetBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
        resetBtn:SetPoint("TOPLEFT",  p, "TOPLEFT",  PAD,  -rstStartY)
        resetBtn:SetPoint("TOPRIGHT", p, "TOPRIGHT", -PAD, -rstStartY)
        resetBtn:SetHeight(22)
        if Addon._styleActionButton then Addon._styleActionButton(resetBtn) end
        resetBtn:SetScript("OnClick", function()
            p:Hide()
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
            -- Reset main frame position, size, and UI scale back to defaults.
            local gdb = Addon.db and Addon.db.global
            if gdb then
                gdb.mainFramePos  = nil
                gdb.mainFrameSize = nil
                gdb.uiScalePct    = 100
            end
            if Addon.ApplyUIScale then Addon:ApplyUIScale() end
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
        local div1 = p:CreateTexture(nil, "OVERLAY")
        div1:SetHeight(1)
        div1:SetPoint("TOPLEFT",  p, "TOPLEFT",  PAD,  -div1StartY)
        div1:SetPoint("TOPRIGHT", p, "TOPRIGHT", -PAD, -div1StartY)
        if Addon.THEME then
            local bdr = Addon.THEME.border
            div1:SetColorTexture(bdr.r, bdr.g, bdr.b, 0.5)
        end

        -- ── 6 Checkboxes ──────────────────────────────────────────────────
        local checks = {
            { key = "_cbHideCompleted",   },
            { key = "_cbHideGreatVault",  },
            { key = "_cbHideCurrency",    },
            { key = "_cbHideChangeWeek",  },
            { key = "_cbHideIlvlRef",     },
            { key = "_cbHideCharPicker",  },
            { key = "_cbHideScaleSlider", },
        }
        local callbacks = {
            _cbHideCompleted  = function(checked)
                local db = Addon:EnsureDB()
                db.hideCompletedSections = checked
                if Addon.RequestRefresh then Addon:RequestRefresh() else Addon:Refresh() end
            end,
            _cbHideGreatVault = function(checked)
                local db = Addon:EnsureDB()
                db.showGreatVault = not checked
                if Addon.RequestRefresh then Addon:RequestRefresh() else Addon:Refresh() end
            end,
            _cbHideCurrency   = function(checked)
                local db = Addon:EnsureDB()
                db.showCurrency = not checked
                if Addon.RequestRefresh then Addon:RequestRefresh() else Addon:Refresh() end
            end,
            _cbHideChangeWeek = function(checked)
                local db = Addon:EnsureDB()
                db.showChangeWeekBtn = not checked
                if Addon.LayoutHeaderButtons then Addon:LayoutHeaderButtons() end
            end,
            _cbHideIlvlRef    = function(checked)
                local db = Addon:EnsureDB()
                db.showIlvlRefBtn = not checked
                if Addon.LayoutHeaderButtons then Addon:LayoutHeaderButtons() end
            end,
            _cbHideCharPicker = function(checked)
                local db = Addon:EnsureDB()
                db.showCharPickerBtn = not checked
                if Addon.LayoutHeaderButtons then Addon:LayoutHeaderButtons() end
            end,
            _cbHideScaleSlider = function(checked)
                local db = Addon:EnsureDB()
                db.showScaleSlider = not checked
                if Addon.ApplyScaleSliderVisibility then Addon:ApplyScaleSliderVisibility() end
            end,
        }

        local N          = #checks
        local TILE_H     = ROW_H + 8
        local cbsY       = div1StartY + 1 + 8   -- checkboxes section top (px from popup top)

        for i, info in ipairs(checks) do
            local tileTopY = -(cbsY + (i - 1) * TILE_H)
            local cbOffY   = tileTopY - math.floor((TILE_H - ROW_H) / 2)

            local cb = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
            cb:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, cbOffY)
            StyleCheckButton(cb)
            -- Explicit label (anonymous frames can't access $parenttext)
            local lbl = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            lbl:SetPoint("LEFT", cb, "RIGHT", 2, 0)
            lbl:SetPoint("RIGHT", p, "RIGHT", -PAD, 0)
            lbl:SetJustifyH("LEFT")
            if Addon.THEME and Addon.THEME.text then
                local t = Addon.THEME.text
                lbl:SetTextColor(t.r, t.g, t.b, t.a or 1)
            end
            cb._label = lbl
            local _key = info.key
            local function FireToggle(newState)
                callbacks[_key](newState)
                if Addon.SyncGearPopup then Addon:SyncGearPopup() end
            end
            cb:SetScript("OnClick", function(self_)
                FireToggle(self_:GetChecked() and true or false)
            end)
            p[info.key] = cb

            local hit = CreateFrame("Button", nil, p)
            hit:SetPoint("TOPLEFT",  p, "TOPLEFT",  0, tileTopY)
            hit:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, tileTopY)
            hit:SetHeight(TILE_H)
            hit:SetFrameLevel(p:GetFrameLevel())
            local hl = hit:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints(hit)
            hl:SetColorTexture(1, 1, 1, 0.06)
            hit:SetScript("OnClick", function()
                local newVal = not (cb:GetChecked() and true or false)
                cb:SetChecked(newVal)
                FireToggle(newVal)
            end)
            cb._hit = hit  -- stored so SyncGearPopup can show/hide the row
        end

        -- ── Divider before Hidden Characters ──────────────────────────────
        local div2StartY = cbsY + N * TILE_H + 6
        local div2 = p:CreateTexture(nil, "OVERLAY")
        div2:SetHeight(1)
        div2:SetPoint("TOPLEFT",  p, "TOPLEFT",  PAD,  -div2StartY)
        div2:SetPoint("TOPRIGHT", p, "TOPRIGHT", -PAD, -div2StartY)
        if Addon.THEME then
            local bdr = Addon.THEME.border
            div2:SetColorTexture(bdr.r, bdr.g, bdr.b, 0.5)
        end
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

        self._gearPopup = p
    end

    -- Sync current values and labels (includes hidden chars trigger label).
    self:SyncGearPopup()

    -- Position below the anchor (gear button) or center if no anchor.
    p:ClearAllPoints()
    if anchor then
        p:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -4)
    else
        p:SetPoint("CENTER", UIParent, "CENTER")
    end
    p:Show()
end
