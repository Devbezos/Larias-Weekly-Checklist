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

-- ── QuestDoneAny ──────────────────────────────────────────────────────────────
-- Returns true/false for completed/not, nil if the quest ID is unknown/invalid.
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
        if hasValid then return false else return nil end
    else
        local q = tonumber(entry) or 0
        if q == 0 then return nil end
        local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, q)
        if not ok then return nil end
        return done and true or false
    end
end

-- ── Quest event frame for inline weeklies ─────────────────────────────────────
-- Frame is created at file-load; RegisterEvent is deferred to OnEnable to avoid
-- ADDON_ACTION_FORBIDDEN on protected Classic game flavours.
local _inlineQuestFrame = CreateFrame("Frame")
_inlineQuestFrame:SetScript("OnEvent", function()
    if Addon._inlineWeeklies and Addon._inlineWeeklies.Refresh then
        Addon._inlineWeeklies.Refresh()
    end
end)

local _inlineWeekliesEventsRegistered = false
function Addon:RegisterInlineWeekliesEvents()
    if _inlineWeekliesEventsRegistered then return end
    _inlineWeekliesEventsRegistered = true
    _inlineQuestFrame:RegisterEvent("QUEST_TURNED_IN")
    _inlineQuestFrame:RegisterEvent("QUEST_LOG_UPDATE")
end
local TrackingUI = { left = {}, right = {} }
local trackingEventFrame  -- frame created lazily in ConfigureTrackingEvents

local tonumber, tostring, type = tonumber, tostring, type
local floor, max, abs = math.floor, math.max, math.abs
local tinsert, tremove, tconcat = table.insert, table.remove, table.concat
-- Feature flag: set to true to show the Great Vault section.
local FEATURE_GREAT_VAULT = false

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

-- Returns true when the logged-in character has previously saved tracking data.
-- Intentionally bypasses _viewingChar so it always reflects the OWN character;
-- used to decide whether background event-driven snapshot updates should run.
function Addon:HasTrackingSnapshot()
    if not (self.db and self.db.global) then return false end
    local ownKey = self:GetCurrentProfileKey()
    local cdb    = self.db.global.chars and self.db.global.chars[ownKey]
    local snap   = cdb and cdb.trackingSnapshot
    return snap ~= nil and (snap.leftLines ~= nil or snap.rightRows ~= nil)
end

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
    end

    if showCurrency then
        trackingEventFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
        trackingEventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
        trackingEventFrame:RegisterEvent("QUEST_TURNED_IN")
        SafeRegisterEvent(trackingEventFrame, "CATALYST_CHARGES_UPDATED")
        SafeRegisterEvent(trackingEventFrame, "CATALYST_UPDATE")
        SafeRegisterEvent(trackingEventFrame, "ITEM_INTERACTION_ITEM_SELECTION_UPDATED")
    end

    -- Needed by both Great Vault (item data for vault slot icons) and Currency
    -- (item data for tracked items); register once regardless of which is shown.
    trackingEventFrame:RegisterEvent("ITEM_DATA_LOAD_RESULT")

    -- Always overwrite the handler so the parentFrame upvalue stays current;
    -- OnEnable may call this with nil before the frame is created.
    trackingEventFrame:SetScript("OnEvent", function()
        local isMainFrameVisible = IsFrameShown(parentFrame)
        local isTrackingPanelVisible = IsFrameShown(Addon._trackingFrame)
        if isMainFrameVisible and isTrackingPanelVisible then
            -- Normal path: panel is open, do a full UI update.
            Addon:RequestTrackingUpdate()
        elseif Addon:HasTrackingSnapshot() then
            -- Background path: this character has prior snapshot data; keep it
            -- fresh via background updates even while the panel is not open.
            Addon:RequestBackgroundSnapshotUpdate()
        end
    end)
end

function Addon:RequestBackgroundSnapshotUpdate()
    -- Throttled background snapshot save (fires when the panel is hidden but
    -- the character already has snapshot data from a previous session).
    if self._bgSnapshotPending then return end
    self._bgSnapshotPending = true

    if not self._bgSnapshotRunner then
        local addon = self
        self._bgSnapshotRunner = function()
            addon._bgSnapshotPending = nil
            if addon.UpdateSnapshotBackground then
                addon:UpdateSnapshotBackground()
            end
        end
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0.2, self._bgSnapshotRunner)
    else
        self._bgSnapshotRunner()
    end
end

function Addon:UpdateSnapshotBackground()
    -- Compute current data from WoW APIs and save to the profile snapshot
    -- without rendering anything to the UI (frame may be hidden/uncreated).
    if not self:HasTrackingSnapshot() then return end
    local db = self:EnsureDB()
    local snap = db.trackingSnapshot
    if type(snap) ~= "table" then return end
    if TI and TI.ComputeSnapshotData then TI.ComputeSnapshotData(snap) end
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
    orange = "ffff8040",
    yellow = "ffffd34d",
    green  = "ff40ff40",
    white  = "ffffffff",
    dim    = "ff808080",
}

local function ColorWrap(hex, txt)
    -- Wrap a string in WoW color codes.
    -- Direct concatenation is measurably faster than (':format()') for a fixed
    -- 3-piece template because it skips format-string parsing/dispatch.
    return "|c" .. hex .. tostring(txt or "") .. "|r"
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
    -- |[cr][%x]* matches both |cAARRGGBB (opening) and |r (closing) in one
    -- pass, halving the string allocations vs two separate gsub calls.
    if type(text) ~= "string" then return false end
    text = text:gsub("|[cr][%x]*", "")
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
    -- Standard progress format: always expects a positive max.
    currentAmount = tonumber(currentAmount) or 0
    maxAmount = tonumber(maxAmount) or 0
    if maxAmount > 0 then return ("%d/%d"):format(currentAmount, maxAmount) end
    return tostring(currentAmount)
end

local function ColorForXY(currentAmount, maxAmount)
    -- Progress coloring: <=50% => red, 51-99% => orange, 100% => green.
    currentAmount = tonumber(currentAmount) or 0
    maxAmount = tonumber(maxAmount) or 0
    if maxAmount <= 0 then return COLORS.yellow end  -- no cap; neutral fallback
    local pct = currentAmount / maxAmount
    if pct >= 1   then return COLORS.green  end
    if pct > 0.5  then return COLORS.orange end
    return COLORS.red
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

local function ComputeWantTrackingPanel(db, prefs)
    -- Decide whether the tracking panel should be shown at all.
    -- db    = per-character data (EnsureDB)  → trackingSnapshot
    -- prefs = account-wide prefs (EnsurePrefs) → showGreatVault, showCurrency
    if Addon._viewingChar then
        -- When viewing another character, only show the panel if we have a
        -- stored snapshot for them (they've opened the addon at least once).
        local snap = db.trackingSnapshot
        local hasData = snap and (snap.leftLines ~= nil or (snap.rightRows ~= nil and #snap.rightRows > 0))
        return hasData and IsMainFrameOnListTab() and true or false
    end
    local wantPanel = (prefs.showGreatVault or prefs.showCurrency or prefs.showInlineWeeklies ~= false) and true or false
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

local function ResizeTrackingPanelToContent(addon)
    -- Auto-size the tracking panel height to the actual visible content.
    local trackingFrame = addon._trackingFrame
    if not (trackingFrame and trackingFrame.GetHeight and trackingFrame.SetHeight) then return end

    -- Measure right column first so the GV grid can expand to match it.
    local bottomRight = 0
    for i = 1, RIGHT_LINE_COUNT do
        local row = TrackingUI.right[RIGHT_ROW_KEYS[i]]
        if type(row) == "table" then
            bottomRight = max(bottomRight, BottomFor(row.frame or row.label))
        else
            bottomRight = max(bottomRight, BottomFor(row))
        end
    end

    -- Reflow the GV grid so it fills the same vertical space as the right column.
    if bottomRight > 0 and Addon._reflowGVGrid then
        Addon._reflowGVGrid(bottomRight)
    end

    local bottomLeft = 0
    -- Use the bottom border of the last GV grid block as the left-column height sentinel.
    bottomLeft = max(bottomLeft, BottomFor(TrackingUI.left._gvSentinel))

    local contentH = max(bottomLeft, bottomRight)
    -- Only reserve space for the GV/currency title row when at least one column is shown.
    local anyColShown = (trackingFrame._lariasLeftCol  and trackingFrame._lariasLeftCol.IsShown  and trackingFrame._lariasLeftCol:IsShown())
                     or (trackingFrame._lariasRightCol and trackingFrame._lariasRightCol.IsShown and trackingFrame._lariasRightCol:IsShown())
    local topOffset = anyColShown and 32 or 0
    local bottomPad = 10
    local minH = 90

    -- Weeklies height contribution depends on its layout mode.
    -- "below"  → strip below both columns; adds to targetH.
    -- "side-*" → weeklies is a column; min frame height = 32 + wsH + pad.
    -- "full"   → only content; starts at y=-32.
    -- "hidden" → ignored.
    local weeklyExtra    = 0
    local weeklyColBottom = 0  -- minimum targetH when weeklies is a column
    local ws    = trackingFrame._lariasWeekliesSection
    local wMode = trackingFrame._weekliesMode or "hidden"
    if ws and ws.IsShown and ws:IsShown() then
        local wsH = tonumber(ws:GetHeight()) or 0
        if wMode == "below" then
            weeklyExtra = wsH + 8
        elseif wMode == "side-right" or wMode == "side-left" or wMode == "full" then
            weeklyColBottom = 32 + wsH + bottomPad
        end
    end

    local targetH = max(minH, topOffset + contentH + bottomPad + weeklyExtra, weeklyColBottom)

    local curH = tonumber(trackingFrame:GetHeight()) or 0
    if math.abs(curH - targetH) <= 1 then return end

    trackingFrame:SetHeight(targetH)
    local colH = max(1, contentH + 2)
    if trackingFrame._lariasLeftCol and trackingFrame._lariasLeftCol.SetHeight then
        trackingFrame._lariasLeftCol:SetHeight(colH)
    end
    if trackingFrame._lariasRightCol and trackingFrame._lariasRightCol.SetHeight then
        trackingFrame._lariasRightCol:SetHeight(colH)
    end
    if addon.ApplyScrollLayout then
        addon:ApplyScrollLayout()
    end
end

local WSEC_PAD_LR   = 10   -- horizontal inset from tracking frame edge
local WSEC_BOT_OFF  = 10   -- pixels above tracking frame bottom

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

-- ── TrackingInternal module bridge ──────────────────────────────────────────
-- Shared utilities exposed here so GreatVault.lua, Currency.lua, and
-- Weeklies.lua can read them after this file loads.
Addon.TrackingInternal = Addon.TrackingInternal or {}
local TI = Addon.TrackingInternal
TI.COLORS                       = COLORS
TI.ColorWrap                    = ColorWrap
TI.Wipe                         = Wipe
TI.IsFrameShown                 = IsFrameShown
TI.IsNonEmptyText               = IsNonEmptyText
TI.SetTextIfChanged             = SetTextIfChanged
TI.SetShownIfChanged            = SetShownIfChanged
TI.IsMainFrameOnListTab         = IsMainFrameOnListTab
TI.FormatXY                     = FormatXY
TI.ColorForXY                   = ColorForXY
TI.IsAchievementCompleteSafe    = IsAchievementCompleteSafe
TI.QuestDoneAny                 = QuestDoneAny
TI.BottomFor                    = BottomFor
TI.TrackingUI                   = TrackingUI
TI.RIGHT_LINE_COUNT             = RIGHT_LINE_COUNT
TI.RIGHT_ROW_KEYS               = RIGHT_ROW_KEYS
TI.FEATURE_GREAT_VAULT          = FEATURE_GREAT_VAULT
TI.ResizeTrackingPanelToContent = ResizeTrackingPanelToContent

function Addon:CreateTrackingPanel(parentFrame)
    -- Build the tracking panel UI (left: Great Vault, right: currency rows).
    if self._trackingFrame then return end
    local db = self:EnsurePrefs()

    local trackingFrame = CreateFrame("Frame", nil, parentFrame)
    -- Lift tracking panel above the in-frame scale slider that sits below it.
    local trackingBottomY = (Addon.UI.sliderBottomPad or 4) + (Addon.UI.sliderH or 20)
    trackingFrame:SetPoint("BOTTOMLEFT", parentFrame, "BOTTOMLEFT", Addon.UI.sectionInsetX, trackingBottomY)
    trackingFrame:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", -Addon.UI.sectionInsetX, trackingBottomY)
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
    leftCol:SetSize(colW, UI.trackH - 40)
    trackingFrame._lariasLeftCol = leftCol

    local rightCol = CreateFrame("Frame", nil, trackingFrame)
    rightCol:SetPoint("TOPLEFT", trackingFrame, "TOPLEFT", padL, -32)
    rightCol:SetSize(colW, UI.trackH - 40)
    trackingFrame._lariasRightCol = rightCol

    -- GV (leftCol) sits to the right of Currency (rightCol).
    leftCol:SetPoint("TOPLEFT", rightCol, "TOPRIGHT", colGap, 0)

    -- ── Decorative box border around each column (title + content) ────────
    local BOX_PAD = 6
    local function MakeColBox(col)
        local box = CreateFrame("Frame", nil, trackingFrame)
        Addon:ApplyTheme(box)
        -- Col boxes use lower alpha so column content stands out.
        if box.SetBackdropColor    then box:SetBackdropColor(THEME.bg.r, THEME.bg.g, THEME.bg.b, 0.55) end
        if box.SetBackdropBorderColor then box:SetBackdropBorderColor(THEME.border.r, THEME.border.g, THEME.border.b, 0.65) end
        -- Keep box behind column content: match trackingFrame's level so
        -- OVERLAY-layer FontStrings in the columns always render on top.
        local tfLevel = trackingFrame.GetFrameLevel and trackingFrame:GetFrameLevel() or 1
        if box.SetFrameLevel then box:SetFrameLevel(tfLevel) end
        box:EnableMouse(false)
        -- Extend above the column to cover the title (title is 24px above col.TOPLEFT).
        box:SetPoint("TOPLEFT",     col, "TOPLEFT",     -BOX_PAD,  24 + BOX_PAD)
        box:SetPoint("BOTTOMRIGHT", col, "BOTTOMRIGHT",  BOX_PAD, -BOX_PAD)
        return box
    end

    -- A small transparent Button placed only over the title strip at the top of
    -- each column (from the top of the decorative box down to where the column
    -- content starts).  Height = title area (24px) + both BOX_PAD margins.
    local function MakeTitleButton(col, tipText, onClick)
        local btn = CreateFrame("Button", nil, trackingFrame)
        btn:SetPoint("TOPLEFT",     col, "TOPLEFT",  -BOX_PAD,  24 + BOX_PAD)
        btn:SetPoint("BOTTOMRIGHT", col, "TOPRIGHT",  BOX_PAD,  BOX_PAD)
        btn:EnableMouse(true)
        -- Subtle highlight only over the title strip on hover.
        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.07)
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(tipText, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        btn:RegisterForClicks("AnyUp")
        if onClick then btn:SetScript("OnClick", onClick) end
        return btn
    end

    local leftBox  = MakeColBox(leftCol)
    local rightBox = MakeColBox(rightCol)
    trackingFrame._lariasLeftBox  = leftBox
    trackingFrame._lariasRightBox = rightBox

    -- Great Vault title button: toggles the Weekly Rewards frame.
    MakeTitleButton(leftCol,
        L.TOOLTIP_OPEN_GREAT_VAULT or "Click to open the Great Vault",
        function()
            -- WeeklyRewardsFrame is lazily created; ensure the module is loaded.
            if not WeeklyRewardsFrame then
                C_AddOns.LoadAddOn("Blizzard_WeeklyRewards")
            end
            if WeeklyRewardsFrame then
                if WeeklyRewardsFrame:IsShown() then WeeklyRewardsFrame:Hide()
                else WeeklyRewardsFrame:Show() end
            end
        end)

    -- Currency title button: toggles the currency panel.
    MakeTitleButton(rightCol,
        L.TOOLTIP_OPEN_CURRENCIES or "Click to open the Currency panel",
        function()
            ToggleCharacter("TokenFrame")
        end)

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

    -- Great Vault section grids (delegated to GreatVault.lua via TI).
    if TI.BuildGreatVaultGridUI then
        TI.BuildGreatVaultGridUI(trackingFrame, leftCol)
    end

    -- Currency rows (delegated to Currency.lua via TI).
    if TI.BuildCurrencyRowUI then
        TI.BuildCurrencyRowUI(rightCol)
    end

    trackingFrame:SetShown((db.showGreatVault or db.showCurrency) and IsMainFrameOnListTab())
    self._trackingFrame = trackingFrame

    -- Weeklies section (delegated to Weeklies.lua via TI).
    if TI.BuildWeekliesSection then TI.BuildWeekliesSection(trackingFrame) end

    if trackingFrame.SetScript then
        trackingFrame:SetScript("OnShow", function()
            local database = Addon:EnsurePrefs()
            Addon:ConfigureTrackingEvents(parentFrame, database.showGreatVault and true or false, database.showCurrency and true or false)
            Addon:RequestTrackingUpdate()
            -- Refresh weeklies rows on every show (quest state may have changed).
            if Addon._inlineWeeklies and Addon._inlineWeeklies.Refresh then
                Addon._inlineWeeklies.Refresh()
            end
        end)
        trackingFrame:SetScript("OnHide", function()
            -- Keep events registered if this character has snapshot data so
            -- background updates continue even while the panel is not visible.
            if trackingEventFrame and not Addon:HasTrackingSnapshot() then
                trackingEventFrame:UnregisterAllEvents()
            end
        end)
    end

    self:ConfigureTrackingEvents(parentFrame, db.showGreatVault and true or false, db.showCurrency and true or false)

    -- Scale slider lives below this panel, inside the main frame.
    if self.CreateInFrameScaleSlider then
        self:CreateInFrameScaleSlider(parentFrame)
    end

    -- Status banner lives in the small space below the slider row.
    if self.CreateStatusBanner then
        self:CreateStatusBanner(parentFrame)
        -- Banner now exists and always takes space; recalculate slider/panel offsets.
        if self.ApplyScaleSliderVisibility then self:ApplyScaleSliderVisibility() end
        -- Initial evaluation — show the right banner state immediately if needed.
        if self.UpdateStatusBanner then self:UpdateStatusBanner() end
    end

end

function Addon:ApplyTrackingPanelOptions()
    -- Re-layout / show/hide columns when options change.
    -- Layout modes for the weeklies section:
    --   "below"      GV + Currency both on  → weeklies is a full-width strip below them
    --   "side-right" GV on, Currency off    → weeklies takes the right column slot
    --   "side-left"  one column on, other off → weeklies takes the left column slot
    --   "full"       neither GV nor Currency → weeklies spans full width as only content
    --   "hidden"     weeklies disabled
    local trackingFrame = self._trackingFrame
    if not trackingFrame then return end

    local db    = self:EnsureDB()
    local prefs = self:EnsurePrefs()
    local showGreatVault = (prefs.showGreatVault and FEATURE_GREAT_VAULT) and true or false
    local showCurrency   = prefs.showCurrency   and true or false
    local showWeeklies   = prefs.showInlineWeeklies ~= false

    local wantPanel
    if Addon._viewingChar then
        local snap = db.trackingSnapshot
        wantPanel = snap and (snap.leftLines ~= nil or (snap.rightRows ~= nil and #snap.rightRows > 0)) and IsMainFrameOnListTab() and true or false
        if wantPanel and snap then
            showGreatVault = snap.leftLines ~= nil
            showCurrency   = snap.rightRows ~= nil and #snap.rightRows > 0
        end
        showWeeklies = false  -- weeklies always shows live data; hide for other-char view
    else
        wantPanel = (showGreatVault or showCurrency or showWeeklies) and IsMainFrameOnListTab()
    end

    trackingFrame:SetShown(wantPanel)
    if not wantPanel then
        if trackingEventFrame then trackingEventFrame:UnregisterAllEvents() end
        if self.ApplyScrollLayout then self:ApplyScrollLayout() end
        return
    end

    if not Addon._viewingChar then
        self:ConfigureTrackingEvents(_G["LariasWeeklyChecklistFrame"], showGreatVault, showCurrency)
    end

    local leftCol    = trackingFrame._lariasLeftCol
    local rightCol   = trackingFrame._lariasRightCol
    local leftTitle  = trackingFrame._lariasLeftTitle
    local rightTitle = trackingFrame._lariasRightTitle
    local ws         = trackingFrame._lariasWeekliesSection
    local padL       = tonumber(trackingFrame._lariasPadL)  or 10
    local padR2      = tonumber(trackingFrame._lariasPadR)  or 10
    local colGap     = tonumber(trackingFrame._lariasColGap) or 12

    -- ── Determine weeklies layout mode ───────────────────────────────────
    local weekliesMode = "hidden"
    if showWeeklies and not Addon._viewingChar then
        if showGreatVault and showCurrency then
            weekliesMode = "below"      -- weeklies strip below both columns
        elseif showGreatVault or showCurrency then
            weekliesMode = "side-left"  -- weeklies left, GV/Currency right
        else
            weekliesMode = "full"
        end
    end
    trackingFrame._weekliesMode = weekliesMode

    -- ── Column and box visibility ─────────────────────────────────────────
    SetShownIfChanged(leftCol,   showGreatVault)
    SetShownIfChanged(rightCol,  showCurrency)
    SetShownIfChanged(leftTitle, showGreatVault)
    SetShownIfChanged(rightTitle, showCurrency)
    local leftBox  = trackingFrame._lariasLeftBox
    local rightBox = trackingFrame._lariasRightBox
    local showBothBoxes = showGreatVault and showCurrency
    if leftBox  then SetShownIfChanged(leftBox,  showBothBoxes) end
    if rightBox then SetShownIfChanged(rightBox, showBothBoxes) end

    -- ── Column anchoring ──────────────────────────────────────────────────
    -- ResizeTrackingCols (via ApplyScrollLayout) sets explicit widths.
    -- Here we only set the initial TOPLEFT anchor for each column.
    if leftCol  then leftCol:ClearAllPoints()  end
    if rightCol then rightCol:ClearAllPoints() end

    trackingFrame._lariasShowBoth = showGreatVault and showCurrency

    if showCurrency then
        -- Currency (rightCol) is always the leftmost column.
        if rightCol then rightCol:SetPoint("TOPLEFT", trackingFrame, "TOPLEFT", padL, -32) end
    end
    if showGreatVault then
        if showCurrency and rightCol then
            -- Both cols: leftCol (GV) starts right of rightCol (Currency).
            if leftCol then leftCol:SetPoint("TOPLEFT", rightCol, "TOPRIGHT", colGap, 0) end
        else
            -- GV-only: GV takes the left anchor.
            if leftCol then leftCol:SetPoint("TOPLEFT", trackingFrame, "TOPLEFT", padL, -32) end
        end
    end

    -- ── Weeklies position ─────────────────────────────────────────────────
    -- "below": use BOTTOMLEFT/BOTTOMRIGHT anchors (width is auto).
    -- All other modes: position and width are handled by ResizeTrackingCols.
    if ws then
        ws:ClearAllPoints()
        if weekliesMode == "below" then
            ws:SetPoint("BOTTOMLEFT",  trackingFrame, "BOTTOMLEFT",  WSEC_PAD_LR,  WSEC_BOT_OFF)
            ws:SetPoint("BOTTOMRIGHT", trackingFrame, "BOTTOMRIGHT", -WSEC_PAD_LR, WSEC_BOT_OFF)
            ws:Show()
            if ws.Refresh then ws.Refresh() end
        elseif weekliesMode == "side-right" or weekliesMode == "side-left" or weekliesMode == "full" then
            -- Position / width set by ResizeTrackingCols; just make sure it is shown.
            ws:Show()
            if ws.Refresh then ws.Refresh() end
        else
            ws:Hide()
            ws:SetHeight(0)
        end
    end

    -- ── Column title positions ────────────────────────────────────────────
    if showGreatVault and leftTitle and leftCol then
        leftTitle:ClearAllPoints()
        leftTitle:SetPoint("TOP", leftCol, "TOP", 0, 24)
    end
    if showCurrency and rightTitle and rightCol then
        rightTitle:ClearAllPoints()
        rightTitle:SetPoint("TOP", rightCol, "TOP", 0, 24)
    end

    if self.ApplyScrollLayout then self:ApplyScrollLayout() end
end

function Addon:UpdateTracking()
    -- Main throttled entry point: reconcile desired visibility, then render content.
    local db    = self:EnsureDB()
    local prefs = self:EnsurePrefs()

    local wantPanel = ComputeWantTrackingPanel(db, prefs)
    EnsureTrackingPanelCreatedIfNeeded(wantPanel)

    if self.ApplyTrackingPanelOptions then
        self:ApplyTrackingPanelOptions()
    end

    if not (wantPanel and self._trackingFrame and self._trackingFrame:IsShown()) then
        if self.ApplyScrollLayout then self:ApplyScrollLayout() end
        return
    end

    -- When viewing another character: render their stored snapshot instead of
    -- calling live WoW APIs which only return the logged-in player's data.
    if Addon._viewingChar then
        local snap = db.trackingSnapshot
        if snap then
            if TI.RenderSnapshotIntoPanel then TI.RenderSnapshotIntoPanel(snap) end
            ResizeTrackingPanelToContent(self)
        end
        return
    end

    -- Normal path: read live WoW APIs for the current player.
    if FEATURE_GREAT_VAULT and TI.ApplyGreatVaultGrid and TI.GetGreatVaultGridData then
        TI.ApplyGreatVaultGrid(TI.GetGreatVaultGridData())
    end
    if TI.ApplyRightColumnAsPairs then TI.ApplyRightColumnAsPairs() end
    ResizeTrackingPanelToContent(self)

    -- Persist the rendered output so the char picker can show it when another
    -- character is viewing this one.
    if TI.SaveTrackingSnapshot then TI.SaveTrackingSnapshot(db) end
end

function Addon:ResizeTrackingCols()
    -- Reflow column widths and, when weeklies occupies a column slot, position it too.
    local tf = self._trackingFrame
    if not tf then return end

    local frameW  = tonumber(tf:GetWidth()) or Addon.UI.frameW
    local padL    = tonumber(tf._lariasPadL)   or 10
    local padR    = tonumber(tf._lariasPadR)   or 10
    local colGap  = tonumber(tf._lariasColGap) or 12
    local leftCol  = tf._lariasLeftCol
    local rightCol = tf._lariasRightCol
    local ws       = tf._lariasWeekliesSection
    local wMode    = tf._weekliesMode or "hidden"

    local leftShown  = leftCol  and leftCol.IsShown  and leftCol:IsShown()  or false
    local rightShown = rightCol and rightCol.IsShown and rightCol:IsShown() or false
    local wShown     = ws and ws.IsShown and ws:IsShown() or false

    -- "Two-slot" layout: GV+Currency, GV+Weeklies, or Currency+Weeklies side by side.
    local sideMode   = (wMode == "side-right" or wMode == "side-left")
    local hasTwoSlots = (leftShown and rightShown) or sideMode

    local newColW
    if hasTwoSlots then
        newColW = math.max(10, math.floor((frameW - padL - padR - colGap) / 2))
    else
        newColW = math.max(10, math.floor(frameW - padL - padR))
    end

    if leftShown  and leftCol.SetWidth  then leftCol:SetWidth(newColW)  end
    if rightShown and rightCol.SetWidth then rightCol:SetWidth(newColW) end

    -- Re-anchor leftCol (GV) right of rightCol (Currency) when both are visible.
    if leftShown and rightShown then
        leftCol:ClearAllPoints()
        leftCol:SetPoint("TOPLEFT", rightCol, "TOPRIGHT", colGap, 0)
    end

    -- Position + size weeklies for side / full modes.
    -- ("below" mode anchors are set by ApplyTrackingPanelOptions; skip here.)
    if wShown and wMode ~= "below" then
        ws:ClearAllPoints()
        if wMode == "side-right" then
            -- Currency on the left; weeklies on the right at the same slot.
            ws:SetWidth(newColW)
            ws:SetPoint("TOPLEFT", tf, "TOPLEFT", padL + newColW + colGap, -32)
        elseif wMode == "side-left" then
            -- Weeklies on the left; Currency (rightCol) on the right.
            ws:SetWidth(newColW)
            ws:SetPoint("TOPLEFT", tf, "TOPLEFT", padL, -32)
            -- Place rightCol (Currency) in the right slot.
            if rightShown and rightCol then
                rightCol:ClearAllPoints()
                rightCol:SetWidth(newColW)
                rightCol:SetPoint("TOPLEFT", tf, "TOPLEFT", padL + newColW + colGap, -32)
            end
            -- GV (leftCol) placed right when GV is also on in side-left mode.
            if leftShown and leftCol then
                leftCol:ClearAllPoints()
                leftCol:SetWidth(newColW)
                leftCol:SetPoint("TOPLEFT", tf, "TOPLEFT", padL + newColW + colGap, -32)
            end
        elseif wMode == "full" then
            local fullW = math.max(10, math.floor(frameW - 2 * WSEC_PAD_LR))
            ws:SetWidth(fullW)
            ws:SetPoint("TOPLEFT", tf, "TOPLEFT", WSEC_PAD_LR, -32)
        end
    end

    -- Update title widths and anchors.
    local leftTitle  = tf._lariasLeftTitle
    local rightTitle = tf._lariasRightTitle
    if leftTitle  and leftTitle.SetWidth  then leftTitle:SetWidth(newColW) end
    if rightTitle and rightTitle.SetWidth then
        rightTitle:SetWidth(newColW)
        if rightCol then
            rightTitle:ClearAllPoints()
            rightTitle:SetPoint("TOP", rightCol, "TOP", 0, 24)
        end
    end
    -- Weeklies title width matches its column slot.
    if ws and ws._hdrFS and ws._hdrFS.SetWidth then
        ws._hdrFS:SetWidth(newColW)
    end

    tf._lariasColW = newColW
end
