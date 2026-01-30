-- Currency.lua
local addonName = ...
local Addon = _G[addonName]
if not Addon then return end

if Addon.InitConstants then
    Addon:InitConstants(addonName)
end

local THEME = Addon.THEME
local UI = Addon.UI

local trackingEventFrame
local TrackingUI = { left = {}, right = {} }

-- Localize globals for hot paths
local tonumber, tostring, type = tonumber, tostring, type
local floor, max = math.floor, math.max
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

-- Set true temporarily to confirm this file is loading
local DEBUG = false
local function D(msg)
    if DEBUG then
        print("|cff00ff00[LariasCurrency]|r " .. tostring(msg))
    end
end

Addon.TRACKING = Addon.TRACKING or {}

local function SafeRegisterEvent(frame, eventName)
    if not (frame and eventName) then return false end
    -- WoW hard-errors when registering an unknown event name; swallow that.
    local ok = pcall(frame.RegisterEvent, frame, eventName)
    return ok and true or false
end

function Addon:RequestTrackingUpdate()
    -- Coalesce frequent events into a single update.
    if self._trackingUpdatePending then return end
    self._trackingUpdatePending = true

    local function run()
        self._trackingUpdatePending = nil
        if self.UpdateTracking then
            self:UpdateTracking()
        end
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0, run)
    else
        run()
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

local function FormatXY(cur, cap)
    cur = tonumber(cur) or 0
    cap = tonumber(cap) or 0
    if cap > 0 then return ("%d/%d"):format(cur, cap) end
    return ("%d/INF"):format(cur)
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

local _crestOrderKeysByIndex = { "weathered", "carved", "runed", "gilded" }
local _crestDisplayNamesByIndex = {
    "Weathered",
    "Carved",
    "Runed",
    "Gilded",
}

local function GetCrestAchievementID(i, crestName)
    local ach = Addon.TRACKING and Addon.TRACKING.crestAchievementIDs
    if type(ach) ~= "table" then return nil end

    if crestName and crestName ~= "" then
        local n = tostring(crestName):lower()
        if n:find("weathered", 1, true) then return ach.weathered end
        if n:find("carved", 1, true) then return ach.carved end
        if n:find("runed", 1, true) then return ach.runed end
        if n:find("gilded", 1, true) then return ach.gilded end
    end

    local key = _crestOrderKeysByIndex[tonumber(i) or 0]
    return key and ach[key] or nil
end

local function FormatCurrencyProgressParts(currencyID)
    if not currencyID or not C_CurrencyInfo or not C_CurrencyInfo.GetCurrencyInfo then return nil end
    local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
    if not info then return nil end

    local name = info.name or ("Currency " .. tostring(currencyID))
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
            if name ~= "" then
                local lower = name:lower()
                -- TWW crests: typically include "Harbinger Crest"; keep it broad but Crest-specific.
                if lower:find("crest", 1, true) then
                    local link = C_CurrencyInfo.GetCurrencyListLink(i)
                    local id = link and tonumber(tostring(link):match("currency:(%d+)"))
                    if id then
                        found[#found + 1] = { id = id, name = name }
                    end
                end
            end
        end
    end

    if #found < 4 then return nil end

    local order = {
        weathered = 1,
        carved = 2,
        runed = 3,
        gilded = 4,
    }

    tsort(found, function(a, b)
        local al = strlower(tostring(a.name or ""))
        local bl = strlower(tostring(b.name or ""))

        local ao = 99
        for k, v in pairs(order) do
            if strfind(al, k, 1, true) then ao = v break end
        end
        local bo = 99
        for k, v in pairs(order) do
            if strfind(bl, k, 1, true) then bo = v break end
        end

        if ao ~= bo then return ao < bo end
        return al < bl
    end)

    local ids = {}
    for i = 1, 4 do
        ids[i] = found[i].id
    end
    return ids
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
            -- Some builds provide itemLevel directly.
            local directIlvl = tonumber(rewardInfo.itemLevel)
            if directIlvl and directIlvl > 0 then return directIlvl end

            -- Prefer an already-provided link if present.
            local link = rewardInfo.itemLink or rewardInfo.itemHyperlink or rewardInfo.hyperlink

            -- Otherwise try to resolve via DBID.
            if (not link) and canWeeklyLink and rewardInfo.itemDBID then
                link = C_WeeklyRewards.GetItemHyperlink(rewardInfo.itemDBID)
            end

            -- Otherwise try to resolve via itemID.
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
    -- Newer builds sometimes expose booleans directly.
    if type(a.isComplete) == "boolean" then return a.isComplete end
    if type(a.isCompleted) == "boolean" then return a.isCompleted end
    if type(a.completed) == "boolean" then return a.completed end

    -- Progress may be numeric or a table depending on API shape.
    local prog = a.progress
    local thr = a.threshold

    if type(prog) == "table" then
        -- Try common shapes: {progress=, threshold=} or {current=, required=}.
        thr = thr or prog.threshold or prog.required or prog.total
        prog = prog.progress or prog.current or prog.value
    end

    local progNum = tonumber(prog) or 0
    local thrNum  = tonumber(thr) or 0
    if thrNum > 0 then return progNum >= thrNum end

    -- Fallback: some shapes only expose a max/required field.
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

local function MakeGVHeader(label, complete, total)
    local c = ColorForGVProgress(complete, total)
    return ColorWrap(COLORS.dim, label .. ": ") .. ColorWrap(c, ("%d/%d"):format(complete, total))
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
            parts[#parts + 1] = ColorWrap(COLORS.dim, "N/A")
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
        out[1] = ColorWrap(COLORS.dim, "Raid: ") .. ColorWrap(COLORS.red, "N/A")
        out[3] = ColorWrap(COLORS.dim, "Dungeons: ") .. ColorWrap(COLORS.red, "N/A")
        out[5] = ColorWrap(COLORS.dim, "World: ") .. ColorWrap(COLORS.red, "N/A")
        return out
    end

    local activities = C_WeeklyRewards.GetActivities()
    if type(activities) ~= "table" then
        out[1] = ColorWrap(COLORS.dim, "Raid: ") .. ColorWrap(COLORS.red, "N/A")
        out[3] = ColorWrap(COLORS.dim, "Dungeons: ") .. ColorWrap(COLORS.red, "N/A")
        out[5] = ColorWrap(COLORS.dim, "World: ") .. ColorWrap(COLORS.red, "N/A")
        return out
    end

    -- Use Blizzard enums when available, otherwise fall back to historical numeric IDs.
    local TYPE_MPLUS = (Enum and Enum.WeeklyRewardChestActivityType and Enum.WeeklyRewardChestActivityType.MythicPlus) or 1
    local TYPE_RAID  = (Enum and Enum.WeeklyRewardChestActivityType and Enum.WeeklyRewardChestActivityType.Raid) or 3

    local rC, rT, rMax = SummarizeVaultType(activities, TYPE_RAID, cache.rIlvls)
    local mC, mT, mMax = SummarizeVaultType(activities, TYPE_MPLUS, cache.mIlvls)
    -- “World” varies by expansion (world/PvP/delves). Treat it as “everything else”.
    local excluded = cache.excluded
    if cache.lastRaidType then excluded[cache.lastRaidType] = nil end
    if cache.lastMplusType then excluded[cache.lastMplusType] = nil end
    excluded[TYPE_RAID] = true
    excluded[TYPE_MPLUS] = true
    cache.lastRaidType = TYPE_RAID
    cache.lastMplusType = TYPE_MPLUS

    local wC, wT, wMax = SummarizeVaultOther(activities, excluded, cache.wIlvls)

    -- Determine the maximum *possible* reward ilvl per category by inspecting example rewards.
    -- (This is more accurate than using the max of only-completed activities.)
    local raidExampleMax, dungeonExampleMax, worldExampleMax = 0, 0, 0
    for idx = 1, #activities do
        local a = activities[idx]
        local t = a and a.type
        if a and t then
            if t == TYPE_RAID then
                raidExampleMax = max(raidExampleMax, GetExampleRewardIlvlForActivity(a))
            elseif t == TYPE_MPLUS then
                dungeonExampleMax = max(dungeonExampleMax, GetExampleRewardIlvlForActivity(a))
            elseif not excluded[t] then
                worldExampleMax = max(worldExampleMax, GetExampleRewardIlvlForActivity(a))
            end
        end
    end

    local raidMax = (raidExampleMax > 0) and raidExampleMax or rMax
    local dungeonMax = (dungeonExampleMax > 0) and dungeonExampleMax or mMax
    local worldMax = (worldExampleMax > 0) and worldExampleMax or wMax

    out[1] = MakeGVHeader("Raid", rC, rT)
    out[2] = (rT > 0) and MakeGVIlvlsRow(cache.rIlvls, raidMax, cache.parts) or ""

    out[3] = MakeGVHeader("Dungeons", mC, mT)
    out[4] = (mT > 0) and MakeGVIlvlsRow(cache.mIlvls, dungeonMax, cache.parts) or ""

    out[5] = MakeGVHeader("World", wC, wT)
    out[6] = (wT > 0) and MakeGVIlvlsRow(cache.wIlvls, worldMax, cache.parts) or ""

    return out
end

local function GetSparksParts()
    local label = ColorWrap(COLORS.dim, "Sparks:")
    if Addon.TRACKING.sparkCurrencyID then
        local _, cur, c = FormatCurrencyProgressParts(Addon.TRACKING.sparkCurrencyID)
        cur = cur or 0
        c = tonumber(c) or 0

        local xy
        local color
        if c > 0 then
            xy = FormatXY(cur, c)
            color = ColorForXY(cur, c)
        else
            -- If the currency doesn't report a cap, treat as unlocked and show INF.
            xy = ("%d/INF"):format(tonumber(cur) or 0)
            color = ((tonumber(cur) or 0) <= 0) and COLORS.red or COLORS.yellow
        end
        return label, ColorWrap(color, xy)
    end

    return label, ColorWrap(COLORS.red, "N/A")
end

local function GetSparksLine()
    local label, value = GetSparksParts()
    return label .. " " .. (value or "")
end

local function GetCrestLines()
    -- Auto-detect crest IDs (TWW changed currency IDs vs older expansions).
    if not Addon.TRACKING._crestIDsDetected then
        local detected = DetectCrestCurrencyIDsFromList()
        if detected then
            Addon.TRACKING.crestCurrencyIDs = detected
        end
        Addon.TRACKING._crestIDsDetected = true
    end

    local ids = Addon.TRACKING.crestCurrencyIDs or {}
    -- Support both array-form ({id1,id2,id3,id4}) and keyed form ({weathered=...,carved=...,...}).
    if type(ids) == "table" and ids[1] == nil and (ids.weathered or ids.carved or ids.runed or ids.gilded) then
        ids = { ids.weathered, ids.carved, ids.runed, ids.gilded }
    end
    local cache = Addon.TRACKING._crestCache
    if not cache then
        cache = {
            out = { "", "", "", "" },
            label = { "", "", "", "" },
            value = { "", "", "", "" },
            name = { nil, nil, nil, nil },
            cur = { 0, 0, 0, 0 },
            cap = { 0, 0, 0, 0 },
            unlocked = { false, false, false, false },
            effective = { 0, 0, 0, 0 },
            gained = { 0, 0, 0, 0 },
        }
        Addon.TRACKING._crestCache = cache
    end

    local out = cache.out
    out[1], out[2], out[3], out[4] = "", "", "", ""
    local labelOut = cache.label
    local valueOut = cache.value
    labelOut[1], labelOut[2], labelOut[3], labelOut[4] = "", "", "", ""
    valueOut[1], valueOut[2], valueOut[3], valueOut[4] = "", "", "", ""

    local ratio = 3
    local batchLower = 45 -- can only trade up in batches of 45 lower crests
    local batchHigher = floor(batchLower / ratio) -- e.g. 45 weathered -> 15 carved
    local crest = cache

    for i = 1, 4 do
        local id = ids[i]
        if id then
            local name, cur, cap = FormatCurrencyProgressParts(id)
            crest.name[i] = _crestDisplayNamesByIndex[i] or name
            crest.cur[i] = tonumber(cur) or 0
            crest.cap[i] = tonumber(cap) or 0
        else
            crest.name[i] = nil
            crest.cur[i] = 0
            crest.cap[i] = 0
        end
    end

    for i = 1, 4 do
        local achievementID = GetCrestAchievementID(i, crest.name[i])
        crest.unlocked[i] = achievementID and IsAchievementCompleteSafe(achievementID) or false
    end

    local highestTradeTarget
    for i = 4, 2, -1 do
        if crest.unlocked[i - 1] then
            highestTradeTarget = i
            break
        end
    end

    -- Effective totals if you trade up everything possible from lower tiers.
    -- Example: runed total includes carved total, which includes weathered total.
    local effective = crest.effective
    local gained = crest.gained
    effective[1] = crest.cur[1] or 0
    gained[1] = 0
    for i = 2, 4 do
        local prevAmt = tonumber(effective[i - 1]) or 0
        local tradeFromPrev = 0
        if crest.unlocked[i - 1] then
            -- Trade-up is only possible in fixed batches.
            tradeFromPrev = floor(prevAmt / batchLower) * batchHigher
        end
        gained[i] = tradeFromPrev
        effective[i] = (crest.cur[i] or 0) + tradeFromPrev
    end

    for i = 1, 4 do
        local id = ids[i]
        if id then
            local name = crest.name[i]
            if name then
                local cur = crest.cur[i]
                local cap = crest.cap[i]

                local forceGreen = crest.unlocked[i] or false

                local xy
                local color
                if cap > 0 then
                    xy = FormatXY(cur, cap)
                    color = forceGreen and COLORS.green or ColorForXY(cur, cap)
                else
                    -- If no cap is returned by the API, treat as unlocked and show INF.
                    xy = ("%d/INF"):format(cur)
                    -- No cap typically means Blizzard has unlocked the crest cap.
                    color = forceGreen and COLORS.green or ((cur <= 0) and COLORS.red or COLORS.green)
                end

                local tradeUp = ""
                if highestTradeTarget and i == highestTradeTarget then
                    local n = tonumber(gained[i]) or 0
                    if n > 0 then
                        tradeUp = ColorWrap(COLORS.dim, " (")
                            .. ColorWrap("ff4da6ff", "+" .. tostring(n))
                            .. ColorWrap(COLORS.dim, " Trade Up)")
                    end
                end

                local lbl = ColorWrap(COLORS.dim, name .. ":") .. tradeUp
                local val = ColorWrap(color, xy)
                labelOut[i] = lbl
                valueOut[i] = val
                out[i] = lbl .. " " .. val
            else
                local lbl = ColorWrap(COLORS.dim, ("Crest %s:"):format(tostring(id)))
                local val = ColorWrap(COLORS.red, "N/A")
                labelOut[i] = lbl
                valueOut[i] = val
                out[i] = lbl .. " " .. val
            end
        else
            local lbl = ColorWrap(COLORS.dim, "Crest:")
            local val = ColorWrap(COLORS.red, "No ID")
            labelOut[i] = lbl
            valueOut[i] = val
            out[i] = lbl .. " " .. val
        end
    end

    return out
end

local function GetCatalystParts()
    -- Catalyst charges (TWW provides a currency for this: 3269).
    local cur, cap

    if Addon.TRACKING and Addon.TRACKING.catalystCurrencyID then
        local _, qty, c = FormatCurrencyProgressParts(Addon.TRACKING.catalystCurrencyID)
        cur = tonumber(qty)
        cap = tonumber(c)
    end

    -- Fallback to C_Catalyst API if the currency isn't available.
    if (cur == nil) and C_Catalyst then
        -- TWW: typically returns a table from GetCharges().
        if C_Catalyst.GetCharges then
            local charges = C_Catalyst.GetCharges()
            if type(charges) == "table" then
                cur = charges.currentCharges or charges.numCharges or charges.charges
                cap = charges.maxCharges or charges.maximumCharges
            end
        end

        -- Fallbacks for builds that expose scalar getters.
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
        return ColorWrap(COLORS.dim, "Catalyst:"), ColorWrap(COLORS.red, "N/A")
    end

    if cap and cap > 0 then
        local xy = FormatXY(cur, cap)
        local color = ColorForXY(cur, cap)
        return ColorWrap(COLORS.dim, "Catalyst:"), ColorWrap(color, xy)
    end

    local color = (cur <= 0) and COLORS.red or COLORS.yellow
    return ColorWrap(COLORS.dim, "Catalyst:"), ColorWrap(color, ("%d"):format(cur))
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
    title:SetText("Great Vault")

    local padL, padR = 10, 10
    local colGap = 12
    local innerW = (UI.frameW - (Addon.UI.sectionInsetX * 2) - padL - padR)
    local colW = math.floor((innerW - colGap) / 2)

    local leftCol = CreateFrame("Frame", nil, tf)
    leftCol:SetPoint("TOPLEFT", tf, "TOPLEFT", padL, -32)
    leftCol:SetSize(colW, UI.trackH - 40)

    local rightCol = CreateFrame("Frame", nil, tf)
    rightCol:SetPoint("TOPLEFT", leftCol, "TOPRIGHT", colGap, 0)
    rightCol:SetSize(colW, UI.trackH - 40)

    local rightTitle = tf:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    rightTitle:SetPoint("TOPLEFT", tf, "TOPLEFT", padL + colW + colGap, -8)
    rightTitle:SetTextColor(THEME.header.r, THEME.header.g, THEME.header.b, THEME.header.a)
    rightTitle:SetText("Currency")

    local function MakeLine(parent, y, template)
        local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
        fs:SetWidth(colW)
        fs:SetJustifyH("LEFT")
        if fs.SetWordWrap then fs:SetWordWrap(false) end
        fs:SetTextColor(THEME.text.r, THEME.text.g, THEME.text.b, THEME.text.a)
        fs:SetText("")
        return fs
    end

    TrackingUI.left.line1 = MakeLine(leftCol,   0, "GameFontHighlight")
    TrackingUI.left.line2 = MakeLine(leftCol, -16, "GameFontHighlightSmall")
    TrackingUI.left.line3 = MakeLine(leftCol, -36, "GameFontHighlight")
    TrackingUI.left.line4 = MakeLine(leftCol, -52, "GameFontHighlightSmall")
    TrackingUI.left.line5 = MakeLine(leftCol, -72, "GameFontHighlight")
    TrackingUI.left.line6 = MakeLine(leftCol, -88, "GameFontHighlightSmall")
    TrackingUI.left.line7 = MakeLine(leftCol, -112, "GameFontHighlight")

    local function MakeLinePair(parent, y, template)
        local row = CreateFrame("Frame", nil, parent)
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
        row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, y)
        row:SetHeight(16)

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

        return { label = label, value = value }
    end

    TrackingUI.right.line1 = MakeLinePair(rightCol,  0, "GameFontHighlight")
    TrackingUI.right.line2 = MakeLinePair(rightCol, -18, "GameFontHighlight")
    TrackingUI.right.line3 = MakeLinePair(rightCol, -36, "GameFontHighlight")
    TrackingUI.right.line4 = MakeLinePair(rightCol, -54, "GameFontHighlight")
    TrackingUI.right.line5 = MakeLinePair(rightCol, -72, "GameFontHighlight")
    TrackingUI.right.line6 = MakeLinePair(rightCol, -90, "GameFontHighlight")

    tf:SetShown(db.showCurrency)
    self._trackingFrame = tf

    trackingEventFrame = trackingEventFrame or CreateFrame("Frame")
    trackingEventFrame:UnregisterAllEvents()
    trackingEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    trackingEventFrame:RegisterEvent("WEEKLY_REWARDS_UPDATE")
    trackingEventFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
    trackingEventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
    trackingEventFrame:RegisterEvent("ITEM_DATA_LOAD_RESULT")
    -- Catalyst events vary; register defensively (unknown events would otherwise error).
    SafeRegisterEvent(trackingEventFrame, "CATALYST_CHARGES_UPDATED")
    SafeRegisterEvent(trackingEventFrame, "CATALYST_UPDATE")
    SafeRegisterEvent(trackingEventFrame, "ITEM_INTERACTION_ITEM_SELECTION_UPDATED")
    trackingEventFrame:SetScript("OnEvent", function()
        if parentFrame and parentFrame:IsShown() then
            Addon:RequestTrackingUpdate()
        end
    end)

    D("Tracking panel created")
end

function Addon:UpdateTracking()
    local db = self:EnsureDB()

    -- If user wants currency visible, ensure panel exists
    if db.showCurrency and not self._trackingFrame then
        local main = _G["LariasWeeklyMidnightChecklistFrame"]
        if main then
            self:CreateTrackingPanel(main)
            self:ApplyScrollLayout()
        end
    end

    if not (db.showCurrency and self._trackingFrame and self._trackingFrame:IsShown()) then return end

    local gv = GetGreatVaultBlockLines()
    SetTextIfChanged(TrackingUI.left.line1, gv[1])
    SetTextIfChanged(TrackingUI.left.line2, gv[2])
    SetTextIfChanged(TrackingUI.left.line3, gv[3])
    SetTextIfChanged(TrackingUI.left.line4, gv[4])
    SetTextIfChanged(TrackingUI.left.line5, gv[5])
    SetTextIfChanged(TrackingUI.left.line6, gv[6])
    -- Sparks moved to the right column.
    SetTextIfChanged(TrackingUI.left.line7, "")

    local crests = GetCrestLines()
    if type(TrackingUI.right.line1) == "table" then
        local cache = Addon.TRACKING and Addon.TRACKING._crestCache
        local lbl = cache and cache.label or nil
        local val = cache and cache.value or nil

        for i = 1, 4 do
            local row = TrackingUI.right["line" .. tostring(i)]
            if row and row.label and row.value then
                SetTextIfChanged(row.label, lbl and lbl[i] or "")
                SetTextIfChanged(row.value, val and val[i] or "")
            end
        end

        if TrackingUI.right.line5 and TrackingUI.right.line5.label and TrackingUI.right.line5.value then
            local cLbl, cVal = GetCatalystParts()
            SetTextIfChanged(TrackingUI.right.line5.label, cLbl)
            SetTextIfChanged(TrackingUI.right.line5.value, cVal)
        end
        if TrackingUI.right.line6 and TrackingUI.right.line6.label and TrackingUI.right.line6.value then
            local sLbl, sVal = GetSparksParts()
            SetTextIfChanged(TrackingUI.right.line6.label, sLbl)
            SetTextIfChanged(TrackingUI.right.line6.value, sVal)
        end
    else
        -- Backward compatible fallback: right column lines are single fontstrings.
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
    end
end

function Addon:SetTrackingVisible(show)
    local db = self:EnsureDB()
    db.showCurrency = show and true or false

    -- turning ON should create the panel right away
    if db.showCurrency and not self._trackingFrame then
        local main = _G["LariasWeeklyMidnightChecklistFrame"]
        if main then
            self:CreateTrackingPanel(main)
        end
    end

    if self._trackingFrame then
        self._trackingFrame:SetShown(db.showCurrency)
    end
    if self._showCurrencyCheck then
        self._showCurrencyCheck:SetChecked(db.showCurrency)
    end

    self:ApplyScrollLayout()
    if self.Refresh then self:Refresh() end
end

D("Currency.lua loaded")
