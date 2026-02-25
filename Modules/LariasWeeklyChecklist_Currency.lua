-- Tracking / currency side-panel logic.
--
-- Design goals:
-- - Event-driven only (no per-frame updates)
-- - Throttled update funnel to avoid spam from rapid events
-- - Rows collapse cleanly when configured IDs are 0
-- - Crest display names are locale-driven
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

local function IsFrameShown(frameObj)
    -- Safe IsShown wrapper; treats missing frames as hidden.
    return frameObj and frameObj.IsShown and frameObj:IsShown()
end

local function Wipe(tableToWipe)
    -- nil-safe wipe compatible with both retail/classic.
    if not tableToWipe then return end
    if wipe then
        wipe(tableToWipe)
        return
    end
    for key in pairs(tableToWipe) do
        tableToWipe[key] = nil
    end
end

Addon.TRACKING = Addon.TRACKING or {}

local function SafeRegisterEvent(frame, eventName)
    -- Some events aren’t present on all client versions; register defensively.
    if not (frame and eventName) then return false end
    local ok = pcall(frame.RegisterEvent, frame, eventName)
    return ok
end

function Addon:ConfigureTrackingEvents(parentFrame, showGreatVault, showCurrency)
    -- Subscribe to the minimal event set needed for the tracking panel.
    -- We only schedule updates while the tracking UI is visible.
    trackingEventFrame = trackingEventFrame or CreateFrame("Frame")
    trackingEventFrame:UnregisterAllEvents()

    local shouldListen = (showGreatVault or showCurrency) and true or false
    if not shouldListen then return end

    -- Only respond while the UI is visible.
    trackingEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

    if showGreatVault then
        trackingEventFrame:RegisterEvent("WEEKLY_REWARDS_UPDATE")
        trackingEventFrame:RegisterEvent("ITEM_DATA_LOAD_RESULT")
    end

    if showCurrency then
        trackingEventFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
        trackingEventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
        trackingEventFrame:RegisterEvent("QUEST_TURNED_IN")
        SafeRegisterEvent(trackingEventFrame, "QUEST_LOG_UPDATE")
        SafeRegisterEvent(trackingEventFrame, "CATALYST_CHARGES_UPDATED")
        SafeRegisterEvent(trackingEventFrame, "CATALYST_UPDATE")
        SafeRegisterEvent(trackingEventFrame, "ITEM_INTERACTION_ITEM_SELECTION_UPDATED")
        trackingEventFrame:RegisterEvent("ITEM_DATA_LOAD_RESULT")
    end

    if not trackingEventFrame._lariasOnEventSet then
        trackingEventFrame._lariasOnEventSet = true
        trackingEventFrame:SetScript("OnEvent", function()
            local isMainFrameVisible = IsFrameShown(parentFrame)
            local isTrackingPanelVisible = IsFrameShown(Addon._trackingFrame)
            if isMainFrameVisible and isTrackingPanelVisible then
                -- Never run per-frame: we update on relevant events only,
                -- and then funnel through a throttle (see RequestTrackingUpdate).
                Addon:RequestTrackingUpdate()
            end
        end)
    end
end

function Addon:RequestTrackingUpdate()
    -- Lazily embed AceBucket-3.0 if available. Same defensive pattern as
    -- AceComm in Comms.lua: not embedded at NewAddon time to avoid crashing
    -- the main chunk when another addon's Ace3 build omits this library.
    if not self.RegisterBucketMessage then
        local aceBucket = LibStub and LibStub("AceBucket-3.0", true)
        if aceBucket then aceBucket:Embed(self) end
    end

    -- Throttle updates to run at most once every 0.2 seconds to prevent spam
    -- from rapid events like bag updates or currency changes.
    if self.RegisterBucketMessage and self.SendMessage then
        if not self._trackingUpdateBucketRegistered then
            self._trackingUpdateBucketRegistered = true
            self:RegisterBucketMessage("LWMC_TRACKING_UPDATE", 0.2, function()
                if Addon.UpdateTracking then
                    Addon:UpdateTracking()
                end
            end)
        end

        self:SendMessage("LWMC_TRACKING_UPDATE")
        return
    end

    -- Fallback if AceBucket isn't available.
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
        C_Timer.After(0.2, self._trackingUpdateRunner)
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

local function ColorWrap(hex, txt)
    -- Wrap a string in WoW color codes.
    return ("|c%s%s|r"):format(hex, tostring(txt or ""))
end

local function SetTextIfChanged(fontString, text)
    -- Avoid repeated SetText calls (triggers layout + renders).
    if not fontString then return end
    text = text or ""
    if fontString._lariasText ~= text then
        fontString._lariasText = text
        fontString:SetText(text)
    end
end

local function IsNonEmptyText(text)
    -- Treat color-coded strings with only whitespace as empty.
    if type(text) ~= "string" then return false end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return text:match("%S") ~= nil
end

local function SetShownIfChanged(region, shown)
    -- Avoid redundant Show/Hide calls.
    if not (region and region.IsShown and region.SetShown) then return end
    local want = shown and true or false
    if region:IsShown() ~= want then
        region:SetShown(want)
    end
end

local function IsMainFrameOnListTab()
    -- Tracking panel only shows on the main list tab.
    local main = _G and _G["LariasWeeklyChecklistFrame"]
    local selectedTab = main and tonumber(main._lariasSelectedTab)
    return (selectedTab == nil) or (selectedTab == 1)
end

local function FormatXY(currentAmount, maxAmount)
    -- Standard progress format with infinity fallback when there is no max.
    currentAmount = tonumber(currentAmount) or 0
    maxAmount = tonumber(maxAmount) or 0
    if maxAmount > 0 then return ("%d/%d"):format(currentAmount, maxAmount) end
    local infiniteString = L.TRACKING_INF
    if type(infiniteString) ~= "string" or infiniteString == "" then infiniteString = "∞" end
    return ("%d/%s"):format(currentAmount, infiniteString)
end

local function ColorForXY(currentAmount, maxAmount)
    -- Progress coloring: 0 => red, complete => green, otherwise yellow.
    currentAmount = tonumber(currentAmount) or 0
    maxAmount = tonumber(maxAmount) or 0
    if currentAmount <= 0 then return COLORS.red end
    if maxAmount > 0 and currentAmount >= maxAmount then return COLORS.green end
    return COLORS.yellow
end

local function IsAchievementCompleteSafe(achievementID)
    -- Achievement APIs vary across client versions; keep this resilient.
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
local RIGHT_ROW_KEYS = {}
for _i = 1, RIGHT_LINE_COUNT do RIGHT_ROW_KEYS[_i] = "line" .. _i end

local function GetCrestAchievementID(i)
    -- Crest achievement mapping is index-based (aligned with crestCurrencyIDs).
    local ach = Addon.TRACKING and Addon.TRACKING.crestAchievementIDs
    if type(ach) ~= "table" then return nil end

    if ach[1] ~= nil then
        -- Order is defined by the crestCurrencyIDs list; use index-based mapping.
        local idx = tonumber(i)
        return idx and ach[idx] or nil
    end

    -- Non-array tables are not supported for crestAchievementIDs; keep it explicit.
    return nil
end

local function FormatCurrencyProgressParts(currencyID)
    -- Returns (qty, cap) where cap is weekly max or total max.
    if not currencyID or not C_CurrencyInfo or not C_CurrencyInfo.GetCurrencyInfo then return nil end
    local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
    if not info then return nil end

    local qty = info.quantity or 0
    local weeklyMax = info.maxWeeklyQuantity
    local maxQty = info.maxQuantity

    if weeklyMax and weeklyMax > 0 then return qty, weeklyMax end
    if maxQty and maxQty > 0 then return qty, maxQty end
    return qty, 0
end

local function GetCrestLabelText(currencyID)
    -- Locale-driven crest name with stable fallbacks when untranslated/unknown.
    local idNum = tonumber(currencyID)
    local nameMap = L.TRACKING_CREST_NAMES_BY_ID
    if type(nameMap) == "table" then
        local name = nameMap[idNum or currencyID]
        if type(name) == "string" and name ~= "" then
            if name:sub(-1) == ":" then return name end
            return name .. ":"
        end
    end

    local fmt = L.TRACKING_CREST_ID_LABEL_FMT
    if type(fmt) == "string" and fmt ~= "" then
        local out = fmt:format(tostring(currencyID))
        if out:sub(-1) == ":" then return out end
        return out .. ":"
    end

    local base = L.TRACKING_CREST_LABEL
    if type(base) ~= "string" or base == "" then base = "Crest:" end
    if base:sub(-1) == ":" then
        return base .. " " .. tostring(currencyID) .. ":"
    end
    return base .. ": " .. tostring(currencyID) .. ":"
end

local function DetectCrestCurrencyIDsFromList()
    -- Fallback heuristic: scan the currency list for a localized substring.
    -- Used only if explicit IDs weren’t provided via constants.
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
    -- Compute bottom-most extent (in pixels) for a UI element with a base Y.
    if not obj then return 0 end
    if obj.IsShown and not IsFrameShown(obj) then return 0 end

    local y = tonumber(obj._lariasBaseY) or 0
    local h = 0
    if obj.GetStringHeight then h = tonumber(obj:GetStringHeight()) or 0 end
    if h <= 0 and obj.GetHeight then h = tonumber(obj:GetHeight()) or 0 end
    if h <= 0 then h = 16 end
    return abs(y) + h
end

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
    -- Use example reward links when we can’t determine ilvl from the reward table.
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
    if type(activity.isCompleted) == "boolean" then return activity.isCompleted end
    if type(activity.completed) == "boolean" then return activity.completed end
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

local GV_TYPE_MPLUS = (Enum and Enum.WeeklyRewardChestActivityType and Enum.WeeklyRewardChestActivityType.MythicPlus) or 1
local GV_TYPE_RAID  = (Enum and Enum.WeeklyRewardChestActivityType and Enum.WeeklyRewardChestActivityType.Raid) or 3
local function GetGreatVaultBlockLines()
    -- Returns 6 lines representing GV raid/dungeons blocks.
    -- Uses a reusable cache table to minimize allocations during throttled updates.
    local cache = Addon.TRACKING._gvCache
    if not cache then
        cache = {
            out = { "", "", "", "", "", "" },
            rIlvls = {},
            mIlvls = {},
            parts = {},
        }
        Addon.TRACKING._gvCache = cache
    end

    local out = cache.out
    out[1], out[2], out[3], out[4], out[5], out[6] = "", "", "", "", "", ""

    if not C_WeeklyRewards or not C_WeeklyRewards.GetActivities then
        out[1] = MakeGVHeader(L.TRACKING_GV_RAID or "Raid")
        out[2] = ColorWrap(COLORS.red, L.TRACKING_NA or "")
        out[4] = MakeGVHeader(L.TRACKING_GV_DUNGEONS or "Dungeons")
        out[5] = ColorWrap(COLORS.red, L.TRACKING_NA or "")
        return out
    end

    local activities = C_WeeklyRewards.GetActivities()
    if type(activities) ~= "table" then
        out[1] = MakeGVHeader(L.TRACKING_GV_RAID or "Raid")
        out[2] = ColorWrap(COLORS.red, L.TRACKING_NA or "")
        out[4] = MakeGVHeader(L.TRACKING_GV_DUNGEONS or "Dungeons")
        out[5] = ColorWrap(COLORS.red, L.TRACKING_NA or "")
        return out
    end

    local TYPE_MPLUS = GV_TYPE_MPLUS
    local TYPE_RAID  = GV_TYPE_RAID

    Wipe(cache.rIlvls)
    Wipe(cache.mIlvls)
    
    local raidTotal, raidComplete, raidMaxIlvl = 0, 0, 0
    local mythicTotal, mythicComplete, mythicMaxIlvl = 0, 0, 0
    local raidExampleMax, dungeonExampleMax = 0, 0

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
        end
    end

    local raidMax = (raidExampleMax > 0) and raidExampleMax or raidMaxIlvl
    local dungeonMax = (dungeonExampleMax > 0) and dungeonExampleMax or mythicMaxIlvl

    out[1] = MakeGVHeader(L.TRACKING_GV_RAID or "Raid")
    out[2] = (raidTotal > 0) and MakeGVThresholdsString(raidComplete, raidTotal, { 2, 4, 6 }, cache.parts) or ColorWrap(COLORS.red, L.TRACKING_NA or "")
    out[3] = (raidTotal > 0) and MakeGVIlvlsRow(cache.rIlvls, raidMax, cache.parts) or ""

    out[4] = MakeGVHeader(L.TRACKING_GV_DUNGEONS or "Dungeons")
    out[5] = (mythicTotal > 0) and MakeGVThresholdsString(mythicComplete, mythicTotal, { 1, 4, 8 }, cache.parts) or ColorWrap(COLORS.red, L.TRACKING_NA or "")
    out[6] = (mythicTotal > 0) and MakeGVIlvlsRow(cache.mIlvls, dungeonMax, cache.parts) or ""

    return out
end

-- Sparks row: currency progress with weekly/total cap semantics.
local function GetSparksParts()
    local id = Addon.TRACKING and Addon.TRACKING.sparkCurrencyID
    if not (id and tonumber(id) and tonumber(id) > 0) then
        -- Disabled/unconfigured.
        return "", ""
    end

    local label = ColorWrap(COLORS.dim, L.TRACKING_SPARKS_LABEL or "")
    local cur, c = FormatCurrencyProgressParts(id)
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

-- Tracking config lookup: resolve a quest ID from a key.
local function GetTrackedQuestID(key)
    local q = Addon.TRACKING and Addon.TRACKING.questIDs and Addon.TRACKING.questIDs[key]
    q = tonumber(q) or 0
    if q <= 0 then return nil end
    return q
end

-- Quest row: returns (label,value) as colored text based on completion.
local function GetQuestDoneParts(labelText, questKey, opts)
    local questID = GetTrackedQuestID(questKey)
    if not questID then
        -- Disabled/unconfigured.
        return "", ""
    end

    local label = ColorWrap(COLORS.dim, labelText)

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

-- Convenience wrappers for specific weekly quest rows.
local function GetDelversBountyParts()
    return GetQuestDoneParts(L.TRACKING_QUEST_DELVERS_BOUNTY or "", "delversBounty", { as01 = true })
end

local function GetWeeklyPreyParts()
    if not GetTrackedQuestID("weeklyPrey") then
        return "", ""
    end
    return GetQuestDoneParts(L.TRACKING_QUEST_WEEKLY_PREY or "", "weeklyPrey", { as01 = true })
end

-- Crest trade-up math depends on the configured batch sizes.
local function GetCrestTradeBatches(profile)
    local p = profile or Addon.TRACKING or {}
    local batch = p.crestTradeBatch
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

local function EnsureCrestIDsDetected(tracking)
    if tracking._crestIDsDetected then return end
    -- crestCurrencyIDs are always supplied by constants; mark as resolved.
    tracking._crestIDsDetected = true
end

local function GetCrestIDsAndCount(tracking)
    -- Crest currency IDs are expected to be an ordered list.
    local ids = tracking.crestCurrencyIDs or {}
    local crestCount
    if type(ids) == "table" and ids[1] ~= nil then
        crestCount = #ids
    else
        ids = {}
        crestCount = 0
    end

    if crestCount <= 0 then crestCount = 4 end
    return ids, crestCount
end

local function EnsureCrestCache(tracking, crestCount)
    -- We keep a cache on TRACKING for two reasons:
    -- 1) avoid allocating new tables every refresh (events can burst), and
    -- 2) allow UI update code to reference stable arrays for label/value.
    local cache = tracking._crestCache
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
        tracking._crestCache = cache
    end
    return cache
end

local function ResetCrestOutput(cache, crestCount)
    -- Zero output buffers without reallocating arrays.
    local out = cache.out
    local labelOut = cache.label
    local valueOut = cache.value
    for i = 1, crestCount do
        out[i] = ""
        labelOut[i] = ""
        valueOut[i] = ""
    end
    return out, labelOut, valueOut
end

local function PopulateCrestCurCap(cache, ids, crestCount)
    -- Populate raw crest currency quantities/caps.
    for i = 1, crestCount do
        local id = ids[i]
        if id then
            local cur, cap = FormatCurrencyProgressParts(id)
            cache.cur[i] = tonumber(cur) or 0
            cache.cap[i] = tonumber(cap) or 0
        else
            cache.cur[i] = 0
            cache.cap[i] = 0
        end
    end
end

local function PopulateCrestUnlocked(cache, crestCount)
    -- Populate unlock state using crest achievements.
    for i = 1, crestCount do
        local achievementID = GetCrestAchievementID(i)
        cache.unlocked[i] = achievementID and IsAchievementCompleteSafe(achievementID) or false
    end
end

local function ComputeCrestTradeup(cache, crestCount, batchLower, batchHigher)
    -- Compute trade-up from lower tiers into higher tiers based on unlocks.
    local highestTradeTarget
    for i = crestCount, 2, -1 do
        if cache.unlocked[i - 1] then
            highestTradeTarget = i
            break
        end
    end

    local effective = cache.effective
    local gained = cache.gained
    effective[1] = cache.cur[1] or 0
    gained[1] = 0
    for i = 2, crestCount do
        local prevAmt = tonumber(effective[i - 1]) or 0
        local tradeFromPrev = 0
        if cache.unlocked[i - 1] then
            tradeFromPrev = floor(prevAmt / batchLower) * batchHigher
        end
        gained[i] = tradeFromPrev
        effective[i] = (cache.cur[i] or 0) + tradeFromPrev
    end

    return highestTradeTarget, gained
end

local function GetCrestLines()
    -- Produces crest rows for the right column.
    -- Returns: combined lines, label-only lines, value-only lines, crestCount.
    local tracking = Addon.TRACKING
    if not tracking then return { "", "", "", "" } end

    EnsureCrestIDsDetected(tracking)
    local ids, crestCount = GetCrestIDsAndCount(tracking)
    local cache = EnsureCrestCache(tracking, crestCount)
    local out, labelOut, valueOut = ResetCrestOutput(cache, crestCount)

    local batchLower, batchHigher = GetCrestTradeBatches(tracking)
    local crest = cache

    PopulateCrestCurCap(crest, ids, crestCount)
    PopulateCrestUnlocked(crest, crestCount)
    local highestTradeTarget, gained = ComputeCrestTradeup(crest, crestCount, batchLower, batchHigher)
    local effective = crest.effective

    for i = 1, crestCount do
        local id = ids[i]
        if id then
            local labelText = GetCrestLabelText(id)
            if labelText then
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

                local lbl = ColorWrap(COLORS.dim, tostring(labelText)) .. tradeUp
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

    -- Return both combined "line" strings and the split label/value parts.
    -- The split form is used by the modern right-column layout (paired labels/values)
    -- and avoids callers reaching into the internal cache table directly.
    return out, labelOut, valueOut, crestCount
end

local function GetCatalystParts()
    -- Catalyst charges row.
    -- Hides entirely when no configured ID and C_Catalyst is unavailable.
    local cur, cap

    local id = Addon.TRACKING and Addon.TRACKING.catalystCurrencyID
    local hasConfiguredID = (id and tonumber(id) and tonumber(id) > 0) and true or false
    if hasConfiguredID then
        local qty, c = FormatCurrencyProgressParts(id)
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
        -- If no ID is configured and we couldn't detect via C_Catalyst, hide the row entirely.
        if not hasConfiguredID then
            return "", ""
        end

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

local function ComputeWantTrackingPanel(db)
    -- Decide whether the tracking panel should be shown at all.
    local wantPanel = (db.showGreatVault or db.showCurrency) and true or false
    if wantPanel and not IsMainFrameOnListTab() then
        wantPanel = false
    end
    return wantPanel
end

local function EnsureTrackingPanelCreatedIfNeeded(wantPanel)
    -- Lazily create the panel (only when needed and on the correct tab).
    if not wantPanel or Addon._trackingFrame then return end
    local main = _G["LariasWeeklyChecklistFrame"]
    if main then
        Addon:CreateTrackingPanel(main)
        Addon:ApplyScrollLayout()
    end
end

local function ApplyGreatVaultLines(lines)
    -- Write left column (Great Vault) lines and collapse empties.
    SetTextIfChanged(TrackingUI.left.line1, lines[1])
    SetTextIfChanged(TrackingUI.left.line2, lines[2])
    SetTextIfChanged(TrackingUI.left.line3, lines[3])
    SetTextIfChanged(TrackingUI.left.line4, lines[4])
    SetTextIfChanged(TrackingUI.left.line5, lines[5])
    SetTextIfChanged(TrackingUI.left.line6, lines[6])

    SetShownIfChanged(TrackingUI.left.line1, IsNonEmptyText(lines[1]))
    SetShownIfChanged(TrackingUI.left.line2, IsNonEmptyText(lines[2]))
    SetShownIfChanged(TrackingUI.left.line3, IsNonEmptyText(lines[3]))
    SetShownIfChanged(TrackingUI.left.line4, IsNonEmptyText(lines[4]))
    SetShownIfChanged(TrackingUI.left.line5, IsNonEmptyText(lines[5]))
    SetShownIfChanged(TrackingUI.left.line6, IsNonEmptyText(lines[6]))
    SetShownIfChanged(TrackingUI.left.raidUnderline, TrackingUI.left.line1 and TrackingUI.left.line1:IsShown())
    SetShownIfChanged(TrackingUI.left.dungeonsUnderline, TrackingUI.left.line4 and TrackingUI.left.line4:IsShown())
end

local function SetRightRowPair(i, rowLabel, rowValue)
    -- Write a {label,value} row and hide it if empty.
    local row = TrackingUI.right[RIGHT_ROW_KEYS[i]]
    if not (row and row.label and row.value) then return end
    rowLabel = rowLabel or ""
    rowValue = rowValue or ""
    SetTextIfChanged(row.label, rowLabel)
    SetTextIfChanged(row.value, rowValue)
    local showRow = IsNonEmptyText(rowLabel) or IsNonEmptyText(rowValue)
    SetShownIfChanged(row.frame or row.label, showRow)
end

local function ApplyRightColumnAsPairs()
    -- Modern layout: right column rows are {frame,label,value} pairs.
    -- We collapse empty rows so ID=0 or missing data doesn't leave vertical gaps.
    local _, labelLines, valueLines, crestCount = GetCrestLines()
    crestCount = tonumber(crestCount) or 4

    local idx = 1

    for i = 1, crestCount do
        if idx > RIGHT_LINE_COUNT then break end
        local rowLabel = (labelLines and labelLines[i]) or ""
        local rowValue = (valueLines and valueLines[i]) or ""
        if IsNonEmptyText(rowLabel) or IsNonEmptyText(rowValue) then
            SetRightRowPair(idx, rowLabel, rowValue)
            idx = idx + 1
        end
    end

    local cLbl, cVal = GetCatalystParts()
    cLbl = cLbl or ""; cVal = cVal or ""
    if idx <= RIGHT_LINE_COUNT and (IsNonEmptyText(cLbl) or IsNonEmptyText(cVal)) then
        SetRightRowPair(idx, cLbl, cVal); idx = idx + 1
    end

    local sLbl, sVal = GetSparksParts()
    sLbl = sLbl or ""; sVal = sVal or ""
    if idx <= RIGHT_LINE_COUNT and (IsNonEmptyText(sLbl) or IsNonEmptyText(sVal)) then
        SetRightRowPair(idx, sLbl, sVal); idx = idx + 1
    end

    local bLbl, bVal = GetDelversBountyParts()
    bLbl = bLbl or ""; bVal = bVal or ""
    if idx <= RIGHT_LINE_COUNT and (IsNonEmptyText(bLbl) or IsNonEmptyText(bVal)) then
        SetRightRowPair(idx, bLbl, bVal); idx = idx + 1
    end

    local pLbl, pVal = GetWeeklyPreyParts()
    pLbl = pLbl or ""; pVal = pVal or ""
    if idx <= RIGHT_LINE_COUNT and (IsNonEmptyText(pLbl) or IsNonEmptyText(pVal)) then
        SetRightRowPair(idx, pLbl, pVal); idx = idx + 1
    end

    for i = idx, RIGHT_LINE_COUNT do
        SetRightRowPair(i, "", "")
    end
end

local function ResizeTrackingPanelToContent(addon)
    -- Auto-size the tracking panel height to the actual visible content.
    local trackingFrame = addon._trackingFrame
    if not (trackingFrame and trackingFrame.GetHeight and trackingFrame.SetHeight) then return end

    local bottomLeft = 0
    bottomLeft = max(bottomLeft, BottomFor(TrackingUI.left.line1))
    bottomLeft = max(bottomLeft, BottomFor(TrackingUI.left.line2))
    bottomLeft = max(bottomLeft, BottomFor(TrackingUI.left.line3))
    bottomLeft = max(bottomLeft, BottomFor(TrackingUI.left.line4))
    bottomLeft = max(bottomLeft, BottomFor(TrackingUI.left.line5))
    bottomLeft = max(bottomLeft, BottomFor(TrackingUI.left.line6))

    local bottomRight = 0
    for i = 1, RIGHT_LINE_COUNT do
        local row = TrackingUI.right[RIGHT_ROW_KEYS[i]]
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

    local curH = tonumber(trackingFrame:GetHeight()) or 0
    if math.abs(curH - targetH) <= 1 then return end

    trackingFrame:SetHeight(targetH)
    if trackingFrame._lariasLeftCol and trackingFrame._lariasLeftCol.SetHeight then
        trackingFrame._lariasLeftCol:SetHeight(max(1, targetH - 40))
    end
    if trackingFrame._lariasRightCol and trackingFrame._lariasRightCol.SetHeight then
        trackingFrame._lariasRightCol:SetHeight(max(1, targetH - 40))
    end
    if addon.ApplyScrollLayout then
        addon:ApplyScrollLayout()
    end
end

function Addon:CreateTrackingPanel(parentFrame)
    -- Build the tracking panel UI (left: Great Vault, right: currency rows).
    if self._trackingFrame then return end
    local db = self:EnsureDB()

    local trackingFrame = CreateFrame("Frame", nil, parentFrame)
    if not trackingFrame.SetBackdrop and BackdropTemplateMixin and Mixin then
        Mixin(trackingFrame, BackdropTemplateMixin)
    end
    trackingFrame:SetPoint("BOTTOMLEFT", parentFrame, "BOTTOMLEFT", Addon.UI.sectionInsetX, UI.scrollBottom)
    trackingFrame:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", -Addon.UI.sectionInsetX, UI.scrollBottom)
    trackingFrame:SetHeight(UI.trackH)
    self:ApplyTheme(trackingFrame)

    local title = trackingFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", trackingFrame, "TOPLEFT", 10, -8)
    title:SetTextColor(THEME.header.r, THEME.header.g, THEME.header.b, THEME.header.a)
    title:SetText(L.TRACKING_GREAT_VAULT_TITLE or "Great Vault")
    trackingFrame._lariasLeftTitle = title

    local padL, padR = 10, 10
    local colGap = 12
    local innerW = (UI.frameW - (Addon.UI.sectionInsetX * 2) - padL - padR)
    local colW = math.floor((innerW - colGap) / 2)
    trackingFrame._lariasPadL, trackingFrame._lariasPadR, trackingFrame._lariasColGap, trackingFrame._lariasColW = padL, padR, colGap, colW

    local leftCol = CreateFrame("Frame", nil, trackingFrame)
    leftCol:SetPoint("TOPLEFT", trackingFrame, "TOPLEFT", padL, -32)
    leftCol:SetSize(colW, UI.trackH - 40)
    trackingFrame._lariasLeftCol = leftCol

    local rightCol = CreateFrame("Frame", nil, trackingFrame)
    rightCol:SetPoint("TOPLEFT", leftCol, "TOPRIGHT", colGap, 0)
    rightCol:SetSize(colW, UI.trackH - 40)
    trackingFrame._lariasRightCol = rightCol

    local rightTitle = trackingFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    rightTitle:SetPoint("TOPLEFT", trackingFrame, "TOPLEFT", padL + colW + colGap, -8)
    rightTitle:SetTextColor(THEME.header.r, THEME.header.g, THEME.header.b, THEME.header.a)
    rightTitle:SetText(L.TRACKING_CURRENCY_TITLE or "Currency")
    trackingFrame._lariasRightTitle = rightTitle

    title:ClearAllPoints()
    title:SetPoint("TOP", leftCol, "TOP", 0, 24)
    title:SetWidth(colW)
    title:SetJustifyH("CENTER")

    rightTitle:ClearAllPoints()
    rightTitle:SetPoint("TOP", rightCol, "TOP", 0, 24)
    rightTitle:SetWidth(colW)
    rightTitle:SetJustifyH("CENTER")

    local function MakeLine(parent, y, template, justify)
        local fontString = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
        fontString:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
        fontString:SetWidth(colW)
        fontString:SetJustifyH(justify or "LEFT")
        if fontString.SetWordWrap then fontString:SetWordWrap(false) end
        fontString:SetTextColor(THEME.text.r, THEME.text.g, THEME.text.b, THEME.text.a)
        fontString:SetText("")
        fontString._lariasBaseY = y
        return fontString
    end

    TrackingUI.left.line1 = MakeLine(leftCol,    0, "GameFontHighlightLarge", "CENTER")
    TrackingUI.left.line2 = MakeLine(leftCol,  -22, "GameFontHighlightSmall", "CENTER")
    TrackingUI.left.line3 = MakeLine(leftCol,  -38, "GameFontHighlightSmall", "CENTER")
    TrackingUI.left.line4 = MakeLine(leftCol,  -62, "GameFontHighlightLarge", "CENTER")
    TrackingUI.left.line5 = MakeLine(leftCol,  -84, "GameFontHighlightSmall", "CENTER")
    TrackingUI.left.line6 = MakeLine(leftCol, -100, "GameFontHighlightSmall", "CENTER")

    local function MakeUnderlineFor(fontString)
        if not fontString then return nil end
        local line = leftCol:CreateTexture(nil, "OVERLAY")
        line:SetColorTexture(THEME.textDim.r, THEME.textDim.g, THEME.textDim.b, 0.55)
        line:SetHeight(1)
        line:SetPoint("TOPLEFT", fontString, "BOTTOMLEFT", 0, -1)
        line:SetPoint("TOPRIGHT", fontString, "BOTTOMRIGHT", 0, -1)
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

    trackingFrame:SetShown((db.showGreatVault or db.showCurrency) and IsMainFrameOnListTab())
    self._trackingFrame = trackingFrame

    if trackingFrame.SetScript then
        trackingFrame:SetScript("OnShow", function()
            local database = Addon:EnsureDB()
            Addon:ConfigureTrackingEvents(parentFrame, database.showGreatVault and true or false, database.showCurrency and true or false)
            Addon:RequestTrackingUpdate()
        end)
        trackingFrame:SetScript("OnHide", function()
            if trackingEventFrame then
                trackingEventFrame:UnregisterAllEvents()
            end
        end)
    end

    self:ConfigureTrackingEvents(parentFrame, db.showGreatVault and true or false, db.showCurrency and true or false)

end

function Addon:ApplyTrackingPanelOptions()
    -- Re-layout / show/hide columns when options change.
    local trackingFrame = self._trackingFrame
    if not trackingFrame then return end

    local db = self:EnsureDB()
    local showGreatVault = db.showGreatVault and true or false
    local showCurrency = db.showCurrency and true or false
    local wantPanel = (showGreatVault or showCurrency) and IsMainFrameOnListTab()

    trackingFrame:SetShown(wantPanel)
    if not wantPanel then
        if trackingEventFrame then
            trackingEventFrame:UnregisterAllEvents()
        end
        if self.ApplyScrollLayout then self:ApplyScrollLayout() end
        return
    end

    self:ConfigureTrackingEvents(_G["LariasWeeklyChecklistFrame"], showGreatVault, showCurrency)

    local leftCol = trackingFrame._lariasLeftCol
    local rightCol = trackingFrame._lariasRightCol
    local leftTitle = trackingFrame._lariasLeftTitle
    local rightTitle = trackingFrame._lariasRightTitle
    local padL = tonumber(trackingFrame._lariasPadL) or 10
    local colGap = tonumber(trackingFrame._lariasColGap) or 12

    SetShownIfChanged(leftCol, showGreatVault)
    SetShownIfChanged(rightCol, showCurrency)
    SetShownIfChanged(leftTitle, showGreatVault)
    SetShownIfChanged(rightTitle, showCurrency)

    if leftCol and leftCol.ClearAllPoints and leftCol.SetPoint then
        leftCol:ClearAllPoints()
    end
    if rightCol and rightCol.ClearAllPoints and rightCol.SetPoint then
        rightCol:ClearAllPoints()
    end

    if showGreatVault and showCurrency then
        if leftCol then leftCol:SetPoint("TOPLEFT", trackingFrame, "TOPLEFT", padL, -32) end
        if rightCol and leftCol then rightCol:SetPoint("TOPLEFT", leftCol, "TOPRIGHT", colGap, 0) end
    elseif showGreatVault then
        if leftCol then leftCol:SetPoint("TOP", trackingFrame, "TOP", 0, -32) end
    else
        if rightCol then rightCol:SetPoint("TOP", trackingFrame, "TOP", 0, -32) end
    end

    if showGreatVault and leftTitle and leftCol then
        leftTitle:ClearAllPoints()
        leftTitle:SetPoint("TOP", leftCol, "TOP", 0, 24)
    end
    if showCurrency and rightTitle and rightCol then
        rightTitle:ClearAllPoints()
        rightTitle:SetPoint("TOP", rightCol, "TOP", 0, 24)
    end

    -- Scroll frame must be re-anchored whenever the panel is shown/resized.
    if self.ApplyScrollLayout then self:ApplyScrollLayout() end
end

function Addon:UpdateTracking()
    -- Main throttled entry point: reconcile desired visibility, then render content.
    local db = self:EnsureDB()

    local wantPanel = ComputeWantTrackingPanel(db)
    EnsureTrackingPanelCreatedIfNeeded(wantPanel)

    if self.ApplyTrackingPanelOptions then
        self:ApplyTrackingPanelOptions()
    end

    if not (wantPanel and self._trackingFrame and self._trackingFrame:IsShown()) then
        if self.ApplyScrollLayout then self:ApplyScrollLayout() end
        return
    end

    ApplyGreatVaultLines(GetGreatVaultBlockLines())

    ApplyRightColumnAsPairs()

    ResizeTrackingPanelToContent(self)
end


