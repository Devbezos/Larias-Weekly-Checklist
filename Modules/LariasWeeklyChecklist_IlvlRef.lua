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

    -- Populate a quick lookup so IC/I can resolve by id string (e.g. "ADV", "VET").
    local TIER_MAP = {}
    for _, t in ipairs(TIERS) do TIER_MAP[t.id] = t end

    -- I("ADV", 2)  → integer ilvl  (ilvlBase + RANK_OFFSETS[rank])
    -- IC("ADV", 2) → colored string ready for display
    local function I(id, rank)
        local t = TIER_MAP[id]
        return t.ilvlBase + RANK_OFFSETS[rank]
    end
    local function IC(id, rank)
        local t = TIER_MAP[id]
        return t.color .. (t.ilvlBase + RANK_OFFSETS[rank]) .. R
    end

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
                     .. " - (|cFFFF2020" .. (L.ILVLREF_DO_NOT_USE_CRESTS_FMT or "DO NOT USE %s CRESTS"):format(nextTier.crest) .. "|r)"
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

    -- Crafted item levels  (quality n = tier base + RANK_OFFSETS[n])
    local CRAFTED = {
        { "|A:Professions-Icon-Quality-Tier1:14:14|a", IC("ADV",1), IC("VET",1), IC("CHAMP",1), IC("HERO",1), IC("MYTH",1) },
        { "|A:Professions-Icon-Quality-Tier2:14:14|a", IC("ADV",2), IC("VET",2), IC("CHAMP",2), IC("HERO",2), IC("MYTH",2) },
        { "|A:Professions-Icon-Quality-Tier3:14:14|a", IC("ADV",3), IC("VET",3), IC("CHAMP",3), IC("HERO",3), IC("MYTH",3) },
        { "|A:Professions-Icon-Quality-Tier4:14:14|a", IC("ADV",4), IC("VET",4), IC("CHAMP",4), IC("HERO",4), IC("MYTH",4) },
        { "|A:Professions-Icon-Quality-Tier5:14:14|a", IC("ADV",5), IC("VET",5), IC("CHAMP",5), IC("HERO",5), IC("MYTH",5) },
    }

    -- Dungeon item levels
    local DUNGEONS = {
        { L.ILVLREF_DUNGEON_PRE_HEROIC, IC("ADV",2),   "?"           },
        { L.ILVLREF_DUNGEON_HEROIC,     IC("ADV",4),   IC("VET",4)   },
        { L.ILVLREF_DUNGEON_PRE_MYTHIC, IC("VET",3),   "?"           },
        { L.ILVLREF_DUNGEON_MYTHIC,     IC("CHAMP",1), IC("CHAMP",4) },
        { "M2",  IC("CHAMP",2), IC("HERO",1)  },
        { "M3",  IC("CHAMP",2), IC("HERO",1)  },
        { "M4",  IC("CHAMP",3), IC("HERO",2)  },
        { "M5",  IC("CHAMP",4), IC("HERO",2)  },
        { "M6",  IC("HERO",1),  IC("HERO",3)  },
        { "M7",  IC("HERO",1),  IC("HERO",4)  },
        { "M8",  IC("HERO",2),  IC("HERO",4)  },
        { "M9",  IC("HERO",2),  IC("HERO",4)  },
        { "M10", IC("HERO",3),  IC("MYTH",1)  },
        { "M11", IC("HERO",3),  IC("MYTH",1)  },
        { "M12", IC("HERO",3),  IC("MYTH",1)  },
    }

    -- Raid item levels  (each difficulty = one tier across boss columns 1–4)
    local RAID = {
        { L.ILVLREF_RAID_LFR,    IC("VET",1),   IC("VET",2),   IC("VET",3),   IC("VET",4)   },
        { L.ILVLREF_RAID_NORMAL,  IC("CHAMP",1), IC("CHAMP",2), IC("CHAMP",3), IC("CHAMP",4) },
        { L.ILVLREF_RAID_HEROIC,  IC("HERO",1),  IC("HERO",2),  IC("HERO",3),  IC("HERO",4)  },
        { L.ILVLREF_RAID_MYTHIC,  IC("MYTH",1),  IC("MYTH",2),  IC("MYTH",3),  IC("MYTH",4)  },
    }

    -- Bountiful Delve item levels
    local tFmt = L.ILVLREF_DELVE_TIER_FMT
    local DELVES = {
        { tFmt:format(1),  IC("ADV",1),   "-",           IC("VET",1)   },
        { tFmt:format(2),  IC("ADV",2),   "-",           IC("VET",2)   },
        { tFmt:format(3),  IC("ADV",3),   "-",           IC("VET",3)   },
        { tFmt:format(4),  IC("ADV",4),   IC("VET",2),   IC("VET",4)   },
        { tFmt:format(5),  IC("VET",1),   IC("VET",4),   IC("CHAMP",1) },
        { tFmt:format(6),  IC("VET",2),   IC("CHAMP",2), IC("CHAMP",3) },
        { tFmt:format(7),  IC("CHAMP",2), IC("CHAMP",4), IC("CHAMP",4) },
        { tFmt:format(8),  IC("CHAMP",2), IC("HERO",1),  IC("HERO",1)  },
        { tFmt:format(9),  IC("CHAMP",2), IC("HERO",1),  IC("HERO",1)  },
        { tFmt:format(10), IC("CHAMP",2), IC("HERO",1),  IC("HERO",1)  },
        { tFmt:format(11), IC("CHAMP",2), IC("HERO",1),  IC("HERO",1)  },
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

    local _savedIlvlSize = Addon.db and Addon.db.global and Addon.db.global.ilvlRefSize
    local initWinW = (_savedIlvlSize and tonumber(_savedIlvlSize.w) or 0)
    local initWinH = (_savedIlvlSize and tonumber(_savedIlvlSize.h) or 0)
    if initWinW < WIN_W then initWinW = WIN_W end
    if initWinH < 150   then initWinH = WIN_H end  -- use default height on first open
    win:SetSize(initWinW, initWinH)
    local _savedIlvlPos = Addon.db and Addon.db.global and Addon.db.global.ilvlRefPos
    if _savedIlvlPos and _savedIlvlPos.x and _savedIlvlPos.y then
        win:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", _savedIlvlPos.x, _savedIlvlPos.y)
    else
        -- Default: snap to the right edge of the main checklist frame, same Y.
        local mf = Addon._mainFrame
        if mf then
            win:SetPoint("TOPLEFT", mf, "TOPRIGHT", 4, 0)
        else
            win:SetPoint("CENTER", UIParent, "CENTER", 260, 0)
        end
    end
    win:SetClampedToScreen(true)
    win:SetMovable(true)
    win:SetResizable(true)
    if win.SetResizeBounds then
        win:SetResizeBounds(WIN_W, 150)
    elseif win.SetMinResize then
        win:SetMinResize(WIN_W, 150)
    end
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

    -- Scroll frame (auto-adapts to win size; content reflows instead of scaling)
    local sf = CreateFrame("ScrollFrame", nil, win, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT",     win, "TOPLEFT",  PAD,     -SCROLLTOP)
    sf:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -(PAD + 22), PAD)

    local sc = CreateFrame("Frame", nil, sf)
    sc:SetSize(1, 1)
    sf:SetScrollChild(sc)

    -- Build each section into its own sub-frame so ReflowIlvlSections can
    -- reposition them without redrawing any content.
    local COL_GAP = 20  -- horizontal gap between two columns when side-by-side

    local function BuildSection(headText, cols, rows)
        local secFrame = CreateFrame("Frame", nil, sc)
        local y = 0
        y = SecHead(secFrame, y, headText)
        y = GridTable(secFrame, y, cols, rows)
        local h = -y
        local w = tblW(cols)
        secFrame:SetSize(w, h)
        return secFrame, w, h
    end

    local secTracks,  wTracks,  hTracks  = BuildSection(L.ILVLREF_SEC_TRACKS,   trackCols, TRACKS)
    local secCrafted, wCrafted, hCrafted = BuildSection(L.ILVLREF_SEC_CRAFTED,   craftCols, CRAFTED)
    local secDungs,   wDungs,   hDungs   = BuildSection(L.ILVLREF_SEC_DUNGEONS,  dungCols,  DUNGEONS)
    local secRaid,    wRaid,    hRaid    = BuildSection(L.ILVLREF_SEC_RAID,       raidCols,  RAID)
    local secDelves,  wDelves,  hDelves  = BuildSection(L.ILVLREF_SEC_DELVES,    delveCols, DELVES)

    -- Natural column widths for multi-column layouts
    local wRight2 = math.max(wCrafted, wDungs, wRaid, wDelves)  -- 2-col: all right sections
    local wMid    = math.max(wCrafted, wDungs)                   -- 3-col: middle column
    local wRight3 = math.max(wRaid,    wDelves)                  -- 3-col: right column

    -- Reposition all section sub-frames based on current window width.
    -- 3-col: Tracks | Crafted+Dungeons | Raid+Delves
    -- 2-col: Tracks | Crafted+Dungeons+Raid+Delves
    -- 1-col: all stacked, scrollbar handles overflow
    local _reflowing = false
    local function ReflowIlvlSections()
        if _reflowing then return end
        _reflowing = true

        local availW = win:GetWidth() - PAD * 2 - 22  -- subtract PAD each side + scrollbar
        sc:SetWidth(math.max(1, availW))

        if availW >= wTracks + wMid + wRight3 + COL_GAP * 2 then
            -- ── Three-column layout ────────────────────────────────────────────
            secTracks:ClearAllPoints()
            secTracks:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, 0)

            local midX   = wTracks + COL_GAP
            local rightX = midX + wMid + COL_GAP

            local my = 0
            for i, s in ipairs({ secCrafted, secDungs }) do
                s:ClearAllPoints()
                s:SetPoint("TOPLEFT", sc, "TOPLEFT", midX, my)
                my = my - ({ hCrafted, hDungs })[i] - SEC_GAP
            end

            local ry = 0
            for i, s in ipairs({ secRaid, secDelves }) do
                s:ClearAllPoints()
                s:SetPoint("TOPLEFT", sc, "TOPLEFT", rightX, ry)
                ry = ry - ({ hRaid, hDelves })[i] - SEC_GAP
            end

            sc:SetHeight(max(1, math.max(hTracks, -my, -ry) + PAD))

        elseif availW >= wTracks + wRight2 + COL_GAP then
            -- ── Two-column layout ──────────────────────────────────────────────
            secTracks:ClearAllPoints()
            secTracks:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, 0)

            local rightX = wTracks + COL_GAP
            local ry = 0
            local rightSecs = { secCrafted, secDungs,   secRaid, secDelves }
            local rightHs   = { hCrafted,  hDungs,     hRaid,   hDelves   }
            for i, s in ipairs(rightSecs) do
                s:ClearAllPoints()
                s:SetPoint("TOPLEFT", sc, "TOPLEFT", rightX, ry)
                ry = ry - rightHs[i] - SEC_GAP
            end

            sc:SetHeight(max(1, math.max(hTracks, -ry) + PAD))
        else
            -- ── Single-column layout ───────────────────────────────────────────
            local allSecs = { secTracks,  secCrafted, secDungs, secRaid,  secDelves }
            local allHs   = { hTracks,   hCrafted,   hDungs,   hRaid,    hDelves   }
            local y = 0
            for i, s in ipairs(allSecs) do
                s:ClearAllPoints()
                s:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, y)
                y = y - allHs[i] - SEC_GAP
            end
            sc:SetHeight(max(1, -y + PAD))
        end

        -- Apply UI scale (does not change logical dimensions, no OnSizeChanged).
        local _scale = Addon.GetUIScale and Addon:GetUIScale() or 1.0
        win:SetScale(_scale)

        -- Enforce max size when content fits without scrolling.
        -- sf is anchored: TOPLEFT=(PAD, -SCROLLTOP), BOTTOMRIGHT=(-(PAD+22), PAD)
        -- so sf effective height = win:GetHeight() - SCROLLTOP - PAD.
        -- Compute this directly from win height to avoid reading sf:GetHeight() before
        -- the layout engine has processed the frame (returns 0 on first call).
        local _scH    = math.ceil(sc:GetHeight())
        local _sfH    = math.floor(win:GetHeight() - SCROLLTOP - PAD)
        local _idealH = SCROLLTOP + _scH + PAD
        local _curW   = win:GetWidth()
        local _sb = sf.ScrollBar
        if _scH <= _sfH then
            -- Content fits: snap height to content, lock both max width and max height.
            win:SetHeight(_idealH)
            if win.SetResizeBounds then
                win:SetResizeBounds(WIN_W, 150, _curW, _idealH)
            elseif win.SetMaxResize then
                win:SetMaxResize(_curW, _idealH)
            end
            if _sb and _sb.Hide then _sb:Hide() end
        else
            -- Content overflows: free both dimensions, show scrollbar.
            if win.SetResizeBounds then
                win:SetResizeBounds(WIN_W, 150, 0, 0)
            elseif win.SetMaxResize then
                win:SetMaxResize(0, 0)
            end
            if _sb and _sb.Show then _sb:Show() end
        end

        _reflowing = false
    end

    win._ilvlReflow = ReflowIlvlSections
    win._baseW = WIN_W  -- default window width (used by reset)
    win._baseH = WIN_H  -- default window height (used by reset)
    ReflowIlvlSections()  -- initial layout

    win:SetScript("OnSizeChanged", function()
        ReflowIlvlSections()
    end)

    local ilvlResizeBtn = CreateFrame("Button", nil, win)
    ilvlResizeBtn:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -4, 4)
    ilvlResizeBtn:SetSize(16, 16)
    ilvlResizeBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    ilvlResizeBtn:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    ilvlResizeBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    ilvlResizeBtn:SetScript("OnMouseDown", function() win:StartSizing("BOTTOMRIGHT") end)
    ilvlResizeBtn:SetScript("OnMouseUp", function()
        win:StopMovingOrSizing()
        ReflowIlvlSections()
        local _gdb = Addon.db and Addon.db.global
        if _gdb then
            _gdb.ilvlRefSize = { w = win:GetWidth(), h = win:GetHeight() }
        end
    end)

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
