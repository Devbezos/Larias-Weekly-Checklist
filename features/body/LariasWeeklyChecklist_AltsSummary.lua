-- LariasWeeklyChecklist_AltsSummary.lua
-- Alt Summary popup: horizontal table — characters as columns, stats as rows.
-- Row groups: Character header | Tasks | Crests (per tier) | Currencies | Great Vault (per activity)
local addonName = ...
local Addon = _G[addonName]
if not Addon then return end
local L = Addon.L or {}
local AU = Addon.AddonUtils
local GetCurrencyIcon = AU.GetCurrencyIcon
local GetCurrencyName = AU.GetCurrencyName
local GetItemName = AU.GetItemName

-- ── Layout constants ──────────────────────────────────────────────────────────
local PAD        = 8
local TITLE_H    = 28
local ROW_H      = 23          -- height of each data row
local HDR_ROW_H  = 27          -- height of section label rows
local COL_LABEL  = 124         -- width of the left-side row label column (wider for icon+text)
local COL_W      = 104         -- width of each character column (slightly thinner)
local ICON_SIZE  = 15          -- currency icon width/height in row labels
local COL_HDR_H  = 36          -- class bar + name + ilvl; date lives in the tooltip

local NUM_CRESTS = 5
local CREST_ABBREV = { "Adv", "Vet", "Chp", "Hero", "Myth" }
local GV_NAMES     = { "Raid", "M+ / Delve", "World" }
local GV_THRESHOLDS = { {2,4,6}, {1,4,8}, {2,4,8} }

-- Read from TRACKING so Overlay.lua (which captures the data) uses the same list.
local GEAR_SLOT_IDS  = (Addon.TRACKING and Addon.TRACKING.gearSlotIDs)
                       or {1,2,3,5,6,7,8,9,10,11,12,13,14,15,16,17}
local GEAR_SLOT_NAMES = {
    [1]=L.ALT_SUMMARY_GEAR_SLOT_HEAD or "Head",
    [2]=L.ALT_SUMMARY_GEAR_SLOT_NECK or "Neck",
    [3]=L.ALT_SUMMARY_GEAR_SLOT_SHOULDERS or "Shoulders",
    [5]=L.ALT_SUMMARY_GEAR_SLOT_CHEST or "Chest",
    [6]=L.ALT_SUMMARY_GEAR_SLOT_WAIST or "Waist",
    [7]=L.ALT_SUMMARY_GEAR_SLOT_LEGS or "Legs",
    [8]=L.ALT_SUMMARY_GEAR_SLOT_FEET or "Feet",
    [9]=L.ALT_SUMMARY_GEAR_SLOT_WRISTS or "Wrists",
    [10]=L.ALT_SUMMARY_GEAR_SLOT_HANDS or "Hands",
    [11]=L.ALT_SUMMARY_GEAR_SLOT_RING1 or "Ring 1",
    [12]=L.ALT_SUMMARY_GEAR_SLOT_RING2 or "Ring 2",
    [13]=L.ALT_SUMMARY_GEAR_SLOT_TRINKET1 or "Trinket 1",
    [14]=L.ALT_SUMMARY_GEAR_SLOT_TRINKET2 or "Trinket 2",
    [15]=L.ALT_SUMMARY_GEAR_SLOT_BACK or "Back",
    [16]=L.ALT_SUMMARY_GEAR_SLOT_MAIN_HAND or "Main Hand",
    [17]=L.ALT_SUMMARY_GEAR_SLOT_OFF_HAND or "Off Hand",
}
local WEAP_UPG_MAX_ILVL = 298
local WEAP_UPG_SLOTS    = { 13, 14, 16, 17 }

-- ── Alpha constants ────────────────────────────────────────────────────
local A_FULL    = 1.00   -- present, data available
local A_EMPTY   = 0.50   -- present but zero / not progressed
local A_DIM     = 0.45   -- no data / placeholder
local A_ILVL    = 0.85   -- ilvl label (slightly dimmed)
local FONT_SM   = 11     -- small font: ilvl, sub-labels
local FONT_CELL = 12     -- standard cell font
local DRAG_THRESHOLD = 10
local FONT_FACE  = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local FONT_FLAGS = "OUTLINE"

-- Alt Summary visual tuning.  These keep the table compact while borrowing
-- the softer, banded rhythm of larger roster dashboards.
local VS = Addon.VISUAL_STYLE or {}
local STYLE = {
    headerBandA    = VS.sectionBandA or 0.08,
    headerLineA    = VS.strongDividerA or 0.22,
    sectionBandA   = 0.045,
    sectionLineA   = VS.sectionAccentA or 0.16,
    rowLightA      = 0.018,
    rowDarkA       = 0.044,
    rowLineA       = 0.030,
    colLineA       = 0.040,
    classBarA      = 0.42,
    hoverA         = 0.090,
    hoverColA      = 0.045,
}
local PLACEHOLDER_DASH = Addon.PLACEHOLDER_DASH or "\226\128\148"

local function GetPanelChromeAlpha()
    if Addon and Addon.GetUIOpacityAlpha then
        return Addon:GetUIOpacityAlpha()
    end
    return 1.0
end

local function SetPlaceholder(cell, th, alpha)
    th = th or (Addon.THEME and Addon.THEME.text) or { r = 1, g = 1, b = 1 }
    if not (cell and cell._fs) then return end
    cell._fs:SetText(PLACEHOLDER_DASH)
    cell._fs:SetTextColor(th.r, th.g, th.b, alpha or A_DIM)
end

-- ── Module state ──────────────────────────────────────────────────────────────
local altSummaryFrame
local _showHidden  = false
local _layout      = nil
-- Row-defs cache: rebuilt when visibility or gear-cost state can change row presence.
-- Avoids redundant BuildRowDefs calls when only rendering/layout state changes.
local _cachedRows  = nil
local _rowsDirty   = true
local _panelDirty  = true
local _summaryRefreshQueued = false
local _gearPopupFrame   = nil   -- lazily-created gear popup; one shared instance
local _gearClickCatcher = nil   -- full-screen dismiss layer shown behind the popup
local _rowCurrencyMetaCache = {}
local _rowItemMetaCache = {}
local GetItemLabelColorRGB
-- Convenience alias: snapshot type-tag strings (defined in Currency.lua, published on Addon).
-- AltsSummary reads this rather than repeating magic strings.
local ST  -- assigned in PopulateSummary after Currency.lua has loaded
local PopulateSummary  -- forward declaration
local ShowGearPopup    -- forward declaration

local function GetCachedCurrencyRowMeta(currencyID, fallbackLabel)
    local id = tonumber(currencyID)
    if not id then
        return fallbackLabel, nil, nil, nil, nil
    end

    local cached = _rowCurrencyMetaCache[id]
    if cached then
        return cached.name or fallbackLabel, cached.icon, cached.cr, cached.cg, cached.cb
    end

    local name = GetCurrencyName(id) or fallbackLabel
    local icon = GetCurrencyIcon(id)
    local cr, cg, cb = Addon:GetCurrencyQualityColorRGB(id)
    _rowCurrencyMetaCache[id] = {
        name = name,
        icon = icon,
        cr = cr,
        cg = cg,
        cb = cb,
    }
    return name, icon, cr, cg, cb
end

local function GetCachedItemRowMeta(itemID)
    local id = tonumber(itemID)
    if not id then
        return nil, nil, nil, nil, nil
    end

    local cached = _rowItemMetaCache[id]
    if cached and cached.name and cached.icon then
        return cached.name, cached.icon, cached.cr, cached.cg, cached.cb
    end

    local name = GetItemName(id)
    local icon
    if GetItemInfo then
        _, _, _, _, _, _, _, _, _, icon = GetItemInfo(id)
    end
    if not icon and C_Item and C_Item.GetItemIconByID then
        icon = C_Item.GetItemIconByID(id)
    end
    local cr, cg, cb = GetItemLabelColorRGB(id)

    if name or icon then
        _rowItemMetaCache[id] = {
            name = name,
            icon = icon,
            cr = cr,
            cg = cg,
            cb = cb,
        }
    end

    return name, icon, cr, cg, cb
end

local function ScheduleSummaryRefresh()
    if _summaryRefreshQueued then return end
    if not (altSummaryFrame and altSummaryFrame.IsShown and altSummaryFrame:IsShown()) then return end

    _summaryRefreshQueued = true
    local function run()
        _summaryRefreshQueued = false
        if altSummaryFrame and altSummaryFrame.IsShown and altSummaryFrame:IsShown() then
            PopulateSummary(altSummaryFrame)
        end
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0.05, run)
    else
        run()
    end
end

-- ── Gear popup ───────────────────────────────────────────────────────────────
-- Shows a small frame listing ilvl per gear slot for a character.
-- anchor: the hdrHit frame to position near.  charKey: unique char identifier.
ShowGearPopup = function(anchor, charKey, charName, cr, cg, cb, snap)
    if not _gearPopupFrame then
        local POPUP_W  = 290
        local GP_ROW_H = 18
        local GP_TTL_H = 22
        local POPUP_H  = GP_TTL_H + 4 + #GEAR_SLOT_IDS * GP_ROW_H + 6
        local f = Addon:NewThemedFrame(nil, UIParent)
        -- Override bg to fully opaque (NewThemedFrame uses theme default a=0.65).
        Addon:ApplyOpaquePopupTheme(f)
        f:SetFrameStrata("TOOLTIP")
        f:SetClampedToScreen(true)
        f:SetSize(POPUP_W, POPUP_H)
        f:RegisterEvent("GET_ITEM_INFO_RECEIVED")
        f:SetScript("OnEvent", function(self_)
            if not (self_ and self_.IsShown and self_:IsShown()) then return end
            local ctx = self_._popupCtx
            if not ctx then return end
            ShowGearPopup(ctx.anchor, ctx.charKey, ctx.charName, ctx.cr, ctx.cg, ctx.cb, ctx.snap)
        end)

        local titleFS = f:CreateFontString(nil, "OVERLAY")
        titleFS:SetFont(FONT_FACE, 11, FONT_FLAGS)
        titleFS:SetPoint("TOPLEFT",  f, "TOPLEFT",  6, -4)
        titleFS:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -4)
        titleFS:SetHeight(GP_TTL_H - 4)
        titleFS:SetJustifyH("LEFT")
        titleFS:SetJustifyV("MIDDLE")
        f._titleFS = titleFS

        local sep = f:CreateTexture(nil, "ARTWORK")
        sep:SetHeight(1)
        local _vs = Addon.VISUAL_STYLE or {}
        sep:SetColorTexture(0.4, 0.4, 0.4, _vs.strongDividerA or 0.7)
        sep:SetPoint("TOPLEFT",  f, "TOPLEFT",  4, -GP_TTL_H)
        sep:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -GP_TTL_H)

        f._rows = {}
        for i, sid in ipairs(GEAR_SLOT_IDS) do
            local rowY = -(GP_TTL_H + 4 + (i - 1) * GP_ROW_H)

            -- Invisible hit region covering the full row width for mouse events.
            local hit = CreateFrame("Frame", nil, f)
            hit:SetPoint("TOPLEFT", f, "TOPLEFT", 4, rowY)
            hit:SetSize(POPUP_W - 8, GP_ROW_H)
            hit:EnableMouse(true)
            hit:SetScript("OnLeave", function() GameTooltip:Hide() end)

            local lblFS = f:CreateFontString(nil, "OVERLAY")
            lblFS:SetFont(FONT_FACE, 10, FONT_FLAGS)
            lblFS:SetPoint("TOPLEFT", f, "TOPLEFT", 8, rowY)
            lblFS:SetSize(78, GP_ROW_H)
            lblFS:SetJustifyH("LEFT")
            lblFS:SetJustifyV("MIDDLE")
            lblFS:SetTextColor(0.52, 0.52, 0.52, 1)
            lblFS:SetText(GEAR_SLOT_NAMES[sid])

            local nameFS = f:CreateFontString(nil, "OVERLAY")
            nameFS:SetFont(FONT_FACE, 10, FONT_FLAGS)
            nameFS:SetPoint("TOPLEFT",  f, "TOPLEFT",  90, rowY)
            nameFS:SetSize(POPUP_W - 90 - 42 - 8, GP_ROW_H)
            nameFS:SetJustifyH("LEFT")
            nameFS:SetJustifyV("MIDDLE")

            local ilvlFS = f:CreateFontString(nil, "OVERLAY")
            ilvlFS:SetFont(FONT_FACE, 10, FONT_FLAGS)
            ilvlFS:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, rowY)
            ilvlFS:SetSize(40, GP_ROW_H)
            ilvlFS:SetJustifyH("RIGHT")
            ilvlFS:SetJustifyV("MIDDLE")

            f._rows[i] = { sid = sid, hit = hit, nameFS = nameFS, ilvlFS = ilvlFS }
        end
        -- Hide catcher whenever the popup is closed by any path.
        f:SetScript("OnHide", function()
            if _gearClickCatcher then _gearClickCatcher:Hide() end
        end)
        _gearPopupFrame = f
    end

    if not _gearClickCatcher then
        local c = CreateFrame("Frame", nil, UIParent)
        c:SetAllPoints(UIParent)
        c:SetFrameStrata("DIALOG")
        c:EnableMouse(true)
        c:SetScript("OnMouseDown", function()
            if _gearPopupFrame then _gearPopupFrame:Hide() end
            c:Hide()
        end)
        c:Hide()
        _gearClickCatcher = c
    end

    local f = _gearPopupFrame
    f._popupCtx = {
        anchor = anchor,
        charKey = charKey,
        charName = charName,
        cr = cr,
        cg = cg,
        cb = cb,
        snap = snap,
    }
    f._titleFS:SetText(charName)
    f._titleFS:SetTextColor(cr, cg, cb, 1)

    local gearSlots = snap and snap.gearSlots
    for _, row in ipairs(f._rows) do
        local slotData = gearSlots and gearSlots[row.sid]
        -- Support both old format (plain number) and current format (table).
        local link, ilvl
        if type(slotData) == "table" then
            link = slotData.link
            ilvl = tonumber(slotData.ilvl) or 0
        elseif type(slotData) == "number" then
            ilvl = slotData
        else
            ilvl = 0
        end

        -- Item name, quality-colored.
        if link then
            local itemName, _, quality = GetItemInfo(link)
            if itemName then
                local qr, qg, qb = GetItemQualityColor(quality or 1)
                row.nameFS:SetText(itemName)
                row.nameFS:SetTextColor(qr or 1, qg or 1, qb or 1, 1)
            else
                row.nameFS:SetText(L.ALT_SUMMARY_LOADING or "Loading...")
                row.nameFS:SetTextColor(0.55, 0.55, 0.55, 1)
            end
        else
            row.nameFS:SetText(L.ALT_SUMMARY_EMPTY or "Empty")
            row.nameFS:SetTextColor(0.27, 0.27, 0.27, 1)
        end

        -- ilvl: tier-colored.
        if ilvl and ilvl > 0 then
            local hex = (Addon.IlvlUtils and Addon.IlvlUtils.GetColorHex(ilvl)) or "ffffffff"
            local r_ = (tonumber(hex:sub(3,4), 16) or 255) / 255
            local g_ = (tonumber(hex:sub(5,6), 16) or 255) / 255
            local b_ = (tonumber(hex:sub(7,8), 16) or 255) / 255
            row.ilvlFS:SetText(tostring(ilvl))
            row.ilvlFS:SetTextColor(r_, g_, b_, 1)
        else
            row.ilvlFS:SetText("")
        end

        -- Hover: full WoW item tooltip (shows gems, enchants, stats, set bonuses).
        local _link = link
        if _link then
            row.hit:SetScript("OnEnter", function(s_)
                GameTooltip:SetOwner(s_, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(_link)
                GameTooltip:Show()
            end)
        else
            row.hit:SetScript("OnEnter", nil)
        end
    end
    f._charKey = charKey
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 6, 0)
    _gearClickCatcher:Show()
    f:Show()
end

-- ── Dynamic layout ────────────────────────────────────────────────────────────
local function ComputeLayout()
    local tracking = Addon.TRACKING
    local miscIDs  = (tracking and type(tracking.miscCurrencyIDs) == "table")
                     and tracking.miscCurrencyIDs or {}
    local numMisc  = #miscIDs
    return {
        numMisc = numMisc,
        miscIDs = miscIDs,
    }
end

-- ── GV helpers ────────────────────────────────────────────────────────────────
local function CalcGVBreakdown(snap)
    if not (snap and snap.leftGrid) then return 0, 0, 0 end
    local s = {0, 0, 0}
    for bi = 1, 3 do
        local block = snap.leftGrid[bi]
        local done  = block and tonumber(block.complete) or 0
        -- block.complete counts unlocked vault slots (same as main panel's `complete >= i` check)
        s[bi] = math.min(done, 3)
    end
    return s[1], s[2], s[3]
end


-- ── Hex colour helper ───────────────────────────────────────────────────────
-- Converts a 6-char hex string (e.g. "FF8000") to three 0-1 floats.
-- Falls back to (0.7, 0.7, 0.7) when nil or malformed.
local function HexToRGB(hex)
    if hex and #hex >= 6 then
        return (tonumber(hex:sub(1,2), 16) or 179) / 255,
               (tonumber(hex:sub(3,4), 16) or 179) / 255,
               (tonumber(hex:sub(5,6), 16) or 179) / 255
    end
    return 0.7, 0.7, 0.7
end

-- ── Currency icon helper ──────────────────────────────────────────────────────
GetItemLabelColorRGB = function(id)
    if Addon.GetItemQualityColorRGB then
        return Addon:GetItemQualityColorRGB(id)
    end
    return nil, nil, nil
end

-- ── Shared tooltip leave ──────────────────────────────────────────────────────
local function OnCellLeave() GameTooltip:Hide() end

local function HideSummaryOverlays()
    if _gearPopupFrame and _gearPopupFrame.IsShown and _gearPopupFrame:IsShown() then
        _gearPopupFrame:Hide()
    end
    if _gearClickCatcher then
        _gearClickCatcher:Hide()
    end
    if Addon.HideContextMenu then
        Addon:HideContextMenu()
    end
end
Addon.HideSummaryOverlays = HideSummaryOverlays

local function ShowCurrencyHideMenu(anchor, currencyID)
    local cid = tonumber(currencyID)
    if not cid then return end
    local currencyName = GetCurrencyName(cid) or tostring(cid)
    local menuText = (L.CONTEXT_HIDE_THIS_CURRENCY_FMT or "Hide %s"):format(currencyName)
    Addon:ShowContextMenu(anchor, {
        { text = menuText, onClick = function()
            Addon:SetCurrencyHidden(cid, true)
        end },
    })
end

local function ShowItemHideMenu(anchor, itemID)
    local id = tonumber(itemID)
    if not id then return end
    local itemName = GetItemName(id) or tostring(id)
    local menuText = (L.CONTEXT_HIDE_THIS_ITEM_FMT or "Hide %s"):format(itemName)
    Addon:ShowContextMenu(anchor, {
        { text = menuText, onClick = function()
            Addon:SetItemHidden(id, true)
        end },
    })
end

local function RefreshAfterCharVisibilityChange(panel)
    if Addon.CharPicker and Addon.CharPicker.Populate then Addon.CharPicker.Populate() end
    if Addon.LayoutHeaderButtons then Addon:LayoutHeaderButtons() end
    _rowsDirty = true
    _panelDirty = true
    PopulateSummary(panel)
    if panel._inline and Addon._mainFrame then
        local padX = (Addon.UI and Addon.UI.padOuterX) or 14
        Addon._mainFrame:SetWidth(2 * padX + panel:GetWidth())
        if Addon.ApplyScrollLayout then Addon:ApplyScrollLayout() end
    end
end

local function SetCharHiddenFromSummary(panel, gdb, charKey, hidden)
    if not (gdb and charKey) then return end
    gdb.hiddenChars = gdb.hiddenChars or {}
    if hidden then
        gdb.hiddenChars[charKey] = true
        if Addon._viewingChar == charKey then Addon:SetViewingChar(nil) end
    else
        gdb.hiddenChars[charKey] = nil
    end
    _panelDirty = true
    RefreshAfterCharVisibilityChange(panel)
end

-- ── Widget helpers ────────────────────────────────────────────────────────────
local function MakeFS(parent, size, flags)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(FONT_FACE, size or 12, (flags == nil or flags == "") and FONT_FLAGS or flags)
    return fs
end

local function MakeCell(parent, w, h)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(w, h)
    f:EnableMouse(true)
    f:SetScript("OnLeave", OnCellLeave)
    local fs = MakeFS(f, 12)
    fs:SetPoint("TOPLEFT", f, "TOPLEFT", 4, 0)
    fs:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 0)
    fs:SetJustifyH("CENTER")
    fs:SetJustifyV("MIDDLE")
    f._fs = fs
    -- Secondary label: trade-up / overflow text, right-anchored.
    local tuFS = MakeFS(f, FONT_SM)
    tuFS:SetPoint("RIGHT", f, "RIGHT", -3, 0)
    tuFS:SetJustifyH("RIGHT")
    f._tu = tuFS
    -- Small hit region that sits over the trade-up text only (rightmost ~36px).
    local tuHit = CreateFrame("Frame", nil, f)
    tuHit:SetPoint("TOPRIGHT",    f, "TOPRIGHT",    0,  0)
    tuHit:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0,  0)
    tuHit:SetWidth(36)
    tuHit:EnableMouse(false)  -- enabled only when trade-up text is showing
    tuHit:SetScript("OnLeave", OnCellLeave)
    f._tuHit = tuHit
    return f
end

-- ── Panel construction ────────────────────────────────────────────────────────
local function EnsurePanel()
    if altSummaryFrame then return altSummaryFrame end

    _layout = ComputeLayout()

    local f = Addon:NewThemedFrame("LariasAltsSummaryFrame", UIParent)
    f:SetSize(400, 200)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(200)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self_) self_:StartMoving() end)
    f:SetScript("OnDragStop",  function(self_) self_:StopMovingOrSizing(); self_._wasMoved = true end)
    f:Hide()
    Addon._altsSummaryFrame = f
    Addon:RegisterWindowSurface(f, { opacityMode = "ui", borderStyle = "panel" })

    local th = Addon.THEME

    -- Title strip.
    local titleBgTex = f:CreateTexture(nil, "BACKGROUND")
    titleBgTex:SetColorTexture(th.header.r, th.header.g, th.header.b, STYLE.sectionBandA * GetPanelChromeAlpha())
    titleBgTex:SetPoint("TOPLEFT",  f, "TOPLEFT",  1, -1)
    titleBgTex:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
    titleBgTex:SetHeight(TITLE_H + 2)
    f._altsTitleBgTex = titleBgTex

    local titleFS = MakeFS(f, 13, "OUTLINE")
    titleFS:SetText(L.ALT_SUMMARY_TITLE or "Alt Summary")
    titleFS:SetTextColor(th.header.r, th.header.g, th.header.b, 1)
    titleFS:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -7)
    f._altsTitleFS = titleFS

    local closeBtn = Addon.Controls.NewCloseButton(f, function()
        if _gearPopupFrame then _gearPopupFrame:Hide() end
        f:Hide()
    end)
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    f._altsCloseBtn = closeBtn

    -- "Show hidden" checkbox.
    local chk = Addon.Controls.NewCheckBox(f, function(checked)
        _showHidden = checked
        _rowsDirty = true
        _panelDirty = true
        PopulateSummary(f)
    end, 14)
    chk:SetChecked(_showHidden)
    chk._label:SetText(L.ALT_SUMMARY_SHOW_HIDDEN or "Show hidden")
    local function ShowHiddenTooltip(self_)
        GameTooltip:SetOwner(self_, "ANCHOR_TOPLEFT")
        GameTooltip:SetText(L.ALT_SUMMARY_SHOW_HIDDEN or "Show hidden", 1, 1, 1)
        GameTooltip:AddLine(L.ALT_SUMMARY_SHOW_HIDDEN_TOOLTIP or "Includes characters you have hidden from the default view.", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end
    chk:SetScript("OnEnter", ShowHiddenTooltip)
    chk:SetScript("OnLeave", OnCellLeave)
    if chk._hit then
        chk._hit:SetScript("OnEnter", ShowHiddenTooltip)
        chk._hit:SetScript("OnLeave", OnCellLeave)
    end
    f._summaryChk = chk

    -- Close the gear popup whenever the summary panel is hidden (close button,
    -- ESC via UISpecialFrames, or any other dismiss path).
    f:SetScript("OnHide", function()
        HideSummaryOverlays()
    end)

    -- Pool tables for reuse.
    f._colPool     = {}
    f._divTexPool  = {}
    f._rowLblPool  = {}
    f._iconTexPool = {}
    f._rowHitPool  = {}

    local hoverRow = f:CreateTexture(nil, "ARTWORK", nil, -1)
    hoverRow:Hide()
    f._hoverRowTex = hoverRow

    local hoverCol = f:CreateTexture(nil, "ARTWORK", nil, -1)
    hoverCol:Hide()
    f._hoverColTex = hoverCol

    local dragInsert = f:CreateTexture(nil, "OVERLAY")
    dragInsert:Hide()
    f._dragInsertTex = dragInsert

    f:SetScript("OnUpdate", function(self_)
        if self_._dragUpdate then
            self_._dragUpdate(self_)
        end
    end)

    altSummaryFrame = f
    -- Register with UISpecialFrames so ESC closes this window.
    tinsert(UISpecialFrames, "LariasAltsSummaryFrame")
    return f
end

-- ── Snapshot helpers ─────────────────────────────────────────────────────────

local function BuildCharList(gdb, ownKey, allKeys, maxLvl)
    local th    = Addon.THEME.text
    local chars = {}
    local orderMap = {}
    do
        local savedOrder = Addon.GetAltSummaryCharOrder and Addon:GetAltSummaryCharOrder() or {}
        for i = 1, #savedOrder do
            orderMap[savedOrder[i]] = i
        end
    end
    for _, charKey in ipairs(allKeys) do
        local isHidden   = gdb and gdb.hiddenChars and gdb.hiddenChars[charKey] and true or false
        local classToken = gdb and gdb.charClasses  and gdb.charClasses[charKey]
        local isOwn      = (charKey == ownKey) or (charKey:lower() == ownKey:lower())
        local charLevel  = gdb and gdb.charLevels and gdb.charLevels[charKey]
        local isMaxLevel = isOwn or (charLevel and charLevel >= maxLvl)
        if isMaxLevel and (isOwn or not isHidden or _showHidden) and classToken then
            local cdb  = gdb and gdb.chars and gdb.chars[charKey]
            local snap = cdb and cdb.trackingSnapshot
            local cr, cg, cb = th.r, th.g, th.b
            local cc = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
            if cc then cr, cg, cb = cc.r, cc.g, cc.b end
            chars[#chars + 1] = {
                key = charKey, snap = snap,
                checked = cdb and cdb.checked,
                sectionCompleted = cdb and cdb.sectionCompleted,
                isOwn = isOwn, isHidden = isHidden,
                classToken = classToken,
                cr = cr, cg = cg, cb = cb,
                alpha = isHidden and 0.45 or 1.0,
                ilvl  = cdb and cdb.ilvl,
                sortIdx = orderMap[charKey],
            }
        end
    end
    -- Manual reordering wins when present; otherwise sort strictly by ilvl.
    table.sort(chars, function(a, b)
        if a.sortIdx ~= b.sortIdx then
            if a.sortIdx == nil then return false end
            if b.sortIdx == nil then return true end
            return a.sortIdx < b.sortIdx
        end
        local aIlvl = tonumber(a.ilvl) or 0
        local bIlvl = tonumber(b.ilvl) or 0
        if aIlvl ~= bIlvl then
            return aIlvl > bIlvl
        end
        return tostring(a.key) < tostring(b.key)
    end)
    return chars
end

local function BuildCharOrderKeys(chars)
    local keys = {}
    for i = 1, #(chars or {}) do
        local key = chars[i] and chars[i].key
        if type(key) == "string" and key ~= "" then
            keys[#keys + 1] = key
        end
    end
    return keys
end

local function MoveOrderKey(orderKeys, fromIdx, toIdx)
    local count = #orderKeys
    if count == 0 then return orderKeys end
    fromIdx = math.max(1, math.min(count, tonumber(fromIdx) or 1))
    toIdx   = math.max(1, math.min(count, tonumber(toIdx)   or fromIdx))
    if fromIdx == toIdx then return orderKeys end

    local moved = orderKeys[fromIdx]
    table.remove(orderKeys, fromIdx)
    table.insert(orderKeys, toIdx, moved)
    return orderKeys
end

local function GetPanelCursorX(panel)
    if not (panel and GetCursorPosition and panel.GetEffectiveScale) then return nil end
    local cursorX = select(1, GetCursorPosition())
    local left = panel:GetLeft()
    if not (cursorX and left) then return nil end
    local scale = panel:GetEffectiveScale()
    if not scale or scale == 0 then scale = 1 end
    return (cursorX / scale) - left
end

local function HasHiddenSummaryChars(gdb, ownKey, allKeys, maxLvl)
    for _, charKey in ipairs(allKeys or {}) do
        local isHidden   = gdb and gdb.hiddenChars and gdb.hiddenChars[charKey] and true or false
        local classToken = gdb and gdb.charClasses and gdb.charClasses[charKey]
        local isOwn      = (charKey == ownKey) or (ownKey and charKey:lower() == ownKey:lower())
        local charLevel  = gdb and gdb.charLevels and gdb.charLevels[charKey]
        local isMaxLevel = isOwn or (charLevel and charLevel >= maxLvl)
        if isHidden and not isOwn and isMaxLevel and classToken then
            return true
        end
    end
    return false
end

-- upgrade vendor, which causes every item to appear embellished (nLevels = 0 →
-- effectiveMax = rank → cost = 0 → "—" for all tiers).  Snapshot capture only
-- stores trueMaxRank when WoW provides usable upgrade details.
local function CalcWeaponUpgradeNeed(snap)
    local gearSlots = Addon.GetUpgradeGearSlots and Addon:GetUpgradeGearSlots(snap)
                   or (type(snap) == "table" and snap.gearSlots)
    if type(gearSlots) ~= "table" then return nil end
    local count = 0
    local sawGear = false
    for _, sid in ipairs(WEAP_UPG_SLOTS) do
        local sd = gearSlots[sid]
        local ilvl = type(sd) == "table" and tonumber(sd.ilvl) or 0
        if ilvl > 0 then sawGear = true end
        if ilvl > 0 and ilvl < WEAP_UPG_MAX_ILVL then
            count = count + 1
        end
    end
    return sawGear and count or nil
end

local function FormatSigilAmount(value)
    value = tonumber(value) or 0
    if value == math.floor(value) then
        return tostring(math.floor(value))
    end
    return ("%.1f"):format(value)
end

-- Compute the total crest cost to max all items of crest tier `tierIdx`,
-- using the rank (x/y) stored in the snapshot.  No ilvl range math needed.
-- Returns totalCost.
local function AnyVisibleCharNeedsUpgradeCost(chars, tierIdx)
    if not chars then return false end
    for _, char in ipairs(chars) do
        if Addon.CalcTierUpgradeCost and Addon:CalcTierUpgradeCost(char.snap, tierIdx) > 0 then
            return true
        end
    end
    return false
end

local function AnyVisibleCharNeedsWeapUpg(chars)
    if not chars then return false end
    for _, char in ipairs(chars) do
        local snap = char and char.snap
        local watermarkNeed = CalcWeaponUpgradeNeed(snap)
        if watermarkNeed ~= nil then
            if watermarkNeed > 0 then return true end
        elseif snap and type(snap.rightRows) == "table" then
            for _, row in ipairs(snap.rightRows) do
                if row.type == ST.WEAPUPG and (tonumber(row.need) or 0) > 0 then
                    return true
                end
            end
        end
    end
    return false
end

local function BuildRowDefs(tracking, LAYOUT, chars)
    local rows = {}
    local function addSec(lbl, action)  rows[#rows + 1] = { type = "sechdr", label = lbl, action = action } end
    local function addRow(t, lbl, extra)
        local r = { type = t, label = lbl }
        if extra then for k, v in pairs(extra) do r[k] = v end end
        rows[#rows + 1] = r
    end
    -- Returns display name and tier RGB for crest tier i.
    local function CrestTierInfo(i)
        local name = (Addon.IlvlUtils and Addon.IlvlUtils.GetCrestTrackName(i))
                     or CREST_ABBREV[i] or ("Tier " .. i)
        local hex  = tracking and tracking.crestColors and tracking.crestColors[i]
        local cr, cg, cb = HexToRGB(hex)
        return name, cr, cg, cb
    end

    addSec(L.ALT_SUMMARY_SECTION_CURRENCIES or "Currencies", "currency")
    for i = 1, NUM_CRESTS do
        local name, cr, cg, cb = CrestTierInfo(i)
        local crestID = tracking and tracking.crestCurrencyIDs and tracking.crestCurrencyIDs[i]
        if not Addon:IsCurrencyHidden(crestID) then
            local _, iconID = GetCachedCurrencyRowMeta(crestID, name)
            addRow("crest", name, { crestIdx = i, cr = cr, cg = cg, cb = cb,
                                    iconID = iconID, currencyID = crestID })
        end
    end

    local _catID = tracking and tracking.catalystCurrencyID
    if not Addon:IsCurrencyHidden(_catID) then
        local fallback = L.TRACKING_CATALYST_LABEL or "Catalyst"
        local _catName, _icon, _cr, _cg, _cb = GetCachedCurrencyRowMeta(_catID, fallback)
        addRow("catalyst", _catName, { iconID = _icon, currencyID = _catID, cr = _cr, cg = _cg, cb = _cb })
    end
    local _sprkID = tracking and tracking.sparkCurrencyID
    if not Addon:IsCurrencyHidden(_sprkID) then
        local fallback = L.TRACKING_SPARKS_LABEL or "Sparks"
        local _sprkName, _icon, _cr, _cg, _cb = GetCachedCurrencyRowMeta(_sprkID, fallback)
        addRow("sparks", _sprkName, { iconID = _icon, currencyID = _sprkID, cr = _cr, cg = _cg, cb = _cb })
    end
    for mi, mID in ipairs(LAYOUT.miscIDs) do
        local mIDNum = tonumber(mID)
        if not Addon:IsCurrencyHidden(mIDNum) then
            local fallback = (L.ALT_SUMMARY_MISC_CURRENCY_FMT or "Currency %d"):format(mID)
            local name, iconID, _cr, _cg, _cb = GetCachedCurrencyRowMeta(mIDNum, fallback)
            addRow("misc", name, { miscIdx = mi, miscID = mID, iconID = iconID, cr = _cr, cg = _cg, cb = _cb })
        end
    end

    -- Quest rows (conditional on questID > 0).
    local questIDs     = (tracking and tracking.questIDs)     or {}
    local questItemIDs = (tracking and tracking.questItemIDs) or {}
    local L            = Addon.L or {}
    local function addQuestRow(key, labelKey, fallback)
        if (tonumber(questIDs[key]) or 0) <= 0 then return end
        if Addon:IsQuestHidden(key) then return end
        local iID = tonumber(questItemIDs[key]) or 0
        if iID > 0 and Addon:IsItemHidden(iID) then return end
        local icon
        local qr, qg, qb
        if iID > 0 then
            _, icon, qr, qg, qb = GetCachedItemRowMeta(iID)
        end
        addRow("quest", L[labelKey] or fallback, { questKey = key, itemID = iID > 0 and iID or nil, iconID = icon, cr = qr, cg = qg, cb = qb })
    end
    addQuestRow("nullaeusSpoils", "TRACKING_QUEST_NULLAEUS_SPOILS", "Spoils of Nullaeus")
    addQuestRow("weeklyPrey",     "TRACKING_QUEST_WEEKLY_PREY",     "Weekly Prey")

    -- Build upgrade-cost rows only for tiers at least one visible character needs.
    do
        local addedUpgradeRows = false
        for i = 1, NUM_CRESTS do
            if AnyVisibleCharNeedsUpgradeCost(chars, i) then
                if not addedUpgradeRows then
                    addSec(L.ALT_SUMMARY_SECTION_UPGRADE_COST or "Upgrade Cost", nil)
                    addedUpgradeRows = true
                end
                local name, cr, cg, cb = CrestTierInfo(i)
                rows[#rows + 1] = { type = "upgcost", label = name, tierIdx = i, cr = cr, cg = cg, cb = cb }
            end
        end

        if not Addon:IsItemHidden(268552) and AnyVisibleCharNeedsWeapUpg(chars) then
            if not addedUpgradeRows then
                addSec(L.ALT_SUMMARY_SECTION_UPGRADE_COST or "Upgrade Cost", nil)
                addedUpgradeRows = true
            end
            local combinedName, combinedTex, wr, wg, wb = GetCachedItemRowMeta(268552)
            addRow("weapupg", combinedName or (L.TRACKING_UPGRADE_SIGIL or "Upgrade Sigil"), {
                itemID = 268552,
                iconID = combinedTex,
                cr = wr, cg = wg, cb = wb,
            })
        end
    end

    addSec(L.TRACKING_GREAT_VAULT_TITLE or "Great Vault", "greatvault")
    addRow("keystone", L.ALT_SUMMARY_KEYSTONE or "Keystone", {})
    for gi = 1, 3 do
        if not Addon:IsGVBlockHidden(gi) then
            addRow("gv", GV_NAMES[gi], { gvBlock = gi })
        end
    end

    return rows
end

-- ── Snap data factory ────────────────────────────────────────────────────
-- Returns a zeroed snap-data record. All consumers call this instead of
-- repeating the field list, so adding a new field only needs one change here.
local function NewSnapData()
    return {
        catQty = 0, catCap = 0,
        sprkQty = 0, sprkCap = 0, sprkQD = nil,
        miscQtys   = {}, miscCaps      = {},
        crestQtys  = {}, crestEarneds  = {}, crestCaps = {}, crestTradeups = {},
        questsDone = {},
        weapUpgShardQty    = 0,
        weapUpgCombinedQty = 0,
        weapUpgNeed        = 0,
    }
end

local function ExtractSnapData(snap, crestIDs, LAYOUT)
    local d = NewSnapData()
    if not (snap and snap.rightRows) then return d end
    for _, r_ in ipairs(snap.rightRows) do
        local t = r_.type
        if t == ST.CREST then
            local rid = tonumber(r_.id)
            for ii = 1, NUM_CRESTS do
                if crestIDs[ii] == rid then
                    d.crestQtys[ii]     = tonumber(r_.qty)    or 0
                    d.crestEarneds[ii]  = tonumber(r_.earned) or 0
                    d.crestCaps[ii]     = tonumber(r_.cap)    or 0
                    d.crestTradeups[ii] = r_.tradeup and tonumber(r_.tradeup) or nil
                    break
                end
            end
        elseif t == ST.CATALYST then
            d.catQty = tonumber(r_.qty) or 0
            d.catCap = tonumber(r_.cap) or 0
        elseif t == ST.SPARKS then
            d.sprkQty = tonumber(r_.qty) or 0
            d.sprkCap = tonumber(r_.cap) or 0
            d.sprkQD  = r_.questDone
        elseif t == ST.MISC then
            local rid = tonumber(r_.id)
            for mi, mID in ipairs(LAYOUT.miscIDs) do
                if tonumber(mID) == rid then
                    d.miscQtys[mi] = tonumber(r_.qty) or 0
                    d.miscCaps[mi] = tonumber(r_.cap) or 0
                    break
                end
            end
        elseif t == ST.QUEST then
            d.questsDone[r_.key] = r_.done
        elseif t == ST.WEAPUPG then
            d.weapUpgShardQty    = tonumber(r_.shardQty)    or 0
            d.weapUpgCombinedQty = tonumber(r_.combinedQty) or 0
            d.weapUpgNeed        = tonumber(r_.need)        or 0
        end
    end
    d.weapUpgNeed = CalcWeaponUpgradeNeed(snap) or d.weapUpgNeed
    return d
end

-- ── Populate ──────────────────────────────────────────────────────────────────

-- ── Per-type cell render functions ───────────────────────────────────────────
-- Each function fills one cell for one column (character).
-- Signature: RenderXxxCell(cell, row, sd, noSnap, alpha, th)
--   cell   : the frame with ._fs FontString, supports SetScript("OnEnter")
--   row    : row definition table (type-specific fields)
--   sd     : ExtractSnapData result for this character
--   noSnap : true when the character has no stored snapshot
--   alpha  : base alpha for the character column
--   th     : Addon.THEME.text {r,g,b}

-- Returns (r,g,b) for a crest cell based on weekly earned vs cap.
-- Green when uncapped or plenty of room; yellow when close; red when fully capped.
local function CrestProgressColor(earned, cap)
    if cap <= 0 then return 0.3, 1.0, 0.3 end  -- uncapped → always green
    local pct = earned / cap
    if     pct >= 1.0 then return 1.0, 0.4,  0.4   -- at cap → red
    elseif pct >= 0.6 then return 1.0, 0.82, 0.0   -- close   → yellow
    else                   return 0.3, 1.0,  0.3   -- room    → green
    end
end

local function RenderCrestCell(cell, row, sd, noSnap, alpha, _th, crestIDs, highestTuIdx)
    local idx    = row.crestIdx
    local earned = sd.crestEarneds[idx] or 0
    local qty    = sd.crestQtys[idx]   or 0
    local cap    = sd.crestCaps[idx]   or 0
    local tuAmt  = (idx == highestTuIdx) and (sd.crestTradeups[idx] or 0) or 0
    local cr2, cg2, cb2 = row.cr or 0.7, row.cg or 0.7, row.cb or 0.7
    if noSnap then
        SetPlaceholder(cell, _th, alpha * A_DIM)
        cell._tu:SetText("")
    else
        -- Show current held crests (wallet balance) vs weekly cap.
        local baseStr = (cap > 0) and (qty .. "/" .. cap) or tostring(qty)
        cell._fs:SetText(baseStr)
        local pr, pg, pb = CrestProgressColor(earned, cap)
        cell._fs:SetTextColor(pr, pg, pb, alpha * (qty > 0 and A_FULL or A_EMPTY))
        if tuAmt > 0 then
            cell._tu:SetText("+" .. tuAmt)
            cell._tu:SetTextColor(0.30, 0.65, 1.0, alpha)
        else
            cell._tu:SetText("")
        end
    end
    -- Main cell tooltip: crest amount detail.
    do
        local _e, _q, _c = earned, qty, cap
        local _nm, _cr2b, _cg2b, _cb2b = row.label, cr2, cg2, cb2
        if noSnap then
            cell:SetScript("OnEnter", nil)
        else
            cell:SetScript("OnEnter", function(s_)
                GameTooltip:SetOwner(s_, "ANCHOR_RIGHT")
                GameTooltip:SetText(_nm, _cr2b, _cg2b, _cb2b)
                if _c > 0 then
                    local bonus = math.max(0, _q - _e)
                    if bonus > 0 then
                        GameTooltip:AddLine((L.ALT_SUMMARY_CAPPED_CRESTS_FMT or "Capped Crests: %d"):format(_e), 1, 1, 1)
                        GameTooltip:AddLine((L.ALT_SUMMARY_BONUS_CRESTS_FMT or "Bonus Crests: +%d"):format(bonus), 1, 1, 1)
                        GameTooltip:AddLine((L.ALT_SUMMARY_TOTAL_CRESTS_FMT or "Total Crests: %d"):format(_q), 1, 1, 1)
                    else
                        GameTooltip:AddLine((L.ALT_SUMMARY_EARNED_SPACED_FMT or "Earned: %d / %d"):format(_e, _c), 1, 1, 1)
                        GameTooltip:AddLine((L.ALT_SUMMARY_TOTAL_HELD_FMT or "Total Held: %d"):format(_q), 1, 1, 1)
                    end
                else
                    GameTooltip:AddLine((L.ALT_SUMMARY_CRESTS_HELD_FMT or "Crests Held: %d"):format(_q), 1, 1, 1)
                end
                GameTooltip:Show()
            end)
        end
    end
    -- Trade-up tooltip lives only over the +N hit area (separate from main amount).
    if tuAmt > 0 then
        local _n, _earned, _cap = tuAmt, earned, cap
        local handler = function(s_)
            local cappedN = (_cap > 0) and math.min(_n, math.max(0, _cap - _earned)) or _n
            local AL = Addon.L or {}
            GameTooltip:SetOwner(s_, "ANCHOR_RIGHT")
            GameTooltip:SetText(AL.TRACKING_TRADEUP_TITLE or "Trade-up available", 0.30, 0.65, 1.0)
            if cappedN ~= _n then
                GameTooltip:AddLine((AL.TRACKING_TRADEUP_CURRENTLY_EARNABLE_FMT or "Currently earnable: %d"):format(cappedN), 1, 1, 1)
                GameTooltip:AddLine((AL.TRACKING_TRADEUP_UNCAPPED_FMT           or "Uncapped: %d"):format(_n),                0.7, 0.7, 0.7)
            else
                GameTooltip:AddLine((AL.TRACKING_TRADEUP_EARNABLE_FMT           or "Earnable: %d"):format(_n), 1, 1, 1)
            end
            local convertTip = AL.TRACKING_CONVERT_TOOLTIP or ""
            if convertTip ~= "" then
                GameTooltip:AddLine(convertTip, 0.7, 0.7, 0.7)
            end
            GameTooltip:Show()
        end
        if cell._tuHit then
            cell._tuHit:EnableMouse(true)
            cell._tuHit:SetScript("OnEnter", handler)
        end
    else
        if cell._tuHit then
            cell._tuHit:EnableMouse(false)
            cell._tuHit:SetScript("OnEnter", nil)
        end
    end
end

local function RenderCatalystCell(cell, row, sd, noSnap, alpha, th)
    local catQty = sd.catQty
    if noSnap then
        SetPlaceholder(cell, th, alpha * A_DIM)
    else
        cell._fs:SetText(tostring(catQty))
        cell._fs:SetTextColor(th.r, th.g, th.b, alpha * (catQty > 0 and A_FULL or A_DIM))
    end
    local _qty = catQty
    if noSnap then
        cell:SetScript("OnEnter", nil)
    else
        cell:SetScript("OnEnter", function(s_)
            GameTooltip:SetOwner(s_, "ANCHOR_RIGHT")
            GameTooltip:SetText(L.TRACKING_CATALYST_CHARGES or "Catalyst Charges", 1, 0.82, 0)
            GameTooltip:AddLine((L.TRACKING_CHARGES_FMT or "Charges: %d"):format(_qty), 1, 1, 1)
            GameTooltip:Show()
        end)
    end
end

local function RenderSparksCell(cell, row, sd, noSnap, alpha, th)
    local sprkQty, sprkCap, sprkQD = sd.sprkQty, sd.sprkCap, sd.sprkQD
    local sqr, sqg, sqb = 0.64, 0.21, 0.93
    if sprkCap > 0 and sprkQty >= sprkCap and sprkQD == true then
        sqr, sqg, sqb = 0.3, 1.0, 0.3
    elseif sprkQD == false then
        sqr, sqg, sqb = 1.0, 0.5, 0.5
    elseif sprkQty > 0 then
        sqr, sqg, sqb = 1.0, 0.82, 0.0
    end
    local sprkStr = (sprkCap > 0) and (sprkQty .. "/" .. sprkCap) or tostring(sprkQty)
    if noSnap then
        SetPlaceholder(cell, th, alpha * A_DIM)
    else
        cell._fs:SetText(sprkStr)
        cell._fs:SetTextColor(sqr, sqg, sqb, alpha * (sprkQty > 0 and A_FULL or A_EMPTY))
    end
    local _qty, _cap, _qd = sprkQty, sprkCap, sprkQD
    if noSnap then
        cell:SetScript("OnEnter", nil)
    else
        cell:SetScript("OnEnter", function(s_)
            GameTooltip:SetOwner(s_, "ANCHOR_RIGHT")
            GameTooltip:SetText(L.TRACKING_SPARKS_LABEL or "Sparks", 1, 0.82, 0)
            if _cap > 0 then
                GameTooltip:AddLine((L.TRACKING_SPARKS_XY_FMT or "Sparks: %d / %d"):format(_qty, _cap), 1, 1, 1)
            else
                GameTooltip:AddLine((L.TRACKING_SPARKS_FMT or "Sparks: %d"):format(_qty), 1, 1, 1)
            end
            if _qd == true then
                GameTooltip:AddLine(L.TRACKING_WEEKLY_QUEST_COMPLETE or "Weekly Quest: Complete", 0.3, 1.0, 0.3)
            elseif _qd == false then
                GameTooltip:AddLine(L.TRACKING_WEEKLY_QUEST_INCOMPLETE or "Weekly Quest: Incomplete", 1.0, 0.4, 0.4)
            end
            GameTooltip:Show()
        end)
    end
end

local function RenderMiscCell(cell, row, sd, noSnap, alpha, th)
    local mQty = sd.miscQtys[row.miscIdx] or 0
    local mCap = sd.miscCaps[row.miscIdx] or 0
    if noSnap then
        SetPlaceholder(cell, th, alpha * A_DIM)
    elseif mCap > 0 then
        cell._fs:SetText(mQty .. "/" .. mCap)
        local pct = mQty / mCap
        if     pct >= 1.0 then cell._fs:SetTextColor(0.3,  1.0,  0.3,  alpha)
        elseif pct >= 0.5 then cell._fs:SetTextColor(1.0,  0.82, 0.0,  alpha)
        else                    cell._fs:SetTextColor(th.r, th.g, th.b, alpha)
        end
    else
        cell._fs:SetText(tostring(mQty))
        cell._fs:SetTextColor(th.r, th.g, th.b, alpha * (mQty > 0 and A_FULL or A_DIM))
    end
    local _qty, _cap, _lbl = mQty, mCap, row.label
    if noSnap then
        cell:SetScript("OnEnter", nil)
    else
        cell:SetScript("OnEnter", function(s_)
            GameTooltip:SetOwner(s_, "ANCHOR_RIGHT")
            GameTooltip:SetText(_lbl or (L.TRACKING_CURRENCY_TITLE or "Currency"), 1, 0.82, 0)
            if _cap > 0 then
                GameTooltip:AddLine((L.ALT_SUMMARY_AMOUNT_XY_FMT or "Amount: %d / %d"):format(_qty, _cap), 1, 1, 1)
            else
                GameTooltip:AddLine((L.ALT_SUMMARY_AMOUNT_FMT or "Amount: %d"):format(_qty), 1, 1, 1)
            end
            GameTooltip:Show()
        end)
    end
end

local function RenderWeapUpgCell(cell, row, sd, noSnap, alpha, th)
    local shardQty    = sd.weapUpgShardQty    or 0
    local combinedQty = sd.weapUpgCombinedQty or 0
    local need        = sd.weapUpgNeed        or 0
    local total       = combinedQty + shardQty / 5  -- combined-equivalent with fractional shards
    if noSnap then
        SetPlaceholder(cell, th, alpha * A_DIM)
        cell:SetScript("OnEnter", nil)
        return
    end
    if need == 0 then
        SetPlaceholder(cell, th, alpha * A_DIM)
        cell:SetScript("OnEnter", nil)
    else
        local displayTotal = (total >= need) and need or total
        local str = FormatSigilAmount(displayTotal) .. "/" .. need
        if     total >= need       then cell._fs:SetTextColor(0.3,  1.0,  0.3,  alpha)
        elseif total >= need * 0.5 then cell._fs:SetTextColor(1.0,  0.82, 0.0,  alpha)
        else                            cell._fs:SetTextColor(th.r, th.g, th.b, alpha)
        end
        cell._fs:SetText(str)
    end
    local _total, _need, _shards, _combined = total, need, shardQty, combinedQty
    cell:SetScript("OnEnter", function(s_)
        GameTooltip:SetOwner(s_, "ANCHOR_RIGHT")
        GameTooltip:SetText(row.label or (L.TRACKING_UPGRADE_SIGIL or "Upgrade Sigil"), 1, 0.82, 0)
        if _need > 0 then
            local neededFmt = L.ALT_SUMMARY_SIGIL_NEEDED_FMT or "%s / %d needed"
            GameTooltip:AddLine(neededFmt:format(FormatSigilAmount(_total), _need), 1, 1, 1)
            GameTooltip:AddLine((L.ALT_SUMMARY_SIGIL_BREAKDOWN_FMT or "%d sigils + %d shards"):format(_combined, _shards), 0.7, 0.7, 0.7)
        else
            GameTooltip:AddLine(L.ALT_SUMMARY_NO_SLOTS_NEED_UPGRADING or "No slots need upgrading", 0.5, 1.0, 0.5)
        end
        GameTooltip:Show()
    end)
end

local function RenderQuestCell(cell, row, sd, noSnap, alpha, th)
    local done = sd.questsDone[row.questKey]
    if noSnap or done == nil then
        SetPlaceholder(cell, th, alpha * A_DIM)
    elseif done then
        cell._fs:SetText("1/1")
        cell._fs:SetTextColor(0.3, 1.0, 0.3, alpha)
    else
        cell._fs:SetText("0/1")
        cell._fs:SetTextColor(1.0, 0.45, 0.45, alpha)
    end
    local _done, _lbl = done, row.label
    cell:SetScript("OnEnter", function(s_)
        GameTooltip:SetOwner(s_, "ANCHOR_RIGHT")
        GameTooltip:SetText(_lbl, 1, 0.82, 0)
        if noSnap or _done == nil then
            GameTooltip:AddLine(L.ALT_SUMMARY_NO_SNAPSHOT or "No snapshot data", 0.6, 0.6, 0.6)
        elseif _done then
            GameTooltip:AddLine(L.ALT_SUMMARY_COMPLETED_THIS_WEEK or "Completed this week", 0.3, 1.0, 0.3)
        else
            GameTooltip:AddLine(L.ALT_SUMMARY_NOT_COMPLETED_THIS_WEEK or "Not completed this week", 1.0, 0.45, 0.45)
        end
        GameTooltip:Show()
    end)
end

local function RenderChecklistItemCell(cell, row, char, alpha, th)
    local checkedMap = char and char.checked
    local completedMap = char and char.sectionCompleted
    local key = row.sectionID and row.itemID and (tostring(row.sectionID) .. ":" .. tostring(row.itemID)) or nil
    local done = (key and checkedMap and checkedMap[key]) or (completedMap and completedMap[row.sectionID]) or false
    local hasData = (checkedMap ~= nil) or (completedMap ~= nil)

    if not hasData then
        SetPlaceholder(cell, th, alpha * A_DIM)
    elseif done then
        cell._fs:SetText("1/1")
        cell._fs:SetTextColor(0.3, 1.0, 0.3, alpha)
    else
        cell._fs:SetText("0/1")
        cell._fs:SetTextColor(1.0, 0.45, 0.45, alpha)
    end

    local _done, _hasData, _lbl = done, hasData, row.label
    cell:SetScript("OnEnter", function(s_)
        GameTooltip:SetOwner(s_, "ANCHOR_RIGHT")
        GameTooltip:SetText(_lbl, 1, 0.82, 0)
        if not _hasData then
            GameTooltip:AddLine(L.ALT_SUMMARY_NO_CHECKLIST_DATA or "No checklist data", 0.6, 0.6, 0.6)
        elseif _done then
            GameTooltip:AddLine(L.ALT_SUMMARY_COMPLETED_THIS_WEEK or "Completed this week", 0.3, 1.0, 0.3)
        else
            GameTooltip:AddLine(L.ALT_SUMMARY_NOT_COMPLETED_THIS_WEEK or "Not completed this week", 1.0, 0.45, 0.45)
        end
        GameTooltip:Show()
    end)
end

local function RenderKeystoneCell(cell, row, snap, noSnap, alpha, th)
    cell._fs:SetFont(FONT_FACE, 11, FONT_FLAGS)
    local ks    = snap and snap.keystone
    local level = ks and tonumber(ks.level) or 0
    if noSnap or not ks then
        SetPlaceholder(cell, th, alpha * A_DIM)
        return
    end
    if level <= 0 then
        SetPlaceholder(cell, th, alpha * A_DIM)
        return
    end
    local name    = (ks.name and ks.name ~= "") and ks.name or nil
    local abbrev  = name and (name:match("^%S+") or name) or nil
    local display = abbrev and ("+" .. level .. " " .. abbrev) or ("+" .. level)
    local kr, kg, kb
    if     level >= 10 then kr, kg, kb = 0.64, 0.21, 0.93
    elseif level >=  7 then kr, kg, kb = 0.12, 0.44, 0.85
    elseif level >=  4 then kr, kg, kb = 0.12, 0.73, 0.12
    else                    kr, kg, kb = 0.70, 0.70, 0.70
    end
    cell._fs:SetText(display)
    cell._fs:SetTextColor(kr, kg, kb, alpha)
    local _level, _name = level, name
    cell:SetScript("OnEnter", function(s_)
        GameTooltip:SetOwner(s_, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.ALT_SUMMARY_KEYSTONE or "Keystone", 1, 0.82, 0)
        if _name then
            GameTooltip:AddLine("+" .. _level .. " " .. _name, 1, 1, 1)
        else
            GameTooltip:AddLine("+" .. _level, 1, 1, 1)
        end
        GameTooltip:Show()
    end)
end

local function RenderUpgradeCostCell(cell, row, snap, noSnap, alpha, th)
    cell._fs:SetFont(FONT_FACE, FONT_CELL, FONT_FLAGS)
    local cr, cg, cb = row.cr or th.r, row.cg or th.g, row.cb or th.b

    if noSnap then
        SetPlaceholder(cell, th, alpha * A_DIM)
        cell:SetScript("OnEnter", nil)
        return
    end

    -- Check whether any gear was actually captured for this character.
    -- snap.gearSlots may be nil (old snapshot) or {} (capture failed / all empty).
    local hasGearData = false
    local upgradeGearSlots = Addon.GetUpgradeGearSlots and Addon:GetUpgradeGearSlots(snap)
                          or (type(snap) == "table" and snap.gearSlots)
    if upgradeGearSlots then
        for _, sid in ipairs(GEAR_SLOT_IDS) do
            local sd = upgradeGearSlots[sid]
            if type(sd) == "table" and sd.rank then
                hasGearData = true; break
            end
        end
    end
    if not hasGearData then
        cell._fs:SetText("?")
        cell._fs:SetTextColor(cr, cg, cb, A_DIM)
        local _nil = not upgradeGearSlots
        -- Count how many slots had ilvl data vs rank data for diagnostics.
        local _ilvlCount, _rankCount = 0, 0
        if upgradeGearSlots then
            for _, sid in ipairs(GEAR_SLOT_IDS) do
                local sd = upgradeGearSlots[sid]
                if type(sd) == "table" then
                    if (sd.ilvl or 0) > 0 then _ilvlCount = _ilvlCount + 1 end
                    if sd.rank then _rankCount = _rankCount + 1 end
                end
            end
        end
        cell:SetScript("OnEnter", function(s_)
            GameTooltip:SetOwner(s_, "ANCHOR_RIGHT")
            GameTooltip:SetText(L.ALT_SUMMARY_NO_GEAR_DATA or "No gear data", 1, 0.6, 0)
            if _nil then
                GameTooltip:AddLine(L.ALT_SUMMARY_SNAPSHOT_PREDATES_RANK or "Snapshot predates rank capture.", 1, 0.6, 0, true)
            elseif _ilvlCount == 0 then
                GameTooltip:AddLine(L.ALT_SUMMARY_ILVL_DATA_NOT_LOADED or "ilvl = 0 for all slots (data not loaded?).", 1, 0.6, 0, true)
            else
                GameTooltip:AddLine((L.ALT_SUMMARY_GEAR_DATA_COUNTS_FMT or "%d slots with ilvl, %d with rank."):format(_ilvlCount, _rankCount), 1, 0.6, 0, true)
            end
            GameTooltip:AddLine(L.ALT_SUMMARY_LOG_IN_REFRESH or "Log in as this character to refresh.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        return
    end

    local targetTier = row.tierIdx
    local totalCost = Addon.CalcTierUpgradeCost and Addon:CalcTierUpgradeCost(snap, targetTier) or 0

    if totalCost == 0 then
        SetPlaceholder(cell, th, alpha * A_DIM)
        cell:SetScript("OnEnter", nil)
    else
        -- Availability is per crest type: wallet balance plus this tier's own
        -- trade-up amount from lower crests, if that conversion is unlocked.
        local heldQty, tradeupQty, availableQty = 0, 0, 0
        if Addon.GetCrestAvailabilityForTier then
            heldQty, tradeupQty, availableQty = Addon:GetCrestAvailabilityForTier(snap, targetTier)
        end
        local displayAvailable = math.min(availableQty, totalCost)
        cell._fs:SetText(displayAvailable .. "/" .. totalCost)
        if availableQty >= totalCost then
            cell._fs:SetTextColor(0.3, 1.0, 0.3, alpha)
        elseif availableQty >= totalCost * 0.5 then
            cell._fs:SetTextColor(1.0, 0.82, 0.0, alpha)
        else
            cell._fs:SetTextColor(cr, cg, cb, alpha)
        end
        local _snap, _tierIdx = snap, targetTier
        local _name, _cr, _cg, _cb = row.label, cr, cg, cb
        local _total = totalCost
        local _held  = heldQty
        local _tradeup = tradeupQty
        local _available = availableQty
        cell:SetScript("OnEnter", function(s_)
            GameTooltip:SetOwner(s_, "ANCHOR_RIGHT")
            GameTooltip:SetText((L.ALT_SUMMARY_UPGRADE_COST_TITLE_FMT or "%s Upgrade Cost"):format(_name), _cr, _cg, _cb)
            GameTooltip:AddLine((L.ALT_SUMMARY_AVAILABLE_NEED_FMT or "Available: %d  /  Need: %d"):format(_available, _total), 1, 1, 1)
            if _tradeup > 0 then
                GameTooltip:AddLine((L.ALT_SUMMARY_HELD_TRADEUP_FMT or "Held: %d  +  Trade-up: %d"):format(_held, _tradeup), 0.65, 0.82, 1.0)
            else
                GameTooltip:AddLine((L.TRACKING_HELD_FMT or "Held: %d"):format(_held), 0.75, 0.75, 0.75)
            end
            local tooltipGearSlots = Addon.GetUpgradeGearSlots and Addon:GetUpgradeGearSlots(_snap)
                                  or (type(_snap) == "table" and _snap.gearSlots)
            if tooltipGearSlots then
                local hasAny = false
                for _, sid in ipairs(GEAR_SLOT_IDS) do
                    local slotData = tooltipGearSlots[sid]
                    if type(slotData) ~= "table" or slotData.tierIdx ~= _tierIdx
                            or not slotData.rank then
                        -- skip
                    else
                        local effectiveMax = Addon.GetSlotEffectiveMax and Addon:GetSlotEffectiveMax(slotData)
                        if effectiveMax then
                            local isEmbellished = Addon.IsSlotLimitedCrafted and Addon:IsSlotLimitedCrafted(slotData, effectiveMax)
                            local needsUpgrade  = (slotData.rank < effectiveMax)
                            if (needsUpgrade and not isEmbellished) or isEmbellished then
                                if not hasAny then
                                    GameTooltip:AddLine(" ")
                                    hasAny = true
                                end
                                local slotName = GEAR_SLOT_NAMES[sid] or ("Slot " .. sid)
                                if isEmbellished then
                                    -- Limited crafted items cannot be upgraded to the full track max.
                                    GameTooltip:AddLine(
                                        "|cff666666" .. slotName .. "  "
                                        .. slotData.rank .. "/" .. effectiveMax .. "|r"
                                        .. "  |cffffcc00" .. (L.ALT_SUMMARY_LIMITED_CRAFTED_IGNORED or "(Embellished crafted - ignored)") .. "|r", 1, 1, 1)
                                else
                                    local slotCost = Addon.GetCrestSlotUpgradeCost
                                        and Addon:GetCrestSlotUpgradeCost(sid, slotData, _snap, _tierIdx, effectiveMax)
                                        or 0
                                    GameTooltip:AddLine(
                                        slotName .. "  " .. slotData.rank .. "/" .. effectiveMax
                                        .. "   (" .. slotCost .. ")", 0.85, 0.85, 0.85)
                                end
                            end
                        end
                    end
                end
            end
            GameTooltip:Show()
        end)
    end
end

local function RenderGVCell(cell, row, snap, noSnap, alpha)
    local gi    = row.gvBlock
    local block = snap and snap.leftGrid and snap.leftGrid[gi]
    local complete = block and tonumber(block.complete) or 0

    cell._fs:SetFont(FONT_FACE, 11, FONT_FLAGS)

    local function FormatGVSlotToken(text, colorCode)
        local token = tostring(text or PLACEHOLDER_DASH)
        if #token < 3 then
            token = (" "):rep(math.floor((3 - #token) / 2)) .. token
                 .. (" "):rep(math.ceil((3 - #token) / 2))
        end
        if colorCode and colorCode ~= "" then
            return "|c" .. colorCode .. token .. "|r"
        end
        return token
    end

    if noSnap or not block then
        cell._fs:SetText(table.concat({
            FormatGVSlotToken(PLACEHOLDER_DASH, "ff555555"),
            FormatGVSlotToken(PLACEHOLDER_DASH, "ff555555"),
            FormatGVSlotToken(PLACEHOLDER_DASH, "ff555555"),
        }, " "))
        cell._fs:SetTextColor(1, 1, 1, alpha * A_DIM)
    else
        local parts = {}
        for si = 1, 3 do
            local slotData = block.slots and block.slots[si]
            local ilvl     = slotData and tonumber(slotData.ilvl) or 0
            local unlocked = complete >= si
            if unlocked then
                if ilvl > 0 then
                    local hex = (Addon.IlvlUtils and Addon.IlvlUtils.GetColorHex(ilvl)) or "ffffffff"
                    parts[si] = FormatGVSlotToken(ilvl, hex)
                else
                    parts[si] = FormatGVSlotToken(PLACEHOLDER_DASH, "ff55aa55")
                end
            else
                parts[si] = FormatGVSlotToken(PLACEHOLDER_DASH, "ff555555")
            end
        end
        cell._fs:SetText(table.concat(parts, " "))
        cell._fs:SetTextColor(1, 1, 1, alpha)
    end

    local _snap3, _bi = snap, gi
    cell:SetScript("OnEnter", function(s_)
        local blk    = _snap3 and _snap3.leftGrid and _snap3.leftGrid[_bi]
        local thresh = GV_THRESHOLDS[_bi]
        local cmplt  = blk and tonumber(blk.complete) or 0
        GameTooltip:SetOwner(s_, "ANCHOR_RIGHT")
        GameTooltip:SetText(GV_NAMES[_bi], 1, 0.82, 0)
        if not blk then
            GameTooltip:AddLine(L.ALT_SUMMARY_NO_SNAPSHOT or "No snapshot data", 0.6, 0.6, 0.6)
            GameTooltip:Show()
            return
        end
        GameTooltip:AddLine((L.ALT_SUMMARY_SLOTS_UNLOCKED_FMT or "Slots unlocked: %d/3"):format(cmplt), 1, 1, 1)
        GameTooltip:AddLine(" ")
        for si = 1, 3 do
            local need     = thresh[si]
            local unlocked = cmplt >= si
            local slotData = blk.slots and blk.slots[si]
            local ilvl     = slotData and tonumber(slotData.ilvl) or 0
            if unlocked then
                local trackLabel = Addon.IlvlUtils and ilvl > 0 and Addon.IlvlUtils.GetTrackLabel(ilvl)
                local line
                if ilvl > 0 then
                    line = (L.ALT_SUMMARY_SLOT_ILVL_FMT or "Slot %d: %d ilvl"):format(si, ilvl)
                    if trackLabel then line = line .. "  (" .. trackLabel .. ")" end
                else
                    line = (L.ALT_SUMMARY_SLOT_UNLOCKED_FMT or "Slot %d: Unlocked"):format(si)
                end
                GameTooltip:AddLine(line, 0.3, 1.0, 0.3)
            else
                GameTooltip:AddLine((L.ALT_SUMMARY_SLOT_REQUIRES_FMT or "Slot %d: Requires %d activities"):format(si, need), 0.55, 0.55, 0.55)
            end
        end
        GameTooltip:Show()
    end)
end

PopulateSummary = function(panel)
    if not panel then return end
    HideSummaryOverlays()
    _panelDirty = false
    panel._lariasAltSummaryPopulated = true
    ST = ST or Addon.SNAP_TYPES or {}  -- lazy-bind once Currency.lua has registered SNAP_TYPES
    if not _layout then _layout = ComputeLayout() end
    local LAYOUT   = _layout
    local gdb      = Addon.db and Addon.db.global
    local ownKey   = Addon:GetCurrentProfileKey()
    local allKeys  = Addon:GetCharProfileKeys()
    local tracking = Addon.TRACKING
    local th       = Addon.THEME.text
    local brd      = Addon.THEME.border
    local header   = Addon.THEME.header
    local maxLvl   = (GetMaxPlayerLevel and GetMaxPlayerLevel()) or 80
    local hasHiddenChars = HasHiddenSummaryChars(gdb, ownKey, allKeys, maxLvl)
    if not hasHiddenChars then
        _showHidden = false
    end

    -- ── Collect visible characters ────────────────────────────────────────────
    local chars    = BuildCharList(gdb, ownKey, allKeys, maxLvl)
    local numChars = #chars

    -- ── Row definitions ───────────────────────────────────────────────────────
    -- Rebuild only when row visibility can change; otherwise reuse the cache.
    if _rowsDirty or not _cachedRows then
        _cachedRows = BuildRowDefs(tracking, LAYOUT, chars)
        _rowsDirty  = false
    end
    local rows = _cachedRows

    -- ── Sizing ────────────────────────────────────────────────────────────────
    local totalContentH = 0
    for _, row in ipairs(rows) do
        totalContentH = totalContentH + (row.type == "sechdr" and HDR_ROW_H or ROW_H)
    end

    local isInline = panel._inline
    local colW = COL_W
    local CONTENT_TOP, COL_HDR_TOP, ROWS_TOP, FOOTER_TOP, TOTAL_H
    if panel._altsTitleBgTex then panel._altsTitleBgTex:SetShown(not isInline) end
    if panel._altsTitleFS    then panel._altsTitleFS:SetShown(not isInline)    end
    if panel._altsCloseBtn   then panel._altsCloseBtn:SetShown(not isInline)   end

    local function HideDragIndicator()
        if panel._dragInsertTex then
            panel._dragInsertTex:Hide()
        end
    end

    local function RestoreDraggedColumnVisual(state)
        local col = state and state.col
        if not col then return end
        if col.nameFS then
            col.nameFS:SetAlpha(1)
        end
        if col.ilvlFS then
            col.ilvlFS:SetAlpha(1)
        end
        if col.classBar then
            col.classBar:SetAlpha(1)
        end
    end

    local function ApplyDraggedColumnVisual(state)
        local col = state and state.col
        if not col then return end
        if col.nameFS then
            col.nameFS:SetAlpha(0.35)
        end
        if col.ilvlFS then
            col.ilvlFS:SetAlpha(0.35)
        end
        if col.classBar then
            col.classBar:SetAlpha(0.35)
        end
    end

    local function GetDropIndex(cursorPanelX)
        if numChars <= 0 then return nil end
        local relativeX = (cursorPanelX or 0) - (PAD + COL_LABEL)
        local idx = math.floor((relativeX + (colW * 0.5)) / colW) + 1
        return math.max(1, math.min(numChars, idx))
    end

    local function ShowDragIndicator(targetIdx)
        if not panel._dragInsertTex then return end
        local lineX = PAD + COL_LABEL + ((targetIdx - 1) * colW)
        panel._dragInsertTex:SetColorTexture(header.r, header.g, header.b, 0.9)
        panel._dragInsertTex:ClearAllPoints()
        panel._dragInsertTex:SetPoint("TOPLEFT", panel, "TOPLEFT", lineX - 1, COL_HDR_TOP)
        panel._dragInsertTex:SetSize(2, math.abs(FOOTER_TOP - COL_HDR_TOP))
        panel._dragInsertTex:Show()
    end

    local function ClearDragState()
        local state = panel._dragState
        if state then
            RestoreDraggedColumnVisual(state)
        end
        panel._dragState = nil
        HideDragIndicator()
    end

    -- Use the same theme colors as the main frame.  ApplyOpacity below supplies
    -- the saved background alpha so the Alt Summary matches the main window.
    do
        local bg  = Addon.THEME.bg
        local bd  = Addon.THEME.border
        if panel._lariaBgTex            then panel._lariaBgTex:SetColorTexture(bg.r, bg.g, bg.b, 1.0) end
        if panel.SetBackdropColor       then panel:SetBackdropColor(0, 0, 0, 0)                    end
        if panel.SetBackdropBorderColor then
            panel:SetBackdropBorderColor(bd.r, bd.g, bd.b, (Addon.VISUAL_STYLE and Addon.VISUAL_STYLE.panelBorderA) or bd.a)
        end
        if not isInline then
            -- Refresh title strip & label with the current header color.
            local h = Addon.THEME.header
            if panel._altsTitleBgTex then
                panel._altsTitleBgTex:SetColorTexture(h.r, h.g, h.b, STYLE.sectionBandA * GetPanelChromeAlpha())
            end
            if panel._altsTitleFS    then panel._altsTitleFS:SetTextColor(h.r, h.g, h.b, 1)          end
        end
    end
    if Addon.ApplyOpacity then Addon:ApplyOpacity() end

    CONTENT_TOP = isInline and -PAD or -(TITLE_H + 4)
    local chromeA = GetPanelChromeAlpha()
    COL_HDR_TOP = CONTENT_TOP
    ROWS_TOP    = COL_HDR_TOP - COL_HDR_H - 2
    FOOTER_TOP  = ROWS_TOP - totalContentH - 8
    TOTAL_H     = math.abs(FOOTER_TOP) + 20 + PAD
    local TOTAL_W     = PAD + COL_LABEL + numChars * colW + PAD

    panel:SetSize(math.max(300, TOTAL_W), math.max(120, TOTAL_H))
    panel._dragUpdate = function(self_)
        local state = self_._dragState
        if not state then return end

        local leftDown = IsMouseButtonDown and IsMouseButtonDown("LeftButton")
        if not leftDown then
            local targetIdx = state.targetIdx or state.sourceIdx
            if state.active and targetIdx and targetIdx ~= state.sourceIdx then
                local orderKeys = BuildCharOrderKeys(chars)
                MoveOrderKey(orderKeys, state.sourceIdx, targetIdx)
                ClearDragState()
                if Addon.SetAltSummaryCharOrder then
                    Addon:SetAltSummaryCharOrder(orderKeys)
                end
                return
            end
            ClearDragState()
            return
        end

        local cursorX = GetPanelCursorX(self_)
        if not cursorX then return end

        if not state.active then
            if math.abs(cursorX - state.startX) < DRAG_THRESHOLD then
                return
            end
            state.active = true
            HideHover()
            OnCellLeave()
            ApplyDraggedColumnVisual(state)
        end

        state.targetIdx = GetDropIndex(cursorX) or state.sourceIdx
        ShowDragIndicator(state.targetIdx)
    end

    -- Hide all pooled widgets from previous call.
    for _, t in ipairs(panel._divTexPool)  do t:Hide() end
    for _, t in ipairs(panel._iconTexPool) do t:Hide() end
    for _, fs in ipairs(panel._rowLblPool) do fs:Hide() end
    for _, h in ipairs(panel._rowHitPool or {}) do h:Hide() end
    if panel._hoverRowTex then panel._hoverRowTex:Hide() end
    if panel._hoverColTex then panel._hoverColTex:Hide() end
    for _, col in ipairs(panel._colPool) do
        col.nameFS:Hide()
        if col.ilvlFS     then col.ilvlFS:Hide()     end
        if col.classBar   then col.classBar:Hide()   end
        if col.hdrHit     then col.hdrHit:Hide()     end
        for _, c in pairs(col.cells) do c:Hide() end
    end

    local divCursor  = 0
    local iconCursor = 0
    local lblCursor  = 0
    local colCursor  = 0
    local hitCursor  = 0

    local function GetDiv()
        divCursor = divCursor + 1
        if not panel._divTexPool[divCursor] then
            panel._divTexPool[divCursor] = panel:CreateTexture(nil, "ARTWORK")
        end
        local t = panel._divTexPool[divCursor]
        t:ClearAllPoints()
        t:SetSize(0, 0)
        t:Show()
        return t
    end
    local function ShowHover(rowY, rowH, colX, colWidth)
        local h = Addon.THEME.header or Addon.THEME.text
        if panel._hoverRowTex and rowY and rowH then
            panel._hoverRowTex:SetColorTexture(h.r, h.g, h.b, STYLE.hoverA)
            panel._hoverRowTex:ClearAllPoints()
            panel._hoverRowTex:SetPoint("TOPLEFT",  panel, "TOPLEFT",  1, rowY)
            panel._hoverRowTex:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, rowY)
            panel._hoverRowTex:SetHeight(rowH)
            panel._hoverRowTex:Show()
        end
        if panel._hoverColTex and colX and colWidth then
            panel._hoverColTex:SetColorTexture(h.r, h.g, h.b, STYLE.hoverColA)
            panel._hoverColTex:ClearAllPoints()
            panel._hoverColTex:SetPoint("TOPLEFT", panel, "TOPLEFT", colX, COL_HDR_TOP)
            panel._hoverColTex:SetSize(colWidth, math.abs(FOOTER_TOP - COL_HDR_TOP))
            panel._hoverColTex:Show()
        elseif panel._hoverColTex then
            panel._hoverColTex:Hide()
        end
    end
    local function HideHover()
        if panel._hoverRowTex then panel._hoverRowTex:Hide() end
        if panel._hoverColTex then panel._hoverColTex:Hide() end
    end
    local function GetIcon()
        iconCursor = iconCursor + 1
        if not panel._iconTexPool[iconCursor] then
            panel._iconTexPool[iconCursor] = panel:CreateTexture(nil, "ARTWORK")
        end
        local t = panel._iconTexPool[iconCursor]
        t:ClearAllPoints()
        t:SetSize(ICON_SIZE, ICON_SIZE)
        t:SetTexture(nil)
        t:Show()
        return t
    end
    local function GetLbl(size, flags)
        lblCursor = lblCursor + 1
        if not panel._rowLblPool[lblCursor] then
            panel._rowLblPool[lblCursor] = MakeFS(panel, size or 12, flags)
        end
        local fs = panel._rowLblPool[lblCursor]
        fs:ClearAllPoints()
        fs:SetFont(FONT_FACE, size or 12, (flags == nil or flags == "") and FONT_FLAGS or flags)
        fs:SetText("")
        fs:SetTextColor(Addon.THEME.text.r, Addon.THEME.text.g, Addon.THEME.text.b, Addon.THEME.text.a)
        fs:Show()
        return fs
    end
    if not panel._rowHitPool then panel._rowHitPool = {} end
    local function GetHit()
        hitCursor = hitCursor + 1
        if not panel._rowHitPool[hitCursor] then
            local h = CreateFrame("Frame", nil, panel)
            h:EnableMouse(true)
            h:SetScript("OnLeave", OnCellLeave)
            panel._rowHitPool[hitCursor] = h
        end
        local h = panel._rowHitPool[hitCursor]
        h:ClearAllPoints()
        h:SetScript("OnEnter", nil)
        h:SetScript("OnMouseUp", nil)
        h:SetScript("OnLeave", function()
            HideHover()
            OnCellLeave()
        end)
        h:Show()
        return h
    end
    local function GetCol()
        colCursor = colCursor + 1
        if not panel._colPool[colCursor] then
            local hdrHit = CreateFrame("Button", nil, panel)
            hdrHit:EnableMouse(true)
            if hdrHit.RegisterForClicks then
                hdrHit:RegisterForClicks("AnyUp")
            end
            hdrHit:SetScript("OnLeave", OnCellLeave)
            panel._colPool[colCursor] = {
                nameFS    = MakeFS(panel, 11, ""),
                ilvlFS    = MakeFS(panel, 10, ""),
                classBar  = panel:CreateTexture(nil, "ARTWORK"),
                hdrHit    = hdrHit,
                cells     = {},
            }
        end
        local col = panel._colPool[colCursor]
        col.nameFS:ClearAllPoints()
        if col.ilvlFS     then col.ilvlFS:ClearAllPoints()     end
        if col.hdrHit     then
            col.hdrHit:ClearAllPoints()
            col.hdrHit:SetFrameStrata(panel:GetFrameStrata())
            col.hdrHit:SetFrameLevel((panel:GetFrameLevel() or 1) + 20)
            col.hdrHit:SetScript("OnEnter", nil)
            col.hdrHit:SetScript("OnClick", nil)
            col.hdrHit:SetScript("OnMouseDown", nil)
            col.hdrHit:SetScript("OnMouseUp", nil)
            col.hdrHit:SetScript("OnLeave", function()
                HideHover()
                OnCellLeave()
            end)
        end
        if col.classBar then col.classBar:ClearAllPoints() end
        col.nameFS:Show()
        if col.ilvlFS     then col.ilvlFS:Show()     end
        if col.hdrHit     then col.hdrHit:Show()     end
        col.classBar:Show()
        return col
    end
    local function GetCell(col, rowIdx)
        if not col.cells[rowIdx] then
            col.cells[rowIdx] = MakeCell(panel, colW, ROW_H)
        end
        local c = col.cells[rowIdx]
        c:ClearAllPoints()
        c:SetScript("OnEnter", nil)
        c:SetScript("OnMouseUp", nil)
        c:SetScript("OnLeave", function()
            HideHover()
            OnCellLeave()
        end)
        c:Show()
        return c
    end

    -- ── Column-header background strip ───────────────────────────────────────
    local hdrBg = GetDiv()
    hdrBg:SetColorTexture(brd.r, brd.g, brd.b, STYLE.headerBandA * chromeA)
    hdrBg:SetPoint("TOPLEFT",  panel, "TOPLEFT",  1,  COL_HDR_TOP)
    hdrBg:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, COL_HDR_TOP)
    hdrBg:SetHeight(COL_HDR_H + 2)

    -- Horizontal divider below column headers.
    local hdrDiv = GetDiv()
    hdrDiv:SetHeight(1)
    hdrDiv:SetColorTexture(brd.r, brd.g, brd.b, STYLE.headerLineA * chromeA)
    hdrDiv:SetPoint("TOPLEFT",  panel, "TOPLEFT",  PAD, ROWS_TOP)
    hdrDiv:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, ROWS_TOP)

    -- ── Left label column ─────────────────────────────────────────────────────
    -- Vertical divider separating labels from data columns.
    local lblDiv = GetDiv()
    lblDiv:SetWidth(1)
    lblDiv:SetColorTexture(brd.r, brd.g, brd.b, STYLE.colLineA * chromeA)
    lblDiv:SetPoint("TOPLEFT",    panel, "TOPLEFT", PAD + COL_LABEL - 1, ROWS_TOP)
    lblDiv:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", PAD + COL_LABEL - 1, FOOTER_TOP)

    -- Row labels (left column).
    local curRowY = ROWS_TOP
    for ri, row in ipairs(rows) do
        local h = (row.type == "sechdr") and HDR_ROW_H or ROW_H
        local rowTop = curRowY

        if row.type == "sechdr" then
            local secBg = GetDiv()
            secBg:SetColorTexture(header.r, header.g, header.b, STYLE.sectionBandA * chromeA)
            secBg:SetPoint("TOPLEFT",  panel, "TOPLEFT",   1, curRowY)
            secBg:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, curRowY)
            secBg:SetHeight(h)

            local secTopLine = GetDiv()
            secTopLine:SetHeight(1)
            secTopLine:SetColorTexture(header.r, header.g, header.b, STYLE.sectionLineA * chromeA)
            secTopLine:SetPoint("TOPLEFT",  panel, "TOPLEFT",   1, curRowY)
            secTopLine:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, curRowY)

            local secBottomLine = GetDiv()
            secBottomLine:SetHeight(1)
            secBottomLine:SetColorTexture(header.r, header.g, header.b, STYLE.sectionLineA * chromeA)
            secBottomLine:SetPoint("TOPLEFT",  panel, "TOPLEFT",   1, curRowY - h + 1)
            secBottomLine:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, curRowY - h + 1)

            local secFS = GetLbl(10, "")
            secFS:SetTextColor(header.r, header.g, header.b, 0.90)
            secFS:SetJustifyH("LEFT")
            secFS:SetJustifyV("MIDDLE")
            secFS:SetText(row.label)
            secFS:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD + 4, curRowY)
            secFS:SetSize(COL_LABEL - 4, h)
            if row.action then
                secBg:EnableMouse(true)
                secBg:SetScript("OnMouseUp", function()
                    if row.action == "currency" then
                        ToggleCharacter("TokenFrame")
                    elseif row.action == "greatvault" then
                        Addon:ToggleGreatVault()
                    end
                end)
                secBg:SetScript("OnEnter", function(s_)
                    ShowHover(rowTop, h - 1)
                    GameTooltip:SetOwner(s_, "ANCHOR_RIGHT")
                    GameTooltip:SetText(L.TOOLTIP_CLICK_TO_OPEN or "Click to open", 1, 1, 1)
                    GameTooltip:Show()
                end)
                secBg:SetScript("OnLeave", function()
                    HideHover()
                    GameTooltip:Hide()
                end)
            end
        else
            local rowBg = GetDiv()
            if (ri % 2) == 0 then
                rowBg:SetColorTexture(1, 1, 1, STYLE.rowLightA * chromeA)
            else
                rowBg:SetColorTexture(0, 0, 0, STYLE.rowDarkA * chromeA)
            end
            rowBg:SetPoint("TOPLEFT",  panel, "TOPLEFT",   1, curRowY)
            rowBg:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, curRowY)
            rowBg:SetHeight(h - 1)

            local rowSep = GetDiv()
            rowSep:SetHeight(1)
            rowSep:SetColorTexture(brd.r, brd.g, brd.b, STYLE.rowLineA * chromeA)
            rowSep:SetPoint("TOPLEFT",  panel, "TOPLEFT",   PAD, curRowY - h + 1)
            rowSep:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, curRowY - h + 1)

            -- Currency icon (if available for this row).
            local textX, textW
            if row.iconID then
                local iconTex  = GetIcon()
                iconTex:SetTexture(row.iconID)
                local iconOffY = curRowY - math.floor((h - ICON_SIZE) / 2)
                iconTex:ClearAllPoints()
                iconTex:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD + 2, iconOffY)
                textX = PAD + 3 + ICON_SIZE + 4
                textW = COL_LABEL - ICON_SIZE - 12
            else
                textX = PAD + 4
                textW = COL_LABEL - 8
            end

            local lblFS = GetLbl(row.iconID and 10 or 11, "")
            if row.type == "crest" or row.type == "upgcost" or row.type == "quest" then
                lblFS:SetTextColor(row.cr or th.r, row.cg or th.g, row.cb or th.b, 0.90)
            elseif row.type == "catalyst" or row.type == "sparks"
                or row.type == "keys"     or row.type == "misc"
                or row.type == "weapupg" then
                lblFS:SetTextColor(row.cr or 1, row.cg or 0.82, row.cb or 0, 0.85)
            else
                lblFS:SetTextColor(th.r, th.g, th.b, 0.80)
            end
            lblFS:SetJustifyH("LEFT")
            lblFS:SetJustifyV("MIDDLE")
            lblFS:SetText(row.label)
            lblFS:SetPoint("TOPLEFT", panel, "TOPLEFT", textX, curRowY)
            lblFS:SetSize(textW, h)

            -- Transparent hit frame so hovering the label shows the currency tooltip.
            local cID = row.currencyID or (row.type == "misc" and row.miscID)
            if cID then
                local hit = GetHit()
                hit:ClearAllPoints()
                hit:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, curRowY)
                hit:SetSize(COL_LABEL - PAD, h - 1)
                local _cid = tonumber(cID)
                hit:SetScript("OnEnter", function(s_)
                    ShowHover(rowTop, h - 1)
                    if not _cid then return end
                    GameTooltip:SetOwner(s_, "ANCHOR_RIGHT")
                    GameTooltip:SetCurrencyByID(_cid)
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine(L.CONTEXT_RIGHT_CLICK_HIDE or "Right-click to hide", 0.5, 0.5, 0.5)
                    GameTooltip:Show()
                end)
                hit:SetScript("OnMouseUp", function(s_, button)
                    if button ~= "RightButton" then return end
                    ShowCurrencyHideMenu(s_, _cid)
                end)
            else
                local hit = GetHit()
                hit:ClearAllPoints()
                hit:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, curRowY)
                hit:SetSize(COL_LABEL - PAD, h - 1)
                hit:SetScript("OnEnter", function()
                    ShowHover(rowTop, h - 1)
                end)
            end
        end

        curRowY = curRowY - h
    end

    local chk = panel._summaryChk
    if chk then
        if hasHiddenChars then
            chk:ClearAllPoints()
            chk:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD + 4, CONTENT_TOP - 4)
            chk:SetSize(14, 14)
            chk:SetChecked(_showHidden)
            chk:Show()
            if chk._label then chk._label:Show() end
            if chk._hit then
                chk._hit:ClearAllPoints()
                chk._hit:SetPoint("LEFT",  chk, "LEFT",  -2, 0)
                chk._hit:SetPoint("RIGHT", chk, "RIGHT", 160, 0)
                chk._hit:SetHeight(18)
                chk._hit:Show()
            end
        else
            chk:Hide()
            if chk._label then chk._label:Hide() end
            if chk._hit then chk._hit:Hide() end
        end
    end

    -- ── Character columns ─────────────────────────────────────────────────────
    local crestIDs = {}
    if tracking and tracking.crestCurrencyIDs then
        for i = 1, NUM_CRESTS do crestIDs[i] = tracking.crestCurrencyIDs[i] end
    end

    for ci, char in ipairs(chars) do
        local colX   = PAD + COL_LABEL + (ci - 1) * colW
        local snap   = char.snap
        local noSnap = not snap

        -- Vertical column separator.
        if ci > 1 then
            local colSep = GetDiv()
            colSep:SetWidth(1)
            colSep:SetColorTexture(brd.r, brd.g, brd.b, STYLE.colLineA * chromeA)
            colSep:SetPoint("TOPLEFT",    panel, "TOPLEFT", colX - 1, COL_HDR_TOP)
            colSep:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", colX - 1, FOOTER_TOP)
        end

        local col = GetCol()

        -- Class-color accent at the top of the name header.
        col.classBar:SetColorTexture(char.cr, char.cg, char.cb, STYLE.classBarA)
        col.classBar:SetPoint("TOPLEFT",  panel, "TOPLEFT", colX + 5,         COL_HDR_TOP - 1)
        col.classBar:SetPoint("TOPRIGHT", panel, "TOPLEFT", colX + colW - 5, COL_HDR_TOP - 1)
        col.classBar:SetHeight(3)

        -- Character name.
        local charName = (char.key:match("^(.-)%s*%-") or char.key):gsub("^%s+",""):gsub("%s+$","")
        if charName == "" then charName = char.key end
        local maxChars = math.floor(colW / 7)
        if #charName > maxChars then charName = charName:sub(1, maxChars - 1) .. "." end

        col.nameFS:SetText(charName)
        col.nameFS:SetFont(FONT_FACE, 12, FONT_FLAGS)
        col.nameFS:SetTextColor(char.cr, char.cg, char.cb, char.alpha)
        col.nameFS:SetJustifyH("CENTER")
        col.nameFS:SetJustifyV("MIDDLE")
        col.nameFS:ClearAllPoints()
        col.nameFS:SetPoint("TOPLEFT", panel, "TOPLEFT", colX, COL_HDR_TOP - 2)
        col.nameFS:SetSize(colW, 18)

        -- Item level below character name.
        if col.ilvlFS then
            local ilvlText = (char.ilvl and char.ilvl > 0) and tostring(math.floor(char.ilvl)) or ""
            col.ilvlFS:SetText(ilvlText)
            col.ilvlFS:SetFont(FONT_FACE, 11, FONT_FLAGS)
            -- Color by the highest crest tier the character qualifies for.
            local ir, ig, ib = 0.85, 0.75, 0.5  -- default warm-gold fallback
            if char.ilvl and char.ilvl > 0 and Addon.IlvlUtils then
                local tier   = Addon.IlvlUtils.GetTier(char.ilvl)
                local colors = Addon.TRACKING and Addon.TRACKING.crestColors
                if tier and colors and colors[tier] then
                    ir, ig, ib = HexToRGB(colors[tier])
                end
            end
            col.ilvlFS:SetTextColor(ir, ig, ib, char.alpha * A_ILVL)
            col.ilvlFS:SetJustifyH("CENTER")
            col.ilvlFS:SetJustifyV("MIDDLE")
            col.ilvlFS:ClearAllPoints()
            col.ilvlFS:SetPoint("TOPLEFT", panel, "TOPLEFT", colX, COL_HDR_TOP - 20)
            col.ilvlFS:SetSize(colW, 13)
        end

        -- Column-header hit region: tooltip showing full last-updated datetime.
        if col.hdrHit then
            col.hdrHit:ClearAllPoints()
            col.hdrHit:SetPoint("TOPLEFT", panel, "TOPLEFT", colX, COL_HDR_TOP)
            col.hdrHit:SetSize(colW, COL_HDR_H)
            local _snap, _name, _cr, _cg, _cb = snap, charName, char.cr, char.cg, char.cb
            local _ck, _isOwn, _isHidden = char.key, char.isOwn, char.isHidden
            col.hdrHit:SetScript("OnEnter", function(s_)
                GameTooltip:SetOwner(s_, "ANCHOR_RIGHT")
                GameTooltip:SetText(_name, _cr, _cg, _cb)
                if _snap and _snap.updatedAt then
                    GameTooltip:AddLine((L.ALT_SUMMARY_LAST_UPDATED_FMT or "Last updated: %s"):format(date("%b %d %Y %H:%M", _snap.updatedAt)), 0.65, 0.65, 0.65)
                else
                    GameTooltip:AddLine(L.ALT_SUMMARY_NO_SNAPSHOT or "No snapshot data", 0.5, 0.5, 0.5)
                end
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(L.ALT_SUMMARY_LEFT_CLICK_GEAR or "Left-click to display gear", 0.5, 0.5, 0.5)
                GameTooltip:AddLine(L.ALT_SUMMARY_ALT_LEFT_CLICK_REORDER or "Alt+drag to reorder", 0.5, 0.5, 0.5)
                if not _isOwn then
                    local actionText = _isHidden and (L.CHAR_PICKER_SHOW or "Show") or (L.CHAR_PICKER_HIDE or "Hide")
                    GameTooltip:AddLine((L.ALT_SUMMARY_RIGHT_CLICK_ACTION_FMT or "Right-click: %s"):format(actionText), 0.5, 0.5, 0.5)
                end
                GameTooltip:Show()
            end)
            col.hdrHit:SetScript("OnMouseDown", function(s_, button)
                if button ~= "LeftButton" then return end
                if not (IsAltKeyDown and IsAltKeyDown()) then return end
                ClearDragState()
                local startX = GetPanelCursorX(panel)
                if not startX then return end
                panel._dragState = {
                    active = false,
                    startX = startX,
                    sourceIdx = ci,
                    targetIdx = ci,
                    charKey = _ck,
                    char = char,
                    col = col,
                }
            end)
            col.hdrHit:SetScript("OnMouseUp", function(s_, button)
                if button == "LeftButton" then
                    local state = panel._dragState
                    if state and state.charKey == _ck and not state.active then
                        ClearDragState()
                        if _gearPopupFrame and _gearPopupFrame:IsShown()
                           and _gearPopupFrame._charKey == _ck then
                            _gearPopupFrame:Hide()
                        else
                            ShowGearPopup(s_, _ck, _name, _cr, _cg, _cb, _snap)
                        end
                    end
                elseif button == "RightButton" and not _isOwn then
                    if Addon.HideContextMenu then
                        Addon:HideContextMenu()
                    end
                    SetCharHiddenFromSummary(panel, gdb, _ck, not _isHidden)
                end
            end)
        end

        -- Pre-extract all snapshot data.
        local sd = ExtractSnapData(snap, crestIDs, LAYOUT)
        -- Find the highest-tier crest that has a trade-up value (only that tier shows +N).
        local highestTuIdx = 0
        for i = NUM_CRESTS, 1, -1 do
            if (sd.crestTradeups[i] or 0) > 0 then highestTuIdx = i; break end
        end
        local gvR, gvM, gvW = CalcGVBreakdown(snap)

        -- Data cells.
        local cellRowY = ROWS_TOP
        for ri, row in ipairs(rows) do
            local h = (row.type == "sechdr") and HDR_ROW_H or ROW_H
            local rowTop = cellRowY

            if row.type ~= "sechdr" then
                local cell = GetCell(col, ri)
                cell:ClearAllPoints()
                cell:SetPoint("TOPLEFT", panel, "TOPLEFT", colX, cellRowY)
                cell:SetSize(colW, h)

                cell._fs:SetFont(FONT_FACE, FONT_CELL, FONT_FLAGS)
                SetPlaceholder(cell, th, A_DIM)
                cell._tu:SetText("")
                cell:SetScript("OnEnter", nil)

                local alpha = char.alpha
                local rtype = row.type

                if rtype == "crest" then
                    RenderCrestCell(cell, row, sd, noSnap, alpha, th, crestIDs, highestTuIdx)
                elseif rtype == "catalyst" then
                    RenderCatalystCell(cell, row, sd, noSnap, alpha, th)
                elseif rtype == "sparks" then
                    RenderSparksCell(cell, row, sd, noSnap, alpha, th)
                elseif rtype == "misc" then
                    RenderMiscCell(cell, row, sd, noSnap, alpha, th)
                elseif rtype == "quest" then
                    RenderQuestCell(cell, row, sd, noSnap, alpha, th)
                elseif rtype == "checkitem" then
                    RenderChecklistItemCell(cell, row, char, alpha, th)
                elseif rtype == "upgcost" then
                    RenderUpgradeCostCell(cell, row, snap, noSnap, alpha, th)
                elseif rtype == "keystone" then
                    RenderKeystoneCell(cell, row, snap, noSnap, alpha, th)
                elseif rtype == "gv" then
                    RenderGVCell(cell, row, snap, noSnap, alpha)
                elseif rtype == "weapupg" then
                    RenderWeapUpgCell(cell, row, sd, noSnap, alpha, th)
                end

                cell._fs:SetJustifyH("CENTER")

                local existingOnEnter = cell:GetScript("OnEnter")
                cell:SetScript("OnEnter", function(s_)
                    ShowHover(rowTop, h - 1, colX, colW)
                    if existingOnEnter then existingOnEnter(s_) end
                end)

                local hideCurrencyID = row.currencyID or (row.type == "misc" and row.miscID)
                local hideItemID = row.itemID
                local hideQuestKey = row.questKey
                if hideCurrencyID or hideItemID or hideQuestKey then
                    local _cid = hideCurrencyID
                    local _itemID = hideItemID
                    local _questKey = hideQuestKey
                    cell:SetScript("OnMouseUp", function(s_, button)
                        if button ~= "RightButton" then return end
                        if _cid then
                            ShowCurrencyHideMenu(s_, _cid)
                        elseif _itemID then
                            ShowItemHideMenu(s_, _itemID)
                        elseif _questKey then
                            Addon:ShowContextMenu(s_, {
                                { text = L.CONTEXT_HIDE_THIS_ROW or "Hide this row", onClick = function()
                                    Addon:SetQuestHidden(_questKey, true)
                                end },
                            })
                        end
                    end)
                else
                    cell:SetScript("OnMouseUp", nil)
                end
            end

            cellRowY = cellRowY - h
        end
    end

    -- No-chars placeholder.
    if numChars == 0 then
        local noCharFS = GetLbl(11, "")
        noCharFS:SetTextColor(th.r, th.g, th.b, 0.5)
        noCharFS:SetJustifyH("CENTER")
        noCharFS:SetJustifyV("MIDDLE")
        noCharFS:SetText(L.ALT_SUMMARY_NO_CHARACTERS or "No characters found")
        noCharFS:SetPoint("CENTER", panel, "CENTER", 0, 0)
        noCharFS:SetSize(200, 30)
    end
end

-- ── Public API ────────────────────────────────────────────────────────────────

function Addon:OpenAltsSummary(anchorFrame)
    local f = EnsurePanel()
    if (not self.HasTrackingSnapshot or not self:HasTrackingSnapshot()) and self.UpdateSnapshotBackground then
        self:UpdateSnapshotBackground()
    end
    -- Sync scale and opacity to current settings (frame may have been created lazily).
    f:SetScale(Addon.GetUIScale and Addon:GetUIScale() or 1.0)
    if Addon.ApplyOpacity then Addon:ApplyOpacity() end
    if not f._wasMoved then
        f:ClearAllPoints()
        if anchorFrame then
            f:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, -4)
        else
            f:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
        end
        f:SetClampedToScreen(true)
    end
    f._inline  = false
    if _panelDirty or _rowsDirty or not f._lariasAltSummaryPopulated then
        PopulateSummary(f)
    end
    f:Show()
end

function Addon:CloseAltsSummary()
    if altSummaryFrame then altSummaryFrame:Hide() end
    if _gearPopupFrame then _gearPopupFrame:Hide() end
end

function Addon:ToggleAltsSummary(anchorFrame)
    local f = altSummaryFrame
    if f and f.IsShown and f:IsShown() then
        if _gearPopupFrame then _gearPopupFrame:Hide() end
        f:Hide()
    else
        self:OpenAltsSummary(anchorFrame)
    end
end

function Addon:RefreshAltsSummary()
    if altSummaryFrame and altSummaryFrame.IsShown and altSummaryFrame:IsShown() then
        _rowsDirty = true  -- currency/GV hidden state may have changed
        _panelDirty = true
        ScheduleSummaryRefresh()
    else
        _rowsDirty = true
        _panelDirty = true
    end
end

function Addon:MarkAltsSummaryDirty(structureChanged)
    if structureChanged then
        _rowsDirty = true
    end
    _panelDirty = true
    ScheduleSummaryRefresh()
end
