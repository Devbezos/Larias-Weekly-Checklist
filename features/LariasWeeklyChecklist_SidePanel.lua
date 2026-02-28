-- LariasWeeklyChecklist_SidePanel.lua
-- Panel anchored to the LEFT of the main window.
-- Sections: Weeklies (quest auto-detect), Rares (combat-log), Treasures (manual toggle).
-- Each section header is clickable to collapse/expand.  If all are collapsed the panel hides.
local addonName = ...
local Addon = _G[addonName]
if not Addon then return end

-- ── Layout ───────────────────────────────────────────────────────────────────
local PANEL_W  = 215    -- outer panel width (px)
local PANEL_GAP = 4     -- gap between main frame right edge and panel left edge
local PAD      = 8      -- horizontal inner padding
local ROW_H    = 17     -- data row height
local SEC_H    = 22     -- top-level section header height (Weeklies / Rares / Treasures)
local ZONE_H   = 18     -- zone sub-header height
local SBAR_W   = 16     -- scrollbar width reservation

-- ── Week-key (approximate Tuesday reset boundary) ────────────────────────────
-- Epoch = Thursday Jan 1 1970.  +5 days makes bucket edges fall on Tuesdays.
local SECS_PER_WEEK = 7 * 24 * 3600
local WEEK_OFF      = 5 * 24 * 3600
local function GetWeekKey()
    return math.floor((GetServerTime() + WEEK_OFF) / SECS_PER_WEEK)
end

-- ── Per-character DB ──────────────────────────────────────────────────────────
local function GetCDB()
    local cdb = Addon:EnsureDB()
    if cdb.rareKills    == nil then cdb.rareKills    = {} end
    if cdb.treasuresFound == nil then cdb.treasuresFound = {} end
    return cdb
end

local function IsRareKilled(npcID)
    local wk = GetCDB().rareKills[GetWeekKey()]
    return wk and wk[npcID] == true
end

local function MarkRareKilled(npcID)
    local cdb  = GetCDB()
    local week = GetWeekKey()
    if not cdb.rareKills[week] then cdb.rareKills[week] = {} end
    cdb.rareKills[week][npcID] = true
end

local function IsTreasureFound(objectID)
    return GetCDB().treasuresFound[objectID] == true
end

local function ToggleTreasure(objectID)
    local cdb = GetCDB()
    cdb.treasuresFound[objectID] = (not cdb.treasuresFound[objectID]) or nil
end

local function PruneOldRareKills()
    local cdb  = GetCDB()
    local week = GetWeekKey()
    for k in pairs(cdb.rareKills) do
        if k ~= week then cdb.rareKills[k] = nil end
    end
end

-- ── Quest helpers (re-used from Weeklies popup pattern) ───────────────────────
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

-- ── Names lookup (IDs are in Constants.lua; names are display-only) ───────────
local RARE_NAMES = {
    eversongWoods = {
        [246332]="Warden of Weeds",      [240129]="Overfester Hydra",
        [250719]="Cre'van",              [250754]="Lady Liminus",
        [250841]="Bad Zed",              [250826]="Banuran",
        [255302]="Duskburn",             [255348]="Dame Bloodshed",
        [246633]="Harried Hawkstrider",  [250582]="Bloated Snapdragon",
        [250683]="Coralfang",            [250876]="Terrinor",
        [250780]="Waverly",              [250788]="Lovely Sunflower",
        [250806]="Lost Guardian",        [255329]="Malfunctioning Construct",
    },
    zulaman = {
        [242023]="Necrohexxer Raz'ka",   [242025]="Skullcrusher Harak",
        [245975]="Mrrlokk",              [242031]="Spinefrill",
        [242033]="Tiny Vermin",          [242035]="The Devouring Invader",
        [242027]="Depthborn Eelamental", [242024]="The Snapping Scourge",
        [242028]="Lightwood Borer",      [247976]="Poacher Rav'ik",
        [242032]="Oophaga",              [242034]="Voidtouched Crustacean",
        [242026]="Elder Oaktalon",       [245692]="Ash'an the Empowered",
        [245691]="The Decaying Diamondback", [246122]="Worm Wrangler",
    },
    harandar = {
        [248741]="Rhazul",               [249849]="Ha'kalawe",
        [249962]="Queen Lashtongue",     [250226]="Mindrot",
        [250246]="Treetop",              [250321]="Pterrock",
        [249844]="Chironex",             [249902]="Tallcap the Truthspreader",
        [249997]="Chlorokyll",           [250180]="Serrasa",
        [250231]="Dracaena",             [250347]="Ahl'ua'huhi",
        [250086]="Stumpy",               [250358]="Annulus the Worldshaker",
        [250317]="Oro'ohna",
    },
    voidstorm = {
        [244272]="Sundereth the Caller", [241443]="Tremora",
        [256923]="Bane of the Vilebloods",[256925]="Lotus Darkblossom",
        [256770]="Bilemaw the Gluttonous",[245044]="Nightbrood",
        [238498]="Territorial Voidscythe",[256922]="Screammaxa the Matriarch",
        [256924]="Aeonelle Blackstar",   [256926]="Queen o' War",
        [245182]="Eruundi",              [257027]="Rakshur the Bonegrinder",
        [256808]="Ravengerus",           [256821]="Far'thana the Mad",
    },
}

local TREASURE_NAMES = {
    eversongWoods = {
        [617881]="Rookery Cache",           [613697]="Gift of the Phoenix",
        [617534]="Gilded Armillary Sphere", [613267]="Farstrider's Lost Quiver",
        [555351]="Burbling Paint Pot",      [613252]="Triple-Locked Safebox",
        [617432]="Forgotten Ink and Quill", [613242]="Antique Nobleman's Signet Ring",
        [587307]="Stone Vat",
    },
    zulaman = {
        [539047]="Abandoned Ritual Skull",  [617659]="Sealed Twilight's Blade Bounty",
        [539050]="Burrow Bounty",           [539052]="Secret Formula",
        [613727]="Honored Warrior's Cache", [539049]="Bait and Tackle",
        [539051]="Mrruk's Mangy Trove",     [539053]="Abandoned Nest",
    },
    harandar = {
        [572958]="Failed Shroom Jumper's Satchel",[573050]="Sporelord's Fight Prize",
        [573307]="Kemet's Simmering Cauldron",    [572998]="Burning Branch of the World Tree",
        [614483]="Peculiar Cauldron",             [616052]="Flame-Hardened Sap of Teldrassil",
        [573095]="Reliquary's Lost Paint Supplies",[590789]="Altar of Wisdom",
        [589202]="Altar of Vigor",                [588929]="Altar of Innocence",
        [615908]="Fungal Mallet",                 [615907]="Mycelium Gong",
    },
    voidstorm = {
        [605169]="Final Clutch of Predaxas",  [612891]="Bloody Sack",
        [613368]="Quivering Egg",             [613351]="Discarded Energy Pike",
        [613317]="Half-Digested Viscera",     [572819]="Void-Shielded Tomb",
        [572893]="Potion of Dissociation",    [555250]="Forgotten Researcher's Cache",
        [612270]="Embedded Spear",            [613358]="Exaliburn",
        [613852]="Potion of Unquestionable Strength",
    },
}

local ZONES_ORDER = { "eversongWoods", "zulaman", "harandar", "voidstorm" }
local ZONE_LABELS = {
    eversongWoods = "Eversong Woods",
    zulaman       = "Zul'Aman",
    harandar      = "Harandar",
    voidstorm     = "The Voidstorm",
}

-- ── Combat-log rare detection ─────────────────────────────────────────────────
local _rareSet = nil
local function GetRareSet()
    if _rareSet then return _rareSet end
    _rareSet = {}
    local rares = Addon.TRACKING and Addon.TRACKING.rares
    if not rares then return _rareSet end
    for _, zone in pairs(rares) do
        for _, id in ipairs(zone) do _rareSet[id] = true end
    end
    return _rareSet
end

-- Creature GUID: "Creature-0-ServerID-InstanceID-ZoneUID-SpawnUID-EntryID"
-- The EntryID (NPC ID) is always the last numeric segment.
local function NpcIDFromGUID(guid)
    if type(guid) ~= "string" then return nil end
    local id = tonumber(guid:match("%-(%d+)$"))
    return (id and id > 0) and id or nil
end

-- ── Module-level event frames ───────────────────────────────────────────────
-- Frames are created at file-load time but RegisterEvent is deferred until
-- Addon:OnEnable via RegisterSidePanelEventListeners() below.  This avoids
-- ADDON_ACTION_FORBIDDEN for Frame:RegisterEvent() on Classic game flavours
-- where RegisterEvent is a protected function.
local _onRareDied    = nil   -- function() called after a tracked rare dies
local _onQuestUpdate = nil   -- function() called on quest log events

local _clfFrame = CreateFrame("Frame")
_clfFrame:SetScript("OnEvent", function()
    if not _onRareDied then return end
    local _, subevent, _, _, _, _, _, destGUID = CombatLogGetCurrentEventInfo()
    if subevent ~= "UNIT_DIED" then return end
    local npcID = NpcIDFromGUID(destGUID)
    if npcID and GetRareSet()[npcID] then
        MarkRareKilled(npcID)
        _onRareDied()
    end
end)

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
    _clfFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    _questFrame:RegisterEvent("QUEST_TURNED_IN")
    _questFrame:RegisterEvent("QUEST_LOG_UPDATE")
end

-- ── Section gap ──────────────────────────────────────────────────────────────
local SEC_GAP = 6   -- vertical gap between sections

-- ── Row widgets ───────────────────────────────────────────────────────────────
-- countFS is nil when there is no count to display (e.g. Treasures zone headers).
local function MakeZoneHdr(parent, text, posY, showCount)
    local COUNT_W = showCount and 44 or 0
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT",  parent, "TOPLEFT",   PAD,                  -posY)
    fs:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -(SBAR_W + COUNT_W),   -posY)
    fs:SetHeight(ZONE_H)
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("MIDDLE")
    fs:SetTextColor(0.85, 0.75, 0.30, 1)
    fs:SetText(text)

    local countFS
    if showCount then
        countFS = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        countFS:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -SBAR_W, -posY)
        countFS:SetSize(COUNT_W, ZONE_H)
        countFS:SetJustifyH("RIGHT")
        countFS:SetJustifyV("MIDDLE")
        countFS:SetTextColor(0.85, 0.75, 0.30, 1)
    end
    return posY + ZONE_H, countFS
end

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

-- Returns (row, newPosY).  row exposes .lbl and .box (colored rect) for refresh.
local BOX_W, BOX_H = 10, 10
local function MakeRareRow(parent, npcID, posY)
    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lbl:SetPoint("TOPLEFT",  parent, "TOPLEFT",   PAD * 2,  -posY)
    lbl:SetPoint("TOPRIGHT", parent, "TOPRIGHT",  -(SBAR_W + BOX_W + 6), -posY)
    lbl:SetHeight(ROW_H)
    lbl:SetJustifyH("LEFT")
    lbl:SetJustifyV("MIDDLE")
    if lbl.SetWordWrap then lbl:SetWordWrap(false) end

    -- Colored rectangle status indicator
    local box = parent:CreateTexture(nil, "ARTWORK")
    box:SetSize(BOX_W, BOX_H)
    box:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -(SBAR_W + 2), -(posY + (ROW_H - BOX_H) / 2))
    box:SetColorTexture(1, 0.25, 0.25, 0.7)  -- default: red (not killed)

    return { lbl = lbl, box = box, npcID = npcID }, posY + ROW_H
end

-- Returns (row, newPosY).  Clicking toggles treasure found state.
local function MakeTreasureRow(parent, objectID, posY)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetPoint("TOPLEFT",  parent, "TOPLEFT",   0,       -posY)
    btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -SBAR_W,  -posY)
    btn:SetHeight(ROW_H)
    btn:RegisterForClicks("AnyUp")

    local box = btn:CreateTexture(nil, "ARTWORK")
    box:SetSize(10, 10)
    box:SetPoint("LEFT", btn, "LEFT", PAD * 2, 0)
    box:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")

    local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lbl:SetPoint("LEFT",  box, "RIGHT", 3, 0)
    lbl:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
    lbl:SetHeight(ROW_H)
    lbl:SetJustifyH("LEFT")
    lbl:SetJustifyV("MIDDLE")
    if lbl.SetWordWrap then lbl:SetWordWrap(false) end

    local function Refresh()
        local found = IsTreasureFound(objectID)
        local hideCompleted = Addon:EnsurePrefs().hideCompletedSections
        box:SetVertexColor(1, 1, 1, found and 1 or 0.15)
        if found then
            lbl:SetTextColor(0.40, 1, 0.40, 0.80)
        else
            lbl:SetTextColor(1, 1, 1, 1)
        end
        btn:SetShown(not (hideCompleted and found))
    end

    btn:SetScript("OnClick", function()
        ToggleTreasure(objectID)
        Refresh()
    end)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local tip = IsTreasureFound(objectID) and "Click to unmark" or "Click to mark as found"
        GameTooltip:SetText(tip, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    return { btn = btn, box = box, lbl = lbl, objectID = objectID, Refresh = Refresh },
           posY + ROW_H
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

    local showWeeklies  = prefs.showSidePanelWeeklies  ~= false
    local showRares     = prefs.showSidePanelRares     ~= false
    local showTreasures = prefs.showSidePanelTreasures ~= false

    local weeklyRows         = {}
    local rareRows           = {}
    local treasureRowObjects = {}
    local zoneCountFS        = {}   -- [zoneKey] = { fs=FontString, total=n }
    local builtSections      = {}
    local prevFrame          = nil

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

    -- ── Rares ─────────────────────────────────────────────────────────────────
    if showRares then
        local sec = MakeSection(sc, L.SIDE_PANEL_RARES or "Rares", prevFrame)
        sec.onToggle = UpdateLayout
        tinsert(builtSections, sec)
        prevFrame = sec.frame

        local content  = sec.content
        local posY     = 0
        local rareData = Addon.TRACKING and Addon.TRACKING.rares
        if rareData then
            for _, zoneKey in ipairs(ZONES_ORDER) do
                local ids = rareData[zoneKey]
                if ids and #ids > 0 then
                    local cfs
                    posY, cfs = MakeZoneHdr(content, ZONE_LABELS[zoneKey] or zoneKey, posY, true)
                    zoneCountFS[zoneKey] = { fs = cfs, total = #ids }
                    local names = RARE_NAMES[zoneKey] or {}
                    for _, npcID in ipairs(ids) do
                        local r
                        r, posY = MakeRareRow(content, npcID, posY)
                        r.lbl:SetText(names[npcID] or ("NPC #" .. npcID))
                        r.zoneKey = zoneKey
                        tinsert(rareRows, r)
                    end
                end
            end
        end
        sec:FinalizeHeight(posY + 4)
    end

    -- ── Treasures ─────────────────────────────────────────────────────────────
    if showTreasures then
        local sec = MakeSection(sc, L.SIDE_PANEL_TREASURES or "Treasures", prevFrame)
        sec.onToggle = UpdateLayout
        tinsert(builtSections, sec)
        prevFrame = sec.frame

        local content      = sec.content
        local posY         = 0
        local treasureData = Addon.TRACKING and Addon.TRACKING.treasures
        if treasureData then
            for _, zoneKey in ipairs(ZONES_ORDER) do
                local ids = treasureData[zoneKey]
                if ids and #ids > 0 then
                    posY = MakeZoneHdr(content, ZONE_LABELS[zoneKey] or zoneKey, posY)
                    local names = TREASURE_NAMES[zoneKey] or {}
                    for _, objID in ipairs(ids) do
                        local r
                        r, posY = MakeTreasureRow(content, objID, posY)
                        r.lbl:SetText(names[objID] or ("Obj #" .. objID))
                        r.Refresh()
                        tinsert(treasureRowObjects, r)
                    end
                end
            end
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

    local function RefreshRareRows()
        local hideCompleted = Addon:EnsurePrefs().hideCompletedSections
        local zoneDone = {}
        for _, r in ipairs(rareRows) do
            local npcID = r.npcID
            if npcID then
                local killed = IsRareKilled(npcID)
                if killed then
                    zoneDone[r.zoneKey] = (zoneDone[r.zoneKey] or 0) + 1
                    r.box:SetColorTexture(0.25, 1.0, 0.25, 1.0)
                    r.lbl:SetTextColor(0.50, 0.90, 0.50, 0.80)
                else
                    r.box:SetColorTexture(1.0, 0.25, 0.25, 0.7)
                    r.lbl:SetTextColor(1, 1, 1, 1)
                end
                local visible = not (hideCompleted and killed)
                r.lbl:SetShown(visible)
                r.box:SetShown(visible)
            end
        end
        -- update per-zone x/y header counts
        for zoneKey, info in pairs(zoneCountFS) do
            local done  = zoneDone[zoneKey] or 0
            local total = info.total
            local col   = (done >= total and total > 0) and GREEN
                       or  done > 0                     and "|cffffd700"
                       or  DIM
            info.fs:SetText(col .. done .. "/" .. total .. CLOSE)
        end
    end

    local function RefreshAll()
        if showWeeklies  then RefreshWeeklyRows() end
        if showRares     then RefreshRareRows()   end
        for _, r in ipairs(treasureRowObjects) do r.Refresh() end
    end

    panel.RefreshAll = RefreshAll

    -- ── Wire module-level event dispatch to this panel's refresh functions ────
    if showRares then
        _onRareDied = RefreshRareRows
    end
    if showWeeklies then
        _onQuestUpdate = function()
            if panel:IsShown() then RefreshWeeklyRows() end
        end
    end

    panel:SetScript("OnShow", function()
        PruneOldRareKills()
        RefreshAll()
    end)

    if panel:IsShown() then
        PruneOldRareKills()
        RefreshAll()
    end

    return panel
end

-- ── Public API ────────────────────────────────────────────────────────────────

function Addon:CreateSidePanel(mainFrame)
    if self._sidePanel then return end
    self._sidePanelMainFrame = mainFrame
    local prefs   = self:EnsurePrefs()
    local showAny = prefs.showSidePanelWeeklies  ~= false
                 or prefs.showSidePanelRares      ~= false
                 or prefs.showSidePanelTreasures  ~= false
    if not showAny then return end
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
    _rareSet       = nil   -- force rebuild of the NPC ID set
    _onRareDied    = nil   -- detach event dispatch before recreating
    _onQuestUpdate = nil
    if mainFrame then
        self:CreateSidePanel(mainFrame)
        if self._sidePanel and mainFrame:IsShown() then
            self._sidePanel:Show()
            self._sidePanel.RefreshAll()
        end
    end
end
