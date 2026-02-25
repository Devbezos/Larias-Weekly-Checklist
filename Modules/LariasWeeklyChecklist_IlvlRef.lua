-- LariasWeeklyChecklist_IlvlRef.lua
-- Standalone popup window: Midnight Season 1 item-level reference tables.
-- Opened/closed via the "Item Levels" button in the main frame.

local addonName = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(addonName, true)
if not Addon then return end

local CreateFrame = CreateFrame
local max = math.max

-- â”€â”€ Layout constants â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
local WIN_W    = 490   -- popup window width
local WIN_H    = 540   -- popup window height
local PAD      = 14    -- outer content padding
local ROW_H    = 18    -- height of one data row
local SEC_GAP  = 14    -- gap between sections
local HDR_H    = 22    -- section heading height
local SUBHDR_H = 18    -- column sub-header height
local SCROLLTOP = 32   -- pixels from win top to scroll frame

-- â”€â”€ Crest color escape codes â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
local ADV   = "|cFF1EFF00"   -- Adventurer  (green)
local VET   = "|cFF0070DD"   -- Veteran     (blue)
local CHAMP = "|cFFA335EE"   -- Champion    (purple)
local HERO  = "|cFFFF8000"   -- Hero        (orange)
local MYTH  = "|cFFFF2020"   -- Myth/Gilded (red)
local R     = "|r"

-- â”€â”€ Build helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

-- Create a FontString anchored at (x, posY) from parent's TOPLEFT.
-- fontObj, r/g/b/a, w, align are optional.
local function FS(parent, x, posY, text, fontObj, r, g, b, a, w, align)
    local fs = parent:CreateFontString(nil, "ARTWORK", fontObj or "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, posY)
    if w     then fs:SetWidth(w) end
    if align then fs:SetJustifyH(align) end
    if r     then fs:SetTextColor(r, g, b, a or 1) end
    if fs.SetWordWrap then fs:SetWordWrap(false) end
    fs:SetText(text ~= nil and tostring(text) or "")
    return fs
end

-- Draw a 1 px horizontal rule and return the new posY.
local function HRule(parent, posY)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetColorTexture(
        Addon.THEME.border.r, Addon.THEME.border.g,
        Addon.THEME.border.b, Addon.THEME.border.a * 0.6)
    t:SetHeight(1)
    t:SetPoint("TOPLEFT",  parent, "TOPLEFT",  0,  posY)
    t:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0,  posY)
    return posY - 4
end

-- Draw a gold section heading and return the new posY.
local function SecHead(parent, posY, text)
    local c = Addon.THEME.header
    FS(parent, 0, posY, text, "GameFontNormal", c.r, c.g, c.b, c.a)
    return posY - HDR_H
end

-- Draw a dim column-header row and return the new posY.
-- cols = array of { x, w, t, align }
local function ColHead(parent, posY, cols)
    local c = Addon.THEME.textDim
    for _, col in ipairs(cols) do
        FS(parent, col.x, posY, col.t, "GameFontHighlightSmall",
           c.r, c.g, c.b, c.a, col.w, col.align)
    end
    return posY - SUBHDR_H
end

-- Draw a data row and return the new posY.
-- cols = array of { x, w, t, align, r, g, b, a }
local function DataRow(parent, posY, cols)
    for _, col in ipairs(cols) do
        FS(parent, col.x, posY, col.t, nil,
           col.r, col.g, col.b, col.a, col.w, col.align)
    end
    return posY - ROW_H
end

-- â”€â”€ Main window builder â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

local function BuildIlvlRefWindow()
    -- â”€â”€ Localised data tables (built here so Addon.L is available) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    local L = Addon.L
    local _or = " " .. (L.ILVLREF_OR or "or") .. " "

    -- Midnight Season 1 upgrade tracks (20 crests per step)
    -- { ilvl (color-coded), track name, crest needed (color-coded) }
    local TRACKS = {
        { ADV.."220"..R,   L.ILVLREF_TRACK_ADV1        or "Adventurer 1",           ADV..(L.ILVLREF_CREST_ADV  or "Adventurer")..R                                                                  },
        { ADV.."224"..R,   L.ILVLREF_TRACK_ADV2        or "Adventurer 2",           ADV..(L.ILVLREF_CREST_ADV  or "Adventurer")..R                                                                  },
        { ADV.."227"..R,   L.ILVLREF_TRACK_ADV3        or "Adventurer 3",           ADV..(L.ILVLREF_CREST_ADV  or "Adventurer")..R                                                                  },
        { ADV.."230"..R,   L.ILVLREF_TRACK_ADV4        or "Adventurer 4",           ADV..(L.ILVLREF_CREST_ADV  or "Adventurer")..R                                                                  },
        { ADV.."233"..R,   L.ILVLREF_TRACK_ADV5_VET1   or "Adventurer 5 / Veteran 1", ADV..(L.ILVLREF_CREST_ADV  or "Adventurer")..R                                                               },
        { VET.."237"..R,   L.ILVLREF_TRACK_ADV6_VET2   or "Adventurer 6 / Veteran 2", ADV..(L.ILVLREF_CREST_ADV_SHORT or "Adv")..R.._or..VET..(L.ILVLREF_CREST_VET_SHORT or "Vet")..R           },
        { VET.."240"..R,   L.ILVLREF_TRACK_VET3        or "Veteran 3",              VET..(L.ILVLREF_CREST_VET  or "Veteran")..R                                                                    },
        { VET.."243"..R,   L.ILVLREF_TRACK_VET4        or "Veteran 4",              VET..(L.ILVLREF_CREST_VET  or "Veteran")..R                                                                    },
        { VET.."246"..R,   L.ILVLREF_TRACK_VET5_CHAMP1 or "Veteran 5 / Champion 1", VET..(L.ILVLREF_CREST_VET  or "Veteran")..R                                                                   },
        { VET.."250"..R,   L.ILVLREF_TRACK_VET6_CHAMP2 or "Veteran 6 / Champion 2", VET..(L.ILVLREF_CREST_VET_SHORT or "Vet")..R.._or..CHAMP..(L.ILVLREF_CREST_CHAMP_SHORT or "Champ")..R     },
        { CHAMP.."253"..R, L.ILVLREF_TRACK_CHAMP3       or "Champion 3",             CHAMP..(L.ILVLREF_CREST_CHAMP or "Champion")..R                                                               },
        { CHAMP.."256"..R, L.ILVLREF_TRACK_CHAMP4       or "Champion 4",             CHAMP..(L.ILVLREF_CREST_CHAMP or "Champion")..R                                                               },
        { CHAMP.."259"..R, L.ILVLREF_TRACK_CHAMP5_HERO1 or "Champion 5 / Hero 1",   CHAMP..(L.ILVLREF_CREST_CHAMP or "Champion")..R                                                               },
        { CHAMP.."263"..R, L.ILVLREF_TRACK_CHAMP6_HERO2 or "Champion 6 / Hero 2",   CHAMP..(L.ILVLREF_CREST_CHAMP_SHORT or "Champ")..R.._or..HERO..(L.ILVLREF_CREST_HERO or "Hero")..R         },
        { HERO.."266"..R,  L.ILVLREF_TRACK_HERO3        or "Hero 3",                HERO..(L.ILVLREF_CREST_HERO  or "Hero")..R                                                                     },
        { HERO.."269"..R,  L.ILVLREF_TRACK_HERO4        or "Hero 4",                HERO..(L.ILVLREF_CREST_HERO  or "Hero")..R                                                                     },
        { HERO.."272"..R,  L.ILVLREF_TRACK_HERO5_MYTH1  or "Hero 5 / Myth 1",       HERO..(L.ILVLREF_CREST_HERO  or "Hero")..R                                                                    },
        { HERO.."276"..R,  L.ILVLREF_TRACK_HERO6_MYTH2  or "Hero 6 / Myth 2",       HERO..(L.ILVLREF_CREST_HERO or "Hero")..R.._or..MYTH..(L.ILVLREF_CREST_MYTH or "Myth")..R                  },
        { MYTH.."279"..R,  L.ILVLREF_TRACK_MYTH3        or "Myth 3",                MYTH..(L.ILVLREF_CREST_MYTH  or "Myth")..R                                                                     },
        { MYTH.."282"..R,  L.ILVLREF_TRACK_MYTH4        or "Myth 4",                MYTH..(L.ILVLREF_CREST_MYTH  or "Myth")..R                                                                     },
        { MYTH.."285"..R,  L.ILVLREF_TRACK_MYTH5        or "Myth 5",                MYTH..(L.ILVLREF_CREST_MYTH  or "Myth")..R                                                                     },
        { MYTH.."289"..R,  L.ILVLREF_TRACK_MYTH6        or "Myth 6",                MYTH..(L.ILVLREF_CREST_MYTH  or "Myth")..R                                                                     },
    }

    -- Crafted item levels
    local CRAFTED = {
        { "220", "220", "233", "246", "259", "272" },
        { "224", "224", "237", "250", "263", "276" },
        { "227", "227", "240", "253", "266", "279" },
        { "230", "230", "243", "256", "269", "282" },
        { "233", "233", "246", "259", "272", "285" },
    }

    -- Dungeon item levels
    local dungCrests = L.ILVLREF_DUNGEON_CRESTS or "Champ crests"
    local DUNGEONS = {
        { L.ILVLREF_DUNGEON_HEROIC or "Heroic", "230", "243", CHAMP..dungCrests..R },
        { L.ILVLREF_DUNGEON_MYTHIC or "Mythic", "246", "256", CHAMP..dungCrests..R },
        { "M2",  "250", "259", HERO..(L.ILVLREF_CREST_HERO or "Hero").."  Ã— 10"..R },
        { "M3",  "250", "259", HERO..(L.ILVLREF_CREST_HERO or "Hero").."  Ã— 12"..R },
        { "M4",  "253", "263", HERO..(L.ILVLREF_CREST_HERO or "Hero").."  Ã— 14"..R },
        { "M5",  "256", "263", HERO..(L.ILVLREF_CREST_HERO or "Hero").."  Ã— 16"..R },
        { "M6",  "259", "266", HERO..(L.ILVLREF_CREST_HERO or "Hero").."  Ã— 18"..R },
        { "M7",  "259", "269", MYTH..(L.ILVLREF_CREST_MYTH or "Myth").."  Ã— 10"..R },
        { "M8",  "263", "269", MYTH..(L.ILVLREF_CREST_MYTH or "Myth").."  Ã— 12"..R },
        { "M9",  "263", "269", MYTH..(L.ILVLREF_CREST_MYTH or "Myth").."  Ã— 14"..R },
        { "M10", "266", "272", MYTH..(L.ILVLREF_CREST_MYTH or "Myth").."  Ã— 16"..R },
        { "M11", "266", "272", MYTH..(L.ILVLREF_CREST_MYTH or "Myth").."  Ã— 18"..R },
        { "M12", "266", "272", MYTH..(L.ILVLREF_CREST_MYTH or "Myth").."  Ã— 20"..R },
    }

    -- Raid item levels
    local RAID = {
        { L.ILVLREF_RAID_LFR    or "LFR",    "233", "237", "240", "243" },
        { L.ILVLREF_RAID_NORMAL or "Normal",  "246", "250", "253", "256" },
        { HERO..(L.ILVLREF_RAID_HEROIC or "Heroic")..R, "259", "263", "266", "269" },
        { MYTH..(L.ILVLREF_RAID_MYTHIC or "Mythic")..R, "272", "276", "279", "282" },
    }

    -- Bountiful Delve item levels
    local tFmt = L.ILVLREF_DELVE_TIER_FMT or "T%d"
    local DELVES = {
        { tFmt:format(1),  "220", "â€“",   "233" },
        { tFmt:format(2),  "224", "â€“",   "237" },
        { tFmt:format(3),  "227", "â€“",   "240" },
        { tFmt:format(4),  "230", "237", "243" },
        { tFmt:format(5),  "233", "243", "246" },
        { tFmt:format(6),  "237", "250", "253" },
        { tFmt:format(7),  "250", "256", "256" },
        { tFmt:format(8),  "â€“",   "â€“",   "â€“"   },
        { tFmt:format(9),  "250", "259", "259" },
        { tFmt:format(10), "â€“",   "â€“",   "â€“"   },
        { tFmt:format(11), "â€“",   "â€“",   "â€“"   },
    }

    -- ── Frame ────────────────────────────────────────────────────────────────
    local win
    if BackdropTemplateMixin then
        win = CreateFrame("Frame", "LariasIlvlRefFrame", UIParent, "BackdropTemplate")
    else
        win = CreateFrame("Frame", "LariasIlvlRefFrame", UIParent)
        if BackdropTemplateMixin and Mixin and not win.SetBackdrop then
            Mixin(win, BackdropTemplateMixin)
        end
    end

    win:SetSize(WIN_W, WIN_H)
    win:SetPoint("CENTER", UIParent, "CENTER", 260, 0)  -- offset right so it doesn't cover the checklist
    win:SetClampedToScreen(true)
    win:SetMovable(true)
    win:EnableMouse(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop",  win.StopMovingOrSizing)
    win:SetFrameStrata("DIALOG")
    win:SetFrameLevel(100)
    win:Hide()

    Addon:ApplyTheme(win)
    -- Override bg to fully opaque (the shared theme uses 0.65 alpha).
    local bg = Addon.THEME.bg
    win:SetBackdropColor(bg.r, bg.g, bg.b, 1.0)

    -- Title
    local titleFS = win:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    titleFS:SetPoint("TOPLEFT", win, "TOPLEFT", PAD, -10)
    local th = Addon.THEME.header
    titleFS:SetTextColor(th.r, th.g, th.b, th.a)
    titleFS:SetText(L.ILVLREF_WINDOW_TITLE or "Midnight Season 1 \u2013 Item Level Reference")

    -- Close button
    local closeBtn = CreateFrame("Button", nil, win, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", win, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() win:Hide() end)

    -- Register with UISpecialFrames so ESC closes it
    if UISpecialFrames and win.GetName then
        local n = win:GetName()
        if n and n ~= "" then
            local exists = false
            for i = 1, #UISpecialFrames do
                if UISpecialFrames[i] == n then exists = true; break end
            end
            if not exists then
                table.insert(UISpecialFrames, n)
            end
        end
    end

    -- Scroll frame
    local sf = CreateFrame("ScrollFrame", nil, win, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT",     win, "TOPLEFT",  PAD,     -SCROLLTOP)
    sf:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -(PAD + 22), PAD)

    local sc = CreateFrame("Frame", nil, sf)
    -- Content width = window width - 2Ã—PAD - scrollbar width (22)
    sc:SetWidth(WIN_W - PAD * 2 - 22)
    sc:SetHeight(1)
    sf:SetScrollChild(sc)

    -- â”€â”€ Content â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    local posY = -4

    -- â”€â”€â”€ 1. Upgrade Tracks â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    posY = SecHead(sc, posY, L.ILVLREF_SEC_TRACKS or "Upgrade Tracks  (20 crests per step)")

    posY = ColHead(sc, posY, {
        { x=0,   w=35,  t=(L.ILVLREF_COL_ILVL         or "ilvl")  },
        { x=40,  w=190, t=(L.ILVLREF_COL_TRACK        or "Track") },
        { x=235, w=165, t=(L.ILVLREF_COL_CREST_NEEDED or "Crest Needed") },
    })

    for _, row in ipairs(TRACKS) do
        posY = DataRow(sc, posY, {
            { x=0,   w=35,  t=row[1] },
            { x=40,  w=190, t=row[2] },
            { x=235, w=165, t=row[3] },
        })
    end

    posY = posY - SEC_GAP
    posY = HRule(sc, posY)
    posY = posY - 4

    -- â”€â”€â”€ 2. Crafted Item Levels â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    posY = SecHead(sc, posY, L.ILVLREF_SEC_CRAFTED or "Crafted Item Levels")

    posY = ColHead(sc, posY, {
        { x=0,   w=45, t=(L.ILVLREF_COL_GEAR or "Gear")                           },
        { x=50,  w=60, t=ADV..(L.ILVLREF_CREST_ADV_SHORT   or "Adv")..R           },
        { x=115, w=60, t=VET..(L.ILVLREF_CREST_VET_SHORT   or "Vet")..R           },
        { x=180, w=65, t=CHAMP..(L.ILVLREF_CREST_CHAMP_SHORT or "Champ")..R       },
        { x=250, w=60, t=HERO..(L.ILVLREF_CREST_HERO        or "Hero")..R         },
        { x=315, w=60, t=MYTH..(L.ILVLREF_CREST_MYTH        or "Myth")..R         },
    })

    for _, row in ipairs(CRAFTED) do
        posY = DataRow(sc, posY, {
            { x=0,   w=45, t=row[1] },
            { x=50,  w=60, t=row[2] },
            { x=115, w=60, t=row[3] },
            { x=180, w=65, t=row[4] },
            { x=250, w=60, t=row[5] },
            { x=315, w=60, t=row[6] },
        })
    end

    posY = posY - SEC_GAP
    posY = HRule(sc, posY)
    posY = posY - 4

    -- â”€â”€â”€ 3. Dungeon Item Levels â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    posY = SecHead(sc, posY, L.ILVLREF_SEC_DUNGEONS or "Dungeon Item Levels")

    posY = ColHead(sc, posY, {
        { x=0,   w=65,  t=(L.ILVLREF_COL_SOURCE     or "Source")     },
        { x=70,  w=65,  t=(L.ILVLREF_COL_END_LOOT   or "End Loot")   },
        { x=140, w=75,  t=(L.ILVLREF_COL_GREAT_VAULT or "Great Vault") },
        { x=220, w=200, t=(L.ILVLREF_COL_CRESTS      or "Crests")     },
    })

    for _, row in ipairs(DUNGEONS) do
        posY = DataRow(sc, posY, {
            { x=0,   w=65,  t=row[1] },
            { x=70,  w=65,  t=row[2] },
            { x=140, w=75,  t=row[3] },
            { x=220, w=200, t=row[4] },
        })
    end

    posY = posY - SEC_GAP
    posY = HRule(sc, posY)
    posY = posY - 4

    -- â”€â”€â”€ 4. Raid Item Levels (approx.) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    posY = SecHead(sc, posY, L.ILVLREF_SEC_RAID or "Approx. Midnight Raid Item Levels")

    posY = ColHead(sc, posY, {
        { x=0,   w=85, t=(L.ILVLREF_COL_DIFFICULTY or "Difficulty") },
        { x=90,  w=65, t=(L.ILVLREF_COL_BOSS1      or "Early")      },
        { x=160, w=65, t=(L.ILVLREF_COL_BOSS2      or "Mid")        },
        { x=230, w=65, t=(L.ILVLREF_COL_BOSS3      or "Late")       },
        { x=300, w=65, t=(L.ILVLREF_COL_BOSS4      or "End")        },
    })

    for _, row in ipairs(RAID) do
        posY = DataRow(sc, posY, {
            { x=0,   w=85, t=row[1] },
            { x=90,  w=65, t=row[2] },
            { x=160, w=65, t=row[3] },
            { x=230, w=65, t=row[4] },
            { x=300, w=65, t=row[5] },
        })
    end

    posY = posY - SEC_GAP
    posY = HRule(sc, posY)
    posY = posY - 4

    -- â”€â”€â”€ 5. Bountiful Delve Item Levels â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    posY = SecHead(sc, posY, L.ILVLREF_SEC_DELVES or "Bountiful Delve Item Levels")

    posY = ColHead(sc, posY, {
        { x=0,   w=45, t=(L.ILVLREF_COL_TIER        or "Tier")        },
        { x=50,  w=65, t=(L.ILVLREF_COL_END_LOOT    or "End Loot")    },
        { x=120, w=65, t=(L.ILVLREF_COL_MAP_DROP     or "Map Drop")    },
        { x=190, w=65, t=(L.ILVLREF_COL_GREAT_VAULT  or "Great Vault") },
    })

    for _, row in ipairs(DELVES) do
        posY = DataRow(sc, posY, {
            { x=0,   w=45, t=row[1] },
            { x=50,  w=65, t=row[2] },
            { x=120, w=65, t=row[3] },
            { x=190, w=65, t=row[4] },
        })
    end

    -- Set final scroll child height
    local totalH = math.abs(posY) + PAD
    sc:SetHeight(max(1, totalH))

    return win
end

-- â”€â”€ Public API â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

function Addon:ToggleIlvlRefWindow()
    if self._ilvlRefWindow then
        if self._ilvlRefWindow:IsShown() then
            self._ilvlRefWindow:Hide()
        else
            self._ilvlRefWindow:Show()
        end
        return
    end

    -- Build on first use
    self._ilvlRefWindow = BuildIlvlRefWindow()
    self._ilvlRefWindow:Show()
end

function Addon:HideIlvlRefWindow()
    if self._ilvlRefWindow and self._ilvlRefWindow:IsShown() then
        self._ilvlRefWindow:Hide()
    end
end

-- Called from UpdateLocalizedUI after a locale switch.
-- Destroys the cached window so the next open rebuilds it with the new locale.
function Addon:RebuildIlvlRefWindow()
    if not self._ilvlRefWindow then return end
    local wasShown = self._ilvlRefWindow:IsShown()
    self._ilvlRefWindow:Hide()
    self._ilvlRefWindow = nil
    -- Remove the old global frame name so CreateFrame doesn't collide.
    if _G["LariasIlvlRefFrame"] then
        _G["LariasIlvlRefFrame"] = nil
    end
    if wasShown then
        self._ilvlRefWindow = BuildIlvlRefWindow()
        self._ilvlRefWindow:Show()
    end
end
