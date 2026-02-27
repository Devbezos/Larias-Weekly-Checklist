local addonName = ...
local Addon = _G[addonName]
if not Addon then return end

-- ── Shared custom UI controls ─────────────────────────────────────────────────
-- Factory functions for every custom-styled button and checkbox used throughout
-- the addon. Define once here, call everywhere:
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
--       Use this for all icon-based buttons (gear, ilvl ref, etc.).
--
--   Addon.Controls.NewPopupPanel([strata [, fadeTime]])
--       Dark floating dropdown panel with outside-click catcher pre-wired.
--
--   Addon.Controls.NewDivider(parent [, y [, leftPad [, rightPad]]])
--       1 px horizontal hairline rule in the border theme color.
--
--   Addon.Controls.NewCheckBox(parent [, onToggle [, boxSize]])
--       Fully custom checkbox: dark square, gold ✓ glyph, no Blizzard art.
--       cb.text/cb._label = label FontString; cb._box = visual frame; cb._hit = hit area.
--       cb:GetChecked() / cb:SetChecked(bool). onToggle(checked:bool) fires on click.
--
--   Addon.Controls.NewExpandButton(parent [, onToggle [, initialExpanded
--                                  [, expandTip [, shrinkTip]]]])
--       Branded 20×20 toggle button: dark backdrop, gold ▼/▲ glyph, white hover.
--       btn._expanded        — current state (bool)
--       btn:SetExpanded(val) — update state + glyph + tooltip without firing onToggle

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

    -- Backdrop: same dark panel look as the rest of the addon.
    Addon:ApplyTheme(btn)

    local T  = Addon.THEME or {}
    local th = T.header or { r = 1.00, g = 0.82, b = 0.00 }  -- gold accent

    -- Glyph: Unicode heavy multiplication sign looks cleaner than ASCII "X".
    local norm = btn:CreateFontString(nil, "OVERLAY")
    norm:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
    norm:SetAllPoints(btn)
    norm:SetJustifyH("CENTER")
    norm:SetJustifyV("MIDDLE")
    norm:SetTextColor(th.r, th.g, th.b, 1)
    norm:SetText("\195\151")  -- × (U+00D7) — Latin-1 supported in all WoW fonts
    btn:SetFontString(norm)

    -- Hover: red bg tint (universal "danger/close" signal).
    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(btn)
    hl:SetColorTexture(0.85, 0.10, 0.10, 0.30)
    btn:SetHighlightTexture(hl)

    -- Push: deeper red flash.
    local pushed = btn:CreateTexture(nil, "OVERLAY")
    pushed:SetAllPoints(btn)
    pushed:SetColorTexture(0.85, 0.10, 0.10, 0.50)
    btn:SetPushedTexture(pushed)

    -- Text transitions gold → white on hover for contrast over the red bg.
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
    return btn
end

-- ── Generic icon button ─────────────────────────────────────────────────────────────
-- Creates a 20×20 branded icon button with any texture (2 px inset so the dark
-- backdrop border shows around it). White at rest, gold on hover. Tooltip shown
-- on mouse-over.  onClick defaults to a no-op.
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
    return btn
end

-- ── Popup panel ─────────────────────────────────────────────────────────────
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
    if p.SetToplevel   then p:SetToplevel(true)  end
    if p.SetFrameLevel then p:SetFrameLevel(200) end
    local catcher = CreateFrame("Button", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata(st)
    catcher:SetFrameLevel((p.GetFrameLevel and p:GetFrameLevel() or 200) - 1)
    catcher:EnableMouse(true)
    catcher:Hide()
    catcher:SetScript("OnMouseDown", function() p:Hide() end)
    p:SetScript("OnHide", function() catcher:Hide() end)
    p:SetScript("OnShow", function()
        catcher:Show()
        if UIFrameFadeIn then UIFrameFadeIn(p, ft, 0, 1)
        else p:SetAlpha(1) end
    end)
    return p
end

-- ── Divider ─────────────────────────────────────────────────────────────
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

-- ── Checkbox ──────────────────────────────────────────────────────────────────
-- Fully addon-themed checkbox — no Blizzard UICheckButtonTemplate used.
--
-- Visual:  dark bordered square (_box) with a gold ✓ glyph when checked.
-- Layout:  label FontString (.text / ._label) anchored LEFT of the box.
--          No right anchor set — caller adds cb._label:SetPoint("RIGHT",...)
--          or calls textLabel:SetWidth(w) for multi-line row use.
--
-- Pooling: _box, _label/_tick are children of cb → survive SetParent() safely.
-- Hit:     _hit is an unsized Button (child of cb at parent's frame level).
--          Caller positions + sizes it for full-row click coverage.
--
-- API shims (CheckButton-compatible):
--   cb:GetChecked()     → bool
--   cb:SetChecked(val)  → sets _checked, shows/hides tick
--   cb:RefreshTint()    → no-op (no Blizzard textures to re-tint)
--
-- onToggle(checked:bool) fires after every click via cb or _hit (NOT SetChecked).
-- boxSize defaults to 16.
function C.NewCheckBox(parent, onToggle, boxSize)
    boxSize = boxSize or 16

    local T  = Addon.THEME or {}
    local th = T.header or { r = 1.00, g = 0.82, b = 0.00, a = 1 }
    local tc = T.text   or { r = 1,    g = 1,    b = 1,    a = 1 }

    -- Outer button: interaction container.  Caller may SetHeight for multiline rows.
    local cb = CreateFrame("Button", nil, parent)
    cb:SetSize(boxSize, boxSize)

    -- Visual box: fixed size, always pinned to the top-left corner of cb.
    local box = CreateFrame("Frame", nil, cb)
    box:SetSize(boxSize, boxSize)
    box:SetPoint("TOPLEFT", cb, "TOPLEFT", 0, 0)
    Addon:ApplyTheme(box)
    cb._box = box

    -- HIGHLIGHT anchored to the box area (cb is a Button so HIGHLIGHT works).
    local hl = cb:CreateTexture(nil, "HIGHLIGHT")
    hl:SetPoint("TOPLEFT",     box, "TOPLEFT",     0, 0)
    hl:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
    hl:SetColorTexture(1, 1, 1, 0.15)

    -- Gold checkmark glyph: ✓ U+2713 = \226\156\147.
    local tick = box:CreateFontString(nil, "OVERLAY")
    tick:SetFont("Fonts\\FRIZQT__.TTF", math.floor(boxSize * 0.75), "OUTLINE")
    tick:SetAllPoints(box)
    tick:SetJustifyH("CENTER")
    tick:SetJustifyV("MIDDLE")
    tick:SetTextColor(th.r, th.g, th.b, 1)
    tick:SetText("\226\156\147")   -- ✓
    tick:Hide()
    cb._tick = tick

    -- Label FontString: child of cb so it survives SetParent / pool reuse.
    local lbl = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetPoint("LEFT", box, "RIGHT", 4, 0)
    lbl:SetJustifyH("LEFT")
    if lbl.SetWordWrap then lbl:SetWordWrap(true) end
    lbl:SetTextColor(tc.r, tc.g, tc.b, tc.a or 1)
    cb._label = lbl
    cb.text   = lbl   -- compat: code reads checkbox.text or checkbox.Text

    -- Hit area: unsized Button child of cb; caller positions and sizes it.
    local hit = CreateFrame("Button", nil, cb)
    hit:SetFrameLevel(parent:GetFrameLevel())
    local hitHl = hit:CreateTexture(nil, "HIGHLIGHT")
    hitHl:SetAllPoints(hit)
    hitHl:SetColorTexture(1, 1, 1, 0.06)
    cb._hit = hit

    -- State API ---------------------------------------------------------------
    cb._checked = false

    function cb:GetChecked()
        return self._checked
    end

    function cb:SetChecked(val)
        self._checked = val and true or false
        if self._checked then tick:Show() else tick:Hide() end
    end

    function cb:RefreshTint()
        -- No-op: compat shim for callers that still invoke it.
    end

    -- Clicks ------------------------------------------------------------------
    cb:SetScript("OnClick", function(self_)
        self_:SetChecked(not self_._checked)
        if onToggle then onToggle(self_._checked) end
    end)
    hit:SetScript("OnClick", function()
        local newVal = not cb._checked
        cb:SetChecked(newVal)
        if onToggle then onToggle(newVal) end
    end)

    return cb
end

-- ── Expand / shrink button ────────────────────────────────────────────────────
-- Branded 20×20 toggle button: dark backdrop, gold ▼/▲ glyph, white on hover.
--
-- initialExpanded=true  → shows ▼ ("content visible; click to shrink")
-- initialExpanded=false → shows ▲ ("content hidden; click to expand")
--
-- expandTip / shrinkTip  — tooltip text shown when content IS shrunk/expanded.
--   Defaults: "Expand" / "Shrink"
-- onToggle(expanded:bool) fires after each click (NOT from SetExpanded).
--
-- btn._expanded        — current state (bool)
-- btn:SetExpanded(val) — update state + glyph + tooltip without firing onToggle
function C.NewExpandButton(parent, onToggle, initialExpanded, expandTip, shrinkTip)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(20, 20)
    Addon:ApplyTheme(btn)

    local T  = Addon.THEME or {}
    local th = T.header or { r = 1.00, g = 0.82, b = 0.00 }  -- gold

    -- ▼ U+25BC = \226\150\188 (expanded: click to shrink)
    -- ▲ U+25B2 = \226\150\178 (shrunk:   click to expand)
    local GLYPH_DOWN = "\226\150\188"
    local GLYPH_UP   = "\226\150\178"

    local _expandTip = expandTip or "Expand"
    local _shrinkTip = shrinkTip or "Shrink"

    local norm = btn:CreateFontString(nil, "OVERLAY")
    norm:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    norm:SetAllPoints(btn)
    norm:SetJustifyH("CENTER")
    norm:SetJustifyV("MIDDLE")
    norm:SetTextColor(th.r, th.g, th.b, 1)
    btn:SetFontString(norm)

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(btn)
    hl:SetColorTexture(1, 1, 1, 0.10)
    btn:SetHighlightTexture(hl)

    btn._expanded = (initialExpanded ~= false)

    -- Internal helper ─ sync glyph; does NOT touch tooltip (OnEnter handles that).
    local function RefreshGlyph()
        norm:SetText(btn._expanded and GLYPH_DOWN or GLYPH_UP)
    end

    function btn:SetExpanded(val)
        self._expanded = val and true or false
        RefreshGlyph()
    end

    RefreshGlyph()

    btn:SetScript("OnEnter", function(self_)
        norm:SetTextColor(1, 1, 1, 1)
        local tip = self_._expanded and _shrinkTip or _expandTip
        GameTooltip:SetOwner(self_, "ANCHOR_BOTTOMLEFT")
        GameTooltip:SetText(tip, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        norm:SetTextColor(th.r, th.g, th.b, 1)
        GameTooltip:Hide()
    end)
    btn:SetScript("OnClick", function(self_)
        self_:SetExpanded(not self_._expanded)
        if onToggle then onToggle(self_._expanded) end
        -- Refresh the tooltip text live if the cursor is still over the button.
        if GameTooltip:GetOwner() == self_ then
            local tip = self_._expanded and _shrinkTip or _expandTip
            GameTooltip:SetText(tip, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)

    return btn
end
