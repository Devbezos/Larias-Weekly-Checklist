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
    -- Don't open when nothing is hidden.
    local gdbT   = self.db and self.db.global
    local hidMap = gdbT and gdbT.hiddenChars or {}
    local anyHidden = false
    for _, v in pairs(hidMap) do if v then anyHidden = true; break end end
    if not anyHidden then return end

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
    -- Position below the trigger button (in the gear popup).
    local trigBtn = Addon._gearHiddenCharsTrigger
    picker:ClearAllPoints()
    if trigBtn then
        picker:SetPoint("TOPLEFT", trigBtn, "BOTTOMLEFT", 0, -4)
    else
        picker:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    -- Show first so IsShown() is true when RefreshHiddenCharsList checks it.
    picker:Show()
    self:RefreshHiddenCharsList()
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

    -- Update trigger button label (lives in the gear popup).
    local trigBtn = self._gearHiddenCharsTrigger
    if trigBtn and trigBtn.SetText then
        if #hidden == 0 then
            -- No hidden chars: plain label, no dropdown arrow, button disabled.
            trigBtn:SetText(string.format("%s (0)", L.OPTIONS_HIDDEN_CHARS_TITLE or "Hidden"))
            trigBtn:SetEnabled(false)
        else
            trigBtn:SetEnabled(true)
            local label = string.format("%s (%d) |TInterface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up:10:10|t", L.OPTIONS_HIDDEN_CHARS_TITLE or "Hidden", #hidden)
            trigBtn:SetText(label)
        end
    end

    -- If the dropdown isn't open, nothing else to do.
    local picker = self._hiddenCharsPicker
    if #hidden == 0 then
        -- Close the picker if it was left open and a char was just unhidden.
        if picker and picker.IsShown and picker:IsShown() then picker:Hide() end
        return
    end
    if not (picker and picker.IsShown and picker:IsShown()) then return end

    -- Release existing rows back to pool.
    for _, b in ipairs(picker._buttons) do
        b:Hide()
        b:ClearAllPoints()
        -- b is a plain Frame; clear scripts on the child button.
        if b._nameBtn then b._nameBtn:SetScript("OnClick", nil) end
        tinsert(picker._pool, b)
    end
    wipe(picker._buttons)

    local function AcquireRow()
        local f = tremove(picker._pool)
        if not f then
            f = CreateFrame("Frame", nil, picker)
            -- name button spans full row width
            local nb = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
            nb:SetHeight(ROW_H)
            nb:SetPoint("TOPLEFT",  f, "TOPLEFT",  0, 0)
            nb:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
            if Addon._styleActionButton then Addon._styleActionButton(nb) end
            -- StyleMainTabButton resets backdrop colors; re-apply theme after it runs.
            if nb.SetBackdrop then
                nb:SetBackdrop({
                    bgFile   = "Interface\\Buttons\\WHITE8x8",
                    edgeFile = "Interface\\Buttons\\WHITE8x8",
                    tile = false, edgeSize = 1,
                    insets = { left = 1, right = 1, top = 1, bottom = 1 },
                })
                if nb.SetBackdropColor then
                    nb:SetBackdropColor(Addon.THEME.bg.r, Addon.THEME.bg.g, Addon.THEME.bg.b, Addon.THEME.bg.a)
                end
                if nb.SetBackdropBorderColor then
                    nb:SetBackdropBorderColor(Addon.THEME.border.r, Addon.THEME.border.g, Addon.THEME.border.b, Addon.THEME.border.a)
                end
            end
            local ntr = nb.Text or (nb.GetFontString and nb:GetFontString())
            if ntr then
                if ntr.SetJustifyH then ntr:SetJustifyH("LEFT") end
                if ntr.SetJustifyV then ntr:SetJustifyV("MIDDLE") end
                if ntr.ClearAllPoints and ntr.SetPoint then
                    ntr:ClearAllPoints()
                    ntr:SetPoint("LEFT",  nb, "LEFT",  6, 0)
                    ntr:SetPoint("RIGHT", nb, "RIGHT", -4, 0)
                end
            end
            f._nameBtn = nb
        end
        f:Show()
        return f
    end

    local posY = -PAD
    for i, key in ipairs(hidden) do
        local charName    = (key:match("^(.-)%s*%-") or key):gsub("^%s+",""):gsub("%s+$","")
        local realm       = (key:match("%-(.+)$") or ""):gsub("^%s+",""):gsub("%s+$","")
        local displayText = (realm ~= "") and (charName .. " - " .. realm) or key

        local f = AcquireRow()
        f._nameBtn:SetEnabled(true)

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
        end
        f._nameBtn:SetScript("OnClick", doUnhide)

        -- Rows span the full picker width edge-to-edge.
        f:SetPoint("TOPLEFT",  picker, "TOPLEFT",  0, posY)
        f:SetPoint("TOPRIGHT", picker, "TOPRIGHT", 0, posY)
        f:SetHeight(ROW_H)
        posY = posY - ROW_H
        tinsert(picker._buttons, f)
    end

    local totalH = -posY + PAD
    picker:SetHeight(math.max(40, totalH))

    -- Deferred width sizing: measure text, resize picker, update nameBtn widths.
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
            local newW = math.max(120, math.min(400, math.ceil(bw) + PAD * 2 + 10))
            picker:SetWidth(newW)
        end)
    end
    -- Initial width.
    picker:SetWidth(NAME_W_MIN + PAD * 2 + 10)
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
        if Addon.ApplyUIScale           then Addon:ApplyUIScale() end
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

-- ── In-frame scale slider ──────────────────────────────────────────────────
-- A compact, custom-styled slider placed below the great vault / currency panel
-- inside the main addon frame.  Width is intentionally non-full-width so it
-- doesn't dominate the bottom of the frame.
function Addon:CreateInFrameScaleSlider(parentFrame)
    if self._inFrameScaleSlider then return end

    local THEME  = Addon.THEME   or {}
    local bdr    = THEME.border  or { r=0.30, g=0.30, b=0.30, a=0.90 }
    local txt    = THEME.text    or { r=1.00, g=1.00, b=1.00, a=1.00 }
    local txtD   = THEME.textDim or txt

    local MIN_V  = 80
    local MAX_V  = 120
    local STEP_V = 5

    -- Dimensions
    local TRACK_H  = 10      -- track bar height
    local THUMB_SZ = 16      -- square thumb side length
    local TRACK_W  = 110     -- usable track width
    local LBL_W    = 38      -- "Scale" label
    local PCT_W    = 36      -- "100%" readout
    local GAP      = 5
    local SLIDER_W = LBL_W + GAP + TRACK_W + GAP + PCT_W
    local SLIDER_H = math.max(THUMB_SZ, Addon.UI.sliderH or 20)

    -- Outer container
    local sf = CreateFrame("Frame", nil, parentFrame)
    sf:SetSize(SLIDER_W, SLIDER_H)
    sf:SetPoint("BOTTOMLEFT", parentFrame, "BOTTOMLEFT", Addon.UI.sectionInsetX or 14, Addon.UI.sliderBottomPad or 4)
    self._inFrameScaleSlider = sf

    -- "Scale" label
    local scaleLbl = sf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    scaleLbl:SetPoint("LEFT", sf, "LEFT", 0, 0)
    scaleLbl:SetWidth(LBL_W)
    scaleLbl:SetJustifyH("RIGHT")
    scaleLbl:SetTextColor(txt.r, txt.g, txt.b, txt.a)
    scaleLbl:SetText("Scale")

    -- Track container (mouse receiver + clipping context)
    local trackCont = CreateFrame("Frame", nil, sf)
    trackCont:SetSize(TRACK_W, SLIDER_H)
    trackCont:SetPoint("LEFT", scaleLbl, "RIGHT", GAP, 0)

    -- Track bar (thin rectangle centred vertically)
    local trackBar = trackCont:CreateTexture(nil, "BACKGROUND")
    trackBar:SetHeight(TRACK_H)
    trackBar:SetPoint("LEFT",  trackCont, "LEFT",  0, 0)
    trackBar:SetPoint("RIGHT", trackCont, "RIGHT", 0, 0)
    trackBar:SetColorTexture(bdr.r, bdr.g, bdr.b, 0.7)

    -- Square white thumb (purely visual – mouse handled by trackCont)
    local thumb = CreateFrame("Frame", nil, trackCont)
    thumb:SetSize(THUMB_SZ, THUMB_SZ)
    thumb:SetFrameLevel(trackCont:GetFrameLevel() + 1)
    local thumbTex = thumb:CreateTexture(nil, "ARTWORK")
    thumbTex:SetAllPoints(thumb)
    thumbTex:SetColorTexture(txt.r, txt.g, txt.b, 0.9)

    -- Percentage readout
    local pctLbl = sf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pctLbl:SetPoint("LEFT", trackCont, "RIGHT", GAP, 0)
    pctLbl:SetWidth(PCT_W)
    pctLbl:SetJustifyH("LEFT")
    pctLbl:SetTextColor(txtD.r, txtD.g, txtD.b, txtD.a)

    -- ── Logic ─────────────────────────────────────────────────────────────

    local USABLE = TRACK_W - THUMB_SZ

    local function GetCurrentPct()
        local gdb = Addon.db and Addon.db.global
        return (gdb and tonumber(gdb.uiScalePct)) or 100
    end

    local function UpdateVisuals(pct)
        pct = math.max(MIN_V, math.min(MAX_V, pct))
        local frac = (pct - MIN_V) / (MAX_V - MIN_V)
        local offX = math.floor(frac * USABLE)
        thumb:ClearAllPoints()
        thumb:SetPoint("LEFT", trackCont, "LEFT", offX, 0)
        pctLbl:SetText(math.floor(pct + 0.5) .. "%")
    end

    local function SetPct(pct)
        pct = math.max(MIN_V, math.min(MAX_V, pct))
        pct = math.floor((pct + STEP_V / 2) / STEP_V) * STEP_V
        local gdb = Addon.db and Addon.db.global
        if gdb then gdb.uiScalePct = pct end
        UpdateVisuals(pct)
        if Addon.ApplyUIScale then Addon:ApplyUIScale() end
    end

    sf.Sync = function() UpdateVisuals(GetCurrentPct()) end

    -- Divide cursor by the frame's OWN effective scale to get coordinates in
    -- the same space as GetLeft() / GetWidth().  Using UIParent:GetEffectiveScale()
    -- alone is wrong whenever the main frame has SetScale() applied.
    local function PctFromCursor()
        local scale = trackCont:GetEffectiveScale()
        local cx    = GetCursorPosition() / scale
        local left  = trackCont:GetLeft()
        if not left then return nil end
        local frac  = (cx - left) / TRACK_W
        return MIN_V + math.max(0, math.min(1, frac)) * (MAX_V - MIN_V)
    end

    -- All mouse interaction through trackCont so extremes are never blocked.
    trackCont:EnableMouse(true)
    trackCont:SetScript("OnMouseDown", function(self_, btn)
        if btn ~= "LeftButton" then return end
        self_._dragging = true
        local pct = PctFromCursor()
        if pct then UpdateVisuals(pct) end
    end)
    trackCont:SetScript("OnMouseUp", function(self_, btn)
        if btn ~= "LeftButton" then return end
        self_._dragging = false
        local pct = PctFromCursor()
        if pct then SetPct(pct) end
    end)
    trackCont:SetScript("OnUpdate", function(self_)
        if not self_._dragging then return end
        local pct = PctFromCursor()
        if pct then UpdateVisuals(pct) end
    end)

    sf:SetScript("OnShow", function() UpdateVisuals(GetCurrentPct()) end)
    UpdateVisuals(GetCurrentPct())
end

-- CreateBlizzOptionsPanel: no longer registers with Blizzard Interface → AddOns.
-- Options are now accessed via the gear icon / minimap right-click (gear popup).
function Addon:CreateBlizzOptionsPanel()
    -- Intentionally a no-op; kept so call-sites don't error.
end