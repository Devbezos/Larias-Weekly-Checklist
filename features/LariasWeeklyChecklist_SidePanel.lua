-- LariasWeeklyChecklist_SidePanel.lua
-- Panel anchored to the right of the main window.
-- Sections: Weeklies (quest auto-detect), Rares (combat-log), Treasures (manual toggle).
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
        return ok and (done and true or false) or nil
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

-- ── Row widgets ───────────────────────────────────────────────────────────────
local function MakeSectionHdr(parent, text, posY)
    local T = Addon.THEME
    local bar = parent:CreateTexture(nil, "BACKGROUND")
    bar:SetPoint("TOPLEFT",  parent, "TOPLEFT",     0,      -posY)
    bar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -SBAR_W,   -posY)
    bar:SetHeight(SEC_H)
    bar:SetColorTexture(T.bg.r * 2.2, T.bg.g * 2.0, T.bg.b * 1.6, 0.95)

    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", bar, "TOPLEFT", PAD, 0)
    fs:SetSize(PANEL_W - PAD - SBAR_W, SEC_H)
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("MIDDLE")
    fs:SetTextColor(T.header.r, T.header.g, T.header.b, T.header.a)
    fs:SetText(text)
    return posY + SEC_H
end

local function MakeZoneHdr(parent, text, posY)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT",  parent, "TOPLEFT",    PAD,    -posY)
    fs:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -SBAR_W,  -posY)
    fs:SetHeight(ZONE_H)
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("MIDDLE")
    fs:SetTextColor(0.85, 0.75, 0.30, 1)
    fs:SetText(text)
    return posY + ZONE_H
end

-- Returns (row, newPosY).  row exposes ._lbl and ._val for refresh.
local function MakeRareRow(parent, npcID, posY)
    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lbl:SetPoint("TOPLEFT",  parent, "TOPLEFT",   PAD * 2,  -posY)
    lbl:SetPoint("TOPRIGHT", parent, "TOPRIGHT",  -36,      -posY)
    lbl:SetHeight(ROW_H)
    lbl:SetJustifyH("LEFT")
    lbl:SetJustifyV("MIDDLE")
    if lbl.SetWordWrap then lbl:SetWordWrap(false) end

    local val = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    val:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -SBAR_W - 2, -posY)
    val:SetSize(30, ROW_H)
    val:SetJustifyH("RIGHT")
    val:SetJustifyV("MIDDLE")

    return { lbl = lbl, val = val, npcID = npcID }, posY + ROW_H
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
        box:SetVertexColor(1, 1, 1, found and 1 or 0.15)
        if found then
            lbl:SetTextColor(0.40, 1, 0.40, 0.80)
        else
            lbl:SetTextColor(1, 1, 1, 1)
        end
    end

    btn:SetScript("OnClick", function()
        ToggleTreasure(objectID)
        Refresh()
    end)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        local tip = IsTreasureFound(objectID) and "Click to unmark" or "Click to mark as found"
        GameTooltip:SetText(tip, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    return { btn = btn, box = box, lbl = lbl, objectID = objectID, Refresh = Refresh },
           posY + ROW_H
end

-- ── Panel builder ─────────────────────────────────────────────────────────────
local function BuildSidePanel(mainFrame)
    local L     = Addon.L or {}
    local prefs = Addon:EnsurePrefs()
    local T     = Addon.THEME

    -- Outer panel frame (child of mainFrame → moves with it)
    local panel = CreateFrame("Frame", "LariasWeeklySidePanelFrame", mainFrame)
    panel:SetPoint("TOPLEFT",    mainFrame, "TOPRIGHT",    PANEL_GAP,  0)
    panel:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMRIGHT", PANEL_GAP,  0)
    panel:SetWidth(PANEL_W)
    Addon:ApplyTheme(panel)

    -- Scroll frame (fills the panel; 4px top/bottom insets)
    local sf = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT",     panel, "TOPLEFT",     0,    0)
    sf:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0,    0)

    local sc = CreateFrame("Frame", nil, sf)
    sc:SetWidth(PANEL_W)
    sc:SetHeight(200) -- will be set after building rows
    sf:SetScrollChild(sc)

    -- ── Build content ─────────────────────────────────────────────────────────
    local posY      = 4                -- cursor: pixels from top of scroll child
    local rareRows  = {}               -- { row, ... } for refresh
    local showWeeklies  = prefs.showSidePanelWeeklies  ~= false
    local showRares     = prefs.showSidePanelRares     ~= false
    local showTreasures = prefs.showSidePanelTreasures ~= false

    -- ── Weeklies section ──────────────────────────────────────────────────────
    local weeklyRows = {}
    if showWeeklies then
        posY = MakeSectionHdr(sc, L.SIDE_PANEL_WEEKLIES or "Weeklies", posY)

        local QIDs   = Addon.TRACKING and Addon.TRACKING.questIDs or {}
        local PQIDs  = Addon.TRACKING and Addon.TRACKING.preyQuestIDs
        local pGoal  = (Addon.TRACKING and Addon.TRACKING.preyQuestGoal) or 4

        -- Prey count row
        local preyRow
        preyRow, posY = MakeRareRow(sc, nil, posY)
        preyRow.isPrey   = true
        preyRow.pGoal    = pGoal
        preyRow.pQuestIDs = PQIDs
        preyRow.lbl:SetText(L.TRACKING_QUEST_PREY or "Prey Hunted")
        tinsert(weeklyRows, preyRow)

        -- 5 seasonal quest rows
        local defs = {
            { key = "abundance",         label = L.TRACKING_QUEST_ABUNDANCE          or "Abundance" },
            { key = "lostLegends",       label = L.TRACKING_QUEST_LOST_LEGENDS       or "Lost Legends" },
            { key = "highEsteem",        label = L.TRACKING_QUEST_HIGH_ESTEEM        or "High Esteem" },
            { key = "fortifyRunestones", label = L.TRACKING_QUEST_FORTIFY_RUNESTONES or "Fortify the Runestones" },
            { key = "standYourGround",   label = L.TRACKING_QUEST_STAND_YOUR_GROUND  or "Stand Your Ground" },
        }
        for _, d in ipairs(defs) do
            local r
            r, posY = MakeRareRow(sc, nil, posY)
            r.questKey   = d.key
            r.questEntry = QIDs[d.key]
            r.lbl:SetText(d.label)
            tinsert(weeklyRows, r)
        end
    end

    -- ── Rares section ─────────────────────────────────────────────────────────
    if showRares then
        posY = posY + 4  -- gap between sections
        posY = MakeSectionHdr(sc, L.SIDE_PANEL_RARES or "Rares", posY)

        local rareData = Addon.TRACKING and Addon.TRACKING.rares
        if rareData then
            for _, zoneKey in ipairs(ZONES_ORDER) do
                local ids = rareData[zoneKey]
                if ids and #ids > 0 then
                    posY = MakeZoneHdr(sc, ZONE_LABELS[zoneKey] or zoneKey, posY)
                    local names = RARE_NAMES[zoneKey] or {}
                    for _, npcID in ipairs(ids) do
                        local r
                        r, posY = MakeRareRow(sc, npcID, posY)
                        r.lbl:SetText(names[npcID] or ("NPC #" .. npcID))
                        tinsert(rareRows, r)
                    end
                end
            end
        end
    end

    -- ── Treasures section ─────────────────────────────────────────────────────
    local treasureRowObjects = {}
    if showTreasures then
        posY = posY + 4
        posY = MakeSectionHdr(sc, L.SIDE_PANEL_TREASURES or "Treasures", posY)

        local treasureData = Addon.TRACKING and Addon.TRACKING.treasures
        if treasureData then
            for _, zoneKey in ipairs(ZONES_ORDER) do
                local ids = treasureData[zoneKey]
                if ids and #ids > 0 then
                    posY = MakeZoneHdr(sc, ZONE_LABELS[zoneKey] or zoneKey, posY)
                    local names = TREASURE_NAMES[zoneKey] or {}
                    for _, objID in ipairs(ids) do
                        local r
                        r, posY = MakeTreasureRow(sc, objID, posY)
                        r.lbl:SetText(names[objID] or ("Obj #" .. objID))
                        r.Refresh()  -- set initial visual state
                        tinsert(treasureRowObjects, r)
                    end
                end
            end
        end
    end

    posY = posY + 8
    sc:SetHeight(posY)

    -- ── Refresh: update quest/rare row values ─────────────────────────────────
    local GREEN = "|cff40ff40"
    local RED   = "|cffff4040"
    local DIM   = "|cff808080"
    local CLOSE = "|r"

    local function RefreshWeeklyRows()
        local QIDs  = Addon.TRACKING and Addon.TRACKING.questIDs or {}
        local PQIDs = Addon.TRACKING and Addon.TRACKING.preyQuestIDs
        local pGoal = (Addon.TRACKING and Addon.TRACKING.preyQuestGoal) or 4
        for _, r in ipairs(weeklyRows) do
            if r.isPrey then
                -- Count prey quests
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
                local col = count >= pGoal and GREEN or RED
                r.val:SetText(col .. count .. "/" .. pGoal .. CLOSE)
            elseif r.questKey then
                local entry = QIDs[r.questKey]
                local done  = entry and QuestDoneAny(entry)
                if done == nil then
                    r.val:SetText(DIM .. (L.TRACKING_NA or "N/A") .. CLOSE)
                elseif done then
                    r.val:SetText(GREEN .. "1/1" .. CLOSE)
                else
                    r.val:SetText(RED .. "0/1" .. CLOSE)
                end
            end
        end
    end

    local function RefreshRareRows()
        for _, r in ipairs(rareRows) do
            local npcID = r.npcID
            if npcID then
                if IsRareKilled(npcID) then
                    r.val:SetText(GREEN .. "Done" .. CLOSE)
                    r.lbl:SetTextColor(0.50, 0.90, 0.50, 0.80)
                else
                    r.val:SetText(RED .. "---" .. CLOSE)
                    r.lbl:SetTextColor(1, 1, 1, 1)
                end
            end
        end
    end

    local function RefreshAll()
        if showWeeklies  then RefreshWeeklyRows() end
        if showRares     then RefreshRareRows()   end
        -- treasure rows are self-refreshing via click; run initial pass on show
        for _, r in ipairs(treasureRowObjects) do r.Refresh() end
    end

    panel.RefreshAll = RefreshAll

    -- ── Combat-log event for rare auto-detection ──────────────────────────────
    if showRares then
        local clf = CreateFrame("Frame", nil, panel)
        clf:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        clf:SetScript("OnEvent", function()
            local _, subevent, _, _, _, _, _, destGUID = CombatLogGetCurrentEventInfo()
            if subevent ~= "UNIT_DIED" then return end
            local npcID = NpcIDFromGUID(destGUID)
            if npcID and GetRareSet()[npcID] then
                MarkRareKilled(npcID)
                RefreshRareRows()
            end
        end)
    end

    -- ── Quest events for weekly auto-detection ────────────────────────────────
    if showWeeklies then
        local qf = CreateFrame("Frame", nil, panel)
        qf:RegisterEvent("QUEST_TURNED_IN")
        qf:RegisterEvent("QUEST_LOG_UPDATE")
        qf:SetScript("OnEvent", function()
            if panel:IsShown() then RefreshWeeklyRows() end
        end)
    end

    panel:SetScript("OnShow", function()
        PruneOldRareKills()
        RefreshAll()
    end)

    -- Initial refresh if already visible
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
    if mainFrame then
        self:CreateSidePanel(mainFrame)
        if self._sidePanel and mainFrame:IsShown() then
            self._sidePanel:Show()
            self._sidePanel.RefreshAll()
        end
    end
end
