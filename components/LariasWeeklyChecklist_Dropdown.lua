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
        p:SetBackdropColor(Addon.THEME.bg.r, Addon.THEME.bg.g, Addon.THEME.bg.b, 1.0)
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
    -- Propagate so the click still reaches whatever frame is underneath;
    -- without this the catcher eats every click while it is shown.
    if catcher.SetPropagateMouseClicks then catcher:SetPropagateMouseClicks(true) end
    catcher:Hide()
    catcher:SetScript("OnMouseDown", function()
        -- Record the close time rather than a bare boolean.  Toggle functions
        -- ignore re-open requests that arrive within 50 ms (same mouse event
        -- still propagating), but allow later clicks to open normally.
        p._lariasJustClosedAt = GetTime and GetTime() or 0
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
