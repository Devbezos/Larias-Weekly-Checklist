-- LariasWeeklyChecklist_Currency.lua
-- Currency data module.  Computes crest/catalyst/sparks/coffer-key rows from
-- WoW APIs and exposes them to the Overlay for rendering.
--
-- Public methods
--   Addon:GetCurrencyPanelRows()         {label,value,iconID,currencyID}[]
--   Addon:FillCurrencySnapshot(snap)     writes snap.rightRows
--   Addon:RenderCurrencySnapshotRow(r)   label, value
local addonName = ...
local Addon = _G[addonName]
if not Addon then return end

local L = Addon.L or {}

local tonumber, tostring, type = tonumber, tostring, type
local floor, max, abs = math.floor, math.max, math.abs
local tinsert, tconcat = table.insert, table.concat

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

local function IsNonEmptyText(text)
    if type(text) ~= "string" then return false end
    text = text:gsub("|[cr][%x]*", "")
    return text:match("%S") ~= nil
end

--  Format helpers 
local function FormatXY(cur, cap)
    cur = tonumber(cur) or 0
    cap = tonumber(cap) or 0
    if cap > 0 then return ("%d/%d"):format(cur, cap) end
    return tostring(cur)
end

local function ColorForXY(cur, cap)
    cur = tonumber(cur) or 0
    cap = tonumber(cap) or 0
    if cur <= 0 then return COLORS.red end
    if cap > 0 and cur >= cap then return COLORS.green end
    return COLORS.yellow
end

local function IsAchievementCompleteSafe(achievementID)
    if not achievementID then return false end
    if C_AchievementInfo and C_AchievementInfo.IsAchievementComplete then
        return C_AchievementInfo.IsAchievementComplete(achievementID) and true or false
    end
    if GetAchievementInfo then
        local _, _, _, completed = GetAchievementInfo(achievementID)
        return completed == true
    end
    return false
end

--  Currency API helpers 
local QUALITY_HEX = {
    [0] = "ff9d9d9d", [1] = "ffffffff", [2] = "ff1eff00",
    [3] = "ff0070dd", [4] = "ffa335ee", [5] = "ffff8000",
    [6] = "ffe6cc80", [7] = "ff00ccff",
}

local function FormatCurrencyProgressParts(currencyID)
    if not currencyID or not C_CurrencyInfo or not C_CurrencyInfo.GetCurrencyInfo then return nil end
    local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
    if not info then return nil end
    local held         = tonumber(info.quantity)          or 0
    local weeklyEarned = tonumber(info.weeklyQuantity)    or 0
    local weeklyMax    = tonumber(info.maxWeeklyQuantity) or 0
    -- Midnight crests don't populate maxWeeklyQuantity; for those, maxQuantity
    -- is the weekly earn cap. Use it as fallback.
    if weeklyMax <= 0 then
        weeklyMax = tonumber(info.maxQuantity) or 0
    end
    if weeklyMax > 0 then
        local available = math.max(0, weeklyMax - weeklyEarned)
        return held, held + available  -- current / (current + still earnable)
    end
    return held, 0
end

local function GetCurrencyIconID(currencyID)
    local id = tonumber(currencyID)
    if not (id and id > 0) then return nil end
    if not (C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo) then return nil end
    local info = C_CurrencyInfo.GetCurrencyInfo(id)
    return info and info.iconFileID or nil
end

local function GetCurrencyName(currencyID)
    local id = tonumber(currencyID)
    if not (id and id > 0) then return nil end
    if not (C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo) then return nil end
    local info = C_CurrencyInfo.GetCurrencyInfo(id)
    return info and info.name or nil
end

local function GetCurrencyQualityColor(currencyID)
    local id = tonumber(currencyID)
    if not (id and id > 0) then return COLORS.dim end
    if not (C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo) then return COLORS.dim end
    local info = C_CurrencyInfo.GetCurrencyInfo(id)
    if not info then return COLORS.dim end
    local q = tonumber(info.quality)
    return (q and QUALITY_HEX[q]) or COLORS.dim
end

-- Builds a table (keyed by currency ID) of the shortest distinguishing label
-- for each crest tier.  Words shared by every name are stripped; what remains
-- is the tier-unique portion (e.g. "Adventurer", "Veteran", …).  Falls back
-- to the first word when nothing distinguishes (e.g. only one crest defined).
local function BuildCrestLabels(ids, crestCount)
    -- Collect per-name word lists and a global word frequency count.
    local wordLists = {}
    local wordCount = {}
    for i = 1, crestCount do
        local id = ids[i]
        local name = (id and GetCurrencyName(id)) or ""
        wordLists[i] = {}
        local seen = {}
        for w in name:gmatch("%S+") do
            tinsert(wordLists[i], w)
            if not seen[w] then
                seen[w] = true
                wordCount[w] = (wordCount[w] or 0) + 1
            end
        end
    end
    -- Words present in every name are common; keep only the unique ones.
    local labels = {}
    for i = 1, crestCount do
        local id = ids[i]
        if id then
            local unique = {}
            for _, w in ipairs(wordLists[i]) do
                if (wordCount[w] or 0) < crestCount then
                    tinsert(unique, w)
                end
            end
            if #unique > 0 then
                labels[id] = tconcat(unique, " ")
            else
                -- All words are shared (or only one crest) – fall back to first word.
                labels[id] = wordLists[i][1] or ("Crest " .. tostring(id))
            end
        end
    end
    return labels
end

--  Crest achievement helpers 
local function GetCrestAchievementID(i)
    local ach = Addon.TRACKING and Addon.TRACKING.crestAchievementIDs
    if type(ach) ~= "table" then return nil end
    local idx = tonumber(i)
    return idx and ach[idx] or nil
end

--  Quest helpers 
local function GetTrackedQuestID(key)
    local q = Addon.TRACKING and Addon.TRACKING.questIDs and Addon.TRACKING.questIDs[key]
    q = tonumber(q) or 0
    if q <= 0 then return nil end
    return q
end

local function GetQuestDoneRaw(questKey)
    local qid = GetTrackedQuestID(questKey)
    if not qid then return nil end
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        return C_QuestLog.IsQuestFlaggedCompleted(qid) and true or false
    end
    if IsQuestFlaggedCompleted then
        return IsQuestFlaggedCompleted(qid) and true or false
    end
    return nil
end

local function GetQuestDoneParts(labelText, questKey, opts)
    local qid = GetTrackedQuestID(questKey)
    if not qid then return "", "" end
    local label = ColorWrap(COLORS.dim, labelText)
    local done
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        done = C_QuestLog.IsQuestFlaggedCompleted(qid)
    elseif IsQuestFlaggedCompleted then
        done = IsQuestFlaggedCompleted(qid)
    end
    if done == nil then
        return label, ColorWrap(COLORS.red, L.TRACKING_NA or "")
    end
    if opts and opts.as01 then
        return label, done and ColorWrap(COLORS.green, "1/1") or ColorWrap(COLORS.red, "0/1")
    end
    return label, done and ColorWrap(COLORS.green, L.TRACKING_DONE or "Done") or ColorWrap(COLORS.red, L.TRACKING_NA or "")
end

local function GetDelversBountyParts()
    if not GetTrackedQuestID("delversBounty") then return "", "" end
    return GetQuestDoneParts(L.TRACKING_QUEST_DELVERS_BOUNTY or "", "delversBounty", { as01 = true })
end

local function GetWeeklyPreyParts()
    if not GetTrackedQuestID("weeklyPrey") then return "", "" end
    return GetQuestDoneParts(L.TRACKING_QUEST_WEEKLY_PREY or "", "weeklyPrey", { as01 = true })
end

--  Sparks 
local function GetSparksParts()
    local id = Addon.TRACKING and Addon.TRACKING.sparkCurrencyID
    if not (id and tonumber(id) and tonumber(id) > 0) then return "", "" end
    local name  = GetCurrencyName(id) or L.TRACKING_SPARKS_LABEL or ""
    local label = ColorWrap(GetCurrencyQualityColor(id), name)
    local cur, cap = FormatCurrencyProgressParts(id)
    cur = tonumber(cur) or 0
    cap = tonumber(cap) or 0
    if cap > 0 then
        return label, ColorWrap(ColorForXY(cur, cap), FormatXY(cur, cap))
    end
    return label, ColorWrap(COLORS.green, tostring(cur))
end

--  Crest computation 
local function GetCrestTradeBatches(profile)
    local p = profile or Addon.TRACKING or {}
    local batch = p.crestTradeBatch
    local lower, higher
    if type(batch) == "table" then
        lower  = tonumber(batch[1] or batch.lower)
        higher = tonumber(batch[2] or batch.higher)
    end
    if not lower  or lower  <= 0 then lower  = 45 end
    if not higher or higher <= 0 then
        higher = floor(lower / 3)
        if higher <= 0 then higher = 1 end
    end
    return lower, higher
end

local function EnsureCrestIDsDetected(tracking)
    if tracking._crestIDsDetected then return end
    tracking._crestIDsDetected = true
end

local function GetCrestIDsAndCount(tracking)
    local ids = tracking.crestCurrencyIDs or {}
    local crestCount
    if type(ids) == "table" and ids[1] ~= nil then
        crestCount = #ids
    else
        ids = {}; crestCount = 0
    end
    if crestCount <= 0 then crestCount = 4 end
    return ids, crestCount
end

local function EnsureCrestCache(tracking, crestCount)
    local cache = tracking._crestCache
    if not cache or cache.count ~= crestCount then
        cache = {
            count     = crestCount,
            out       = {}, label     = {}, value   = {},
            name      = {}, cur       = {}, cap     = {},
            unlocked  = {}, effective = {}, gained  = {},
        }
        tracking._crestCache = cache
    end
    return cache
end

local function ResetCrestOutput(cache, crestCount)
    local out, labelOut, valueOut = cache.out, cache.label, cache.value
    for i = 1, crestCount do out[i] = ""; labelOut[i] = ""; valueOut[i] = "" end
    return out, labelOut, valueOut
end

local function PopulateCrestCurCap(cache, ids, crestCount)
    for i = 1, crestCount do
        local id = ids[i]
        if id then
            local cur, cap = FormatCurrencyProgressParts(id)
            cache.cur[i] = tonumber(cur) or 0
            cache.cap[i] = tonumber(cap) or 0
        else
            cache.cur[i] = 0; cache.cap[i] = 0
        end
    end
end

local function PopulateCrestUnlocked(cache, crestCount)
    for i = 1, crestCount do
        local achID = GetCrestAchievementID(i)
        cache.unlocked[i] = achID and IsAchievementCompleteSafe(achID) or false
    end
end

local function ComputeCrestTradeup(cache, crestCount, batchLower, batchHigher)
    local highestTradeTarget
    for i = crestCount, 2, -1 do
        if cache.unlocked[i - 1] then highestTradeTarget = i; break end
    end
    local effective, gained = cache.effective, cache.gained
    effective[1] = cache.cur[1] or 0; gained[1] = 0
    for i = 2, crestCount do
        local prevAmt = tonumber(effective[i - 1]) or 0
        local tradeFromPrev = 0
        if cache.unlocked[i - 1] then
            tradeFromPrev = floor(prevAmt / batchLower) * batchHigher
        end
        gained[i]    = tradeFromPrev
        effective[i] = (cache.cur[i] or 0) + tradeFromPrev
    end
    return highestTradeTarget, gained
end

local function GetCrestLines()
    local tracking = Addon.TRACKING
    if not tracking then return { "", "", "", "" } end
    EnsureCrestIDsDetected(tracking)
    local ids, crestCount = GetCrestIDsAndCount(tracking)
    local cache = EnsureCrestCache(tracking, crestCount)
    local out, labelOut, valueOut = ResetCrestOutput(cache, crestCount)
    local batchLower, batchHigher = GetCrestTradeBatches(tracking)
    PopulateCrestCurCap(cache, ids, crestCount)
    PopulateCrestUnlocked(cache, crestCount)
    local highestTradeTarget, gained = ComputeCrestTradeup(cache, crestCount, batchLower, batchHigher)
    local crestLabels = BuildCrestLabels(ids, crestCount)
    local tooltipTexts = {}
    for i = 1, crestCount do
        local id = ids[i]
        if id then
            local name = crestLabels[id] or GetCurrencyName(id) or tostring(id)
            if name then
                local cur, cap = cache.cur[i], cache.cap[i]
                local xy, color
                if cap > 0 then
                    xy = FormatXY(cur, cap)
                    color = (cur >= cap) and COLORS.green or (cache.unlocked[i] and COLORS.yellow or COLORS.red)
                else
                    xy = tostring(cur); color = COLORS.green
                end
                local tradeUp = ""
                if highestTradeTarget and i == highestTradeTarget then
                    local n = tonumber(gained[i]) or 0
                    if n > 0 then
                        tradeUp = ColorWrap(COLORS.dim, " (")
                            .. ColorWrap("ff4da6ff", "+" .. tostring(n))
                            .. ColorWrap(COLORS.dim, L.TRACKING_TRADE_UP_SUFFIX or "")
                        tooltipTexts[i] = L.TRACKING_CONVERT_TOOLTIP or ""
                    end
                end
                local lbl = ColorWrap(GetCurrencyQualityColor(id), tostring(name)) .. tradeUp
                local val = ColorWrap(color, xy)
                labelOut[i] = lbl; valueOut[i] = val; out[i] = lbl .. " " .. val
            end
        else
            local lbl = ColorWrap(COLORS.dim, L.TRACKING_CREST_LABEL or "")
            local val = ColorWrap(COLORS.red, L.TRACKING_NO_ID or "")
            labelOut[i] = lbl; valueOut[i] = val; out[i] = lbl .. " " .. val
        end
    end
    return out, labelOut, valueOut, crestCount, tooltipTexts
end

--  Catalyst 
local function GetCatalystQtyRaw()
    local cur
    local tracking = Addon.TRACKING
    local id = tracking and tracking.catalystCurrencyID
    local hasID = (id and tonumber(id) and tonumber(id) > 0) and true or false
    if hasID then
        local qty, _ = FormatCurrencyProgressParts(tonumber(id))
        cur = tonumber(qty)
    end
    if cur == nil and C_Catalyst then
        if C_Catalyst.GetCharges then
            local charges = C_Catalyst.GetCharges()
            if type(charges) == "table" then
                cur = tonumber(charges.currentCharges or charges.numCharges or charges.charges)
            end
        end
        if cur == nil and C_Catalyst.GetNumCharges then
            cur = tonumber(C_Catalyst.GetNumCharges())
        end
    end
    if cur == nil and not hasID then return nil end
    return cur
end

local function GetCatalystParts()
    local cur, cap
    local id = Addon.TRACKING and Addon.TRACKING.catalystCurrencyID
    local hasID = (id and tonumber(id) and tonumber(id) > 0) and true or false
    local catName  = (hasID and GetCurrencyName(tonumber(id))) or L.TRACKING_CATALYST_LABEL or ""
    local catColor = (hasID and GetCurrencyQualityColor(tonumber(id))) or COLORS.dim
    if hasID then
        local qty, c = FormatCurrencyProgressParts(id)
        cur = tonumber(qty); cap = tonumber(c)
    end
    if cur == nil and C_Catalyst then
        if C_Catalyst.GetCharges then
            local charges = C_Catalyst.GetCharges()
            if type(charges) == "table" then
                cur = charges.currentCharges or charges.numCharges or charges.charges
                cap = charges.maxCharges or charges.maximumCharges
            end
        end
        if cur == nil and C_Catalyst.GetNumCharges then cur = C_Catalyst.GetNumCharges() end
        if cap == nil and C_Catalyst.GetMaxCharges  then cap = C_Catalyst.GetMaxCharges()  end
    end
    cur = tonumber(cur); cap = tonumber(cap)
    if not cur then
        if not hasID then return "", "" end
        return ColorWrap(catColor, catName), ColorWrap(COLORS.red, L.TRACKING_NA or "")
    end
    if cap and cap > 0 then
        return ColorWrap(catColor, catName), ColorWrap(ColorForXY(cur, cap), FormatXY(cur, cap))
    end
    return ColorWrap(catColor, catName), ColorWrap((cur <= 0) and COLORS.red or COLORS.green, ("%d"):format(cur))
end

--  Coffer Keys 
local function GetCofferKeysParts()
    local id = Addon.TRACKING and Addon.TRACKING.cofferKeysCurrencyID
    if not (id and tonumber(id) and tonumber(id) > 0) then return "", "" end
    id = tonumber(id)
    local name  = GetCurrencyName(id) or "Restored Coffer Keys"
    local label = ColorWrap(GetCurrencyQualityColor(id), name)
    local cur, cap = FormatCurrencyProgressParts(id)
    cur = tonumber(cur) or 0; cap = tonumber(cap) or 0
    if cap > 0 then
        return label, ColorWrap(ColorForXY(cur, cap), FormatXY(cur, cap))
    end
    return label, ColorWrap((cur <= 0) and COLORS.red or COLORS.green, tostring(cur))
end

--  Public API 

-- Reusable buffers for GetCurrencyPanelRows – avoids allocating new tables on
-- every tracking update (which fires on bag updates, currency changes, etc.).
local _panelRowBuf  = {}  -- result array, returned and reused each call
local _panelRowPool = {}  -- pool of row sub-tables, one slot per max possible row

local function FillRow(n, lbl, val, iconID, currencyID, tooltipText)
    if not _panelRowPool[n] then _panelRowPool[n] = {} end
    local r       = _panelRowPool[n]
    r.label       = lbl
    r.value       = val
    r.iconID      = iconID
    r.currencyID  = currencyID
    r.tooltipText = tooltipText or nil
    _panelRowBuf[n] = r
end

--- Returns an ordered list of currency rows ready to display in the right column.
--- Each entry: { label, value, iconID, currencyID }.  Empty rows are omitted.
--- The returned table is reused across calls – do not hold a reference past the
--- next tracking update.
function Addon:GetCurrencyPanelRows()
    local RIGHT_LINE_COUNT = 10
    local n        = 0
    local tracking = self.TRACKING

    -- Crests
    local _, labelLines, valueLines, crestCount, crestTooltips = GetCrestLines()
    crestCount = tonumber(crestCount) or 4
    local crestIDs = tracking and GetCrestIDsAndCount(tracking) or {}
    if type(crestIDs) ~= "table" then crestIDs = {} end
    for i = 1, crestCount do
        if n >= RIGHT_LINE_COUNT then break end
        local lbl = (labelLines and labelLines[i]) or ""
        local val = (valueLines and valueLines[i]) or ""
        if IsNonEmptyText(lbl) or IsNonEmptyText(val) then
            local id = crestIDs[i]
            n = n + 1
            FillRow(n, lbl, val, GetCurrencyIconID(id), id, crestTooltips and crestTooltips[i])
        end
    end

    -- Catalyst
    if n < RIGHT_LINE_COUNT then
        local cLbl, cVal = GetCatalystParts()
        if IsNonEmptyText(cLbl) or IsNonEmptyText(cVal) then
            local catID = tracking and tracking.catalystCurrencyID
            n = n + 1
            FillRow(n, cLbl, cVal, GetCurrencyIconID(catID), catID)
        end
    end

    -- Sparks
    if n < RIGHT_LINE_COUNT then
        local sLbl, sVal = GetSparksParts()
        if IsNonEmptyText(sLbl) or IsNonEmptyText(sVal) then
            local sID = tracking and tracking.sparkCurrencyID
            n = n + 1
            FillRow(n, sLbl, sVal, GetCurrencyIconID(sID), sID)
        end
    end

    -- Coffer Keys
    if n < RIGHT_LINE_COUNT then
        local kLbl, kVal = GetCofferKeysParts()
        if IsNonEmptyText(kLbl) or IsNonEmptyText(kVal) then
            local kID = tracking and tracking.cofferKeysCurrencyID
            n = n + 1
            FillRow(n, kLbl, kVal, GetCurrencyIconID(kID), kID)
        end
    end

    -- Delver's Bounty (quest)
    if n < RIGHT_LINE_COUNT then
        local bLbl, bVal = GetDelversBountyParts()
        if IsNonEmptyText(bLbl) or IsNonEmptyText(bVal) then
            n = n + 1
            FillRow(n, bLbl, bVal, nil, nil)
        end
    end

    -- Weekly Prey (quest)
    if n < RIGHT_LINE_COUNT then
        local pLbl, pVal = GetWeeklyPreyParts()
        if IsNonEmptyText(pLbl) or IsNonEmptyText(pVal) then
            n = n + 1
            FillRow(n, pLbl, pVal, nil, nil)
        end
    end

    -- Trim stale entries from a previous call that had more rows.
    for i = n + 1, #_panelRowBuf do _panelRowBuf[i] = nil end

    return _panelRowBuf
end

--- Populates snap.rightRows with structured (type-tagged) snapshot data.
--- Called from the Overlay's ComputeSnapshotData.
function Addon:FillCurrencySnapshot(snap)
    if snap.rightRows then Wipe(snap.rightRows) else snap.rightRows = {} end
    local tracking = self.TRACKING
    if tracking then
        EnsureCrestIDsDetected(tracking)
        local ids, crestCount = GetCrestIDsAndCount(tracking)
        local cache = EnsureCrestCache(tracking, crestCount)
        PopulateCrestCurCap(cache, ids, crestCount)
        for i = 1, crestCount do
            local id = ids[i]
            if id then
                snap.rightRows[#snap.rightRows + 1] = {
                    type = "crest", id = id, qty = cache.cur[i] or 0,
                }
            end
        end
    end
    local catQty = GetCatalystQtyRaw()
    snap.rightRows[#snap.rightRows + 1] = { type = "catalyst", qty = catQty or 0 }
    local sparkID = tracking and tonumber(tracking.sparkCurrencyID)
    if sparkID and sparkID > 0 then
        local sQty, _ = FormatCurrencyProgressParts(sparkID)
        snap.rightRows[#snap.rightRows + 1] = { type = "sparks", id = sparkID, qty = tonumber(sQty) or 0 }
    end
    local cofferID = tracking and tonumber(tracking.cofferKeysCurrencyID)
    if cofferID and cofferID > 0 then
        local kQty, _ = FormatCurrencyProgressParts(cofferID)
        snap.rightRows[#snap.rightRows + 1] = { type = "cofferkeys", id = cofferID, qty = tonumber(kQty) or 0 }
    end
    local bDone = GetQuestDoneRaw("delversBounty")
    if bDone ~= nil then
        snap.rightRows[#snap.rightRows + 1] = { type = "quest", key = "delversBounty", done = bDone }
    end
    local pDone = GetQuestDoneRaw("weeklyPrey")
    if pDone ~= nil then
        snap.rightRows[#snap.rightRows + 1] = { type = "quest", key = "weeklyPrey", done = pDone }
    end
end

--- Converts a single typed snapshot row into a (label, value) display string pair.
--- Used by the Overlay when rendering another character's stored snapshot.
function Addon:RenderCurrencySnapshotRow(row)
    local t = row.type
    if t == "crest" then
        local id  = row.id
        local qty = tonumber(row.qty) or 0
        local tracking = self.TRACKING
        local crestIDs, crestCount = GetCrestIDsAndCount(tracking or {})
        local crestLabels = BuildCrestLabels(crestIDs, crestCount)
        local name  = crestLabels[id] or GetCurrencyName(id) or tostring(id or "?")
        local lbl   = ColorWrap(GetCurrencyQualityColor(id), tostring(name))
        local _, cap = FormatCurrencyProgressParts(id)
        cap = tonumber(cap) or 0
        if cap > 0 then
            return lbl, ColorWrap(ColorForXY(qty, cap), FormatXY(qty, cap))
        end
        return lbl, ColorWrap(COLORS.green, tostring(qty))
    elseif t == "catalyst" then
        local qty = tonumber(row.qty) or 0
        local tracking = self.TRACKING
        local catID = tracking and tonumber(tracking.catalystCurrencyID)
        local catLabel = (catID and catID > 0 and GetCurrencyName(catID)) or L.TRACKING_CATALYST_LABEL or ""
        local lbl = ColorWrap(GetCurrencyQualityColor(catID), catLabel)
        local cap = nil
        if C_Catalyst then
            if C_Catalyst.GetMaxCharges then cap = tonumber(C_Catalyst.GetMaxCharges()) end
            if not cap and C_Catalyst.GetCharges then
                local ch = C_Catalyst.GetCharges()
                if type(ch) == "table" then cap = tonumber(ch.maxCharges or ch.maximumCharges) end
            end
        end
        if (not cap or cap == 0) and catID and catID > 0 then
            local _, c = FormatCurrencyProgressParts(catID); cap = tonumber(c)
        end
        if cap and cap > 0 then
            return lbl, ColorWrap(ColorForXY(qty, cap), FormatXY(qty, cap))
        end
        return lbl, ColorWrap((qty <= 0) and COLORS.red or COLORS.green, ("%d"):format(qty))
    elseif t == "sparks" then
        local qty = tonumber(row.qty) or 0
        local id  = tonumber(row.id) or (self.TRACKING and tonumber(self.TRACKING.sparkCurrencyID))
        local name  = (id and id > 0 and GetCurrencyName(id)) or L.TRACKING_SPARKS_LABEL or ""
        local lbl   = ColorWrap(GetCurrencyQualityColor(id), name)
        local cap = 0
        if id and id > 0 then local _, c = FormatCurrencyProgressParts(id); cap = tonumber(c) or 0 end
        if cap > 0 then return lbl, ColorWrap(ColorForXY(qty, cap), FormatXY(qty, cap)) end
        return lbl, ColorWrap((qty <= 0) and COLORS.red or COLORS.green, tostring(qty))
    elseif t == "cofferkeys" then
        local qty = tonumber(row.qty) or 0
        local id  = tonumber(row.id) or (self.TRACKING and tonumber(self.TRACKING.cofferKeysCurrencyID))
        local name  = (id and id > 0 and GetCurrencyName(id)) or "Restored Coffer Keys"
        local lbl   = ColorWrap(GetCurrencyQualityColor(id), name)
        local cap = 0
        if id and id > 0 then local _, c = FormatCurrencyProgressParts(id); cap = tonumber(c) or 0 end
        if cap > 0 then return lbl, ColorWrap(ColorForXY(qty, cap), FormatXY(qty, cap)) end
        return lbl, ColorWrap((qty <= 0) and COLORS.red or COLORS.green, tostring(qty))
    elseif t == "quest" then
        local key  = row.key
        local done = row.done
        local labelText = ""
        if key == "delversBounty" then labelText = L.TRACKING_QUEST_DELVERS_BOUNTY or ""
        elseif key == "weeklyPrey" then labelText = L.TRACKING_QUEST_WEEKLY_PREY or "" end
        if not IsNonEmptyText(labelText) then return "", "" end
        local lbl = ColorWrap(COLORS.dim, labelText)
        if done == nil then return lbl, ColorWrap(COLORS.red, L.TRACKING_NA or "")
        elseif done   then return lbl, ColorWrap(COLORS.green, "1/1")
        else               return lbl, ColorWrap(COLORS.red,   "0/1") end
    end
    return "", ""
end

--- Expose icon/name helpers for use by the Overlay snapshot renderer.
function Addon:GetCurrencyIcon(id) return GetCurrencyIconID(id) end
