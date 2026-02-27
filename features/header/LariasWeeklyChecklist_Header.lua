-- Header module: close/gear/change-week/ilvl-ref buttons, week-picker popup.
-- Exposes Addon:CreateHeader(frame) called from Addon:CreateFrame().
local addonName = ...
local Addon = _G[addonName]
if not Addon then return end

-- ── Picker layout constants ───────────────────────────────────────────────────
local PICKER_PAD        = 8   -- padding inside the picker frame (px)
local PICKER_ROW_HEIGHT = 24  -- height of each week-row button (px)
local PICKER_ROW_WIDTH  = 160 -- initial button width; deferred resize will widen to fit

-- Strips the "current week" indicator prefix and returns only the date range
-- portion before the first hyphen separator (e.g. "Jan 1" from "Jan 1 - Jan 7").
-- Pure function: no upvalue dependencies, safe to call from any scope.
local function ExtractMonthRangeLabel(label)
    label = tostring(label or "")
    local s = label:gsub("^%s*>%s*", ""):gsub("^%s+", "")
    if s == "" then return label end
    local hyphenA = s:find("%s%-%s") or s:find("%-")
    if not hyphenA then return s end
    local out = s:sub(1, hyphenA - 1):gsub("%s+$", "")
    return out ~= "" and out or s
end

-- Sets the text colour on a picker row button. Defined once at module scope
-- rather than as an anonymous closure per button to avoid extra allocations.
local function SetPickerButtonTextColor(btn, color)
    local tr = btn.Text or (btn.GetFontString and btn:GetFontString())
    if tr and tr.SetTextColor and color then
        tr:SetTextColor(color.r, color.g, color.b, color.a or 1)
    end
end

-- ── Addon:CreateHeader ────────────────────────────────────────────────────────
-- Creates all header chrome (close/gear/change-week/ilvl-ref/char-picker),
-- defines the week-picker popup, and wires LayoutHeaderButtons_.
-- Must be called from Addon:CreateFrame() after the main frame is constructed
-- but before the scroll frame is created.
-- Scroll-event hooks are registered via Addon._wireScrollHeaderHooks(sf) which
-- must be called immediately after the scroll frame is created.
function Addon:CreateHeader(frame)
    local L = self.L or {}
    local C = Addon.Controls

    -- ── Close button ─────────────────────────────────────────────────────────
    local closeBtn = C.NewCloseButton(frame, function() frame:Hide() end)
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -Addon.UI.closeInset, -Addon.UI.closeInset)
    frame._lariasCloseBtn = closeBtn

    -- ── Gear / settings button ────────────────────────────────────────────────
    local gearBtn = C.NewIconButton(frame, "Interface\\Buttons\\UI-OptionsButton", nil, L.TAB_OPTIONS or "Options")
    gearBtn:SetPoint("RIGHT", closeBtn, "LEFT", -2, 0)
    gearBtn:SetScript("OnClick", function()
        if Addon.ToggleGearPopup then Addon:ToggleGearPopup(gearBtn, true) end
    end)
    frame._lariasGearBtn = gearBtn

    -- ── StyleMainTabButton ────────────────────────────────────────────────────
    local function StyleMainTabButton(tabButton)
        if not tabButton then return end
        Addon:ApplyTheme(tabButton)
        if tabButton.SetBackdropColor then
            tabButton:SetBackdropColor(Addon.THEME.bg.r, Addon.THEME.bg.g, Addon.THEME.bg.b,
                math.max(0, (tonumber(Addon.THEME.bg.a) or 1) - 0.28))
        end
        local function ClearAndHideTexture(texture)
            if not texture then return end
            if texture.SetTexture then texture:SetTexture(nil) end
            if texture.SetAlpha   then texture:SetAlpha(0) end
            if texture.Hide       then texture:Hide() end
        end
        if tabButton.GetNormalTexture   then ClearAndHideTexture(tabButton:GetNormalTexture())   end
        if tabButton.GetPushedTexture   then ClearAndHideTexture(tabButton:GetPushedTexture())   end
        if tabButton.GetDisabledTexture then ClearAndHideTexture(tabButton:GetDisabledTexture()) end
        if tabButton.GetHighlightTexture then ClearAndHideTexture(tabButton:GetHighlightTexture()) end
        if tabButton.Left   and tabButton.Left.Hide   then tabButton.Left:Hide()   end
        if tabButton.Middle and tabButton.Middle.Hide then tabButton.Middle:Hide() end
        if tabButton.Right  and tabButton.Right.Hide  then tabButton.Right:Hide()  end
        if tabButton.SetTextInsets then tabButton:SetTextInsets(12, 12, 4, 4) end
        local textRegion = tabButton.Text or (tabButton.GetFontString and tabButton:GetFontString())
        if textRegion then
            if textRegion.SetJustifyV       then textRegion:SetJustifyV("MIDDLE") end
            if textRegion.ClearAllPoints and textRegion.SetPoint then
                textRegion:ClearAllPoints()
                textRegion:SetPoint("CENTER", tabButton, "CENTER", 0, 0)
            end
            if textRegion.SetTextColor then textRegion:SetTextColor(1, 1, 1, 1) end
        end
        if tabButton.CreateTexture and not tabButton._lariasCustomHighlight then
            local highlight = tabButton:CreateTexture(nil, "HIGHLIGHT")
            highlight:SetAllPoints(tabButton)
            highlight:SetColorTexture(Addon.THEME.text.r, Addon.THEME.text.g, Addon.THEME.text.b, 0.06)
            tabButton._lariasCustomHighlight = highlight
        end
        tabButton._lariasTabStyled = true
    end
    Addon._styleActionButton = StyleMainTabButton

    -- ── Lazy header button locals ─────────────────────────────────────────────
    local changeWeekBtn
    local ilvlRefBtn

    -- ── Char-picker init ──────────────────────────────────────────────────────
    if Addon.InitCharPickerUI then
        Addon:InitCharPickerUI(frame, StyleMainTabButton)
    end

    local function EnsureCharPickerBtn_()
        if Addon._cpEnsureBtn then return Addon._cpEnsureBtn() end
    end

    -- ── EnsureChangeWeekBtn_ ──────────────────────────────────────────────────
    local function EnsureChangeWeekBtn_()
        if changeWeekBtn then return changeWeekBtn end
        local btn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        btn:SetSize(108, 22)
        StyleMainTabButton(btn)
        local _fs = btn.GetFontString and btn:GetFontString()
        if _fs and _fs.SetJustifyH then _fs:SetJustifyH("CENTER") end
        if btn.SetTextInsets then btn:SetTextInsets(12, 22, 4, 4) end
        local arrowTex = btn:CreateTexture(nil, "ARTWORK")
        arrowTex:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
        arrowTex:SetSize(14, 14)
        arrowTex:SetPoint("RIGHT", btn, "RIGHT", -5, 0)
        arrowTex:SetVertexColor(1, 1, 1, 0.85)
        btn._lariasArrowTex        = arrowTex
        changeWeekBtn              = btn
        frame._lariasChangeWeekBtn = btn
        return btn
    end

    -- ── EnsureIlvlRefBtn_ ────────────────────────────────────────────────────
    local function EnsureIlvlRefBtn_()
        if ilvlRefBtn then return ilvlRefBtn end
        local btn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        btn:SetSize(140, 22)
        StyleMainTabButton(btn)
        btn:SetText(L.ILVLREF_BUTTON or "View Item Levels")
        btn:SetScript("OnClick", function() Addon:ToggleIlvlRefWindow() end)
        ilvlRefBtn              = btn
        frame._lariasIlvlRefBtn = btn
        return btn
    end

    -- ── Header picker (week selector popup) ──────────────────────────────────
    local function EnsureHeaderPicker()
        if frame._lariasHeaderPicker then return frame._lariasHeaderPicker end
        local picker = Addon.Controls.NewPopupPanel("HIGH", 0.15)
        picker._buttons    = {}
        picker._buttonPool = {}
        frame._lariasHeaderPicker = picker
        return picker
    end

    local function ReleasePickerButtons(picker)
        if not (picker and picker._buttons and picker._buttonPool) then return end
        for i = #picker._buttons, 1, -1 do
            local btn = picker._buttons[i]
            picker._buttons[i] = nil
            if btn then
                btn:Hide()
                btn:ClearAllPoints()
                btn:SetScript("OnClick",  nil)
                btn:SetScript("OnEnter", nil)
                btn:SetScript("OnLeave", nil)
                tinsert(picker._buttonPool, btn)
            end
        end
    end

    local function AcquirePickerButton(picker)
        local btn = tremove(picker._buttonPool)
        if not btn then
            btn = CreateFrame("Button", nil, picker, "UIPanelButtonTemplate")
            btn:SetFrameStrata("HIGH")
            StyleMainTabButton(btn)
            if btn.SetTextInsets then btn:SetTextInsets(10, 10, 0, 0) end
            local tr = btn.Text or (btn.GetFontString and btn:GetFontString())
            if tr then
                if tr.SetJustifyH then tr:SetJustifyH("LEFT") end
                if tr.SetJustifyV then tr:SetJustifyV("MIDDLE") end
            end
        end
        if picker.GetFrameLevel and btn.SetFrameLevel then
            btn:SetFrameLevel((tonumber(picker:GetFrameLevel()) or 200) + 1)
        end
        if btn.Enable      then btn:Enable() end
        if btn.EnableMouse then btn:EnableMouse(true) end
        btn:Show()
        SetPickerButtonTextColor(btn, Addon.THEME.text)
        btn:SetScript("OnEnter", function() SetPickerButtonTextColor(btn, Addon.THEME.header) end)
        btn:SetScript("OnLeave", function() SetPickerButtonTextColor(btn, Addon.THEME.text) end)
        return btn
    end

    -- ── HandlePick ───────────────────────────────────────────────────────────
    local function HandlePick(sectionId, sf)
        local db       = Addon:EnsureDB()
        local picker   = EnsureHeaderPicker()
        local order    = Addon._order or {}
        local oldStart = tostring(db.startAtSectionId or "")
        local newStart = tostring(sectionId or "")

        local oldIdx, newIdx = 0, 0
        for i = 1, #order do
            if order[i] == oldStart then oldIdx = i end
            if order[i] == newStart then newIdx = i end
        end

        if oldIdx == 0 and #order > 0 then oldIdx = 1 end

        if newIdx > oldIdx then
            if type(db.checked)          ~= "table" then db.checked          = {} end
            if type(db.collapsedSections) ~= "table" then db.collapsedSections = {} end
            for i = oldIdx, newIdx - 1 do
                local secId  = order[i]
                local secDef = Addon._sectionsById and Addon._sectionsById[secId]
                local items  = secDef and secDef.items or {}
                for _, item in ipairs(items) do
                    db.checked[secId .. ":" .. tostring(item.id)] = true
                end
                db.collapsedSections[secId] = true
            end
        elseif newIdx <= oldIdx then
            local checked   = type(db.checked)          == "table" and db.checked          or nil
            local collapsed = type(db.collapsedSections) == "table" and db.collapsedSections or nil
            local fromIdx   = (newIdx == 0 and 1 or newIdx)
            for i = fromIdx, oldIdx do
                local secId  = order[i]
                local secDef = Addon._sectionsById and Addon._sectionsById[secId]
                local items  = secDef and secDef.items or {}
                if checked then
                    for _, item in ipairs(items) do
                        checked[secId .. ":" .. tostring(item.id)] = nil
                    end
                end
                if collapsed then collapsed[secId] = nil end
            end
        end

        db.startAtSectionId = newStart

        if picker and picker.Hide then picker:Hide() end
        if sf and sf.SetVerticalScroll then sf:SetVerticalScroll(0) end
        if Addon.SelectMainTab then Addon:SelectMainTab(1) end
        if Addon.RequestRefresh then
            Addon:RequestRefresh()
        elseif Addon.Refresh then
            Addon:Refresh()
        end
    end

    -- ── PopulateHeaderPicker ─────────────────────────────────────────────────
    local function PopulateHeaderPicker()
        local picker = EnsureHeaderPicker()
        ReleasePickerButtons(picker)

        local data = Addon.GetListData and Addon:GetListData() or {}
        local posY = -PICKER_PAD

        local db0         = Addon:EnsureDB()
        local storedStart = tostring(db0.startAtSectionId or "")
        local currentId
        if storedStart ~= "" then
            currentId = storedStart
        else
            -- No explicit pick: find the last section that has at least one checked item.
            -- This keeps the ">" marker on the week the user was most recently working on
            -- rather than jumping forward to the next incomplete week the moment the current
            -- one is fully done (which would feel premature before the Tuesday reset).
            local order = Addon._order or {}
            local lastActiveId = nil
            for i = 1, #order do
                if Addon._HasAnySectionItemChecked and Addon._HasAnySectionItemChecked(order[i], db0) then
                    lastActiveId = tostring(order[i])
                end
            end
            if lastActiveId then
                currentId = lastActiveId
            elseif Addon._order and Addon._order[1] then
                -- Nothing checked yet: default to the first section.
                currentId = tostring(Addon._order[1])
            end
        end

        if type(data) == "table" then
            for i = 1, #data do
                local section = data[i]
                if type(section) == "table" then
                    local id        = section.id
                    local isCurrent = (tostring(id or "") == currentId)
                    local label     = ExtractMonthRangeLabel(section.title or id or "")
                    if label == "" then label = tostring(id or i) end
                    if isCurrent then label = "> " .. label end

                    local btn = AcquirePickerButton(picker)
                    btn:ClearAllPoints()
                    btn:SetPoint("TOPLEFT", picker, "TOPLEFT", PICKER_PAD, posY)
                    btn:SetHeight(PICKER_ROW_HEIGHT)
                    btn:SetText(label)
                    btn:SetEnabled(true)
                    local capturedId = id
                    btn:SetScript("OnClick", function()
                        HandlePick(capturedId, Addon._scrollFrame)
                    end)

                    if isCurrent then
                        SetPickerButtonTextColor(btn, Addon.THEME.textDim or Addon.THEME.text)
                        btn:SetScript("OnEnter", function()
                            SetPickerButtonTextColor(btn, Addon.THEME.header)
                        end)
                        btn:SetScript("OnLeave", function()
                            SetPickerButtonTextColor(btn, Addon.THEME.textDim or Addon.THEME.text)
                        end)
                    end

                    tinsert(picker._buttons, btn)
                    posY = posY - PICKER_ROW_HEIGHT
                end
            end
        end

        local totalH = -posY + PICKER_PAD
        picker:SetHeight(math.max(40, totalH))

        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                if not (picker and picker.IsShown and picker:IsShown()) then return end
                local bestW = 120
                for _, b in ipairs(picker._buttons) do
                    local tr = b.Text or (b.GetFontString and b:GetFontString())
                    local w
                    if tr then
                        if tr.GetUnboundedStringWidth then
                            w = tonumber(tr:GetUnboundedStringWidth())
                        elseif tr.GetStringWidth then
                            w = tonumber(tr:GetStringWidth())
                        end
                    end
                    if (not w or w <= 0) and b.GetTextWidth then
                        w = tonumber(b:GetTextWidth())
                    end
                    if w and w > bestW then bestW = w end
                end
                local newW = math.max(160, math.min(520, math.ceil(bestW + PICKER_PAD * 4 + 24)))
                picker:SetWidth(newW)
                for _, b in ipairs(picker._buttons) do
                    if b.SetWidth then b:SetWidth(newW - PICKER_PAD * 2) end
                end
            end)
        end

        for _, b in ipairs(picker._buttons) do
            if b.SetWidth then b:SetWidth(PICKER_ROW_WIDTH) end
        end
    end

    Addon._PopulateHeaderPicker = PopulateHeaderPicker

    -- ── LayoutHeaderButtons_ ─────────────────────────────────────────────────
    local function LayoutHeaderButtons_()
        if Addon._inLayoutHeaderButtons then return end
        Addon._inLayoutHeaderButtons = true
        local dbLocal = Addon:EnsureDB()
        local showCW  = dbLocal.showChangeWeekBtn ~= false
        local showIR  = dbLocal.showIlvlRefBtn    ~= false
        local showCP  = dbLocal.showCharPickerBtn ~= false
                    and (Addon.FEATURE_FLAGS and Addon.FEATURE_FLAGS.ENABLE_CHAR_SELECTOR) ~= false

        if showCP then
            if Addon.HasPickableChars then showCP = Addon:HasPickableChars() end
        end

        -- charPickerBtn is in the BOTTOM row; position it first.
        local cpBtn = EnsureCharPickerBtn_()
        if cpBtn then
            if showCP then
                cpBtn:SetScript("OnClick", function()
                    if Addon._cpOnClick then Addon._cpOnClick() end
                end)
                cpBtn:ClearAllPoints()
                local _cpBannerExtra = Addon._statusBanner
                    and ((Addon._statusBannerH or 14) + (Addon._statusBannerPad or 3))
                    or 0
                local _spf = Addon._inFrameScaleSlider
                local _cpY = (Addon.UI.sliderBottomPad or 4) + _cpBannerExtra
                if _spf and _spf.IsShown and _spf:IsShown() then
                    _cpY = _cpY + (_spf:GetHeight() or 36) + 4
                end
                cpBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT",
                    -(Addon.UI.sectionInsetX or 14), _cpY)
                if Addon._cpUpdateLabel then Addon._cpUpdateLabel() end
                cpBtn:Show()
                local sf = Addon._inFrameScaleSlider
                if sf and sf.AdjustForCpBtn then
                    if C_Timer and C_Timer.After then
                        C_Timer.After(0, function() sf.AdjustForCpBtn(cpBtn) end)
                    else
                        sf.AdjustForCpBtn(cpBtn)
                    end
                end
            else
                if Addon._viewingChar then
                    Addon._viewingChar = nil
                    if Addon._cpUpdateLabel  then Addon._cpUpdateLabel() end
                    if Addon.RequestRefresh  then Addon:RequestRefresh() else Addon:Refresh() end
                end
                cpBtn:Hide()
                local sf = Addon._inFrameScaleSlider
                if sf and sf.AdjustForCpBtn then
                    if C_Timer and C_Timer.After then
                        C_Timer.After(0, function() sf.AdjustForCpBtn(nil) end)
                    else
                        sf.AdjustForCpBtn(nil)
                    end
                end
            end
        end

        -- changeWeekBtn: top-left of the frame.
        if showCW then
            local btn = EnsureChangeWeekBtn_()
            local cwWeekLabel
            do
                local db0 = Addon:EnsureDB()
                local storedStart = tostring(db0.startAtSectionId or "")
                local currentId
                if storedStart ~= "" then
                    currentId = storedStart
                else
                    local order = Addon._order or {}
                    for i = 1, #order do
                        if Addon._IsSectionCompleteById and
                           not Addon._IsSectionCompleteById(order[i], db0) then
                            currentId = tostring(order[i])
                            break
                        end
                    end
                    if not currentId and Addon._order and Addon._order[1] then
                        currentId = tostring(Addon._order[1])
                    end
                end
                local section   = currentId and Addon._sectionsById and Addon._sectionsById[currentId]
                local extracted = ExtractMonthRangeLabel((section and section.title) or currentId or "")
                cwWeekLabel = (extracted ~= "") and extracted or (L.CHANGE_WEEK_BUTTON or "Change Week")
            end
            btn._lariasSelectedLabel = cwWeekLabel
            btn:SetText(cwWeekLabel)
            local cwTip = L.CHANGE_WEEK_BUTTON or "Change Week"
            btn:SetScript("OnEnter", function(self_)
                GameTooltip:SetOwner(self_, "ANCHOR_BOTTOMLEFT")
                GameTooltip:SetText(cwTip, 1, 1, 1, 1, true)
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            btn:SetScript("OnClick", function()
                local p = EnsureHeaderPicker()
                if p and p.IsShown and p:IsShown() then
                    p:Hide()
                    return
                end
                p:ClearAllPoints()
                p:SetPoint("TOPLEFT", changeWeekBtn, "BOTTOMLEFT", 0, -6)
                p:Show()
                if C_Timer and C_Timer.After then
                    C_Timer.After(0, PopulateHeaderPicker)
                else
                    PopulateHeaderPicker()
                end
            end)
            btn:ClearAllPoints()
            local cwInsetX = (Addon.UI.padOuterX or 14) + (Addon.UI.sectionInsetX or 14)
            btn:SetPoint("TOPLEFT", frame, "TOPLEFT", cwInsetX, -(Addon.UI.padOuterTop or 10) - 2)
            btn:Show()
        elseif changeWeekBtn then
            changeWeekBtn:Hide()
        end

        -- ilvlRefBtn: left of gearBtn.
        if showIR then
            local btn = EnsureIlvlRefBtn_()
            btn:ClearAllPoints()
            btn:SetPoint("TOPRIGHT", gearBtn, "TOPLEFT", -4, 0)
            btn:Show()
        elseif ilvlRefBtn then
            ilvlRefBtn:Hide()
            if Addon._ilvlRefWindow and Addon._ilvlRefWindow.IsShown and
               Addon._ilvlRefWindow:IsShown() then
                Addon._ilvlRefWindow:Hide()
            end
        end

        -- Enforce minimum frame width based on visible button footprint.
        local _insetX = (Addon.UI.padOuterX or 14) + (Addon.UI.sectionInsetX or 14)
        local _leftW  = _insetX + (showCW and (108 + 6) or 0)
        local _rightW = (Addon.UI.closeInset or 4) + 32 + 2 + 20
        if showIR then _rightW = _rightW + 4 + 140 end
        local _minW   = _leftW + 20 + _rightW
        local _absMinW = math.floor(Addon.UI.frameW * 0.8)
        _minW = math.max(_minW, _absMinW)
        local currentW = frame:GetWidth()
        if currentW < _minW then
            frame:SetWidth(_minW)
            local _gdb = Addon.db and Addon.db.global
            if _gdb and _gdb.mainFrameSize then _gdb.mainFrameSize.w = _minW end
        end

        Addon._inLayoutHeaderButtons = nil
    end  -- LayoutHeaderButtons_

    Addon.LayoutHeaderButtons = function(self_) LayoutHeaderButtons_() end
    LayoutHeaderButtons_()

    -- ── RefreshChangeWeekLabel_ ───────────────────────────────────────────────
    -- Updates the change-week button label to reflect whichever section is
    -- currently visible in the scroll viewport. Exposed via Addon for use by
    -- Refresh / scroll hooks once the scroll frame exists.
    local function RefreshChangeWeekLabel_()
        local btn = changeWeekBtn
        if not (btn and btn.IsShown and btn:IsShown()) then return end

        local sf       = Addon._scrollFrame
        local sections = Addon._activeSections or {}

        -- Priority: at the very bottom → show the last section.
        if sf and sf.GetVerticalScroll and sf.GetVerticalScrollRange then
            local scrollOffset = sf:GetVerticalScroll() or 0
            local scrollRange  = sf:GetVerticalScrollRange() or 0
            if scrollRange > 0 and scrollOffset >= scrollRange - 1 then
                local lastId = nil
                for i = 1, #sections do
                    local s = sections[i]
                    if s and s.IsShown and s:IsShown() and s._sectionId then
                        lastId = s._sectionId
                    end
                end
                if lastId then
                    local section   = Addon._sectionsById and Addon._sectionsById[tostring(lastId)]
                    local extracted = ExtractMonthRangeLabel((section and section.title) or tostring(lastId))
                    local label     = (extracted ~= "") and extracted or (L.CHANGE_WEEK_BUTTON or "Change Week")
                    btn:SetText(label)
                    return
                end
            end
        end

        -- Normal scroll: first section whose top is at or below the viewport top.
        local sfViewTop = sf and sf.GetTop and sf:GetTop()
        if sfViewTop then
            for i = 1, #sections do
                local s = sections[i]
                if s and s.IsShown and s:IsShown() and s._sectionId then
                    local top = s:GetTop()
                    if top and top <= sfViewTop + 1 then
                        local section   = Addon._sectionsById and Addon._sectionsById[tostring(s._sectionId)]
                        local extracted = ExtractMonthRangeLabel((section and section.title) or tostring(s._sectionId))
                        local label     = (extracted ~= "") and extracted or (L.CHANGE_WEEK_BUTTON or "Change Week")
                        btn:SetText(label)
                        return
                    end
                end
            end
        end

        if btn._lariasSelectedLabel then btn:SetText(btn._lariasSelectedLabel) end
    end

    -- ── CalcChangeWeekBtnWidth_ ───────────────────────────────────────────────
    local function CalcChangeWeekBtnWidth_()
        local btn = changeWeekBtn
        if not (btn and frame) then return end
        local order = Addon._order or {}
        if #order == 0 then return end

        if not btn._lariasMeasureFS then
            local scratch = frame:CreateFontString(nil, "ARTWORK")
            scratch:Hide()
            local bfs = btn.GetFontString and btn:GetFontString()
            if bfs then
                local fontPath, fontH, fontFlags = bfs:GetFont()
                if fontPath then
                    scratch:SetFont(fontPath, fontH or 12, fontFlags or "")
                else
                    scratch:SetFontObject(GameFontNormal)
                end
            else
                scratch:SetFontObject(GameFontNormal)
            end
            btn._lariasMeasureFS = scratch
        end
        local scratch      = btn._lariasMeasureFS
        local sectionsById = Addon._sectionsById or {}
        local maxW         = 108
        local PAD          = 34
        for i = 1, #order do
            local sec       = sectionsById[tostring(order[i])]
            local extracted = ExtractMonthRangeLabel((sec and sec.title) or tostring(order[i] or ""))
            local label     = (extracted ~= "") and extracted or (L.CHANGE_WEEK_BUTTON or "Change Week")
            scratch:SetText(label)
            local w = 0
            if scratch.GetUnboundedStringWidth then
                w = tonumber(scratch:GetUnboundedStringWidth()) or 0
            end
            if w <= 0 and scratch.GetStringWidth then
                w = tonumber(scratch:GetStringWidth()) or 0
            end
            maxW = math.max(maxW, math.ceil(w) + PAD)
        end
        btn:SetWidth(maxW)
    end

    Addon._refreshChangeWeekLabel = RefreshChangeWeekLabel_
    Addon._calcChangeWeekBtnWidth = CalcChangeWeekBtnWidth_

    -- ── Scroll-hook wiring ────────────────────────────────────────────────────
    -- Called by CreateFrame immediately after the scroll frame is created so
    -- scroll events keep the change-week button label in sync.
    Addon._wireScrollHeaderHooks = function(sf)
        local _sb = sf.ScrollBar
        if _sb and _sb.HookScript then
            _sb:HookScript("OnValueChanged", function() RefreshChangeWeekLabel_() end)
        end
        if sf.HookScript then
            sf:HookScript("OnScrollRangeChanged", function() RefreshChangeWeekLabel_() end)
            sf:HookScript("OnVerticalScroll",     function() RefreshChangeWeekLabel_() end)
        end
        Addon._wireScrollHeaderHooks = nil  -- one-shot
    end
end
