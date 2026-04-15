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
local _crestLabelsCache = { count = 0, ids = {}, labels = nil }

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
    local held        = tonumber(info.quantity)    or 0
    local earnedSoFar = tonumber(info.totalEarned) or 0
    local weeklyMax   = tonumber(info.maxQuantity) or 0
    -- cap = held + still-earnable-this-week = held + (weeklyMax - earnedSoFar)
    if weeklyMax > 0 then
        local available = math.max(0, weeklyMax - earnedSoFar)
        return held, held + available
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
    -- Return cached result when the crest IDs haven't changed.
    if _crestLabelsCache.labels and _crestLabelsCache.count == crestCount then
        local valid = true
        for i = 1, crestCount do
            if _crestLabelsCache.ids[i] ~= ids[i] then valid = false; break end
        end
        if valid then return _crestLabelsCache.labels end
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
    _crestLabelsCache.count = crestCount
    for i = 1, crestCount do _crestLabelsCache.ids[i] = ids[i] end
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
            -- If the previous tier is at its weekly cap, lower crests can't funnel
            -- through it; only the wallet balance is available to convert upward.
            local prevEarned = cache.earned[i - 1]    or 0
            local prevWkMax  = cache.weeklyMax[i - 1] or 0
            local prevCapped = prevWkMax > 0 and prevEarned >= prevWkMax
            local prevAmt    = prevCapped and (cache.cur[i - 1] or 0)
                                          or (tonumber(effective[i - 1]) or 0)
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
                            tipTbl[#tipTbl + 1] = { text = "Currently earnable: " .. cappedN }
                            tipTbl[#tipTbl + 1] = { text = "Uncapped: "           .. n       }
                        else
                            tipTbl[#tipTbl + 1] = { text = "Earnable: "           .. n       }
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

local function FillRow(n, lbl, val, iconID, currencyID, tooltipText, amountTooltipText, itemID)
    if not _panelRowPool[n] then _panelRowPool[n] = {} end
    local r             = _panelRowPool[n]
    r.label             = lbl
    r.value             = val
    r.iconID            = iconID
    r.currencyID        = currencyID
    r.tooltipText       = tooltipText or nil
    r.amountTooltipText = amountTooltipText or nil
    r.itemID            = itemID or nil
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
        local lbl = (labelLines and labelLines[i]) or ""
        local val = (valueLines and valueLines[i]) or ""
        if IsNonEmptyText(lbl) or IsNonEmptyText(val) then
            local id = crestIDs[i]
            n = n + 1
            FillRow(n, lbl, val, GetCurrencyIconID(id), id,
                crestConvertTooltips and crestConvertTooltips[i],
                crestAmountTooltips  and crestAmountTooltips[i])
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
        local kLbl, kVal, kTip = GetCofferKeysParts()
        if IsNonEmptyText(kLbl) or IsNonEmptyText(kVal) then
            local kDisplayID = tracking and tracking.cofferKeysDisplayCurrencyID
            n = n + 1
            FillRow(n, kLbl, kVal, GetCurrencyIconID(kDisplayID), kDisplayID, nil, kTip)
        end
    end

    -- Delver's Bounty (quest)
    if n < RIGHT_LINE_COUNT then
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
            FillRow(n, bLblFinal, bVal, bIcon, nil, nil, nil, bItemID > 0 and bItemID or nil)
        end
    end

    -- Spoils of Nullaeus (quest)
    if n < RIGHT_LINE_COUNT then
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
            FillRow(n, sLblFinal, sVal, sIcon, nil, nil, nil, sItemID > 0 and sItemID or nil)
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
    local cofferShardsID  = tracking and tonumber(tracking.cofferKeysCurrencyID)
    local cofferDisplayID = tracking and tonumber(tracking.cofferKeysDisplayCurrencyID)
    if cofferShardsID and cofferShardsID > 0 then
        local getCurrency  = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo
        local shardInfo    = getCurrency and getCurrency(cofferShardsID)
        local kEarned    = (shardInfo and tonumber(shardInfo.quantityEarnedThisWeek)) or 0
        local kWeeklyCap = (shardInfo and tonumber(shardInfo.maxWeeklyQuantity))      or 0
        snap.rightRows[#snap.rightRows + 1] = { type = "cofferkeys", id = cofferDisplayID or cofferShardsID, qty = kEarned, cap = kWeeklyCap }
    end
    local bDone = GetQuestDoneRaw("delversBounty")
    if bDone ~= nil then
        snap.rightRows[#snap.rightRows + 1] = { type = "quest", key = "delversBounty", done = bDone }
    end
    local sDone = GetQuestDoneRaw("nullaeusSpoils")
    if sDone ~= nil then
        snap.rightRows[#snap.rightRows + 1] = { type = "quest", key = "nullaeusSpoils", done = sDone }
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
