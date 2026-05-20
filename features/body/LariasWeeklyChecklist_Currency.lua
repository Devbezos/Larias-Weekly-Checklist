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

-- Maximum rows in the right column (defined in AddonUtils, shared with Overlay).
local RIGHT_LINE_COUNT = Addon.RIGHT_LINE_COUNT

-- Per-session cache for static currency fields (name, iconFileID, quality).
-- These never change within a session, so we avoid repeated C_CurrencyInfo calls.
local _currencyStaticCache = {}  -- [id] = { name, iconFileID, quality } or false

-- Cache for BuildCrestLabels output; invalidated only when crest IDs change.
local _crestLabelsCache = { key = nil, labels = nil }

-- ── Snapshot row type constants ─────────────────────────────────────────────
-- Single source of truth for all type-tag strings used in snap.rightRows.
-- AltsSummary.lua reads these via Addon.SNAP_TYPES so both sides stay in sync.
Addon.SNAP_TYPES = {
    CREST      = "crest",
    CATALYST   = "catalyst",
    SPARKS     = "sparks",
    COFFERKEYS = "cofferkeys",
    MISC       = "misc",
    QUEST      = "quest",
}
local SNAP_TYPES = Addon.SNAP_TYPES

--  Shared mini-utilities (from Addon.AddonUtils) 
local AU             = Addon.AddonUtils
local COLORS         = AU.COLORS
local ColorWrap      = AU.ColorWrap
local Wipe           = AU.Wipe
local IsNonEmptyText = AU.IsNonEmptyText
local FormatXY       = AU.FormatXY
local ColorForXY     = AU.ColorForXY

local function IsAchievementCompleteSafe(achievementID)
    if not achievementID then return false end
    if GetAchievementInfo then
        local _, _, _, _, _, _, _, _, _, _, _, _, wasEarnedByMe = GetAchievementInfo(achievementID)
        return wasEarnedByMe == true
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
    local held     = tonumber(info.quantity)    or 0
    local wkAmount = tonumber(info.maxWeeklyQuantity) or 0
    local walletCap= tonumber(info.maxQuantity) or 0
    -- If the currency has a weekly earn cap, display weekly-earned / weekly-cap so
    -- that spending the currency doesn't reset the display back to 0 (e.g. 0/2
    -- after spending 2 earned → should show 2/2).  Use >= so this also catches
    -- currencies where wallet cap equals weekly cap (e.g. ID 3418, cap=2).
    if info.hasWeeklyLimit and wkAmount > 0 and wkAmount >= walletCap then
        local weeklyEarned = tonumber(info.quantityEarnedThisWeek) or tonumber(info.weeklyQuantity) or 0
        return weeklyEarned, wkAmount
    end
    -- For season-capped currencies (crests, sparks) use the season cap and
    -- total earned to compute how much is still earnable this season.
    local earnedSoFar = tonumber(info.totalEarned) or 0
    local seasonMax   = walletCap
    if seasonMax > 0 then
        local available = math.max(0, seasonMax - earnedSoFar)
        return held, math.max(seasonMax, held + available)
    end
    return held, 0
end

-- Returns a cached table of static currency fields {name, iconFileID, quality}.
-- Call this instead of GetCurrencyInfo when you only need data that never
-- changes within a session.  FormatCurrencyProgressParts must still go direct
-- because quantity/totalEarned are dynamic.
local function GetCurrencyStaticInfo(currencyID)
    local id = tonumber(currencyID)
    if not (id and id > 0) then return nil end
    local cached = _currencyStaticCache[id]
    if cached ~= nil then return cached or nil end
    if not (C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo) then return nil end
    local info = C_CurrencyInfo.GetCurrencyInfo(id)
    if not info then _currencyStaticCache[id] = false; return nil end
    local s = { name = info.name, iconFileID = info.iconFileID, quality = tonumber(info.quality) }
    _currencyStaticCache[id] = s
    return s
end

local function GetCurrencyIconID(currencyID)
    local s = GetCurrencyStaticInfo(currencyID)
    return s and s.iconFileID or nil
end

local function GetCurrencyName(currencyID)
    local s = GetCurrencyStaticInfo(currencyID)
    return s and s.name or nil
end

local function GetCurrencyQualityColor(currencyID)
    local s = GetCurrencyStaticInfo(currencyID)
    if not s then return COLORS.dim end
    return (s.quality and QUALITY_HEX[s.quality]) or COLORS.dim
end

-- Builds a table (keyed by currency ID) of the shortest distinguishing label
-- for each crest tier.  Words shared by every name are stripped; what remains
-- is the tier-unique portion (e.g. "Adventurer", "Veteran", …).  Falls back
-- to the first word when nothing distinguishes (e.g. only one crest defined).
-- Result is cached in _crestLabelsCache; rebuilt only when crest IDs change.
local function BuildCrestLabels(ids, crestCount)
    -- Build a single key string so cache validity is one comparison instead of a loop.
    local keyParts = {}
    for i = 1, crestCount do keyParts[i] = tostring(ids[i] or 0) end
    local key = crestCount .. ":" .. tconcat(keyParts, ",")
    if _crestLabelsCache.labels and _crestLabelsCache.key == key then
        return _crestLabelsCache.labels
    end

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

    -- Store result in the cache for subsequent calls this session.
    _crestLabelsCache.key    = key
    _crestLabelsCache.labels = labels
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

local function GetNullaeusSpoilsParts()
    if not GetTrackedQuestID("nullaeusSpoils") then return "", "" end
    return GetQuestDoneParts(L.TRACKING_QUEST_NULLAEUS_SPOILS or "", "nullaeusSpoils", { as01 = true })
end

--  Sparks 
local function GetSparksParts()
    local id = Addon.TRACKING and Addon.TRACKING.sparkCurrencyID
    if not (id and tonumber(id) and tonumber(id) > 0) then return "", "" end
    local name  = GetCurrencyName(id) or L.TRACKING_SPARKS_LABEL or ""
    local label = name
    local cur, cap = FormatCurrencyProgressParts(id)
    cur = tonumber(cur) or 0
    cap = tonumber(cap) or 0

    -- Check quest completion first so we can adjust cap accordingly.
    -- The weekly quest grants a bonus spark that is not tracked in totalEarned,
    -- so we subtract 1 from the remaining cap when the quest is done.
    local qid = Addon.TRACKING and tonumber(Addon.TRACKING.sparkQuestID)
    local done
    if qid and qid > 0 then
        if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
            done = C_QuestLog.IsQuestFlaggedCompleted(qid)
        elseif IsQuestFlaggedCompleted then
            done = IsQuestFlaggedCompleted(qid)
        end
    end
    if done then
        cap = cap + 1
    end

    -- Build tooltip lines: quest completion + weekly cap.
    local tipLines = {}
    if qid and qid > 0 then
        if done == nil then
            tipLines[#tipLines + 1] = { text = "Weekly Quest: Unknown",   r = 0.6, g = 0.6, b = 0.6 }
        elseif done then
            tipLines[#tipLines + 1] = { text = "Weekly Quest: Complete",  r = 0.3, g = 1.0, b = 0.3 }
        else
            tipLines[#tipLines + 1] = { text = "Weekly Quest: Incomplete", r = 1.0, g = 0.4, b = 0.4 }
        end
    end
    if cap > 0 then
        tipLines[#tipLines + 1] = { text = "Weekly Cap: " .. cap, r = 1, g = 1, b = 1 }
    end
    local tooltip = (#tipLines > 0) and tipLines or nil

    if cap > 0 then
        return label, ColorWrap(ColorForXY(cur, cap), FormatXY(cur, cap)), tooltip
    end
    -- cap unavailable — show quantity in normal text color (no false green "done" signal)
    local th = Addon.THEME and Addon.THEME.text
    local dimHex = (th and th.r) and
        string.format("ff%02x%02x%02x", math.floor(th.r*255), math.floor(th.g*255), math.floor(th.b*255))
        or COLORS.dim
    return label, ColorWrap(dimHex, tostring(cur)), tooltip
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
            out       = {}, label     = {}, value    = {},
            name      = {},
            -- cur[i]      : wallet balance (held crests, may exceed earned if bonus-capped)
            -- earned[i]   : totalEarned toward the season cap (used for X/Y display)
            -- cap[i]      : season wallet cap == weekly soft cap (maxQuantity)
            -- weeklyMax[i]: same value as cap[i] (kept for legacy callers)
            cur       = {}, cap       = {},
            unlocked  = {}, effective = {}, gained  = {},
            earned    = {}, weeklyMax = {},
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
    local getCurrency = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo
    for i = 1, crestCount do
        local id = ids[i]
        if id then
            local info      = getCurrency and getCurrency(id)
            local held      = info and tonumber(info.quantity)    or 0
            local weeklyCap = info and tonumber(info.maxQuantity) or 0  -- weekly soft cap for crests
            local earned    = info and tonumber(info.totalEarned) or 0  -- earned toward weekly cap
            cache.cur[i]       = held
            cache.cap[i]       = weeklyCap
            cache.earned[i]    = earned
            cache.weeklyMax[i] = weeklyCap
        else
            cache.cur[i] = 0; cache.cap[i] = 0
            cache.earned[i] = 0; cache.weeklyMax[i] = 0
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
        local tradeFromPrev = 0
        if cache.unlocked[i - 1] then
            -- Always cascade using the effective (potentially traded-up) amount from
            -- the previous tier.  Crest trading at the vendor is based on wallet
            -- balance, not weekly earn caps, so the weekly-cap check was removed.
            tradeFromPrev = floor((effective[i - 1] or 0) / batchLower) * batchHigher
        end
        gained[i]    = tradeFromPrev
        effective[i] = (cache.cur[i] or 0) + tradeFromPrev
    end
    return highestTradeTarget, gained
end

local function GetCrestLines()
    local tracking = Addon.TRACKING
    if not tracking then return { "", "", "", "" } end
    local ids, crestCount = GetCrestIDsAndCount(tracking)
    local cache = EnsureCrestCache(tracking, crestCount)
    local out, labelOut, valueOut = ResetCrestOutput(cache, crestCount)
    local batchLower, batchHigher = GetCrestTradeBatches(tracking)
    PopulateCrestCurCap(cache, ids, crestCount)
    PopulateCrestUnlocked(cache, crestCount)
    local highestTradeTarget, gained = ComputeCrestTradeup(cache, crestCount, batchLower, batchHigher)
    local crestLabels = BuildCrestLabels(ids, crestCount)
    local convertTooltipTexts = {}
    local amountTooltipTexts  = {}
    for i = 1, crestCount do
        local id = ids[i]
        if id then
            local name = crestLabels[id] or GetCurrencyName(id) or tostring(id)
            if name then
                local earned = cache.earned[i]    or 0  -- totalEarned toward weekly cap
                local wkMax  = cache.weeklyMax[i] or 0  -- weekly soft cap
                local held   = cache.cur[i]       or 0  -- wallet balance
                local xy, color
                if wkMax > 0 then
                    xy = FormatXY(earned, wkMax)
                    color = (earned >= wkMax) and COLORS.green or (cache.unlocked[i] and COLORS.yellow or COLORS.red)
                else
                    xy = tostring(earned); color = COLORS.green
                end
                local tipBonus = math.max(0, held - earned)
                local tipTbl
                if tipBonus > 0 then
                    tipTbl = {
                        { text = "Capped Crests: " .. earned   },
                        { text = "Bonus Crests: "  .. tipBonus },
                        { text = "Total Crests: "  .. held     },
                    }
                else
                    tipTbl = {
                        { text = "Total Crests: " .. held },
                    }
                end
                amountTooltipTexts[i] = tipTbl
                local tradeUp = ""
                if highestTradeTarget and i == highestTradeTarget then
                    local n = tonumber(gained[i]) or 0
                    if n > 0 then
                        tradeUp = " " .. ColorWrap("ff4da6ff", "+" .. tostring(n))
                        local thisEarned = cache.earned[i]    or 0
                        local thisWkMax  = cache.weeklyMax[i] or 0
                        local cappedN    = (thisWkMax > 0) and math.min(n, math.max(0, thisWkMax - thisEarned)) or n
                        local tipTbl     = {}
                        if cappedN ~= n then
                            tipTbl[#tipTbl + 1] = { text = (L.TRACKING_TRADEUP_CURRENTLY_EARNABLE_FMT or "Currently earnable: %d"):format(cappedN) }
                            tipTbl[#tipTbl + 1] = { text = (L.TRACKING_TRADEUP_UNCAPPED_FMT           or "Uncapped: %d"):format(n) }
                        else
                            tipTbl[#tipTbl + 1] = { text = (L.TRACKING_TRADEUP_EARNABLE_FMT           or "Earnable: %d"):format(n) }
                        end
                        local convertTip = L.TRACKING_CONVERT_TOOLTIP or ""
                        if convertTip ~= "" then
                            tipTbl[#tipTbl + 1] = { text = convertTip, r = 0.7, g = 0.7, b = 0.7 }
                        end
                        convertTooltipTexts[i] = tipTbl
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
    return out, labelOut, valueOut, crestCount, convertTooltipTexts, amountTooltipTexts
end

--  Catalyst 
-- Returns current qty and cap for Catalyst charges, trying currency ID then
-- C_Catalyst APIs. Extracted so FillCurrencySnapshot can reuse the same logic
-- as GetCatalystParts without duplicating the fallback chain.
local function GetCatalystRawQtyCap()
    local cur, cap
    local id    = Addon.TRACKING and Addon.TRACKING.catalystCurrencyID
    local hasID = (id and tonumber(id) and tonumber(id) > 0) and true or false
    if hasID then
        local q, c = FormatCurrencyProgressParts(tonumber(id))
        cur = tonumber(q); cap = tonumber(c)
    end
    if cur == nil and C_Catalyst then
        if C_Catalyst.GetCharges then
            local charges = C_Catalyst.GetCharges()
            if type(charges) == "table" then
                cur = tonumber(charges.currentCharges or charges.numCharges or charges.charges)
                cap = tonumber(charges.maxCharges or charges.maximumCharges)
            end
        end
        if cur == nil and C_Catalyst.GetNumCharges then cur = tonumber(C_Catalyst.GetNumCharges()) end
        if cap == nil and C_Catalyst.GetMaxCharges  then cap = tonumber(C_Catalyst.GetMaxCharges())  end
    end
    return cur, cap
end

local function GetCatalystParts()
    local id    = Addon.TRACKING and Addon.TRACKING.catalystCurrencyID
    local hasID = (id and tonumber(id) and tonumber(id) > 0) and true or false
    local catName  = (hasID and GetCurrencyName(tonumber(id))) or L.TRACKING_CATALYST_LABEL or ""
    local catColor = (hasID and GetCurrencyQualityColor(tonumber(id))) or COLORS.dim
    local cur, _ = GetCatalystRawQtyCap()
    cur = tonumber(cur)
    if not cur then
        if not hasID then return "", "" end
        return ColorWrap(catColor, catName), ColorWrap(COLORS.red, L.TRACKING_NA or "")
    end
    return ColorWrap(catColor, catName), ColorWrap((cur <= 0) and COLORS.red or COLORS.green, ("%d"):format(cur))
end

--  Coffer Keys 
local function GetCofferKeysParts()
    local tracking  = Addon.TRACKING
    local shardsID  = tracking and tonumber(tracking.cofferKeysCurrencyID)
    local displayID = tracking and tonumber(tracking.cofferKeysDisplayCurrencyID)
    if not (shardsID and shardsID > 0) then return "", "" end
    -- Icon and name come from the key currency (3028)
    local name  = (displayID and displayID > 0 and GetCurrencyName(displayID)) or "Coffer Keys"
    local label = ColorWrap(GetCurrencyQualityColor(displayID or shardsID), name)
    -- Progress: keys earned+used this week vs total possible keys this week
    local getCurrency = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo
    local shardInfo   = getCurrency and getCurrency(shardsID)
    local keyInfo     = (getCurrency and displayID and displayID > 0) and getCurrency(displayID) or nil
    local earned    = (shardInfo and tonumber(shardInfo.quantityEarnedThisWeek)) or 0
    local weeklyCap = (shardInfo and tonumber(shardInfo.maxWeeklyQuantity))      or 0
    local current   = math.floor(earned    / 100)
    local total     = math.floor(weeklyCap / 100)
    -- Whole keys already held (display currency 3028) + any unconverted shards (÷100).
    -- Shards auto-convert to keys so the shard balance alone would show 0 when you
    -- hold a converted key; we need to add both together.
    local wholeKeys = (keyInfo  and tonumber(keyInfo.quantity))  or 0
    local rawShards = (shardInfo and tonumber(shardInfo.quantity)) or 0
    local balance   = wholeKeys + math.floor(rawShards / 100)
    local bonus = math.max(0, balance - current)
    local tipLines
    if bonus > 0 then
        tipLines = {
            { text = "Capped Keys: " .. (balance - bonus) },
            { text = "Bonus Keys: "  .. bonus             },
            { text = "Total Keys: "  .. balance           },
        }
    else
        tipLines = {
            { text = "Total Keys: " .. balance },
        }
    end
    if total > 0 then
        return label, ColorWrap(ColorForXY(current, total), FormatXY(current, total)), tipLines
    end
    return label, ColorWrap((current <= 0) and COLORS.red or COLORS.green, tostring(current)), tipLines
end

--  Public API 

-- Reusable buffers for GetCurrencyPanelRows – avoids allocating new tables on
-- every tracking update (which fires on bag updates, currency changes, etc.).
local _panelRowBuf  = {}  -- result array, returned and reused each call
local _panelRowPool = {}  -- pool of row sub-tables, one slot per max possible row

local function FillRow(n, lbl, val, iconID, currencyID, tooltipText, amountTooltipText, itemID, questKey)
    if not _panelRowPool[n] then _panelRowPool[n] = {} end
    local r             = _panelRowPool[n]
    r.label             = lbl
    r.value             = val
    r.iconID            = iconID
    r.currencyID        = currencyID
    r.tooltipText       = tooltipText or nil
    r.amountTooltipText = amountTooltipText or nil
    r.itemID            = itemID or nil
    r.questKey          = questKey or nil
    _panelRowBuf[n] = r
end

--- Returns an ordered list of currency rows ready to display in the right column.
--- Each entry: { label, value, iconID, currencyID }.  Empty rows are omitted.
--- The returned table is reused across calls – do not hold a reference past the
--- next tracking update.
function Addon:GetCurrencyPanelRows()
    local n        = 0
    local tracking = self.TRACKING

    -- Crests
    local _, labelLines, valueLines, crestCount, crestConvertTooltips, crestAmountTooltips = GetCrestLines()
    crestCount = tonumber(crestCount) or 4
    local crestIDs = tracking and GetCrestIDsAndCount(tracking) or {}
    if type(crestIDs) ~= "table" then crestIDs = {} end
    for i = 1, crestCount do
        if n >= RIGHT_LINE_COUNT then break end
        local id  = crestIDs[i]
        local lbl = (labelLines and labelLines[i]) or ""
        local val = (valueLines and valueLines[i]) or ""
        if (IsNonEmptyText(lbl) or IsNonEmptyText(val)) and not Addon:IsCurrencyHidden(id) then
            n = n + 1
            FillRow(n, lbl, val, GetCurrencyIconID(id), id,
                crestConvertTooltips and crestConvertTooltips[i],
                crestAmountTooltips  and crestAmountTooltips[i])
        end
    end

    -- Catalyst
    if n < RIGHT_LINE_COUNT then
        local catID = tracking and tracking.catalystCurrencyID
        local cLbl, cVal = GetCatalystParts()
        if (IsNonEmptyText(cLbl) or IsNonEmptyText(cVal)) and not Addon:IsCurrencyHidden(catID) then
            n = n + 1
            FillRow(n, cLbl, cVal, GetCurrencyIconID(catID), catID)
        end
    end

    -- Sparks
    if n < RIGHT_LINE_COUNT then
        local sID = tracking and tracking.sparkCurrencyID
        local sLbl, sVal, sTip = GetSparksParts()
        if (IsNonEmptyText(sLbl) or IsNonEmptyText(sVal)) and not Addon:IsCurrencyHidden(sID) then
            n = n + 1
            FillRow(n, sLbl, sVal, GetCurrencyIconID(sID), sID, nil, sTip)
        end
    end

    -- Coffer Keys
    if n < RIGHT_LINE_COUNT then
        local kDisplayID = tracking and tracking.cofferKeysDisplayCurrencyID
        local kLbl, kVal, kTip = GetCofferKeysParts()
        if (IsNonEmptyText(kLbl) or IsNonEmptyText(kVal)) and not Addon:IsCurrencyHidden(kDisplayID) then
            n = n + 1
            FillRow(n, kLbl, kVal, GetCurrencyIconID(kDisplayID), kDisplayID, nil, kTip)
        end
    end

    -- Misc currencies (miscCurrencyIDs in constants)
    if n < RIGHT_LINE_COUNT then
        local miscIDs = tracking and tracking.miscCurrencyIDs
        if type(miscIDs) == "table" then
            for _, rawID in ipairs(miscIDs) do
                if n >= RIGHT_LINE_COUNT then break end
                local id = tonumber(rawID)
                if id and id > 0 and not Addon:IsCurrencyHidden(id) then
                    local qty, cap = FormatCurrencyProgressParts(id)
                    qty = tonumber(qty) or 0
                    cap = tonumber(cap) or 0
                    local name = GetCurrencyName(id) or tostring(id)
                    local lbl = ColorWrap(GetCurrencyQualityColor(id), name)
                    local val
                    if cap > 0 then
                        val = ColorWrap(ColorForXY(qty, cap), FormatXY(qty, cap))
                    else
                        val = ColorWrap((qty <= 0) and COLORS.red or COLORS.green, tostring(qty))
                    end
                    if IsNonEmptyText(lbl) or IsNonEmptyText(val) then
                        n = n + 1
                        FillRow(n, lbl, val, GetCurrencyIconID(id), id)
                    end
                end
            end
        end
    end

    -- Delver's Bounty (quest)
    if n < RIGHT_LINE_COUNT and not Addon:IsQuestHidden("delversBounty") then
        local bLbl, bVal = GetDelversBountyParts()
        if IsNonEmptyText(bLbl) or IsNonEmptyText(bVal) then
            n = n + 1
            local bItemID = tracking and tracking.questItemIDs and tonumber(tracking.questItemIDs.delversBounty) or 0
            local bIcon, bLblFinal = nil, bLbl
            if bItemID > 0 then
                local itemName, _, itemQuality, _, _, _, _, _, _, itemTexture = GetItemInfo(bItemID)
                if itemTexture then bIcon = itemTexture end
                if itemName then
                    local qhex = QUALITY_HEX[itemQuality] or COLORS.white
                    bLblFinal = ColorWrap(qhex, itemName)
                end
            end
            FillRow(n, bLblFinal, bVal, bIcon, nil, nil, nil, bItemID > 0 and bItemID or nil, "delversBounty")
        end
    end

    -- Spoils of Nullaeus (quest)
    if n < RIGHT_LINE_COUNT and not Addon:IsQuestHidden("nullaeusSpoils") then
        local sLbl, sVal = GetNullaeusSpoilsParts()
        if IsNonEmptyText(sLbl) or IsNonEmptyText(sVal) then
            n = n + 1
            local sItemID = tracking and tracking.questItemIDs and tonumber(tracking.questItemIDs.nullaeusSpoils) or 0
            local sIcon, sLblFinal = nil, sLbl
            if sItemID > 0 then
                local itemName, _, itemQuality, _, _, _, _, _, _, itemTexture = GetItemInfo(sItemID)
                if itemTexture then sIcon = itemTexture end
                if itemName then
                    local qhex = QUALITY_HEX[itemQuality] or COLORS.white
                    sLblFinal = ColorWrap(qhex, itemName)
                end
            end
            FillRow(n, sLblFinal, sVal, sIcon, nil, nil, nil, sItemID > 0 and sItemID or nil, "nullaeusSpoils")
        end
    end

    -- Weekly Prey (quest)
    if n < RIGHT_LINE_COUNT and not Addon:IsQuestHidden("weeklyPrey") then
        local pLbl, pVal = GetWeeklyPreyParts()
        if IsNonEmptyText(pLbl) or IsNonEmptyText(pVal) then
            n = n + 1
            FillRow(n, pLbl, pVal, nil, nil, nil, nil, nil, "weeklyPrey")
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
        local ids, crestCount = GetCrestIDsAndCount(tracking)
        local cache = EnsureCrestCache(tracking, crestCount)
        local batchLower, batchHigher = GetCrestTradeBatches(tracking)
        PopulateCrestCurCap(cache, ids, crestCount)
        PopulateCrestUnlocked(cache, crestCount)
        local _, gained = ComputeCrestTradeup(cache, crestCount, batchLower, batchHigher)
        for i = 1, crestCount do
            local id = ids[i]
            if id then
                local tradeup = (gained[i] and gained[i] > 0) and gained[i] or nil
                snap.rightRows[#snap.rightRows + 1] = {
                    type = SNAP_TYPES.CREST, id = id, qty = cache.cur[i] or 0, earned = cache.earned[i] or 0, cap = cache.cap[i] or 0, tradeup = tradeup,
                }
            end
        end
    end
    local catQty, catCap = GetCatalystRawQtyCap()
    snap.rightRows[#snap.rightRows + 1] = { type = SNAP_TYPES.CATALYST, qty = catQty or 0, cap = catCap or 0 }
    local sparkID = tracking and tonumber(tracking.sparkCurrencyID)
    if sparkID and sparkID > 0 then
        local sQty, sCap = FormatCurrencyProgressParts(sparkID)
        local sparkQID = tonumber(tracking and tracking.sparkQuestID) or 0
        local sparkQDone = nil
        if sparkQID > 0 then
            if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
                sparkQDone = C_QuestLog.IsQuestFlaggedCompleted(sparkQID) and true or false
            elseif IsQuestFlaggedCompleted then
                sparkQDone = IsQuestFlaggedCompleted(sparkQID) and true or false
            end
        end
        -- Quest spark is counted in totalEarned but is a bonus on top of the weekly cap.
        -- Add 1 to the cap when the quest is done so the display reflects the true maximum.
        local sCapAdj = tonumber(sCap) or 0
        if sparkQDone then
            sCapAdj = sCapAdj + 1
        end
        snap.rightRows[#snap.rightRows + 1] = { type = SNAP_TYPES.SPARKS, id = sparkID, qty = tonumber(sQty) or 0, cap = sCapAdj, questDone = sparkQDone }
    end
    local cofferShardsID  = tracking and tonumber(tracking.cofferKeysCurrencyID)
    local cofferDisplayID = tracking and tonumber(tracking.cofferKeysDisplayCurrencyID)
    if cofferShardsID and cofferShardsID > 0 then
        local getCurrency  = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo
        local shardInfo    = getCurrency and getCurrency(cofferShardsID)
        local kEarned    = (shardInfo and tonumber(shardInfo.quantityEarnedThisWeek)) or 0
        local kWeeklyCap = (shardInfo and tonumber(shardInfo.maxWeeklyQuantity))      or 0
        -- Convert shard units (100 shards = 1 key) to key units, matching GetCofferKeysParts display.
        snap.rightRows[#snap.rightRows + 1] = { type = SNAP_TYPES.COFFERKEYS, id = cofferDisplayID or cofferShardsID, qty = math.floor(kEarned / 100), cap = math.floor(kWeeklyCap / 100) }
    end
    local miscIDs = tracking and tracking.miscCurrencyIDs
    if type(miscIDs) == "table" then
        for _, rawID in ipairs(miscIDs) do
            local id = tonumber(rawID)
            if id and id > 0 then
                local qty, cap = FormatCurrencyProgressParts(id)
                snap.rightRows[#snap.rightRows + 1] = { type = SNAP_TYPES.MISC, id = id, qty = tonumber(qty) or 0, cap = tonumber(cap) or 0 }
            end
        end
    end
    local bDone = GetQuestDoneRaw("delversBounty")
    if bDone ~= nil then
        snap.rightRows[#snap.rightRows + 1] = { type = SNAP_TYPES.QUEST, key = "delversBounty", done = bDone }
    end
    local sDone = GetQuestDoneRaw("nullaeusSpoils")
    if sDone ~= nil then
        snap.rightRows[#snap.rightRows + 1] = { type = SNAP_TYPES.QUEST, key = "nullaeusSpoils", done = sDone }
    end
    local pDone = GetQuestDoneRaw("weeklyPrey")
    if pDone ~= nil then
        snap.rightRows[#snap.rightRows + 1] = { type = SNAP_TYPES.QUEST, key = "weeklyPrey", done = pDone }
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
        return lbl, ColorWrap((qty <= 0) and COLORS.red or COLORS.green, ("%d"):format(qty))
    elseif t == "sparks" then
        local qty = tonumber(row.qty) or 0
        local id  = tonumber(row.id) or (self.TRACKING and tonumber(self.TRACKING.sparkCurrencyID))
        local name  = (id and id > 0 and GetCurrencyName(id)) or L.TRACKING_SPARKS_LABEL or ""
        local lbl   = ColorWrap(GetCurrencyQualityColor(id), name)
        local cap = 0
        if id and id > 0 then local _, c = FormatCurrencyProgressParts(id); cap = tonumber(c) or 0 end
        -- Append quest status line when snapshot has it.
        if row.questDone == true then
            lbl = lbl .. " |cff4dff4d(quest done)|r"
        elseif row.questDone == false then
            lbl = lbl .. " |cffff6666(quest not done)|r"
        end
        if cap > 0 then return lbl, ColorWrap(ColorForXY(qty, cap), FormatXY(qty, cap)) end
        return lbl, ColorWrap((qty <= 0) and COLORS.red or COLORS.green, tostring(qty))
    elseif t == "cofferkeys" then
        local earned = tonumber(row.qty) or 0
        local cap    = tonumber(row.cap) or 0
        local id     = tonumber(row.id) or (self.TRACKING and tonumber(self.TRACKING.cofferKeysDisplayCurrencyID))
            or (self.TRACKING and tonumber(self.TRACKING.cofferKeysCurrencyID))
        local name = (id and id > 0 and GetCurrencyName(id)) or "Coffer Keys"
        local lbl  = ColorWrap(GetCurrencyQualityColor(id), name)
        local current = math.floor(earned / 100)
        local total   = math.floor(cap    / 100)
        if total > 0 then return lbl, ColorWrap(ColorForXY(current, total), FormatXY(current, total)) end
        return lbl, ColorWrap((current <= 0) and COLORS.red or COLORS.green, tostring(current))
    elseif t == "misc" then
        local id  = tonumber(row.id)
        local qty = tonumber(row.qty) or 0
        local name = (id and id > 0 and GetCurrencyName(id)) or tostring(id or "?")
        local lbl  = ColorWrap(GetCurrencyQualityColor(id), name)
        local _, cap = FormatCurrencyProgressParts(id)
        cap = tonumber(cap) or 0
        if cap > 0 then
            return lbl, ColorWrap(ColorForXY(qty, cap), FormatXY(qty, cap))
        end
        return lbl, ColorWrap((qty <= 0) and COLORS.red or COLORS.green, tostring(qty))
    elseif t == "quest" then
        local key  = row.key
        local done = row.done
        local labelText = ""
        if key == "delversBounty" then labelText = L.TRACKING_QUEST_DELVERS_BOUNTY or ""
        elseif key == "nullaeusSpoils" then labelText = L.TRACKING_QUEST_NULLAEUS_SPOILS or ""
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

--- Expose crest ordering so consumers don't duplicate the fallback logic.
function Addon:GetCrestIDsAndCount()
    return GetCrestIDsAndCount(self.TRACKING or {})
end
