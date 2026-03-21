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
    -- Delegates to the shared Controls.StyleButton so there is one implementation.
    local StyleMainTabButton = Addon.Controls.StyleButton
    Addon._styleActionButton = StyleMainTabButton

    -- ── Lazy header button locals ─────────────────────────────────────────────
    local changeWeekBtn
    local ilvlRefBtn

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
        -- Keep the change-week button arrow in sync with panel open/close state.
        local function SyncArrow()
            local btn = changeWeekBtn
            if not (btn and btn._lariasArrowTex) then return end
            local open = picker.IsShown and picker:IsShown()
            btn._lariasArrowTex:SetTexture(open
                and "Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up"
                or  "Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
        end
        picker:HookScript("OnShow", SyncArrow)
        picker:HookScript("OnHide", SyncArrow)
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
        local newStart = tostring(sectionId or "")

        -- Resolve the "current" position using the same logic as PopulateHeaderPicker
        -- and LayoutHeaderButtons_: prefer the stored pin, but if it's empty or its
        -- week is now complete, fall back to the first incomplete week.
        local rawStored = tostring(db.startAtSectionId or "")
        local oldStart
        if rawStored ~= "" and not (Addon._IsSectionCompleteById and
                Addon._IsSectionCompleteById(rawStored, db)) then
            oldStart = rawStored
        else
            -- First incomplete week (same as the ">" marker in the picker).
            for i = 1, #order do
                if Addon._IsSectionCompleteById and
                   not Addon._IsSectionCompleteById(order[i], db) then
                    oldStart = tostring(order[i])
                    break
                end
            end
            if not oldStart and order[1] then oldStart = tostring(order[1]) end
        end
        oldStart = oldStart or ""

        local oldIdx, newIdx = 0, 0
        for i = 1, #order do
            if order[i] == oldStart then oldIdx = i end
            if order[i] == newStart then newIdx = i end
        end

        if oldIdx == 0 and #order > 0 then oldIdx = 1 end

        if newIdx > oldIdx then
            if type(db.checked)          ~= "table" then db.checked          = {} end
            if type(db.collapsedSections) ~= "table" then db.collapsedSections = {} end
            if type(db.sectionCompleted)  ~= "table" then db.sectionCompleted  = {} end
            for i = oldIdx, newIdx - 1 do
                local secId  = order[i]
                local secDef = Addon._sectionsById and Addon._sectionsById[secId]
                local items  = secDef and secDef.items or {}
                for _, item in ipairs(items) do
                    db.checked[secId .. ":" .. tostring(item.id)] = true
                end
                db.collapsedSections[secId] = true
                db.sectionCompleted[secId]  = true  -- persist so hide-finished-weeks survives updates
            end
        elseif newIdx <= oldIdx then
            local checked   = type(db.checked)          == "table" and db.checked          or nil
            local collapsed = type(db.collapsedSections) == "table" and db.collapsedSections or nil
            local done      = type(db.sectionCompleted)  == "table" and db.sectionCompleted  or nil
            local fromIdx   = (newIdx == 0 and 1 or newIdx)
            -- Clear from the selected week all the way to the end: jumping back to
            -- a week means "show everything from here forward", regardless of how
            -- far ahead oldIdx happened to be.
            for i = fromIdx, #order do
                local secId  = order[i]
                local secDef = Addon._sectionsById and Addon._sectionsById[secId]
                local items  = secDef and secDef.items or {}
                if checked then
                    for _, item in ipairs(items) do
                        checked[secId .. ":" .. tostring(item.id)] = nil
                    end
                end
                if collapsed then collapsed[secId] = nil end
                if done      then done[secId]      = nil end  -- un-complete when navigating backward
            end
        end

        db.startAtSectionId = newStart
        -- Ensure the newly-selected section starts expanded.
        if db.collapsedSections and newStart and newStart ~= "" then
            db.collapsedSections[newStart] = false
        end
        -- Allow a complete section to stay expanded if the user picked it.
        if Addon._userExpandedCompleted and newStart and newStart ~= "" then
            Addon._userExpandedCompleted[newStart] = true
        end

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
            -- If that pinned week is now complete, clear the pin so the marker
            -- advances to the first-incomplete / last-active week below.
            if Addon._IsSectionCompleteById and
               Addon._IsSectionCompleteById(storedStart, db0) then
                db0.startAtSectionId = ""
                storedStart = ""
            else
                currentId = storedStart
            end
        end
        if not currentId then
            -- No explicit pin: find the first incomplete week, matching the same
            -- logic used by LayoutHeaderButtons_ so the ">" marker always lands
            -- on the same week shown in the button label.
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

        -- Pre-compute index of the current week so tooltips can say
        -- "Reset to week" (going back) vs "Go to week" (going forward).
        local currentIdx = 0
        if type(data) == "table" then
            for i = 1, #data do
                local s = data[i]
                if type(s) == "table" and tostring(s.id or "") == currentId then
                    currentIdx = i
                    break
                end
            end
        end

        if type(data) == "table" then
            for i = 1, #data do
                local section = data[i]
                if type(section) == "table" then
                    local id        = section.id
                    local isCurrent = (tostring(id or "") == currentId)
                    local label = ExtractMonthRangeLabel(section.title or id or "")
                    if label == "" then label = tostring(id or i) end
                    if isCurrent then label = "> " .. label end

                    local btn = AcquirePickerButton(picker)
                    btn:ClearAllPoints()
                    btn:SetPoint("TOPLEFT", picker, "TOPLEFT", PICKER_PAD, posY)
                    btn:SetHeight(PICKER_ROW_HEIGHT)
                    btn:SetText(label)
                    btn:SetEnabled(true)
                    local capturedId    = id
                    local capturedTitle = section.title or label
                    local capturedIdx   = i
                    btn:SetScript("OnClick", function()
                        HandlePick(capturedId, Addon._scrollFrame)
                    end)
                    btn:SetScript("OnEnter", function(self_)
                        local prefix
                        if currentIdx > 0 and capturedIdx > currentIdx then
                            prefix = L.PICKER_GO_TO_WEEK_TOOLTIP or "Go to week:"
                        else
                            prefix = L.PICKER_RESET_WEEK_TOOLTIP or "Reset to week:"
                        end
                        Addon.AddonUtils.SetTooltip(self_, prefix .. "\n" .. capturedTitle)
                    end)
                    btn:SetScript("OnLeave", Addon.AddonUtils.HideTooltip)

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
        local dbLocal = Addon:EnsurePrefs()
        local showCW  = dbLocal.showChangeWeekBtn ~= false
        local showIR  = dbLocal.showIlvlRefBtn    ~= false

        -- changeWeekBtn: top-left of the frame.
        if showCW then
            local btn = EnsureChangeWeekBtn_()
            local cwWeekLabel
            do
                local db0 = Addon:EnsureDB()
                local storedStart = tostring(db0.startAtSectionId or "")
                local currentId
                if storedStart ~= "" then
                    -- If the pinned week is now fully complete, clear the pin and
                    -- auto-advance to the first incomplete week instead.
                    if Addon._IsSectionCompleteById and
                       Addon._IsSectionCompleteById(storedStart, db0) then
                        db0.startAtSectionId = ""
                        storedStart = ""
                    else
                        currentId = storedStart
                    end
                end
                -- If the section index is built but no longer contains this ID
                -- (stale SavedVariable from an older data format, version bump, etc.)
                -- drop the pin so the first-incomplete-week logic takes over.
                if currentId and next(Addon._sectionsById or {}) and
                   not (Addon._sectionsById or {})[currentId] then
                    db0.startAtSectionId = ""
                    currentId = nil
                end
                if not currentId then
                    local order = Addon._order or {}
                    local allComplete = true
                    for i = 1, #order do
                        if Addon._IsSectionCompleteById and
                           not Addon._IsSectionCompleteById(order[i], db0) then
                            currentId   = tostring(order[i])
                            allComplete = false
                            break
                        end
                    end
                    if allComplete then
                        -- Every week is done — show a completion label.
                        cwWeekLabel = L.ALL_WEEKS_COMPLETE or "Finished!"
                    end
                end
                if not cwWeekLabel then
                    if not currentId and Addon._order and Addon._order[1] then
                        currentId = tostring(Addon._order[1])
                    end
                    local section   = currentId and Addon._sectionsById and Addon._sectionsById[currentId]
                    -- Never fall back to the raw section ID as display text; if the
                    -- section isn't found (not yet built or stale ID), show the
                    -- generic label and let the next Refresh() supply the real one.
                    local extracted = ExtractMonthRangeLabel(section and section.title or "")
                    cwWeekLabel = (extracted ~= "") and extracted or (L.CHANGE_WEEK_BUTTON or "Change Week")
                end
            end
            btn._lariasSelectedLabel = cwWeekLabel
            btn:SetText(cwWeekLabel)
            local cwTip = L.CHANGE_WEEK_BUTTON or "Change Week"
            btn:SetScript("OnEnter", function(self_) Addon.AddonUtils.SetTooltip(self_, cwTip, "ANCHOR_BOTTOMLEFT") end)
            btn:SetScript("OnLeave", Addon.AddonUtils.HideTooltip)
            btn:SetScript("OnClick", function()
                local p = EnsureHeaderPicker()
                if p and p._lariasClosedAt and (GetTime() - p._lariasClosedAt) < 0.20 then p._lariasClosedAt = nil; return end
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

        -- Normal scroll: find the deepest section whose header has reached or
        -- passed the viewport top (top >= sfViewTop). Iterating forward through
        -- visual order (section 1 → section N) and keeping the last match means
        -- the result is the section currently sitting at the top of the view.
        --
        -- Wrong approach (old): return on first section where top <= sfViewTop.
        -- That immediately picks section 2 the instant section 1 moves 1px above
        -- the fold, because section 2's top is also <= sfViewTop (it's just lower).
        local sfViewTop = sf and sf.GetTop and sf:GetTop()
        if sfViewTop then
            local bestId = nil
            for i = 1, #sections do
                local s = sections[i]
                if s and s.IsShown and s:IsShown() and s._sectionId then
                    local top = s:GetTop()
                    -- top >= sfViewTop - 1: this section's header has reached or
                    -- passed the viewport top; keep updating so the last (lowest)
                    -- qualifying one wins.
                    if top and top >= sfViewTop - 1 then
                        bestId = s._sectionId
                    end
                end
            end
            if bestId then
                local section   = Addon._sectionsById and Addon._sectionsById[tostring(bestId)]
                local extracted = ExtractMonthRangeLabel((section and section.title) or tostring(bestId))
                local label     = (extracted ~= "") and extracted or (L.CHANGE_WEEK_BUTTON or "Change Week")
                btn:SetText(label)
                return
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
        -- OnVerticalScroll covers every scroll step; OnValueChanged on the scrollbar
        -- fires the same event, so we skip it to avoid double-calling the label refresh.
        if sf.HookScript then
            sf:HookScript("OnScrollRangeChanged", function() RefreshChangeWeekLabel_() end)
            sf:HookScript("OnVerticalScroll",     function() RefreshChangeWeekLabel_() end)
        end
        Addon._wireScrollHeaderHooks = nil  -- one-shot
    end
end
