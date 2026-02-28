local addonName = ...
local Addon = _G[addonName]
if not Addon then return end

-- ── Button controls ───────────────────────────────────────────────────────────
-- Factory functions for all custom-styled button types:
--
--   Addon.Controls.StyleButton(btn)
--       Apply the addon's dark-backdrop action-button style to any Button.
--
--   Addon.Controls.NewCloseButton(parent [, onClick])
--       Branded 20×20 ✕ button: dark backdrop, gold glyph, red hover/push,
--       "Close" tooltip. onClick defaults to parent:Hide().
--
--   Addon.Controls.NewIconButton(parent, texturePath [, onClick [, tooltip]])
--       Branded 20×20 icon button (any texture), dark backdrop, gold hover.
--
--   Addon.Controls.NewExpandButton(parent [, onToggle [, initialExpanded
--                                  [, expandTip [, shrinkTip]]]])
--       Branded 20×20 toggle button: dark backdrop, gold ▼/▲ glyph, white hover.

Addon.Controls = Addon.Controls or {}
local C = Addon.Controls

-- ── Action button styler ──────────────────────────────────────────────────────
-- Strips Blizzard default art and applies the addon's dark-backdrop theme.
-- Replaces the old local StyleMainTabButton / Addon._styleActionButton.
function C.StyleButton(btn)
    if not btn then return end

    Addon:ApplyTheme(btn)
    -- Buttons use a slightly lower bg alpha than panels.
    if btn.SetBackdropColor then
        local T = Addon.THEME
        if T then
            btn:SetBackdropColor(T.bg.r, T.bg.g, T.bg.b, math.max(0, (tonumber(T.bg.a) or 1) - 0.28))
        end
    end

    local function ClearTex(t)
        if not t then return end
        if t.SetTexture then t:SetTexture(nil) end
        if t.SetAlpha   then t:SetAlpha(0)     end
        if t.Hide       then t:Hide()          end
    end
    if btn.GetNormalTexture    then ClearTex(btn:GetNormalTexture())    end
    if btn.GetPushedTexture    then ClearTex(btn:GetPushedTexture())    end
    if btn.GetDisabledTexture  then ClearTex(btn:GetDisabledTexture())  end
    if btn.GetHighlightTexture then ClearTex(btn:GetHighlightTexture()) end

    if btn.Left   and btn.Left.Hide   then btn.Left:Hide()   end
    if btn.Middle and btn.Middle.Hide then btn.Middle:Hide() end
    if btn.Right  and btn.Right.Hide  then btn.Right:Hide()  end

    if btn.SetTextInsets then btn:SetTextInsets(12, 12, 4, 4) end

    local tr = btn.Text or (btn.GetFontString and btn:GetFontString())
    if tr then
        if tr.SetJustifyV then tr:SetJustifyV("MIDDLE") end
        if tr.ClearAllPoints and tr.SetPoint then
            tr:ClearAllPoints()
            tr:SetPoint("CENTER", btn, "CENTER", 0, 0)
        end
        if tr.SetTextColor then tr:SetTextColor(1, 1, 1, 1) end
    end

    if btn.CreateTexture and not btn._lariasCustomHighlight then
        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(btn)
        local T = Addon.THEME
        if T then
            hl:SetColorTexture(T.text.r, T.text.g, T.text.b, 0.06)
        else
            hl:SetColorTexture(1, 1, 1, 0.06)
        end
        btn._lariasCustomHighlight = hl
    end

    btn._lariasTabStyled = true
end

-- Expose as the legacy global reference so all existing code that calls
-- Addon._styleActionButton(btn) continues to work without any changes.
Addon._styleActionButton = C.StyleButton

-- ── Close button ──────────────────────────────────────────────────────────────
-- Creates and returns a branded 20×20 close button as a child of `parent`.
-- Design: dark backdrop matching the frame theme, gold "✕" glyph at rest,
-- white glyph + red bg tint on hover, deeper red on push, "Close" tooltip.
-- onClick defaults to hiding parent.  Caller is responsible for positioning.
function C.NewCloseButton(parent, onClick)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(20, 20)

    Addon:ApplyTheme(btn)

    local T  = Addon.THEME or {}
    local th = T.header or { r = 1.00, g = 0.82, b = 0.00 }  -- gold accent

    local norm = btn:CreateFontString(nil, "OVERLAY")
    norm:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
    norm:SetAllPoints(btn)
    norm:SetJustifyH("CENTER")
    norm:SetJustifyV("MIDDLE")
    norm:SetTextColor(th.r, th.g, th.b, 1)
    norm:SetText("\195\151")  -- × (U+00D7)
    btn:SetFontString(norm)

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(btn)
    hl:SetColorTexture(0.85, 0.10, 0.10, 0.30)
    btn:SetHighlightTexture(hl)

    local pushed = btn:CreateTexture(nil, "OVERLAY")
    pushed:SetAllPoints(btn)
    pushed:SetColorTexture(0.85, 0.10, 0.10, 0.50)
    btn:SetPushedTexture(pushed)

    btn:SetScript("OnEnter", function()
        norm:SetTextColor(1, 1, 1, 1)
        local tip = (Addon.L and Addon.L.CLOSE) or "Close"
        GameTooltip:SetOwner(btn, "ANCHOR_BOTTOMLEFT")
        GameTooltip:SetText(tip, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        norm:SetTextColor(th.r, th.g, th.b, 1)
        GameTooltip:Hide()
    end)

    btn:SetScript("OnClick", onClick or function() parent:Hide() end)
    -- Allow ApplyThemeColors to refresh the glyph color when header color changes.
    function btn:RefreshColor()
        local _th = Addon.THEME and Addon.THEME.header or th
        norm:SetTextColor(_th.r, _th.g, _th.b, 1)
    end
    return btn
end

-- ── Generic icon button ───────────────────────────────────────────────────────
-- Creates a 20×20 branded icon button with any texture (2 px inset so the dark
-- backdrop border shows around it). White at rest, gold on hover.
-- onClick defaults to a no-op.
function C.NewIconButton(parent, texturePath, onClick, tooltip)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(20, 20)

    Addon:ApplyTheme(btn)

    local T  = Addon.THEME or {}
    local tt = T.text   or { r = 1, g = 1, b = 1 }
    local th = T.header or { r = 1, g = 0.82, b = 0 }

    local PAD = 2
    local norm = btn:CreateTexture(nil, "BORDER")
    norm:SetTexture(texturePath)
    norm:SetPoint("TOPLEFT",     btn, "TOPLEFT",      PAD, -PAD)
    norm:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -PAD,  PAD)
    norm:SetVertexColor(tt.r, tt.g, tt.b, 0.65)
    btn:SetNormalTexture(norm)

    local pushed = btn:CreateTexture(nil, "OVERLAY")
    pushed:SetTexture(texturePath)
    pushed:SetPoint("TOPLEFT",     btn, "TOPLEFT",      PAD, -PAD)
    pushed:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -PAD,  PAD)
    pushed:SetVertexColor(th.r * 0.75, th.g * 0.75, th.b * 0.75, 1)
    btn:SetPushedTexture(pushed)

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(btn)
    hl:SetColorTexture(1, 1, 1, 0.10)
    btn:SetHighlightTexture(hl)

    btn:SetScript("OnEnter", function(self_)
        norm:SetVertexColor(th.r, th.g, th.b, 1)
        if tooltip then
            GameTooltip:SetOwner(self_, "ANCHOR_BOTTOMLEFT")
            GameTooltip:SetText(tooltip, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function()
        norm:SetVertexColor(tt.r, tt.g, tt.b, 0.65)
        GameTooltip:Hide()
    end)

    btn:SetScript("OnClick", onClick or function() end)
    -- Allow ApplyThemeColors to refresh the icon tint when text color changes.
    function btn:RefreshColor()
        local _tt = Addon.THEME and Addon.THEME.text or tt
        norm:SetVertexColor(_tt.r, _tt.g, _tt.b, 0.65)
    end
    return btn
end

-- ── Expand / shrink button ────────────────────────────────────────────────────
-- Branded 20×20 toggle button: dark backdrop, gold ▼/▲ glyph, white on hover.
--
-- initialExpanded=true  → shows ▼ ("content visible; click to shrink")
-- initialExpanded=false → shows ▲ ("content hidden; click to expand")
--
-- btn._expanded        — current state (bool)
-- btn:SetExpanded(val) — update state + glyph + tooltip without firing onToggle
function C.NewExpandButton(parent, onToggle, initialExpanded, expandTip, shrinkTip)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(20, 20)
    Addon:ApplyTheme(btn)

    local T  = Addon.THEME or {}
    local th = T.header or { r = 1.00, g = 0.82, b = 0.00 }

    local _expandTip = expandTip or "Expand"
    local _shrinkTip = shrinkTip or "Shrink"

    -- Use WoW scrollbar arrow textures: reliable across all WoW clients and
    -- fonts, unlike Unicode glyphs which FRIZQT__.TTF doesn't contain.
    local TEX_DOWN = "Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up"
    local TEX_UP   = "Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up"

    local normTex = btn:CreateTexture(nil, "ARTWORK")
    normTex:SetAllPoints(btn)
    normTex:SetVertexColor(th.r, th.g, th.b, 1)
    btn:SetNormalTexture(normTex)

    local hlTex = btn:CreateTexture(nil, "HIGHLIGHT")
    hlTex:SetAllPoints(btn)
    hlTex:SetColorTexture(1, 1, 1, 0.10)
    btn:SetHighlightTexture(hlTex)

    local pushedTex = btn:CreateTexture(nil, "ARTWORK")
    pushedTex:SetAllPoints(btn)
    pushedTex:SetVertexColor(1, 1, 1, 1)
    btn:SetPushedTexture(pushedTex)

    btn._expanded = (initialExpanded ~= false)

    local function RefreshGlyph()
        local tex = btn._expanded and TEX_DOWN or TEX_UP
        normTex:SetTexture(tex)
        pushedTex:SetTexture(tex)
    end

    function btn:SetExpanded(val)
        self._expanded = val and true or false
        RefreshGlyph()
    end

    RefreshGlyph()

    btn:SetScript("OnEnter", function(self_)
        normTex:SetVertexColor(1, 1, 1, 1)
        local tip = self_._expanded and _shrinkTip or _expandTip
        GameTooltip:SetOwner(self_, "ANCHOR_BOTTOMLEFT")
        GameTooltip:SetText(tip, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        normTex:SetVertexColor(th.r, th.g, th.b, 1)
        GameTooltip:Hide()
    end)
    btn:SetScript("OnClick", function(self_)
        self_:SetExpanded(not self_._expanded)
        if onToggle then onToggle(self_._expanded) end
        if GameTooltip:GetOwner() == self_ then
            local tip = self_._expanded and _shrinkTip or _expandTip
            GameTooltip:SetText(tip, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)

    return btn
end
