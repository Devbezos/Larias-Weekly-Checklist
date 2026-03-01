-- Inline Weeklies section: per-quest status rows shown below the tracking panel.
-- Depends on LariasWeeklyChecklist_Overlay.lua being loaded first (provides Addon.TrackingInternal).
local addonName = ...
local Addon = _G[addonName]
if not Addon then return end

local TI = Addon.TrackingInternal
local QuestDoneAny = TI.QuestDoneAny
local max = math.max
local tinsert = table.insert
local THEME = Addon.THEME

-- ── Inline Weeklies Section ──────────────────────────────────────────────────────
-- Builds a compact weekly-quest status block anchored to the bottom of the
-- tracking frame, below the Great Vault and Currency columns.
-- Called from CreateTrackingPanel after self._trackingFrame is assigned.
local WSEC_PAD_TOP  = 6    -- gap above header text (below separator)
local WSEC_HEADER_H = 20   -- height of the "Weeklies" title row
local WSEC_ROW_H    = 15   -- height of each quest status row
local WSEC_PAD_BOT  = 6    -- padding below last row
local WSEC_PAD_LR   = 10   -- horizontal inset from tracking frame edge
local WSEC_BOT_OFF  = 10   -- pixels above tracking frame bottom
local WSEC_COL_GAP  = 12   -- gap between the two quest columns
local WSEC_ROWS_PER_COL = 4  -- 7 rows split across 2 columns (4 left, 3 right)

-- Expose constants so Overlay.lua can reference them via TI.
TI.WSEC_PAD_LR  = WSEC_PAD_LR
TI.WSEC_BOT_OFF = WSEC_BOT_OFF

-- Count how many quest IDs from the given array are flagged completed this week.
local function CountPreyArray(arr)
    if not arr then return 0 end
    if not (C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted) then return 0 end
    local n = 0
    for _, id in ipairs(arr) do
        id = tonumber(id) or 0
        if id > 0 then
            local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, id)
            if ok and done then n = n + 1 end
        end
    end
    return n
end

local function BuildWeekliesSection(trackingFrame)
    local L     = Addon.L or {}
    local prefs = Addon:EnsurePrefs()

    local sec = CreateFrame("Frame", nil, trackingFrame)
    sec:SetPoint("BOTTOMLEFT",  trackingFrame, "BOTTOMLEFT",  WSEC_PAD_LR,  WSEC_BOT_OFF)
    sec:SetPoint("BOTTOMRIGHT", trackingFrame, "BOTTOMRIGHT", -WSEC_PAD_LR, WSEC_BOT_OFF)

    Addon._inlineWeeklies              = sec
    trackingFrame._lariasWeekliesSection = sec

    -- Solid background so checklist items never bleed through the section.
    -- Only shown in "below" mode; in side/full modes the section blends into
    -- the tracking frame background.
    local bg = sec:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(sec)
    bg:SetColorTexture(THEME.bg.r, THEME.bg.g, THEME.bg.b, THEME.bg.a)
    sec._bg = bg

    -- Hide immediately when pref is off; return stub so resize skips it.
    if prefs.showInlineWeeklies == false then
        sec:SetHeight(0)
        sec:Hide()
        return sec
    end

    -- Thin separator line at the very top of the section.
    -- Only shown in "below" mode where it divides GV/Currency from Weeklies.
    local sep = sec:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetColorTexture(THEME.border.r, THEME.border.g, THEME.border.b, 0.5)
    sep:SetPoint("TOPLEFT",  sec, "TOPLEFT",  0, 0)
    sep:SetPoint("TOPRIGHT", sec, "TOPRIGHT", 0, 0)
    sec._sep = sep

    -- "Weeklies" header
    -- Header positioned ABOVE sec (matching the currency column title style).
    -- Width is updated by ResizeTrackingCols for side/full modes.
    local hdrFS = sec:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    hdrFS:SetPoint("TOP", sec, "TOP", 0, 24)
    hdrFS:SetHeight(WSEC_HEADER_H)
    hdrFS:SetWidth(200)  -- initial width; overridden by ResizeTrackingCols
    hdrFS:SetJustifyH("CENTER")
    hdrFS:SetJustifyV("MIDDLE")
    hdrFS:SetTextColor(THEME.header.r, THEME.header.g, THEME.header.b, THEME.header.a)
    hdrFS:SetText(L.TRACKING_WEEKLIES_TITLE)
    sec._hdrFS = hdrFS

    -- Two column sub-frames: content starts at the top of sec (title is above sec).
    local colOffY = 0
    local spine = CreateFrame("Frame", nil, sec)
    spine:SetPoint("TOPLEFT",  sec, "TOP", -WSEC_COL_GAP/2, colOffY)
    spine:SetPoint("TOPRIGHT", sec, "TOP",  WSEC_COL_GAP/2, colOffY)
    spine:SetHeight(1)

    local leftCol = CreateFrame("Frame", nil, sec)
    leftCol:SetPoint("TOPLEFT",  sec,   "TOPLEFT",  0, colOffY)
    leftCol:SetPoint("TOPRIGHT", spine, "TOPLEFT",  0, 0)
    leftCol:SetHeight(WSEC_ROWS_PER_COL * WSEC_ROW_H)

    local rightCol = CreateFrame("Frame", nil, sec)
    rightCol:SetPoint("TOPLEFT",  spine, "TOPRIGHT", 0, 0)
    rightCol:SetPoint("TOPRIGHT", sec,   "TOPRIGHT", 0, colOffY)
    rightCol:SetHeight(WSEC_ROWS_PER_COL * WSEC_ROW_H)

    local rowDefs = {
        { isPrey = true,  label = L.TRACKING_QUEST_PREY            },
        { questKey = "abundance",         label = L.TRACKING_QUEST_ABUNDANCE          },
        { questKey = "lostLegends",       label = L.TRACKING_QUEST_LOST_LEGENDS       },
        { questKey = "highEsteem",        label = L.TRACKING_QUEST_HIGH_ESTEEM        },
        { questKey = "fortifyRunestones", label = L.TRACKING_QUEST_FORTIFY_RUNESTONES },
        { questKey = "standYourGround",   label = L.TRACKING_QUEST_STAND_YOUR_GROUND  },
        { questKey = "delversBounty",     label = L.TRACKING_QUEST_DELVERS_BOUNTY     },
    }

    local GREEN = "|cff40ff40"
    local RED   = "|cffff4040"
    local CLOSE = "|r"

    local rows = {}
    for i, d in ipairs(rowDefs) do
        if d.label then
        local colFrame = (i <= WSEC_ROWS_PER_COL) and leftCol or rightCol
        local colIdx   = (i <= WSEC_ROWS_PER_COL) and 1 or 2
        local rowInCol = (i - 1) % WSEC_ROWS_PER_COL
        local rowY     = rowInCol * WSEC_ROW_H

        local lblFS = colFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lblFS:SetPoint("TOPLEFT", colFrame, "TOPLEFT", 4, -rowY)
        lblFS:SetHeight(WSEC_ROW_H)
        lblFS:SetJustifyH("LEFT")
        lblFS:SetJustifyV("MIDDLE")
        if lblFS.SetWordWrap then lblFS:SetWordWrap(false) end
        do local t = THEME.text; lblFS:SetTextColor(t.r, t.g, t.b, 1) end

        -- All rows use a right-aligned value FontString ("x/4", "0/1", "1/1").
        local valFS = colFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        valFS:SetPoint("TOPRIGHT", colFrame, "TOPRIGHT", -4, -rowY)
        valFS:SetSize(40, WSEC_ROW_H)
        valFS:SetJustifyH("RIGHT")
        valFS:SetJustifyV("MIDDLE")
        lblFS:SetPoint("TOPRIGHT", valFS, "TOPLEFT", -2, 0)

        local row = { lblFS = lblFS, valFS = valFS, colIdx = colIdx }
        for k, v in pairs(d) do row[k] = v end
        lblFS:SetText(d.label)
        tinsert(rows, row)
        end
    end
    sec._rows = rows

    local function Refresh()
        local hideCompleted = Addon:EnsurePrefs().hideCompletedSections
        local QIDs2      = Addon.TRACKING and Addon.TRACKING.questIDs or {}
        local PQIDs2    = Addon.TRACKING and Addon.TRACKING.preyQuestIDs
        local PQIDs_Hard = Addon.TRACKING and Addon.TRACKING.preyHardQuestIDs
        local PQIDs_NM   = Addon.TRACKING and Addon.TRACKING.preyNightmareQuestIDs
        local pGoal2 = (Addon.TRACKING and Addon.TRACKING.preyQuestGoal) or 4

        -- Layout: 2 columns when weeklies has full width (below or full mode),
        -- 1 column when sharing space side-by-side with GV or Currency.
        local tf        = Addon._trackingFrame
        local wMode     = tf and tf._weekliesMode or "below"
        local singleCol = (wMode == "side-right" or wMode == "side-left")

        -- Show separator + background only in "below" mode.
        local isBelow = (wMode == "below")
        if sec._sep then sec._sep:SetShown(isBelow) end
        if sec._bg  then sec._bg:SetShown(isBelow)  end

        -- Reflow the two column sub-frames to match the current mode.
        if singleCol then
            leftCol:ClearAllPoints()
            leftCol:SetPoint("TOPLEFT",  sec, "TOPLEFT",  0, colOffY)
            leftCol:SetPoint("TOPRIGHT", sec, "TOPRIGHT", 0, colOffY)
            rightCol:Hide()
        else
            leftCol:ClearAllPoints()
            leftCol:SetPoint("TOPLEFT",  sec,   "TOPLEFT",  0, colOffY)
            leftCol:SetPoint("TOPRIGHT", spine, "TOPLEFT",  0, 0)
            rightCol:Show()
            rightCol:ClearAllPoints()
            rightCol:SetPoint("TOPLEFT",  spine, "TOPRIGHT", 0, 0)
            rightCol:SetPoint("TOPRIGHT", sec,   "TOPRIGHT", 0, colOffY)
        end

        -- Pass 1: evaluate visibility and content for every row.
        local rowState = {}
        local visCount = 0
        for i, r in ipairs(rows) do
            local rowDone = false
            local disabled = false
            if r.isPrey then
                local count, tierSuffix = 0, ""
                local nm = CountPreyArray(PQIDs_NM)
                local hd = CountPreyArray(PQIDs_Hard)
                local nr = CountPreyArray(PQIDs2)
                if nm > 0 then
                    count, tierSuffix = nm, " (Nightmare)"
                elseif hd > 0 then
                    count, tierSuffix = hd, " (Hard)"
                else
                    count = nr
                end
                rowDone = count >= pGoal2
                local col = rowDone and GREEN or RED
                r.valFS:SetText(col .. count .. "/" .. pGoal2 .. CLOSE)
                r.lblFS:SetText((L.TRACKING_QUEST_PREY or "Prey Hunted") .. tierSuffix)
            elseif r.questKey then
                local entry = QIDs2[r.questKey]
                local isEnabled = entry and not (type(entry) == "number" and entry == 0)
                if not isEnabled then
                    disabled = true
                else
                    local done = QuestDoneAny(entry)
                    rowDone = (done == true)
                    if done == true then
                        r.valFS:SetText(GREEN .. "1/1" .. CLOSE)
                    elseif done == false then
                        r.valFS:SetText(RED .. "0/1" .. CLOSE)
                    else
                        r.valFS:SetText(RED .. "0/1" .. CLOSE)
                    end
                end
            end
            local visible = not disabled and not (hideCompleted and rowDone)
            rowState[i] = { visible = visible }
            if visible then visCount = visCount + 1 end
        end

        -- Pass 2: assign columns evenly so the two halves are balanced.
        -- In single-col mode everything goes left; otherwise split ceil/floor.
        local splitAt = singleCol and visCount or math.ceil(visCount / 2)
        local visIdx = 0
        for i, r in ipairs(rows) do
            if rowState[i].visible then
                visIdx = visIdx + 1
                r.colIdx = (visIdx <= splitAt) and 1 or 2
            end
        end

        -- Reparent FontStrings to the correct column frame (affects visibility inheritance).
        for _, r in ipairs(rows) do
            local target = (singleCol or r.colIdx == 1) and leftCol or rightCol
            r.lblFS:SetParent(target)
            r.valFS:SetParent(target)
        end

        -- Pass 3: show/hide and anchor each row within its column.
        local leftVis, rightVis = 0, 0
        local leftSlot, rightSlot = 0, 0
        for i, r in ipairs(rows) do
            local visible = rowState[i].visible
            r.lblFS:SetShown(visible)
            r.valFS:SetShown(visible)
            if visible then
                local refFrame, slot
                if singleCol or r.colIdx == 1 then
                    leftSlot  = leftSlot + 1
                    leftVis   = leftVis  + 1
                    refFrame  = leftCol
                    slot      = leftSlot
                else
                    rightSlot = rightSlot + 1
                    rightVis  = rightVis  + 1
                    refFrame  = rightCol
                    slot      = rightSlot
                end
                local rowY = -((slot - 1) * WSEC_ROW_H)
                r.valFS:ClearAllPoints()
                r.valFS:SetPoint("TOPRIGHT", refFrame, "TOPRIGHT", -4, rowY)
                r.lblFS:ClearAllPoints()
                r.lblFS:SetPoint("TOPLEFT",  refFrame, "TOPLEFT",  4, rowY)
                r.lblFS:SetPoint("TOPRIGHT", r.valFS, "TOPLEFT", -2, 0)
            end
        end

        -- Height: single-col tallies all rows; two-col uses the tallest column.
        local rowsH = singleCol
            and (leftVis * WSEC_ROW_H)
            or  (max(leftVis, rightVis) * WSEC_ROW_H)
        local newH = rowsH + WSEC_PAD_BOT
        leftCol:SetHeight(max(1, rowsH))
        rightCol:SetHeight(max(1, rowsH))
        local curSecH = tonumber(sec:GetHeight()) or 0
        if math.abs(curSecH - newH) > 1 then
            sec:SetHeight(newH)
            local tf2  = Addon._trackingFrame
            local tfH = tf2 and (tonumber(tf2:GetHeight()) or 0) or 0
            if tf2 and tfH > 90 then
                TI.ResizeTrackingPanelToContent(Addon)
            end
        end
    end

    sec.Refresh = Refresh

    -- Initial height: all rows shown, 3 rows tall (2-column layout).
    sec:SetHeight(WSEC_PAD_TOP + WSEC_HEADER_H + WSEC_ROWS_PER_COL * WSEC_ROW_H + WSEC_PAD_BOT)
    return sec
end

TI.BuildWeekliesSection = BuildWeekliesSection

function Addon:ApplyInlineWeekliesVisibility()
    -- Delegate: ApplyTrackingPanelOptions re-evaluates the full layout mode
    -- (below / side / full / hidden) and repositions everything correctly.
    if not self._trackingFrame then return end
    if self.ApplyTrackingPanelOptions then
        self:ApplyTrackingPanelOptions()
    end
    if self.RequestTrackingUpdate then
        self:RequestTrackingUpdate()
    end
end
