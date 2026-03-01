-- Great Vault section: data queries, grid rendering, and UI construction.
-- Depends on LariasWeeklyChecklist_Overlay.lua being loaded first (provides Addon.TrackingInternal).
local addonName = ...
local Addon = _G[addonName]
if not Addon then return end

local TI            = Addon.TrackingInternal
local ColorWrap     = TI.ColorWrap
local SetTextIfChanged = TI.SetTextIfChanged
local COLORS        = TI.COLORS
local Wipe          = TI.Wipe
local TrackingUI    = TI.TrackingUI
local L             = Addon.L or {}
local THEME         = Addon.THEME
local floor, max    = math.floor, math.max
local tconcat       = table.concat

-- Great Vault 3-column grid layout constants (one grid per section).
-- Single-row layout: section label left, then 3 ilvl cells; no threshold row.
local GV_LABEL_W     = 60   -- px reserved for the section label to the left of each grid
local GV_LABEL_GAP   =  5   -- gap between label right edge and grid left border (px)
local GV_GRID_X      = GV_LABEL_W + GV_LABEL_GAP  -- x offset of grid left border = 65
local GV_ROW_H       = 16   -- height of the single ilvl row (px)
local GV_GRID_H      = 1 + GV_ROW_H + 1  -- top border + row + bot border = 18px
local GV_BLOCK_STEP  = GV_GRID_H + 4                      -- 22px between sections
local GV_BLOCK_Y     = { 0, -GV_BLOCK_STEP, -GV_BLOCK_STEP * 2 } -- {0, -22, -44}
local GV_CELL_W      = 40   -- wider single cell (no threshold row sharing width)
local GV_GRID_W      = GV_CELL_W * 3                                -- total grid width = 120px
local GV_SECTION_KEYS   = { "TRACKING_GV_RAID", "TRACKING_GV_DUNGEONS", "TRACKING_GV_WORLD" }
local GV_SECTION_LABELS = { "Raid", "Dungeons", "World" }

local function GetIlvlFromItemLink(itemLink)
    -- Prefer detailed ilvl, fall back to item info.
    if not itemLink then return 0 end
    if GetDetailedItemLevelInfo then
        local ilvl = GetDetailedItemLevelInfo(itemLink)
        return tonumber(ilvl) or 0
    end
    if GetItemInfo then
        local _, _, _, ilvl = GetItemInfo(itemLink)
        return tonumber(ilvl) or 0
    end
    return 0
end

local function EnsureItemDataLoaded(itemLink)
    -- Triggers async item data load to improve later ilvl resolution.
    if not itemLink then return false end
    if not (C_Item and C_Item.RequestLoadItemDataByID) then return false end
    local itemID = tonumber(tostring(itemLink):match("item:(%d+)"))
    if not itemID then return false end
    C_Item.RequestLoadItemDataByID(itemID)
    return true
end

local function GetExampleRewardIlvlForActivity(activityInfo)
    -- Use example reward links when we can't determine ilvl from the reward table.
    if not (activityInfo and C_WeeklyRewards and C_WeeklyRewards.GetExampleRewardItemHyperlinks) then return 0 end
    local activityID = activityInfo.id or activityInfo.activityID
    if not activityID then return 0 end

    local itemLink, upgradeItemLink = C_WeeklyRewards.GetExampleRewardItemHyperlinks(activityID)
    local ilvl = GetIlvlFromItemLink(itemLink)
    if ilvl <= 0 then
        ilvl = GetIlvlFromItemLink(upgradeItemLink)
    end
    if ilvl <= 0 then
        EnsureItemDataLoaded(itemLink)
        EnsureItemDataLoaded(upgradeItemLink)
    end
    return ilvl
end

local function GetActivityRewardIlvl(activityInfo)
    -- Extract best-known ilvl from a weekly reward activity.
    if not (activityInfo and activityInfo.rewards) then return 0 end

    local canWeeklyLink = (C_WeeklyRewards and C_WeeklyRewards.GetItemHyperlink)

    for _, rewardInfo in ipairs(activityInfo.rewards) do
        if rewardInfo and rewardInfo.type == Enum.CachedRewardType.Item then
            local directIlvl = tonumber(rewardInfo.itemLevel)
            if directIlvl and directIlvl > 0 then return directIlvl end
            local link = rewardInfo.itemLink or rewardInfo.itemHyperlink or rewardInfo.hyperlink
            if (not link) and canWeeklyLink and rewardInfo.itemDBID then
                link = C_WeeklyRewards.GetItemHyperlink(rewardInfo.itemDBID)
            end
            if (not link) and rewardInfo.itemID and GetItemInfo then
                local _, itemLink = GetItemInfo(rewardInfo.itemID)
                link = itemLink
            end

            local ilvl = GetIlvlFromItemLink(link)
            if ilvl and ilvl > 0 then return ilvl end
        end
    end
    return 0
end

local function IsActivityComplete(activity)
    -- Compatibility shim: activities have used multiple field shapes over time.
    if not activity then return false end
    if type(activity.isComplete) == "boolean" then return activity.isComplete end
    local progress = activity.progress
    local threshold = activity.threshold

    if type(progress) == "table" then
        threshold = threshold or progress.threshold or progress.required or progress.total
        progress = progress.progress or progress.current or progress.value
    end

    local progressNum = tonumber(progress) or 0
    local thresholdNum  = tonumber(threshold) or 0
    if thresholdNum > 0 then return progressNum >= thresholdNum end

    local maxProgress = tonumber(activity.maxProgress or activity.requiredProgress or activity.required or activity.total)
    if maxProgress and maxProgress > 0 then return progressNum >= maxProgress end

    return false
end

local function MakeGVHeader(label)
    -- GV headers are dimmed for readability.
    return ColorWrap(COLORS.dim, label)
end

local function MakeGVThresholdsString(complete, total, thresholds, parts)
    -- Render thresholds with per-threshold completion coloring.
    complete = tonumber(complete) or 0
    total = tonumber(total) or 0
    parts = parts or {}
    Wipe(parts)

    if total <= 0 or type(thresholds) ~= "table" or #thresholds <= 0 then
        return ColorWrap(COLORS.red, L.TRACKING_NA or "")
    end

    for i = 1, #thresholds do
        local value = tonumber(thresholds[i])
        if value then
            parts[#parts + 1] = ColorWrap((complete >= i) and COLORS.green or COLORS.red, " " .. tostring(value) .. " ")
        end
    end
    return tconcat(parts, " ")
end

local function MakeGVIlvlsRow(ilvls, maxPossible, parts)
    -- Render ilvls, highlighting the best possible value.
    parts = parts or {}
    Wipe(parts)
    for i = 1, #ilvls do
        local value = tonumber(ilvls[i]) or 0
        if value > 0 then
            local c = (maxPossible > 0 and value == maxPossible) and COLORS.green or COLORS.red
            parts[#parts + 1] = ColorWrap(c, tostring(value))
        else
            parts[#parts + 1] = ColorWrap(COLORS.dim, L.TRACKING_NA or "")
        end
    end
    return tconcat(parts, " ")
end

local GV_TYPE_MPLUS  = (Enum and Enum.WeeklyRewardChestActivityType and Enum.WeeklyRewardChestActivityType.MythicPlus) or 1
local GV_TYPE_WORLD  = (Enum and Enum.WeeklyRewardChestActivityType and Enum.WeeklyRewardChestActivityType.World) or 2
local GV_TYPE_RAID   = (Enum and Enum.WeeklyRewardChestActivityType and Enum.WeeklyRewardChestActivityType.Raid) or 3

local function GetGreatVaultBlockLines()
    -- Returns 9 lines representing GV raid/dungeons/world blocks.
    -- Uses a reusable cache table to minimize allocations during throttled updates.
    local cache = Addon.TRACKING._gvCache
    if not cache then
        cache = {
            out = { "", "", "", "", "", "", "", "", "" },
            rIlvls = {},
            mIlvls = {},
            wIlvls = {},
            parts = {},
        }
        Addon.TRACKING._gvCache = cache
    end

    local out = cache.out
    out[1], out[2], out[3], out[4], out[5], out[6], out[7], out[8], out[9] = "", "", "", "", "", "", "", "", ""

    local activities = C_WeeklyRewards and C_WeeklyRewards.GetActivities and C_WeeklyRewards.GetActivities()
    if type(activities) ~= "table" then
        out[1] = MakeGVHeader(L.TRACKING_GV_RAID or "Raid")
        out[2] = ColorWrap(COLORS.red, L.TRACKING_NA or "")
        out[4] = MakeGVHeader(L.TRACKING_GV_DUNGEONS or "Dungeons")
        out[5] = ColorWrap(COLORS.red, L.TRACKING_NA or "")
        out[7] = MakeGVHeader(L.TRACKING_GV_WORLD or "World")
        out[8] = ColorWrap(COLORS.red, L.TRACKING_NA or "")
        return out
    end

    local TYPE_MPLUS = GV_TYPE_MPLUS
    local TYPE_WORLD = GV_TYPE_WORLD
    local TYPE_RAID  = GV_TYPE_RAID

    Wipe(cache.rIlvls)
    Wipe(cache.mIlvls)
    Wipe(cache.wIlvls)

    local raidTotal, raidComplete, raidMaxIlvl = 0, 0, 0
    local mythicTotal, mythicComplete, mythicMaxIlvl = 0, 0, 0
    local worldTotal, worldComplete, worldMaxIlvl = 0, 0, 0
    local raidExampleMax, dungeonExampleMax, worldExampleMax = 0, 0, 0

    for idx = 1, #activities do
        local activity = activities[idx]
        local activityType = activity and activity.type

        if activityType == TYPE_RAID then
            raidTotal = raidTotal + 1
            local level = 0
            if IsActivityComplete(activity) then
                raidComplete = raidComplete + 1
                level = GetActivityRewardIlvl(activity)
                if level <= 0 then
                    level = GetExampleRewardIlvlForActivity(activity)
                end
                if level > raidMaxIlvl then raidMaxIlvl = level end
            end
            cache.rIlvls[#cache.rIlvls + 1] = level

            local exLevel = GetExampleRewardIlvlForActivity(activity)
            if exLevel > raidExampleMax then raidExampleMax = exLevel end

        elseif activityType == TYPE_MPLUS then
            mythicTotal = mythicTotal + 1
            local level = 0
            if IsActivityComplete(activity) then
                mythicComplete = mythicComplete + 1
                level = GetActivityRewardIlvl(activity)
                if level <= 0 then
                    level = GetExampleRewardIlvlForActivity(activity)
                end
                if level > mythicMaxIlvl then mythicMaxIlvl = level end
            end
            cache.mIlvls[#cache.mIlvls + 1] = level

            local exLevel = GetExampleRewardIlvlForActivity(activity)
            if exLevel > dungeonExampleMax then dungeonExampleMax = exLevel end

        elseif activityType == TYPE_WORLD then
            worldTotal = worldTotal + 1
            local level = 0
            if IsActivityComplete(activity) then
                worldComplete = worldComplete + 1
                level = GetActivityRewardIlvl(activity)
                if level <= 0 then
                    level = GetExampleRewardIlvlForActivity(activity)
                end
                if level > worldMaxIlvl then worldMaxIlvl = level end
            end
            cache.wIlvls[#cache.wIlvls + 1] = level

            local exLevel = GetExampleRewardIlvlForActivity(activity)
            if exLevel > worldExampleMax then worldExampleMax = exLevel end
        end
    end

    local raidMax    = (raidExampleMax > 0)    and raidExampleMax    or raidMaxIlvl
    local dungeonMax = (dungeonExampleMax > 0) and dungeonExampleMax or mythicMaxIlvl
    local worldMax   = (worldExampleMax > 0)   and worldExampleMax   or worldMaxIlvl

    out[1] = MakeGVHeader(L.TRACKING_GV_RAID or "Raid")
    out[2] = (raidTotal > 0) and MakeGVThresholdsString(raidComplete, raidTotal, { 2, 4, 6 }, cache.parts) or ColorWrap(COLORS.red, L.TRACKING_NA or "")
    out[3] = (raidTotal > 0) and MakeGVIlvlsRow(cache.rIlvls, raidMax, cache.parts) or ""

    out[4] = MakeGVHeader(L.TRACKING_GV_DUNGEONS or "Dungeons")
    out[5] = (mythicTotal > 0) and MakeGVThresholdsString(mythicComplete, mythicTotal, { 1, 4, 8 }, cache.parts) or ColorWrap(COLORS.red, L.TRACKING_NA or "")
    out[6] = (mythicTotal > 0) and MakeGVIlvlsRow(cache.mIlvls, dungeonMax, cache.parts) or ""

    out[7] = MakeGVHeader(L.TRACKING_GV_WORLD or "World")
    out[8] = (worldTotal > 0) and MakeGVThresholdsString(worldComplete, worldTotal, { 2, 4, 8 }, cache.parts) or ColorWrap(COLORS.red, L.TRACKING_NA or "")
    out[9] = (worldTotal > 0) and MakeGVIlvlsRow(cache.wIlvls, worldMax, cache.parts) or ""

    -- Populate structured grid data for ApplyGreatVaultGrid.
    cache.gridBlocks = cache.gridBlocks or {}
    local gb = cache.gridBlocks
    gb[1] = {
        available = raidTotal   > 0, complete = raidComplete,   maxIlvl = raidMax,
        slots = { { thresh=2, ilvl=cache.rIlvls[1] or 0 },
                  { thresh=4, ilvl=cache.rIlvls[2] or 0 },
                  { thresh=6, ilvl=cache.rIlvls[3] or 0 } },
    }
    gb[2] = {
        available = mythicTotal > 0, complete = mythicComplete, maxIlvl = dungeonMax,
        slots = { { thresh=1, ilvl=cache.mIlvls[1] or 0 },
                  { thresh=4, ilvl=cache.mIlvls[2] or 0 },
                  { thresh=8, ilvl=cache.mIlvls[3] or 0 } },
    }
    gb[3] = {
        available = worldTotal  > 0, complete = worldComplete,  maxIlvl = worldMax,
        slots = { { thresh=2, ilvl=cache.wIlvls[1] or 0 },
                  { thresh=4, ilvl=cache.wIlvls[2] or 0 },
                  { thresh=8, ilvl=cache.wIlvls[3] or 0 } },
    }

    return out
end

local function GetGreatVaultGridData()
    -- Refresh the GV cache and return the structured per-slot data for grid rendering.
    GetGreatVaultBlockLines()
    local c = Addon.TRACKING and Addon.TRACKING._gvCache
    return c and c.gridBlocks
end

local function ApplyGreatVaultGrid(gridBlocks)
    -- Fill the 3 GV section grids from structured per-slot block data.
    -- Single-row layout: each cell shows the ilvl reward only.
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
                local ilvl    = slot and slot.ilvl   or 0
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

-- ── Great Vault grid UI builder ───────────────────────────────────────────────
-- Called from CreateTrackingPanel (Overlay.lua) via TI.BuildGreatVaultGridUI.
-- Builds the 3 GV section grids inside leftCol and wires up Addon._reflowGVGrid.
TI.BuildGreatVaultGridUI = function(trackingFrame, leftCol)
    local GRID_BOR_A = 0.55  -- outer border opacity
    local GRID_MID_A = 0.30  -- inner row/col divider opacity
    local CELL_INSET = 4     -- horizontal text inset inside each cell (px)

    local function MakeHLine(yOff, alpha, xOff, w)
        local t = leftCol:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(THEME.border.r, THEME.border.g, THEME.border.b, alpha)
        t:SetHeight(1)
        t:SetPoint("TOPLEFT", leftCol, "TOPLEFT", xOff or 0, yOff)
        if w then
            t:SetWidth(w)
        else
            t:SetPoint("TOPRIGHT", leftCol, "TOPRIGHT", 0, yOff)
        end
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
        fs:SetSize(w, GV_ROW_H)
        fs:SetJustifyH("CENTER")
        fs:SetJustifyV("MIDDLE")
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
        hdr:SetSize(GV_LABEL_W, GV_GRID_H)
        hdr:SetJustifyH("LEFT")
        hdr:SetJustifyV("MIDDLE")
        if hdr.SetWordWrap then hdr:SetWordWrap(false) end
        hdr:SetTextColor(THEME.header.r, THEME.header.g, THEME.header.b, THEME.header.a)
        hdr:SetText(L[GV_SECTION_KEYS[bi]] or GV_SECTION_LABELS[bi])

        local vLeft  = MakeVLine(GV_GRID_X,             blockY, GRID_BOR_A)
        local vRight = MakeVLine(GV_GRID_X + GV_GRID_W, blockY, GRID_BOR_A)
        local vMid1  = MakeVLine(GV_GRID_X + cellW,     blockY, GRID_MID_A)
        local vMid2  = MakeVLine(GV_GRID_X + cellW * 2, blockY, GRID_MID_A)

        local cells = {}
        for col = 1, 3 do
            local cellX = GV_GRID_X + (col - 1) * cellW + CELL_INSET
            local cw    = cellW - CELL_INSET * 2
            cells[col] = { bot = MakeCellFS(cellX, blockY - 1, cw) }
        end

        gvGrids[bi] = {
            header   = hdr,
            topLine  = topLine, botLine = botLine,
            vLeft    = vLeft,   vRight  = vRight,
            vMid1    = vMid1,   vMid2   = vMid2,
            cells    = cells,
            gridTopY = blockY,
        }
    end
    TrackingUI.left.gvGrids     = gvGrids
    TrackingUI.left._gvSentinel = gvGrids[3] and gvGrids[3].botLine
    trackingFrame._lariasGvGrids = gvGrids

    -- ReflowGVGrid: repositions and resizes all GV grid elements inside leftCol.
    local function ReflowGVGrid(targetH)
        local grds = TrackingUI.left.gvGrids
        if not grds then return end
        local GAP    = 4
        local BORDER = 1
        local CINSET = 4
        if targetH and targetH > 0 then
            TrackingUI.left._lastGvH = targetH
        else
            targetH = TrackingUI.left._lastGvH
            if not (targetH and targetH > 0) then return end
        end
        local availGridW = math.max(60, (leftCol:GetWidth() or 0) - GV_GRID_X)
        local cellW = math.max(30, math.floor(availGridW / 3))
        local gridW = cellW * 3
        local gridH = math.max(14, math.min(18, math.floor((math.max(0, targetH or 0) - GAP * 2) / 3)))
        local rowH  = math.max(10, math.min(16, gridH - BORDER * 2))
        gridH = BORDER + rowH + BORDER

        for bi = 1, 3 do
            local blockY   = -(bi - 1) * (gridH + GAP)
            local gridBotY = blockY - BORDER - rowH
            local grid = grds[bi]
            if not grid then break end

            local function setHL(t, y)
                if not t then return end
                t:ClearAllPoints()
                t:SetPoint("TOPLEFT", leftCol, "TOPLEFT", GV_GRID_X, y)
                t:SetWidth(gridW)
                t._lariasBaseY = y
            end
            setHL(grid.topLine, blockY)
            setHL(grid.botLine, gridBotY)

            local hdr2 = grid.header
            if hdr2 then
                hdr2:ClearAllPoints()
                hdr2:SetPoint("TOPLEFT", leftCol, "TOPLEFT", 0, blockY)
                hdr2:SetSize(GV_LABEL_W, gridH)
            end

            if bi == 3 then
                TrackingUI.left._gvSentinel = grid.botLine
            end

            local function setVL(t, x, y)
                if not t then return end
                t:ClearAllPoints()
                t:SetPoint("TOPLEFT", leftCol, "TOPLEFT", x, y)
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
end

TI.GetGreatVaultBlockLines = GetGreatVaultBlockLines
TI.GetGreatVaultGridData   = GetGreatVaultGridData
TI.ApplyGreatVaultGrid     = ApplyGreatVaultGrid
