-- LariasWeeklyChecklist_IlvlRef.lua
-- Standalone popup window: Midnight Season 1 item-level reference tables.
-- Opened/closed via the "Item Levels" button in the main frame.

local addonName = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(addonName, true)
if not Addon then return end

local CreateFrame = CreateFrame
local max = math.max

local WIN_W    = 620   -- popup window width
local WIN_H    = 540   -- popup window height
local PAD      = 14    -- outer content padding
local ROW_H    = 18    -- height of one data row
local SEC_GAP  = 14    -- gap between sections
local HDR_H    = 22    -- section heading height
local SUBHDR_H = 18    -- column sub-header height
local SCROLLTOP = 32   -- pixels from win top to scroll frame

local ADV   = "|cFF1EFF00"   -- Adventurer  (green)
local VET   = "|cFF0070DD"   -- Veteran     (blue)
local CHAMP = "|cFFA335EE"   -- Champion    (purple)
local HERO  = "|cFFFF8000"   -- Hero        (orange)
local MYTH  = "|cFFFFD100"   -- Myth/Gilded (gold)
local R     = "|r"


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

-- Measure visible pixel width of a string (strips WoW colour codes).
local _mfs
local function MeasureStr(text, fontObj)
    if not _mfs then
        _mfs = UIParent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        _mfs:Hide()
    end
    if fontObj then _mfs:SetFontObject(fontObj) end
    local plain = (text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    _mfs:SetText(plain)
    return _mfs:GetStringWidth()
end

-- Given cols ({t=header, [align=]}) and a rows 2-D array,
-- measures each column's max content width and fills col.w + col.x in-place.
local CELL_PAD = 10  -- 4 px left inset + right margin + buffer
local function AutoFitCols(cols, rows)
    for ci, col in ipairs(cols) do
        local w = MeasureStr(col.t or "", "GameFontHighlightSmall")
        for _, row in ipairs(rows) do
            local cw = MeasureStr(row[ci] or "")
            if cw > w then w = cw end
        end
        col.w = math.ceil(w) + CELL_PAD
    end
    local x = 0
    for _, col in ipairs(cols) do col.x = x; x = x + col.w end
    return cols
end



-- Color-code an ilvl number string by its crest tier.
local function IlvlColor(s)
    local n = tonumber(s)
    if not n then return s end
    if     n >= 279 then return MYTH ..s..R
    elseif n >= 266 then return HERO ..s..R
    elseif n >= 253 then return CHAMP..s..R
    elseif n >= 237 then return VET  ..s..R
    else                  return ADV  ..s..R
    end
end

-- Color the two halves of a "Tier A / Tier B" track name independently.
local function DualTrack(str, c1, c2)
    local a, b = str:match("^(.+) / (.+)$")
    if a and b then return c1..a..R.." / "..c2..b..R end
    return c1..str..R
end

-- Draw a bordered grid table (header + data rows with column separators).
-- cols = { {x, w, t, [align]} }  (x/w are cell boundaries; t = header text)
-- rows = { {cell1, cell2, ...}, ... }
-- Returns new posY.
local GBOR = 0.55  -- outer border / header divider opacity multiplier
local GLIN = 0.18  -- inner row / column line opacity multiplier
local function GridTable(parent, posY, cols, rows)
    local br = Addon.THEME.border
    local tc = Addon.THEME.textDim
    -- compute right edge of the table
    local rightX = 0
    for _, c in ipairs(cols) do
        local e = (c.x or 0) + (c.w or 60)
        if e > rightX then rightX = e end
    end
    local nRows  = #rows
    local totalH = SUBHDR_H + ROW_H * nRows
    local startY = posY

    local function hline(y, mul)
        local t = parent:CreateTexture(nil, "ARTWORK")
        t:SetColorTexture(br.r, br.g, br.b, math.min(1, br.a * mul))
        t:SetSize(rightX, 1)
        t:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
    end
    local function vline(x)
        local t = parent:CreateTexture(nil, "ARTWORK")
        t:SetColorTexture(br.r, br.g, br.b, math.min(1, br.a * GBOR))
        t:SetSize(1, totalH)
        t:SetPoint("TOPLEFT", parent, "TOPLEFT", x, startY)
    end

    -- top border
    hline(startY, GBOR)
    -- header cells (4 px left inset)
    for _, col in ipairs(cols) do
        FS(parent, (col.x or 0) + 4, startY - 2, col.t or "",
           "GameFontHighlightSmall", tc.r, tc.g, tc.b, tc.a, (col.w or 60) - 6, col.align)
    end
    posY = startY - SUBHDR_H
    hline(posY, GBOR)  -- strong line under header

    -- data rows
    for ri, row in ipairs(rows) do
        for ci, col in ipairs(cols) do
            FS(parent, (col.x or 0) + 4, posY - 2, row[ci] or "",
               nil, nil, nil, nil, nil, (col.w or 60) - 6, col.align)
        end
        posY = posY - ROW_H
        hline(posY, ri == nRows and GBOR or GLIN)
    end

    -- vertical borders: left edge of every column + right edge of last
    for _, col in ipairs(cols) do vline(col.x or 0) end
    vline(rightX)

    return posY
end

local function BuildIlvlRefWindow()
    local L = Addon.L

    -- ilvl at rank r = ilvlBase + RANK_OFFSETS[r]
    local RANK_OFFSETS = { 0, 4, 7, 10, 13, 17 }

    local TIERS = {
        { id="ADV",   color=ADV,   ilvlBase=220,
          crest      = L.ILVLREF_CREST_ADV,
          crestShort = L.ILVLREF_CREST_ADV },
        { id="VET",   color=VET,   ilvlBase=233,
          crest      = L.ILVLREF_CREST_VET,
          crestShort = L.ILVLREF_CREST_VET },
        { id="CHAMP", color=CHAMP, ilvlBase=246,
          crest      = L.ILVLREF_CREST_CHAMP,
          crestShort = L.ILVLREF_CREST_CHAMP },
        { id="HERO",  color=HERO,  ilvlBase=259,
          crest      = L.ILVLREF_CREST_HERO,
          crestShort = L.ILVLREF_CREST_HERO },
        { id="MYTH",  color=MYTH,  ilvlBase=272,
          crest      = L.ILVLREF_CREST_MYTH,
          crestShort = L.ILVLREF_CREST_MYTH },
    }

    local function makeTrackRow(tier, rank, nextTier)
        local ilvl      = tier.ilvlBase + RANK_OFFSETS[rank]
        local isOverlap = (rank >= 5) and (nextTier ~= nil)

        local ilvlCell = (isOverlap and nextTier.color or tier.color) .. ilvl .. R

        local nameCell
        if isOverlap then
            local nextRank = rank - 4
            local lKey     = "ILVLREF_TRACK_" .. tier.id .. rank .. "_" .. nextTier.id .. nextRank
            local fb       = tier.crest .. " " .. rank .. " / " .. nextTier.crest .. " " .. nextRank
            nameCell = DualTrack(L[lKey] or fb, tier.color, nextTier.color)
        else
            local lKey = "ILVLREF_TRACK_" .. tier.id .. rank
            nameCell   = tier.color .. (L[lKey] or tier.crest .. " " .. rank) .. R
        end

        local crestCell
        if rank == 6 and nextTier then
            crestCell = tier.color .. tier.crestShort .. R
                     .. " - (|cFFFF2020DO NOT USE " .. nextTier.id .. " CRESTS|r)"
        else
            crestCell = tier.color .. tier.crest .. R
        end

        return { ilvlCell, nameCell, crestCell }
    end

    local TRACKS = {}
    for ti, tier in ipairs(TIERS) do
        local nextTier  = TIERS[ti + 1]
        local startRank = (ti == 1) and 1 or 3
        for rank = startRank, 6 do
            table.insert(TRACKS, makeTrackRow(tier, rank, nextTier))
        end
    end

    -- Crafted item levels
    local CRAFTED = {
        { "|A:Professions-Icon-Quality-Tier1:14:14|a", ADV..("220")..R, VET..("233")..R, CHAMP..("246")..R, HERO..("259")..R, MYTH..("272")..R },
        { "|A:Professions-Icon-Quality-Tier2:14:14|a", ADV..("224")..R, VET..("237")..R, CHAMP..("250")..R, HERO..("263")..R, MYTH..("276")..R },
        { "|A:Professions-Icon-Quality-Tier3:14:14|a", ADV..("227")..R, VET..("240")..R, CHAMP..("253")..R, HERO..("266")..R, MYTH..("279")..R },
        { "|A:Professions-Icon-Quality-Tier4:14:14|a", ADV..("230")..R, VET..("243")..R, CHAMP..("256")..R, HERO..("269")..R, MYTH..("282")..R },
        { "|A:Professions-Icon-Quality-Tier5:14:14|a", ADV..("233")..R, VET..("246")..R, CHAMP..("259")..R, HERO..("272")..R, MYTH..("285")..R },
    }

    -- Dungeon item levels
    local DUNGEONS = {
        { L.ILVLREF_DUNGEON_PRE_HEROIC, ADV.."224"..R,  "?"            },
        { L.ILVLREF_DUNGEON_HEROIC,     ADV.."230"..R,  VET.."243"..R  },
        { L.ILVLREF_DUNGEON_PRE_MYTHIC, VET.."240"..R,  "?"            },
        { L.ILVLREF_DUNGEON_MYTHIC,     CHAMP.."246"..R, CHAMP.."256"..R },
        { "M2",  CHAMP.."250"..R, HERO.."259"..R  },
        { "M3",  CHAMP.."250"..R, HERO.."259"..R  },
        { "M4",  CHAMP.."253"..R, HERO.."263"..R  },
        { "M5",  CHAMP.."256"..R, HERO.."263"..R  },
        { "M6",  HERO.."259"..R,  HERO.."266"..R  },
        { "M7",  HERO.."259"..R,  HERO.."269"..R  },
        { "M8",  HERO.."263"..R,  HERO.."269"..R  },
        { "M9",  HERO.."263"..R,  HERO.."269"..R  },
        { "M10", HERO.."266"..R,  MYTH.."272"..R  },
        { "M11", HERO.."266"..R,  MYTH.."272"..R  },
        { "M12", HERO.."266"..R,  MYTH.."272"..R  },
    }

    -- Raid item levels
    local RAID = {
        { L.ILVLREF_RAID_LFR,    VET.."233"..R,   VET.."237"..R,   VET.."240"..R,   CHAMP.."243"..R },
        { L.ILVLREF_RAID_NORMAL,  CHAMP.."246"..R, CHAMP.."250"..R, CHAMP.."253"..R, HERO.."256"..R  },
        { L.ILVLREF_RAID_HEROIC,  HERO.."259"..R,  HERO.."263"..R,  HERO.."266"..R,  MYTH.."269"..R  },
        { L.ILVLREF_RAID_MYTHIC,  MYTH.."272"..R,  MYTH.."276"..R,  MYTH.."279"..R,  MYTH.."282"..R  },
    }

    -- Bountiful Delve item levels
    local tFmt = L.ILVLREF_DELVE_TIER_FMT
    local DELVES = {
        { tFmt:format(1),  ADV.."220"..R,   "-",             VET.."233"..R   },
        { tFmt:format(2),  ADV.."224"..R,   "-",             VET.."237"..R   },
        { tFmt:format(3),  ADV.."227"..R,   "-",             VET.."240"..R   },
        { tFmt:format(4),  ADV.."230"..R,   VET.."237"..R,   VET.."243"..R   },
        { tFmt:format(5),  VET.."233"..R,   VET.."243"..R,   CHAMP.."246"..R },
        { tFmt:format(6),  VET.."237"..R,   CHAMP.."250"..R, CHAMP.."253"..R },
        { tFmt:format(7),  CHAMP.."250"..R, CHAMP.."256"..R, CHAMP.."256"..R },
        { tFmt:format(8),  CHAMP.."250"..R, HERO.."259"..R,  HERO.."259"..R  },
        { tFmt:format(9),  CHAMP.."250"..R, HERO.."259"..R,  HERO.."259"..R  },
        { tFmt:format(10), CHAMP.."250"..R, HERO.."259"..R,  HERO.."259"..R  },
        { tFmt:format(11), CHAMP.."250"..R, HERO.."259"..R,  HERO.."259"..R  },
    }

    -- Pre-fit column widths and compute dynamic window width ----------------
    local trackCols = AutoFitCols({
        { t = L.ILVLREF_COL_ILVL           },
        { t = L.ILVLREF_COL_TRACK  },
        { t = L.ILVLREF_COL_CREST_NEEDED          },
    }, TRACKS)
    local craftCols = AutoFitCols({
        { t = L.ILVLREF_COL_QUALITY               },
        { t = ADV..L.ILVLREF_CREST_ADV..R    },
        { t = VET..L.ILVLREF_CREST_VET..R    },
        { t = CHAMP..L.ILVLREF_CREST_CHAMP..R },
        { t = HERO..L.ILVLREF_CREST_HERO..R  },
        { t = MYTH..L.ILVLREF_CREST_MYTH..R  },
    }, CRAFTED)
    local dungCols = AutoFitCols({
        { t = L.ILVLREF_COL_SOURCE      },
        { t = L.ILVLREF_COL_END_LOOT    },
        { t = L.ILVLREF_COL_GREAT_VAULT },
    }, DUNGEONS)
    local raidCols = AutoFitCols({
        { t = L.ILVLREF_COL_DIFFICULTY },
        { t = L.ILVLREF_COL_BOSS1      },
        { t = L.ILVLREF_COL_BOSS2        },
        { t = L.ILVLREF_COL_BOSS3       },
        { t = L.ILVLREF_COL_BOSS4        },
    }, RAID)
    local delveCols = AutoFitCols({
        { t = L.ILVLREF_COL_TIER        },
        { t = L.ILVLREF_COL_END_LOOT    },
        { t = L.ILVLREF_COL_MAP_DROP    },
        { t = L.ILVLREF_COL_GREAT_VAULT },
    }, DELVES)
    local function tblW(c) return c[#c].x + c[#c].w end
    local contentW = math.max(tblW(trackCols), tblW(craftCols), tblW(dungCols),
                               tblW(raidCols), tblW(delveCols))
    local WIN_W = contentW + PAD * 2 + 22  -- PAD each side + scrollbar

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
    local _savedIlvlPos = Addon.db and Addon.db.global and Addon.db.global.ilvlRefPos
    if _savedIlvlPos and _savedIlvlPos.x and _savedIlvlPos.y then
        win:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", _savedIlvlPos.x, _savedIlvlPos.y)
    else
        win:SetPoint("CENTER", UIParent, "CENTER", 260, 0)  -- offset right so it doesn't cover the checklist
    end
    win:SetClampedToScreen(true)
    win:SetMovable(true)
    win:EnableMouse(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", function()
        win:StopMovingOrSizing()
        local _gdb = Addon.db and Addon.db.global
        if _gdb then
            _gdb.ilvlRefPos = { x = win:GetLeft(), y = win:GetBottom() }
        end
    end)
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
    titleFS:SetText(L.ILVLREF_WINDOW_TITLE)

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
    -- Content width = window width - 2xPAD - scrollbar width (22)
    sc:SetWidth(WIN_W - PAD * 2 - 22)
    sc:SetHeight(1)
    sf:SetScrollChild(sc)


    local posY = -4

    -- 1. Upgrade Tracks
    posY = SecHead(sc, posY, L.ILVLREF_SEC_TRACKS)
    posY = GridTable(sc, posY, trackCols, TRACKS)
    posY = posY - SEC_GAP

    -- 2. Crafted Item Levels
    posY = SecHead(sc, posY, L.ILVLREF_SEC_CRAFTED)
    posY = GridTable(sc, posY, craftCols, CRAFTED)
    posY = posY - SEC_GAP

    -- 3. Dungeon Item Levels
    posY = SecHead(sc, posY, L.ILVLREF_SEC_DUNGEONS)
    posY = GridTable(sc, posY, dungCols, DUNGEONS)
    posY = posY - SEC_GAP

    -- 4. Raid Item Levels
    posY = SecHead(sc, posY, L.ILVLREF_SEC_RAID)
    posY = GridTable(sc, posY, raidCols, RAID)
    posY = posY - SEC_GAP

    -- 5. Bountiful Delve Item Levels
    posY = SecHead(sc, posY, L.ILVLREF_SEC_DELVES)
    posY = GridTable(sc, posY, delveCols, DELVES)

    -- Set final scroll child height
    local totalH = math.abs(posY) + PAD
    sc:SetHeight(max(1, totalH))

    return win
end


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
