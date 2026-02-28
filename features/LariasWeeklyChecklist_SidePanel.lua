-- LariasWeeklyChecklist_SidePanel.lua
-- Panel anchored to the LEFT of the main window.
-- Shows weekly quest tracking with auto-detect via quest log events.
-- Section header is clickable to collapse/expand.
local addonName = ...
local Addon = _G[addonName]
if not Addon then return end

-- ── Layout ───────────────────────────────────────────────────────────────────
local PANEL_W  = 215    -- outer panel width (px)
local PANEL_GAP = 4     -- gap between main frame right edge and panel left edge
local PAD      = 8      -- horizontal inner padding
local ROW_H    = 17     -- data row height
local SEC_H    = 22     -- top-level section header height
local ZONE_H   = 18     -- zone sub-header height
local SBAR_W   = 16     -- scrollbar width reservation

-- ── Quest helpers ────────────────────────────────────────────────────────────
local function QuestDoneAny(entry)
    if not (C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted) then return nil end
    if type(entry) == "table" then
        local hasValid = false
        for _, id in ipairs(entry) do
            id = tonumber(id) or 0
            if id > 0 then
                hasValid = true
                local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, id)
                if ok and done then return true end
            end
        end
        return hasValid and false or nil
    else
        local q = tonumber(entry) or 0
        if q == 0 then return nil end
        local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, q)
        -- NOTE: avoid "ok and X or nil" idiom here – when done==false that
        -- collapses to nil via Lua short-circuit.  Use explicit if instead.
        if not ok then return nil end
        return done and true or false
    end
end

-- ── Module-level event frames ───────────────────────────────────────────────
-- Frames are created at file-load time but RegisterEvent is deferred until
-- Addon:OnEnable via RegisterSidePanelEventListeners() below.  This avoids
-- ADDON_ACTION_FORBIDDEN for Frame:RegisterEvent() on Classic game flavours
-- where RegisterEvent is a protected function.
local _onQuestUpdate = nil   -- function() called on quest log events

local _questFrame = CreateFrame("Frame")
_questFrame:SetScript("OnEvent", function()
    if _onQuestUpdate then _onQuestUpdate() end
end)

-- Called once from Addon:OnEnable (Ace3 guarantees a safe, non-protected
-- context).  Guard against double-registration.
local _sidePanelEventsRegistered = false
function Addon:RegisterSidePanelEventListeners()
    if _sidePanelEventsRegistered then return end
    _sidePanelEventsRegistered = true
    _questFrame:RegisterEvent("QUEST_TURNED_IN")
    _questFrame:RegisterEvent("QUEST_LOG_UPDATE")
end

-- ── Section gap ──────────────────────────────────────────────────────────────
local SEC_GAP = 6   -- vertical gap between sections

-- ── Row widgets ───────────────────────────────────────────────────────────────
-- Returns (row, newPosY).  row exposes .lbl and .val (FontString) for refresh.
local function MakeWeeklyRow(parent, posY)
    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lbl:SetPoint("TOPLEFT",  parent, "TOPLEFT",   PAD * 2, -posY)
    lbl:SetPoint("TOPRIGHT", parent, "TOPRIGHT",  -42,     -posY)
    lbl:SetHeight(ROW_H)
    lbl:SetJustifyH("LEFT")
    lbl:SetJustifyV("MIDDLE")
    if lbl.SetWordWrap then lbl:SetWordWrap(false) end

    local val = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    val:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -SBAR_W - 2, -posY)
    val:SetSize(36, ROW_H)
    val:SetJustifyH("RIGHT")
    val:SetJustifyV("MIDDLE")

    return { lbl = lbl, val = val }, posY + ROW_H
end

-- ── Collapsible section container ────────────────────────────────────────────
-- Creates a header button + content frame block stacked below prevFrame.
-- After building rows into sec.content (with local posY from 0), call
-- sec:FinalizeHeight(h) so the section knows its expanded size.
-- Assign sec.onToggle = fn to be called whenever the section is toggled.
local function MakeSection(sc, label, prevFrame)
    local T = Addon.THEME

    local secFrame = CreateFrame("Frame", nil, sc)
    secFrame:SetWidth(PANEL_W)
    if prevFrame then
        secFrame:SetPoint("TOPLEFT", prevFrame, "BOTTOMLEFT", 0, -SEC_GAP)
    else
        secFrame:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, -4)
    end

    -- Clickable colored header bar
    local bar = CreateFrame("Button", nil, secFrame)
    bar:SetPoint("TOPLEFT",  secFrame, "TOPLEFT",      0,       0)
    bar:SetPoint("TOPRIGHT", secFrame, "TOPRIGHT", -SBAR_W,     0)
    bar:SetHeight(SEC_H)

    local baseR, baseG, baseB = T.bg.r * 2.2, T.bg.g * 2.0, T.bg.b * 1.6
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar)
    bg:SetColorTexture(baseR, baseG, baseB, 0.95)

    local titleFS = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    titleFS:SetPoint("TOPLEFT",  bar, "TOPLEFT",  PAD, 0)
    titleFS:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -(SEC_H + 4), 0)
    titleFS:SetHeight(SEC_H)
    titleFS:SetJustifyH("LEFT")
    titleFS:SetJustifyV("MIDDLE")
    titleFS:SetTextColor(T.header.r, T.header.g, T.header.b, T.header.a)
    titleFS:SetText(label)

    -- Collapse indicator [–] / [+]
    local togFS = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    togFS:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -4, 0)
    togFS:SetSize(SEC_H, SEC_H)
    togFS:SetJustifyH("RIGHT")
    togFS:SetJustifyV("MIDDLE")
    togFS:SetTextColor(T.header.r, T.header.g, T.header.b, T.header.a)
    togFS:SetText("-")

    -- Content frame (rows anchored inside this with local posY)
    local content = CreateFrame("Frame", nil, secFrame)
    content:SetPoint("TOPLEFT",  secFrame, "TOPLEFT",  0, -SEC_H)
    content:SetPoint("TOPRIGHT", secFrame, "TOPRIGHT", 0, -SEC_H)
    content:SetHeight(1)

    local sec = {
        frame     = secFrame,
        content   = content,
        collapsed = false,
        contentH  = 0,
        onToggle  = nil,
    }

    local function ApplyHeight()
        if sec.collapsed then
            content:Hide()
            secFrame:SetHeight(SEC_H)
            togFS:SetText("+")
        else
            content:Show()
            secFrame:SetHeight(SEC_H + sec.contentH)
            togFS:SetText("-")
        end
        if sec.onToggle then sec.onToggle() end
    end

    function sec:FinalizeHeight(h)
        self.contentH = math.max(h, 1)
        content:SetHeight(self.contentH)
        ApplyHeight()
    end

    bar:SetScript("OnClick", function()
        sec.collapsed = not sec.collapsed
        ApplyHeight()
    end)
    bar:SetScript("OnEnter", function()
        bg:SetColorTexture(baseR * 1.35, baseG * 1.35, baseB * 1.35, 0.95)
    end)
    bar:SetScript("OnLeave", function()
        bg:SetColorTexture(baseR, baseG, baseB, 0.95)
    end)

    return sec
end

-- ── Panel builder ─────────────────────────────────────────────────────────────
local function BuildSidePanel(mainFrame)
    local L     = Addon.L or {}
    local prefs = Addon:EnsurePrefs()

    -- Outer panel frame – anchored to the LEFT of the main frame
    local panel = CreateFrame("Frame", "LariasWeeklySidePanelFrame", mainFrame)
    panel:SetPoint("TOPRIGHT",    mainFrame, "TOPLEFT",    -PANEL_GAP, 0)
    panel:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMLEFT", -PANEL_GAP, 0)
    panel:SetWidth(PANEL_W)
    Addon:ApplyTheme(panel)

    -- Scroll frame
    local sf = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT",     panel, "TOPLEFT",     0, 0)
    sf:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)

    local sc = CreateFrame("Frame", nil, sf)
    sc:SetWidth(PANEL_W)
    sc:SetHeight(200)
    sf:SetScrollChild(sc)

    local showWeeklies  = prefs.showSidePanelWeeklies ~= false

    local weeklyRows    = {}
    local builtSections = {}
    local prevFrame     = nil

    -- Recalculate scroll child height & auto-hide panel when all sections collapsed
    local function UpdateLayout()
        local h = 4
        for _, sec in ipairs(builtSections) do
            h = h + sec.frame:GetHeight() + SEC_GAP
        end
        sc:SetHeight(math.max(h, 50))

        local allCollapsed = true
        for _, sec in ipairs(builtSections) do
            if not sec.collapsed then allCollapsed = false; break end
        end
        if allCollapsed then panel:Hide() else panel:Show() end
    end

    -- ── Weeklies ──────────────────────────────────────────────────────────────
    if showWeeklies then
        local sec = MakeSection(sc, L.SIDE_PANEL_WEEKLIES or "Weeklies", prevFrame)
        sec.onToggle = UpdateLayout
        tinsert(builtSections, sec)
        prevFrame = sec.frame

        local content = sec.content
        local posY    = 0
        local QIDs    = Addon.TRACKING and Addon.TRACKING.questIDs or {}
        local PQIDs   = Addon.TRACKING and Addon.TRACKING.preyQuestIDs
        local pGoal   = (Addon.TRACKING and Addon.TRACKING.preyQuestGoal) or 4

        local preyRow
        preyRow, posY = MakeWeeklyRow(content, posY)
        preyRow.isPrey    = true
        preyRow.pGoal     = pGoal
        preyRow.pQuestIDs = PQIDs
        preyRow.lbl:SetText(L.TRACKING_QUEST_PREY or "Prey Hunted")
        tinsert(weeklyRows, preyRow)

        local defs = {
            { key = "abundance",         label = L.TRACKING_QUEST_ABUNDANCE          or "Abundance" },
            { key = "lostLegends",       label = L.TRACKING_QUEST_LOST_LEGENDS       or "Lost Legends" },
            { key = "highEsteem",        label = L.TRACKING_QUEST_HIGH_ESTEEM        or "High Esteem" },
            { key = "fortifyRunestones", label = L.TRACKING_QUEST_FORTIFY_RUNESTONES or "Fortify the Runestones" },
            { key = "standYourGround",   label = L.TRACKING_QUEST_STAND_YOUR_GROUND  or "Stand Your Ground" },
        }
        for _, d in ipairs(defs) do
            local r
            r, posY = MakeWeeklyRow(content, posY)
            r.questKey   = d.key
            r.questEntry = QIDs[d.key]
            r.lbl:SetText(d.label)
            tinsert(weeklyRows, r)
        end
        sec:FinalizeHeight(posY + 4)
    end

    UpdateLayout()

    -- ── Refresh ───────────────────────────────────────────────────────────────
    local GREEN = "|cff40ff40"
    local RED   = "|cffff4040"
    local DIM   = "|cff808080"
    local CLOSE = "|r"

    local function RefreshWeeklyRows()
        local hideCompleted = Addon:EnsurePrefs().hideCompletedSections
        local QIDs  = Addon.TRACKING and Addon.TRACKING.questIDs or {}
        local PQIDs = Addon.TRACKING and Addon.TRACKING.preyQuestIDs
        local pGoal = (Addon.TRACKING and Addon.TRACKING.preyQuestGoal) or 4
        for _, r in ipairs(weeklyRows) do
            local rowDone = false
            if r.isPrey then
                local count = 0
                if PQIDs and C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
                    for _, id in ipairs(PQIDs) do
                        id = tonumber(id) or 0
                        if id > 0 then
                            local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, id)
                            if ok and done then count = count + 1 end
                        end
                    end
                end
                rowDone = count >= pGoal
                local col = rowDone and GREEN or RED
                r.val:SetText(col .. count .. "/" .. pGoal .. CLOSE)
            elseif r.questKey then
                local entry = QIDs[r.questKey]
                local done  = entry and QuestDoneAny(entry)
                rowDone = (done == true)
                if done == nil then
                    r.val:SetText(DIM .. (L.TRACKING_NA or "N/A") .. CLOSE)
                elseif done then
                    r.val:SetText(GREEN .. "1/1" .. CLOSE)
                else
                    r.val:SetText(RED .. "0/1" .. CLOSE)
                end
            end
            local visible = not (hideCompleted and rowDone)
            r.lbl:SetShown(visible)
            r.val:SetShown(visible)
        end
    end

    local function RefreshAll()
        if showWeeklies then RefreshWeeklyRows() end
    end

    panel.RefreshAll = RefreshAll

    -- ── Wire quest-log event dispatch ─────────────────────────────────────────
    if showWeeklies then
        _onQuestUpdate = function()
            if panel:IsShown() then RefreshWeeklyRows() end
        end
    end

    panel:SetScript("OnShow", function()
        RefreshAll()
    end)

    if panel:IsShown() then
        RefreshAll()
    end

    return panel
end

-- ── Public API ────────────────────────────────────────────────────────────────

function Addon:CreateSidePanel(mainFrame)
    if self._sidePanel then return end
    self._sidePanelMainFrame = mainFrame
    local prefs   = self:EnsurePrefs()
    if prefs.showSidePanelWeeklies == false then return end
    self._sidePanel = BuildSidePanel(mainFrame)
end

-- Called by Settings when any side-panel section pref changes.
-- Destroys and recreates the panel so the row list reflects the new prefs.
function Addon:RebuildSidePanel()
    local mainFrame = self._sidePanelMainFrame
    if self._sidePanel then
        self._sidePanel:Hide()
        self._sidePanel:SetParent(nil)
        self._sidePanel = nil
    end
    _onQuestUpdate = nil
    if mainFrame then
        self:CreateSidePanel(mainFrame)
        if self._sidePanel and mainFrame:IsShown() then
            self._sidePanel:Show()
            self._sidePanel.RefreshAll()
        end
    end
end
