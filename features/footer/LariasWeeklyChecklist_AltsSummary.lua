-- LariasWeeklyChecklist_AltsSummary.lua
-- Alt Summary popup: horizontal table — characters as columns, stats as rows.
-- Row groups: Character header | Tasks | Crests (per tier) | Currencies | Great Vault (per activity)
local addonName = ...
local Addon = _G[addonName]
if not Addon then return end

-- ── Layout constants ──────────────────────────────────────────────────────────
local PAD        = 8
local TITLE_H    = 28
local ROW_H      = 23          -- height of each data row
local HDR_ROW_H  = 25          -- height of section label rows
local COL_LABEL  = 124         -- width of the left-side row label column (wider for icon+text)
local COL_W      = 120         -- width of each character column
local BTN_H      = 18
local BTN_W      = 74          -- centered single button per column in COL_W=104
local ICON_SIZE  = 15          -- currency icon width/height in row labels

local COL_HDR_H  = 47          -- class bar(2) + name(18) + ilvl(13) + updated(10) + padding(4)
local BTN_ROW_H  = BTN_H + 8  -- = 26: button strip height at bottom of panel

local NUM_CRESTS = 5
local CREST_ABBREV = { "Adv", "Vet", "Chp", "Hero", "Myth" }
local GV_NAMES     = { "Raid", "M+ / Delve", "World" }
local GV_THRESHOLDS = { {2,4,6}, {1,4,8}, {2,4,8} }

-- Read from TRACKING so Overlay.lua (which captures the data) uses the same list.
local GEAR_SLOT_IDS  = (Addon.TRACKING and Addon.TRACKING.gearSlotIDs)
                       or {1,2,3,5,6,7,8,9,10,11,12,13,14,15,16,17}
local GEAR_SLOT_NAMES = {
    [1]="Head",      [2]="Neck",      [3]="Shoulders",
    [5]="Chest",     [6]="Waist",     [7]="Legs",
    [8]="Feet",      [9]="Wrists",    [10]="Hands",
    [11]="Ring 1",   [12]="Ring 2",   [13]="Trinket 1",
    [14]="Trinket 2",[15]="Back",     [16]="Main Hand", [17]="Off Hand",
}

-- ── Alpha constants ────────────────────────────────────────────────────
local A_FULL    = 1.00   -- present, data available
local A_EMPTY   = 0.50   -- present but zero / not progressed
local A_DIM     = 0.45   -- no data / placeholder
local A_ILVL    = 0.85   -- ilvl label (slightly dimmed)
local FONT_SM   = 11     -- small font: ilvl, sub-labels
local FONT_CELL = 12     -- standard cell font

-- ── Module state ──────────────────────────────────────────────────────────────
local altSummaryFrame
local _showHidden  = false
local _layout      = nil
-- Row-defs cache: rebuilt only when currency/GV hidden state changes (via RefreshAltsSummary)
-- or on panel open.  Avoids redundant BuildRowDefs calls when only character data changes.
local _cachedRows  = nil
local _rowsDirty   = true
local _gearPopupFrame   = nil   -- lazily-created gear popup; one shared instance
local _gearClickCatcher = nil   -- full-screen dismiss layer shown behind the popup
-- Convenience alias: snapshot type-tag strings (defined in Currency.lua, published on Addon).
-- AltsSummary reads this rather than repeating magic strings.
local ST  -- assigned in PopulateSummary after Currency.lua has loaded
local PopulateSummary  -- forward declaration
local ShowGearPopup    -- forward declaration

-- ── Gear popup ───────────────────────────────────────────────────────────────
-- Shows a small frame listing ilvl per gear slot for a character.
-- anchor: the hdrHit frame to position near.  charKey: unique char identifier.
ShowGearPopup = function(anchor, charKey, charName, cr, cg, cb, snap)
    if not _gearPopupFrame then
        local POPUP_W  = 290
        local GP_ROW_H = 18
        local GP_TTL_H = 22
        local POPUP_H  = GP_TTL_H + 4 + #GEAR_SLOT_IDS * GP_ROW_H + 6
        local f = Addon:NewThemedFrame(nil, UIParent)
        -- Override bg to fully opaque (NewThemedFrame uses theme default a=0.65).
        local _bg = Addon.THEME.bg
        f:SetBackdropColor(_bg.r, _bg.g, _bg.b, 1.0)
        f:SetFrameStrata("TOOLTIP")
        f:SetClampedToScreen(true)
        f:SetSize(POPUP_W, POPUP_H)

        local titleFS = f:CreateFontString(nil, "OVERLAY")
        titleFS:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
        titleFS:SetPoint("TOPLEFT",  f, "TOPLEFT",  6, -4)
        titleFS:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -4)
        titleFS:SetHeight(GP_TTL_H - 4)
        titleFS:SetJustifyH("LEFT")
        titleFS:SetJustifyV("MIDDLE")
        f._titleFS = titleFS

        local sep = f:CreateTexture(nil, "ARTWORK")
        sep:SetHeight(1)
        sep:SetColorTexture(0.4, 0.4, 0.4, 0.7)
        sep:SetPoint("TOPLEFT",  f, "TOPLEFT",  4, -GP_TTL_H)
        sep:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -GP_TTL_H)

        f._rows = {}
        for i, sid in ipairs(GEAR_SLOT_IDS) do
            local rowY = -(GP_TTL_H + 4 + (i - 1) * GP_ROW_H)

            -- Invisible hit region covering the full row width for mouse events.
            local hit = CreateFrame("Frame", nil, f)
            hit:SetPoint("TOPLEFT", f, "TOPLEFT", 4, rowY)
            hit:SetSize(POPUP_W - 8, GP_ROW_H)
            hit:EnableMouse(true)
            hit:SetScript("OnLeave", function() GameTooltip:Hide() end)

            local lblFS = f:CreateFontString(nil, "OVERLAY")
            lblFS:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
            lblFS:SetPoint("TOPLEFT", f, "TOPLEFT", 8, rowY)
            lblFS:SetSize(78, GP_ROW_H)
            lblFS:SetJustifyH("LEFT")
            lblFS:SetJustifyV("MIDDLE")
            lblFS:SetTextColor(0.52, 0.52, 0.52, 1)
            lblFS:SetText(GEAR_SLOT_NAMES[sid])

            local nameFS = f:CreateFontString(nil, "OVERLAY")
            nameFS:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
            nameFS:SetPoint("TOPLEFT",  f, "TOPLEFT",  90, rowY)
            nameFS:SetSize(POPUP_W - 90 - 42 - 8, GP_ROW_H)
            nameFS:SetJustifyH("LEFT")
            nameFS:SetJustifyV("MIDDLE")

            local ilvlFS = f:CreateFontString(nil, "OVERLAY")
            ilvlFS:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
            ilvlFS:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, rowY)
            ilvlFS:SetSize(40, GP_ROW_H)
            ilvlFS:SetJustifyH("RIGHT")
            ilvlFS:SetJustifyV("MIDDLE")

            f._rows[i] = { sid = sid, hit = hit, nameFS = nameFS, ilvlFS = ilvlFS }
        end
        -- Hide catcher whenever the popup is closed by any path.
        f:SetScript("OnHide", function()
            if _gearClickCatcher then _gearClickCatcher:Hide() end
        end)
        _gearPopupFrame = f
    end

    if not _gearClickCatcher then
        local c = CreateFrame("Frame", nil, UIParent)
        c:SetAllPoints(UIParent)
        c:SetFrameStrata("DIALOG")
        c:EnableMouse(true)
        c:SetScript("OnMouseDown", function()
            if _gearPopupFrame then _gearPopupFrame:Hide() end
            c:Hide()
        end)
        c:Hide()
        _gearClickCatcher = c
    end

    local f = _gearPopupFrame
    f._titleFS:SetText(charName)
    f._titleFS:SetTextColor(cr, cg, cb, 1)

    local gearSlots = snap and snap.gearSlots
    for _, row in ipairs(f._rows) do
        local slotData = gearSlots and gearSlots[row.sid]
        -- Support both old format (plain number) and current format (table).
        local link, ilvl
        if type(slotData) == "table" then
            link = slotData.link
            ilvl = tonumber(slotData.ilvl) or 0
        elseif type(slotData) == "number" then
            ilvl = slotData
        else
            ilvl = 0
        end

        -- Item name, quality-colored.
        if link then
            local itemName, _, quality = GetItemInfo(link)
            if itemName then
                local qr, qg, qb = GetItemQualityColor(quality or 1)
                row.nameFS:SetText(itemName)
                row.nameFS:SetTextColor(qr or 1, qg or 1, qb or 1, 1)
            else
                row.nameFS:SetText("Loading...")
                row.nameFS:SetTextColor(0.55, 0.55, 0.55, 1)
            end
        else
            row.nameFS:SetText("Empty")
            row.nameFS:SetTextColor(0.27, 0.27, 0.27, 1)
        end

        -- ilvl: tier-colored.
        if ilvl and ilvl > 0 then
            local hex = (Addon.IlvlUtils and Addon.IlvlUtils.GetColorHex(ilvl)) or "ffffffff"
            local r_ = (tonumber(hex:sub(3,4), 16) or 255) / 255
            local g_ = (tonumber(hex:sub(5,6), 16) or 255) / 255
            local b_ = (tonumber(hex:sub(7,8), 16) or 255) / 255
            row.ilvlFS:SetText(tostring(ilvl))
            row.ilvlFS:SetTextColor(r_, g_, b_, 1)
        else
            row.ilvlFS:SetText("")
        end

        -- Hover: full WoW item tooltip (shows gems, enchants, stats, set bonuses).
        local _link = link
        if _link then
            row.hit:SetScript("OnEnter", function(s_)
                GameTooltip:SetOwner(s_, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(_link)
                GameTooltip:Show()
            end)
        else
            row.hit:SetScript("OnEnter", nil)
        end
    end
    f._charKey = charKey
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 6, 0)
    _gearClickCatcher:Show()
    f:Show()
end

-- ── Dynamic layout ────────────────────────────────────────────────────────────
local function ComputeLayout()
    local tracking = Addon.TRACKING
    local miscIDs  = (tracking and type(tracking.miscCurrencyIDs) == "table")
                     and tracking.miscCurrencyIDs or {}
    local numMisc  = #miscIDs
    return {
        numMisc = numMisc,
        miscIDs = miscIDs,
    }
end

-- ── GV helpers ────────────────────────────────────────────────────────────────
local function CalcGVBreakdown(snap)
    if not (snap and snap.leftGrid) then return 0, 0, 0 end
    local s = {0, 0, 0}
    for bi = 1, 3 do
        local block = snap.leftGrid[bi]
        local done  = block and tonumber(block.complete) or 0
        -- block.complete counts unlocked vault slots (same as main panel's `complete >= i` check)
        s[bi] = math.min(done, 3)
    end
    return s[1], s[2], s[3]
end


-- ── Hex colour helper ───────────────────────────────────────────────────────
-- Converts a 6-char hex string (e.g. "FF8000") to three 0-1 floats.
-- Falls back to (0.7, 0.7, 0.7) when nil or malformed.
local function HexToRGB(hex)
    if hex and #hex >= 6 then
        return (tonumber(hex:sub(1,2), 16) or 179) / 255,
               (tonumber(hex:sub(3,4), 16) or 179) / 255,
               (tonumber(hex:sub(5,6), 16) or 179) / 255
    end
    return 0.7, 0.7, 0.7
end

-- ── Currency icon helper ──────────────────────────────────────────────────────
local function GetCurrencyIcon(id)
    if not id or id == 0 then return nil end
    local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo
                 and C_CurrencyInfo.GetCurrencyInfo(tonumber(id))
    return info and info.iconFileID
end

-- ── Shared tooltip leave ──────────────────────────────────────────────────────
local function OnCellLeave() GameTooltip:Hide() end

-- ── Widget helpers ────────────────────────────────────────────────────────────
local function MakeFS(parent, size, flags)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont("Fonts\\FRIZQT__.TTF", size or 12, flags or "")
    return fs
end

local function MakeCell(parent, w, h)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(w, h)
    f:EnableMouse(true)
    f:SetScript("OnLeave", OnCellLeave)
    local fs = MakeFS(f, 12)
    fs:SetAllPoints(f)
    fs:SetJustifyH("CENTER")
    fs:SetJustifyV("MIDDLE")
    f._fs = fs
    -- Secondary label: trade-up / overflow text, right-anchored.
    local tuFS = MakeFS(f, FONT_SM)
    tuFS:SetPoint("RIGHT", f, "RIGHT", -3, 0)
    tuFS:SetJustifyH("RIGHT")
    f._tu = tuFS
    -- Small hit region that sits over the trade-up text only (rightmost ~36px).
    local tuHit = CreateFrame("Frame", nil, f)
    tuHit:SetPoint("TOPRIGHT",    f, "TOPRIGHT",    0,  0)
    tuHit:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0,  0)
    tuHit:SetWidth(36)
    tuHit:EnableMouse(false)  -- enabled only when trade-up text is showing
    tuHit:SetScript("OnLeave", OnCellLeave)
    f._tuHit = tuHit
    return f
end

-- ── Panel construction ────────────────────────────────────────────────────────
local function EnsurePanel()
    if altSummaryFrame then return altSummaryFrame end

    _layout = ComputeLayout()

    local f = Addon:NewThemedFrame(nil, UIParent)
    f:SetSize(400, 200)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(200)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self_) self_:StartMoving() end)
    f:SetScript("OnDragStop",  function(self_) self_:StopMovingOrSizing(); self_._wasMoved = true end)
    f:Hide()
    Addon._altsSummaryFrame = f

    local th = Addon.THEME

    -- Title strip.
    local titleBgTex = f:CreateTexture(nil, "BACKGROUND")
    titleBgTex:SetColorTexture(th.header.r, th.header.g, th.header.b, 0.09)
    titleBgTex:SetPoint("TOPLEFT",  f, "TOPLEFT",  1, -1)
    titleBgTex:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
    titleBgTex:SetHeight(TITLE_H + 2)
    f._altsTitleBgTex = titleBgTex

    local titleFS = MakeFS(f, 13, "OUTLINE")
    titleFS:SetText("Alt Summary")
    titleFS:SetTextColor(th.header.r, th.header.g, th.header.b, 1)
    titleFS:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -7)
    f._altsTitleFS = titleFS

    local closeBtn = Addon.Controls.NewCloseButton(f, function()
        if _gearPopupFrame then _gearPopupFrame:Hide() end
        f:Hide()
    end)
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    f._altsCloseBtn = closeBtn

    -- "Show hidden" checkbox.
    local chk = Addon.Controls.NewCheckBox(f, function(checked)
        _showHidden = checked
        PopulateSummary(f)
    end, 14)
    chk:SetChecked(_showHidden)
    chk._label:SetText("Show hidden")
    f._footerChk = chk

    -- Pool tables for reuse.
    f._colPool     = {}
    f._divTexPool  = {}
    f._rowLblPool  = {}
    f._iconTexPool = {}
    f._rowHitPool  = {}

    altSummaryFrame = f
    return f
end

-- ── Snapshot helpers ─────────────────────────────────────────────────────────

local function BuildCharList(gdb, ownKey, allKeys, maxLvl)
    local th    = Addon.THEME.text
    local chars = {}
    for _, charKey in ipairs(allKeys) do
        local isHidden   = gdb and gdb.hiddenChars and gdb.hiddenChars[charKey] and true or false
        local classToken = gdb and gdb.charClasses  and gdb.charClasses[charKey]
        local isOwn      = (charKey == ownKey) or (charKey:lower() == ownKey:lower())
        local charLevel  = gdb and gdb.charLevels and gdb.charLevels[charKey]
        local isMaxLevel = isOwn or (charLevel and charLevel >= maxLvl)
        if isMaxLevel and (not isHidden or _showHidden) and classToken then
            local cdb  = gdb and gdb.chars and gdb.chars[charKey]
            local snap = cdb and cdb.trackingSnapshot
            local cr, cg, cb = th.r, th.g, th.b
            local cc = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
            if cc then cr, cg, cb = cc.r, cc.g, cc.b end
            chars[#chars + 1] = {
                key = charKey, snap = snap,
                isOwn = isOwn, isHidden = isHidden,
                classToken = classToken,
                cr = cr, cg = cg, cb = cb,
                alpha = isHidden and 0.45 or 1.0,
                ilvl  = cdb and cdb.ilvl,

            }
        end
    end
    -- Own character leftmost, then descending ilvl
    table.sort(chars, function(a, b)
        if a.isOwn ~= b.isOwn then return a.isOwn end
        return (tonumber(a.ilvl) or 0) > (tonumber(b.ilvl) or 0)
    end)
    return chars
end

-- Per-session cache: item link → effective max rank.
-- Avoids repeated C_ItemUpgrade calls for the same stored alt item links.
local _effectiveMaxCache = {}

-- Returns the effective max rank for a gear slot, accounting for embellished/crafted
-- items that are capped below the tier max rank.
-- Uses trueMaxRank if already stored; otherwise tries C_ItemUpgrade.GetItemUpgradeInfo
-- on the stored link, caches the result, and persists it back to the slot data.
local function GetSlotEffectiveMax(sd)
    if sd.trueMaxRank ~= nil then return sd.trueMaxRank end
    if not (sd.link and sd.rank and sd.maxRank and sd.rank < sd.maxRank) then
        return sd.maxRank
    end
    local cached = _effectiveMaxCache[sd.link]
    if cached ~= nil then
        if cached < sd.maxRank then sd.trueMaxRank = cached end
        return cached
    end
    if C_ItemUpgrade and C_ItemUpgrade.SetItemUpgradeFromItemLink
            and C_ItemUpgrade.GetItemUpgradeItemInfo then
        local ok = pcall(C_ItemUpgrade.SetItemUpgradeFromItemLink, sd.link)
        if ok then
            local info = C_ItemUpgrade.GetItemUpgradeItemInfo()
            if info and info.upgradeLevelInfos then
                local nLevels = #info.upgradeLevelInfos
                local effectiveMax = sd.maxRank
                if nLevels == 0 then
                    effectiveMax = sd.rank  -- no upgrades available → embellished cap
                elseif (sd.rank + nLevels) < sd.maxRank then
                    effectiveMax = sd.rank + nLevels  -- partial cap
                end
                if C_ItemUpgrade.ClearItemUpgrade then
                    pcall(C_ItemUpgrade.ClearItemUpgrade)
                end
                _effectiveMaxCache[sd.link] = effectiveMax
                if effectiveMax < sd.maxRank then
                    sd.trueMaxRank = effectiveMax  -- persist back to snapshot
                end
                return effectiveMax
            end
            if C_ItemUpgrade.ClearItemUpgrade then
                pcall(C_ItemUpgrade.ClearItemUpgrade)
            end
        end
    end
    _effectiveMaxCache[sd.link] = sd.maxRank  -- not embellished or API unavailable
    return sd.maxRank
end

-- Compute the total crest cost to max all items of crest tier `tierIdx`,
-- using the rank (x/y) stored in the snapshot.  No ilvl range math needed.
-- Returns totalCost.
local function CalcTierUpgradeCost(snap, tierIdx)
    if not (snap and snap.gearSlots) then return 0 end
    local TRACKING  = Addon.TRACKING
    -- Prefer the actual cost captured at snapshot time via C_ItemUpgrade;
    -- it already reflects any active account-wide or character discounts.
    -- Fall back to constants for old snapshots.
    local costPerStep
    if snap.upgradeCostPerStep and snap.upgradeCostPerStep[tierIdx] then
        costPerStep = snap.upgradeCostPerStep[tierIdx]
    else
        local costList = TRACKING and TRACKING.crestUpgradeCostPerStep
        costPerStep = (costList and costList[tierIdx]) or 20
    end
    local freeRanks   = (TRACKING and TRACKING.crestUpgradeFreeRanks
                        and TRACKING.crestUpgradeFreeRanks[tierIdx])   or 0
    local totalCost = 0
    for _, sid in ipairs(GEAR_SLOT_IDS) do
        local sd = snap.gearSlots[sid]
        local effectiveMax = sd and GetSlotEffectiveMax(sd)
        if type(sd) == "table" and sd.tierIdx == tierIdx
                and sd.rank and effectiveMax and sd.rank < effectiveMax then
            local remaining = math.max(0,
                (effectiveMax - sd.rank) - math.max(0, freeRanks - (sd.rank - 1))
            )
            totalCost = totalCost + remaining * costPerStep
        end
    end
    return totalCost
end

local function BuildRowDefs(tracking, LAYOUT, ownSnap)
    local rows = {}
    local function addSec(lbl, action)  rows[#rows + 1] = { type = "sechdr", label = lbl, action = action } end
    local function addRow(t, lbl, extra)
        local r = { type = t, label = lbl }
        if extra then for k, v in pairs(extra) do r[k] = v end end
        rows[#rows + 1] = r
    end
    -- Returns display name and tier RGB for crest tier i.
    local function CrestTierInfo(i)
        local name = (Addon.IlvlUtils and Addon.IlvlUtils.GetCrestTrackName(i))
                     or CREST_ABBREV[i] or ("Tier " .. i)
        local hex  = tracking and tracking.crestColors and tracking.crestColors[i]
        local cr, cg, cb = HexToRGB(hex)
        return name, cr, cg, cb
    end

    addSec("Crests", "currency")
    for i = 1, NUM_CRESTS do
        local name, cr, cg, cb = CrestTierInfo(i)
        local crestID = tracking and tracking.crestCurrencyIDs and tracking.crestCurrencyIDs[i]
        if not Addon:IsCurrencyHidden(crestID) then
            addRow("crest", name, { crestIdx = i, cr = cr, cg = cg, cb = cb,
                                    iconID = GetCurrencyIcon(crestID), currencyID = crestID })
        end
    end

    -- Build upgrade-cost rows.  If the own character has gear data, skip any
    -- tier where they have nothing left to upgrade (all items maxed or absent).
    do
        local ownHasGearData = false
        if ownSnap and ownSnap.gearSlots then
            for _, sid in ipairs(GEAR_SLOT_IDS) do
                local sd = ownSnap.gearSlots[sid]
                if type(sd) == "table" and sd.rank then
                    ownHasGearData = true; break
                end
            end
        end
        local upgRows = {}
        for i = 1, NUM_CRESTS do
            local name, cr, cg, cb = CrestTierInfo(i)
            local show = true
            if ownHasGearData then
                show = CalcTierUpgradeCost(ownSnap, i) > 0
            end
            if show then
                upgRows[#upgRows + 1] = { type = "upgcost", label = name, tierIdx = i, cr = cr, cg = cg, cb = cb }
            end
        end
        if #upgRows > 0 then
            addSec("Upgrade Cost", nil)
            for _, r in ipairs(upgRows) do rows[#rows + 1] = r end
        end
    end

    addSec("Currencies", "currency")
    local _catID = tracking and tracking.catalystCurrencyID
    if not Addon:IsCurrencyHidden(_catID) then
        addRow("catalyst", "Catalyst Charges", { iconID = GetCurrencyIcon(_catID),
                                                 currencyID = _catID })
    end
    local _sprkID = tracking and tracking.sparkCurrencyID
    if not Addon:IsCurrencyHidden(_sprkID) then
        addRow("sparks",   "Sparks",           { iconID = GetCurrencyIcon(_sprkID),
                                                 currencyID = _sprkID })
    end
    local _keysID = tracking and tracking.cofferKeysDisplayCurrencyID
    if not Addon:IsCurrencyHidden(_keysID) then
        addRow("keys",     "Coffer Keys",      { iconID = GetCurrencyIcon(_keysID),
                                                 currencyID = _keysID })
    end
    for mi, mID in ipairs(LAYOUT.miscIDs) do
        if not Addon:IsCurrencyHidden(tonumber(mID)) then
            local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo
                         and C_CurrencyInfo.GetCurrencyInfo(tonumber(mID))
            addRow("misc", (info and info.name) or ("Currency " .. mID),
                   { miscIdx = mi, miscID = mID, iconID = GetCurrencyIcon(mID) })
        end
    end

    -- Quest rows (conditional on questID > 0).
    local questIDs     = (tracking and tracking.questIDs)     or {}
    local questItemIDs = (tracking and tracking.questItemIDs) or {}
    local L            = Addon.L or {}
    local function addQuestRow(key, labelKey, fallback)
        if (tonumber(questIDs[key]) or 0) <= 0 then return end
        if Addon:IsQuestHidden(key) then return end
        local iID = tonumber(questItemIDs[key]) or 0
        local icon
        if iID > 0 then
            local _, _, _, _, _, _, _, _, _, tex = GetItemInfo(iID)
            if tex then icon = tex end
        end
        addRow("quest", L[labelKey] or fallback, { questKey = key, iconID = icon })
    end
    addQuestRow("delversBounty",  "TRACKING_QUEST_DELVERS_BOUNTY",  "Trovehunter's Bounty")
    addQuestRow("nullaeusSpoils", "TRACKING_QUEST_NULLAEUS_SPOILS", "Spoils of Nullaeus")
    addQuestRow("weeklyPrey",     "TRACKING_QUEST_WEEKLY_PREY",     "Weekly Prey")

    addSec("Great Vault", "greatvault")
    addRow("keystone", "Keystone", {})
    for gi = 1, 3 do
        if not Addon:IsGVBlockHidden(gi) then
            addRow("gv", GV_NAMES[gi], { gvBlock = gi })
        end
    end

    return rows
end

-- ── Snap data factory ────────────────────────────────────────────────────
-- Returns a zeroed snap-data record. All consumers call this instead of
-- repeating the field list, so adding a new field only needs one change here.
local function NewSnapData()
    return {
        catQty = 0, catCap = 0,
        sprkQty = 0, sprkCap = 0, sprkQD = nil,
        keysQty = 0, keysCap = 0,
        miscQtys   = {}, miscCaps      = {},
        crestQtys  = {}, crestEarneds  = {}, crestCaps = {}, crestTradeups = {},
        questsDone = {},
    }
end

local function ExtractSnapData(snap, crestIDs, LAYOUT)
    local d = NewSnapData()
    if not (snap and snap.rightRows) then return d end
    for _, r_ in ipairs(snap.rightRows) do
        local t = r_.type
        if t == ST.CREST then
            local rid = tonumber(r_.id)
            for ii = 1, NUM_CRESTS do
                if crestIDs[ii] == rid then
                    d.crestQtys[ii]     = tonumber(r_.qty)    or 0
                    d.crestEarneds[ii]  = tonumber(r_.earned) or 0
                    d.crestCaps[ii]     = tonumber(r_.cap)    or 0
                    d.crestTradeups[ii] = r_.tradeup and tonumber(r_.tradeup) or nil
                    break
                end
            end
        elseif t == ST.CATALYST then
            d.catQty = tonumber(r_.qty) or 0
            d.catCap = tonumber(r_.cap) or 0
        elseif t == ST.SPARKS then
            d.sprkQty = tonumber(r_.qty) or 0
            d.sprkCap = tonumber(r_.cap) or 0
            d.sprkQD  = r_.questDone
        elseif t == ST.COFFERKEYS then
            d.keysQty = tonumber(r_.qty) or 0
            d.keysCap = tonumber(r_.cap) or 0
        elseif t == ST.MISC then
            local rid = tonumber(r_.id)
            for mi, mID in ipairs(LAYOUT.miscIDs) do
                if tonumber(mID) == rid then
                    d.miscQtys[mi] = tonumber(r_.qty) or 0
                    d.miscCaps[mi] = tonumber(r_.cap) or 0
                    break
                end
            end
        elseif t == ST.QUEST then
            d.questsDone[r_.key] = r_.done
        end
    end
    return d
end

-- ── Populate ──────────────────────────────────────────────────────────────────

-- ── Per-type cell render functions ───────────────────────────────────────────
-- Each function fills one cell for one column (character).
-- Signature: RenderXxxCell(cell, row, sd, noSnap, alpha, th)
--   cell   : the frame with ._fs FontString, supports SetScript("OnEnter")
--   row    : row definition table (type-specific fields)
--   sd     : ExtractSnapData result for this character
--   noSnap : true when the character has no stored snapshot
--   alpha  : base alpha for the character column
--   th     : Addon.THEME.text {r,g,b}

local function RenderCrestCell(cell, row, sd, noSnap, alpha, _th, crestIDs, highestTuIdx)
    local idx    = row.crestIdx
    local earned = sd.crestEarneds[idx] or 0
    local qty    = sd.crestQtys[idx]   or 0
    local cap    = sd.crestCaps[idx]   or 0
    local tuAmt  = (idx == highestTuIdx) and (sd.crestTradeups[idx] or 0) or 0
    local cr2, cg2, cb2 = row.cr or 0.7, row.cg or 0.7, row.cb or 0.7
    if noSnap then
        cell._fs:SetText("—")
        cell._fs:SetTextColor(cr2, cg2, cb2, alpha * A_EMPTY)
        cell._tu:SetText("")
    else
        -- Show current held crests (wallet balance) vs season cap.
        local baseStr = (cap > 0) and (qty .. "/" .. cap) or tostring(qty)
        cell._fs:SetText(baseStr)
        cell._fs:SetTextColor(cr2, cg2, cb2, alpha * (qty > 0 and A_FULL or A_EMPTY))
        if tuAmt > 0 then
            cell._tu:SetText("+" .. tuAmt)
            cell._tu:SetTextColor(0.30, 0.65, 1.0, alpha)
        else
            cell._tu:SetText("")
        end
    end
    -- Main cell tooltip: crest amount detail.
    do
        local _e, _q, _c = earned, qty, cap
        local _nm, _cr2b, _cg2b, _cb2b = row.label, cr2, cg2, cb2
        if noSnap then
            cell:SetScript("OnEnter", nil)
        else
            cell:SetScript("OnEnter", function(s_)
                GameTooltip:SetOwner(s_, "ANCHOR_RIGHT")
                GameTooltip:SetText(_nm, _cr2b, _cg2b, _cb2b)
                if _c > 0 then
                    local bonus = math.max(0, _q - _e)
                    if bonus > 0 then
                        GameTooltip:AddLine("Capped Crests: " .. _e,        1, 1, 1)
                        GameTooltip:AddLine("Bonus Crests: +" .. bonus,      1, 1, 1)
                        GameTooltip:AddLine("Total Crests: "  .. _q,         1, 1, 1)
                    else
                        GameTooltip:AddLine("Earned: " .. _e .. " / " .. _c, 1, 1, 1)
                        GameTooltip:AddLine("Total Held: "    .. _q,         1, 1, 1)
                    end
                else
                    GameTooltip:AddLine("Crests Held: " .. _q, 1, 1, 1)
                end
                GameTooltip:Show()
            end)
        end
    end
    -- Trade-up tooltip lives only over the +N hit area (separate from main amount).
    if tuAmt > 0 then
        local _n, _earned, _cap = tuAmt, earned, cap
        local handler = function(s_)
            local cappedN = (_cap > 0) and math.min(_n, math.max(0, _cap - _earned)) or _n
            local AL = Addon.L or {}
            GameTooltip:SetOwner(s_, "ANCHOR_RIGHT")
            GameTooltip:SetText(AL.TRACKING_TRADEUP_TITLE or "Trade-up available", 0.30, 0.65, 1.0)
            if cappedN ~= _n then
                GameTooltip:AddLine((AL.TRACKING_TRADEUP_CURRENTLY_EARNABLE_FMT or "Currently earnable: %d"):format(cappedN), 1, 1, 1)
                GameTooltip:AddLine((AL.TRACKING_TRADEUP_UNCAPPED_FMT           or "Uncapped: %d"):format(_n),                0.7, 0.7, 0.7)
            else
                GameTooltip:AddLine((AL.TRACKING_TRADEUP_EARNABLE_FMT           or "Earnable: %d"):format(_n), 1, 1, 1)
            end
            local convertTip = AL.TRACKING_CONVERT_TOOLTIP or ""
            if convertTip ~= "" then
                GameTooltip:AddLine(convertTip, 0.7, 0.7, 0.7)
            end
            GameTooltip:Show()
        end
        if cell._tuHit then
            cell._tuHit:EnableMouse(true)
            cell._tuHit:SetScript("OnEnter", handler)
        end
    else
        if cell._tuHit then
            cell._tuHit:EnableMouse(false)
            cell._tuHit:SetScript("OnEnter", nil)
        end
    end
end

local function RenderCatalystCell(cell, row, sd, noSnap, alpha, th)
    local catQty = sd.catQty
    cell._fs:SetText(noSnap and "—" or tostring(catQty))
    cell._fs:SetTextColor(th.r, th.g, th.b, alpha * (catQty > 0 and A_FULL or A_DIM))
    local _qty = catQty
    if noSnap then
        cell:SetScript("OnEnter", nil)
    else
        cell:SetScript("OnEnter", function(s_)
            GameTooltip:SetOwner(s_, "ANCHOR_RIGHT")
            GameTooltip:SetText("Catalyst Charges", 1, 0.82, 0)
            GameTooltip:AddLine("Charges: " .. _qty, 1, 1, 1)
            GameTooltip:Show()
        end)
    end
end

local function RenderSparksCell(cell, row, sd, noSnap, alpha, th)
    local sprkQty, sprkCap, sprkQD = sd.sprkQty, sd.sprkCap, sd.sprkQD
    local sqr, sqg, sqb = th.r, th.g, th.b
    if     sprkQD == true  then sqr, sqg, sqb = 0.3, 1.0, 0.3
    elseif sprkQD == false then sqr, sqg, sqb = 1.0, 0.5, 0.5
    end
    local sprkStr = (sprkCap > 0) and (sprkQty .. "/" .. sprkCap) or tostring(sprkQty)
    cell._fs:SetText(noSnap and "—" or sprkStr)
    cell._fs:SetTextColor(sqr, sqg, sqb, alpha * (sprkQty > 0 and A_FULL or A_EMPTY))
    local _qty, _cap, _qd = sprkQty, sprkCap, sprkQD
    if noSnap then
        cell:SetScript("OnEnter", nil)
    else
        cell:SetScript("OnEnter", function(s_)
            GameTooltip:SetOwner(s_, "ANCHOR_RIGHT")
            GameTooltip:SetText("Sparks", 1, 0.82, 0)
            if _cap > 0 then
                GameTooltip:AddLine("Sparks: " .. _qty .. " / " .. _cap, 1, 1, 1)
            else
                GameTooltip:AddLine("Sparks: " .. _qty, 1, 1, 1)
            end
            if _qd == true then
                GameTooltip:AddLine("Weekly Quest: Complete",   0.3, 1.0, 0.3)
            elseif _qd == false then
                GameTooltip:AddLine("Weekly Quest: Incomplete", 1.0, 0.4, 0.4)
            end
            GameTooltip:Show()
        end)
    end
end

local function RenderKeysCell(cell, row, sd, noSnap, alpha, th)
    local keysQty, keysCap = sd.keysQty, sd.keysCap
    local keysStr = (keysCap > 0) and (keysQty .. "/" .. keysCap) or tostring(keysQty)
    cell._fs:SetText(noSnap and "—" or keysStr)
    cell._fs:SetTextColor(th.r, th.g, th.b, alpha * (keysQty > 0 and A_FULL or A_DIM))
    local _qty, _cap = keysQty, keysCap
    if noSnap then
        cell:SetScript("OnEnter", nil)
    else
        cell:SetScript("OnEnter", function(s_)
            GameTooltip:SetOwner(s_, "ANCHOR_RIGHT")
            GameTooltip:SetText("Coffer Keys", 1, 0.82, 0)
            if _cap > 0 then
                GameTooltip:AddLine("Keys: " .. _qty .. " / " .. _cap, 1, 1, 1)
            else
                GameTooltip:AddLine("Keys: " .. _qty, 1, 1, 1)
            end
            GameTooltip:Show()
        end)
    end
end

local function RenderMiscCell(cell, row, sd, noSnap, alpha, th)
    local mQty = sd.miscQtys[row.miscIdx] or 0
    local mCap = sd.miscCaps[row.miscIdx] or 0
    if noSnap then
        cell._fs:SetText("—")
        cell._fs:SetTextColor(th.r, th.g, th.b, A_DIM)
    elseif mCap > 0 then
        cell._fs:SetText(mQty .. "/" .. mCap)
        local pct = mQty / mCap
        if     pct >= 1.0 then cell._fs:SetTextColor(0.3,  1.0,  0.3,  alpha)
        elseif pct >= 0.5 then cell._fs:SetTextColor(1.0,  0.82, 0.0,  alpha)
        else                    cell._fs:SetTextColor(th.r, th.g, th.b, alpha)
        end
    else
        cell._fs:SetText(tostring(mQty))
        cell._fs:SetTextColor(th.r, th.g, th.b, alpha * (mQty > 0 and A_FULL or A_DIM))
    end
    local _qty, _cap, _lbl = mQty, mCap, row.label
    if noSnap then
        cell:SetScript("OnEnter", nil)
    else
        cell:SetScript("OnEnter", function(s_)
            GameTooltip:SetOwner(s_, "ANCHOR_RIGHT")
            GameTooltip:SetText(_lbl or "Currency", 1, 0.82, 0)
            if _cap > 0 then
                GameTooltip:AddLine("Amount: " .. _qty .. " / " .. _cap, 1, 1, 1)
            else
                GameTooltip:AddLine("Amount: " .. _qty, 1, 1, 1)
            end
            GameTooltip:Show()
        end)
    end
end

local function RenderQuestCell(cell, row, sd, noSnap, alpha, th)
    local done = sd.questsDone[row.questKey]
    if noSnap or done == nil then
        cell._fs:SetText("—")
        cell._fs:SetTextColor(th.r, th.g, th.b, A_DIM)
    elseif done then
        cell._fs:SetText("Done")
        cell._fs:SetTextColor(0.3, 1.0, 0.3, alpha)
    else
        cell._fs:SetText("No")
        cell._fs:SetTextColor(1.0, 0.45, 0.45, alpha)
    end
    local _done, _lbl = done, row.label
    cell:SetScript("OnEnter", function(s_)
        GameTooltip:SetOwner(s_, "ANCHOR_RIGHT")
        GameTooltip:SetText(_lbl, 1, 0.82, 0)
        if noSnap or _done == nil then
            GameTooltip:AddLine("No snapshot data", 0.6, 0.6, 0.6)
        elseif _done then
            GameTooltip:AddLine("Completed this week", 0.3, 1.0, 0.3)
        else
            GameTooltip:AddLine("Not completed this week", 1.0, 0.45, 0.45)
        end
        GameTooltip:Show()
    end)
end

local function RenderKeystoneCell(cell, row, snap, noSnap, alpha, th)
    cell._fs:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
    local ks    = snap and snap.keystone
    local level = ks and tonumber(ks.level) or 0
    if noSnap or not ks then
        cell._fs:SetText("—")
        cell._fs:SetTextColor(th.r, th.g, th.b, A_DIM)
        return
    end
    if level <= 0 then
        cell._fs:SetText("None")
        cell._fs:SetTextColor(0.5, 0.5, 0.5, alpha * A_EMPTY)
        return
    end
    local name    = (ks.name and ks.name ~= "") and ks.name or nil
    local abbrev  = name and (name:match("^%S+") or name) or nil
    local display = abbrev and ("+" .. level .. " " .. abbrev) or ("+" .. level)
    local kr, kg, kb
    if     level >= 10 then kr, kg, kb = 0.64, 0.21, 0.93
    elseif level >=  7 then kr, kg, kb = 0.12, 0.44, 0.85
    elseif level >=  4 then kr, kg, kb = 0.12, 0.73, 0.12
    else                    kr, kg, kb = 0.70, 0.70, 0.70
    end
    cell._fs:SetText(display)
    cell._fs:SetTextColor(kr, kg, kb, alpha)
    local _level, _name = level, name
    cell:SetScript("OnEnter", function(s_)
        GameTooltip:SetOwner(s_, "ANCHOR_RIGHT")
        GameTooltip:SetText("Keystone", 1, 0.82, 0)
        if _name then
            GameTooltip:AddLine("+" .. _level .. " " .. _name, 1, 1, 1)
        else
            GameTooltip:AddLine("+" .. _level, 1, 1, 1)
        end
        GameTooltip:Show()
    end)
end

local function RenderUpgradeCostCell(cell, row, snap, noSnap, alpha, th)
    cell._fs:SetFont("Fonts\\FRIZQT__.TTF", FONT_CELL, "")
    local cr, cg, cb = row.cr or th.r, row.cg or th.g, row.cb or th.b

    if noSnap then
        cell._fs:SetText("\226\128\148")
        cell._fs:SetTextColor(th.r, th.g, th.b, A_DIM)
        cell:SetScript("OnEnter", nil)
        return
    end

    -- Check whether any gear was actually captured for this character.
    -- snap.gearSlots may be nil (old snapshot) or {} (capture failed / all empty).
    local hasGearData = false
    if snap.gearSlots then
        for _, sid in ipairs(GEAR_SLOT_IDS) do
            local sd = snap.gearSlots[sid]
            if type(sd) == "table" and sd.rank then
                hasGearData = true; break
            end
        end
    end
    if not hasGearData then
        cell._fs:SetText("?")
        cell._fs:SetTextColor(cr, cg, cb, A_DIM)
        local _nil = not snap.gearSlots
        -- Count how many slots had ilvl data vs rank data for diagnostics.
        local _ilvlCount, _rankCount = 0, 0
        if snap.gearSlots then
            for _, sid in ipairs(GEAR_SLOT_IDS) do
                local sd = snap.gearSlots[sid]
                if type(sd) == "table" then
                    if (sd.ilvl or 0) > 0 then _ilvlCount = _ilvlCount + 1 end
                    if sd.rank then _rankCount = _rankCount + 1 end
                end
            end
        end
        cell:SetScript("OnEnter", function(s_)
            GameTooltip:SetOwner(s_, "ANCHOR_RIGHT")
            GameTooltip:SetText("No gear data", 1, 0.6, 0)
            if _nil then
                GameTooltip:AddLine("Snapshot predates rank capture.", 1, 0.6, 0, true)
            elseif _ilvlCount == 0 then
                GameTooltip:AddLine("ilvl = 0 for all slots (data not loaded?).", 1, 0.6, 0, true)
            else
                GameTooltip:AddLine(_ilvlCount .. " slots with ilvl, " .. _rankCount .. " with rank.", 1, 0.6, 0, true)
            end
            GameTooltip:AddLine("Log in as this character to refresh.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        return
    end

    local targetTier = row.tierIdx
    local totalCost = CalcTierUpgradeCost(snap, targetTier)

    if totalCost == 0 then
        cell._fs:SetText("\226\128\148")
        cell._fs:SetTextColor(cr, cg, cb, A_EMPTY)
        cell:SetScript("OnEnter", nil)
    else
        cell._fs:SetText(tostring(totalCost))
        cell._fs:SetTextColor(cr, cg, cb, alpha)
        local _snap, _tierIdx = snap, targetTier
        local _name, _cr, _cg, _cb = row.label, cr, cg, cb
        local _total = totalCost
        cell:SetScript("OnEnter", function(s_)
            GameTooltip:SetOwner(s_, "ANCHOR_RIGHT")
            GameTooltip:SetText(_name .. " Upgrade Cost", _cr, _cg, _cb)
            GameTooltip:AddLine("Total: " .. _total .. " crests", 1, 1, 1)
            local TRACKING    = Addon.TRACKING
            local costPerStep
            if _snap.upgradeCostPerStep and _snap.upgradeCostPerStep[_tierIdx] then
                costPerStep = _snap.upgradeCostPerStep[_tierIdx]
            else
                local _costList = TRACKING and TRACKING.crestUpgradeCostPerStep
                costPerStep = (_costList and _costList[_tierIdx]) or 20
            end
            local freeRanks   = (TRACKING and TRACKING.crestUpgradeFreeRanks
                                and TRACKING.crestUpgradeFreeRanks[_tierIdx])   or 0
            if _snap and _snap.gearSlots then
                local hasAny = false
                for _, sid in ipairs(GEAR_SLOT_IDS) do
                    local slotData = _snap.gearSlots[sid]
                    if type(slotData) ~= "table" or slotData.tierIdx ~= _tierIdx
                            or not slotData.rank then
                        -- skip
                    else
                        local effectiveMax = GetSlotEffectiveMax(slotData)
                        if effectiveMax then
                            local isEmbellished = (effectiveMax < (slotData.maxRank or effectiveMax))
                            local needsUpgrade  = (slotData.rank < effectiveMax)
                            if needsUpgrade or (isEmbellished and not needsUpgrade) then
                                if not hasAny then
                                    GameTooltip:AddLine(" ")
                                    hasAny = true
                                end
                                local slotName = GEAR_SLOT_NAMES[sid] or ("Slot " .. sid)
                                if isEmbellished and not needsUpgrade then
                                    -- Item is at its embellished cap — show dimmed with label.
                                    GameTooltip:AddLine(
                                        "|cff666666" .. slotName .. "  "
                                        .. slotData.rank .. "/" .. effectiveMax .. "|r"
                                        .. "  |cffffcc00(Embellishment)|r", 1, 1, 1)
                                else
                                    local remaining = math.max(0,
                                        (effectiveMax - slotData.rank)
                                        - math.max(0, freeRanks - (slotData.rank - 1))
                                    )
                                    local slotCost = remaining * costPerStep
                                    GameTooltip:AddLine(
                                        slotName .. "  " .. slotData.rank .. "/" .. effectiveMax
                                        .. "   (" .. slotCost .. ")", 0.85, 0.85, 0.85)
                                end
                            end
                        end
                    end
                end
            end
            GameTooltip:Show()
        end)
    end
end

local function RenderGVCell(cell, row, snap, noSnap, alpha)
    local gi    = row.gvBlock
    local block = snap and snap.leftGrid and snap.leftGrid[gi]
    local complete = block and tonumber(block.complete) or 0

    cell._fs:SetFont("Fonts\\FRIZQT__.TTF", 10, "")

    if noSnap or not block then
        cell._fs:SetText("—")
        cell._fs:SetTextColor(0.5, 0.5, 0.5, alpha * A_DIM)
    else
        local parts = {}
        for si = 1, 3 do
            local slotData = block.slots and block.slots[si]
            local ilvl     = slotData and tonumber(slotData.ilvl) or 0
            local unlocked = complete >= si
            if unlocked then
                if ilvl > 0 then
                    local hex = (Addon.IlvlUtils and Addon.IlvlUtils.GetColorHex(ilvl)) or "ffffffff"
                    parts[si] = "|c" .. hex .. ilvl .. "|r"
                else
                    parts[si] = "|cff55aa55—|r"
                end
            else
                parts[si] = "|cff555555—|r"
            end
        end
        cell._fs:SetText(table.concat(parts, " "))
        cell._fs:SetTextColor(1, 1, 1, alpha)
    end

    local _snap3, _bi = snap, gi
    cell:SetScript("OnEnter", function(s_)
        local blk    = _snap3 and _snap3.leftGrid and _snap3.leftGrid[_bi]
        local thresh = GV_THRESHOLDS[_bi]
        local cmplt  = blk and tonumber(blk.complete) or 0
        GameTooltip:SetOwner(s_, "ANCHOR_RIGHT")
        GameTooltip:SetText(GV_NAMES[_bi], 1, 0.82, 0)
        if not blk then
            GameTooltip:AddLine("No snapshot data", 0.6, 0.6, 0.6)
            GameTooltip:Show()
            return
        end
        GameTooltip:AddLine("Slots unlocked: " .. cmplt .. "/3", 1, 1, 1)
        GameTooltip:AddLine(" ")
        for si = 1, 3 do
            local need     = thresh[si]
            local unlocked = cmplt >= si
            local slotData = blk.slots and blk.slots[si]
            local ilvl     = slotData and tonumber(slotData.ilvl) or 0
            if unlocked then
                local trackLabel = Addon.IlvlUtils and ilvl > 0 and Addon.IlvlUtils.GetTrackLabel(ilvl)
                local line
                if ilvl > 0 then
                    line = "Slot " .. si .. ": " .. ilvl .. " ilvl"
                    if trackLabel then line = line .. "  (" .. trackLabel .. ")" end
                else
                    line = "Slot " .. si .. ": Unlocked"
                end
                GameTooltip:AddLine(line, 0.3, 1.0, 0.3)
            else
                GameTooltip:AddLine("Slot " .. si .. ": Requires " .. need .. " activities", 0.55, 0.55, 0.55)
            end
        end
        GameTooltip:Show()
    end)
end

PopulateSummary = function(panel)
    ST = ST or Addon.SNAP_TYPES or {}  -- lazy-bind once Currency.lua has registered SNAP_TYPES
    if not _layout then _layout = ComputeLayout() end
    local LAYOUT   = _layout
    local gdb      = Addon.db and Addon.db.global
    local ownKey   = Addon:GetCurrentProfileKey()
    local allKeys  = Addon:GetCharProfileKeys()
    local tracking = Addon.TRACKING
    local th       = Addon.THEME.text
    local brd      = Addon.THEME.border
    local header   = Addon.THEME.header
    local maxLvl   = (GetMaxPlayerLevel and GetMaxPlayerLevel()) or 80

    -- ── Collect visible characters ────────────────────────────────────────────
    local chars    = BuildCharList(gdb, ownKey, allKeys, maxLvl)
    local numChars = #chars

    -- ── Row definitions ───────────────────────────────────────────────────────
    -- Rebuild only when currency/GV visibility has changed; otherwise reuse the cache.
    if _rowsDirty or not _cachedRows then
        local ownCdb  = gdb and gdb.chars and gdb.chars[ownKey]
        local ownSnap = ownCdb and ownCdb.trackingSnapshot
        _cachedRows = BuildRowDefs(tracking, LAYOUT, ownSnap)
        _rowsDirty  = false
    end
    local rows = _cachedRows

    -- ── Sizing ────────────────────────────────────────────────────────────────
    local totalContentH = 0
    for _, row in ipairs(rows) do
        totalContentH = totalContentH + (row.type == "sechdr" and HDR_ROW_H or ROW_H)
    end

    local isInline = panel._inline
    if panel._altsTitleBgTex then panel._altsTitleBgTex:SetShown(not isInline) end
    if panel._altsTitleFS    then panel._altsTitleFS:SetShown(not isInline)    end
    if panel._altsCloseBtn   then panel._altsCloseBtn:SetShown(not isInline)   end

    -- Transparent backdrop when inline (content sits on the main window's bg).
    -- When shown as a standalone popup, use alpha=1 to match the main window's
    -- solid background (the main window paints a fully-opaque bg texture).
    if isInline then
        if panel.SetBackdropColor       then panel:SetBackdropColor(0, 0, 0, 0)       end
        if panel.SetBackdropBorderColor then panel:SetBackdropBorderColor(0, 0, 0, 0) end
    else
        local bg = Addon.THEME.bg
        local bd = Addon.THEME.border
        if panel.SetBackdropColor       then panel:SetBackdropColor(bg.r, bg.g, bg.b, 1.0)       end
        if panel.SetBackdropBorderColor then panel:SetBackdropBorderColor(bd.r, bd.g, bd.b, bd.a) end
        -- Refresh title strip & label with the current header color.
        local h = Addon.THEME.header
        if panel._altsTitleBgTex then panel._altsTitleBgTex:SetColorTexture(h.r, h.g, h.b, 0.09) end
        if panel._altsTitleFS    then panel._altsTitleFS:SetTextColor(h.r, h.g, h.b, 1)          end
    end

    local CONTENT_TOP = isInline and -PAD or -(TITLE_H + 4)
    local COL_HDR_TOP = CONTENT_TOP
    local ROWS_TOP    = COL_HDR_TOP - COL_HDR_H - 2
    local BTNS_TOP    = ROWS_TOP - totalContentH - 4
    local FOOTER_TOP  = BTNS_TOP - BTN_ROW_H - 4
    local TOTAL_H     = math.abs(FOOTER_TOP) + 20 + PAD
    local TOTAL_W     = PAD + COL_LABEL + numChars * COL_W + PAD

    panel:SetSize(math.max(300, TOTAL_W), math.max(120, TOTAL_H))

    -- Hide all pooled widgets from previous call.
    for _, t in ipairs(panel._divTexPool)  do t:Hide() end
    for _, t in ipairs(panel._iconTexPool) do t:Hide() end
    for _, fs in ipairs(panel._rowLblPool) do fs:Hide() end
    for _, h in ipairs(panel._rowHitPool or {}) do h:Hide() end
    for _, col in ipairs(panel._colPool) do
        col.nameFS:Hide()
        if col.ilvlFS     then col.ilvlFS:Hide()     end
        if col.updatedFS  then col.updatedFS:Hide()  end
        if col.classBar   then col.classBar:Hide()   end
        if col.hdrHit     then col.hdrHit:Hide()     end
        col.hideBtn:Hide()
        for _, c in pairs(col.cells) do c:Hide() end
    end

    local divCursor  = 0
    local iconCursor = 0
    local lblCursor  = 0
    local colCursor  = 0
    local hitCursor  = 0

    local function GetDiv()
        divCursor = divCursor + 1
        if not panel._divTexPool[divCursor] then
            panel._divTexPool[divCursor] = panel:CreateTexture(nil, "ARTWORK")
        end
        local t = panel._divTexPool[divCursor]
        t:Show()
        return t
    end
    local function GetIcon()
        iconCursor = iconCursor + 1
        if not panel._iconTexPool[iconCursor] then
            panel._iconTexPool[iconCursor] = panel:CreateTexture(nil, "ARTWORK")
        end
        local t = panel._iconTexPool[iconCursor]
        t:SetSize(ICON_SIZE, ICON_SIZE)
        t:Show()
        return t
    end
    local function GetLbl(size, flags)
        lblCursor = lblCursor + 1
        if not panel._rowLblPool[lblCursor] then
            panel._rowLblPool[lblCursor] = MakeFS(panel, size or 12, flags)
        end
        local fs = panel._rowLblPool[lblCursor]
        fs:SetFont("Fonts\\FRIZQT__.TTF", size or 12, flags or "")
        fs:Show()
        return fs
    end
    if not panel._rowHitPool then panel._rowHitPool = {} end
    local function GetHit()
        hitCursor = hitCursor + 1
        if not panel._rowHitPool[hitCursor] then
            local h = CreateFrame("Frame", nil, panel)
            h:EnableMouse(true)
            h:SetScript("OnLeave", OnCellLeave)
            panel._rowHitPool[hitCursor] = h
        end
        local h = panel._rowHitPool[hitCursor]
        h:Show()
        return h
    end
    local function GetCol()
        colCursor = colCursor + 1
        if not panel._colPool[colCursor] then
            local hdrHit = CreateFrame("Frame", nil, panel)
            hdrHit:EnableMouse(true)
            hdrHit:SetScript("OnLeave", OnCellLeave)
            panel._colPool[colCursor] = {
                nameFS    = MakeFS(panel, 11, ""),
                ilvlFS    = MakeFS(panel, 10, ""),
                updatedFS = MakeFS(panel, FONT_SM, ""),
                classBar  = panel:CreateTexture(nil, "ARTWORK"),
                hdrHit    = hdrHit,
                hideBtn   = Addon.Controls.NewActionButton(panel, BTN_W, BTN_H),
                cells     = {},
            }
        end
        local col = panel._colPool[colCursor]
        col.nameFS:Show()
        if col.ilvlFS     then col.ilvlFS:Show()     end
        if col.updatedFS  then col.updatedFS:Show()  end
        if col.hdrHit     then col.hdrHit:Show()     end
        col.classBar:Show()
        col.hideBtn:Show()
        return col
    end
    local function GetCell(col, rowIdx)
        if not col.cells[rowIdx] then
            col.cells[rowIdx] = MakeCell(panel, COL_W, ROW_H)
        end
        local c = col.cells[rowIdx]
        c:Show()
        return c
    end

    -- ── Column-header background strip ───────────────────────────────────────
    local hdrBg = GetDiv()
    hdrBg:SetColorTexture(brd.r, brd.g, brd.b, 0.22)
    hdrBg:SetPoint("TOPLEFT",  panel, "TOPLEFT",  1,  COL_HDR_TOP)
    hdrBg:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, COL_HDR_TOP)
    hdrBg:SetHeight(COL_HDR_H + 2)

    -- Horizontal divider below column headers.
    local hdrDiv = GetDiv()
    hdrDiv:SetHeight(1)
    hdrDiv:SetColorTexture(brd.r, brd.g, brd.b, 0.55)
    hdrDiv:SetPoint("TOPLEFT",  panel, "TOPLEFT",  PAD, ROWS_TOP)
    hdrDiv:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, ROWS_TOP)

    -- ── Button strip background (above footer checkbox) ───────────────────────
    local btnsBg = GetDiv()
    btnsBg:SetColorTexture(brd.r, brd.g, brd.b, 0.18)
    btnsBg:SetPoint("TOPLEFT",  panel, "TOPLEFT",  1, BTNS_TOP)
    btnsBg:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, BTNS_TOP)
    btnsBg:SetHeight(BTN_ROW_H)

    local btnsDiv = GetDiv()
    btnsDiv:SetHeight(1)
    btnsDiv:SetColorTexture(brd.r, brd.g, brd.b, 0.50)
    btnsDiv:SetPoint("TOPLEFT",  panel, "TOPLEFT",  PAD, BTNS_TOP)
    btnsDiv:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, BTNS_TOP)

    -- ── Left label column ─────────────────────────────────────────────────────
    -- Vertical divider separating labels from data columns.
    local lblDiv = GetDiv()
    lblDiv:SetWidth(1)
    lblDiv:SetColorTexture(brd.r, brd.g, brd.b, 0.40)
    lblDiv:SetPoint("TOPLEFT",    panel, "TOPLEFT", PAD + COL_LABEL - 1, ROWS_TOP)
    lblDiv:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", PAD + COL_LABEL - 1, FOOTER_TOP)

    -- Row labels (left column).
    local curRowY = ROWS_TOP
    for ri, row in ipairs(rows) do
        local h = (row.type == "sechdr") and HDR_ROW_H or ROW_H

        if row.type == "sechdr" then
            local secBg = GetDiv()
            secBg:SetColorTexture(header.r, header.g, header.b, 0.08)
            secBg:SetPoint("TOPLEFT",  panel, "TOPLEFT",   1, curRowY)
            secBg:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, curRowY)
            secBg:SetHeight(h)

            local secFS = GetLbl(10, "")
            secFS:SetTextColor(header.r, header.g, header.b, 0.90)
            secFS:SetJustifyH("LEFT")
            secFS:SetJustifyV("MIDDLE")
            secFS:SetText(row.label)
            secFS:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD + 4, curRowY)
            secFS:SetSize(COL_LABEL - 4, h)
            if row.action then
                secBg:EnableMouse(true)
                secBg:SetScript("OnMouseUp", function()
                    if row.action == "currency" then
                        ToggleCharacter("TokenFrame")
                    elseif row.action == "greatvault" then
                        if not WeeklyRewardsFrame then C_AddOns.LoadAddOn("Blizzard_WeeklyRewards") end
                        if WeeklyRewardsFrame then
                            if WeeklyRewardsFrame:IsShown() then WeeklyRewardsFrame:Hide()
                            else WeeklyRewardsFrame:Show() end
                        end
                    end
                end)
                secBg:SetScript("OnEnter", function(s_)
                    GameTooltip:SetOwner(s_, "ANCHOR_RIGHT")
                    GameTooltip:SetText("Click to open", 1, 1, 1)
                    GameTooltip:Show()
                end)
                secBg:SetScript("OnLeave", function() GameTooltip:Hide() end)
            end
        else
            local rowBg = GetDiv()
            if (ri % 2) == 0 then
                rowBg:SetColorTexture(1, 1, 1, 0.03)
            else
                rowBg:SetColorTexture(0, 0, 0, 0.10)
            end
            rowBg:SetPoint("TOPLEFT",  panel, "TOPLEFT",   1, curRowY)
            rowBg:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, curRowY)
            rowBg:SetHeight(h - 1)

            local rowSep = GetDiv()
            rowSep:SetHeight(1)
            rowSep:SetColorTexture(brd.r, brd.g, brd.b, 0.18)
            rowSep:SetPoint("TOPLEFT",  panel, "TOPLEFT",   PAD, curRowY - h + 1)
            rowSep:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, curRowY - h + 1)

            -- Currency icon (if available for this row).
            local textX, textW
            if row.iconID then
                local iconTex  = GetIcon()
                iconTex:SetTexture(row.iconID)
                local iconOffY = curRowY - math.floor((h - ICON_SIZE) / 2)
                iconTex:ClearAllPoints()
                iconTex:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD + 2, iconOffY)
                textX = PAD + 2 + ICON_SIZE + 2  -- 6+2+14+2 = 24px from left edge
                textW = COL_LABEL - 2 - ICON_SIZE - 2 - 2
            else
                textX = PAD + 4
                textW = COL_LABEL - 8
            end

            local lblFS = GetLbl(row.iconID and 10 or 11, "")
            if row.type == "crest" or row.type == "upgcost" then
                lblFS:SetTextColor(row.cr or th.r, row.cg or th.g, row.cb or th.b, 0.90)
            elseif row.type == "catalyst" or row.type == "sparks"
                or row.type == "keys"     or row.type == "misc" then
                lblFS:SetTextColor(1, 0.82, 0, 0.85)  -- WoW gold for all currency rows
            else
                lblFS:SetTextColor(th.r, th.g, th.b, 0.80)
            end
            lblFS:SetJustifyH("LEFT")
            lblFS:SetJustifyV("MIDDLE")
            lblFS:SetText(row.label)
            lblFS:SetPoint("TOPLEFT", panel, "TOPLEFT", textX, curRowY)
            lblFS:SetSize(textW, h)

            -- Transparent hit frame so hovering the label shows the currency tooltip.
            local cID = row.currencyID or (row.type == "misc" and row.miscID)
            if cID then
                local hit = GetHit()
                hit:ClearAllPoints()
                hit:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, curRowY)
                hit:SetSize(COL_LABEL - PAD, h - 1)
                local _cid = tonumber(cID)
                hit:SetScript("OnEnter", function(s_)
                    if not _cid then return end
                    GameTooltip:SetOwner(s_, "ANCHOR_RIGHT")
                    GameTooltip:SetCurrencyByID(_cid)
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("Right-click to hide", 0.5, 0.5, 0.5)
                    GameTooltip:Show()
                end)
                hit:SetScript("OnMouseUp", function(s_, button)
                    if button ~= "RightButton" then return end
                    Addon:ShowContextMenu(s_, {
                        { text = "Hide this currency", onClick = function()
                            Addon:SetCurrencyHidden(_cid, true)
                        end },
                    })
                end)
            end
        end

        curRowY = curRowY - h
    end

    -- Footer divider + checkbox.
    local footerDiv = GetDiv()
    footerDiv:SetHeight(1)
    footerDiv:SetColorTexture(brd.r, brd.g, brd.b, 0.40)
    footerDiv:SetPoint("TOPLEFT",  panel, "TOPLEFT",   PAD, FOOTER_TOP)
    footerDiv:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, FOOTER_TOP)

    local chk = panel._footerChk
    if chk then
        chk:ClearAllPoints()
        chk:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD + 4, FOOTER_TOP - 4)
        chk:SetSize(14, 14)
        if chk._hit then
            chk._hit:ClearAllPoints()
            chk._hit:SetPoint("LEFT",  chk, "LEFT",  -2, 0)
            chk._hit:SetPoint("RIGHT", chk, "RIGHT", 160, 0)
            chk._hit:SetHeight(18)
        end
    end

    -- "+ Add task" button — only visible in inline (completion) mode.
    local addBtn = panel._addTaskBtn
    if isInline then
        if not addBtn then
            addBtn = CreateFrame("Button", nil, panel)
            addBtn:SetSize(90, 18)
            local fs = addBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            fs:SetAllPoints()
            fs:SetText("|cff00cc44+|r Add task")
            addBtn._fs = fs
            addBtn:SetScript("OnClick", function()
                StaticPopup_Show("LARIAS_ADD_CUSTOM_ITEM")
            end)
            addBtn:SetScript("OnEnter", function(self_)
                self_._fs:SetTextColor(1, 1, 0.4, 1)
            end)
            addBtn:SetScript("OnLeave", function(self_)
                self_._fs:SetTextColor(1, 1, 1, 1)
            end)
            panel._addTaskBtn = addBtn
        end
        addBtn:ClearAllPoints()
        addBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, FOOTER_TOP - 3)
        addBtn:Show()
    elseif addBtn then
        addBtn:Hide()
    end

    -- ── Character columns ─────────────────────────────────────────────────────
    local crestIDs = {}
    if tracking and tracking.crestCurrencyIDs then
        for i = 1, NUM_CRESTS do crestIDs[i] = tracking.crestCurrencyIDs[i] end
    end

    -- Button Y position: vertically centered within BTN_ROW_H strip.
    local btnY = BTNS_TOP - math.floor((BTN_ROW_H - BTN_H) / 2)

    for ci, char in ipairs(chars) do
        local colX   = PAD + COL_LABEL + (ci - 1) * COL_W
        local snap   = char.snap
        local noSnap = not snap

        -- Vertical column separator.
        if ci > 1 then
            local colSep = GetDiv()
            colSep:SetWidth(1)
            colSep:SetColorTexture(brd.r, brd.g, brd.b, 0.30)
            colSep:SetPoint("TOPLEFT",    panel, "TOPLEFT", colX - 1, COL_HDR_TOP)
            colSep:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", colX - 1, FOOTER_TOP)
        end

        local col = GetCol()

        -- Thin class-color bar at top of the name header.
        col.classBar:SetColorTexture(char.cr, char.cg, char.cb, 0.35)
        col.classBar:SetPoint("TOPLEFT",  panel, "TOPLEFT", colX,         COL_HDR_TOP)
        col.classBar:SetPoint("TOPRIGHT", panel, "TOPLEFT", colX + COL_W, COL_HDR_TOP)
        col.classBar:SetHeight(2)

        -- Character name.
        local charName = (char.key:match("^(.-)%s*%-") or char.key):gsub("^%s+",""):gsub("%s+$","")
        if charName == "" then charName = char.key end
        local maxChars = math.floor(COL_W / 7)
        if #charName > maxChars then charName = charName:sub(1, maxChars - 1) .. "." end

        col.nameFS:SetText(charName)
        col.nameFS:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
        col.nameFS:SetTextColor(char.cr, char.cg, char.cb, char.alpha)
        col.nameFS:SetJustifyH("CENTER")
        col.nameFS:SetJustifyV("MIDDLE")
        col.nameFS:ClearAllPoints()
        col.nameFS:SetPoint("TOPLEFT", panel, "TOPLEFT", colX, COL_HDR_TOP - 2)
        col.nameFS:SetSize(COL_W, 18)

        -- Item level below character name.
        if col.ilvlFS then
            local ilvlText = (char.ilvl and char.ilvl > 0) and tostring(math.floor(char.ilvl)) or ""
            col.ilvlFS:SetText(ilvlText)
            col.ilvlFS:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
            -- Color by the highest crest tier the character qualifies for.
            local ir, ig, ib = 0.85, 0.75, 0.5  -- default warm-gold fallback
            if char.ilvl and char.ilvl > 0 and Addon.IlvlUtils then
                local tier   = Addon.IlvlUtils.GetTier(char.ilvl)
                local colors = Addon.TRACKING and Addon.TRACKING.crestColors
                if tier and colors and colors[tier] then
                    ir, ig, ib = HexToRGB(colors[tier])
                end
            end
            col.ilvlFS:SetTextColor(ir, ig, ib, char.alpha * A_ILVL)
            col.ilvlFS:SetJustifyH("CENTER")
            col.ilvlFS:SetJustifyV("MIDDLE")
            col.ilvlFS:ClearAllPoints()
            col.ilvlFS:SetPoint("TOPLEFT", panel, "TOPLEFT", colX, COL_HDR_TOP - 20)
            col.ilvlFS:SetSize(COL_W, 13)
        end

        -- Last-updated timestamp below ilvl.
        if col.updatedFS then
            local updText, updAlpha = "—", 0.35
            if snap and snap.updatedAt then
                updText  = date("%b %d", snap.updatedAt)
                updAlpha = 0.45
            end
            col.updatedFS:SetText(updText)
            col.updatedFS:SetFont("Fonts\\FRIZQT__.TTF", FONT_SM - 2, "")
            col.updatedFS:SetTextColor(th.r, th.g, th.b, char.alpha * updAlpha)
            col.updatedFS:SetJustifyH("CENTER")
            col.updatedFS:SetJustifyV("MIDDLE")
            col.updatedFS:ClearAllPoints()
            col.updatedFS:SetPoint("TOPLEFT", panel, "TOPLEFT", colX, COL_HDR_TOP - 33)
            col.updatedFS:SetSize(COL_W, 11)
        end

        -- Column-header hit region: tooltip showing full last-updated datetime.
        if col.hdrHit then
            col.hdrHit:ClearAllPoints()
            col.hdrHit:SetPoint("TOPLEFT", panel, "TOPLEFT", colX, COL_HDR_TOP)
            col.hdrHit:SetSize(COL_W, COL_HDR_H)
            local _snap, _name, _cr, _cg, _cb = snap, charName, char.cr, char.cg, char.cb
            local _ck = char.key
            col.hdrHit:SetScript("OnEnter", function(s_)
                GameTooltip:SetOwner(s_, "ANCHOR_RIGHT")
                GameTooltip:SetText(_name, _cr, _cg, _cb)
                if _snap and _snap.updatedAt then
                    GameTooltip:AddLine("Last updated: " .. date("%b %d %Y %H:%M", _snap.updatedAt), 0.65, 0.65, 0.65)
                else
                    GameTooltip:AddLine("No snapshot data", 0.5, 0.5, 0.5)
                end
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Click to view gear", 0.5, 0.5, 0.5)
                GameTooltip:Show()
            end)
            col.hdrHit:SetScript("OnMouseUp", function(s_, button)
                if button == "LeftButton" then
                    if _gearPopupFrame and _gearPopupFrame:IsShown()
                       and _gearPopupFrame._charKey == _ck then
                        _gearPopupFrame:Hide()
                    else
                        ShowGearPopup(s_, _ck, _name, _cr, _cg, _cb, _snap)
                    end
                end
            end)
        end

        -- Hide button centered in the column.
        local btnX = colX + math.floor((COL_W - BTN_W) / 2)

        col.hideBtn:ClearAllPoints()
        col.hideBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", btnX, btnY)
        col.hideBtn:SetSize(BTN_W, BTN_H)

        if char.isOwn then
            col.hideBtn:SetText("—")
            col.hideBtn:SetEnabled(false)
            local fs = Addon.Controls.GetButtonFontString(col.hideBtn)
            if fs then fs:SetTextColor(0.3, 0.3, 0.3, 1) end
            col.hideBtn:SetScript("OnClick", nil)
        elseif char.isHidden then
            col.hideBtn:SetText("Show")
            col.hideBtn:SetEnabled(true)
            local fs = Addon.Controls.GetButtonFontString(col.hideBtn)
            if fs then fs:SetTextColor(0.5, 1, 0.5, 1) end
            local _ck = char.key
            col.hideBtn:SetScript("OnClick", function()
                if gdb then gdb.hiddenChars = gdb.hiddenChars or {}; gdb.hiddenChars[_ck] = nil end
                if Addon.CharPicker and Addon.CharPicker.Populate then Addon.CharPicker.Populate() end
                if Addon.LayoutHeaderButtons then Addon:LayoutHeaderButtons() end
                _rowsDirty = true
                PopulateSummary(panel)
            end)
        else
            col.hideBtn:SetText("Hide")
            col.hideBtn:SetEnabled(true)
            local fs = Addon.Controls.GetButtonFontString(col.hideBtn)
            if fs then fs:SetTextColor(1, 0.5, 0.5, 1) end
            local _ck = char.key
            col.hideBtn:SetScript("OnClick", function()
                if gdb then
                    gdb.hiddenChars = gdb.hiddenChars or {}
                    gdb.hiddenChars[_ck] = true
                    if Addon._viewingChar == _ck then Addon:SetViewingChar(nil) end
                end
                if Addon.CharPicker and Addon.CharPicker.Populate then Addon.CharPicker.Populate() end
                if Addon.LayoutHeaderButtons then Addon:LayoutHeaderButtons() end
                _rowsDirty = true
                PopulateSummary(panel)
            end)
        end

        -- Pre-extract all snapshot data.
        local sd = ExtractSnapData(snap, crestIDs, LAYOUT)
        -- Find the highest-tier crest that has a trade-up value (only that tier shows +N).
        local highestTuIdx = 0
        for i = NUM_CRESTS, 1, -1 do
            if (sd.crestTradeups[i] or 0) > 0 then highestTuIdx = i; break end
        end
        local gvR, gvM, gvW = CalcGVBreakdown(snap)

        -- Data cells.
        local cellRowY = ROWS_TOP
        for ri, row in ipairs(rows) do
            local h = (row.type == "sechdr") and HDR_ROW_H or ROW_H

            if row.type ~= "sechdr" then
                local cell = GetCell(col, ri)
                cell:ClearAllPoints()
                cell:SetPoint("TOPLEFT", panel, "TOPLEFT", colX, cellRowY)
                cell:SetSize(COL_W, h)

                cell._fs:SetFont("Fonts\\FRIZQT__.TTF", FONT_CELL, "")
                cell._fs:SetText("—")
                cell._fs:SetTextColor(th.r, th.g, th.b, A_DIM)
                cell._tu:SetText("")
                cell:SetScript("OnEnter", nil)

                local alpha = char.alpha
                local rtype = row.type

                if rtype == "crest" then
                    RenderCrestCell(cell, row, sd, noSnap, alpha, th, crestIDs, highestTuIdx)
                elseif rtype == "catalyst" then
                    RenderCatalystCell(cell, row, sd, noSnap, alpha, th)
                elseif rtype == "sparks" then
                    RenderSparksCell(cell, row, sd, noSnap, alpha, th)
                elseif rtype == "keys" then
                    RenderKeysCell(cell, row, sd, noSnap, alpha, th)
                elseif rtype == "misc" then
                    RenderMiscCell(cell, row, sd, noSnap, alpha, th)
                elseif rtype == "quest" then
                    RenderQuestCell(cell, row, sd, noSnap, alpha, th)
                elseif rtype == "upgcost" then
                    RenderUpgradeCostCell(cell, row, snap, noSnap, alpha, th)
                elseif rtype == "keystone" then
                    RenderKeystoneCell(cell, row, snap, noSnap, alpha, th)
                elseif rtype == "gv" then
                    RenderGVCell(cell, row, snap, noSnap, alpha)
                end

                cell:SetScript("OnMouseUp", nil)
            end

            cellRowY = cellRowY - h
        end
    end

    -- No-chars placeholder.
    if numChars == 0 then
        local noCharFS = GetLbl(11, "")
        noCharFS:SetTextColor(th.r, th.g, th.b, 0.5)
        noCharFS:SetJustifyH("CENTER")
        noCharFS:SetJustifyV("MIDDLE")
        noCharFS:SetText("No characters found")
        noCharFS:SetPoint("CENTER", panel, "CENTER", 0, 0)
        noCharFS:SetSize(200, 30)
    end
end

-- ── Public API ────────────────────────────────────────────────────────────────

function Addon:OpenAltsSummary(anchorFrame)
    -- Ensure the own character's snapshot is current before rendering, in case
    -- PLAYER_ENTERING_WORLD already fired before these fixes were in place or
    -- the user has been in-game without opening the main window first.
    if self.UpdateSnapshotBackground then self:UpdateSnapshotBackground() end
    local f = EnsurePanel()
    if not f._wasMoved then
        f:ClearAllPoints()
        if anchorFrame then
            f:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, -4)
        else
            f:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
        end
        f:SetClampedToScreen(true)
    end
    f._inline  = false
    _rowsDirty = true  -- always rebuild on open; state may have changed while panel was hidden
    PopulateSummary(f)
    f:Show()
end

function Addon:OpenAltsSummaryInline(mainFrame)
    -- Like OpenAltsSummary, but positions the panel at the top of the main
    -- window's scroll area instead of below it.  Used when the list is complete
    -- so the Alt Summary replaces the empty scroll content inline.
    if self.UpdateSnapshotBackground then self:UpdateSnapshotBackground() end
    local f = EnsurePanel()
    if not f._wasMoved then
        f:ClearAllPoints()
        if mainFrame then
            local padX      = (Addon.UI and Addon.UI.padOuterX)  or 6
            local scrollTop = (Addon.UI and Addon.UI.scrollTop)   or 60
            f:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", padX, -scrollTop)
        else
            f:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
        end
        f:SetClampedToScreen(true)
    end
    f._inline  = true
    _rowsDirty = true
    PopulateSummary(f)
    f:Show()
end

function Addon:CloseAltsSummary()
    if altSummaryFrame then altSummaryFrame:Hide() end
    if _gearPopupFrame then _gearPopupFrame:Hide() end
end

function Addon:GetAltsSummaryWidth()
    return altSummaryFrame and altSummaryFrame.GetWidth and altSummaryFrame:GetWidth() or nil
end

function Addon:GetAltsSummaryHeight()
    return altSummaryFrame and altSummaryFrame.GetHeight and altSummaryFrame:GetHeight() or nil
end

function Addon:ToggleAltsSummary(anchorFrame)
    local f = altSummaryFrame
    if f and f.IsShown and f:IsShown() then
        if _gearPopupFrame then _gearPopupFrame:Hide() end
        f:Hide()
    else
        self:OpenAltsSummary(anchorFrame)
    end
end

function Addon:RefreshAltsSummary()
    if altSummaryFrame and altSummaryFrame.IsShown and altSummaryFrame:IsShown() then
        _rowsDirty = true  -- currency/GV hidden state may have changed
        PopulateSummary(altSummaryFrame)
    end
end
