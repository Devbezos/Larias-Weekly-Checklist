-- LariasWeeklyChecklist_Overlay.lua
-- Owns the tracking panel frame, event routing, snapshot persistence and
-- all UI rendering.  Pure data computation lives in GreatVault.lua and
-- Currency.lua; this file wires them together through the Addon: API.
local addonName = ...
local Addon = _G[addonName]
if not Addon then return end

if Addon.InitConstants then
    Addon:InitConstants(addonName)
end

local THEME = Addon.THEME
local UI    = Addon.UI
local L     = Addon.L or {}

local tonumber, tostring, type = tonumber, tostring, type
local floor, max, abs = math.floor, math.max, math.abs
local tinsert, tconcat = table.insert, table.concat

--  Module-level state 
Addon.TRACKING = Addon.TRACKING or {}

-- TrackingUI owns every sub-frame/FontString created by CreateTrackingPanel.
local TrackingUI = { left = {}, right = {} }

-- Key lists for ResizeTrackingCols to iterate without allocating.
local LEFT_LINE_KEYS  = { "line1","line2","line3","line4","line5","line6","line7","line8","line9" }
local RIGHT_LINE_COUNT = Addon.RIGHT_LINE_COUNT or 10
local RIGHT_ROW_KEYS  = {}
for _i = 1, RIGHT_LINE_COUNT do RIGHT_ROW_KEYS[_i] = "line" .. _i end
local EnsureRightRowCount

-- GV layout constants (sourced from Addon.GV_LAYOUT set by GreatVault.lua).
local _GL           = Addon.GV_LAYOUT
local GV_LABEL_W    = _GL.LABEL_W
local GV_LABEL_GAP  = _GL.LABEL_GAP
local GV_GRID_X     = _GL.GRID_X
local GV_ROW_H      = _GL.ROW_H
local GV_GRID_H     = _GL.GRID_H
local GV_BLOCK_STEP = _GL.BLOCK_STEP
local GV_BLOCK_Y    = _GL.BLOCK_Y
local GV_CELL_W     = _GL.CELL_W
local GV_GRID_W     = _GL.GRID_W

--  Shared mini-utilities 
local AU             = Addon.AddonUtils
local COLORS         = AU.COLORS
local ColorWrap      = AU.ColorWrap
local Wipe           = AU.Wipe
local IsNonEmptyText = AU.IsNonEmptyText
local FormatXY       = AU.FormatXY
local ColorForXY     = AU.ColorForXY
local GetCurrencyName = AU.GetCurrencyName
local GetItemName     = AU.GetItemName

local function SetTextIfChanged(fs, text)
    if not fs then return end
    text = text or ""
    if fs._lariasText ~= text then
        fs._lariasText = text
        fs:SetText(text)
    end
end

local function SetShownIfChanged(region, shown)
    if not (region and region.IsShown and region.SetShown) then return end
    local want = shown and true or false
    if region:IsShown() ~= want then region:SetShown(want) end
end

local IsFrameShown = AU.IsFrameShown

local function BottomFor(obj)
    if not obj then return 0 end
    if obj.IsShown and not IsFrameShown(obj) then return 0 end
    local y = tonumber(obj._lariasBaseY) or 0
    local h = 0
    if obj.GetStringHeight then h = tonumber(obj:GetStringHeight()) or 0 end
    if h <= 0 and obj.GetHeight then h = tonumber(obj:GetHeight()) or 0 end
    if h <= 0 then h = 16 end
    return abs(y) + h
end

local function IsMainFrameOnListTab()
    local main = _G and _G["LariasWeeklyChecklistFrame"]
    local selectedTab = main and tonumber(main._lariasSelectedTab)
    return (selectedTab == nil) or (selectedTab == 1)
end

--  Rendering helpers 

local function ApplyGreatVaultGrid(gridBlocks)
    local grids = TrackingUI.left.gvGrids
    if not grids then return end
    local function setGridVisible(grid, shown)
        local function sv(obj) if obj then if shown then obj:Show() else obj:Hide() end end end
        sv(grid.header); sv(grid.topLine); sv(grid.botLine)
        sv(grid.vLeft);  sv(grid.vRight);  sv(grid.vMid1); sv(grid.vMid2)
        if grid.cells then
            for col = 1, 3 do
                local cell = grid.cells[col]
                if cell then sv(cell.bot); sv(cell.hit) end
            end
        end
        -- _hoverZone shows/hides with the block; _xBtn appears on hover only
        sv(grid._hoverZone)
        if grid._xBtn then grid._xBtn:Hide() end
    end
    for bi = 1, 3 do
        local grid  = grids[bi]
        local block = gridBlocks and gridBlocks[bi]
        if not (grid and grid.cells) then break end
        if Addon:IsGVBlockHidden(bi) then
            setGridVisible(grid, false)
        else
            setGridVisible(grid, true)
            if block and block.available then
                local done = block.complete or 0
                if grid.header then grid.header:SetTextColor(1, 1, 1, 1) end
                for col = 1, 3 do
                    local slot     = block.slots and block.slots[col]
                    local ilvl     = slot and slot.ilvl or 0
                    local unlocked = done >= col
                    local cell     = grid.cells[col]
                    local txt
                    if unlocked and ilvl > 0 then
                        txt = ColorWrap(Addon.IlvlUtils.GetColorHex(ilvl), tostring(ilvl))
                        if cell.hit then
                            cell.hit._lariasTooltipText = Addon.IlvlUtils.GetTrackLabel(ilvl)
                        end
                    else
                        txt = ColorWrap(COLORS.dim, "-")
                        if cell.hit then cell.hit._lariasTooltipText = nil end
                    end
                    SetTextIfChanged(cell.bot, txt)
                end
            else
                if grid.header then grid.header:SetTextColor(0.5, 0.5, 0.5, 1.0) end
                for col = 1, 3 do
                    local cell = grid.cells[col]
                    SetTextIfChanged(cell.bot, ColorWrap(COLORS.dim, "-"))
                    if cell.hit then cell.hit._lariasTooltipText = nil end
                end
            end
        end
    end
end

local function SetRightRowPair(i, rowLabel, rowValue, iconFileID, currencyID, tooltipText, amountTooltipText, itemID, questKey)
    if EnsureRightRowCount then EnsureRightRowCount(i) end
    local row = TrackingUI.right[RIGHT_ROW_KEYS[i]]
    if not (row and row.label and row.value) then return end
    rowLabel = rowLabel or ""; rowValue = rowValue or ""
    local txt = Addon.THEME and Addon.THEME.text
    if txt then
        row.label:SetTextColor(txt.r, txt.g, txt.b, txt.a or 1)
        row.value:SetTextColor(txt.r, txt.g, txt.b, txt.a or 1)
    end
    SetTextIfChanged(row.label, rowLabel)
    SetTextIfChanged(row.value, rowValue)
    local showRow = IsNonEmptyText(rowLabel) or IsNonEmptyText(rowValue)
    SetShownIfChanged(row.frame or row.label, showRow)
    if row.frame then
        row.frame._lariasTooltipText       = tooltipText or nil
        row.frame._lariasAmountTooltipText = amountTooltipText or nil
    end
    if row.icon then
        if showRow and iconFileID and iconFileID ~= 0 then
            if row.icon._tex then row.icon._tex:SetTexture(iconFileID) end
            row.icon._lariasIconCurrencyID = (not itemID) and currencyID or nil
            row.icon._lariasIconItemID     = itemID or nil
            row.icon._lariasIconQuestKey   = questKey or nil
            SetShownIfChanged(row.icon, true)
        else
            if row.icon._tex then row.icon._tex:SetTexture(nil) end
            row.icon._lariasIconCurrencyID = nil
            row.icon._lariasIconItemID     = nil
            row.icon._lariasIconQuestKey   = nil
            SetShownIfChanged(row.icon, false)
        end
    end
    if row.frame then
        row.frame._lariasRightClickCurrencyID = (showRow and currencyID) and currencyID or nil
        row.frame._lariasRightClickItemID     = (showRow and itemID) and itemID or nil
        row.frame._lariasRightClickQuestKey   = (showRow and questKey) and questKey or nil
    end
end

local function ApplyRightColumnAsPairs()
    -- Delegates to Currency module for the row data.
    local panelRows = Addon:GetCurrencyPanelRows()
    if EnsureRightRowCount then EnsureRightRowCount(max(RIGHT_LINE_COUNT, #panelRows)) end
    for i, row in ipairs(panelRows) do
        SetRightRowPair(i, row.label, row.value, row.iconID, row.currencyID, row.tooltipText, row.amountTooltipText, row.itemID, row.questKey)
    end
    for i = #panelRows + 1, RIGHT_LINE_COUNT do
        SetRightRowPair(i, "", "")
    end
end

local function ResizeTrackingPanelToContent(addon)
    local trackingFrame = addon._trackingFrame
    if not (trackingFrame and trackingFrame.GetHeight and trackingFrame.SetHeight) then return end

    local bottomRight = 0
    for i = 1, RIGHT_LINE_COUNT do
        local row = TrackingUI.right[RIGHT_ROW_KEYS[i]]
        if type(row) == "table" then
            bottomRight = max(bottomRight, BottomFor(row.frame or row.label))
        else
            bottomRight = max(bottomRight, BottomFor(row))
        end
    end

    -- Reflow GV rows: use natural cell height (squares stay square) and centre
    -- the blocks vertically.  targetH drives how much space to centre within;
    -- at least naturalGvH so currency shrinking never collapses the GV.
    if Addon._reflowGVGrid then
        local GAP        = 8
        local nVisible   = 0
        for bi = 1, 3 do
            if not addon:IsGVBlockHidden(bi) then nVisible = nVisible + 1 end
        end
        local naturalGvH = nVisible * GV_GRID_H + max(0, nVisible - 1) * GAP
        local targetGvH  = max(naturalGvH, bottomRight)
        Addon._reflowGVGrid(targetGvH > 0 and targetGvH or nil)
    end

    local bottomLeft = max(0, BottomFor(TrackingUI.left._gvSentinel))
    local contentH   = max(bottomLeft, bottomRight)
    local topOffset  = 32
    local bottomPad  = 10
    local minH       = 90
    local targetH    = max(minH, topOffset + contentH + bottomPad)
    do
        local main = addon._mainFrame
        local frameH = (main and main.GetHeight and tonumber(main:GetHeight())) or UI.frameH or 737
        local trackingBottomY = (UI.sliderBottomPad or 4) + (UI.sliderH or 20)
        local minScrollH = 44
        local maxH = frameH
            - trackingBottomY
            - (UI.scrollTop or 38)
            - (UI.trackTopPad or 10)
            - minScrollH
        targetH = math.min(targetH, max(minH, maxH))
    end
    local curH       = tonumber(trackingFrame:GetHeight()) or 0
    if abs(curH - targetH) <= 1 then return end

    trackingFrame:SetHeight(targetH)
    if trackingFrame._lariasLeftCol  and trackingFrame._lariasLeftCol.SetHeight  then trackingFrame._lariasLeftCol:SetHeight(max(1, targetH - 40))  end
    if trackingFrame._lariasRightCol and trackingFrame._lariasRightCol.SetHeight then trackingFrame._lariasRightCol:SetHeight(max(1, targetH - 40)) end
    if addon.ApplyScrollLayout then addon:ApplyScrollLayout() end
end

local function ComputeWantTrackingPanel(prefs)
    local wantPanel = (prefs.showGreatVault or prefs.showCurrency) and true or false
    if wantPanel and not IsMainFrameOnListTab() then wantPanel = false end
    return wantPanel
end

local function EnsureTrackingPanelCreatedIfNeeded(wantPanel)
    if not wantPanel or Addon._trackingFrame then return end
    local main = _G["LariasWeeklyChecklistFrame"]
    if main then
        Addon:CreateTrackingPanel(main)
        Addon:ApplyScrollLayout()
    end
end

--  Panel creation 
function Addon:CreateTrackingPanel(parentFrame)
    if self._trackingFrame then return end
    local db = self:EnsurePrefs()

    local trackingFrame = CreateFrame("Frame", nil, parentFrame)
    local trackingBottomY = (UI.sliderBottomPad or 4) + (UI.sliderH or 20)
    trackingFrame:SetPoint("BOTTOMLEFT",  parentFrame, "BOTTOMLEFT",  UI.sectionInsetX,  trackingBottomY)
    trackingFrame:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", -UI.sectionInsetX, trackingBottomY)
    trackingFrame:SetHeight(UI.trackH)
    self:RegisterWindowSurface(trackingFrame, { opacityMode = "ui", borderStyle = "panel" })

    local title = trackingFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", trackingFrame, "TOPLEFT", 10, -8)
    title:SetTextColor(THEME.header.r, THEME.header.g, THEME.header.b, THEME.header.a)
    title:SetText(L.TRACKING_GREAT_VAULT_TITLE or "Great Vault")
    trackingFrame._lariasLeftTitle = title

    local padL, padR = 10, 10
    local colGap = 12
    local innerW = (UI.frameW - (UI.sectionInsetX * 2) - padL - padR)
    local colW   = math.floor((innerW - colGap) / 2)
    trackingFrame._lariasPadL    = padL
    trackingFrame._lariasPadR    = padR
    trackingFrame._lariasColGap  = colGap
    trackingFrame._lariasColW    = colW

    local leftCol = CreateFrame("Frame", nil, trackingFrame)
    leftCol:SetPoint("TOPLEFT", trackingFrame, "TOPLEFT", padL, -32)
    leftCol:SetSize(colW, UI.trackH - 40)
    trackingFrame._lariasLeftCol = leftCol

    local rightCol = CreateFrame("Frame", nil, trackingFrame)
    rightCol:SetPoint("TOPLEFT", leftCol, "TOPRIGHT", colGap, 0)
    rightCol:SetSize(colW, UI.trackH - 40)
    trackingFrame._lariasRightCol = rightCol

    local BOX_PAD = 6

    local function MakeTitleButton(col, tipText, onClick)
        local btn = CreateFrame("Button", nil, trackingFrame)
        btn:SetPoint("TOPLEFT",     col, "TOPLEFT",  -BOX_PAD,  24 + BOX_PAD)
        btn:SetPoint("BOTTOMRIGHT", col, "TOPRIGHT",  BOX_PAD,  BOX_PAD)
        btn:EnableMouse(true)
        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.07)
        btn:SetScript("OnEnter", function(self) AU.SetTooltip(self, tipText, "ANCHOR_TOP") end)
        btn:SetScript("OnLeave", AU.HideTooltip)
        btn:RegisterForClicks("AnyUp")
        if onClick then
            btn:SetScript("OnClick", function(self_, button)
                if button == "RightButton" then return end
                onClick()
            end)
        end
        return btn
    end

    -- Vertical separator shown between the two columns.
    local colSep = trackingFrame:CreateTexture(nil, "ARTWORK")
    colSep:SetColorTexture(THEME.border.r, THEME.border.g, THEME.border.b,
        (Addon.VISUAL_STYLE and Addon.VISUAL_STYLE.strongDividerA) or 0.65)
    colSep:SetWidth(1)
    colSep:SetPoint("TOPLEFT",    leftCol, "TOPRIGHT",    floor(colGap / 2), 24 + BOX_PAD)
    colSep:SetPoint("BOTTOMLEFT", leftCol, "BOTTOMRIGHT", floor(colGap / 2), -BOX_PAD)
    colSep:Hide()
    trackingFrame._lariasColSep = colSep

    trackingFrame._lariasLeftTitleBtn = MakeTitleButton(leftCol,
        L.TOOLTIP_OPEN_GREAT_VAULT or "Click to open the Great Vault",
        function()
            Addon:ToggleGreatVault()
        end)
    trackingFrame._lariasLeftTitleBtn:HookScript("OnClick", function(self_, button)
        if button ~= "RightButton" then return end
        Addon:ShowContextMenu(self_, {
            { text = L.CONTEXT_DISABLE_GREAT_VAULT or "Disable Great Vault Section", onClick = function()
                local db = Addon:EnsurePrefs()
                db.showGreatVault = false
                if Addon.RequestRefresh then Addon:RequestRefresh() else Addon:Refresh() end
                if Addon.SyncGearPopup then Addon:SyncGearPopup() end
            end },
        })
    end)

    trackingFrame._lariasRightTitleBtn = MakeTitleButton(rightCol,
        L.TOOLTIP_OPEN_CURRENCIES or "Click to open the Currency panel",
        function() ToggleCharacter("TokenFrame") end)
    trackingFrame._lariasRightTitleBtn:HookScript("OnClick", function(self_, button)
        if button ~= "RightButton" then return end
        Addon:ShowContextMenu(self_, {
            { text = L.CONTEXT_DISABLE_CURRENCY or "Disable Currency Section", onClick = function()
                local db = Addon:EnsurePrefs()
                db.showCurrency = false
                if Addon.RequestRefresh then Addon:RequestRefresh() else Addon:Refresh() end
                if Addon.SyncGearPopup then Addon:SyncGearPopup() end
            end },
        })
    end)

    local rightTitle = trackingFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    rightTitle:SetPoint("TOPLEFT", trackingFrame, "TOPLEFT", padL + colW + colGap, -8)
    rightTitle:SetTextColor(THEME.header.r, THEME.header.g, THEME.header.b, THEME.header.a)
    rightTitle:SetText(L.TRACKING_CURRENCY_TITLE or "Currency")
    trackingFrame._lariasRightTitle = rightTitle

    title:ClearAllPoints()
    title:SetPoint("TOP", leftCol, "TOP", 0, 24)
    title:SetWidth(colW); title:SetJustifyH("CENTER")

    rightTitle:ClearAllPoints()
    rightTitle:SetPoint("TOP", rightCol, "TOP", 0, 24)
    rightTitle:SetWidth(colW); rightTitle:SetJustifyH("CENTER")

    --  Great Vault grids 
    local GV_SECTION_KEYS   = { "TRACKING_GV_RAID", "TRACKING_GV_DUNGEONS", "TRACKING_GV_WORLD" }
    local GV_SECTION_LABELS = { "Raid", "Dungeons", "World" }
    local GRID_BOR_A = (Addon.VISUAL_STYLE and Addon.VISUAL_STYLE.trackingBorderA) or 0.55
    local GRID_MID_A = (Addon.VISUAL_STYLE and Addon.VISUAL_STYLE.trackingInnerA) or 0.30
    local CELL_INSET = 4

    local function MakeHLine(yOff, alpha, xOff, w)
        local t = leftCol:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(THEME.border.r, THEME.border.g, THEME.border.b, alpha)
        t:SetHeight(1)
        t:SetPoint("TOPLEFT", leftCol, "TOPLEFT", xOff or 0, yOff)
        if w then t:SetWidth(w) else t:SetPoint("TOPRIGHT", leftCol, "TOPRIGHT", 0, yOff) end
        t._lariasBaseY = yOff
        return t
    end

    local function MakeVLine(xOff, yOff, alpha)
        local t = leftCol:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(THEME.border.r, THEME.border.g, THEME.border.b, alpha)
        t:SetSize(1, GV_GRID_H)
        t:SetPoint("TOPLEFT", leftCol, "TOPLEFT", xOff, yOff)
        return t
    end

    local function MakeCellFS(xOff, yOff, w)
        local fs = leftCol:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        fs:SetPoint("TOPLEFT", leftCol, "TOPLEFT", xOff, yOff)
        fs:SetSize(w, GV_ROW_H); fs:SetJustifyH("CENTER"); fs:SetJustifyV("MIDDLE")
        if fs.SetWordWrap then fs:SetWordWrap(false) end
        fs:SetText("")
        return fs
    end

    local gvGrids = {}
    for bi = 1, 3 do
        local blockY   = GV_BLOCK_Y[bi]
        local gridBotY = blockY - 1 - GV_ROW_H
        local cellW    = GV_CELL_W

        local topLine = MakeHLine(blockY,   GRID_BOR_A, GV_GRID_X, GV_GRID_W)
        local botLine = MakeHLine(gridBotY, GRID_BOR_A, GV_GRID_X, GV_GRID_W)
        botLine._lariasBaseY = gridBotY

        local hdr = leftCol:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        hdr:SetPoint("TOPLEFT", leftCol, "TOPLEFT", 0, blockY)
        hdr:SetSize(GV_LABEL_W, GV_GRID_H); hdr:SetJustifyH("LEFT"); hdr:SetJustifyV("MIDDLE")
        if hdr.SetWordWrap then hdr:SetWordWrap(false) end
        hdr:SetTextColor(THEME.header.r, THEME.header.g, THEME.header.b, THEME.header.a)
        hdr:SetText(L[GV_SECTION_KEYS[bi]] or GV_SECTION_LABELS[bi])

        local vLeft  = MakeVLine(GV_GRID_X,           blockY, GRID_BOR_A)
        local vRight = MakeVLine(GV_GRID_X + GV_GRID_W, blockY, GRID_BOR_A)
        local vMid1  = MakeVLine(GV_GRID_X + cellW,     blockY, GRID_MID_A)
        local vMid2  = MakeVLine(GV_GRID_X + cellW * 2, blockY, GRID_MID_A)

        local cells = {}
        for col = 1, 3 do
            local cellX = GV_GRID_X + (col - 1) * cellW + CELL_INSET
            local cw    = cellW - CELL_INSET * 2
            local bot   = MakeCellFS(cellX, blockY - 1, cw)
            local hit   = CreateFrame("Frame", nil, leftCol)
            hit:SetAllPoints(bot)
            hit:EnableMouse(true)
            hit:SetScript("OnEnter", function(self)
                if self._lariasTooltipText then AU.SetTooltip(self, self._lariasTooltipText, "ANCHOR_TOP") end
            end)
            hit:SetScript("OnLeave", AU.HideTooltip)
            cells[col] = { bot = bot, hit = hit }
        end

        gvGrids[bi] = {
            header = hdr, topLine = topLine, botLine = botLine,
            vLeft  = vLeft, vRight = vRight, vMid1 = vMid1, vMid2 = vMid2,
            cells  = cells, gridTopY = blockY,
        }

        -- (right-click to hide removed)
        do
            local hz = CreateFrame("Frame", nil, leftCol)
            hz:SetPoint("TOPLEFT", leftCol, "TOPLEFT", 0, blockY)
            hz:SetSize(GV_GRID_X - 2, GV_GRID_H)
            gvGrids[bi]._hoverZone = hz
        end
    end
    TrackingUI.left.gvGrids    = gvGrids
    TrackingUI.left._gvSentinel = gvGrids[3] and gvGrids[3].botLine
    trackingFrame._lariasGvGrids = gvGrids

    -- ReflowGVGrid: repositions all GV elements to fill available vertical space.
    local function ReflowGVGrid(targetH)
        local grds = TrackingUI.left.gvGrids
        if not grds then return end
        local GAP = 8; local BORDER = 1; local CINSET = 4
        if targetH and targetH > 0 then
            TrackingUI.left._lastGvH = targetH
        else
            targetH = TrackingUI.left._lastGvH
            if not (targetH and targetH > 0) then return end
        end
        -- Keep the Great Vault grid at its own designed width.  The Currency
        -- column can change the tracking panel's available width, but that
        -- should never resize GV cells.
        local cellW = GV_CELL_W
        local gridW = GV_GRID_W

        -- Count visible (non-hidden) blocks so row heights fill available space.
        local nVisible = 0
        for bi = 1, 3 do
            if not Addon:IsGVBlockHidden(bi) then nVisible = nVisible + 1 end
        end
        local GAP_TOTAL = max(0, nVisible - 1) * GAP
        -- Use the natural GV row height so Currency can never shrink the grid.
        local gridH   = GV_GRID_H
        local rowH    = GV_ROW_H
        -- Vertically centre the blocks; equal whitespace above and below.
        local naturalH = nVisible * gridH + GAP_TOTAL
        local vOffset  = max(0, floor((max(0, targetH) - naturalH) / 2))

        local visRow = 0
        TrackingUI.left._gvSentinel = nil
        for bi = 1, 3 do
            local grid = grds[bi]
            if not grid then break end
            local function h(obj) if obj and obj.Hide then obj:Hide() end end
            if Addon:IsGVBlockHidden(bi) then
                -- Hide every element of this block.
                h(grid.header); h(grid.topLine); h(grid.botLine)
                h(grid.vLeft);  h(grid.vRight);  h(grid.vMid1); h(grid.vMid2)
                if grid.cells then
                    for col = 1, 3 do
                        local c = grid.cells[col]
                        if c then h(c.bot); h(c.hit) end
                    end
                end
                h(grid._xBtn)
                h(grid._hoverZone)
            else
                local blockY   = -(vOffset + visRow * (gridH + GAP))
                local gridBotY = blockY - BORDER - rowH
                visRow = visRow + 1

                local function setHL(t, y)
                    if not t then return end
                    t:ClearAllPoints()
                    t:SetPoint("TOPLEFT", leftCol, "TOPLEFT", GV_GRID_X, y)
                    t:SetWidth(gridW); t._lariasBaseY = y
                    t:Show()
                end
                setHL(grid.topLine, blockY); setHL(grid.botLine, gridBotY)

                if grid.header then
                    grid.header:ClearAllPoints()
                    grid.header:SetPoint("TOPLEFT", leftCol, "TOPLEFT", 0, blockY)
                    grid.header:SetSize(GV_LABEL_W, gridH)
                    grid.header:Show()
                end

                if grid._xBtn then
                    grid._xBtn:ClearAllPoints()
                    grid._xBtn:SetPoint("TOPLEFT", leftCol, "TOPLEFT", GV_GRID_X - 16, blockY)
                    -- hidden until hovered; shown via _hoverZone
                end
                if grid._hoverZone then
                    grid._hoverZone:ClearAllPoints()
                    grid._hoverZone:SetPoint("TOPLEFT", leftCol, "TOPLEFT", 0, blockY)
                    grid._hoverZone:SetSize(GV_GRID_X - 2, gridH)
                    grid._hoverZone:Show()
                end

                TrackingUI.left._gvSentinel = grid.botLine

                local function setVL(t, x, y)
                    if not t then return end
                    t:ClearAllPoints(); t:SetPoint("TOPLEFT", leftCol, "TOPLEFT", x, y)
                    t:SetSize(1, gridH); t:Show()
                end
                setVL(grid.vLeft,  GV_GRID_X,             blockY)
                setVL(grid.vRight, GV_GRID_X + gridW,     blockY)
                setVL(grid.vMid1,  GV_GRID_X + cellW,     blockY)
                setVL(grid.vMid2,  GV_GRID_X + cellW * 2, blockY)

                for col = 1, 3 do
                    local cellX = GV_GRID_X + (col - 1) * cellW + CINSET
                    local cw    = cellW - CINSET * 2
                    local cell  = grid.cells and grid.cells[col]
                    if cell and cell.bot then
                        cell.bot:ClearAllPoints()
                        cell.bot:SetPoint("TOPLEFT", leftCol, "TOPLEFT", cellX, blockY - BORDER)
                        cell.bot:SetSize(cw, rowH)
                        cell.bot:Show()
                    end
                    if cell and cell.hit then cell.hit:Show() end
                end
                grid.gridTopY = blockY
            end
        end
    end
    Addon._reflowGVGrid = ReflowGVGrid

    --  Right column: currency rows 
    local ROW_ICON_SZ  = 14
    local ROW_ICON_GAP = 3

    local function MakeLinePair(parent, y, template)
        local row = CreateFrame("Frame", nil, parent)
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
        row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, y)
        row:SetHeight(16); row._lariasBaseY = y

        local icon = CreateFrame("Button", nil, row)
        icon:SetSize(ROW_ICON_SZ, ROW_ICON_SZ)
        icon:SetPoint("LEFT", row, "LEFT", 0, 0); icon:Hide(); icon:EnableMouse(true)
        local iconTex = icon:CreateTexture(nil, "ARTWORK")
        iconTex:SetAllPoints(icon); icon._tex = iconTex
        icon:SetScript("OnEnter", function(self)
            if self._lariasIconItemID then
                GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                GameTooltip:SetItemByID(self._lariasIconItemID)
                GameTooltip:Show()
            elseif self._lariasIconCurrencyID then
                GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                GameTooltip:SetCurrencyByID(self._lariasIconCurrencyID)
                GameTooltip:Show()
            end
        end)
        icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
        icon:SetScript("OnMouseUp", function(self, button)
            if button ~= "RightButton" then return end
            local id = self._lariasIconCurrencyID
            local qk = self._lariasIconQuestKey
            local itemID = self._lariasIconItemID
            if id then
                Addon:ShowContextMenu(self, {
                    { text = (L.CONTEXT_HIDE_THIS_CURRENCY_FMT or "Hide %s"):format(GetCurrencyName(id) or tostring(id)), onClick = function()
                        Addon:SetCurrencyHidden(id, true)
                    end },
                })
            elseif itemID then
                Addon:ShowContextMenu(self, {
                    { text = (L.CONTEXT_HIDE_THIS_ITEM_FMT or "Hide %s"):format(GetItemName(itemID) or tostring(itemID)), onClick = function()
                        Addon:SetItemHidden(itemID, true)
                    end },
                })
            elseif qk then
                Addon:ShowContextMenu(self, {
                    { text = L.CONTEXT_HIDE_THIS_ROW or "Hide this row", onClick = function()
                        Addon:SetQuestHidden(qk, true)
                    end },
                })
            end
        end)

        -- Right-side hit area: shows "Accurately tracks" tooltip over the quantity numbers.
        local valueHit = CreateFrame("Frame", nil, row)
        valueHit:SetPoint("TOPRIGHT",    row, "TOPRIGHT",    0,  0)
        valueHit:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0,  0)
        valueHit:SetWidth(80)
        valueHit:EnableMouse(true)
        valueHit:SetScript("OnEnter", function(self)
            local tip = row._lariasAmountTooltipText
            if type(tip) == "table" then
                AU.SetTooltipLines(self, tip, "ANCHOR_TOP")
            elseif tip and tip ~= "" then
                AU.SetTooltip(self, tip, "ANCHOR_TOP")
            end
        end)
        valueHit:SetScript("OnLeave", AU.HideTooltip)
        valueHit:SetScript("OnMouseUp", function(_, button)
            if button ~= "RightButton" then return end
            local id  = row._lariasRightClickCurrencyID
            local qk  = row._lariasRightClickQuestKey
            local itemID = row._lariasRightClickItemID
            if id then
                Addon:ShowContextMenu(row, {
                    { text = (L.CONTEXT_HIDE_THIS_CURRENCY_FMT or "Hide %s"):format(GetCurrencyName(id) or tostring(id)), onClick = function()
                        Addon:SetCurrencyHidden(id, true)
                    end },
                })
            elseif itemID then
                Addon:ShowContextMenu(row, {
                    { text = (L.CONTEXT_HIDE_THIS_ITEM_FMT or "Hide %s"):format(GetItemName(itemID) or tostring(itemID)), onClick = function()
                        Addon:SetItemHidden(itemID, true)
                    end },
                })
            elseif qk then
                Addon:ShowContextMenu(row, {
                    { text = L.CONTEXT_HIDE_THIS_ROW or "Hide this row", onClick = function()
                        Addon:SetQuestHidden(qk, true)
                    end },
                })
            end
        end)
        row._lariasValueHit = valueHit

        -- Full row: shows the convert tooltip when hovering over the label side.
        -- (valueHit captures mouse on the right, so OnEnter here fires on the label area only.)
        row:EnableMouse(true)
        row:SetScript("OnEnter", function(self)
            local tip = self._lariasTooltipText
            if type(tip) == "table" then
                AU.SetTooltipLines(self, tip, "ANCHOR_TOP")
            elseif tip and tip ~= "" then
                AU.SetTooltip(self, tip, "ANCHOR_TOP")
            end
        end)
        row:SetScript("OnLeave", function(self)
            AU.HideTooltip()
        end)
        row:SetScript("OnMouseUp", function(self, button)
            if button ~= "RightButton" then return end
            local id = self._lariasRightClickCurrencyID
            local qk = self._lariasRightClickQuestKey
            local itemID = self._lariasRightClickItemID
            if id then
                Addon:ShowContextMenu(self, {
                    { text = (L.CONTEXT_HIDE_THIS_CURRENCY_FMT or "Hide %s"):format(GetCurrencyName(id) or tostring(id)), onClick = function()
                        Addon:SetCurrencyHidden(id, true)
                    end },
                })
            elseif itemID then
                Addon:ShowContextMenu(self, {
                    { text = (L.CONTEXT_HIDE_THIS_ITEM_FMT or "Hide %s"):format(GetItemName(itemID) or tostring(itemID)), onClick = function()
                        Addon:SetItemHidden(itemID, true)
                    end },
                })
            elseif qk then
                Addon:ShowContextMenu(self, {
                    { text = L.CONTEXT_HIDE_THIS_ROW or "Hide this row", onClick = function()
                        Addon:SetQuestHidden(qk, true)
                    end },
                })
            end
        end)

        local label = row:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
        label:SetPoint("LEFT", row, "LEFT", ROW_ICON_SZ + ROW_ICON_GAP, 0)
        label:SetJustifyH("LEFT")
        if label.SetWordWrap then label:SetWordWrap(false) end
        label:SetTextColor(THEME.text.r, THEME.text.g, THEME.text.b, THEME.text.a)
        label:SetText("")

        local value = row:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
        value:SetPoint("RIGHT", row, "RIGHT", 0, 0); value:SetJustifyH("RIGHT")
        if value.SetWordWrap then value:SetWordWrap(false) end
        value:SetTextColor(THEME.text.r, THEME.text.g, THEME.text.b, THEME.text.a)
        value:SetText("")

        label:SetPoint("RIGHT", value, "LEFT", -6, 0)

        return { frame = row, icon = icon, label = label, value = value }
    end

    EnsureRightRowCount = function(count)
        count = max(tonumber(count) or 0, Addon.RIGHT_LINE_COUNT or 10)
        for i = RIGHT_LINE_COUNT + 1, count do
            RIGHT_ROW_KEYS[i] = "line" .. i
        end
        for i = 1, count do
            local key = RIGHT_ROW_KEYS[i] or ("line" .. i)
            RIGHT_ROW_KEYS[i] = key
            if not TrackingUI.right[key] then
                TrackingUI.right[key] = MakeLinePair(rightCol, -18 * (i - 1), "GameFontHighlight")
            end
        end
        RIGHT_LINE_COUNT = max(RIGHT_LINE_COUNT, count)
    end
    EnsureRightRowCount(RIGHT_LINE_COUNT)

    for i = 1, RIGHT_LINE_COUNT do
        local row = TrackingUI.right[RIGHT_ROW_KEYS[i]]
        if row and row.frame then row.frame:Show() end
    end

    trackingFrame:SetShown((db.showGreatVault or db.showCurrency) and IsMainFrameOnListTab())
    self._trackingFrame = trackingFrame

    if trackingFrame.SetScript then
        trackingFrame:SetScript("OnShow", function()
            local database = Addon:EnsurePrefs()
            Addon:ConfigureTrackingEvents(parentFrame, database.showGreatVault and true or false, database.showCurrency and true or false)
            Addon:RequestTrackingUpdate()
        end)
        trackingFrame:SetScript("OnHide", function()
            Addon:SuspendTrackingUI()
        end)
    end

    self:ConfigureTrackingEvents(parentFrame, db.showGreatVault and true or false, db.showCurrency and true or false)
    if self.CreateStatusBanner then
        self:CreateStatusBanner(parentFrame)
        if self.ApplyScaleSliderVisibility then self:ApplyScaleSliderVisibility() end
        if self.UpdateStatusBanner then self:UpdateStatusBanner() end
    end
end

--  Options / visibility 
function Addon:ApplyTrackingPanelOptions()
    local trackingFrame = self._trackingFrame
    if not trackingFrame then return end

    local db    = self:EnsureDB()
    local prefs = self:EnsurePrefs()
    local showGreatVault = prefs.showGreatVault and true or false
    local showCurrency   = prefs.showCurrency   and true or false
    -- Suppress the currency column when tracking data exists but every currency
    -- has been individually hidden (GetCurrencyPanelRows returns nothing to show).
    if showCurrency and self.TRACKING and #self:GetCurrencyPanelRows() == 0 then
        showCurrency = false
    end
    -- Suppress the GV column when all 3 blocks have been individually hidden.
    if showGreatVault and Addon:IsGVBlockHidden(1) and Addon:IsGVBlockHidden(2) and Addon:IsGVBlockHidden(3) then
        showGreatVault = false
    end

    local wantPanel
    wantPanel = (showGreatVault or showCurrency) and IsMainFrameOnListTab()

    trackingFrame:SetShown(wantPanel)
    if not wantPanel then
        self:SuspendTrackingUI()
        if self.ApplyScrollLayout then self:ApplyScrollLayout() end
        return
    end

    self:ConfigureTrackingEvents(_G["LariasWeeklyChecklistFrame"], showGreatVault, showCurrency)

    local leftCol    = trackingFrame._lariasLeftCol
    local rightCol   = trackingFrame._lariasRightCol
    local leftTitle  = trackingFrame._lariasLeftTitle
    local rightTitle = trackingFrame._lariasRightTitle
    local padL   = tonumber(trackingFrame._lariasPadL)   or 10
    local padR2  = tonumber(trackingFrame._lariasPadR)   or 10
    local colGap = tonumber(trackingFrame._lariasColGap) or 12

    SetShownIfChanged(leftCol,    showGreatVault)
    SetShownIfChanged(rightCol,   showCurrency)
    SetShownIfChanged(leftTitle,  showGreatVault)
    SetShownIfChanged(rightTitle, showCurrency)

    SetShownIfChanged(trackingFrame._lariasColSep, showGreatVault and showCurrency)

    if leftCol  and leftCol.ClearAllPoints  then leftCol:ClearAllPoints()  end
    if rightCol and rightCol.ClearAllPoints then rightCol:ClearAllPoints() end

    if showGreatVault and showCurrency then
        trackingFrame._lariasShowBoth = true
        if leftCol  then leftCol:SetPoint("TOPLEFT", trackingFrame, "TOPLEFT", padL, -32) end
        if rightCol and leftCol then rightCol:SetPoint("TOPLEFT", leftCol, "TOPRIGHT", colGap, 0) end
    else
        local tfW = tonumber(trackingFrame:GetWidth())
        if not tfW or tfW < 10 then tfW = max(10, (UI.frameW or 520) - 2 * (UI.sectionInsetX or 14)) end
        local fullW = max(10, floor(tfW - padL - padR2))
        trackingFrame._lariasShowBoth = false
        if showGreatVault then
            if leftCol then leftCol:SetWidth(fullW); leftCol:SetPoint("TOP", trackingFrame, "TOP", 0, -32) end
        else
            if rightCol then rightCol:SetWidth(fullW); rightCol:SetPoint("TOPLEFT", trackingFrame, "TOPLEFT", padL, -32) end
        end
    end

    if showGreatVault and leftTitle and leftCol then
        leftTitle:ClearAllPoints()
        leftTitle:SetPoint("TOP", leftCol, "TOP", 0, 24)
    end
    if showCurrency and rightTitle and rightCol then
        rightTitle:ClearAllPoints()
        rightTitle:SetPoint("TOP", rightCol, "TOP", 0, 24)
    end

    if self.ApplyScrollLayout then self:ApplyScrollLayout() end
end

--  Snapshot 
local function RenderSnapshotIntoPanel(snap)
    -- Apply a stored snapshot into the tracking panel.
    ApplyGreatVaultGrid(snap.leftGrid or nil)

    if snap.rightRows then
        local idx = 1

        -- Separate crest rows from the rest so we can re-order by current config.
        local storedCrestQty = {}
        local nonCrestRows   = {}
        for _, row in ipairs(snap.rightRows) do
            if row.type == "crest" and row.id then
                storedCrestQty[row.id] = tonumber(row.qty) or 0
            else
                nonCrestRows[#nonCrestRows + 1] = row
            end
        end

        -- Render crests in current config order (with 0 for missing IDs).
        local tracking = Addon.TRACKING
        if tracking and Addon.GetGVData then
            local ids, crestCount = Addon:GetCrestIDsAndCount()
            for i = 1, crestCount do
                local id = ids[i]
                if id and not Addon:IsCurrencyHidden(id) then
                    local qty = storedCrestQty[id] or 0
                    local lbl, val = Addon:RenderCurrencySnapshotRow({ type = "crest", id = id, qty = qty })
                    if IsNonEmptyText(lbl) or IsNonEmptyText(val) then
                        SetRightRowPair(idx, lbl, val, Addon:GetCurrencyIcon(id), id)
                        idx = idx + 1
                    end
                end
            end
        end

        -- Remaining rows (catalyst, sparks, misc currencies, quests).
        for _, row in ipairs(nonCrestRows) do
            local lbl, val
            if row.type then
                lbl, val = Addon:RenderCurrencySnapshotRow(row)
            else
                lbl = row.label or ""; val = row.value or ""
            end
            local iconID = nil
            local currencyID = nil
            local itemID = nil
            local questKey = nil
            if row.type == "sparks" or row.type == "misc" then
                currencyID = row.id
                iconID = Addon:GetCurrencyIcon(currencyID)
            elseif row.type == "catalyst" then
                currencyID = tracking and tracking.catalystCurrencyID
                iconID = Addon:GetCurrencyIcon(currencyID)
            elseif row.type == "quest" then
                questKey = row.key
                itemID = tracking and tracking.questItemIDs and tonumber(tracking.questItemIDs[questKey]) or nil
                if itemID and itemID > 0 then
                    local _, _, _, _, _, _, _, _, _, itemTexture = GetItemInfo(itemID)
                    iconID = itemTexture
                end
            elseif row.type == "weapupg" then
                itemID = 268552
                local _, _, _, _, _, _, _, _, _, itemTexture = GetItemInfo(itemID)
                iconID = itemTexture
            end
            if (not currencyID or not Addon:IsCurrencyHidden(currencyID))
                    and (not questKey or not Addon:IsQuestHidden(questKey))
                    and (not itemID or not Addon:IsItemHidden(itemID))
                    and (IsNonEmptyText(lbl) or IsNonEmptyText(val)) then
                SetRightRowPair(idx, lbl, val, iconID, currencyID, nil, nil, itemID, questKey)
                idx = idx + 1
            end
        end

        for i = idx, RIGHT_LINE_COUNT do SetRightRowPair(i, "", "") end
    end
end

--  Main entry points 
function Addon:UpdateTracking()
    local db    = self:EnsureDB()
    local prefs = self:EnsurePrefs()

    local wantPanel = ComputeWantTrackingPanel(prefs)
    EnsureTrackingPanelCreatedIfNeeded(wantPanel)

    if self.ApplyTrackingPanelOptions then self:ApplyTrackingPanelOptions() end

    if not (wantPanel and self._trackingFrame and self._trackingFrame:IsShown()) then
        if self.ApplyScrollLayout then self:ApplyScrollLayout() end
        return
    end

    -- When viewing an alt, render their stored snapshot instead of live data.
    local viewKey = self._viewingChar
    if viewKey then
        local altCdb  = self.db and self.db.global and self.db.global.chars and self.db.global.chars[viewKey]
        local altSnap = altCdb and altCdb.trackingSnapshot
        if altSnap then
            RenderSnapshotIntoPanel(altSnap)
        else
            ApplyGreatVaultGrid(nil)
            for i = 1, RIGHT_LINE_COUNT do SetRightRowPair(i, "", "") end
        end
        ResizeTrackingPanelToContent(self)
        return  -- Do not overwrite own snapshot when viewing an alt.
    end

    -- Live render: GreatVault via module API, currency via module API.
    local gridBlocks, _ = self:GetGVData()
    ApplyGreatVaultGrid(gridBlocks)
    ApplyRightColumnAsPairs()
    ResizeTrackingPanelToContent(self)
    self:SaveTrackingSnapshot(db)
end

function Addon:ResizeTrackingCols()
    local tf = self._trackingFrame
    if not tf then return end

    local frameW  = tonumber(tf:GetWidth()) or UI.frameW
    local padL    = tonumber(tf._lariasPadL)   or 10
    local padR    = tonumber(tf._lariasPadR)   or 10
    local colGap  = tonumber(tf._lariasColGap) or 12
    local leftCol  = tf._lariasLeftCol
    local rightCol = tf._lariasRightCol
    local leftShown  = leftCol  and leftCol.IsShown  and leftCol:IsShown()  or false
    local rightShown = rightCol and rightCol.IsShown and rightCol:IsShown() or false
    local bothShown  = leftShown and rightShown

    local newColW
    if bothShown then
        newColW = max(10, floor((frameW - padL - padR - colGap) / 2))
    else
        newColW = max(10, floor(frameW - padL - padR))
    end

    if leftShown  and leftCol.SetWidth  then leftCol:SetWidth(newColW)  end
    if rightShown and rightCol.SetWidth then rightCol:SetWidth(newColW) end
    if bothShown and leftCol and rightCol then
        rightCol:ClearAllPoints()
        rightCol:SetPoint("TOPLEFT", leftCol, "TOPRIGHT", colGap, 0)
    end

    for _, k in ipairs(LEFT_LINE_KEYS) do
        local fs = TrackingUI.left[k]
        if fs and fs.SetWidth then fs:SetWidth(newColW) end
    end

    local leftTitle  = tf._lariasLeftTitle
    local rightTitle = tf._lariasRightTitle
    if leftTitle  and leftTitle.SetWidth  then leftTitle:SetWidth(newColW) end
    if rightTitle and rightTitle.SetWidth then
        rightTitle:SetWidth(newColW)
        if rightCol then
            rightTitle:ClearAllPoints()
            rightTitle:SetPoint("TOP", rightCol, "TOP", 0, 24)
        end
    end

    if leftShown and Addon._reflowGVGrid then Addon._reflowGVGrid(nil) end
    tf._lariasColW = newColW
end
