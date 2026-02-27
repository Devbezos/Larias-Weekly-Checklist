local addonName = ...
local Addon = _G[addonName]
if not Addon then return end

-- ── In-frame scale slider ─────────────────────────────────────────────────────
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
    local TRACK_H   = 10     -- track bar height
    local THUMB_W   = 34     -- wide enough to show "100%"
    local THUMB_H   = 16     -- thumb height
    local TRACK_W   = 100    -- usable track width
    local MIN_LBL_W = 26     -- "50%" label
    local MAX_LBL_W = 32     -- "unc." / "150%" label
    local GAP       = 6
    local SLIDER_W  = MIN_LBL_W + GAP + TRACK_W + GAP + MAX_LBL_W
    local SLIDER_H  = math.max(THUMB_H, Addon.UI.sliderH or 20)

    -- Outer container
    local sf = CreateFrame("Frame", nil, parentFrame)
    sf:SetSize(SLIDER_W, SLIDER_H)
    sf:SetPoint("BOTTOMLEFT", parentFrame, "BOTTOMLEFT", Addon.UI.sectionInsetX or 14, Addon.UI.sliderBottomPad or 4)
    sf:EnableMouse(true)
    self._inFrameScaleSlider = sf

    local L = self.L or {}

    -- Min label ("50%")
    local minLbl = sf:CreateFontString(nil, "OVERLAY")
    minLbl:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    minLbl:SetPoint("LEFT", sf, "LEFT", 0, 0)
    minLbl:SetWidth(MIN_LBL_W)
    minLbl:SetJustifyH("RIGHT")
    minLbl:SetWordWrap(false)
    minLbl:SetTextColor(txtD.r, txtD.g, txtD.b, 0.65)
    minLbl:SetText(L.UI_SCALE_MIN_LABEL or "50%")

    -- Track container (mouse receiver) — right of min label
    local trackCont = CreateFrame("Frame", nil, sf)
    trackCont:SetSize(TRACK_W, SLIDER_H)
    trackCont:SetPoint("LEFT", minLbl, "RIGHT", GAP, 0)

    -- Track bar (thin rectangle centred vertically)
    local trackBar = trackCont:CreateTexture(nil, "BACKGROUND")
    trackBar:SetHeight(TRACK_H)
    trackBar:SetPoint("LEFT",  trackCont, "LEFT",  0, 0)
    trackBar:SetPoint("RIGHT", trackCont, "RIGHT", 0, 0)
    trackBar:SetColorTexture(bdr.r, bdr.g, bdr.b, 0.7)

    -- Thumb — shows the current percentage as text
    local thumb = CreateFrame("Frame", nil, trackCont)
    thumb:SetSize(THUMB_W, THUMB_H)
    thumb:SetFrameLevel(trackCont:GetFrameLevel() + 1)
    local thumbTex = thumb:CreateTexture(nil, "ARTWORK")
    thumbTex:SetAllPoints(thumb)
    thumbTex:SetColorTexture(txt.r, txt.g, txt.b, 0.9)
    -- Text inside the thumb (black on white so it's readable)
    local thumbLbl = thumb:CreateFontString(nil, "OVERLAY")
    thumbLbl:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    thumbLbl:SetAllPoints(thumb)
    thumbLbl:SetJustifyH("CENTER")
    thumbLbl:SetJustifyV("MIDDLE")
    thumbLbl:SetWordWrap(false)
    thumbLbl:SetTextColor(0, 0, 0, 1)

    -- Max label ("unc." for enUS, "150%" for other locales)
    local maxLbl = sf:CreateFontString(nil, "OVERLAY")
    maxLbl:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    maxLbl:SetPoint("LEFT", trackCont, "RIGHT", GAP, 0)
    maxLbl:SetWidth(MAX_LBL_W)
    maxLbl:SetJustifyH("LEFT")
    maxLbl:SetWordWrap(false)
    maxLbl:SetTextColor(txtD.r, txtD.g, txtD.b, 0.65)
    maxLbl:SetText(L.UI_SCALE_MAX_LABEL or "150%")

    -- ── Logic ─────────────────────────────────────────────────────────────

    local USABLE = TRACK_W - THUMB_W

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
        local rounded = math.floor(pct + 0.5)
        local label = (rounded >= MAX_V) and "unc." or (rounded .. "%")
        thumbLbl:SetText(label)
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

    local function PctFromCursor()
        local uiScale = UIParent and UIParent:GetScale() or 1
        local cx      = GetCursorPosition() / uiScale
        -- During drag: use cursor DELTA from start rather than cursor vs track origin.
        -- This is completely immune to the track position changing when the frame
        -- rescales, eliminating the feedback loop that locked the slider at extremes.
        local startCx  = trackCont._dragStartCursorX
        local startPct = trackCont._dragStartPct
        local trackPxW = trackCont._dragTrackPxW
        if startCx and startPct and trackPxW and trackPxW > 0 then
            local delta    = cx - startCx
            local pctDelta = (delta / trackPxW) * (MAX_V - MIN_V)
            return math.max(MIN_V, math.min(MAX_V, startPct + pctDelta))
        end
        -- Fallback (MouseUp / no active drag): absolute cursor vs track position.
        local left = trackCont:GetLeft()
        if not left then return nil end
        local mfScale = (Addon._mainFrame and Addon._mainFrame:GetScale()) or 1
        local frac = (cx - left) / (TRACK_W * mfScale)
        return MIN_V + math.max(0, math.min(1, frac)) * (MAX_V - MIN_V)
    end

    trackCont:EnableMouse(true)
    trackCont:SetScript("OnMouseDown", function(self_, btn)
        if btn ~= "LeftButton" then return end
        local uiScale_d = UIParent and UIParent:GetScale() or 1
        local cx_d      = GetCursorPosition() / uiScale_d
        local mf        = Addon._mainFrame
        local mfScale   = (mf and mf:GetScale()) or 1
        local left_d    = trackCont:GetLeft()
        local clickPct  = GetCurrentPct()
        if left_d then
            local frac_d = (cx_d - left_d) / (TRACK_W * mfScale)
            clickPct = MIN_V + math.max(0, math.min(1, frac_d)) * (MAX_V - MIN_V)
        end
        self_._dragging         = true
        self_._dragStartCursorX = cx_d
        self_._dragStartPct     = clickPct
        self_._dragTrackPxW     = TRACK_W * mfScale
        UpdateVisuals(clickPct)
        -- Only run OnUpdate for the duration of the drag; not every frame forever.
        trackCont:SetScript("OnUpdate", function()
            local pct = PctFromCursor()
            if pct then UpdateVisuals(pct) end
            -- Scale commits on mouse release via OnMouseUp → SetPct.
        end)
    end)
    trackCont:SetScript("OnMouseUp", function(self_, btn)
        if btn ~= "LeftButton" then return end
        trackCont:SetScript("OnUpdate", nil)  -- stop per-frame work immediately
        local pct = PctFromCursor()  -- delta path still active here
        self_._dragging         = false
        self_._dragStartCursorX = nil
        self_._dragStartPct     = nil
        self_._dragTrackPxW     = nil
        if pct then SetPct(pct) end  -- full commit: saves, applies scale + layout
    end)

    sf:SetScript("OnShow", function() UpdateVisuals(GetCurrentPct()) end)
    UpdateVisuals(GetCurrentPct())

    -- Apply saved visibility preference.
    if Addon.ApplyScaleSliderVisibility then Addon:ApplyScaleSliderVisibility() end
end
