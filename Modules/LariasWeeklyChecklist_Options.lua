local addonName = ...
local Addon = _G[addonName]
if not Addon then return end

local function GetMainFrame()
    if Addon._mainFrame then
        return Addon._mainFrame
    end
    local name = "LariasWeeklyChecklistFrame"
    return _G and _G[name]
end

local function SetCheckText(checkButton, text)
    if not checkButton then return end
    local textRegion = checkButton.text or checkButton.Text
    if textRegion and textRegion.SetText then
        textRegion:SetText(text)
        if textRegion.SetTextColor and Addon.THEME and Addon.THEME.text then
            textRegion:SetTextColor(Addon.THEME.text.r, Addon.THEME.text.g, Addon.THEME.text.b, Addon.THEME.text.a)
        end
    end
end

function Addon:InitOptionsTab(frame, optionsPanel)
    if not (frame and optionsPanel) then return end

    local db = self:EnsureDB()

    local hideCompletedCheck = CreateFrame("CheckButton", nil, optionsPanel, "UICheckButtonTemplate")
    -- Anchor the first item to the TOP-center of the panel so the whole column is centered.
    hideCompletedCheck:SetPoint("TOP", optionsPanel, "TOP", -100, -10)
    hideCompletedCheck:SetChecked(db.hideCompletedSections and true or false)
    hideCompletedCheck:SetScript("OnClick", function(selfBtn)
        local dbForClick = Addon:EnsureDB()
        dbForClick.hideCompletedSections = selfBtn:GetChecked() and true or false
        if Addon.RequestRefresh then
            Addon:RequestRefresh()
        else
            Addon:Refresh()
        end
    end)
    frame._lariasOptHideCompleted = hideCompletedCheck

    local showGreatVaultCheck = CreateFrame("CheckButton", nil, optionsPanel, "UICheckButtonTemplate")
    showGreatVaultCheck:SetPoint("TOPLEFT", hideCompletedCheck, "BOTTOMLEFT", 0, -8)
    showGreatVaultCheck:SetChecked(not db.showGreatVault)
    showGreatVaultCheck:SetScript("OnClick", function(selfBtn)
        local dbForClick = Addon:EnsureDB()
        dbForClick.showGreatVault = not selfBtn:GetChecked()
        if Addon.RequestRefresh then
            Addon:RequestRefresh()
        else
            Addon:Refresh()
        end
    end)
    frame._lariasOptShowGreatVault = showGreatVaultCheck

    local showCurrencyCheck = CreateFrame("CheckButton", nil, optionsPanel, "UICheckButtonTemplate")
    showCurrencyCheck:SetPoint("TOPLEFT", showGreatVaultCheck, "BOTTOMLEFT", 0, -8)
    showCurrencyCheck:SetChecked(not db.showCurrency)
    showCurrencyCheck:SetScript("OnClick", function(selfBtn)
        local dbForClick = Addon:EnsureDB()
        dbForClick.showCurrency = not selfBtn:GetChecked()
        if Addon.RequestRefresh then
            Addon:RequestRefresh()
        else
            Addon:Refresh()
        end
    end)
    frame._lariasOptShowCurrency = showCurrencyCheck

    local showChangeWeekCheck = CreateFrame("CheckButton", nil, optionsPanel, "UICheckButtonTemplate")
    showChangeWeekCheck:SetPoint("TOPLEFT", showCurrencyCheck, "BOTTOMLEFT", 0, -8)
    showChangeWeekCheck:SetChecked(db.showChangeWeekBtn == false)
    showChangeWeekCheck:SetScript("OnClick", function(selfBtn)
        local dbForClick = Addon:EnsureDB()
        dbForClick.showChangeWeekBtn = not selfBtn:GetChecked()
        if Addon.LayoutHeaderButtons then
            Addon:LayoutHeaderButtons()
        end
    end)
    frame._lariasOptShowChangeWeekBtn = showChangeWeekCheck

    local showIlvlRefCheck = CreateFrame("CheckButton", nil, optionsPanel, "UICheckButtonTemplate")
    showIlvlRefCheck:SetPoint("TOPLEFT", showChangeWeekCheck, "BOTTOMLEFT", 0, -8)
    showIlvlRefCheck:SetChecked(db.showIlvlRefBtn == false)
    showIlvlRefCheck:SetScript("OnClick", function(selfBtn)
        local dbForClick = Addon:EnsureDB()
        dbForClick.showIlvlRefBtn = not selfBtn:GetChecked()
        if Addon.LayoutHeaderButtons then
            Addon:LayoutHeaderButtons()
        end
    end)
    frame._lariasOptShowIlvlRefBtn = showIlvlRefCheck

    local showCharPickerCheck = CreateFrame("CheckButton", nil, optionsPanel, "UICheckButtonTemplate")
    showCharPickerCheck:SetPoint("TOPLEFT", showIlvlRefCheck, "BOTTOMLEFT", 0, -8)
    showCharPickerCheck:SetChecked(db.showCharPickerBtn == false)
    showCharPickerCheck:SetScript("OnClick", function(selfBtn)
        local dbForClick = Addon:EnsureDB()
        dbForClick.showCharPickerBtn = not selfBtn:GetChecked()
        if Addon.LayoutHeaderButtons then
            Addon:LayoutHeaderButtons()
        end
    end)
    frame._lariasOptShowCharPickerBtn = showCharPickerCheck

    local resetBtn = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
    resetBtn:SetSize(108, 22)
    if Addon._styleActionButton then
        Addon._styleActionButton(resetBtn)
    end
    resetBtn:SetScript("OnClick", function()
        local dbForReset = Addon:EnsureDB()
        if wipe then
            wipe(dbForReset.checked)
            wipe(dbForReset.collapsedSections)
        else
            dbForReset.checked = {}
            dbForReset.collapsedSections = {}
        end
        dbForReset.hideCompletedSections = true
        dbForReset.startAtSectionId = ""
        dbForReset.showGreatVault    = true
        dbForReset.showCurrency      = true
        dbForReset.showChangeWeekBtn = true
        dbForReset.showIlvlRefBtn    = true

        -- Reset window positions, sizes, and scale back to defaults
        local gdb = Addon.db and Addon.db.global
        if gdb then
            gdb.mainFramePos  = nil
            gdb.mainFrameSize = nil
            gdb.ilvlRefPos    = nil
            gdb.ilvlRefSize   = nil
            gdb.uiScalePct    = nil  -- resets to 100%
        end

        -- Switch back to own character before resetting frames/controls
        -- (so SyncOptionsTabControls and Refresh display own char's data).
        if Addon.SetViewingChar then Addon:SetViewingChar(nil) end

        local mf = Addon._mainFrame
        if mf then
            mf:SetScale(1.0)
            mf:ClearAllPoints()
            mf:SetPoint("CENTER")
            mf:SetSize(Addon.UI.frameW, Addon.UI.frameH)
            if Addon.ApplyScrollLayout then Addon:ApplyScrollLayout() end
        end

        local iw = Addon._ilvlRefWindow
        if iw then
            iw:ClearAllPoints()
            if mf then
                iw:SetPoint("TOPLEFT", mf, "TOPRIGHT", 4, 0)
            else
                iw:SetPoint("CENTER", UIParent, "CENTER", 260, 0)
            end
            local bw = iw._baseW or Addon.UI.frameW
            local bh = iw._baseH or 540
            iw:SetSize(bw, bh)
            if iw._ilvlReflow then iw._ilvlReflow() end
        end

        if Addon.LayoutHeaderButtons then
            Addon:LayoutHeaderButtons()
        end

        if Addon.SyncOptionsTabControls then
            Addon:SyncOptionsTabControls()
        end

        if Addon.RequestRefresh then
            Addon:RequestRefresh()
        else
            Addon:Refresh()
        end
    end)

    frame._lariasOptResetBtn = resetBtn

    -- UI Scale slider -------------------------------------------------------
    local scaleTitle = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    scaleTitle:SetPoint("TOPLEFT", showCharPickerCheck, "BOTTOMLEFT", 0, -16)
    frame._lariasOptScaleTitleFS = scaleTitle

    local scaleSlider = CreateFrame("Slider", "LariasWeeklyChecklistScaleSlider", optionsPanel, "OptionsSliderTemplate")
    scaleSlider:SetPoint("TOPLEFT", scaleTitle, "BOTTOMLEFT", 6, -6)
    scaleSlider:SetWidth(220)
    scaleSlider:SetMinMaxValues(80, 120)
    scaleSlider:SetValueStep(1)
    local _initPct = (Addon.db and Addon.db.global and tonumber(Addon.db.global.uiScalePct)) or 100
    scaleSlider:SetValue(math.max(80, math.min(120, _initPct)))
    do
        local lo  = _G["LariasWeeklyChecklistScaleSliderLow"]
        local hi  = _G["LariasWeeklyChecklistScaleSliderHigh"]
        local txt = _G["LariasWeeklyChecklistScaleSliderText"]
        if lo  then lo:SetText("80%")  end
        if hi  then hi:SetText("120%") end
        if txt then txt:SetText("")    end  -- title managed separately
    end
    local function ApplyScaleVal(val)
        val = math.floor(val + 0.5)
        local gdb = Addon.db and Addon.db.global
        if gdb then gdb.uiScalePct = val end
        local tf = GetMainFrame() and GetMainFrame()._lariasOptScaleTitleFS
        if tf then
            local L2 = Addon.L or {}
            tf:SetText((L2.UI_SCALE_LABEL or "UI Scale") .. ": " .. val .. "%")
        end
        if Addon.ApplyUIScale then Addon:ApplyUIScale() end
    end
    -- Update label while dragging; only apply scale on release to avoid
    -- the window resizing jankily on every tick.
    scaleSlider:SetScript("OnValueChanged", function(self_, val)
        val = math.floor(val + 0.5)
        local tf = GetMainFrame() and GetMainFrame()._lariasOptScaleTitleFS
        if tf then
            local L2 = Addon.L or {}
            tf:SetText((L2.UI_SCALE_LABEL or "UI Scale") .. ": " .. val .. "%")
        end
    end)
    scaleSlider:SetScript("OnMouseUp", function(self_)
        ApplyScaleVal(self_:GetValue())
    end)
    frame._lariasScaleSlider = scaleSlider
    -- -------------------------------------------------------------------------

    -- Hidden characters section ----------------------------------------------
    local hiddenCharsTitle = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    hiddenCharsTitle:SetPoint("TOPLEFT", scaleSlider, "BOTTOMLEFT", -6, -14)
    frame._lariasOptHiddenCharsTitle = hiddenCharsTitle

    local hiddenCharsTriggerBtn = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
    hiddenCharsTriggerBtn:SetPoint("TOPLEFT", hiddenCharsTitle, "BOTTOMLEFT", 0, -4)
    hiddenCharsTriggerBtn:SetSize(108, 22)
    if Addon._styleActionButton then Addon._styleActionButton(hiddenCharsTriggerBtn) end
    hiddenCharsTriggerBtn:SetScript("OnClick", function()
        if Addon.ToggleHiddenCharsDropdown then Addon:ToggleHiddenCharsDropdown() end
    end)
    frame._lariasOptHiddenCharsTrigger = hiddenCharsTriggerBtn
    -- -------------------------------------------------------------------------

    -- Reset button: bottom of the column, below hidden chars trigger.
    resetBtn:SetPoint("TOPLEFT", hiddenCharsTriggerBtn, "BOTTOMLEFT", 0, -14)

    local localizationHint = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    localizationHint:SetPoint("TOPLEFT", resetBtn, "BOTTOMLEFT", 0, -8)
    localizationHint:SetWidth(200)
    localizationHint:SetJustifyH("LEFT")
    localizationHint:SetJustifyV("TOP")
    localizationHint:Hide()
    frame._lariasOptLocalizationHint = localizationHint

    if Addon.RefreshHiddenCharsList then
        Addon:RefreshHiddenCharsList()
    end

    if self.UpdateOptionsLocalizedUI then
        self:UpdateOptionsLocalizedUI()
    end
end

function Addon:ToggleHiddenCharsDropdown()
    local picker = self._hiddenCharsPicker
    if picker and picker.IsShown and picker:IsShown() then
        picker:Hide()
        return
    end
    -- Create picker frame lazily.
    if not picker then
        if BackdropTemplateMixin then
            picker = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        else
            picker = CreateFrame("Frame", nil, UIParent)
        end
        if not picker.SetBackdrop and BackdropTemplateMixin and Mixin then
            Mixin(picker, BackdropTemplateMixin)
        end
        picker:SetFrameStrata("HIGH")
        picker:SetClampedToScreen(true)
        picker:SetSize(160, 40)
        picker:Hide()
        if picker.SetToplevel then picker:SetToplevel(true) end
        if picker.SetFrameLevel then picker:SetFrameLevel(200) end
        if picker.SetBackdrop then
            picker:SetBackdrop({
                bgFile   = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                tile = false, edgeSize = 1,
                insets = { left=1, right=1, top=1, bottom=1 },
            })
        end
        if Addon.THEME then
            if picker.SetBackdropColor then
                picker:SetBackdropColor(Addon.THEME.bg.r, Addon.THEME.bg.g, Addon.THEME.bg.b, 1.0)
            end
            if picker.SetBackdropBorderColor then
                picker:SetBackdropBorderColor(Addon.THEME.border.r, Addon.THEME.border.g, Addon.THEME.border.b, Addon.THEME.border.a)
            end
        end
        picker._buttons = {}
        picker._pool    = {}
        -- Fullscreen catcher closes picker on outside click.
        local catcher = CreateFrame("Button", nil, UIParent)
        catcher:SetAllPoints(UIParent)
        catcher:SetFrameStrata("HIGH")
        catcher:SetFrameLevel(picker:GetFrameLevel() - 1)
        catcher:Hide()
        catcher:SetScript("OnClick", function()
            picker:Hide()
            catcher:Hide()
        end)
        picker._catcher = catcher
        picker:SetScript("OnHide", function() catcher:Hide() end)
        picker:SetScript("OnShow", function() catcher:Show() end)
        self._hiddenCharsPicker = picker
    end
    -- Position below the trigger button.
    local frame = GetMainFrame()
    local trigBtn = frame and frame._lariasOptHiddenCharsTrigger
    picker:ClearAllPoints()
    if trigBtn then
        picker:SetPoint("TOPLEFT", trigBtn, "BOTTOMLEFT", 0, -4)
    else
        picker:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    self:RefreshHiddenCharsList()
    picker:Show()
end

function Addon:RefreshHiddenCharsList()
    local frame = GetMainFrame()
    if not frame then return end

    local L          = self.L or {}
    local gdb        = self.db and self.db.global
    local hiddenMap  = gdb and gdb.hiddenChars or {}
    local ROW_H      = 20
    local PAD        = 6
    local BTN_W      = 20
    local NAME_W_MIN = 120

    -- Collect and sort hidden keys.
    local hidden = {}
    for key, v in pairs(hiddenMap) do
        if v then tinsert(hidden, key) end
    end
    table.sort(hidden)

    -- Update trigger button label.
    local trigBtn = frame._lariasOptHiddenCharsTrigger
    if trigBtn and trigBtn.SetText then
        local label = string.format("%s (%d)", L.OPTIONS_HIDDEN_CHARS_TITLE or "Hidden", #hidden)
        trigBtn:SetText(label)
    end

    -- If the dropdown isn't open, nothing else to do.
    local picker = self._hiddenCharsPicker
    if not (picker and picker.IsShown and picker:IsShown()) then return end

    -- Release existing rows back to pool.
    for _, b in ipairs(picker._buttons) do
        b:Hide()
        b:ClearAllPoints()
        b:SetScript("OnClick", nil)
        tinsert(picker._pool, b)
    end
    wipe(picker._buttons)

    local function AcquireRow()
        local f = tremove(picker._pool)
        if not f then
            f = CreateFrame("Frame", nil, picker)
            -- name button
            local nb = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
            nb:SetHeight(ROW_H)
            nb:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
            if Addon._styleActionButton then Addon._styleActionButton(nb) end
            if nb.SetTextInsets then nb:SetTextInsets(4, 4, 0, 0) end
            local ntr = nb.Text or (nb.GetFontString and nb:GetFontString())
            if ntr then
                if ntr.SetJustifyH then ntr:SetJustifyH("LEFT") end
                if ntr.SetJustifyV then ntr:SetJustifyV("MIDDLE") end
            end
            f._nameBtn = nb
            -- unhide button
            local ub = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
            ub:SetSize(BTN_W, ROW_H)
            ub:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
            if Addon._styleActionButton then Addon._styleActionButton(ub) end
            if ub.SetTextInsets then ub:SetTextInsets(0, 0, 0, 0) end
            local utr = ub.Text or (ub.GetFontString and ub:GetFontString())
            if utr and utr.SetJustifyH then utr:SetJustifyH("CENTER") end
            ub:SetText("|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12|t")
            f._unhideBtn = ub
        end
        f:Show()
        return f
    end

    if #hidden == 0 then
        -- Single disabled row saying "None".
        local f = AcquireRow()
        f._nameBtn:SetText(L.OPTIONS_HIDDEN_CHARS_NONE or "None")
        f._nameBtn:SetEnabled(false)
        f._unhideBtn:Hide()
        f._nameBtn:SetWidth(NAME_W_MIN)
        f:SetSize(NAME_W_MIN + PAD * 2, ROW_H)
        f:SetPoint("TOPLEFT", picker, "TOPLEFT", PAD, -PAD)
        tinsert(picker._buttons, f)
        picker:SetSize(NAME_W_MIN + PAD * 2, ROW_H + PAD * 2)
        return
    end

    local posY   = -PAD
    local bestW  = NAME_W_MIN
    for i, key in ipairs(hidden) do
        local charName    = (key:match("^(.-)%s*%-") or key):gsub("^%s+",""):gsub("%s+$","")
        local realm       = (key:match("%-(.+)$") or ""):gsub("^%s+",""):gsub("%s+$","")
        local displayText = (realm ~= "") and (charName .. " - " .. realm) or key

        local f = AcquireRow()
        f._nameBtn:SetEnabled(true)
        f._unhideBtn:Show()

        -- Class colour.
        local classToken = gdb and gdb.charClasses and gdb.charClasses[key]
        local r, g, b = 1, 1, 1
        if classToken then
            local cc = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
            if cc then r, g, b = cc.r, cc.g, cc.b end
        end
        local ntr = f._nameBtn.Text or (f._nameBtn.GetFontString and f._nameBtn:GetFontString())
        if ntr then ntr:SetTextColor(r, g, b, 1) end
        f._nameBtn:SetText(displayText)

        local _key = key
        local function doUnhide()
            local gdbU = Addon.db and Addon.db.global
            if gdbU and gdbU.hiddenChars then gdbU.hiddenChars[_key] = nil end
            if Addon.RefreshHiddenCharsList then Addon:RefreshHiddenCharsList() end
            if Addon.LayoutHeaderButtons    then Addon:LayoutHeaderButtons() end
            -- If the char picker button just became visible, open its dropdown
            -- so the player can immediately switch to the newly unhidden character.
            if C_Timer and C_Timer.After then
                C_Timer.After(0, function()
                    local cpBtn = Addon._cpEnsureBtn and Addon._cpEnsureBtn()
                    if cpBtn and cpBtn.IsShown and cpBtn:IsShown() then
                        if Addon._cpOnClick then Addon._cpOnClick() end
                    end
                end)
            end
        end
        f._nameBtn:SetScript("OnClick",   doUnhide)
        f._unhideBtn:SetScript("OnClick", doUnhide)

        f:SetPoint("TOPLEFT", picker, "TOPLEFT", PAD, posY)
        posY = posY - ROW_H
        tinsert(picker._buttons, f)
    end

    local totalH = -posY + PAD
    picker:SetHeight(math.max(40, totalH))

    -- Deferred width sizing (same pattern as header picker).
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            if not (picker and picker.IsShown and picker:IsShown()) then return end
            local bw = NAME_W_MIN
            for _, f in ipairs(picker._buttons) do
                local nb = f._nameBtn
                local tr = nb.Text or (nb.GetFontString and nb:GetFontString())
                local w  = 0
                if tr then
                    if tr.GetUnboundedStringWidth then w = tonumber(tr:GetUnboundedStringWidth()) or 0 end
                    if w <= 0 and tr.GetStringWidth then w = tonumber(tr:GetStringWidth()) or 0 end
                end
                if w > bw then bw = w end
            end
            local newW = math.max(160, math.min(400, math.ceil(bw) + BTN_W + PAD * 3 + 8))
            picker:SetWidth(newW)
            for _, f in ipairs(picker._buttons) do
                f:SetWidth(newW - PAD * 2)
                f._nameBtn:SetWidth(newW - PAD * 2 - BTN_W - 4)
            end
        end)
    end
    -- Initial width.
    local initW = NAME_W_MIN + BTN_W + PAD * 3 + 8
    picker:SetWidth(initW)
    for _, f in ipairs(picker._buttons) do
        f:SetWidth(initW - PAD * 2)
        f._nameBtn:SetWidth(initW - PAD * 2 - BTN_W - 4)
    end
end

function Addon:SyncOptionsTabControls()
    local frame = GetMainFrame()
    if not frame then return end

    local db = self:EnsureDB()

    local showGreatVaultCheck = frame._lariasOptShowGreatVault
    if showGreatVaultCheck and showGreatVaultCheck.SetChecked then
        showGreatVaultCheck:SetChecked(not db.showGreatVault)
    end

    local showCurrencyCheck = frame._lariasOptShowCurrency
    if showCurrencyCheck and showCurrencyCheck.SetChecked then
        showCurrencyCheck:SetChecked(not db.showCurrency)
    end

    local hideCompletedCheck = frame._lariasOptHideCompleted
    if hideCompletedCheck and hideCompletedCheck.SetChecked then
        hideCompletedCheck:SetChecked(db.hideCompletedSections and true or false)
    end

    local showChangeWeekCheck = frame._lariasOptShowChangeWeekBtn
    if showChangeWeekCheck and showChangeWeekCheck.SetChecked then
        showChangeWeekCheck:SetChecked(db.showChangeWeekBtn == false)
    end

    local showIlvlRefCheck = frame._lariasOptShowIlvlRefBtn
    if showIlvlRefCheck and showIlvlRefCheck.SetChecked then
        showIlvlRefCheck:SetChecked(db.showIlvlRefBtn == false)
    end

    local showCharPickerCheck = frame._lariasOptShowCharPickerBtn
    if showCharPickerCheck and showCharPickerCheck.SetChecked then
        showCharPickerCheck:SetChecked(db.showCharPickerBtn == false)
    end

    if self.RefreshHiddenCharsList then
        self:RefreshHiddenCharsList()
    end

    local scaleSlider = frame._lariasScaleSlider
    if scaleSlider and scaleSlider.SetValue then
        local gdb = Addon.db and Addon.db.global
        scaleSlider:SetValue((gdb and tonumber(gdb.uiScalePct)) or 100)
    end

    if self.UpdateOptionsLocalizedUI then
        self:UpdateOptionsLocalizedUI()
    end
end

function Addon:UpdateOptionsLocalizedUI()
    local frame = GetMainFrame()
    if not frame then return end

    local L = self.L or {}

    SetCheckText(frame._lariasOptHideCompleted, L.HIDE_COMPLETED_WEEKS or "Hide completed weeks")
    SetCheckText(frame._lariasOptShowGreatVault, L.OPTIONS_HIDE_GREAT_VAULT or "Hide Great Vault")
    SetCheckText(frame._lariasOptShowCurrency, L.OPTIONS_HIDE_CURRENCY or "Hide Currency")
    SetCheckText(frame._lariasOptShowChangeWeekBtn, L.OPTIONS_HIDE_CHANGE_WEEK_BTN or "Hide Change Week button")
    SetCheckText(frame._lariasOptShowIlvlRefBtn, L.OPTIONS_HIDE_ILVL_REF_BTN or "Hide Ilvl Refs button")
    SetCheckText(frame._lariasOptShowCharPickerBtn, L.OPTIONS_HIDE_CHAR_SELECT or "Hide character select")

    local hiddenCharsTitle = frame._lariasOptHiddenCharsTitle
    if hiddenCharsTitle and hiddenCharsTitle.SetText then
        hiddenCharsTitle:SetText(L.OPTIONS_HIDDEN_CHARS_TITLE or "Hidden characters:")
    end

    if self.RefreshHiddenCharsList then
        self:RefreshHiddenCharsList()
    end

    local resetBtn = frame._lariasOptResetBtn
    if resetBtn and resetBtn.SetText then
        resetBtn:SetText(L.RESET_BUTTON or "Reset List")
    end

    local scaleTitleFS = frame._lariasOptScaleTitleFS
    if scaleTitleFS then
        local gdb = Addon.db and Addon.db.global
        local pct = (gdb and tonumber(gdb.uiScalePct)) or 100
        scaleTitleFS:SetText((L.UI_SCALE_LABEL or "UI Scale") .. ": " .. pct .. "%")
    end

    local hint = frame._lariasOptLocalizationHint
    if hint and hint.SetText then
        if Addon.ShouldShowLocalizationCompanionHint and Addon:ShouldShowLocalizationCompanionHint() then
            hint:SetText(Addon.LOCALIZATION_COMPANION_HINT_TEXT or "Tip: For non-English translations, install the optional addon 'LariasWeeklyChecklist_Localization'.")
            hint:Show()
        else
            hint:SetText("")
            hint:Hide()
        end
    end
end
