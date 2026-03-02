local addonName = ...
local Addon = _G[addonName]
if not Addon then return end

-- ── Dropdown / popup panel controls ──────────────────────────────────────────
-- Factory functions for floating panels and layout helpers:
--
--   Addon.Controls.NewPopupPanel([strata [, fadeTime]])
--       Dark floating dropdown panel with outside-click catcher pre-wired.
--
--   Addon.Controls.NewDivider(parent [, y [, leftPad [, rightPad]]])
--       1 px horizontal hairline rule in the border theme color.

Addon.Controls = Addon.Controls or {}
local C = Addon.Controls

-- ── Popup panel ───────────────────────────────────────────────────────────────
-- Dark-themed floating dropdown with an outside-click catcher pre-wired.
-- Caller sets size and populates content; all boilerplate is handled here.
--   strata   — frame strata string (default "HIGH")
--   fadeTime — UIFrameFadeIn duration in seconds (default 0.15)
function C.NewPopupPanel(strata, fadeTime)
    local st = strata   or "HIGH"
    local ft = fadeTime or 0.15
    local p = Addon:NewThemedFrame(nil, UIParent)
    if p.SetBackdropColor then
        local pct   = (Addon.db and Addon.db.global and tonumber(Addon.db.global.uiOpacityPct)) or 65
        local alpha = math.max(0, math.min(1.0, pct / 100))
        p:SetBackdropColor(Addon.THEME.bg.r, Addon.THEME.bg.g, Addon.THEME.bg.b, alpha)
    end
    p:SetFrameStrata(st)
    p:SetClampedToScreen(true)
    p:SetSize(200, 40)
    p:Hide()
    p:EnableMouse(true)   -- absorb clicks on empty background so they don't reach the catcher
    if p.SetToplevel   then p:SetToplevel(true)  end
    if p.SetFrameLevel then p:SetFrameLevel(200) end

    local catcher = CreateFrame("Button", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata(st)
    catcher:SetFrameLevel((p.GetFrameLevel and p:GetFrameLevel() or 200) - 1)
    catcher:EnableMouse(true)
    -- Note: SetPropagateMouseClicks is protected and cannot be called by addons.
    -- The _lariasClosedAt timestamp handles the toggle-button re-click case instead.
    catcher:Hide()
    catcher:SetScript("OnMouseDown", function()
        -- Record the time the panel was closed via the outside-click catcher so
        -- that the propagated click arriving at the toggle button does not
        -- immediately reopen it.  A 200 ms window covers the full mouse-down →
        -- mouse-up (OnClick) duration of a normal human click, while a stale
        -- timestamp (>200 ms old) never silently blocks a later toggle click.
        p._lariasClosedAt = GetTime()
        p:Hide()
    end)

    p:SetScript("OnHide", function() catcher:Hide() end)
    p:SetScript("OnShow", function()
        catcher:Show()
        if UIFrameFadeIn then UIFrameFadeIn(p, ft, 0, 1)
        else p:SetAlpha(1) end
    end)
    return p
end

-- ── Color picker ─────────────────────────────────────────────────────────────
-- Thin wrapper around WoW's color picker that supports both the retail 10.x+
-- API (ColorPickerFrame:SetupColorPickerAndShow) and the legacy Classic API.
-- onUpdate(r,g,b) fires live while dragging; onCancel(r,g,b) fires on cancel.
function C.OpenColorPicker(r, g, b, onUpdate, onCancel)
    -- If all channels are near-zero the HSV picker opens with V=0 (solid black),
    -- making H/S impossible to navigate.  Open at mid-grey instead; cancel still
    -- restores the real saved color via the closed-over originals below.
    local nearBlack = (r < 0.08) and (g < 0.08) and (b < 0.08)
    local openR = nearBlack and 0.5 or r
    local openG = nearBlack and 0.5 or g
    local openB = nearBlack and 0.5 or b

    if ColorPickerFrame.SetupColorPickerAndShow then
        -- Retail 10.x+ API.  previousValues and cancel arg are handled internally.
        -- Close over the real originals so the cancel callback always reverts to them.
        local origR, origG, origB = r, g, b
        ColorPickerFrame:SetupColorPickerAndShow({
            r = openR, g = openG, b = openB,
            hasOpacity = false,
            swatchFunc = function()
                local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                onUpdate(nr, ng, nb)
            end,
            cancelFunc = function()
                onCancel(origR, origG, origB)
            end,
        })
    else
        -- Classic / legacy API.  Must call SetColorRGB so GetColorRGB is correct.
        -- previousValues must be a positional array; cancelFunc receives it.
        local origR, origG, origB = r, g, b
        ColorPickerFrame.hasOpacity     = false
        ColorPickerFrame.previousValues = { origR, origG, origB }
        ColorPickerFrame.func = function()
            local nr, ng, nb = ColorPickerFrame:GetColorRGB()
            onUpdate(nr, ng, nb)
        end
        ColorPickerFrame.cancelFunc = function()
            local pv = ColorPickerFrame.previousValues
            onCancel(pv[1], pv[2], pv[3])
        end
        ColorPickerFrame:SetColorRGB(openR, openG, openB)
        ColorPickerFrame:Show()
    end
end

-- ── Divider ───────────────────────────────────────────────────────────────────
-- Creates a 1 px horizontal rule textured in the border theme color.
-- y (negative) sets TOPLEFT Y offset from parent; omit to position manually.
function C.NewDivider(parent, y, leftPad, rightPad)
    local lp = leftPad  or 0
    local rp = rightPad or 0
    local div = parent:CreateTexture(nil, "OVERLAY")
    div:SetHeight(1)
    if Addon.THEME then
        local bdr = Addon.THEME.border
        div:SetColorTexture(bdr.r, bdr.g, bdr.b, 0.5)
    end
    if y then
        div:SetPoint("TOPLEFT",  parent, "TOPLEFT",  lp,  y)
        div:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -rp, y)
    end
    return div
end
