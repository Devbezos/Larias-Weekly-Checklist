-- Currency / crest / catalyst panel logic.
-- Depends on LariasWeeklyChecklist_Overlay.lua (Addon.TrackingInternal) and
-- LariasWeeklyChecklist_GreatVault.lua (TI.GetGreatVaultBlockLines, TI.ApplyGreatVaultGrid).
local addonName = ...
local Addon = _G[addonName]
if not Addon then return end

local TI                = Addon.TrackingInternal
local COLORS            = TI.COLORS
local ColorWrap         = TI.ColorWrap
local SetTextIfChanged  = TI.SetTextIfChanged
local SetShownIfChanged = TI.SetShownIfChanged
local IsNonEmptyText    = TI.IsNonEmptyText
local FormatXY          = TI.FormatXY
local ColorForXY        = TI.ColorForXY
local IsAchievementCompleteSafe = TI.IsAchievementCompleteSafe
local Wipe              = TI.Wipe
local RIGHT_LINE_COUNT  = TI.RIGHT_LINE_COUNT
local RIGHT_ROW_KEYS    = TI.RIGHT_ROW_KEYS
local TrackingUI        = TI.TrackingUI
local THEME             = Addon.THEME
local L                 = Addon.L or {}
local floor             = math.floor

-- Mirror of the feature flag in Overlay.lua; keeps snapshot logic consistent.
-- Keep in sync with LariasWeeklyChecklist_Overlay.lua.
local FEATURE_GREAT_VAULT = false

-- ── Currency ID helpers ───────────────────────────────────────────────────────

local function GetCrestAchievementID(i)
    local ach = Addon.TRACKING and Addon.TRACKING.crestAchievementIDs
    if type(ach) ~= "table" then return nil end
    if ach[1] ~= nil then
        local idx = tonumber(i)
        return idx and ach[idx] or nil
    end
    return nil
end

local function FormatCurrencyProgressParts(currencyID)
    if not currencyID or not C_CurrencyInfo or not C_CurrencyInfo.GetCurrencyInfo then return nil end
    local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
    if not info then return nil end

    local weeklyMax = info.maxWeeklyQuantity
    if weeklyMax and weeklyMax > 0 then
        local held         = info.quantity or 0
        local weeklyEarned = info.weeklyQuantity or 0
        local weeklyLeft   = math.max(0, weeklyMax - weeklyEarned)
        return held, held + weeklyLeft
    end

    local qty    = info.quantity or 0
    local maxQty = info.maxQuantity
    if maxQty and maxQty > 0 then return qty, maxQty end
    return qty, 0
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

local QUALITY_HEX = {
    [0] = "ff9d9d9d",  -- Poor (gray)
    [1] = "ffffffff",  -- Common (white)
    [2] = "ff1eff00",  -- Uncommon (green)
    [3] = "ff0070dd",  -- Rare (blue)
    [4] = "ffa335ee",  -- Epic (purple)
    [5] = "ffff8000",  -- Legendary (orange)
    [6] = "ffe6cc80",  -- Artifact / Token
    [7] = "ff00ccff",  -- Heirloom
}

local function GetCurrencyQualityColor(currencyID)
    local id = tonumber(currencyID)
    if not (id and id > 0) then return COLORS.dim end
    if not (C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo) then return COLORS.dim end
    local info = C_CurrencyInfo.GetCurrencyInfo(id)
    if not info then return COLORS.dim end
    local q = tonumber(info.quality)
    return (q and QUALITY_HEX[q]) or COLORS.dim
end

local function GetCrestLabelText(currencyID)
    local gameName = GetCurrencyName(currencyID)
    if type(gameName) == "string" and gameName ~= "" then return gameName end
    return "Crest " .. tostring(currencyID)
end

-- ── Quest helpers ─────────────────────────────────────────────────────────────

local function GetTrackedQuestID(key)
    local q = Addon.TRACKING and Addon.TRACKING.questIDs and Addon.TRACKING.questIDs[key]
    q = tonumber(q) or 0
    if q <= 0 then return nil end
    return q
end

local function GetQuestDoneRaw(questKey)
    local questID = GetTrackedQuestID(questKey)
    if not questID then return nil end
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, questID)
        if ok then return done and true or false end
    end
    return nil
end

local function GetQuestDoneParts(labelText, questKey, opts)
    local questID = GetTrackedQuestID(questKey)
    if not questID then return "", "" end

    local label = ColorWrap(COLORS.dim, labelText)
    opts = opts or {}
    local doneText    = opts.doneText
    local notDoneText = opts.notDoneText
    if opts.as01 then
        doneText    = doneText    or "1/1"
        notDoneText = notDoneText or "0/1"
    else
        doneText    = doneText    or (L.TRACKING_DONE     or "")
        notDoneText = notDoneText or (L.TRACKING_NOT_DONE or "")
    end

    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, questID)
        if ok then
            if done then return label, ColorWrap(COLORS.green, doneText) end
            return label, ColorWrap(COLORS.red, notDoneText)
        end
    end
    return label, ColorWrap(COLORS.red, L.TRACKING_NA or "")
end

local function GetDelversBountyParts()
    return GetQuestDoneParts(L.TRACKING_QUEST_DELVERS_BOUNTY or "", "delversBounty", { as01 = true })
end

local function GetWeeklyPreyParts()
    if not GetTrackedQuestID("weeklyPrey") then return "", "" end
    return GetQuestDoneParts(L.TRACKING_QUEST_WEEKLY_PREY or "", "weeklyPrey", { as01 = true })
end

-- ── Sparks row ────────────────────────────────────────────────────────────────

local function GetSparksParts()
    local id = Addon.TRACKING and Addon.TRACKING.sparkCurrencyID
    if not (id and tonumber(id) and tonumber(id) > 0) then return "", "" end

    local name  = GetCurrencyName(id) or L.TRACKING_SPARKS_LABEL or ""
    local label = ColorWrap(GetCurrencyQualityColor(id), name)
    local cur, c = FormatCurrencyProgressParts(id)
    cur = tonumber(cur) or 0
    c   = tonumber(c)   or 0
    local xy, color
    if c > 0 then
        xy    = FormatXY(cur, c)
        color = ColorForXY(cur, c)
    else
        xy    = tostring(cur)
        color = COLORS.green
    end
    return label, ColorWrap(color, xy)
end

-- ── Crest functions ───────────────────────────────────────────────────────────

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
        ids = {}
        crestCount = 0
    end
    if crestCount <= 0 then crestCount = 4 end
    return ids, crestCount
end

local function EnsureCrestCache(tracking, crestCount)
    local cache = tracking._crestCache
    if not cache or cache.count ~= crestCount then
        cache = {
            count     = crestCount,
            out       = {},
            label     = {},
            value     = {},
            name      = {},
            cur       = {},
            cap       = {},
            unlocked  = {},
            effective = {},
            gained    = {},
        }
        tracking._crestCache = cache
    end
    return cache
end

local function ResetCrestOutput(cache, crestCount)
    local out      = cache.out
    local labelOut = cache.label
    local valueOut = cache.value
    for i = 1, crestCount do
        out[i]      = ""
        labelOut[i] = ""
        valueOut[i] = ""
    end
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
            cache.cur[i] = 0
            cache.cap[i] = 0
        end
    end
end

local function PopulateCrestUnlocked(cache, crestCount)
    for i = 1, crestCount do
        local achievementID = GetCrestAchievementID(i)
        cache.unlocked[i] = achievementID and IsAchievementCompleteSafe(achievementID) or false
    end
end

local function ComputeCrestTradeup(cache, crestCount, batchLower, batchHigher)
    local highestTradeTarget
    for i = crestCount, 2, -1 do
        if cache.unlocked[i - 1] then
            highestTradeTarget = i
            break
        end
    end

    local effective = cache.effective
    local gained    = cache.gained
    effective[1] = cache.cur[1] or 0
    gained[1]    = 0
    for i = 2, crestCount do
        local prevAmt       = tonumber(effective[i - 1]) or 0
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

    local ids, crestCount = GetCrestIDsAndCount(tracking)
    local cache = EnsureCrestCache(tracking, crestCount)
    local out, labelOut, valueOut = ResetCrestOutput(cache, crestCount)

    local batchLower, batchHigher = GetCrestTradeBatches(tracking)
    PopulateCrestCurCap(cache, ids, crestCount)
    PopulateCrestUnlocked(cache, crestCount)
    local highestTradeTarget, gained = ComputeCrestTradeup(cache, crestCount, batchLower, batchHigher)

    for i = 1, crestCount do
        local id = ids[i]
        if id then
            local name = GetCrestLabelText(id) or GetCurrencyName(id) or tostring(id)
            if name then
                local cur = cache.cur[i]
                local cap = cache.cap[i]
                local xy, color
                if cap > 0 then
                    xy = FormatXY(cur, cap)
                    if cur >= cap then
                        color = COLORS.green
                    elseif cache.unlocked[i] then
                        color = COLORS.yellow
                    else
                        color = COLORS.red
                    end
                else
                    xy    = tostring(cur)
                    color = COLORS.green
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

                local lbl = ColorWrap(GetCurrencyQualityColor(id), tostring(name)) .. tradeUp
                local val = ColorWrap(color, xy)
                labelOut[i] = lbl
                valueOut[i] = val
                out[i]      = lbl .. " " .. val
            end
        else
            local lbl = ColorWrap(COLORS.dim, L.TRACKING_CREST_LABEL or "")
            local val = ColorWrap(COLORS.red,  L.TRACKING_NO_ID      or "")
            labelOut[i] = lbl
            valueOut[i] = val
            out[i]      = lbl .. " " .. val
        end
    end
    return out, labelOut, valueOut, crestCount
end

-- ── Catalyst ──────────────────────────────────────────────────────────────────

local function GetCatalystQtyRaw()
    local cur
    local tracking = Addon.TRACKING
    local id = tracking and tracking.catalystCurrencyID
    local hasConfiguredID = (id and tonumber(id) and tonumber(id) > 0) and true or false
    if hasConfiguredID then
        local qty = FormatCurrencyProgressParts(tonumber(id))
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
    if cur == nil and not hasConfiguredID then return nil end
    return cur
end

local function GetCatalystParts()
    local cur, cap
    local id = Addon.TRACKING and Addon.TRACKING.catalystCurrencyID
    local hasConfiguredID = (id and tonumber(id) and tonumber(id) > 0) and true or false
    local catName        = (hasConfiguredID and GetCurrencyName(tonumber(id))) or L.TRACKING_CATALYST_LABEL or ""
    local catLabelColor  = (hasConfiguredID and GetCurrencyQualityColor(tonumber(id))) or COLORS.dim

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
                cap = charges.maxCharges     or charges.maximumCharges
            end
        end
        if cur == nil and C_Catalyst.GetNumCharges then cur = C_Catalyst.GetNumCharges() end
        if cap == nil and C_Catalyst.GetMaxCharges  then cap = C_Catalyst.GetMaxCharges()  end
    end

    cur = tonumber(cur)
    cap = tonumber(cap)
    if not cur then
        if not hasConfiguredID then return "", "" end
        return ColorWrap(catLabelColor, catName), ColorWrap(COLORS.red, L.TRACKING_NA or "")
    end

    if cap and cap > 0 then
        return ColorWrap(catLabelColor, catName), ColorWrap(ColorForXY(cur, cap), FormatXY(cur, cap))
    end
    local color = (cur <= 0) and COLORS.red or COLORS.green
    return ColorWrap(catLabelColor, catName), ColorWrap(color, ("%d"):format(cur))
end

-- ── Coffer Keys ───────────────────────────────────────────────────────────────

local function GetCofferKeysParts()
    local id = Addon.TRACKING and Addon.TRACKING.cofferKeysCurrencyID
    if not (id and tonumber(id) and tonumber(id) > 0) then return "", "" end
    id = tonumber(id)
    local name  = GetCurrencyName(id) or "Restored Coffer Keys"
    local label = ColorWrap(GetCurrencyQualityColor(id), name)
    local cur, cap = FormatCurrencyProgressParts(id)
    cur = tonumber(cur) or 0
    cap = tonumber(cap) or 0
    local xy, color
    if cap > 0 then
        xy    = FormatXY(cur, cap)
        color = ColorForXY(cur, cap)
    else
        xy    = tostring(cur)
        color = (cur <= 0) and COLORS.red or COLORS.green
    end
    return label, ColorWrap(color, xy)
end

-- ── Right-column row layout ───────────────────────────────────────────────────

local function SetRightRowPair(i, rowLabel, rowValue, iconFileID, currencyID)
    local row = TrackingUI.right[RIGHT_ROW_KEYS[i]]
    if not (row and row.label and row.value) then return end
    rowLabel = rowLabel or ""
    rowValue = rowValue or ""
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

-- ── Wide-mode reflow ────────────────────────────────────────────────────────
-- Repositions currency row frames when the column is full-width (solo panel).
-- wideMode=true  → crests in left half, non-crests in right half.
-- wideMode=false → all rows span the full column width (normal).
-- Must be called AFTER SetRightRowPair populates / hides rows so that
-- BottomFor() returns correct values in ResizeTrackingPanelToContent.
local CURR_INNER_GAP = 8
local CURR_ROW_H     = 18

function TI.ReflowCurrencyRows(wideMode, crestCount, colW)
    local tf       = Addon._trackingFrame
    local rightCol = tf and tf._lariasRightCol
    if not rightCol then return end
    local halfW = math.max(10, math.floor((colW - CURR_INNER_GAP) / 2))

    for i = 1, RIGHT_LINE_COUNT do
        local entry = TrackingUI.right["line" .. i]
        if not (entry and entry.frame) then break end
        local f = entry.frame
        f:ClearAllPoints()

        if wideMode then
            local inLeft = (i <= crestCount)
            local rowIdx = inLeft and (i - 1) or (i - crestCount - 1)
            local y      = -(CURR_ROW_H * rowIdx)
            local xOff   = inLeft and 0 or (halfW + CURR_INNER_GAP)
            f:SetPoint("TOPLEFT", rightCol, "TOPLEFT", xOff, y)
            f:SetWidth(halfW)
            f._lariasBaseY = y
        else
            local y = -(CURR_ROW_H * (i - 1))
            f:SetPoint("TOPLEFT",  rightCol, "TOPLEFT",  0, y)
            f:SetPoint("TOPRIGHT", rightCol, "TOPRIGHT", 0, y)
            f._lariasBaseY = y
        end
    end
end

local function ApplyRightColumnAsPairs()
    local _, labelLines, valueLines, crestCount = GetCrestLines()
    crestCount = tonumber(crestCount) or 4

    local tracking = Addon.TRACKING
    local crestIDs = GetCrestIDsAndCount(tracking or {})

    local idx = 1

    for i = 1, crestCount do
        if idx > RIGHT_LINE_COUNT then break end
        local rowLabel = (labelLines and labelLines[i]) or ""
        local rowValue = (valueLines and valueLines[i]) or ""
        if IsNonEmptyText(rowLabel) or IsNonEmptyText(rowValue) then
            SetRightRowPair(idx, rowLabel, rowValue, GetCurrencyIconID(crestIDs[i]), crestIDs[i])
            idx = idx + 1
        end
    end

    local cLbl, cVal = GetCatalystParts()
    cLbl = cLbl or ""; cVal = cVal or ""
    if idx <= RIGHT_LINE_COUNT and (IsNonEmptyText(cLbl) or IsNonEmptyText(cVal)) then
        local cID = tracking and tracking.catalystCurrencyID
        SetRightRowPair(idx, cLbl, cVal, GetCurrencyIconID(cID), cID)
        idx = idx + 1
    end

    local sLbl, sVal = GetSparksParts()
    sLbl = sLbl or ""; sVal = sVal or ""
    if idx <= RIGHT_LINE_COUNT and (IsNonEmptyText(sLbl) or IsNonEmptyText(sVal)) then
        local sID = tracking and tracking.sparkCurrencyID
        SetRightRowPair(idx, sLbl, sVal, GetCurrencyIconID(sID), sID)
        idx = idx + 1
    end

    local kLbl, kVal = GetCofferKeysParts()
    kLbl = kLbl or ""; kVal = kVal or ""
    if idx <= RIGHT_LINE_COUNT and (IsNonEmptyText(kLbl) or IsNonEmptyText(kVal)) then
        local kID = tracking and tracking.cofferKeysCurrencyID
        SetRightRowPair(idx, kLbl, kVal, GetCurrencyIconID(kID), kID)
        idx = idx + 1
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

    -- Reflow layout: split into two sub-columns when currency is the only panel.
    local tf       = Addon._trackingFrame
    local rightCol = tf and tf._lariasRightCol
    if rightCol then
        rightCol._currCrestCount = crestCount
        local leftShown = tf._lariasLeftCol  and tf._lariasLeftCol.IsShown  and tf._lariasLeftCol:IsShown()
        local ws        = tf._lariasWeekliesSection
        local wShown    = ws and ws.IsShown and ws:IsShown()
        local rcShown   = rightCol.IsShown and rightCol:IsShown()
        local wideCurrency = rcShown and not leftShown and not wShown
        TI.ReflowCurrencyRows(wideCurrency and true or false, crestCount, tonumber(rightCol:GetWidth()) or 200)
    end
end

-- ── Currency row UI builder ───────────────────────────────────────────────────
-- Called once from CreateTrackingPanel (Overlay.lua) via TI.BuildCurrencyRowUI.
TI.BuildCurrencyRowUI = function(rightCol)
    local ROW_ICON_SZ  = 14
    local ROW_ICON_GAP = 3

    local function MakeLinePair(parent, y, template)
        local row = CreateFrame("Frame", nil, parent)
        row:SetPoint("TOPLEFT",  parent, "TOPLEFT",  0, y)
        row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, y)
        row:SetHeight(16)
        row._lariasBaseY = y

        local icon = CreateFrame("Button", nil, row)
        icon:SetSize(ROW_ICON_SZ, ROW_ICON_SZ)
        icon:SetPoint("LEFT", row, "LEFT", 0, 0)
        icon:Hide()
        icon:EnableMouse(true)
        local iconTex = icon:CreateTexture(nil, "ARTWORK")
        iconTex:SetAllPoints(icon)
        icon._tex = iconTex
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
        value:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        value:SetJustifyH("RIGHT")
        if value.SetWordWrap then value:SetWordWrap(false) end
        value:SetTextColor(THEME.text.r, THEME.text.g, THEME.text.b, THEME.text.a)
        value:SetText("")

        label:SetPoint("RIGHT", value, "LEFT", -6, 0)
        return { frame = row, icon = icon, label = label, value = value }
    end

    for i = 1, RIGHT_LINE_COUNT do
        TrackingUI.right["line" .. tostring(i)] = MakeLinePair(rightCol, -18 * (i - 1), "GameFontHighlight")
    end
end

-- ── Snapshot data helpers ─────────────────────────────────────────────────────

local function ComputeSnapshotData(snap)
    if FEATURE_GREAT_VAULT then
        local gvLines = TI.GetGreatVaultBlockLines and TI.GetGreatVaultBlockLines() or {}
        snap.leftLines = snap.leftLines or {}
        for i = 1, 9 do snap.leftLines[i] = gvLines[i] or "" end

        local gvc = Addon.TRACKING._gvCache
        if gvc and gvc.gridBlocks then
            snap.leftGrid = snap.leftGrid or {{},{},{}}
            for bi = 1, 3 do
                local src = gvc.gridBlocks[bi]
                local dst = snap.leftGrid[bi]
                if src and dst then
                    dst.available = src.available
                    dst.complete  = src.complete
                    dst.maxIlvl   = src.maxIlvl
                    dst.slots = dst.slots or {{},{},{}}
                    for si = 1, 3 do
                        if src.slots and src.slots[si] and dst.slots[si] then
                            dst.slots[si].thresh = src.slots[si].thresh
                            dst.slots[si].ilvl   = src.slots[si].ilvl
                        end
                    end
                end
            end
        end
    end

    if snap.rightRows then
        Wipe(snap.rightRows)
    else
        snap.rightRows = {}
    end

    local tracking = Addon.TRACKING
    if tracking then
        local ids, crestCount = GetCrestIDsAndCount(tracking)
        local cache = EnsureCrestCache(tracking, crestCount)
        PopulateCrestCurCap(cache, ids, crestCount)
        for i = 1, crestCount do
            local id = ids[i]
            if id then
                local qty = cache.cur[i] or 0
                snap.rightRows[#snap.rightRows + 1] = { type = "crest", id = id, qty = qty }
            end
        end
    end

    local catQty = GetCatalystQtyRaw()
    snap.rightRows[#snap.rightRows + 1] = { type = "catalyst", qty = catQty or 0 }

    local sparkID = tracking and tonumber(tracking.sparkCurrencyID)
    if sparkID and sparkID > 0 then
        local sQty = FormatCurrencyProgressParts(sparkID)
        snap.rightRows[#snap.rightRows + 1] = { type = "sparks", id = sparkID, qty = tonumber(sQty) or 0 }
    end

    local cofferID = tracking and tonumber(tracking.cofferKeysCurrencyID)
    if cofferID and cofferID > 0 then
        local kQty = FormatCurrencyProgressParts(cofferID)
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

local function RenderSnapshotRow(row)
    local t = row.type
    if t == "crest" then
        local id  = row.id
        local qty = tonumber(row.qty) or 0
        local name = GetCrestLabelText(id) or GetCurrencyName(id) or tostring(id or "?")
        local lbl  = ColorWrap(GetCurrencyQualityColor(id), tostring(name))
        local _, cap = FormatCurrencyProgressParts(id)
        cap = tonumber(cap) or 0
        local xy, color
        if cap > 0 then
            xy    = FormatXY(qty, cap)
            color = ColorForXY(qty, cap)
        else
            xy    = tostring(qty)
            color = COLORS.green
        end
        return lbl, ColorWrap(color, xy)

    elseif t == "catalyst" then
        local qty = tonumber(row.qty) or 0
        local tracking = Addon.TRACKING
        local catID = tracking and tonumber(tracking.catalystCurrencyID)
        local catLabel = (catID and catID > 0 and GetCurrencyName(catID)) or L.TRACKING_CATALYST_LABEL or ""
        local lbl = ColorWrap(GetCurrencyQualityColor(catID), catLabel)
        local cap = nil
        if C_Catalyst then
            if C_Catalyst.GetMaxCharges then cap = tonumber(C_Catalyst.GetMaxCharges()) end
            if not cap and C_Catalyst.GetCharges then
                local charges = C_Catalyst.GetCharges()
                if type(charges) == "table" then
                    cap = tonumber(charges.maxCharges or charges.maximumCharges)
                end
            end
        end
        if (not cap or cap == 0) and catID and catID > 0 then
            local _, c = FormatCurrencyProgressParts(catID)
            cap = tonumber(c)
        end
        local val
        if cap and cap > 0 then
            val = ColorWrap(ColorForXY(qty, cap), FormatXY(qty, cap))
        else
            val = ColorWrap((qty <= 0) and COLORS.red or COLORS.green, ("%d"):format(qty))
        end
        return lbl, val

    elseif t == "sparks" then
        local qty = tonumber(row.qty) or 0
        local id  = tonumber(row.id)
        if not id then
            local tracking = Addon.TRACKING
            id = tracking and tonumber(tracking.sparkCurrencyID)
        end
        local sparkLabel = (id and id > 0 and GetCurrencyName(id)) or L.TRACKING_SPARKS_LABEL or ""
        local lbl = ColorWrap(GetCurrencyQualityColor(id), sparkLabel)
        local cap = 0
        if id and id > 0 then
            local _, c = FormatCurrencyProgressParts(id)
            cap = tonumber(c) or 0
        end
        local xy, color
        if cap > 0 then
            xy    = FormatXY(qty, cap)
            color = ColorForXY(qty, cap)
        else
            xy    = tostring(qty)
            color = (qty <= 0) and COLORS.red or COLORS.green
        end
        return lbl, ColorWrap(color, xy)

    elseif t == "cofferkeys" then
        local qty = tonumber(row.qty) or 0
        local id  = tonumber(row.id)
        if not id then
            local tracking = Addon.TRACKING
            id = tracking and tonumber(tracking.cofferKeysCurrencyID)
        end
        local keyName = (id and id > 0 and GetCurrencyName(id)) or "Restored Coffer Keys"
        local lbl = ColorWrap(GetCurrencyQualityColor(id), keyName)
        local cap = 0
        if id and id > 0 then
            local _, c = FormatCurrencyProgressParts(id)
            cap = tonumber(c) or 0
        end
        local xy, color
        if cap > 0 then
            xy    = FormatXY(qty, cap)
            color = ColorForXY(qty, cap)
        else
            xy    = tostring(qty)
            color = (qty <= 0) and COLORS.red or COLORS.green
        end
        return lbl, ColorWrap(color, xy)

    elseif t == "quest" then
        local key  = row.key
        local done = row.done
        local labelText = ""
        if key == "delversBounty" then
            labelText = L.TRACKING_QUEST_DELVERS_BOUNTY or ""
        elseif key == "weeklyPrey" then
            labelText = L.TRACKING_QUEST_WEEKLY_PREY or ""
        end
        if not IsNonEmptyText(labelText) then return "", "" end
        local lbl = ColorWrap(COLORS.dim, labelText)
        local val
        if done == nil then
            val = ColorWrap(COLORS.red, L.TRACKING_NA or "")
        elseif done then
            val = ColorWrap(COLORS.green, "1/1")
        else
            val = ColorWrap(COLORS.red, "0/1")
        end
        return lbl, val
    end
    return "", ""
end

local function RenderSnapshotIntoPanel(snap)
    if FEATURE_GREAT_VAULT and TI.ApplyGreatVaultGrid then
        TI.ApplyGreatVaultGrid(snap.leftGrid or nil)
    end

    if snap.rightRows then
        local idx = 1
        local storedCrestQty = {}
        local nonCrestRows   = {}
        for _, row in ipairs(snap.rightRows) do
            if row.type == "crest" and row.id then
                storedCrestQty[row.id] = tonumber(row.qty) or 0
            else
                nonCrestRows[#nonCrestRows + 1] = row
            end
        end

        local tracking = Addon.TRACKING
        if tracking then
            local ids, crestCount = GetCrestIDsAndCount(tracking)
            for i = 1, crestCount do
                if idx > RIGHT_LINE_COUNT then break end
                local id = ids[i]
                if id then
                    local qty = storedCrestQty[id] or 0
                    local lbl, val = RenderSnapshotRow({ type = "crest", id = id, qty = qty })
                    if IsNonEmptyText(lbl) or IsNonEmptyText(val) then
                        SetRightRowPair(idx, lbl, val, GetCurrencyIconID(id))
                        idx = idx + 1
                    end
                end
            end
        end

        for _, row in ipairs(nonCrestRows) do
            if idx > RIGHT_LINE_COUNT then break end
            local lbl, val
            if row.type then
                lbl, val = RenderSnapshotRow(row)
            else
                lbl = row.label or ""
                val = row.value or ""
            end
            if IsNonEmptyText(lbl) or IsNonEmptyText(val) then
                local iconID = nil
                if row.type == "sparks" or row.type == "cofferkeys" then
                    iconID = GetCurrencyIconID(row.id)
                elseif row.type == "catalyst" then
                    local tr = Addon.TRACKING
                    iconID = GetCurrencyIconID(tr and tr.catalystCurrencyID)
                end
                SetRightRowPair(idx, lbl, val, iconID)
                idx = idx + 1
            end
        end

        for i = idx, RIGHT_LINE_COUNT do
            SetRightRowPair(i, "", "")
        end
    end
end

local function SaveTrackingSnapshot(db)
    local snap = db.trackingSnapshot
    if type(snap) ~= "table" then
        snap = {}
        db.trackingSnapshot = snap
    end
    ComputeSnapshotData(snap)
end

-- ── TI exports ────────────────────────────────────────────────────────────────

TI.FormatCurrencyProgressParts = FormatCurrencyProgressParts
TI.GetCurrencyIconID           = GetCurrencyIconID
TI.GetCurrencyName             = GetCurrencyName
TI.GetCurrencyQualityColor     = GetCurrencyQualityColor
TI.GetCrestLabelText           = GetCrestLabelText
TI.GetCrestIDsAndCount         = GetCrestIDsAndCount
TI.EnsureCrestCache            = EnsureCrestCache
TI.PopulateCrestCurCap         = PopulateCrestCurCap
TI.GetCatalystQtyRaw           = GetCatalystQtyRaw
TI.SetRightRowPair             = SetRightRowPair
TI.ApplyRightColumnAsPairs     = ApplyRightColumnAsPairs
TI.ComputeSnapshotData         = ComputeSnapshotData
TI.RenderSnapshotIntoPanel     = RenderSnapshotIntoPanel
TI.SaveTrackingSnapshot        = SaveTrackingSnapshot
