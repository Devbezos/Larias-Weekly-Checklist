-- LariasWeeklyChecklist_GreatVault.lua
-- Great Vault data module.  Fetches and computes GV progress from WoW APIs.
-- Exposes Addon:GetGVData() → (gridBlocks, lines[9]) for the Overlay to render.
local addonName = ...
local Addon = _G[addonName]
if not Addon then return end

if Addon.InitConstants then Addon:InitConstants(addonName) end

local L = Addon.L or {}

local tonumber, type = tonumber, type
local floor, max = math.floor, math.max
local tinsert, tconcat = table.insert, table.concat

-- ── Shared mini-utilities (re-declared; Overlay owns the canonical copy) ──────
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

-- ── Great Vault layout constants ──────────────────────────────────────────────
local GV_LABEL_W     = 60
local GV_LABEL_GAP   =  5
local GV_GRID_X      = GV_LABEL_W + GV_LABEL_GAP   -- 65
local GV_ROW_H       = 24
local GV_GRID_H      = 1 + GV_ROW_H + 1            -- 26
local GV_BLOCK_STEP  = GV_GRID_H + 6               -- 32
local GV_BLOCK_Y     = { 0, -GV_BLOCK_STEP, -GV_BLOCK_STEP * 2 }
local GV_CELL_W      = 40
local GV_GRID_W      = GV_CELL_W * 3               -- 120
local GV_THRESHOLDS  = { {2,4,6}, {1,4,8}, {2,4,8} }
local GV_SECTION_KEYS   = { "TRACKING_GV_RAID", "TRACKING_GV_DUNGEONS", "TRACKING_GV_WORLD" }
local GV_SECTION_LABELS = { "Raid", "Dungeons", "World" }

-- Expose layout constants so Overlay can build the grid UI.
Addon.GV_LAYOUT = {
    LABEL_W = GV_LABEL_W, LABEL_GAP = GV_LABEL_GAP,
    GRID_X  = GV_GRID_X,  ROW_H     = GV_ROW_H,
    GRID_H  = GV_GRID_H,  BLOCK_STEP = GV_BLOCK_STEP,
    BLOCK_Y = GV_BLOCK_Y, CELL_W    = GV_CELL_W,
    GRID_W  = GV_GRID_W,
    SECTION_KEYS   = GV_SECTION_KEYS,
    SECTION_LABELS = GV_SECTION_LABELS,
}

-- ── Enum shims ────────────────────────────────────────────────────────────────
local GV_TYPE_MPLUS = (Enum and Enum.WeeklyRewardChestActivityType and Enum.WeeklyRewardChestActivityType.MythicPlus) or 1
local GV_TYPE_WORLD = (Enum and Enum.WeeklyRewardChestActivityType and Enum.WeeklyRewardChestActivityType.World)     or 2
local GV_TYPE_RAID  = (Enum and Enum.WeeklyRewardChestActivityType and Enum.WeeklyRewardChestActivityType.Raid)      or 3

-- ── Item-level helpers ────────────────────────────────────────────────────────
local function GetIlvlFromItemLink(itemLink)
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
    if not itemLink then return end
    if C_Item and C_Item.RequestLoadItemDataByID then
        local itemID = tonumber(itemLink:match("item:(%d+)"))
        if itemID then C_Item.RequestLoadItemDataByID(itemID) end
    end
end

local function GetExampleRewardIlvlForActivity(activityInfo)
    if not activityInfo then return 0 end
    if activityInfo.levelItemLink then
        local ilvl = GetIlvlFromItemLink(activityInfo.levelItemLink)
        if ilvl > 0 then return ilvl end
    end
    if activityInfo.level then return tonumber(activityInfo.level) or 0 end
    return 0
end

local function GetActivityRewardIlvl(activityInfo)
    if not activityInfo then return 0 end
    -- Try the item link attached to the specific slot.
    if activityInfo.itemLink then
        local ilvl = GetIlvlFromItemLink(activityInfo.itemLink)
        if ilvl > 0 then return ilvl end
        EnsureItemDataLoaded(activityInfo.itemLink)
    end
    if activityInfo.levelItemLink then
        local ilvl = GetIlvlFromItemLink(activityInfo.levelItemLink)
        if ilvl > 0 then return ilvl end
        EnsureItemDataLoaded(activityInfo.levelItemLink)
    end
    return 0
end

local function IsActivityComplete(activity)
    if not activity then return false end
    if type(activity.isComplete) == "boolean" then return activity.isComplete end
    local progress  = activity.progress
    local threshold = activity.threshold
    if type(progress) == "table" then
        threshold = threshold or progress.threshold or progress.required or progress.total
        progress  = progress.progress or progress.current or progress.value
    end
    local progressNum  = tonumber(progress)  or 0
    local thresholdNum = tonumber(threshold) or 0
    if thresholdNum > 0 then return progressNum >= thresholdNum end
    local maxProgress = tonumber(activity.maxProgress or activity.requiredProgress or activity.required or activity.total)
    if maxProgress and maxProgress > 0 then return progressNum >= maxProgress end
    return false
end

-- ── GV string builders ────────────────────────────────────────────────────────
local function MakeGVHeader(label)
    return ColorWrap(COLORS.dim, label)
end

local function MakeGVThresholdsString(complete, total, thresholds, parts)
    complete  = tonumber(complete)  or 0
    total     = tonumber(total)     or 0
    parts     = parts or {}
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

-- ── Main GV data computation ──────────────────────────────────────────────────
local function GetGreatVaultBlockLines()
    -- Returns 9 lines (Raid/Dungeons/World header+threshold+ilvl) AND fills
    -- cache.gridBlocks with structured per-slot data.
    local cache = Addon.TRACKING._gvCache
    if not cache then
        cache = {
            out     = { "", "", "", "", "", "", "", "", "" },
            rIlvls  = {},
            mIlvls  = {},
            wIlvls  = {},
            parts   = {},
        }
        Addon.TRACKING._gvCache = cache
    end

    local out = cache.out
    out[1], out[2], out[3], out[4], out[5], out[6], out[7], out[8], out[9] = "", "", "", "", "", "", "", "", ""

    local activities = C_WeeklyRewards and C_WeeklyRewards.GetActivities and C_WeeklyRewards.GetActivities()
    if type(activities) ~= "table" then
        out[1] = MakeGVHeader(L.TRACKING_GV_RAID      or "Raid")
        out[2] = ColorWrap(COLORS.red, L.TRACKING_NA  or "")
        out[4] = MakeGVHeader(L.TRACKING_GV_DUNGEONS  or "Dungeons")
        out[5] = ColorWrap(COLORS.red, L.TRACKING_NA  or "")
        out[7] = MakeGVHeader(L.TRACKING_GV_WORLD     or "World")
        out[8] = ColorWrap(COLORS.red, L.TRACKING_NA  or "")
        cache.gridBlocks = nil
        return out
    end

    Wipe(cache.rIlvls)
    Wipe(cache.mIlvls)
    Wipe(cache.wIlvls)

    local raidTotal,   raidComplete,   raidMaxIlvl   = 0, 0, 0
    local mythicTotal, mythicComplete, mythicMaxIlvl = 0, 0, 0
    local worldTotal,  worldComplete,  worldMaxIlvl  = 0, 0, 0
    local raidExampleMax, dungeonExampleMax, worldExampleMax = 0, 0, 0

    for idx = 1, #activities do
        local activity     = activities[idx]
        local activityType = activity and activity.type

        if activityType == GV_TYPE_RAID then
            raidTotal = raidTotal + 1
            local level = 0
            if IsActivityComplete(activity) then
                raidComplete = raidComplete + 1
                level = GetActivityRewardIlvl(activity)
                if level <= 0 then level = GetExampleRewardIlvlForActivity(activity) end
                if level > raidMaxIlvl then raidMaxIlvl = level end
            end
            cache.rIlvls[#cache.rIlvls + 1] = level
            local exLevel = GetExampleRewardIlvlForActivity(activity)
            if exLevel > raidExampleMax then raidExampleMax = exLevel end

        elseif activityType == GV_TYPE_MPLUS then
            mythicTotal = mythicTotal + 1
            local level = 0
            if IsActivityComplete(activity) then
                mythicComplete = mythicComplete + 1
                level = GetActivityRewardIlvl(activity)
                if level <= 0 then level = GetExampleRewardIlvlForActivity(activity) end
                if level > mythicMaxIlvl then mythicMaxIlvl = level end
            end
            cache.mIlvls[#cache.mIlvls + 1] = level
            local exLevel = GetExampleRewardIlvlForActivity(activity)
            if exLevel > dungeonExampleMax then dungeonExampleMax = exLevel end

        elseif activityType == GV_TYPE_WORLD then
            worldTotal = worldTotal + 1
            local level = 0
            if IsActivityComplete(activity) then
                worldComplete = worldComplete + 1
                level = GetActivityRewardIlvl(activity)
                if level <= 0 then level = GetExampleRewardIlvlForActivity(activity) end
                if level > worldMaxIlvl then worldMaxIlvl = level end
            end
            cache.wIlvls[#cache.wIlvls + 1] = level
            local exLevel = GetExampleRewardIlvlForActivity(activity)
            if exLevel > worldExampleMax then worldExampleMax = exLevel end
        end
    end

    local raidMax    = (raidExampleMax    > 0) and raidExampleMax    or raidMaxIlvl
    local dungeonMax = (dungeonExampleMax > 0) and dungeonExampleMax or mythicMaxIlvl
    local worldMax   = (worldExampleMax   > 0) and worldExampleMax   or worldMaxIlvl

    out[1] = MakeGVHeader(L.TRACKING_GV_RAID     or "Raid")
    out[2] = (raidTotal   > 0) and MakeGVThresholdsString(raidComplete,   raidTotal,   {2,4,6}, cache.parts) or ColorWrap(COLORS.red, L.TRACKING_NA or "")
    out[3] = (raidTotal   > 0) and MakeGVIlvlsRow(cache.rIlvls, raidMax,    cache.parts) or ""
    out[4] = MakeGVHeader(L.TRACKING_GV_DUNGEONS or "Dungeons")
    out[5] = (mythicTotal > 0) and MakeGVThresholdsString(mythicComplete, mythicTotal, {1,4,8}, cache.parts) or ColorWrap(COLORS.red, L.TRACKING_NA or "")
    out[6] = (mythicTotal > 0) and MakeGVIlvlsRow(cache.mIlvls, dungeonMax, cache.parts) or ""
    out[7] = MakeGVHeader(L.TRACKING_GV_WORLD    or "World")
    out[8] = (worldTotal  > 0) and MakeGVThresholdsString(worldComplete,  worldTotal,  {2,4,8}, cache.parts) or ColorWrap(COLORS.red, L.TRACKING_NA or "")
    out[9] = (worldTotal  > 0) and MakeGVIlvlsRow(cache.wIlvls, worldMax,  cache.parts) or ""

    -- Structured per-slot data for the grid renderer.
    cache.gridBlocks = cache.gridBlocks or {}
    local gb = cache.gridBlocks
    gb[1] = {
        available = raidTotal > 0, complete = raidComplete, maxIlvl = raidMax,
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
        available = worldTotal > 0, complete = worldComplete, maxIlvl = worldMax,
        slots = { { thresh=2, ilvl=cache.wIlvls[1] or 0 },
                  { thresh=4, ilvl=cache.wIlvls[2] or 0 },
                  { thresh=8, ilvl=cache.wIlvls[3] or 0 } },
    }
    return out
end

-- ── Public API ────────────────────────────────────────────────────────────────

--- Returns (gridBlocks, lines[9]).
--- gridBlocks: structured table used by ApplyGreatVaultGrid in Overlay.
--- lines:      9 formatted strings (legacy text layout).
--- Also refreshes the GV cache so snapshot saves see current data.
function Addon:GetGVData()
    Addon.TRACKING = Addon.TRACKING or {}
    local out = GetGreatVaultBlockLines()
    local c   = Addon.TRACKING._gvCache
    return (c and c.gridBlocks), out
end
