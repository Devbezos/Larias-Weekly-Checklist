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

    local resetBtn = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
    resetBtn:SetPoint("TOPLEFT", showIlvlRefCheck, "BOTTOMLEFT", 0, -12)
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
    scaleTitle:SetPoint("TOPLEFT", resetBtn, "BOTTOMLEFT", 0, -18)
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
    scaleSlider:SetScript("OnValueChanged", function(_, val)
        val = math.floor(val / 10 + 0.5) * 10
        local gdb = Addon.db and Addon.db.global
        if gdb then gdb.uiScalePct = val end
        local tf = GetMainFrame() and GetMainFrame()._lariasOptScaleTitleFS
        if tf then
            local L2 = Addon.L or {}
            tf:SetText((L2.UI_SCALE_LABEL or "UI Scale") .. ": " .. val .. "%")
        end
        if Addon.ApplyUIScale then Addon:ApplyUIScale() end
    end)
    frame._lariasScaleSlider = scaleSlider
    -- -----------------------------------------------------------------------

    local localizationHint = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    localizationHint:SetPoint("TOPLEFT", resetBtn, "BOTTOMLEFT", 0, -10)
    localizationHint:SetWidth(420)
    localizationHint:SetJustifyH("LEFT")
    localizationHint:SetJustifyV("TOP")
    localizationHint:Hide()
    frame._lariasOptLocalizationHint = localizationHint

    if self.UpdateOptionsLocalizedUI then
        self:UpdateOptionsLocalizedUI()
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
