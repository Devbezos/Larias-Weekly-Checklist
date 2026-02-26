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

-- Creates a 1-pixel horizontal rule anchored below anchorFrame.
local function MakeDivider(parent, anchorFrame, padX, offsetY)
    padX    = padX    or 0
    offsetY = offsetY or -8
    local d = parent:CreateTexture(nil, "ARTWORK")
    d:SetHeight(1)
    local th = Addon.THEME and Addon.THEME.border
    if th then
        d:SetColorTexture(th.r, th.g, th.b, 0.5)
    else
        d:SetColorTexture(0.3, 0.3, 0.3, 0.5)
    end
    d:SetPoint("TOPLEFT",  anchorFrame, "BOTTOMLEFT",  -padX, offsetY)
    d:SetPoint("TOPRIGHT", anchorFrame, "BOTTOMRIGHT",  padX, offsetY)
    return d
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
    StyleCheckButton(hideCompletedCheck)

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
    StyleCheckButton(showGreatVaultCheck)

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
    StyleCheckButton(showCurrencyCheck)

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
    StyleCheckButton(showChangeWeekCheck)

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
    StyleCheckButton(showIlvlRefCheck)

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
    StyleCheckButton(showCharPickerCheck)

    local localizationHint = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    localizationHint:SetPoint("TOPLEFT", showCharPickerCheck, "BOTTOMLEFT", 0, -12)
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
        picker:SetFrameStrata("FULLSCREEN_DIALOG")
        picker:SetClampedToScreen(true)
        picker:SetSize(160, 40)
        picker:Hide()
        if picker.SetToplevel then picker:SetToplevel(true) end
        if picker.SetFrameLevel then picker:SetFrameLevel(600) end
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
        catcher:SetFrameStrata("FULLSCREEN_DIALOG")
        catcher:SetFrameLevel(picker:GetFrameLevel() - 1)
        catcher:Hide()
        catcher:SetScript("OnClick", function()
            picker:Hide()
            catcher:Hide()
        end)
        picker._catcher = catcher
        picker:SetScript("OnHide", function() catcher:Hide() end)
        picker:SetScript("OnShow", function()
            catcher:Show()
            if UIFrameFadeIn then UIFrameFadeIn(picker, 0.15, 0, 1)
            else picker:SetAlpha(1) end
        end)
        self._hiddenCharsPicker = picker
    end
    -- Position below the trigger button (lives on the Blizzard options panel).
    local trigBtn = Addon._blizzOptHiddenCharsTrigger
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

    -- Update trigger button label (lives on the Blizzard options panel).
    local trigBtn = self._blizzOptHiddenCharsTrigger
    if trigBtn and trigBtn.SetText then
        local label = string.format("%s (%d) |TInterface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up:10:10|t", L.OPTIONS_HIDDEN_CHARS_TITLE or "Hidden", #hidden)
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
                f:SetSize(newW - PAD * 2, ROW_H)
                f._nameBtn:SetWidth(newW - PAD * 2 - BTN_W - 4)
            end
        end)
    end
    -- Initial width.
    local initW = NAME_W_MIN + BTN_W + PAD * 3 + 8
    picker:SetWidth(initW)
    for _, f in ipairs(picker._buttons) do
        f:SetSize(initW - PAD * 2, ROW_H)
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
    SetCheckText(frame._lariasOptShowChangeWeekBtn, L.OPTIONS_HIDE_CHANGE_WEEK_BTN or "Hide week selector")
    SetCheckText(frame._lariasOptShowIlvlRefBtn, L.OPTIONS_HIDE_ILVL_REF_BTN or "Hide ilvl references")
    SetCheckText(frame._lariasOptShowCharPickerBtn, L.OPTIONS_HIDE_CHAR_SELECT or "Hide character selector")

    if self.RefreshHiddenCharsList then
        self:RefreshHiddenCharsList()
    end

    -- Sync labels on the Blizzard options panel when locale changes.
    if self.SyncBlizzOptionsPanel then self:SyncBlizzOptionsPanel() end

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
-- ---------------------------------------------------------------------------
-- Blizzard Interface Options panel (Interface → AddOns → addonName)
-- Hosts: UI Scale slider, Hidden Characters, Reset List button.
-- ---------------------------------------------------------------------------

-- Builds the control content of the Blizzard options panel.
-- Called once lazily on first OnShow so L and THEME are fully loaded.
function Addon:InitBlizzOptionsPanel(panel)
    local L   = self.L or {}
    local PAD = 16

    -- Apply addon backdrop so the panel matches the addon's dark theme.
    if not panel.SetBackdrop then
        if BackdropTemplateMixin and Mixin then Mixin(panel, BackdropTemplateMixin) end
    end
    if panel.SetBackdrop and Addon.THEME then
        panel:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile = false, edgeSize = 1,
            insets = { left=0, right=0, top=0, bottom=0 },
        })
        local bg  = Addon.THEME.bg
        local brd = Addon.THEME.border
        panel:SetBackdropColor(bg.r, bg.g, bg.b, bg.a or 1)
        panel:SetBackdropBorderColor(brd.r, brd.g, brd.b, brd.a or 1)
    end

    local function MakeLabel(text)
        local fs = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        if Addon.THEME then
            local h = Addon.THEME.header
            fs:SetTextColor(h.r, h.g, h.b, h.a or 1)
        end
        fs:SetText(text)
        return fs
    end

    local function StyleBtn(btn)
        if Addon._styleActionButton then Addon._styleActionButton(btn) end
    end

    -- ── UI Scale ────────────────────────────────────────────────────────────
    local scaleTitle = MakeLabel("")
    scaleTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -PAD)
    self._blizzOptScaleTitleFS = scaleTitle

    local scaleSlider = CreateFrame("Slider", "LariasWeeklyChecklistScaleSlider", panel, "OptionsSliderTemplate")
    scaleSlider:SetPoint("TOPLEFT", scaleTitle, "BOTTOMLEFT", 6, -6)
    scaleSlider:SetWidth(220)
    scaleSlider:SetMinMaxValues(80, 120)
    scaleSlider:SetValueStep(1)
    do
        local lo  = _G["LariasWeeklyChecklistScaleSliderLow"]
        local hi  = _G["LariasWeeklyChecklistScaleSliderHigh"]
        local txt = _G["LariasWeeklyChecklistScaleSliderText"]
        if lo  then lo:SetText("80%")  end
        if hi  then hi:SetText("120%") end
        if txt then txt:SetText("")    end
    end
    local function ApplyScale(val)
        val = math.floor(val + 0.5)
        local gdb = Addon.db and Addon.db.global
        if gdb then gdb.uiScalePct = val end
        if Addon._blizzOptScaleTitleFS then
            local L2 = Addon.L or {}
            Addon._blizzOptScaleTitleFS:SetText((L2.UI_SCALE_LABEL or "UI Scale") .. ": " .. val .. "%")
        end
        if Addon.ApplyUIScale then Addon:ApplyUIScale() end
    end
    scaleSlider:SetScript("OnValueChanged", function(self_, val)
        val = math.floor(val + 0.5)
        if Addon._blizzOptScaleTitleFS then
            local L2 = Addon.L or {}
            Addon._blizzOptScaleTitleFS:SetText((L2.UI_SCALE_LABEL or "UI Scale") .. ": " .. val .. "%")
        end
    end)
    scaleSlider:SetScript("OnMouseUp", function(self_) ApplyScale(self_:GetValue()) end)
    self._blizzOptScaleSlider = scaleSlider

    -- ── Hidden Characters ────────────────────────────────────────────────────
    local hiddenTitle = MakeLabel("")
    hiddenTitle:SetPoint("TOPLEFT", scaleSlider, "BOTTOMLEFT", -6, -20)
    self._blizzOptHiddenCharsTitle = hiddenTitle

    local hiddenTrigger = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    hiddenTrigger:SetPoint("TOPLEFT", hiddenTitle, "BOTTOMLEFT", 0, -4)
    hiddenTrigger:SetSize(160, 22)
    StyleBtn(hiddenTrigger)
    hiddenTrigger:SetScript("OnClick", function()
        if Addon.ToggleHiddenCharsDropdown then Addon:ToggleHiddenCharsDropdown() end
    end)
    self._blizzOptHiddenCharsTrigger = hiddenTrigger

    -- ── Reset List button ────────────────────────────────────────────────────
    local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetBtn:SetPoint("TOPLEFT", hiddenTrigger, "BOTTOMLEFT", 0, -20)
    resetBtn:SetSize(120, 22)
    StyleBtn(resetBtn)
    resetBtn:SetScript("OnClick", function()
        local dbR = Addon:EnsureDB()
        if wipe then
            wipe(dbR.checked)
            wipe(dbR.collapsedSections)
        else
            dbR.checked = {}
            dbR.collapsedSections = {}
        end
        dbR.hideCompletedSections = true
        dbR.startAtSectionId      = ""
        dbR.showGreatVault        = true
        dbR.showCurrency          = true
        dbR.showChangeWeekBtn     = true
        dbR.showIlvlRefBtn        = true

        local gdb = Addon.db and Addon.db.global
        if gdb then
            gdb.mainFramePos  = nil
            gdb.mainFrameSize = nil
            gdb.ilvlRefPos    = nil
            gdb.ilvlRefSize   = nil
            gdb.uiScalePct    = nil
        end

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
            if mf then iw:SetPoint("TOPLEFT", mf, "TOPRIGHT", 4, 0)
            else       iw:SetPoint("CENTER", UIParent, "CENTER", 260, 0) end
            iw:SetSize(iw._baseW or Addon.UI.frameW, iw._baseH or 540)
            if iw._ilvlReflow then iw._ilvlReflow() end
        end

        if Addon.LayoutHeaderButtons    then Addon:LayoutHeaderButtons() end
        if Addon.SyncOptionsTabControls then Addon:SyncOptionsTabControls() end
        if Addon.SyncBlizzOptionsPanel  then Addon:SyncBlizzOptionsPanel() end
        if Addon.RequestRefresh then Addon:RequestRefresh() else Addon:Refresh() end
    end)
    self._blizzOptResetBtn = resetBtn

    -- Initial label sync.
    self:SyncBlizzOptionsPanel()
end

-- Syncs all values/labels on the Blizzard options panel to current DB state.
function Addon:SyncBlizzOptionsPanel()
    if not self._blizzOptScaleSlider then return end  -- not yet initialized
    local L   = self.L or {}
    local gdb = self.db and self.db.global
    local pct = (gdb and tonumber(gdb.uiScalePct)) or 100

    self._blizzOptScaleSlider:SetValue(math.max(80, math.min(120, pct)))
    if self._blizzOptScaleTitleFS then
        self._blizzOptScaleTitleFS:SetText((L.UI_SCALE_LABEL or "UI Scale") .. ": " .. pct .. "%")
    end
    if self._blizzOptHiddenCharsTitle then
        self._blizzOptHiddenCharsTitle:SetText(L.OPTIONS_HIDDEN_CHARS_TITLE or "Hidden characters:")
    end
    if self._blizzOptResetBtn then
        self._blizzOptResetBtn:SetText(L.RESET_BUTTON or "Reset List")
    end
    if self.RefreshHiddenCharsList then self:RefreshHiddenCharsList() end
end

-- Creates and registers the Blizzard Interface Options panel (once).
-- Must be called early (e.g. OnInitialize) so the panel appears in the AddOns list.
function Addon:CreateBlizzOptionsPanel()
    if self._blizzOptPanel then return self._blizzOptPanel end

    local panelName = (self.L and self.L.DISPLAY_NAME) or addonName

    local panel = CreateFrame("Frame")
    panel.name  = panelName

    local initialized = false
    panel:SetScript("OnShow", function()
        if not initialized then
            initialized = true
            Addon:InitBlizzOptionsPanel(panel)
        end
        Addon:SyncBlizzOptionsPanel()
    end)

    -- Modern API (10.x / 11.x / 12.x): RegisterCanvasLayoutCategory returns a
    -- category object that must then be passed to RegisterAddOnCategory.
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panelName)
        Settings.RegisterAddOnCategory(category)
        self._blizzOptCategory = category
    elseif InterfaceOptions_AddCategory then
        -- Legacy fallback (pre-10.x).
        InterfaceOptions_AddCategory(panel)
    end

    self._blizzOptPanel = panel
    return panel
end

-- ---------------------------------------------------------------------------
-- Gear popup: small floating panel with the 6 display toggles.
-- Anchors below the gear button, styled like the other dropdowns.
-- ---------------------------------------------------------------------------

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
        catcher:SetScript("OnClick", function() p:Hide() end)
        p:SetScript("OnHide", function() catcher:Hide() end)
        p:SetScript("OnShow", function()
            catcher:Show()
            if UIFrameFadeIn then UIFrameFadeIn(p, 0.12, 0, 1)
            else p:SetAlpha(1) end
        end)

        -- Build the 6 checkboxes.
        local PAD    = 10
        local ROW_H  = 26   -- UICheckButtonTemplate default height
        local checks = {
            { key = "_cbHideCompleted",  },
            { key = "_cbHideGreatVault", },
            { key = "_cbHideCurrency",   },
            { key = "_cbHideChangeWeek", },
            { key = "_cbHideIlvlRef",    },
            { key = "_cbHideCharPicker", },
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
        }

        local N      = #checks
        local TILE_H = ROW_H + 8          -- height of each equal slice
        local totalH = N * TILE_H
        p:SetHeight(totalH)

        for i, info in ipairs(checks) do
            -- Each tile occupies an equal vertical slice of the popup.
            local tileTopY = -((i - 1) * TILE_H)
            local cbOffY   = tileTopY - math.floor((TILE_H - ROW_H) / 2)

            local cb = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
            cb:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, cbOffY)
            StyleCheckButton(cb)
            local _key = info.key
            local function FireToggle(newState)
                callbacks[_key](newState)
                if Addon.SyncOptionsTabControls then Addon:SyncOptionsTabControls() end
            end
            cb:SetScript("OnClick", function(self_)
                FireToggle(self_:GetChecked() and true or false)
            end)
            p[info.key] = cb

            -- Hit region: full popup width × 1/N height, zero gaps.
            local hit = CreateFrame("Button", nil, p)
            hit:SetPoint("TOPLEFT",  p, "TOPLEFT",  0, tileTopY)
            hit:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, tileTopY)
            hit:SetHeight(TILE_H)
            hit:SetFrameLevel(p:GetFrameLevel())   -- below CheckButton (p+1)
            local hl = hit:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints(hit)
            hl:SetColorTexture(1, 1, 1, 0.06)
            hit:SetScript("OnClick", function()
                local newVal = not (cb:GetChecked() and true or false)
                cb:SetChecked(newVal)
                FireToggle(newVal)
            end)
        end

        -- No deferred resize needed; height is fixed from the tile formula.

        self._gearPopup = p
    end

    -- Sync current values and labels.
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