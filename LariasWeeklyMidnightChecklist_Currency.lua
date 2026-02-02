local addonName = ...
local Addon = _G[addonName]
if not Addon then return end

if Addon.InitConstants then
    Addon:InitConstants(addonName)
end

local THEME = Addon.THEME
local UI = Addon.UI

local L = Addon.L or {}

local trackingEventFrame
local TrackingUI = { left = {}, right = {} }

local tonumber, tostring, type = tonumber, tostring, type
local floor, max, abs = math.floor, math.max, math.abs
local tinsert, tremove, tconcat, tsort = table.insert, table.remove, table.concat, table.sort
local strlower, strfind = string.lower, string.find

local function Wipe(t)
    if not t then return end
    if wipe then
        wipe(t)
        return
    end
    for k in pairs(t) do
        t[k] = nil
    end
end

Addon.TRACKING = Addon.TRACKING or {}

local function GetActiveTrackingProfile()
    local tracking = Addon.TRACKING
    local profiles = tracking and tracking.profiles
    local tww = profiles and profiles.tww
    local midnight = profiles and profiles.midnight

    local threshold = (tracking and tonumber(tracking.midnightMinLevel)) or 90
    local level = 0
    if UnitLevel then
        level = tonumber(UnitLevel("player")) or 0
    end

    if level >= threshold then
        return midnight or tww or tracking
    end
    return tww or tracking
end

local function SafeRegisterEvent(frame, eventName)
    if not (frame and eventName) then return false end
    local ok = pcall(frame.RegisterEvent, frame, eventName)
    return ok and true or false
end

function Addon:RequestTrackingUpdate()
    if self._trackingUpdatePending then return end
    self._trackingUpdatePending = true

    if not self._trackingUpdateRunner then
        local addon = self
        self._trackingUpdateRunner = function()
            addon._trackingUpdatePending = nil
            if addon.UpdateTracking then
                addon:UpdateTracking()
            end
        end
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0, self._trackingUpdateRunner)
    else
        self._trackingUpdateRunner()
    end
end

local COLORS = {
    red    = "ffff4040",
    yellow = "ffffd34d",
    green  = "ff40ff40",
    dim    = "ffbfbfbf",
}

local function ColorWrap(hex, txt) return ("|c%s%s|r"):format(hex, tostring(txt or "")) end

local function SetTextIfChanged(fs, text)
    if not fs then return end
    text = text or ""
    if fs._lariasText ~= text then
        fs._lariasText = text
        fs:SetText(text)
    end
end

local function IsNonEmptyText(s)
    if type(s) ~= "string" then return false end
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return s:match("%S") ~= nil
end

local function SetShownIfChanged(region, shown)
    if not (region and region.IsShown and region.SetShown) then return end
    local want = shown and true or false
    if region:IsShown() ~= want then
        region:SetShown(want)
    end
end

local function FormatXY(cur, cap)
    cur = tonumber(cur) or 0
    cap = tonumber(cap) or 0
    if cap > 0 then return ("%d/%d"):format(cur, cap) end
    local inf = L.TRACKING_INF
    if type(inf) ~= "string" or inf == "" then inf = "∞" end
    return ("%d/%s"):format(cur, inf)
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

local RIGHT_LINE_COUNT = 10

local function GetCrestAchievementID(i)
    local profile = GetActiveTrackingProfile()
    local ach = profile and profile.crestAchievementIDs
    if type(ach) ~= "table" then return nil end

    if ach[1] ~= nil then
        -- Order is defined by the crestCurrencyIDs list; use index-based mapping.
        local idx = tonumber(i)
        return idx and ach[idx] or nil
    end

    -- Non-array tables are not supported for crestAchievementIDs; keep it explicit.
    return nil
end

local function FirstWord(s)
    if not s then return nil end
    s = tostring(s)
    local w = s:match("^(%S+)")
    if w and w ~= "" then return w end
    return nil
end

local function SplitWords(s)
    if not s then return {} end
    s = tostring(s)
    local out = {}
    for w in s:gmatch("%S+") do
        out[#out + 1] = w
    end
    return out
end

local function CommonPrefixLen(wordsList)
    local minLen
    for i = 1, #wordsList do
        local w = wordsList[i]
        local n = type(w) == "table" and #w or 0
        if n > 0 then
            if not minLen or n < minLen then minLen = n end
        end
    end
    if not minLen or minLen <= 0 then return 0 end

    local prefix = 0
    for idx = 1, minLen do
        local base
        for i = 1, #wordsList do
            local w = wordsList[i]
            if type(w) == "table" and #w > 0 then
                local cur = tostring(w[idx] or "")
                if cur == "" then return prefix end
                cur = cur:lower()
                if base == nil then
                    base = cur
                elseif base ~= cur then
                    return prefix
                end
            end
        end
        prefix = idx
    end
    return prefix
end

local function CommonSuffixLen(wordsList)
    local minLen
    for i = 1, #wordsList do
        local w = wordsList[i]
        local n = type(w) == "table" and #w or 0
        if n > 0 then
            if not minLen or n < minLen then minLen = n end
        end
    end
    if not minLen or minLen <= 0 then return 0 end

    local suffix = 0
    for back = 1, minLen do
        local base
        for i = 1, #wordsList do
            local w = wordsList[i]
            if type(w) == "table" and #w > 0 then
                local idx = (#w - back) + 1
                local cur = tostring(w[idx] or "")
                if cur == "" then return suffix end
                cur = cur:lower()
                if base == nil then
                    base = cur
                elseif base ~= cur then
                    return suffix
                end
            end
        end
        suffix = back
    end
    return suffix
end

local function BuildUniqueWordDisplayNames(names, count)
    local function CapitalizeWords(s)
        if type(s) ~= "string" or s == "" then return s end
        return (s:gsub("(%S)(%S*)", function(a, b)
            return a:upper() .. b
        end))
    end

    local wordsList = {}
    local out = {}
    count = tonumber(count) or 0
    for i = 1, count do
        local name = names and names[i]
        if type(name) == "string" and name ~= "" then
            wordsList[#wordsList + 1] = SplitWords(name)
        end
    end

    local prefixLen = CommonPrefixLen(wordsList)
    local suffixLen = CommonSuffixLen(wordsList)

    for i = 1, count do
        local name = names and names[i]
        if type(name) == "string" and name ~= "" then
            local words = SplitWords(name)
            local startIdx = prefixLen + 1
            local endIdx = #words - suffixLen

            local unique
            if startIdx <= endIdx then
                unique = table.concat(words, " ", startIdx, endIdx)
            end

            if not unique or unique == "" then
                unique = FirstWord(name) or name
            end
            out[i] = CapitalizeWords(unique)
        else
            out[i] = nil
        end
    end
    return out
end

local function FormatCurrencyProgressParts(currencyID)
    if not currencyID or not C_CurrencyInfo or not C_CurrencyInfo.GetCurrencyInfo then return nil end
    local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
    if not info then return nil end

    local prefix = L.TRACKING_CURRENCY_FALLBACK_PREFIX
    if type(prefix) ~= "string" then prefix = "" end
    local name = info.name or (prefix .. tostring(currencyID))
    local qty = info.quantity or 0
    local weeklyMax = info.maxWeeklyQuantity
    local maxQty = info.maxQuantity

    if weeklyMax and weeklyMax > 0 then return name, qty, weeklyMax end
    if maxQty and maxQty > 0 then return name, qty, maxQty end
    return name, qty, 0
end

local function CountItemInBags(itemID)
    if not itemID or not C_Item or not C_Item.GetItemCount then return 0 end
    return C_Item.GetItemCount(itemID, true) or 0
end

local function DetectCrestCurrencyIDsFromList()
    if not (C_CurrencyInfo and C_CurrencyInfo.GetCurrencyListSize and C_CurrencyInfo.GetCurrencyListInfo and C_CurrencyInfo.GetCurrencyListLink) then
        return nil
    end

    local found = {}
    local size = C_CurrencyInfo.GetCurrencyListSize() or 0
    for i = 1, size do
        local info = C_CurrencyInfo.GetCurrencyListInfo(i)
        if info and not info.isHeader then
            local name = tostring(info.name or "")
            local needle = L.TRACKING_CREST_MATCH_SUBSTRING
            needle = type(needle) == "string" and needle:lower() or ""
            if needle ~= "" and name ~= "" and name:lower():find(needle, 1, true) then
                local link = C_CurrencyInfo.GetCurrencyListLink(i)
                local id = link and tonumber(tostring(link):match("currency:(%d+)"))
                if id then
                    found[#found + 1] = id
                end
            end
        end
    end

    if #found < 4 then return nil end

    local ids = {}
    for i = 1, 4 do
        ids[i] = found[i]
    end
    return ids
end

local function BottomFor(obj)
    if not obj then return 0 end
    if obj.IsShown and not obj:IsShown() then return 0 end

    local y = tonumber(obj._lariasBaseY) or 0
    local h = 0
    if obj.GetStringHeight then h = tonumber(obj:GetStringHeight()) or 0 end
    if h <= 0 and obj.GetHeight then h = tonumber(obj:GetHeight()) or 0 end
    if h <= 0 then h = 16 end
    return abs(y) + h
end

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
    if not itemLink then return false end
    if not (C_Item and C_Item.RequestLoadItemDataByID) then return false end
    local itemID = tonumber(tostring(itemLink):match("item:(%d+)"))
    if not itemID then return false end
    C_Item.RequestLoadItemDataByID(itemID)
    return true
end

local function GetExampleRewardIlvlForActivity(activityInfo)
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

local function IsActivityComplete(a)
    if not a then return false end
    if type(a.isComplete) == "boolean" then return a.isComplete end
    if type(a.isCompleted) == "boolean" then return a.isCompleted end
    if type(a.completed) == "boolean" then return a.completed end
    local prog = a.progress
    local thr = a.threshold

    if type(prog) == "table" then
        thr = thr or prog.threshold or prog.required or prog.total
        prog = prog.progress or prog.current or prog.value
    end

    local progNum = tonumber(prog) or 0
    local thrNum  = tonumber(thr) or 0
    if thrNum > 0 then return progNum >= thrNum end

    local maxP = tonumber(a.maxProgress or a.requiredProgress or a.required or a.total)
    if maxP and maxP > 0 then return progNum >= maxP end

    return false
end

local function ColorForGVProgress(complete, total)
    complete = tonumber(complete) or 0
    total = tonumber(total) or 0
    if total <= 0 then return COLORS.dim end
    if complete <= 0 then return COLORS.red end
    if complete >= total then return COLORS.green end
    return COLORS.yellow
end

local function MakeGVHeader(label)
    return ColorWrap(COLORS.dim, label)
end

local function MakeGVThresholdsString(complete, total, thresholds, parts)
    complete = tonumber(complete) or 0
    total = tonumber(total) or 0
    parts = parts or {}
    Wipe(parts)

    if total <= 0 or type(thresholds) ~= "table" or #thresholds <= 0 then
        return ColorWrap(COLORS.red, L.TRACKING_NA or "")
    end

    for i = 1, #thresholds do
        local v = tonumber(thresholds[i])
        if v then
            parts[#parts + 1] = ColorWrap((complete >= i) and COLORS.green or COLORS.red, " " .. tostring(v) .. " ")
        end
    end
    return tconcat(parts, " ")
end

local function MakeGVIlvlsRow(ilvls, maxPossible, parts)
    parts = parts or {}
    Wipe(parts)
    for i = 1, #ilvls do
        local v = tonumber(ilvls[i]) or 0
        if v > 0 then
            local c = (maxPossible > 0 and v == maxPossible) and COLORS.green or COLORS.red
            parts[#parts + 1] = ColorWrap(c, tostring(v))
        else
            parts[#parts + 1] = ColorWrap(COLORS.dim, L.TRACKING_NA or "")
        end
    end
    return tconcat(parts, " ")
end

local function SummarizeVaultType(allActivities, desiredType, ilvls)
    local total, complete, maxPossible = 0, 0, 0
    ilvls = ilvls or {}
    Wipe(ilvls)

    for idx = 1, #allActivities do
        local a = allActivities[idx]
        if a and a.type == desiredType then
            total = total + 1
            if IsActivityComplete(a) then
                complete = complete + 1
                local ilvl = GetActivityRewardIlvl(a)
                if not ilvl or ilvl <= 0 then
                    ilvl = GetExampleRewardIlvlForActivity(a)
                end
                ilvls[#ilvls + 1] = ilvl
                if ilvl and ilvl > maxPossible then maxPossible = ilvl end
            else
                ilvls[#ilvls + 1] = 0
            end
        end
    end

    return complete, total, maxPossible
end

local function SummarizeVaultOther(allActivities, excludedTypes, ilvls)
    local total, complete, maxPossible = 0, 0, 0
    ilvls = ilvls or {}
    Wipe(ilvls)

    for idx = 1, #allActivities do
        local a = allActivities[idx]
        local t = a and a.type
        if a and not (excludedTypes and excludedTypes[t]) then
            total = total + 1
            if IsActivityComplete(a) then
                complete = complete + 1
                local ilvl = GetActivityRewardIlvl(a)
                if not ilvl or ilvl <= 0 then
                    ilvl = GetExampleRewardIlvlForActivity(a)
                end
                ilvls[#ilvls + 1] = ilvl
                if ilvl > maxPossible then maxPossible = ilvl end
            else
                ilvls[#ilvls + 1] = 0
            end
        end
    end

    return complete, total, maxPossible
end

local function GetGreatVaultBlockLines()
    local cache = Addon.TRACKING._gvCache
    if not cache then
        cache = {
            out = { "", "", "", "", "", "" },
            rIlvls = {},
            mIlvls = {},
            wIlvls = {},
            parts = {},
            excluded = {},
            lastRaidType = nil,
            lastMplusType = nil,
        }
        Addon.TRACKING._gvCache = cache
    end

    local out = cache.out
    out[1], out[2], out[3], out[4], out[5], out[6] = "", "", "", "", "", ""

    if not C_WeeklyRewards or not C_WeeklyRewards.GetActivities then
        out[1] = MakeGVHeader(L.TRACKING_GV_RAID or "")
        out[2] = ColorWrap(COLORS.red, L.TRACKING_NA or "")
        out[4] = MakeGVHeader(L.TRACKING_GV_DUNGEONS or "")
        out[5] = ColorWrap(COLORS.red, L.TRACKING_NA or "")
        return out
    end

    local activities = C_WeeklyRewards.GetActivities()
    if type(activities) ~= "table" then
        out[1] = MakeGVHeader(L.TRACKING_GV_RAID or "")
        out[2] = ColorWrap(COLORS.red, L.TRACKING_NA or "")
        out[4] = MakeGVHeader(L.TRACKING_GV_DUNGEONS or "")
        out[5] = ColorWrap(COLORS.red, L.TRACKING_NA or "")
        return out
    end

    local TYPE_MPLUS = (Enum and Enum.WeeklyRewardChestActivityType and Enum.WeeklyRewardChestActivityType.MythicPlus) or 1
    local TYPE_RAID  = (Enum and Enum.WeeklyRewardChestActivityType and Enum.WeeklyRewardChestActivityType.Raid) or 3

    local rC, rT, rMax = SummarizeVaultType(activities, TYPE_RAID, cache.rIlvls)
    local mC, mT, mMax = SummarizeVaultType(activities, TYPE_MPLUS, cache.mIlvls)

    local raidExampleMax, dungeonExampleMax = 0, 0
    for idx = 1, #activities do
        local a = activities[idx]
        local t = a and a.type
        if a and t then
            if t == TYPE_RAID then
                raidExampleMax = max(raidExampleMax, GetExampleRewardIlvlForActivity(a))
            elseif t == TYPE_MPLUS then
                dungeonExampleMax = max(dungeonExampleMax, GetExampleRewardIlvlForActivity(a))
            end
        end
    end

    local raidMax = (raidExampleMax > 0) and raidExampleMax or rMax
    local dungeonMax = (dungeonExampleMax > 0) and dungeonExampleMax or mMax

    out[1] = MakeGVHeader(L.TRACKING_GV_RAID or "")
    out[2] = (rT > 0) and MakeGVThresholdsString(rC, rT, { 2, 4, 6 }, cache.parts) or ColorWrap(COLORS.red, L.TRACKING_NA or "")
    out[3] = (rT > 0) and MakeGVIlvlsRow(cache.rIlvls, raidMax, cache.parts) or ""

    out[4] = MakeGVHeader(L.TRACKING_GV_DUNGEONS or "")
    out[5] = (mT > 0) and MakeGVThresholdsString(mC, mT, { 1, 4, 8 }, cache.parts) or ColorWrap(COLORS.red, L.TRACKING_NA or "")
    out[6] = (mT > 0) and MakeGVIlvlsRow(cache.mIlvls, dungeonMax, cache.parts) or ""

    return out
end

local function GetSparksParts()
    local label = ColorWrap(COLORS.dim, L.TRACKING_SPARKS_LABEL or "")
    local profile = GetActiveTrackingProfile()
    local id = profile and profile.sparkCurrencyID
    if id and tonumber(id) and tonumber(id) > 0 then
        local _, cur, c = FormatCurrencyProgressParts(id)
        cur = cur or 0
        c = tonumber(c) or 0

        local xy
        local color
        if c > 0 then
            xy = FormatXY(cur, c)
            color = ColorForXY(cur, c)
        else
            local inf = L.TRACKING_INF
            if type(inf) ~= "string" or inf == "" then inf = "∞" end
            xy = ("%d/%s"):format(tonumber(cur) or 0, inf)
            color = ((tonumber(cur) or 0) <= 0) and COLORS.red or COLORS.yellow
        end
        return label, ColorWrap(color, xy)
    end

    return label, ColorWrap(COLORS.red, L.TRACKING_NA or "")
end

local function GetSparksLine()
    local label, value = GetSparksParts()
    return label .. " " .. (value or "")
end

local function GetTrackedQuestID(key)
    local profile = GetActiveTrackingProfile()
    local q = profile and profile.questIDs and profile.questIDs[key]
    q = tonumber(q) or 0
    if q <= 0 then return nil end
    return q
end

local function GetQuestDoneParts(labelText, questKey, opts)
    local label = ColorWrap(COLORS.dim, labelText)
    local questID = GetTrackedQuestID(questKey)
    if not questID then
        return label, ColorWrap(COLORS.dim, "?")
    end

    opts = opts or {}
    local doneText = opts.doneText
    local notDoneText = opts.notDoneText
    if opts.as01 then
        doneText = doneText or "1/1"
        notDoneText = notDoneText or "0/1"
    else
        doneText = doneText or (L.TRACKING_DONE or "")
        notDoneText = notDoneText or (L.TRACKING_NOT_DONE or "")
    end

    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, questID)
        if ok then
            if done then
                return label, ColorWrap(COLORS.green, doneText)
            end
            return label, ColorWrap(COLORS.red, notDoneText)
        end
    end
    return label, ColorWrap(COLORS.red, L.TRACKING_NA or "")
end

local function GetDelversBountyParts()
    return GetQuestDoneParts(L.TRACKING_QUEST_DELVERS_BOUNTY or "", "delversBounty", { as01 = true })
end

local function GetWeeklyPreyParts()
    if not GetTrackedQuestID("weeklyPrey") then
        return "", ""
    end
    return GetQuestDoneParts(L.TRACKING_QUEST_WEEKLY_PREY or "", "weeklyPrey", { as01 = true })
end

local function GetCrestTradeBatches(profile)
    profile = profile or GetActiveTrackingProfile() or {}
    local batch = profile.crestTradeBatch
    local lower
    local higher

    if type(batch) == "table" then
        -- Accept either { lower, higher } or { lower = X, higher = Y }.
        lower = tonumber(batch[1] or batch.lower)
        higher = tonumber(batch[2] or batch.higher)
    end

    -- Backstop defaults (historically 45 -> 15).
    if not lower or lower <= 0 then lower = 45 end
    if not higher or higher <= 0 then
        higher = floor(lower / 3)
        if higher <= 0 then higher = 1 end
    end

    return lower, higher
end

local function GetCrestLines()
    local profile = GetActiveTrackingProfile()
    if not profile then return { "", "", "", "" } end

    -- Respect the configured crestCurrencyIDs order; only auto-detect if none are configured.
    if not profile._crestIDsDetected then
        local ids = profile.crestCurrencyIDs
        local hasConfigured = false
        if type(ids) == "table" and ids[1] ~= nil and #ids > 0 then
            hasConfigured = true
        end

        if not hasConfigured then
            local detected = DetectCrestCurrencyIDsFromList()
            if detected then
                profile.crestCurrencyIDs = detected
            end
        end
        profile._crestIDsDetected = true
    end

    local ids = profile.crestCurrencyIDs or {}
    local crestCount
    if type(ids) == "table" and ids[1] ~= nil then
        crestCount = #ids
    else
        ids = {}
        crestCount = 0
    end

    if crestCount <= 0 then crestCount = 4 end
    local cache = profile._crestCache
    if not cache or cache.count ~= crestCount then
        cache = {
            count = crestCount,
            out = {},
            label = {},
            value = {},
            name = {},
            cur = {},
            cap = {},
            unlocked = {},
            effective = {},
            gained = {},
        }
        profile._crestCache = cache
    end

    local out = cache.out
    local labelOut = cache.label
    local valueOut = cache.value
    for i = 1, crestCount do
        out[i] = ""
        labelOut[i] = ""
        valueOut[i] = ""
    end

    local batchLower, batchHigher = GetCrestTradeBatches(profile)
    local crest = cache

    for i = 1, crestCount do
        local id = ids[i]
        if id then
            local name, cur, cap = FormatCurrencyProgressParts(id)
            crest.name[i] = name
            crest.cur[i] = tonumber(cur) or 0
            crest.cap[i] = tonumber(cap) or 0
        else
            crest.name[i] = nil
            crest.cur[i] = 0
            crest.cap[i] = 0
        end
    end

    for i = 1, crestCount do
        local achievementID = GetCrestAchievementID(i)
        crest.unlocked[i] = achievementID and IsAchievementCompleteSafe(achievementID) or false
    end

    local highestTradeTarget
    for i = crestCount, 2, -1 do
        if crest.unlocked[i - 1] then
            highestTradeTarget = i
            break
        end
    end

    local effective = crest.effective
    local gained = crest.gained
    effective[1] = crest.cur[1] or 0
    gained[1] = 0
    for i = 2, crestCount do
        local prevAmt = tonumber(effective[i - 1]) or 0
        local tradeFromPrev = 0
        if crest.unlocked[i - 1] then
            tradeFromPrev = floor(prevAmt / batchLower) * batchHigher
        end
        gained[i] = tradeFromPrev
        effective[i] = (crest.cur[i] or 0) + tradeFromPrev
    end

    for i = 1, crestCount do
        local id = ids[i]
        if id then
            local name = crest.name[i]
            if name then
                local displayNames = crest._displayNames
                if type(displayNames) ~= "table" or displayNames._count ~= crestCount then
                    displayNames = { _count = crestCount }
                    crest._displayNames = displayNames
                end

                local sigParts = crest._displaySigParts
                if type(sigParts) ~= "table" then
                    sigParts = {}
                    crest._displaySigParts = sigParts
                end
                local sig = ""
                for si = 1, crestCount do
                    local n = crest.name[si] or ""
                    sigParts[si] = n
                end
                sig = table.concat(sigParts, "|")

                if crest._displaySig ~= sig then
                    local computed = BuildUniqueWordDisplayNames(crest.name, crestCount)
                    for di = 1, crestCount do
                        displayNames[di] = computed[di]
                    end
                    crest._displaySig = sig
                end

                local displayName = displayNames[i] or name
                local cur = crest.cur[i]
                local cap = crest.cap[i]

                local forceGreen = crest.unlocked[i] or false

                local xy
                local color
                if cap > 0 then
                    xy = FormatXY(cur, cap)
                    color = forceGreen and COLORS.green or ColorForXY(cur, cap)
                else
                    local inf = L.TRACKING_INF
                    if type(inf) ~= "string" or inf == "" then inf = "∞" end
                    xy = ("%d/%s"):format(cur, inf)
                    color = forceGreen and COLORS.green or ((cur <= 0) and COLORS.red or COLORS.green)
                end

                local tradeUp = ""
                if highestTradeTarget and i == highestTradeTarget then
                    local n = tonumber(gained[i]) or 0
                    if n > 0 then
                        tradeUp = ColorWrap(COLORS.dim, " (")
                            .. ColorWrap("ff4da6ff", "+" .. tostring(n))
                            .. ColorWrap(COLORS.dim, L.TRACKING_TRADE_UP_SUFFIX or "")
                    end
                end

                local lbl = ColorWrap(COLORS.dim, tostring(displayName) .. ":") .. tradeUp
                local val = ColorWrap(color, xy)
                labelOut[i] = lbl
                valueOut[i] = val
                out[i] = lbl .. " " .. val
            else
                local fmt = L.TRACKING_CREST_ID_LABEL_FMT or "%s"
                local lbl = ColorWrap(COLORS.dim, (fmt):format(tostring(id)))
                local val = ColorWrap(COLORS.red, L.TRACKING_NA or "")
                labelOut[i] = lbl
                valueOut[i] = val
                out[i] = lbl .. " " .. val
            end
        else
            local lbl = ColorWrap(COLORS.dim, L.TRACKING_CREST_LABEL or "")
            local val = ColorWrap(COLORS.red, L.TRACKING_NO_ID or "")
            labelOut[i] = lbl
            valueOut[i] = val
            out[i] = lbl .. " " .. val
        end
    end

    return out
end

local function GetCatalystParts()
    local cur, cap

    local profile = GetActiveTrackingProfile()
    local id = profile and profile.catalystCurrencyID
    if id and tonumber(id) and tonumber(id) > 0 then
        local _, qty, c = FormatCurrencyProgressParts(id)
        cur = tonumber(qty)
        cap = tonumber(c)
    end

    if (cur == nil) and C_Catalyst then
        if C_Catalyst.GetCharges then
            local charges = C_Catalyst.GetCharges()
            if type(charges) == "table" then
                cur = charges.currentCharges or charges.numCharges or charges.charges
                cap = charges.maxCharges or charges.maximumCharges
            end
        end

        if cur == nil and C_Catalyst.GetNumCharges then
            cur = C_Catalyst.GetNumCharges()
        end
        if cap == nil and C_Catalyst.GetMaxCharges then
            cap = C_Catalyst.GetMaxCharges()
        end
    end

    cur = tonumber(cur)
    cap = tonumber(cap)
    if not cur then
        return ColorWrap(COLORS.dim, L.TRACKING_CATALYST_LABEL or ""), ColorWrap(COLORS.red, L.TRACKING_NA or "")
    end

    if cap and cap > 0 then
        local xy = FormatXY(cur, cap)
        local color = ColorForXY(cur, cap)
        return ColorWrap(COLORS.dim, L.TRACKING_CATALYST_LABEL or ""), ColorWrap(color, xy)
    end

    local color = (cur <= 0) and COLORS.red or COLORS.yellow
    return ColorWrap(COLORS.dim, L.TRACKING_CATALYST_LABEL or ""), ColorWrap(color, ("%d"):format(cur))
end

local function GetCatalystLine()
    local label, value = GetCatalystParts()
    return label .. " " .. (value or "")
end

function Addon:CreateTrackingPanel(parentFrame)
    if self._trackingFrame then return end
    local db = self:EnsureDB()

    local tf = CreateFrame("Frame", nil, parentFrame)
    if not tf.SetBackdrop and BackdropTemplateMixin and Mixin then
        Mixin(tf, BackdropTemplateMixin)
    end
    tf:SetPoint("BOTTOMLEFT", parentFrame, "BOTTOMLEFT", Addon.UI.sectionInsetX, UI.scrollBottom)
    tf:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", -Addon.UI.sectionInsetX, UI.scrollBottom)
    tf:SetHeight(UI.trackH)
    self:ApplyTheme(tf)

    local title = tf:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", tf, "TOPLEFT", 10, -8)
    title:SetTextColor(THEME.header.r, THEME.header.g, THEME.header.b, THEME.header.a)
    title:SetText(L.TRACKING_GREAT_VAULT_TITLE or "")
    tf._lariasLeftTitle = title

    local padL, padR = 10, 10
    local colGap = 12
    local innerW = (UI.frameW - (Addon.UI.sectionInsetX * 2) - padL - padR)
    local colW = math.floor((innerW - colGap) / 2)
    tf._lariasPadL, tf._lariasPadR, tf._lariasColGap, tf._lariasColW = padL, padR, colGap, colW

    local leftCol = CreateFrame("Frame", nil, tf)
    leftCol:SetPoint("TOPLEFT", tf, "TOPLEFT", padL, -32)
    leftCol:SetSize(colW, UI.trackH - 40)
    tf._lariasLeftCol = leftCol

    local rightCol = CreateFrame("Frame", nil, tf)
    rightCol:SetPoint("TOPLEFT", leftCol, "TOPRIGHT", colGap, 0)
    rightCol:SetSize(colW, UI.trackH - 40)
    tf._lariasRightCol = rightCol

    local rightTitle = tf:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    rightTitle:SetPoint("TOPLEFT", tf, "TOPLEFT", padL + colW + colGap, -8)
    rightTitle:SetTextColor(THEME.header.r, THEME.header.g, THEME.header.b, THEME.header.a)
    rightTitle:SetText(L.TRACKING_CURRENCY_TITLE or "")
    tf._lariasRightTitle = rightTitle

    title:ClearAllPoints()
    title:SetPoint("TOP", leftCol, "TOP", 0, 24)
    title:SetWidth(colW)
    title:SetJustifyH("CENTER")

    rightTitle:ClearAllPoints()
    rightTitle:SetPoint("TOP", rightCol, "TOP", 0, 24)
    rightTitle:SetWidth(colW)
    rightTitle:SetJustifyH("CENTER")

    local function MakeLine(parent, y, template, justify)
        local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
        fs:SetWidth(colW)
        fs:SetJustifyH(justify or "LEFT")
        if fs.SetWordWrap then fs:SetWordWrap(false) end
        fs:SetTextColor(THEME.text.r, THEME.text.g, THEME.text.b, THEME.text.a)
        fs:SetText("")
        fs._lariasBaseY = y
        return fs
    end

    TrackingUI.left.line1 = MakeLine(leftCol,    0, "GameFontHighlightLarge", "CENTER")
    TrackingUI.left.line2 = MakeLine(leftCol,  -22, "GameFontHighlightSmall", "CENTER")
    TrackingUI.left.line3 = MakeLine(leftCol,  -38, "GameFontHighlightSmall", "CENTER")
    TrackingUI.left.line4 = MakeLine(leftCol,  -62, "GameFontHighlightLarge", "CENTER")
    TrackingUI.left.line5 = MakeLine(leftCol,  -84, "GameFontHighlightSmall", "CENTER")
    TrackingUI.left.line6 = MakeLine(leftCol, -100, "GameFontHighlightSmall", "CENTER")

    local function MakeUnderlineFor(fs)
        if not fs then return nil end
        local line = leftCol:CreateTexture(nil, "OVERLAY")
        line:SetColorTexture(THEME.textDim.r, THEME.textDim.g, THEME.textDim.b, 0.55)
        line:SetHeight(1)
        line:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -1)
        line:SetPoint("TOPRIGHT", fs, "BOTTOMRIGHT", 0, -1)
        return line
    end

    TrackingUI.left.raidUnderline = MakeUnderlineFor(TrackingUI.left.line1)
    TrackingUI.left.dungeonsUnderline = MakeUnderlineFor(TrackingUI.left.line4)

    local function MakeLinePair(parent, y, template)
        local row = CreateFrame("Frame", nil, parent)
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
        row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, y)
        row:SetHeight(16)
        row._lariasBaseY = y

        local label = row:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
        label:SetPoint("LEFT", row, "LEFT", 0, 0)
        label:SetJustifyH("LEFT")
        if label.SetWordWrap then label:SetWordWrap(false) end
        label:SetTextColor(THEME.text.r, THEME.text.g, THEME.text.b, THEME.text.a)
        label:SetText("")

        local value = row:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
        value:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        value:SetJustifyH("RIGHT")
        if value.SetWordWrap then value:SetWordWrap(false) end
        value:SetTextColor(THEME.text.r, THEME.text.g, THEME.text.b, THEME.text.a)
        value:SetText("")

        label:SetPoint("RIGHT", value, "LEFT", -6, 0)

        return { frame = row, label = label, value = value }
    end

    for i = 1, RIGHT_LINE_COUNT do
        TrackingUI.right["line" .. tostring(i)] = MakeLinePair(rightCol, -18 * (i - 1), "GameFontHighlight")
    end

    tf:SetShown((db.showGreatVault or db.showCurrency) and true or false)
    self._trackingFrame = tf

    trackingEventFrame = trackingEventFrame or CreateFrame("Frame")
    trackingEventFrame:UnregisterAllEvents()
    trackingEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    trackingEventFrame:RegisterEvent("WEEKLY_REWARDS_UPDATE")
    trackingEventFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
    trackingEventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
    trackingEventFrame:RegisterEvent("ITEM_DATA_LOAD_RESULT")
    trackingEventFrame:RegisterEvent("QUEST_TURNED_IN")
    SafeRegisterEvent(trackingEventFrame, "QUEST_LOG_UPDATE")
    SafeRegisterEvent(trackingEventFrame, "CATALYST_CHARGES_UPDATED")
    SafeRegisterEvent(trackingEventFrame, "CATALYST_UPDATE")
    SafeRegisterEvent(trackingEventFrame, "ITEM_INTERACTION_ITEM_SELECTION_UPDATED")
    trackingEventFrame:SetScript("OnEvent", function()
        if parentFrame and parentFrame:IsShown() then
            Addon:RequestTrackingUpdate()
        end
    end)

end

function Addon:ApplyTrackingPanelOptions()
    local tf = self._trackingFrame
    if not tf then return end

    local db = self:EnsureDB()
    local showGV = db.showGreatVault and true or false
    local showCur = db.showCurrency and true or false
    local wantPanel = showGV or showCur

    tf:SetShown(wantPanel)
    if not wantPanel then
        if self.ApplyScrollLayout then self:ApplyScrollLayout() end
        return
    end

    local leftCol = tf._lariasLeftCol
    local rightCol = tf._lariasRightCol
    local leftTitle = tf._lariasLeftTitle
    local rightTitle = tf._lariasRightTitle
    local padL = tonumber(tf._lariasPadL) or 10
    local colGap = tonumber(tf._lariasColGap) or 12

    SetShownIfChanged(leftCol, showGV)
    SetShownIfChanged(rightCol, showCur)
    SetShownIfChanged(leftTitle, showGV)
    SetShownIfChanged(rightTitle, showCur)

    if leftCol and leftCol.ClearAllPoints and leftCol.SetPoint then
        leftCol:ClearAllPoints()
    end
    if rightCol and rightCol.ClearAllPoints and rightCol.SetPoint then
        rightCol:ClearAllPoints()
    end

    if showGV and showCur then
        if leftCol then leftCol:SetPoint("TOPLEFT", tf, "TOPLEFT", padL, -32) end
        if rightCol and leftCol then rightCol:SetPoint("TOPLEFT", leftCol, "TOPRIGHT", colGap, 0) end
    elseif showGV then
        if leftCol then leftCol:SetPoint("TOP", tf, "TOP", 0, -32) end
    else
        if rightCol then rightCol:SetPoint("TOP", tf, "TOP", 0, -32) end
    end

    if showGV and leftTitle and leftCol then
        leftTitle:ClearAllPoints()
        leftTitle:SetPoint("TOP", leftCol, "TOP", 0, 24)
    end
    if showCur and rightTitle and rightCol then
        rightTitle:ClearAllPoints()
        rightTitle:SetPoint("TOP", rightCol, "TOP", 0, 24)
    end
end

function Addon:UpdateTracking()
    local db = self:EnsureDB()

    local wantPanel = (db.showGreatVault or db.showCurrency) and true or false

    if wantPanel and not self._trackingFrame then
        local main = _G["LariasWeeklyMidnightChecklistFrame"]
        if main then
            self:CreateTrackingPanel(main)
            self:ApplyScrollLayout()
        end
    end

    if self.ApplyTrackingPanelOptions then
        self:ApplyTrackingPanelOptions()
    end

    if not (wantPanel and self._trackingFrame and self._trackingFrame:IsShown()) then
        if self.ApplyScrollLayout then self:ApplyScrollLayout() end
        return
    end

    local gv = GetGreatVaultBlockLines()
    SetTextIfChanged(TrackingUI.left.line1, gv[1])
    SetTextIfChanged(TrackingUI.left.line2, gv[2])
    SetTextIfChanged(TrackingUI.left.line3, gv[3])
    SetTextIfChanged(TrackingUI.left.line4, gv[4])
    SetTextIfChanged(TrackingUI.left.line5, gv[5])
    SetTextIfChanged(TrackingUI.left.line6, gv[6])

    SetShownIfChanged(TrackingUI.left.line1, IsNonEmptyText(gv[1]))
    SetShownIfChanged(TrackingUI.left.line2, IsNonEmptyText(gv[2]))
    SetShownIfChanged(TrackingUI.left.line3, IsNonEmptyText(gv[3]))
    SetShownIfChanged(TrackingUI.left.line4, IsNonEmptyText(gv[4]))
    SetShownIfChanged(TrackingUI.left.line5, IsNonEmptyText(gv[5]))
    SetShownIfChanged(TrackingUI.left.line6, IsNonEmptyText(gv[6]))
    SetShownIfChanged(TrackingUI.left.raidUnderline, TrackingUI.left.line1 and TrackingUI.left.line1:IsShown())
    SetShownIfChanged(TrackingUI.left.dungeonsUnderline, TrackingUI.left.line4 and TrackingUI.left.line4:IsShown())

    local crests
    if type(TrackingUI.right.line1) == "table" then
        local profile = GetActiveTrackingProfile()
        GetCrestLines()
        local cache = profile and profile._crestCache
        local lbl = cache and cache.label or nil
        local val = cache and cache.value or nil
        local crestCount = (cache and tonumber(cache.count)) or 4

        local function SetRow(i, l, v)
            local row = TrackingUI.right["line" .. tostring(i)]
            if not (row and row.label and row.value) then return end
            l = l or ""
            v = v or ""
            SetTextIfChanged(row.label, l)
            SetTextIfChanged(row.value, v)
            local showRow = IsNonEmptyText(l) or IsNonEmptyText(v)
            SetShownIfChanged(row.frame or row.label, showRow)
        end

        for i = 1, crestCount do
            SetRow(i, lbl and lbl[i] or "", val and val[i] or "")
        end

        local idx = crestCount + 1
        local cLbl, cVal = GetCatalystParts()
        SetRow(idx, cLbl, cVal)

        idx = idx + 1
        local sLbl, sVal = GetSparksParts()
        SetRow(idx, sLbl, sVal)

        idx = idx + 1
        local bLbl, bVal = GetDelversBountyParts()
        SetRow(idx, bLbl, bVal)

        idx = idx + 1
        local pLbl, pVal = GetWeeklyPreyParts()
        SetRow(idx, pLbl, pVal)

        for i = idx + 1, RIGHT_LINE_COUNT do
            SetRow(i, "", "")
        end
    else
        crests = GetCrestLines()
        SetTextIfChanged(TrackingUI.right.line1, crests[1])
        SetTextIfChanged(TrackingUI.right.line2, crests[2])
        SetTextIfChanged(TrackingUI.right.line3, crests[3])
        SetTextIfChanged(TrackingUI.right.line4, crests[4])
        if TrackingUI.right.line5 then
            SetTextIfChanged(TrackingUI.right.line5, GetCatalystLine())
        end
        if TrackingUI.right.line6 then
            SetTextIfChanged(TrackingUI.right.line6, GetSparksLine())
        end
        if TrackingUI.right.line7 then
            local bLbl, bVal = GetDelversBountyParts()
            SetTextIfChanged(TrackingUI.right.line7, (bLbl or "") .. " " .. (bVal or ""))
        end
        if TrackingUI.right.line8 then
            local pLbl, pVal = GetWeeklyPreyParts()
            SetTextIfChanged(TrackingUI.right.line8, (pLbl or "") .. " " .. (pVal or ""))
        end

        SetShownIfChanged(TrackingUI.right.line1, IsNonEmptyText(crests[1]))
        SetShownIfChanged(TrackingUI.right.line2, IsNonEmptyText(crests[2]))
        SetShownIfChanged(TrackingUI.right.line3, IsNonEmptyText(crests[3]))
        SetShownIfChanged(TrackingUI.right.line4, IsNonEmptyText(crests[4]))
        if TrackingUI.right.line5 then SetShownIfChanged(TrackingUI.right.line5, IsNonEmptyText(TrackingUI.right.line5._lariasText or "")) end
        if TrackingUI.right.line6 then SetShownIfChanged(TrackingUI.right.line6, IsNonEmptyText(TrackingUI.right.line6._lariasText or "")) end
        if TrackingUI.right.line7 then SetShownIfChanged(TrackingUI.right.line7, IsNonEmptyText(TrackingUI.right.line7._lariasText or "")) end
        if TrackingUI.right.line8 then SetShownIfChanged(TrackingUI.right.line8, IsNonEmptyText(TrackingUI.right.line8._lariasText or "")) end
    end

    local tf = self._trackingFrame
    if tf and tf.GetHeight and tf.SetHeight then
        local bottomLeft = 0
        bottomLeft = max(bottomLeft, BottomFor(TrackingUI.left.line1))
        bottomLeft = max(bottomLeft, BottomFor(TrackingUI.left.line2))
        bottomLeft = max(bottomLeft, BottomFor(TrackingUI.left.line3))
        bottomLeft = max(bottomLeft, BottomFor(TrackingUI.left.line4))
        bottomLeft = max(bottomLeft, BottomFor(TrackingUI.left.line5))
        bottomLeft = max(bottomLeft, BottomFor(TrackingUI.left.line6))

        local bottomRight = 0
        for i = 1, RIGHT_LINE_COUNT do
            local row = TrackingUI.right["line" .. tostring(i)]
            if type(row) == "table" then
                bottomRight = max(bottomRight, BottomFor(row.frame or row.label))
            else
                bottomRight = max(bottomRight, BottomFor(row))
            end
        end

        local contentH = max(bottomLeft, bottomRight)
        local topOffset = 32
        local bottomPad = 10
        local minH = 90
        local targetH = max(minH, topOffset + contentH + bottomPad)

        local curH = tonumber(tf:GetHeight()) or 0
        if math.abs(curH - targetH) > 1 then
            tf:SetHeight(targetH)
            if tf._lariasLeftCol and tf._lariasLeftCol.SetHeight then
                tf._lariasLeftCol:SetHeight(max(1, targetH - 40))
            end
            if tf._lariasRightCol and tf._lariasRightCol.SetHeight then
                tf._lariasRightCol:SetHeight(max(1, targetH - 40))
            end
            if self.ApplyScrollLayout then
                self:ApplyScrollLayout()
            end
        end
    end
end

function Addon:SetTrackingVisible(show)
    local db = self:EnsureDB()
    local want = show and true or false
    db.showGreatVault = want
    db.showCurrency = want

    if (db.showGreatVault or db.showCurrency) and not self._trackingFrame then
        local main = _G["LariasWeeklyMidnightChecklistFrame"]
        if main then
            self:CreateTrackingPanel(main)
        end
    end

    if self._trackingFrame then
        self._trackingFrame:SetShown((db.showGreatVault or db.showCurrency) and true or false)
    end

    self:ApplyScrollLayout()
    if self.Refresh then self:Refresh() end
end

