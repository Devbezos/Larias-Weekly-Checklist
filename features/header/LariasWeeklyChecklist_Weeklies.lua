-- Weeklies popup: floating panel showing current-week quest completion status.
-- Opened / closed via the "Weeklies" button in the main frame header.
local addonName = ...
local Addon = _G[addonName]
if not Addon then return end

local WIN_W   = 250   -- popup window width (auto-resizes height to content)
local PAD     = 12    -- outer content padding
local TITLE_H = 30    -- pixels from window top to content start
local ROW_H   = 18    -- height per quest row

-- ── Quest helpers ─────────────────────────────────────────────────────────────

-- Returns a single quest ID (number), a table of variant IDs, or nil if disabled.
local function GetWeekliesQuestEntry(key)
    local q = Addon.TRACKING and Addon.TRACKING.questIDs and Addon.TRACKING.questIDs[key]
    if type(q) == "table" then return q end
    q = tonumber(q) or 0
    return q > 0 and q or nil
end

-- Returns true/false/nil.
-- Handles a table of variant IDs (true if any one is flagged completed).
local function GetQuestDoneAny(key)
    local q = GetWeekliesQuestEntry(key)
    if not q then return nil end
    if not (C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted) then return nil end
    if type(q) == "table" then
        local hasValid = false
        for _, id in ipairs(q) do
            id = tonumber(id) or 0
            if id > 0 then
                hasValid = true
                local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, id)
                if ok and done then return true end
            end
        end
        return hasValid and false or nil
    else
        local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, q)
        return ok and (done and true or false) or nil
    end
end

-- Returns (count, goal, tierSuffix) or nil if IDs are not configured.
-- Checks Nightmare > Hard > Normal and returns the highest tier with completions.
local function GetPreyCount()
    local t = Addon.TRACKING
    if not (t and t.preyQuestIDs and t.preyQuestGoal) then return nil end
    if not (C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted) then return nil end
    local goal = tonumber(t.preyQuestGoal) or 4
    local function CountArr(arr)
        if not arr then return 0 end
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
    if t.preyNightmareQuestIDs then
        local nm = CountArr(t.preyNightmareQuestIDs)
        if nm > 0 then return nm, goal, " (Nightmare)" end
    end
    if t.preyHardQuestIDs then
        local hd = CountArr(t.preyHardQuestIDs)
        if hd > 0 then return hd, goal, " (Hard)" end
    end
    return CountArr(t.preyQuestIDs), goal, ""
end

-- ── Window builder ────────────────────────────────────────────────────────────

local function BuildWeekliesWindow()
    local Locale = Addon.L or {}

    local RED   = "ffff4040"
    local GREEN = "ff40ff40"
    local DIM   = "ff808080"
    local function CW(hex, txt) return "|c" .. hex .. tostring(txt or "") .. "|r" end

    local win = CreateFrame("Frame", "LariasWeekliesFrame", UIParent)
    Addon:ApplyTheme(win)
    win:SetSize(WIN_W, 60)  -- height adjusted by Populate()
    win:SetFrameStrata("HIGH")
    win:SetToplevel(true)
    win:SetClampedToScreen(true)
    win:SetMovable(true)
    win:EnableMouse(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", function(self) self:StartMoving() end)
    win:SetScript("OnDragStop",  function(self) self:StopMovingOrSizing() end)

    -- Title
    local titleFS = win:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleFS:SetPoint("TOPLEFT", win, "TOPLEFT", PAD, -8)
    titleFS:SetTextColor(Addon.THEME.header.r, Addon.THEME.header.g, Addon.THEME.header.b, Addon.THEME.header.a)
    titleFS:SetText(Locale.TRACKING_WEEKLIES_TITLE or "Weeklies")
    win._titleFS = titleFS

    -- Close button
    local closeBtn = Addon.Controls.NewCloseButton(win, function() win:Hide() end)
    closeBtn:SetPoint("TOPRIGHT", win, "TOPRIGHT", -4, -4)

    -- Pre-create 8 rows (max: 1 prey + 6 quests + 1 spare)
    local MAX_ROWS = 8
    local rows = {}
    for i = 1, MAX_ROWS do
        local y = TITLE_H + ROW_H * (i - 1)
        local lbl = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lbl:SetPoint("TOPLEFT",  win, "TOPLEFT",  PAD,  -y)
        lbl:SetJustifyH("LEFT")
        if lbl.SetWordWrap then lbl:SetWordWrap(false) end
        local val = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        val:SetPoint("TOPRIGHT", win, "TOPRIGHT", -PAD, -y)
        val:SetJustifyH("RIGHT")
        if val.SetWordWrap then val:SetWordWrap(false) end
        rows[i] = { label = lbl, value = val }
    end
    win._rows = rows

    -- ── Populate ─────────────────────────────────────────────────────────────
    local function Populate()
        local idx = 1

        local function SetRow(labelText, valueStr)
            local r = rows[idx]
            if not r then return end
            r.label:SetText(CW(DIM, labelText))
            r.value:SetText(valueStr or "")
            idx = idx + 1
        end

        -- Prey count
        local preyCount, preyGoal, preyTier = GetPreyCount()
        if preyCount then
            local xy  = preyCount .. "/" .. preyGoal
            local col = (preyCount >= preyGoal) and GREEN or RED
            local preyLabel = (Locale.TRACKING_QUEST_PREY or "Prey Hunted") .. (preyTier or "")
            SetRow(preyLabel, CW(col, xy))
        end

        -- 6 season weeklies
        local defs = {
            { key = "abundance",         label = Locale.TRACKING_QUEST_ABUNDANCE          or "Abundance" },
            { key = "lostLegends",       label = Locale.TRACKING_QUEST_LOST_LEGENDS       or "Lost Legends" },
            { key = "highEsteem",        label = Locale.TRACKING_QUEST_HIGH_ESTEEM        or "High Esteem" },
            { key = "fortifyRunestones", label = Locale.TRACKING_QUEST_FORTIFY_RUNESTONES or "Fortify the Runestones" },
            { key = "standYourGround",   label = Locale.TRACKING_QUEST_STAND_YOUR_GROUND  or "Stand Your Ground" },
            { key = "delversBounty",     label = Locale.TRACKING_QUEST_DELVERS_BOUNTY     or "Delver's Bounty" },
        }
        for _, d in ipairs(defs) do
            -- Skip rows whose quest ID is 0 (unknown/disabled).
            if GetWeekliesQuestEntry(d.key) then
                local done = GetQuestDoneAny(d.key)
                if done == nil then
                    SetRow(d.label, CW(DIM, Locale.TRACKING_NA or "N/A"))
                elseif done then
                    SetRow(d.label, CW(GREEN, "1/1"))
                else
                    SetRow(d.label, CW(RED, "0/1"))
                end
            end
        end

        -- Hide unused rows and size window to content
        for i = idx, MAX_ROWS do
            rows[i].label:SetText("")
            rows[i].value:SetText("")
        end
        local usedRows = idx - 1
        win:SetHeight(TITLE_H + usedRows * ROW_H + PAD)
    end

    win._populate = Populate

    -- Live update on quest events
    local evf = CreateFrame("Frame", nil, win)
    evf:SetScript("OnEvent", function()
        if win:IsShown() then Populate() end
    end)
    evf:RegisterEvent("QUEST_TURNED_IN")
    evf:RegisterEvent("QUEST_LOG_UPDATE")

    win:SetScript("OnShow", function() Populate() end)

    -- Initial position: centre of screen
    win:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

    Populate()
    return win
end

-- ── Public API ────────────────────────────────────────────────────────────────

function Addon:ToggleWeekliesWindow()
    if self._weekliesWindow then
        if self._weekliesWindow:IsShown() then
            self._weekliesWindow:Hide()
        else
            self._weekliesWindow:Show()
        end
        return
    end
    self._weekliesWindow = BuildWeekliesWindow()
    self._weekliesWindow:Show()
end
