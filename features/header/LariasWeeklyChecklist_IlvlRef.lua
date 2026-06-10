-- IlvlRef module: standalone popup window with Midnight Season 1 item-level reference tables.
-- Opened/closed via the "Item Levels" button in the main frame.

local addonName = ...
local Addon = _G[addonName]
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

local ADV   = Addon.IlvlUtils.GetEscapePrefix(1)  -- Adventurer  (green)
local VET   = Addon.IlvlUtils.GetEscapePrefix(2)  -- Veteran     (blue)
local CHAMP = Addon.IlvlUtils.GetEscapePrefix(3)  -- Champion    (purple)
local HERO  = Addon.IlvlUtils.GetEscapePrefix(4)  -- Hero        (orange)
local MYTH  = Addon.IlvlUtils.GetEscapePrefix(5)  -- Myth/Gilded (gold)
local COLOR_RESET = "|r"

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
    local tex = parent:CreateTexture(nil, "ARTWORK")
    local vs = Addon.VISUAL_STYLE or {}
    tex:SetColorTexture(
        Addon.THEME.border.r, Addon.THEME.border.g,
        Addon.THEME.border.b, vs.strongDividerA or (Addon.THEME.border.a * 0.6))
    tex:SetHeight(1)
    tex:SetPoint("TOPLEFT",  parent, "TOPLEFT",  0,  posY)
    tex:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0,  posY)
    return posY - 4
end

-- Draw a gold section heading and return the new posY.
local function SecHead(parent, posY, text)
    local headerColor = Addon.THEME.header
    FS(parent, 0, posY, text, "GameFontNormal", headerColor.r, headerColor.g, headerColor.b, headerColor.a)
    return posY - HDR_H
end

-- Draw a dim column-header row and return the new posY.
-- cols = array of { x, w, t, align }
local function ColHead(parent, posY, cols)
    local dimColor = Addon.THEME.textDim
    for _, col in ipairs(cols) do
        FS(parent, col.x, posY, col.t, "GameFontHighlightSmall",
           dimColor.r, dimColor.g, dimColor.b, dimColor.a, col.w, col.align)
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
        local maxW = MeasureStr(col.t or "", "GameFontHighlightSmall")
        for _, row in ipairs(rows) do
            local cellW = MeasureStr(row[ci] or "")
            if cellW > maxW then maxW = cellW end
        end
        col.w = math.ceil(maxW) + CELL_PAD
    end
    local colX = 0
    for _, col in ipairs(cols) do col.x = colX; colX = colX + col.w end
    return cols
end

-- Color the two halves of a "Tier A / Tier B" track name independently.
local function DualTrack(str, c1, c2)
    local leftPart, rightPart = str:match("^(.+) / (.+)$")
    if leftPart and rightPart then return c1..leftPart..COLOR_RESET.." / "..c2..rightPart..COLOR_RESET end
    return c1..str..COLOR_RESET
end

-- Draw a bordered grid table (header + data rows with column separators).
-- cols = { {x, w, t, [align]} }  (x/w are cell boundaries; t = header text)
-- rows = { {cell1, cell2, ...}, ... }
-- Returns new posY.
local GBOR = (Addon.VISUAL_STYLE and Addon.VISUAL_STYLE.trackingBorderA) or 0.55
local GLIN = (Addon.VISUAL_STYLE and Addon.VISUAL_STYLE.trackingInnerA) or 0.18
local function GridTable(parent, posY, cols, rows)
        local borderColor = Addon.THEME.border
        local dimColor    = Addon.THEME.textDim
        -- compute right edge of the table
        local rightX = 0
        for _, col in ipairs(cols) do
            local edge = (col.x or 0) + (col.w or 60)
            if edge > rightX then rightX = edge end
        end
        local nRows  = #rows
        local totalH = SUBHDR_H + ROW_H * nRows
        local startY = posY

        local function hline(y, mul)
            local tex = parent:CreateTexture(nil, "ARTWORK")
            tex:SetColorTexture(borderColor.r, borderColor.g, borderColor.b, math.min(1, borderColor.a * mul))
            tex:SetSize(rightX, 1)
            tex:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
        end
        local function vline(vx)
            local tex = parent:CreateTexture(nil, "ARTWORK")
            tex:SetColorTexture(borderColor.r, borderColor.g, borderColor.b, math.min(1, borderColor.a * GBOR))
            tex:SetSize(1, totalH)
            tex:SetPoint("TOPLEFT", parent, "TOPLEFT", vx, startY)
        end
    hline(startY, GBOR)
    -- header cells (4 px left inset)
    for _, col in ipairs(cols) do
        FS(parent, (col.x or 0) + 4, startY - 2, col.t or "",
           "GameFontHighlightSmall", dimColor.r, dimColor.g, dimColor.b, dimColor.a, (col.w or 60) - 6, col.align)
    end
    posY = startY - SUBHDR_H
    hline(posY, GBOR)  -- strong line under header

    -- data rows
    local txt = Addon.THEME.text
    for ri, row in ipairs(rows) do
        for ci, col in ipairs(cols) do
            FS(parent, (col.x or 0) + 4, posY - 2, row[ci] or "",
               nil, txt.r, txt.g, txt.b, txt.a, (col.w or 60) - 6, col.align)
        end
        posY = posY - ROW_H
        hline(posY, ri == nRows and GBOR or GLIN)
    end

    -- vertical borders: left edge of every column + right edge of last
    for _, col in ipairs(cols) do vline(col.x or 0) end
    vline(rightX)  -- right edge

    return posY
end

local function BuildIlvlRefWindow()
    local Locale = Addon.L

    -- ilvl at rank r = ilvlBase + RANK_OFFSETS[r]
    -- Starting points and rank offsets are defined in LariasWeeklyChecklist_Constants.lua
    -- and loaded into Addon.TRACKING. The literals below are fallbacks only.
    local tracking     = Addon.TRACKING or {}
    local ilvlBase      = tracking.ilvlBase      or 220
    local ilvlTrackStep = tracking.ilvlTrackStep or 13
    local RANK_OFFSETS  = tracking.ilvlRankOffsets or { 0, 4, 7, 10, 13, 17 }

    local TIERS = {
        { id="ADV",   color=ADV,   ilvlBase=ilvlBase + ilvlTrackStep * 0,
          crest      = Locale.ILVLREF_CREST_ADV,
          crestShort = Locale.ILVLREF_CREST_ADV },
        { id="VET",   color=VET,   ilvlBase=ilvlBase + ilvlTrackStep * 1,
          crest      = Locale.ILVLREF_CREST_VET,
          crestShort = Locale.ILVLREF_CREST_VET },
        { id="CHAMP", color=CHAMP, ilvlBase=ilvlBase + ilvlTrackStep * 2,
          crest      = Locale.ILVLREF_CREST_CHAMP,
          crestShort = Locale.ILVLREF_CREST_CHAMP },
        { id="HERO",  color=HERO,  ilvlBase=ilvlBase + ilvlTrackStep * 3,
          crest      = Locale.ILVLREF_CREST_HERO,
          crestShort = Locale.ILVLREF_CREST_HERO },
        { id="MYTH",  color=MYTH,  ilvlBase=ilvlBase + ilvlTrackStep * 4,
          crest      = Locale.ILVLREF_CREST_MYTH,
          crestShort = Locale.ILVLREF_CREST_MYTH },
    }

    -- GetIlvl(2, 3)  → integer ilvl  for tier index 2, rank 3  (ilvlBase + RANK_OFFSETS[rank])
    -- IC(2, 3) → colored string ready for display
    local function GetIlvl(tier, rank)
        local tierData = TIERS[tier]
        return tierData.ilvlBase + RANK_OFFSETS[rank]
    end
    local function IC(tier, rank)
        local tierData = TIERS[tier]
        return tierData.color .. (tierData.ilvlBase + RANK_OFFSETS[rank]) .. COLOR_RESET
    end

    local function makeTrackRow(tier, rank, nextTier)
        local ilvl      = tier.ilvlBase + RANK_OFFSETS[rank]
        local isOverlap = (rank >= 5) and (nextTier ~= nil)

        local ilvlCell = (isOverlap and nextTier.color or tier.color) .. ilvl .. COLOR_RESET

        local nameCell
        if isOverlap then
            local nextRank = rank - 4
            local lKey     = "ILVLREF_TRACK_" .. tier.id .. rank .. "_" .. nextTier.id .. nextRank
            local fb       = tier.crest .. " " .. rank .. " / " .. nextTier.crest .. " " .. nextRank
            nameCell = DualTrack(Locale[lKey] or fb, tier.color, nextTier.color)
        else
            local lKey = "ILVLREF_TRACK_" .. tier.id .. rank
            nameCell   = tier.color .. (Locale[lKey] or tier.crest .. " " .. rank) .. COLOR_RESET
        end

        local crestCell
        if rank == 6 and nextTier then
            crestCell = tier.color .. tier.crestShort .. COLOR_RESET
                     .. " - (|cFFFF2020" .. (Locale.ILVLREF_DO_NOT_USE_CRESTS_FMT or "DO NOT USE %s CRESTS"):format(nextTier.crest) .. "|r)"
        else
            crestCell = tier.color .. tier.crest .. COLOR_RESET
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
    local rawIcons = tracking.craftingQualityIcons or {}
    local function QIcon(n)
        local atlas = rawIcons[n] or ("Professions-Icon-Quality-Tier" .. n)
        return "|A:" .. atlas .. ":14:14|a"
    end
    local CRAFTED = {
        { QIcon(1), IC(1,1), IC(2,1), IC(3,1), IC(4,1), IC(5,1) },
        { QIcon(2), IC(1,2), IC(2,2), IC(3,2), IC(4,2), IC(5,2) },
        { QIcon(3), IC(1,3), IC(2,3), IC(3,3), IC(4,3), IC(5,3) },
        { QIcon(4), IC(1,4), IC(2,4), IC(3,4), IC(4,4), IC(5,4) },
        { QIcon(5), IC(1,5), IC(2,5), IC(3,5), IC(4,5), IC(5,5) },
    }

    -- Dungeon item levels
    local DUNGEONS = {
        { Locale.ILVLREF_DUNGEON_HEROIC,     IC(1,4), IC(2,4)  },
        { Locale.ILVLREF_DUNGEON_MYTHIC,     IC(3,1), IC(3,4)  },
        { "M2",  IC(3,2), IC(4,1) },
        { "M3",  IC(3,2), IC(4,1) },
        { "M4",  IC(3,3), IC(4,2) },
        { "M5",  IC(3,4), IC(4,2) },
        { "M6",  IC(4,1), IC(4,3) },
        { "M7",  IC(4,1), IC(4,4) },
        { "M8",  IC(4,2), IC(4,4) },
        { "M9",  IC(4,2), IC(4,4) },
        { "M10", IC(4,3), IC(5,1) },
        { "M11", IC(4,3), IC(5,1) },
        { "M12", IC(4,3), IC(5,1) },
    }

    -- Raid item levels  (each difficulty = one tier across boss columns 1–4)
    local RAID = {
        { Locale.ILVLREF_RAID_LFR,    IC(2,1), IC(2,2), IC(2,3), IC(2,4) },
        { Locale.ILVLREF_RAID_NORMAL,  IC(3,1), IC(3,2), IC(3,3), IC(3,4) },
        { Locale.ILVLREF_RAID_HEROIC,  IC(4,1), IC(4,2), IC(4,3), IC(4,4) },
        { Locale.ILVLREF_RAID_MYTHIC,  IC(5,1), IC(5,2), IC(5,3), IC(5,4) },
    }

    -- Bountiful Delve item levels
    local tFmt = Locale.ILVLREF_DELVE_TIER_FMT
    local DELVES = {
        { tFmt:format(1),  IC(1,1), "-",     IC(2,1) },
        { tFmt:format(2),  IC(1,2), "-",     IC(2,2) },
        { tFmt:format(3),  IC(1,3), "-",     IC(2,3) },
        { tFmt:format(4),  IC(1,4), IC(2,2), IC(2,4) },
        { tFmt:format(5),  IC(2,1), IC(2,4), IC(3,1) },
        { tFmt:format(6),  IC(2,2), IC(3,2), IC(3,3) },
        { tFmt:format(7),  IC(3,2), IC(3,4), IC(3,4) },
        { tFmt:format(8),  IC(3,2), IC(4,1), IC(4,1) },
        { tFmt:format(9),  IC(3,2), IC(4,1), IC(4,1) },
        { tFmt:format(10), IC(3,2), IC(4,1), IC(4,1) },
        { tFmt:format(11), IC(3,2), IC(4,1), IC(4,1) },
    }

    -- Pre-fit column widths and compute dynamic window width ----------------
    local trackCols = AutoFitCols({
        { t = Locale.ILVLREF_COL_ILVL           },
        { t = Locale.ILVLREF_COL_TRACK  },
        { t = Locale.ILVLREF_COL_CREST_NEEDED          },
    }, TRACKS)
    local craftCols = AutoFitCols({
        { t = Locale.ILVLREF_COL_QUALITY                          },
        { t = ADV..Locale.ILVLREF_CREST_ADV..COLOR_RESET    },
        { t = VET..Locale.ILVLREF_CREST_VET..COLOR_RESET    },
        { t = CHAMP..Locale.ILVLREF_CREST_CHAMP..COLOR_RESET },
        { t = HERO..Locale.ILVLREF_CREST_HERO..COLOR_RESET  },
        { t = MYTH..Locale.ILVLREF_CREST_MYTH..COLOR_RESET  },
    }, CRAFTED)
    local dungCols = AutoFitCols({
        { t = Locale.ILVLREF_COL_SOURCE      },
        { t = Locale.ILVLREF_COL_END_LOOT    },
        { t = Locale.ILVLREF_COL_GREAT_VAULT },
    }, DUNGEONS)
    local raidCols = AutoFitCols({
        { t = Locale.ILVLREF_COL_DIFFICULTY },
        { t = Locale.ILVLREF_COL_BOSS1      },
        { t = Locale.ILVLREF_COL_BOSS2      },
        { t = Locale.ILVLREF_COL_BOSS3      },
        { t = Locale.ILVLREF_COL_BOSS4      },
    }, RAID)
    local delveCols = AutoFitCols({
        { t = Locale.ILVLREF_COL_TIER        },
        { t = Locale.ILVLREF_COL_END_LOOT    },
        { t = Locale.ILVLREF_COL_MAP_DROP    },
        { t = Locale.ILVLREF_COL_GREAT_VAULT },
    }, DELVES)
    local function tblW(cols) return cols[#cols].x + cols[#cols].w end

    local win = Addon:NewThemedFrame("LariasIlvlRefFrame", UIParent)

    -- Default width = 2-col layout (Tracks | everything else).  Set after
    -- BuildSection calls (wTracks/wRight2 not yet available here).
    win:SetSize(WIN_W, WIN_H)
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

    -- Override bg to fully opaque (NewThemedFrame sets theme defaults; bg.a is 0.65).
    Addon:ApplyOpaquePopupTheme(win)

    -- Title (centered, leaves room for close button on the right)
    local titleFS = win:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    titleFS:SetPoint("TOPLEFT",  win, "TOPLEFT",  PAD,  -10)
    -- Leave room for two (SCROLLTOP-4)=28px buttons + 2px gaps + 2px right margin = 64px.
    titleFS:SetPoint("TOPRIGHT", win, "TOPRIGHT", -64,  -10)
    titleFS:SetJustifyH("CENTER")
    local titleHeaderColor = Addon.THEME.header
    titleFS:SetTextColor(titleHeaderColor.r, titleHeaderColor.g, titleHeaderColor.b, titleHeaderColor.a)
    titleFS:SetText(Locale.ILVLREF_WINDOW_TITLE)

    -- Close button: branded ✕ matching the addon theme.
    local closeBtn = Addon.Controls.NewCloseButton(win, function() win:Hide() end)
    closeBtn:SetPoint("TOPRIGHT", win, "TOPRIGHT", -2, -2)
    closeBtn:SetSize(SCROLLTOP - 4, SCROLLTOP - 4)
    closeBtn:SetBackdropBorderColor(0, 0, 0, 0)

    -- Register with UISpecialFrames so ESC closes this window via Blizzard's
    -- secure ESC chain rather than the protected SetPropagateKeyboardInput.
    tinsert(UISpecialFrames, "LariasIlvlRefFrame")

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
        local sectionY = 0
        sectionY = SecHead(secFrame, sectionY, headText)
        sectionY = GridTable(secFrame, sectionY, cols, rows)
        local secHeight = -sectionY
        local secWidth  = tblW(cols)
        secFrame:SetSize(secWidth, secHeight)
        return secFrame, secWidth, secHeight
    end

    local secTracks,  wTracks,  hTracks  = BuildSection(Locale.ILVLREF_SEC_TRACKS,   trackCols, TRACKS)
    local secCrafted, wCrafted, hCrafted = BuildSection(Locale.ILVLREF_SEC_CRAFTED,   craftCols, CRAFTED)
    local secDungs,   wDungs,   hDungs   = BuildSection(Locale.ILVLREF_SEC_DUNGEONS,  dungCols,  DUNGEONS)
    local secRaid,    wRaid,    hRaid    = BuildSection(Locale.ILVLREF_SEC_RAID,       raidCols,  RAID)
    local secDelves,  wDelves,  hDelves  = BuildSection(Locale.ILVLREF_SEC_DELVES,    delveCols, DELVES)

    -- Natural column widths for multi-column layouts
    local wMid    = math.max(wCrafted, wDungs)        -- 3-col: middle column
    local wRight3 = math.max(wRaid,    wDelves)        -- 3-col: right column
    local wSingle = math.max(wTracks, wCrafted, wDungs, wRaid, wDelves)  -- 1-col: widest table

    -- Maximized = 3-col, auto-height, no scroll.
    -- Minimized = 1-col stacked, fixed WIN_H, scrollable.
    local _isMaximized = (Addon.db and Addon.db.global and Addon.db.global.ilvlRefMaximized) and true or false
    local _reflowing   = false

    local function ReflowIlvlSections()
        if _reflowing then return end
        _reflowing = true

        local sb = sf.ScrollBar

        if _isMaximized then
            -- ── Three-column layout (maximized) ───────────────────────────────
            local col3W = wTracks + wMid + wRight3 + COL_GAP * 2
            sc:SetWidth(max(1, col3W))

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

            -- Auto-fit height so no scrollbar is needed.
            local idealH = SCROLLTOP + math.ceil(sc:GetHeight()) + PAD
            win:SetHeight(idealH)
            -- +1 extra pixel so the scroll viewport (win_w - 2*PAD - 22) is wide
            -- enough to include the 1px right-border vline drawn at x=col3W.
            win:SetWidth(col3W + PAD * 2 + 22 + 1)
            if sb then sb:Hide() end

        else
            -- ── Single-column layout (minimized / default) ────────────────────
            sc:SetWidth(max(1, wSingle))

            local allSecs = { secTracks, secCrafted, secDungs, secRaid,  secDelves }
            local allHs   = { hTracks,  hCrafted,   hDungs,   hRaid,    hDelves   }
            local y = 0
            for i, s in ipairs(allSecs) do
                s:ClearAllPoints()
                s:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, y)
                y = y - allHs[i] - SEC_GAP
            end
            sc:SetHeight(max(1, -y + PAD))

            -- Fixed window height; scroll frame handles overflow.
            win:SetHeight(WIN_H)
            if sb then sb:Show() end
        end

        -- The outer window (win) is scaled uniformly via win:SetScale() in
        -- ApplyUIScale, so no separate content scale is needed here.

        _reflowing = false
    end

    win._ilvlReflow = ReflowIlvlSections

    -- Toggle button: branded expand/shrink icon matching the header button row.
    local toggleBtn = Addon.Controls.NewExpandButton(win,
        nil,  -- OnClick wired below
        not _isMaximized,  -- shrunk = expanded=true shows the ▼ ("click to shrink") glyph
        Locale.ILVLREF_TOGGLE_EXPAND or "Expand",
        Locale.ILVLREF_TOGGLE_SHRINK or "Shrink")
    -- Sit immediately left of the close button, vertically aligned.
    toggleBtn:SetPoint("TOPRIGHT", closeBtn, "TOPLEFT", -2, 0)
    toggleBtn:SetSize(SCROLLTOP - 4, SCROLLTOP - 4)
    toggleBtn:SetBackdropBorderColor(0, 0, 0, 0)

    local function UpdateToggleTexture()
        -- expanded=true means the window IS maximized (down arrow, click to shrink).
        toggleBtn:SetExpanded(_isMaximized)
    end
    UpdateToggleTexture()

    toggleBtn:SetScript("OnClick", function()
        _isMaximized = not _isMaximized
        local _gdb = Addon.db and Addon.db.global
        if _gdb then _gdb.ilvlRefMaximized = _isMaximized end
        UpdateToggleTexture()
        -- Freeze the horizontal center so the window grows/shrinks
        -- symmetrically left and right from its current position.
        local pinCX  = win:GetLeft() + win:GetWidth() / 2
        local pinTop = win:GetTop()
        if _isMaximized then
            -- Widen to fit 3-col before reflow so layout branch is chosen correctly.
            -- +1 for the right-border pixel on the last table (see ReflowIlvlSections).
            win:SetWidth(wTracks + wMid + wRight3 + COL_GAP * 2 + PAD * 2 + 22 + 1)
        else
            win:SetWidth(wSingle + PAD * 2 + 22)
        end
        win:ClearAllPoints()
        win:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pinCX - win:GetWidth() / 2, pinTop)
        ReflowIlvlSections()
    end)

    -- Initial state: apply saved maximized state (defaults to minimized/1-col scrollable).
    if _isMaximized then
        win:SetWidth(wTracks + wMid + wRight3 + COL_GAP * 2 + PAD * 2 + 22 + 1)
    else
        win:SetWidth(wSingle + PAD * 2 + 22)
    end
    ReflowIlvlSections()

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
