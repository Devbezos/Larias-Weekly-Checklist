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
    hideCompletedCheck:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 6, -6)
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

    -- ── Right column anchor ──────────────────────────────────────────────────
    local RIGHT_COL_X = 216

    local resetBtn = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
    resetBtn:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", RIGHT_COL_X, -6)
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
    scaleTitle:SetPoint("TOPLEFT", resetBtn, "BOTTOMLEFT", 0, -14)
    frame._lariasOptScaleTitleFS = scaleTitle

    local scaleSlider = CreateFrame("Slider", "LariasWeeklyChecklistScaleSlider", optionsPanel, "OptionsSliderTemplate")
    scaleSlider:SetPoint("TOPLEFT", scaleTitle, "BOTTOMLEFT", 6, -6)
    scaleSlider:SetWidth(220)
    scaleSlider:SetMinMaxValues(80, 120)
    scaleSlider:SetValueStep(10)
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
        val = math.floor(val / 10 + 0.5) * 10
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
        val = math.floor(val / 10 + 0.5) * 10
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

    local hiddenCharsPanel = CreateFrame("Frame", nil, optionsPanel)
    hiddenCharsPanel:SetPoint("TOPLEFT", hiddenCharsTitle, "BOTTOMLEFT", 0, -4)
    hiddenCharsPanel:SetWidth(210)
    hiddenCharsPanel:SetHeight(20)
    hiddenCharsPanel._rows = {}
    frame._lariasOptHiddenCharsPanel = hiddenCharsPanel
    -- -------------------------------------------------------------------------

    local localizationHint = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    localizationHint:SetPoint("TOPLEFT", showCharPickerCheck, "BOTTOMLEFT", 6, -10)
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

function Addon:RefreshHiddenCharsList()
    local frame = GetMainFrame()
    if not frame then return end
    local panel = frame._lariasOptHiddenCharsPanel
    if not panel then return end

    local L = self.L or {}
    local gdb = self.db and self.db.global
    local hiddenChars = gdb and gdb.hiddenChars or {}
    local ROW_H = 22
    local BTN_W = 20
    local PAD   = 4

    -- Collect and sort hidden keys.
    local hidden = {}
    for key, v in pairs(hiddenChars) do
        if v then tinsert(hidden, key) end
    end
    table.sort(hidden)

    panel._rows = panel._rows or {}

    if #hidden == 0 then
        for _, row in ipairs(panel._rows) do row:Hide() end
        if not panel._noneLabel then
            local lbl = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
            lbl:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
            panel._noneLabel = lbl
        end
        panel._noneLabel:SetText(L.OPTIONS_HIDDEN_CHARS_NONE or "None")
        panel._noneLabel:Show()
        panel:SetHeight(ROW_H)
        return
    end

    if panel._noneLabel then panel._noneLabel:Hide() end

    for i, key in ipairs(hidden) do
        local charName = (key:match("^(.-)%s*%-") or key):gsub("^%s+",""):gsub("%s+$","")
        local realm    = (key:match("%-%s*(.+)$") or ""):gsub("^%s+",""):gsub("%s+$","")
        local displayText
        if realm ~= "" then
            displayText = charName .. " - " .. realm
        else
            displayText = key
        end

        local row = panel._rows[i]
        if not row then
            row = CreateFrame("Frame", nil, panel)
            panel._rows[i] = row

            -- Checkmark button (unhide action)
            local checkBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            checkBtn:SetSize(BTN_W, BTN_W)
            checkBtn:SetPoint("LEFT", row, "LEFT", 0, 0)
            if Addon._styleActionButton then Addon._styleActionButton(checkBtn) end
            local checkTR = checkBtn.Text or (checkBtn.GetFontString and checkBtn:GetFontString())
            if checkTR then
                if checkTR.SetJustifyH then checkTR:SetJustifyH("CENTER") end
            end
            checkBtn:SetText("|cFF00FF00\226\156\147|r")  -- green checkmark ✓
            row._checkBtn = checkBtn

            -- Name + realm fontstring  (aligns flush with panel left after button)
            local nameFS = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            nameFS:SetPoint("LEFT", checkBtn, "RIGHT", PAD, 0)
            nameFS:SetWidth(panel:GetWidth() - BTN_W - PAD * 2)
            if nameFS.SetJustifyH then nameFS:SetJustifyH("LEFT") end
            if nameFS.SetWordWrap  then nameFS:SetWordWrap(false)  end
            row._nameFS = nameFS
        end

        row:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -(ROW_H * (i - 1)))
        row:SetSize(panel:GetWidth(), ROW_H)
        row:Show()

        local classToken = gdb and gdb.charClasses and gdb.charClasses[key]
        local r, g, b = 1, 1, 1
        if classToken then
            local cc = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
            if cc then r, g, b = cc.r, cc.g, cc.b end
        end
        row._nameFS:SetText(displayText)
        row._nameFS:SetTextColor(r, g, b, 1)

        local _key = key
        row._checkBtn:SetScript("OnClick", function()
            local gdbU = Addon.db and Addon.db.global
            if gdbU and gdbU.hiddenChars then
                gdbU.hiddenChars[_key] = nil
            end
            if Addon.RefreshHiddenCharsList then Addon:RefreshHiddenCharsList() end
        end)
    end

    -- Hide any unused rows from a previous (longer) list.
    for i = #hidden + 1, #panel._rows do
        if panel._rows[i] then panel._rows[i]:Hide() end
    end

    panel:SetHeight(math.max(ROW_H, ROW_H * #hidden))
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
