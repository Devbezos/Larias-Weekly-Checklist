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

    local showGreatVaultCheck = CreateFrame("CheckButton", nil, optionsPanel, "UICheckButtonTemplate")
    showGreatVaultCheck:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 6, -6)
    showGreatVaultCheck:SetChecked(db.showGreatVault and true or false)
    showGreatVaultCheck:SetScript("OnClick", function(selfBtn)
        local dbForClick = Addon:EnsureDB()
        dbForClick.showGreatVault = selfBtn:GetChecked() and true or false
        if Addon.RequestRefresh then
            Addon:RequestRefresh()
        else
            Addon:Refresh()
        end
    end)
    frame._lariasOptShowGreatVault = showGreatVaultCheck

    local showCurrencyCheck = CreateFrame("CheckButton", nil, optionsPanel, "UICheckButtonTemplate")
    showCurrencyCheck:SetPoint("TOPLEFT", showGreatVaultCheck, "BOTTOMLEFT", 0, -8)
    showCurrencyCheck:SetChecked(db.showCurrency and true or false)
    showCurrencyCheck:SetScript("OnClick", function(selfBtn)
        local dbForClick = Addon:EnsureDB()
        dbForClick.showCurrency = selfBtn:GetChecked() and true or false
        if Addon.RequestRefresh then
            Addon:RequestRefresh()
        else
            Addon:Refresh()
        end
    end)
    frame._lariasOptShowCurrency = showCurrencyCheck

    local hideCompletedCheck = CreateFrame("CheckButton", nil, optionsPanel, "UICheckButtonTemplate")
    hideCompletedCheck:SetPoint("TOPLEFT", showCurrencyCheck, "BOTTOMLEFT", 0, -8)
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

    local resetBtn = CreateFrame("Button", nil, optionsPanel, "GameMenuButtonTemplate")
    resetBtn:SetPoint("TOPLEFT", hideCompletedCheck, "BOTTOMLEFT", 0, -12)
    resetBtn:SetSize(120, 24)
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
        showGreatVaultCheck:SetChecked(db.showGreatVault and true or false)
    end

    local showCurrencyCheck = frame._lariasOptShowCurrency
    if showCurrencyCheck and showCurrencyCheck.SetChecked then
        showCurrencyCheck:SetChecked(db.showCurrency and true or false)
    end

    local hideCompletedCheck = frame._lariasOptHideCompleted
    if hideCompletedCheck and hideCompletedCheck.SetChecked then
        hideCompletedCheck:SetChecked(db.hideCompletedSections and true or false)
    end

    if self.UpdateOptionsLocalizedUI then
        self:UpdateOptionsLocalizedUI()
    end
end

function Addon:UpdateOptionsLocalizedUI()
    local frame = GetMainFrame()
    if not frame then return end

    local L = self.L or {}

    SetCheckText(frame._lariasOptShowGreatVault, L.OPTIONS_SHOW_GREAT_VAULT or "Show Great Vault")
    SetCheckText(frame._lariasOptShowCurrency, L.OPTIONS_SHOW_CURRENCY or "Show Currency")
    SetCheckText(frame._lariasOptHideCompleted, L.HIDE_COMPLETED_WEEKS or "Hide completed weeks")

    local resetBtn = frame._lariasOptResetBtn
    if resetBtn and resetBtn.SetText then
        resetBtn:SetText(L.RESET_BUTTON or "Reset")
    end
end
