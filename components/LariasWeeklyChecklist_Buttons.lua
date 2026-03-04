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

    local T = Addon.THEME  -- single reference; all uses below share this upvalue

    Addon:ApplyTheme(btn)
    -- Buttons use a slightly lower bg alpha than panels.
    if btn.SetBackdropColor and T then
        btn:SetBackdropColor(T.bg.r, T.bg.g, T.bg.b, math.max(0, (tonumber(T.bg.a) or 1) - 0.28))
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
        if tr.SetTextColor then
            if T and T.text then tr:SetTextColor(T.text.r, T.text.g, T.text.b, T.text.a or 1)
            else                 tr:SetTextColor(1, 1, 1, 1) end
        end
    end

    if btn.CreateTexture and not btn._lariasCustomHighlight then
        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(btn)
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

-- Applies a fixed dark backdrop (not theme-driven) to header icon buttons so
-- they never change color when the user adjusts the background theme.
local function ApplyFixedBackdrop(btn)
    if not btn.SetBackdrop and BackdropTemplateMixin and Mixin then
        Mixin(btn, BackdropTemplateMixin)
    end
    if btn.SetBackdrop then
        btn:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile = false, edgeSize = 1,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        btn:SetBackdropColor(0.08, 0.08, 0.08, 0.85)
        local bd = Addon.THEME and Addon.THEME.border or { r=0.3, g=0.3, b=0.3, a=0.8 }
        btn:SetBackdropBorderColor(bd.r, bd.g, bd.b, bd.a)
    end
end

-- ── Close button ──────────────────────────────────────────────────────────────
-- Creates and returns a branded 20×20 close button as a child of `parent`.
-- Design: fixed dark backdrop, gold "✕" glyph at rest, white glyph + red bg
-- tint on hover, deeper red on push, "Close" tooltip.
-- onClick defaults to hiding parent.  Caller is responsible for positioning.
function C.NewCloseButton(parent, onClick)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(20, 20)
    ApplyFixedBackdrop(btn)

    -- Fixed colors: intentionally NOT driven by theme so the × never changes
    -- when the user adjusts the header color.
    local CLOSE_R, CLOSE_G, CLOSE_B = 1.00, 0.82, 0.00

    local norm = btn:CreateFontString(nil, "OVERLAY")
    norm:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
    norm:SetAllPoints(btn)
    norm:SetJustifyH("CENTER")
    norm:SetJustifyV("MIDDLE")
    norm:SetTextColor(CLOSE_R, CLOSE_G, CLOSE_B, 1)
    norm:SetText("\195\151")  -- × (U+00D7)
    btn:SetFontString(norm)
    -- _lariasCloseGlyph intentionally not stored — ApplyThemeColors must not restyle this button.

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
        norm:SetTextColor(CLOSE_R, CLOSE_G, CLOSE_B, 1)
        GameTooltip:Hide()
    end)

    btn:SetScript("OnClick", onClick or function() parent:Hide() end)
    return btn
end

-- ── Generic icon button ───────────────────────────────────────────────────────
-- Creates a 20×20 branded icon button with any texture (2 px inset so the dark
-- backdrop border shows around it). Fixed dim-white at rest, fixed gold on hover.
-- onClick defaults to a no-op.
function C.NewIconButton(parent, texturePath, onClick, tooltip)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(20, 20)
    ApplyFixedBackdrop(btn)

    -- Fixed colors — intentionally NOT driven by theme so the icon never
    -- changes color when the user adjusts text/header theme colors.
    local REST_R, REST_G, REST_B, REST_A = 0.75, 0.75, 0.75, 0.65  -- dim white
    local HOV_R,  HOV_G,  HOV_B         = 1.00, 0.82, 0.00         -- gold

    local PAD = 2
    -- Keep norm as a plain BORDER texture (not registered via SetNormalTexture).
    -- Using SetNormalTexture would let WoW's button state machinery reset vertex
    -- colors on click→release transitions, causing color flicker.
    local norm = btn:CreateTexture(nil, "BORDER")
    norm:SetTexture(texturePath)
    norm:SetPoint("TOPLEFT",     btn, "TOPLEFT",      PAD, -PAD)
    norm:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -PAD,  PAD)
    norm:SetVertexColor(REST_R, REST_G, REST_B, REST_A)

    -- Pushed overlay shown during click; lives above the norm texture.
    local pushed = btn:CreateTexture(nil, "OVERLAY")
    pushed:SetTexture(texturePath)
    pushed:SetPoint("TOPLEFT",     btn, "TOPLEFT",      PAD, -PAD)
    pushed:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -PAD,  PAD)
    pushed:SetVertexColor(HOV_R * 0.45, HOV_G * 0.45, HOV_B * 0.45, 1)
    pushed:Hide()

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(btn)
    hl:SetColorTexture(1, 1, 1, 0.10)
    btn:SetHighlightTexture(hl)

    btn:SetScript("OnEnter", function(self_)
        norm:SetVertexColor(HOV_R, HOV_G, HOV_B, 1)
        if tooltip then
            GameTooltip:SetOwner(self_, "ANCHOR_BOTTOMLEFT")
            GameTooltip:SetText(tooltip, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function()
        norm:SetVertexColor(REST_R, REST_G, REST_B, REST_A)
        pushed:Hide()
        GameTooltip:Hide()
    end)
    btn:SetScript("OnMouseDown", function()
        pushed:Show()
        norm:SetVertexColor(HOV_R * 0.45, HOV_G * 0.45, HOV_B * 0.45, 1)
    end)
    btn:SetScript("OnMouseUp", function()
        pushed:Hide()
        -- Mouse is still on the button after a click; restore hover color.
        norm:SetVertexColor(HOV_R, HOV_G, HOV_B, 1)
    end)

    btn:SetScript("OnClick", onClick or function() end)
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
    ApplyFixedBackdrop(btn)

    -- Fixed colors — intentionally NOT driven by theme so the arrow never
    -- changes color when the user adjusts header/background theme colors.
    local REST_R, REST_G, REST_B, REST_A = 0.75, 0.75, 0.75, 0.65  -- dim white
    local HOV_R,  HOV_G,  HOV_B         = 1.00, 1.00, 1.00         -- white

    local _expandTip = expandTip or "Expand"
    local _shrinkTip = shrinkTip or "Shrink"

    -- Use WoW scrollbar arrow textures: reliable across all WoW clients and
    -- fonts, unlike Unicode glyphs which FRIZQT__.TTF doesn't contain.
    local TEX_DOWN = "Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up"
    local TEX_UP   = "Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up"

    local PAD = 2
    local normTex = btn:CreateTexture(nil, "BORDER")
    normTex:SetPoint("TOPLEFT",     btn, "TOPLEFT",      PAD, -PAD)
    normTex:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -PAD,  PAD)
    normTex:SetVertexColor(REST_R, REST_G, REST_B, REST_A)

    local hlTex = btn:CreateTexture(nil, "HIGHLIGHT")
    hlTex:SetAllPoints(btn)
    hlTex:SetColorTexture(1, 1, 1, 0.10)
    btn:SetHighlightTexture(hlTex)

    local pushedTex = btn:CreateTexture(nil, "OVERLAY")
    pushedTex:SetPoint("TOPLEFT",     btn, "TOPLEFT",      PAD, -PAD)
    pushedTex:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -PAD,  PAD)
    pushedTex:SetVertexColor(HOV_R * 0.45, HOV_G * 0.45, HOV_B * 0.45, 1)
    pushedTex:Hide()

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
        normTex:SetVertexColor(HOV_R, HOV_G, HOV_B, 1)
        local tip = self_._expanded and _shrinkTip or _expandTip
        GameTooltip:SetOwner(self_, "ANCHOR_BOTTOMLEFT")
        GameTooltip:SetText(tip, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        normTex:SetVertexColor(REST_R, REST_G, REST_B, REST_A)
        pushedTex:Hide()
        GameTooltip:Hide()
    end)
    btn:SetScript("OnMouseDown", function()
        pushedTex:Show()
        normTex:SetVertexColor(HOV_R * 0.45, HOV_G * 0.45, HOV_B * 0.45, 1)
    end)
    btn:SetScript("OnMouseUp", function()
        pushedTex:Hide()
        normTex:SetVertexColor(HOV_R, HOV_G, HOV_B, 1)
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
