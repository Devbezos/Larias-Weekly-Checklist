local addonName = ...
local Addon = _G[addonName]
if not Addon then return end

-- â”€â”€ In-frame scale + opacity sliders â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- Two compact custom-styled sliders placed side-by-side at the bottom of the
-- main addon frame, each with a label above the track.
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

    -- Outer container spanning the full bottom width of the frame.
    local sf = CreateFrame("Frame", nil, parentFrame)
    sf:SetPoint("BOTTOMLEFT",  parentFrame, "BOTTOMLEFT",
        Addon.UI.sectionInsetX or 14, Addon.UI.sliderBottomPad or 4)
    sf:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT",
        -(Addon.UI.sectionInsetX or 14), Addon.UI.sliderBottomPad or 4)
    sf:SetHeight(TOTAL_H)
    sf:EnableMouse(true)
    self._inFrameScaleSlider = sf

    -- Re-anchor the slider container's right edge so it stops before the char-
    -- picker button when that button is visible (avoids overlap in the bottom row).
    sf._parentFrame = parentFrame
    sf.AdjustForCpBtn = function(cpBtn)
        local inset   = Addon.UI.sectionInsetX  or 14
        local botPad  = Addon.UI.sliderBottomPad or 4
        local rightInset
        if cpBtn and cpBtn.IsShown and cpBtn:IsShown() then
            local cpW = (cpBtn.GetWidth and math.ceil(cpBtn:GetWidth())) or 108
            rightInset = inset + cpW + 8   -- 8px gap between slider edge and button
        else
            rightInset = inset
        end
        sf:ClearAllPoints()
        sf:SetPoint("BOTTOMLEFT",  parentFrame, "BOTTOMLEFT",  inset,       botPad)
        sf:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", -rightInset, botPad)
    end

    -- BuildSlider: populates `pane` (height = TOTAL_H) with the interactive
    -- track, thumb knob, and min/max labels.  Returns a Sync() closure.
    local function BuildSlider(pane, minV, maxV, stepV, getVal, applyFn,
                               minLabel, maxLabel, fmtFn)
        local USABLE = TRACK_W - THUMB_W

        -- Min label anchored to the bottom-left of the pane (track zone).
        local minLbl = pane:CreateFontString(nil, "OVERLAY")
        minLbl:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        minLbl:SetPoint("BOTTOMLEFT", pane, "BOTTOMLEFT", 0, 0)
        minLbl:SetSize(MIN_LBL_W, SLIDER_H)
        minLbl:SetJustifyH("RIGHT")
        minLbl:SetJustifyV("MIDDLE")
        minLbl:SetWordWrap(false)
        minLbl:SetTextColor(txtD.r, txtD.g, txtD.b, 0.65)
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
        thumbTex:SetColorTexture(txt.r, txt.g, txt.b, 0.9)
        local thumbLbl = thumb:CreateFontString(nil, "OVERLAY")
        thumbLbl:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
        thumbLbl:SetAllPoints(thumb)
        thumbLbl:SetJustifyH("CENTER")
        thumbLbl:SetJustifyV("MIDDLE")
        thumbLbl:SetWordWrap(false)
        thumbLbl:SetTextColor(0, 0, 0, 1)

        -- Max label (right of track).
        local maxLbl = pane:CreateFontString(nil, "OVERLAY")
        maxLbl:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        maxLbl:SetPoint("BOTTOMLEFT", trackCont, "BOTTOMRIGHT", GAP, 0)
        maxLbl:SetSize(MAX_LBL_W, SLIDER_H)
        maxLbl:SetJustifyH("LEFT")
        maxLbl:SetJustifyV("MIDDLE")
        maxLbl:SetWordWrap(false)
        maxLbl:SetTextColor(txtD.r, txtD.g, txtD.b, 0.65)
        maxLbl:SetText(maxLabel)

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
                if v then UpdateVisuals(v) end
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

    local function GetScaleVal()
        local gdb = Addon.db and Addon.db.global
        return (gdb and tonumber(gdb.uiScalePct)) or 100
    end

    local scaleSync = BuildSlider(
        scalePane, 50, 150, 1,
        GetScaleVal,
        function(pct)
            local gdb = Addon.db and Addon.db.global
            if gdb then gdb.uiScalePct = pct end
            if Addon.ApplyUIScale then Addon:ApplyUIScale() end
        end,
        L.UI_SCALE_MIN_LABEL or "50%",
        L.UI_SCALE_MAX_LABEL or "150%",
        function(v)
            local r = math.floor(v + 0.5)
            return (r >= 150) and "unc." or (r .. "%")
        end
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
        function(v) return math.floor(v + 0.5) .. "%" end
    )
    sf._opacityPane = opacityPane
    sf.SyncOpacity  = function() opacSync() end

    -- â”€â”€ Pane layout â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    -- Repositions the two panes based on which are currently shown.
    -- When only one is visible it expands to full width.
    local function LayoutSliderPanes()
        local sv = scalePane:IsShown()
        local ov = opacityPane:IsShown()
        scalePane:ClearAllPoints()
        opacityPane:ClearAllPoints()
        if sv and ov then
            -- Side by side: each takes exactly half of sf's width.
            scalePane:SetPoint("TOPLEFT",  sf, "TOPLEFT",  0, 0)
            scalePane:SetPoint("TOPRIGHT", sf, "TOP",      0, 0)
            opacityPane:SetPoint("TOPLEFT",  sf, "TOP",      0, 0)
            opacityPane:SetPoint("TOPRIGHT", sf, "TOPRIGHT", 0, 0)
        elseif sv then
            scalePane:SetPoint("TOPLEFT",  sf, "TOPLEFT",  0, 0)
            scalePane:SetPoint("TOPRIGHT", sf, "TOPRIGHT", 0, 0)
        elseif ov then
            opacityPane:SetPoint("TOPLEFT",  sf, "TOPLEFT",  0, 0)
            opacityPane:SetPoint("TOPRIGHT", sf, "TOPRIGHT", 0, 0)
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

