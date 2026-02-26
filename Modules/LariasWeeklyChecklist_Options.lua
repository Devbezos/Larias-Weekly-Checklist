local addonName = ...
local Addon = _G[addonName]
if not Addon then return end

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
            local noneLabel = string.format("%s %s",
                L.OPTIONS_HIDDEN_CHARS_TITLE or "Hidden characters:",
                L.OPTIONS_HIDDEN_CHARS_NONE  or "None")
            trigBtn:SetText(noneLabel)
            trigBtn:SetEnabled(false)
        else
            trigBtn:SetEnabled(true)
            local label = string.format("%s (%d) |TInterface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up:10:10|t",
                L.OPTIONS_HIDDEN_CHARS_TITLE or "Hidden characters:", #hidden)
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
    -- Options tab removed; keep as stub so existing call-sites don't error.
    if self.SyncGearPopup then self:SyncGearPopup() end
end

function Addon:UpdateOptionsLocalizedUI()
    -- Refresh gear popup labels when locale changes.
    if self.SyncGearPopup then self:SyncGearPopup() end
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

    local MIN_V  = 50
    local MAX_V  = 150
    local STEP_V = 1

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
    sf:EnableMouse(true)  -- consume all clicks so right-clicks don't propagate to parent
    self._inFrameScaleSlider = sf

    -- "Scale" label
    local scaleLbl = sf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    scaleLbl:SetPoint("LEFT", sf, "LEFT", 0, 0)
    scaleLbl:SetWidth(LBL_W)
    scaleLbl:SetJustifyH("RIGHT")
    scaleLbl:SetWordWrap(false)
    scaleLbl:SetTextColor(txt.r, txt.g, txt.b, txt.a)
    local L = self.L or {}
    scaleLbl:SetText(L.UI_SCALE_LABEL or "Scale")

    -- Percentage readout — sits right after the "Scale" label
    local pctLbl = sf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pctLbl:SetPoint("LEFT", scaleLbl, "RIGHT", GAP, 0)
    pctLbl:SetWidth(PCT_W)
    pctLbl:SetJustifyH("LEFT")
    pctLbl:SetWordWrap(false)
    pctLbl:SetTextColor(txtD.r, txtD.g, txtD.b, txtD.a)

    -- Track container (mouse receiver + clipping context) — right of the readout
    local trackCont = CreateFrame("Frame", nil, sf)
    trackCont:SetSize(TRACK_W, SLIDER_H)
    trackCont:SetPoint("LEFT", pctLbl, "RIGHT", GAP, 0)

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

    -- The main frame always has SetScale(1); content scaling is applied to
    -- scrollChild and the tracking frame instead of the outer window.
    -- GetEffectiveScale() here is just UIParent's scale, which is the correct
    -- divisor for mapping raw cursor pixels to frame-local coordinates.
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
        if pct then SetPct(pct) end
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
        if pct then SetPct(pct) end
    end)

    sf:SetScript("OnShow", function() UpdateVisuals(GetCurrentPct()) end)
    UpdateVisuals(GetCurrentPct())
end

-- CreateBlizzOptionsPanel: no longer registers with Blizzard Interface → AddOns.
-- Options are now accessed via the gear icon / minimap right-click (gear popup).
function Addon:CreateBlizzOptionsPanel()
    -- Intentionally a no-op; kept so call-sites don't error.
end