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

-- Forward declaration: ComputeSnapshotData is defined after all helpers.
local ComputeSnapshotData

--  Module-level state 
Addon.TRACKING = Addon.TRACKING or {}

local trackingEventFrame
-- TrackingUI owns every sub-frame/FontString created by CreateTrackingPanel.
local TrackingUI = { left = {}, right = {} }

-- Key lists for ResizeTrackingCols to iterate without allocating.
local LEFT_LINE_KEYS  = { "line1","line2","line3","line4","line5","line6","line7","line8","line9" }
local RIGHT_LINE_COUNT = 10
local RIGHT_ROW_KEYS  = {}
for _i = 1, RIGHT_LINE_COUNT do RIGHT_ROW_KEYS[_i] = "line" .. _i end

-- GV layout constants (mirror of Addon.GV_LAYOUT set in GreatVault.lua).
local GV_LABEL_W    = 60
local GV_LABEL_GAP  =  5
local GV_GRID_X     = GV_LABEL_W + GV_LABEL_GAP   -- 65
local GV_ROW_H      = 24
local GV_GRID_H     = 1 + GV_ROW_H + 1            -- 26
local GV_BLOCK_STEP = GV_GRID_H + 6               -- 32
local GV_BLOCK_Y    = { 0, -GV_BLOCK_STEP, -GV_BLOCK_STEP * 2 }
local GV_CELL_W     = 40
local GV_GRID_W     = GV_CELL_W * 3               -- 120

--  Shared mini-utilities 
local COLORS = {
    red    = "ffff4040",
    yellow = "ffffd34d",
    green  = "ff40ff40",
    white  = "ffffffff",
    dim    = "ff808080",
}

local function ColorWrap(hex, txt)
    return "|c" .. hex .. tostring(txt or "") .. "|r"
end

local function Wipe(t)
    if not t then return end
    if wipe then wipe(t); return end
    for k in pairs(t) do t[k] = nil end
end

local function SetTextIfChanged(fs, text)
    if not fs then return end
    text = text or ""
    if fs._lariasText ~= text then
        fs._lariasText = text
        fs:SetText(text)
    end
end

local function IsNonEmptyText(text)
    if type(text) ~= "string" then return false end
    text = text:gsub("|[cr][%x]*", "")
    return text:match("%S") ~= nil
end

local function SetShownIfChanged(region, shown)
    if not (region and region.IsShown and region.SetShown) then return end
    local want = shown and true or false
    if region:IsShown() ~= want then region:SetShown(want) end
end

local function IsFrameShown(frameObj)
    return frameObj and frameObj.IsShown and frameObj:IsShown()
end

local function FormatXY(cur, cap)
    cur = tonumber(cur) or 0; cap = tonumber(cap) or 0
    if cap > 0 then return ("%d/%d"):format(cur, cap) end
    return tostring(cur)
end

local function ColorForXY(cur, cap)
    cur = tonumber(cur) or 0; cap = tonumber(cap) or 0
    if cur <= 0 then return COLORS.red end
    if cap > 0 and cur >= cap then return COLORS.green end
    return COLORS.yellow
end

local function GetCurrencyIconID(currencyID)
    local id = tonumber(currencyID)
    if not (id and id > 0) then return nil end
    if not (C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo) then return nil end
    local info = C_CurrencyInfo.GetCurrencyInfo(id)
    return info and info.iconFileID or nil
end

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

local function SafeRegisterEvent(frame, eventName)
    if not (frame and eventName) then return false end
    local ok = pcall(frame.RegisterEvent, frame, eventName)
    return ok
end

--  Snapshot / event API 
function Addon:HasTrackingSnapshot()
    if not (self.db and self.db.global) then return false end
    local ownKey = self:GetCurrentProfileKey()
    local cdb    = self.db.global.chars and self.db.global.chars[ownKey]
    local snap   = cdb and cdb.trackingSnapshot
    return snap ~= nil and (snap.leftLines ~= nil or snap.rightRows ~= nil)
end

function Addon:ConfigureTrackingEvents(parentFrame, showGreatVault, showCurrency)
    trackingEventFrame = trackingEventFrame or CreateFrame("Frame")
    trackingEventFrame:UnregisterAllEvents()
    local shouldListen = (showGreatVault or showCurrency) and true or false
    if not shouldListen then return end

    trackingEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    if showGreatVault then
        trackingEventFrame:RegisterEvent("WEEKLY_REWARDS_UPDATE")
        trackingEventFrame:RegisterEvent("ITEM_DATA_LOAD_RESULT")
    end
    if showCurrency then
        trackingEventFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
        trackingEventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
        trackingEventFrame:RegisterEvent("QUEST_TURNED_IN")
        SafeRegisterEvent(trackingEventFrame, "CATALYST_CHARGES_UPDATED")
        SafeRegisterEvent(trackingEventFrame, "CATALYST_UPDATE")
        SafeRegisterEvent(trackingEventFrame, "ITEM_INTERACTION_ITEM_SELECTION_UPDATED")
        if not showGreatVault then
            -- Avoid double-registration: Great Vault block already registered this above.
            trackingEventFrame:RegisterEvent("ITEM_DATA_LOAD_RESULT")
        end
    end

    trackingEventFrame:SetScript("OnEvent", function()
        if IsFrameShown(parentFrame) and IsFrameShown(Addon._trackingFrame) then
            Addon:RequestTrackingUpdate()
        elseif Addon:HasTrackingSnapshot() then
            Addon:RequestBackgroundSnapshotUpdate()
        end
    end)
end

function Addon:RequestBackgroundSnapshotUpdate()
    if self._bgSnapshotPending then return end
    self._bgSnapshotPending = true
    if not self._bgSnapshotRunner then
        local addon = self
        self._bgSnapshotRunner = function()
            addon._bgSnapshotPending = nil
            if addon.UpdateSnapshotBackground then addon:UpdateSnapshotBackground() end
        end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0.2, self._bgSnapshotRunner)
    else self._bgSnapshotRunner() end
end

function Addon:UpdateSnapshotBackground()
    if not self:HasTrackingSnapshot() then return end
    local db   = self:EnsureDB()
    local snap = db.trackingSnapshot
    if type(snap) ~= "table" then return end
    ComputeSnapshotData(snap)
end

function Addon:RequestTrackingUpdate()
    if not self.RegisterBucketMessage then
        local aceBucket = LibStub and LibStub("AceBucket-3.0", true)
        if aceBucket then aceBucket:Embed(self) end
    end
    if self.RegisterBucketMessage and self.SendMessage then
        if not self._trackingUpdateBucketRegistered then
            self._trackingUpdateBucketRegistered = true
            self:RegisterBucketMessage("LWMC_TRACKING_UPDATE", 0.2, function()
                if Addon.UpdateTracking then Addon:UpdateTracking() end
            end)
        end
        self:SendMessage("LWMC_TRACKING_UPDATE")
        return
    end
    if self._trackingUpdatePending then return end
    self._trackingUpdatePending = true
    if not self._trackingUpdateRunner then
        local addon = self
        self._trackingUpdateRunner = function()
            addon._trackingUpdatePending = nil
            if addon.UpdateTracking then addon:UpdateTracking() end
        end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0.2, self._trackingUpdateRunner)
    else self._trackingUpdateRunner() end
end

--  Rendering helpers 
local function ApplyGreatVaultGrid(gridBlocks)
    local grids = TrackingUI.left.gvGrids
    if not grids then return end
    for bi = 1, 3 do
        local grid  = grids[bi]
        local block = gridBlocks and gridBlocks[bi]
        if not (grid and grid.cells) then break end
        if block and block.available then
            local done    = block.complete or 0
            local maxIlvl = block.maxIlvl  or 0
            for col = 1, 3 do
                local slot    = block.slots and block.slots[col]
                local ilvl    = slot and slot.ilvl or 0
                local unlocked = done >= col
                local txt = (unlocked and ilvl > 0)
                    and ColorWrap((maxIlvl > 0 and ilvl == maxIlvl) and COLORS.green or COLORS.white, tostring(ilvl))
                    or  ColorWrap(COLORS.dim, "-")
                SetTextIfChanged(grid.cells[col].bot, txt)
            end
        else
            for col = 1, 3 do
                SetTextIfChanged(grid.cells[col].bot, ColorWrap(COLORS.dim, "-"))
            end
        end
    end
end

local function SetRightRowPair(i, rowLabel, rowValue, iconFileID, currencyID)
    local row = TrackingUI.right[RIGHT_ROW_KEYS[i]]
    if not (row and row.label and row.value) then return end
    rowLabel = rowLabel or ""; rowValue = rowValue or ""
    SetTextIfChanged(row.label, rowLabel)
    SetTextIfChanged(row.value, rowValue)
    local showRow = IsNonEmptyText(rowLabel) or IsNonEmptyText(rowValue)
    SetShownIfChanged(row.frame or row.label, showRow)
    if row.icon then
        if showRow and iconFileID and iconFileID ~= 0 then
            if row.icon._tex then row.icon._tex:SetTexture(iconFileID) end
            row.icon._lariasIconCurrencyID = currencyID or nil
            SetShownIfChanged(row.icon, true)
        else
            row.icon._lariasIconCurrencyID = nil
            SetShownIfChanged(row.icon, false)
        end
    end
end

local function ApplyRightColumnAsPairs()
    -- Delegates to Currency module for the row data.
    local panelRows = Addon:GetCurrencyPanelRows()
    for i, row in ipairs(panelRows) do
        if i > RIGHT_LINE_COUNT then break end
        SetRightRowPair(i, row.label, row.value, row.iconID, row.currencyID)
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

    if bottomRight > 0 and Addon._reflowGVGrid then
        Addon._reflowGVGrid(bottomRight)
    end

    local bottomLeft = max(0, BottomFor(TrackingUI.left._gvSentinel))
    local contentH   = max(bottomLeft, bottomRight)
    local topOffset  = 32
    local bottomPad  = 10
    local minH       = 90
    local targetH    = max(minH, topOffset + contentH + bottomPad)
    local curH       = tonumber(trackingFrame:GetHeight()) or 0
    if abs(curH - targetH) <= 1 then return end

    trackingFrame:SetHeight(targetH)
    if trackingFrame._lariasLeftCol  and trackingFrame._lariasLeftCol.SetHeight  then trackingFrame._lariasLeftCol:SetHeight(max(1, targetH - 40))  end
    if trackingFrame._lariasRightCol and trackingFrame._lariasRightCol.SetHeight then trackingFrame._lariasRightCol:SetHeight(max(1, targetH - 40)) end
    if addon.ApplyScrollLayout then addon:ApplyScrollLayout() end
end

local function ComputeWantTrackingPanel(db, prefs)
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
    self:ApplyTheme(trackingFrame)

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

    --  Decorative column boxes 
    local BOX_PAD = 6
    local function MakeColBox(col)
        local box = CreateFrame("Frame", nil, trackingFrame)
        Addon:ApplyTheme(box)
        if box.SetBackdropColor      then box:SetBackdropColor(THEME.bg.r, THEME.bg.g, THEME.bg.b, 0.55) end
        if box.SetBackdropBorderColor then box:SetBackdropBorderColor(THEME.border.r, THEME.border.g, THEME.border.b, 0.65) end
        local tfLevel = trackingFrame.GetFrameLevel and trackingFrame:GetFrameLevel() or 1
        if box.SetFrameLevel then box:SetFrameLevel(tfLevel) end
        box:EnableMouse(false)
        box:SetPoint("TOPLEFT",     col, "TOPLEFT",     -BOX_PAD,  24 + BOX_PAD)
        box:SetPoint("BOTTOMRIGHT", col, "BOTTOMRIGHT",  BOX_PAD, -BOX_PAD)
        return box
    end

    local function MakeTitleButton(col, tipText, onClick)
        local btn = CreateFrame("Button", nil, trackingFrame)
        btn:SetPoint("TOPLEFT",     col, "TOPLEFT",  -BOX_PAD,  24 + BOX_PAD)
        btn:SetPoint("BOTTOMRIGHT", col, "TOPRIGHT",  BOX_PAD,  BOX_PAD)
        btn:EnableMouse(true)
        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.07)
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(tipText, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        btn:RegisterForClicks("AnyUp")
        if onClick then btn:SetScript("OnClick", onClick) end
        return btn
    end

    local leftBox  = MakeColBox(leftCol)
    local rightBox = MakeColBox(rightCol)
    trackingFrame._lariasLeftBox  = leftBox
    trackingFrame._lariasRightBox = rightBox

    MakeTitleButton(leftCol,
        L.TOOLTIP_OPEN_GREAT_VAULT or "Click to open the Great Vault",
        function()
            if not WeeklyRewardsFrame then C_AddOns.LoadAddOn("Blizzard_WeeklyRewards") end
            if WeeklyRewardsFrame then
                if WeeklyRewardsFrame:IsShown() then WeeklyRewardsFrame:Hide()
                else WeeklyRewardsFrame:Show() end
            end
        end)

    MakeTitleButton(rightCol,
        L.TOOLTIP_OPEN_CURRENCIES or "Click to open the Currency panel",
        function() ToggleCharacter("TokenFrame") end)

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
    local GRID_BOR_A = 0.55
    local GRID_MID_A = 0.30
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
        local fs = leftCol:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
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

        local hdr = leftCol:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
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
            cells[col]  = { bot = MakeCellFS(cellX, blockY - 1, cw) }
        end

        gvGrids[bi] = {
            header = hdr, topLine = topLine, botLine = botLine,
            vLeft  = vLeft, vRight = vRight, vMid1 = vMid1, vMid2 = vMid2,
            cells  = cells, gridTopY = blockY,
        }
    end
    TrackingUI.left.gvGrids    = gvGrids
    TrackingUI.left._gvSentinel = gvGrids[3] and gvGrids[3].botLine
    trackingFrame._lariasGvGrids = gvGrids

    -- ReflowGVGrid: repositions all GV elements to fill available vertical space.
    local function ReflowGVGrid(targetH)
        local grds = TrackingUI.left.gvGrids
        if not grds then return end
        local GAP = 6; local BORDER = 1; local CINSET = 4
        if targetH and targetH > 0 then
            TrackingUI.left._lastGvH = targetH
        else
            targetH = TrackingUI.left._lastGvH
            if not (targetH and targetH > 0) then return end
        end
        local availGridW = max(60, (leftCol:GetWidth() or 0) - GV_GRID_X)
        local cellW = max(30, floor(availGridW / 3))
        local gridW = cellW * 3
        local gridH = max(14, floor((max(0, targetH) - GAP * 2) / 3))
        local rowH  = max(10, gridH - BORDER * 2)
        gridH       = BORDER + rowH + BORDER

        for bi = 1, 3 do
            local blockY   = -(bi - 1) * (gridH + GAP)
            local gridBotY = blockY - BORDER - rowH
            local grid = grds[bi]
            if not grid then break end

            local function setHL(t, y)
                if not t then return end
                t:ClearAllPoints()
                t:SetPoint("TOPLEFT", leftCol, "TOPLEFT", GV_GRID_X, y)
                t:SetWidth(gridW); t._lariasBaseY = y
            end
            setHL(grid.topLine, blockY); setHL(grid.botLine, gridBotY)

            if grid.header then
                grid.header:ClearAllPoints()
                grid.header:SetPoint("TOPLEFT", leftCol, "TOPLEFT", 0, blockY)
                grid.header:SetSize(GV_LABEL_W, gridH)
            end

            if bi == 3 then TrackingUI.left._gvSentinel = grid.botLine end

            local function setVL(t, x, y)
                if not t then return end
                t:ClearAllPoints(); t:SetPoint("TOPLEFT", leftCol, "TOPLEFT", x, y)
                t:SetSize(1, gridH)
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
                end
            end
            grid.gridTopY = blockY
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
            if self._lariasIconCurrencyID then
                GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                GameTooltip:SetCurrencyByID(self._lariasIconCurrencyID)
                GameTooltip:Show()
            end
        end)
        icon:SetScript("OnLeave", function() GameTooltip:Hide() end)

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

    for i = 1, RIGHT_LINE_COUNT do
        TrackingUI.right["line" .. i] = MakeLinePair(rightCol, -18 * (i - 1), "GameFontHighlight")
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
            if trackingEventFrame and not Addon:HasTrackingSnapshot() then
                trackingEventFrame:UnregisterAllEvents()
            end
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

    local wantPanel
    wantPanel = (showGreatVault or showCurrency) and IsMainFrameOnListTab()

    trackingFrame:SetShown(wantPanel)
    if not wantPanel then
        if trackingEventFrame then trackingEventFrame:UnregisterAllEvents() end
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

    local showBothBoxes = showGreatVault and showCurrency
    SetShownIfChanged(trackingFrame._lariasLeftBox,  showBothBoxes)
    SetShownIfChanged(trackingFrame._lariasRightBox, showBothBoxes)

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
ComputeSnapshotData = function(snap)
    -- Left column: Great Vault via the GreatVault module API.
    local gridBlocks, gvLines = Addon:GetGVData()

    snap.leftLines = snap.leftLines or {}
    for i = 1, 9 do snap.leftLines[i] = (gvLines and gvLines[i]) or "" end

    if gridBlocks then
        snap.leftGrid = snap.leftGrid or {{},{},{}}
        for bi = 1, 3 do
            local src = gridBlocks[bi]
            local dst = snap.leftGrid[bi]
            if src and dst then
                dst.available = src.available
                dst.complete  = src.complete
                dst.maxIlvl   = src.maxIlvl
                dst.slots     = dst.slots or {{},{},{}}
                for si = 1, 3 do
                    if src.slots and src.slots[si] and dst.slots[si] then
                        dst.slots[si].thresh = src.slots[si].thresh
                        dst.slots[si].ilvl   = src.slots[si].ilvl
                    end
                end
            end
        end
    end

    -- Right column: currency data via the Currency module API.
    Addon:FillCurrencySnapshot(snap)
end

local function SaveTrackingSnapshot(db)
    local snap = db.trackingSnapshot
    if type(snap) ~= "table" then snap = {}; db.trackingSnapshot = snap end
    ComputeSnapshotData(snap)
end

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
            -- GetCrestIDsAndCount is in the Currency module; replicate minimal logic.
            local ids = tracking.crestCurrencyIDs or {}
            local crestCount = (type(ids) == "table" and ids[1]) and #ids or 4
            for i = 1, crestCount do
                if idx > RIGHT_LINE_COUNT then break end
                local id = ids[i]
                if id then
                    local qty = storedCrestQty[id] or 0
                    local lbl, val = Addon:RenderCurrencySnapshotRow({ type = "crest", id = id, qty = qty })
                    if IsNonEmptyText(lbl) or IsNonEmptyText(val) then
                        SetRightRowPair(idx, lbl, val, GetCurrencyIconID(id))
                        idx = idx + 1
                    end
                end
            end
        end

        -- Remaining rows (catalyst, sparks, cofferkeys, quests).
        for _, row in ipairs(nonCrestRows) do
            if idx > RIGHT_LINE_COUNT then break end
            local lbl, val
            if row.type then
                lbl, val = Addon:RenderCurrencySnapshotRow(row)
            else
                lbl = row.label or ""; val = row.value or ""
            end
            if IsNonEmptyText(lbl) or IsNonEmptyText(val) then
                local iconID = nil
                if row.type == "sparks" or row.type == "cofferkeys" then
                    iconID = GetCurrencyIconID(row.id)
                elseif row.type == "catalyst" then
                    iconID = GetCurrencyIconID(tracking and tracking.catalystCurrencyID)
                end
                SetRightRowPair(idx, lbl, val, iconID)
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

    local wantPanel = ComputeWantTrackingPanel(db, prefs)
    EnsureTrackingPanelCreatedIfNeeded(wantPanel)

    if self.ApplyTrackingPanelOptions then self:ApplyTrackingPanelOptions() end

    if not (wantPanel and self._trackingFrame and self._trackingFrame:IsShown()) then
        if self.ApplyScrollLayout then self:ApplyScrollLayout() end
        return
    end

    -- Live render: GreatVault via module API, currency via module API.
    local gridBlocks, _ = self:GetGVData()
    ApplyGreatVaultGrid(gridBlocks)
    ApplyRightColumnAsPairs()
    ResizeTrackingPanelToContent(self)
    SaveTrackingSnapshot(db)
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
