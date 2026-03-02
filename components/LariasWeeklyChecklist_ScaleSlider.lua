local addonName = ...
local Addon = _G[addonName]
if not Addon then return end

-- â”€â”€ In-frame scale + opacity sliders â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- Two compact custom-styled sliders placed side-by-side at the bottom of the
-- main addon frame, each with a label above the track.
-- ── Shared slider widget factory ─────────────────────────────────────────────
-- Creates a single slider (track + thumb + min/max labels + optional title)
-- inside `pane`.  `pane` must have a fixed height of:
--   (sliderLabelH + 2 + max(16, sliderH))  ≈ 36 px.
-- Returns a Sync() closure that repositions the thumb to the current value.
--
-- opts = {
--   minV, maxV, stepV,
--   getVal()    → number,
--   applyFn(v): called on mouse-up (and every tick if liveApply=true),
--   minLabel, maxLabel,
--   fmtFn(v)    → string shown on thumb,
--   titleLabel  = string | nil   (label drawn above the track),
--   liveApply   = true | false | nil,
--   trackW      = number | nil   (default 100),
--   scaleFrame  = frame | nil    (GetScale() source; nil → 1.0),
-- }
function Addon:CreateSliderWidget(pane, opts)
    local THEME = Addon.THEME or {}
    local bdr   = THEME.border  or { r=0.30, g=0.30, b=0.30, a=0.90 }
    local txt   = THEME.text    or { r=1.00, g=1.00, b=1.00, a=1.00 }

    local TRACK_H   = 10
    local THUMB_W   = 34
    local THUMB_H   = 16
    local TRACK_W   = opts.trackW or 100
    local MIN_LBL_W = 26
    local MAX_LBL_W = 32
    local GAP       = 6
    local SLIDER_H  = math.max(THUMB_H, Addon.UI.sliderH or 20)
    local LABEL_H   = Addon.UI.sliderLabelH or 14
    local CONTENT_W = MIN_LBL_W + GAP + TRACK_W + GAP + MAX_LBL_W
    local USABLE    = TRACK_W - THUMB_W

    local minV      = opts.minV
    local maxV      = opts.maxV
    local stepV     = opts.stepV
    local getVal    = opts.getVal
    local applyFn   = opts.applyFn
    local fmtFn     = opts.fmtFn
    local liveApply = opts.liveApply

    -- Optional title label spanning the full pane width.
    if opts.titleLabel then
        local titleLbl = pane:CreateFontString(nil, "OVERLAY")
        titleLbl:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        titleLbl:SetPoint("TOPLEFT",  pane, "TOPLEFT",  0, 0)
        titleLbl:SetPoint("TOPRIGHT", pane, "TOPRIGHT", 0, 0)
        titleLbl:SetHeight(LABEL_H)
        titleLbl:SetJustifyH("CENTER")
        titleLbl:SetWordWrap(false)
        titleLbl:SetTextColor(txt.r, txt.g, txt.b, 0.75)
        titleLbl:SetText(opts.titleLabel)
        pane._titleLbl = titleLbl
    end

    -- Min label anchored to the bottom-centre of the pane.
    local minLbl = pane:CreateFontString(nil, "OVERLAY")
    minLbl:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    minLbl:SetPoint("BOTTOMLEFT", pane, "BOTTOM", -CONTENT_W / 2, 0)
    minLbl:SetSize(MIN_LBL_W, SLIDER_H)
    minLbl:SetJustifyH("RIGHT")
    minLbl:SetJustifyV("MIDDLE")
    minLbl:SetWordWrap(false)
    minLbl:SetTextColor(txt.r, txt.g, txt.b, 0.65)
    minLbl:SetText(opts.minLabel)

    -- Track container (mouse hit area).
    local trackCont = CreateFrame("Frame", nil, pane)
    trackCont:SetSize(TRACK_W, SLIDER_H)
    trackCont:SetPoint("BOTTOMLEFT", minLbl, "BOTTOMRIGHT", GAP, 0)

    local trackBar = trackCont:CreateTexture(nil, "BACKGROUND")
    trackBar:SetHeight(TRACK_H)
    trackBar:SetPoint("LEFT",  trackCont, "LEFT",  0, 0)
    trackBar:SetPoint("RIGHT", trackCont, "RIGHT", 0, 0)
    trackBar:SetColorTexture(bdr.r, bdr.g, bdr.b, 0.7)

    local thumb = CreateFrame("Frame", nil, trackCont)
    thumb:SetSize(THUMB_W, THUMB_H)
    thumb:SetFrameLevel(trackCont:GetFrameLevel() + 1)
    local thumbTex = thumb:CreateTexture(nil, "ARTWORK")
    thumbTex:SetAllPoints(thumb)
    thumbTex:SetColorTexture(txt.r * 0.45, txt.g * 0.45, txt.b * 0.45, 0.9)
    local thumbLbl = thumb:CreateFontString(nil, "OVERLAY")
    thumbLbl:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    thumbLbl:SetAllPoints(thumb)
    thumbLbl:SetJustifyH("CENTER")
    thumbLbl:SetJustifyV("MIDDLE")
    thumbLbl:SetWordWrap(false)
    thumbLbl:SetTextColor(txt.r, txt.g, txt.b, 1)

    -- Max label.
    local maxLbl = pane:CreateFontString(nil, "OVERLAY")
    maxLbl:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    maxLbl:SetPoint("BOTTOMLEFT", trackCont, "BOTTOMRIGHT", GAP, 0)
    maxLbl:SetSize(MAX_LBL_W, SLIDER_H)
    maxLbl:SetJustifyH("LEFT")
    maxLbl:SetJustifyV("MIDDLE")
    maxLbl:SetWordWrap(false)
    maxLbl:SetTextColor(txt.r, txt.g, txt.b, 0.65)
    maxLbl:SetText(opts.maxLabel)

    local function UpdateVisuals(v)
        v = math.max(minV, math.min(maxV, v))
        local frac = (v - minV) / (maxV - minV)
        thumb:ClearAllPoints()
        thumb:SetPoint("LEFT", trackCont, "LEFT", math.floor(frac * USABLE), 0)
        thumbLbl:SetText(fmtFn(v))
    end

    local function SetVal(v)
        v = math.max(minV, math.min(maxV, v))
        v = math.floor((v + stepV / 2) / stepV) * stepV
        applyFn(v)
        UpdateVisuals(v)
    end

    local function ValFromCursor()
        local sf      = opts.scaleFrame
        local mfScale = (sf and sf:GetScale()) or 1
        local uiScale = UIParent and UIParent:GetScale() or 1
        local cx      = GetCursorPosition() / uiScale
        local startCx  = trackCont._dragStartCursorX
        local startVal = trackCont._dragStartVal
        local trackPxW = trackCont._dragTrackPxW
        if startCx and startVal and trackPxW and trackPxW > 0 then
            local delta    = cx - startCx
            local valDelta = (delta / trackPxW) * (maxV - minV)
            return math.max(minV, math.min(maxV, startVal + valDelta))
        end
        local left = trackCont:GetLeft()
        if not left then return nil end
        local frac = (cx - left) / (TRACK_W * mfScale)
        return minV + math.max(0, math.min(1, frac)) * (maxV - minV)
    end

    trackCont:EnableMouse(true)
    trackCont:SetScript("OnMouseDown", function(_, btn)
        if btn ~= "LeftButton" then return end
        local sf      = opts.scaleFrame
        local mfScale = (sf and sf:GetScale()) or 1
        local uiScale = UIParent and UIParent:GetScale() or 1
        local cx      = GetCursorPosition() / uiScale
        local clickVal = getVal()
        local left = trackCont:GetLeft()
        if left then
            local frac = (cx - left) / (TRACK_W * mfScale)
            clickVal = minV + math.max(0, math.min(1, frac)) * (maxV - minV)
        end
        trackCont._dragging         = true
        trackCont._dragStartCursorX = cx
        trackCont._dragStartVal     = clickVal
        trackCont._dragTrackPxW     = TRACK_W * mfScale
        UpdateVisuals(clickVal)
        trackCont:SetScript("OnUpdate", function()
            local v = ValFromCursor()
            if v then
                UpdateVisuals(v)
                if liveApply then
                    local snapped = math.floor((v + stepV / 2) / stepV) * stepV
                    if type(liveApply) == "function" then liveApply(snapped)
                    else applyFn(snapped) end
                end
            end
        end)
    end)
    trackCont:SetScript("OnMouseUp", function(_, btn)
        if btn ~= "LeftButton" then return end
        trackCont:SetScript("OnUpdate", nil)
        local v = ValFromCursor()
        trackCont._dragging         = false
        trackCont._dragStartCursorX = nil
        trackCont._dragStartVal     = nil
        trackCont._dragTrackPxW     = nil
        if v then SetVal(v) end
    end)

    return function() UpdateVisuals(getVal()) end   -- Sync()
end

function Addon:CreateInFrameScaleSlider(parentFrame)
    if self._inFrameScaleSlider then return end

    local THEME = Addon.THEME or {}
    local bdr   = THEME.border  or { r=0.30, g=0.30, b=0.30, a=0.90 }
    local txt   = THEME.text    or { r=1.00, g=1.00, b=1.00, a=1.00 }
    local txtD  = THEME.textDim or txt
    local L     = self.L or {}

    -- Shared layout constants
    local TRACK_H   = 10
    local THUMB_W   = 34
    local THUMB_H   = 16
    local TRACK_W   = 100
    local MIN_LBL_W = 26
    local MAX_LBL_W = 32
    local GAP       = 6
    local SLIDER_H  = math.max(THUMB_H, Addon.UI.sliderH or 20)
    local LABEL_H   = Addon.UI.sliderLabelH or 14
    local LABEL_GAP = 2
    local TOTAL_H   = LABEL_H + LABEL_GAP + SLIDER_H
    local CONTENT_W = MIN_LBL_W + GAP + TRACK_W + GAP + MAX_LBL_W  -- total fixed slider row width

    -- Outer container spanning the full bottom width of the frame.
    local sf = CreateFrame("Frame", nil, parentFrame)
    sf:SetPoint("BOTTOMLEFT",  parentFrame, "BOTTOMLEFT",
        Addon.UI.sectionInsetX or 14, Addon.UI.sliderBottomPad or 4)
    sf:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT",
        -(Addon.UI.sectionInsetX or 14), Addon.UI.sliderBottomPad or 4)
    sf:SetHeight(TOTAL_H)
    sf:EnableMouse(true)
    self._inFrameScaleSlider = sf

    -- Re-anchor the slider container to absorb any banner height change.
    -- The char-picker button is now placed ABOVE the slider row by LayoutHeaderButtons_
    -- so no right-edge shrinking is needed.
    sf.AdjustForCpBtn = function(_ignore)
        local inset  = Addon.UI.sectionInsetX  or 14
        local botPad = (Addon.UI.sliderBottomPad or 4) + (sf._bannerBotExtra or 0)
        sf:ClearAllPoints()
        sf:SetPoint("BOTTOMLEFT",  parentFrame, "BOTTOMLEFT",  inset,  botPad)
        sf:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", -inset, botPad)
    end

    -- BuildSlider: populates `pane` (height = TOTAL_H) with the interactive
    -- track, thumb knob, and min/max labels.  Returns a Sync() closure.
    local function BuildSlider(pane, minV, maxV, stepV, getVal, applyFn,
                               minLabel, maxLabel, fmtFn, liveApply)
        local USABLE = TRACK_W - THUMB_W

        -- Min label anchored to the bottom-centre of the pane so the entire
        -- content block (minLbl + track + maxLbl) is horizontally centred,
        -- keeping the title label (which spans the full pane) aligned over the track.
        local minLbl = pane:CreateFontString(nil, "OVERLAY")
        minLbl:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        minLbl:SetPoint("BOTTOMLEFT", pane, "BOTTOM", -CONTENT_W / 2, 0)
        minLbl:SetSize(MIN_LBL_W, SLIDER_H)
        minLbl:SetJustifyH("RIGHT")
        minLbl:SetJustifyV("MIDDLE")
        minLbl:SetWordWrap(false)
        minLbl:SetTextColor(txt.r, txt.g, txt.b, 0.65)
        minLbl:SetText(minLabel)

        -- Track container (mouse hit area).
        local trackCont = CreateFrame("Frame", nil, pane)
        trackCont:SetSize(TRACK_W, SLIDER_H)
        trackCont:SetPoint("BOTTOMLEFT", minLbl, "BOTTOMRIGHT", GAP, 0)

        -- Track bar (thin horizontal line).
        local trackBar = trackCont:CreateTexture(nil, "BACKGROUND")
        trackBar:SetHeight(TRACK_H)
        trackBar:SetPoint("LEFT",  trackCont, "LEFT",  0, 0)
        trackBar:SetPoint("RIGHT", trackCont, "RIGHT", 0, 0)
        trackBar:SetColorTexture(bdr.r, bdr.g, bdr.b, 0.7)

        -- Thumb (draggable knob showing the current value).
        local thumb = CreateFrame("Frame", nil, trackCont)
        thumb:SetSize(THUMB_W, THUMB_H)
        thumb:SetFrameLevel(trackCont:GetFrameLevel() + 1)
        local thumbTex = thumb:CreateTexture(nil, "ARTWORK")
        thumbTex:SetAllPoints(thumb)
        -- Thumb background = darkened text color so it stays in the same hue as the rest of the UI.
        thumbTex:SetColorTexture(txt.r * 0.45, txt.g * 0.45, txt.b * 0.45, 0.9)
        local thumbLbl = thumb:CreateFontString(nil, "OVERLAY")
        thumbLbl:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
        thumbLbl:SetAllPoints(thumb)
        thumbLbl:SetJustifyH("CENTER")
        thumbLbl:SetJustifyV("MIDDLE")
        thumbLbl:SetWordWrap(false)
        -- Thumb label = full-brightness text color to contrast the darkened background.
        thumbLbl:SetTextColor(txt.r, txt.g, txt.b, 1)

        -- Max label (right of track).
        local maxLbl = pane:CreateFontString(nil, "OVERLAY")
        maxLbl:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        maxLbl:SetPoint("BOTTOMLEFT", trackCont, "BOTTOMRIGHT", GAP, 0)
        maxLbl:SetSize(MAX_LBL_W, SLIDER_H)
        maxLbl:SetJustifyH("LEFT")
        maxLbl:SetJustifyV("MIDDLE")
        maxLbl:SetWordWrap(false)
        maxLbl:SetTextColor(txt.r, txt.g, txt.b, 0.65)
        maxLbl:SetText(maxLabel)

        -- Store refs for dynamic re-theming via sf.RefreshColors().
        pane._minLbl   = minLbl
        pane._maxLbl   = maxLbl
        pane._thumbTex = thumbTex
        pane._thumbLbl = thumbLbl

        local function UpdateVisuals(v)
            v = math.max(minV, math.min(maxV, v))
            local frac = (v - minV) / (maxV - minV)
            thumb:ClearAllPoints()
            thumb:SetPoint("LEFT", trackCont, "LEFT", math.floor(frac * USABLE), 0)
            thumbLbl:SetText(fmtFn(v))
        end

        local function SetVal(v)
            v = math.max(minV, math.min(maxV, v))
            v = math.floor((v + stepV / 2) / stepV) * stepV
            applyFn(v)
            UpdateVisuals(v)
        end

        local function ValFromCursor()
            local uiScale  = UIParent and UIParent:GetScale() or 1
            local cx       = GetCursorPosition() / uiScale
            local startCx  = trackCont._dragStartCursorX
            local startVal = trackCont._dragStartVal
            local trackPxW = trackCont._dragTrackPxW
            if startCx and startVal and trackPxW and trackPxW > 0 then
                local delta    = cx - startCx
                local valDelta = (delta / trackPxW) * (maxV - minV)
                return math.max(minV, math.min(maxV, startVal + valDelta))
            end
            -- Fallback: absolute cursor vs track origin.
            local left    = trackCont:GetLeft()
            if not left then return nil end
            local mfScale = (Addon._mainFrame and Addon._mainFrame:GetScale()) or 1
            local frac    = (cx - left) / (TRACK_W * mfScale)
            return minV + math.max(0, math.min(1, frac)) * (maxV - minV)
        end

        trackCont:EnableMouse(true)
        trackCont:SetScript("OnMouseDown", function(self_, btn)
            if btn ~= "LeftButton" then return end
            local uiScale_d = UIParent and UIParent:GetScale() or 1
            local cx_d      = GetCursorPosition() / uiScale_d
            local mf        = Addon._mainFrame
            local mfScale   = (mf and mf:GetScale()) or 1
            local left_d    = trackCont:GetLeft()
            local clickVal  = getVal()
            if left_d then
                local frac_d = (cx_d - left_d) / (TRACK_W * mfScale)
                clickVal     = minV + math.max(0, math.min(1, frac_d)) * (maxV - minV)
            end
            trackCont._dragging         = true
            trackCont._dragStartCursorX = cx_d
            trackCont._dragStartVal     = clickVal
            trackCont._dragTrackPxW     = TRACK_W * mfScale
            UpdateVisuals(clickVal)
            trackCont:SetScript("OnUpdate", function()
                local v = ValFromCursor()
                if v then
                    UpdateVisuals(v)
                    if liveApply then
                        local snapped = math.floor((v + stepV / 2) / stepV) * stepV
                        if type(liveApply) == "function" then
                            liveApply(snapped)
                        else
                            applyFn(snapped)
                        end
                    end
                end
            end)
        end)
        trackCont:SetScript("OnMouseUp", function(self_, btn)
            if btn ~= "LeftButton" then return end
            trackCont:SetScript("OnUpdate", nil)
            local v = ValFromCursor()
            trackCont._dragging         = false
            trackCont._dragStartCursorX = nil
            trackCont._dragStartVal     = nil
            trackCont._dragTrackPxW     = nil
            if v then SetVal(v) end
        end)

        return function() UpdateVisuals(getVal()) end   -- Sync closure
    end

    -- â”€â”€ Scale pane (left half by default) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    local scalePane = CreateFrame("Frame", nil, sf)
    scalePane:SetHeight(TOTAL_H)

    local scaleTitleLbl = scalePane:CreateFontString(nil, "OVERLAY")
    scaleTitleLbl:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    scaleTitleLbl:SetPoint("TOPLEFT",  scalePane, "TOPLEFT",  0, 0)
    scaleTitleLbl:SetPoint("TOPRIGHT", scalePane, "TOPRIGHT", 0, 0)
    scaleTitleLbl:SetHeight(LABEL_H)
    scaleTitleLbl:SetJustifyH("CENTER")
    scaleTitleLbl:SetWordWrap(false)
    scaleTitleLbl:SetTextColor(txt.r, txt.g, txt.b, 0.75)
    scaleTitleLbl:SetText(L.UI_SCALE_LABEL or "Scale")
    sf._scaleTitleLbl = scaleTitleLbl

    local function GetScaleVal()
        local gdb = Addon.db and Addon.db.global
        return (gdb and tonumber(gdb.uiScalePct)) or 100
    end

    local scaleSync = BuildSlider(
        scalePane, 50, 150, 1,
        GetScaleVal,
        -- applyFn (called on mouse-up): save + full re-anchor via ApplyUIScale.
        function(pct)
            local gdb = Addon.db and Addon.db.global
            if gdb then gdb.uiScalePct = pct end
            if Addon.ApplyUIScale then Addon:ApplyUIScale() end
        end,
        L.UI_SCALE_MIN_LABEL or "50%",
        L.UI_SCALE_MAX_LABEL or "150%",
        function(v)
            local r = math.floor(v + 0.5)
            return r .. "%"
        end,
        nil  -- no liveApply: scale is applied only on mouse-up to avoid jank while dragging
    )
    sf._scalePane = scalePane
    sf.Sync       = function() scaleSync() end

    -- â”€â”€ Opacity pane (right half by default) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    local opacityPane = CreateFrame("Frame", nil, sf)
    opacityPane:SetHeight(TOTAL_H)

    local opacTitleLbl = opacityPane:CreateFontString(nil, "OVERLAY")
    opacTitleLbl:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    opacTitleLbl:SetPoint("TOPLEFT",  opacityPane, "TOPLEFT",  0, 0)
    opacTitleLbl:SetPoint("TOPRIGHT", opacityPane, "TOPRIGHT", 0, 0)
    opacTitleLbl:SetHeight(LABEL_H)
    opacTitleLbl:SetJustifyH("CENTER")
    opacTitleLbl:SetWordWrap(false)
    opacTitleLbl:SetTextColor(txt.r, txt.g, txt.b, 0.75)
    opacTitleLbl:SetText(L.UI_OPACITY_LABEL or "Opacity")
    sf._opacTitleLbl = opacTitleLbl

    local function GetOpacityVal()
        local gdb = Addon.db and Addon.db.global
        return (gdb and tonumber(gdb.uiOpacityPct)) or 65
    end

    local opacSync = BuildSlider(
        opacityPane, 10, 100, 5,
        GetOpacityVal,
        function(pct)
            local gdb = Addon.db and Addon.db.global
            if gdb then gdb.uiOpacityPct = pct end
            if Addon.ApplyOpacity then Addon:ApplyOpacity() end
        end,
        L.UI_OPACITY_MIN_LABEL or "10%",
        L.UI_OPACITY_MAX_LABEL or "100%",
        function(v) return math.floor(v + 0.5) .. "%" end,
        true  -- liveApply: update opacity on every drag tick
    )
    sf._opacityPane = opacityPane
    sf.SyncOpacity  = function() opacSync() end
    -- Re-applies the current THEME.text colors to all slider labels and thumbs.
    -- Call this from ApplyThemeColors after THEME.text changes.
    sf.RefreshColors = function()
        local t = Addon.THEME.text
        -- Darkened text color for the thumb background (same hue, lower brightness).
        local dR, dG, dB = t.r * 0.45, t.g * 0.45, t.b * 0.45
        -- Slider title labels.
        if sf._scaleTitleLbl then sf._scaleTitleLbl:SetTextColor(t.r, t.g, t.b, 0.75) end
        if sf._opacTitleLbl  then sf._opacTitleLbl:SetTextColor(t.r, t.g, t.b, 0.75)  end
        -- Scale pane min/max labels and thumb.
        local sp = sf._scalePane
        if sp then
            if sp._minLbl   then sp._minLbl:SetTextColor(t.r, t.g, t.b, 0.65)     end
            if sp._maxLbl   then sp._maxLbl:SetTextColor(t.r, t.g, t.b, 0.65)     end
            if sp._thumbTex then sp._thumbTex:SetColorTexture(dR, dG, dB, 0.9)    end
            if sp._thumbLbl then sp._thumbLbl:SetTextColor(t.r, t.g, t.b, 1)      end
        end
        -- Opacity pane min/max labels and thumb.
        local op = sf._opacityPane
        if op then
            if op._minLbl   then op._minLbl:SetTextColor(t.r, t.g, t.b, 0.65)     end
            if op._maxLbl   then op._maxLbl:SetTextColor(t.r, t.g, t.b, 0.65)     end
            if op._thumbTex then op._thumbTex:SetColorTexture(dR, dG, dB, 0.9)    end
            if op._thumbLbl then op._thumbLbl:SetTextColor(t.r, t.g, t.b, 1)      end
        end
    end

    -- â”€â”€ Pane layout â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    -- Repositions the two panes based on which are currently shown.
    -- When only one is visible it expands to full width.
    local function LayoutSliderPanes()
        local sv = scalePane:IsShown()
        local ov = opacityPane:IsShown()
        scalePane:ClearAllPoints()
        opacityPane:ClearAllPoints()
        -- Shift the dividing point 30px right of centre so the opacity pane
        -- sits further to the right (scale pane gets slightly more width).
        local splitOffset = 30
        if sv and ov then
            scalePane:SetPoint("TOPLEFT",  sf, "TOPLEFT",  0,           0)
            scalePane:SetPoint("TOPRIGHT", sf, "TOP",      splitOffset, 0)
            opacityPane:SetPoint("TOPLEFT",  sf, "TOP",      splitOffset, 0)
            opacityPane:SetPoint("TOPRIGHT", sf, "TOPRIGHT", 0,           0)
        elseif sv then
            -- Only scale: keep it in the LEFT half so its position is consistent.
            scalePane:SetPoint("TOPLEFT",  sf, "TOPLEFT",  0,           0)
            scalePane:SetPoint("TOPRIGHT", sf, "TOP",      splitOffset, 0)
        elseif ov then
            -- Only opacity: keep it in the RIGHT half.
            opacityPane:SetPoint("TOPLEFT",  sf, "TOP",      splitOffset, 0)
            opacityPane:SetPoint("TOPRIGHT", sf, "TOPRIGHT", 0,           0)
        end
    end
    sf._layout = LayoutSliderPanes

    sf:SetScript("OnShow", function()
        scaleSync()
        opacSync()
    end)
    scaleSync()
    opacSync()
    LayoutSliderPanes()

    -- Apply saved visibility preferences.
    if Addon.ApplyScaleSliderVisibility then Addon:ApplyScaleSliderVisibility() end
end

