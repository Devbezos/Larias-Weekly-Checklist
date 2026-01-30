-- Checklist.lua
local addonName = ...
local Addon = _G[addonName] or {}
_G[addonName] = Addon

if Addon.InitConstants then
    Addon:InitConstants(addonName)
end

local frame
local scrollFrame
local scrollChild

local THEME = Addon.THEME
local UI = Addon.UI

-- Pools/state
Addon._sectionPool = Addon._sectionPool or {}
Addon._checkboxPool = Addon._checkboxPool or {}
Addon._activeSections = Addon._activeSections or {}

Addon._dataSig = Addon._dataSig or ""
Addon._sectionsById = Addon._sectionsById or {}
Addon._order = Addon._order or {}
Addon._sectionsIndexById = Addon._sectionsIndexById or {}

-- =========================
-- Shared helpers
-- =========================
function Addon:DB()
    return _G[self._DB_NAME]
end

local function CopyTableShallow(src)
    if type(src) ~= "table" then return {} end
    local dst = {}
    for k, v in pairs(src) do
        if type(v) == "table" then
            local child = {}
            for ck, cv in pairs(v) do
                child[ck] = cv
            end
            dst[k] = child
        else
            dst[k] = v
        end
    end
    return dst
end

function Addon:EnsureDB()
    if not self:DB() then _G[self._DB_NAME] = {} end
    local db = self:DB()

    -- One-time migration: copy legacy account-wide data into this character's DB.
    -- (Keeps existing checkmarks, but characters can diverge afterwards.)
    if db._migratedFromAccountDB ~= true then
        local legacyName = self._ACCOUNT_DB_NAME
        local legacy = legacyName and _G[legacyName] or nil
        if type(legacy) == "table" then
            -- Only migrate into an empty/new per-character DB.
            local hasAnyChecks = (type(db.checked) == "table") and (next(db.checked) ~= nil)
            if not hasAnyChecks then
                if type(legacy.checked) == "table" then db.checked = CopyTableShallow(legacy.checked) end
                if type(legacy.collapsedSections) == "table" then db.collapsedSections = CopyTableShallow(legacy.collapsedSections) end
                if legacy.hideCompletedSections ~= nil then db.hideCompletedSections = legacy.hideCompletedSections and true or false end
                if legacy.showCurrency ~= nil then db.showCurrency = legacy.showCurrency and true or false end
            end
        end
        db._migratedFromAccountDB = true
    end

    db.checked = db.checked or {}
    db.collapsedSections = db.collapsedSections or {}
    if db.hideCompletedSections == nil then db.hideCompletedSections = false end
    if db.showCurrency == nil then db.showCurrency = true end
    return db
end

function Addon:GetListData()
    local data = _G[self._LIST_DATA_KEY]
    if type(data) == "table" then return data end
    return {}
end

function Addon:ApplyTheme(f)
    if not f or not f.SetBackdrop then return end
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        edgeSize = 1,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(THEME.bg.r, THEME.bg.g, THEME.bg.b, THEME.bg.a)
    f:SetBackdropBorderColor(THEME.border.r, THEME.border.g, THEME.border.b, THEME.border.a)
end

-- Reserves/reclaims space for tracking panel (Currency.lua sets Addon._trackingFrame)
function Addon:ApplyScrollLayout()
    if not (frame and scrollFrame) then return end
    local db = self:EnsureDB()

    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", UI.padOuterX, -UI.scrollTop)

    local extra = 0
    if db.showCurrency and self._trackingFrame then
        extra = UI.trackH + UI.trackTopPad
    end

    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -UI.scrollRight, UI.scrollBottom + extra)
end

-- =========================
-- Checklist logic
-- =========================
local function Key(sectionId, itemId)
    return tostring(sectionId) .. ":" .. tostring(itemId)
end

local function IsItemChecked(sectionId, itemId)
    local db = Addon:EnsureDB()
    return db.checked[Key(sectionId, itemId)] and true or false
end

local function SetItemChecked(sectionId, itemId, checked)
    local db = Addon:EnsureDB()
    db.checked[Key(sectionId, itemId)] = checked and true or nil
end

local function IsSectionCollapsed(sectionId)
    local db = Addon:EnsureDB()
    return db.collapsedSections[sectionId] or false
end

local function SetSectionCollapsed(sectionId, collapsed)
    local db = Addon:EnsureDB()
    db.collapsedSections[sectionId] = collapsed and true or nil
end

local function IsSectionCompleteById(sectionId)
    local section = Addon._sectionsById[sectionId]
    if not section then return false end
    for _, item in ipairs(section.items or {}) do
        if not IsItemChecked(sectionId, item.id) then
            return false
        end
    end
    return true
end

local function AcquireSectionFrame()
    local sf = table.remove(Addon._sectionPool)
    if sf then
        sf:Show()
        return sf
    end

    sf = CreateFrame("Frame", nil, scrollChild)
    sf:SetWidth(1)
    sf._checkboxes = {}

    local header = CreateFrame("Button", nil, sf)
    header:SetPoint("TOPLEFT", sf, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", sf, "TOPRIGHT", 0, 0)
    header:SetHeight(UI.headerMinH)
    sf._header = header

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", header, "LEFT", 0, 0)
    title:SetTextColor(THEME.header.r, THEME.header.g, THEME.header.b, THEME.header.a)
    title:SetJustifyH("LEFT")
    if title.SetWordWrap then title:SetWordWrap(true) end
    sf._title = title

    local status = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    status:SetPoint("RIGHT", header, "RIGHT", 0, 0)
    status:SetTextColor(THEME.textDim.r, THEME.textDim.g, THEME.textDim.b, THEME.textDim.a)
    sf._status = status

    return sf
end

local function ReleaseSectionFrame(sf)
    if not sf then return end
    sf:Hide()
    sf:ClearAllPoints()
    sf._sectionId = nil
    sf._index = nil

    if sf._checkboxes then
        for i = #sf._checkboxes, 1, -1 do
            local cb = sf._checkboxes[i]
            cb:Hide()
            cb:ClearAllPoints()
            cb._sectionId = nil
            cb._itemId = nil
            cb._dbKey = nil
            cb:SetScript("OnClick", nil)
            table.insert(Addon._checkboxPool, cb)
            sf._checkboxes[i] = nil
        end
    end

    sf._header:SetScript("OnClick", nil)
    table.insert(Addon._sectionPool, sf)
end

local function AcquireCheckbox(sf)
    local cb = table.remove(Addon._checkboxPool)
    if cb then
        cb:SetParent(sf)
        cb:Show()
        return cb
    end

    cb = CreateFrame("CheckButton", nil, sf, "UICheckButtonTemplate")
    local txt = cb.text or cb.Text
    if txt then
        txt:SetJustifyH("LEFT")
        if txt.SetWordWrap then txt:SetWordWrap(true) end
        if txt.SetTextColor then
            txt:SetTextColor(THEME.text.r, THEME.text.g, THEME.text.b, THEME.text.a)
        end
    end
    return cb
end

local function ComputeHeaderHeight(sf, headerTextWidth)
    sf._title:SetWidth(headerTextWidth)
    local th = 0
    if sf._title.GetStringHeight then
        th = sf._title:GetStringHeight() or 0
    end
    local hh = math.max(UI.headerMinH, th + 6)
    sf._header:SetHeight(hh)
    sf._headerBlockHeight = hh + UI.headerBottomPad
end

local function LayoutItems(sf, collapsed)
    local y = -(sf._headerBlockHeight or (UI.headerMinH + UI.headerBottomPad))
    local total = 0
    for _, cb in ipairs(sf._checkboxes) do
        cb:ClearAllPoints()
        cb:SetPoint("TOPLEFT", sf, "TOPLEFT", 0, y)
        local rh = cb:GetHeight() or UI.itemMinH
        y = y - rh
        total = total + rh
        cb:SetShown(not collapsed)
    end
    sf._itemsHeight = total
end

local function UpdateSectionHeight(sf, collapsed)
    local h = (sf._headerBlockHeight or (UI.headerMinH + UI.headerBottomPad))
    if not collapsed then
        h = h + (sf._itemsHeight or 0)
    end
    sf:SetHeight(h)
end

local function LayoutFrom(startIndex)
    local y = -UI.sectionTopPad
    local paddingX = UI.sectionInsetX

    for i = 1, #Addon._activeSections do
        local sf = Addon._activeSections[i]
        if sf:IsShown() then
            if i < startIndex then
                y = y - sf:GetHeight() - UI.sectionGap
            else
                sf:ClearAllPoints()
                sf:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", paddingX, y)
                sf:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -paddingX, y)
                y = y - sf:GetHeight() - UI.sectionGap
            end
        end
    end

    local height = math.max(1, -y + UI.sectionGap)
    scrollChild:SetHeight(height)
end

local function CalcDataSig(data)
    if type(data) ~= "table" then return "" end
    -- List data is static for the session; cache the computed signature on the table
    -- to avoid rebuilding the signature string on every Refresh().
    if data.__lariasSig and data.__lariasSigN == #data then
        return data.__lariasSig
    end
    local parts = {}
    parts[#parts + 1] = tostring(#data)
    for i = 1, #data do
        local s = data[i]
        parts[#parts + 1] = tostring(s.id)
        local items = s.items or {}
        parts[#parts + 1] = tostring(#items)
        for j = 1, #items do
            parts[#parts + 1] = tostring(items[j].id)
        end
    end
    local sig = table.concat(parts, "|")
    data.__lariasSig = sig
    data.__lariasSigN = #data
    return sig
end

local function SetHeaderText(sf, sectionId)
    local section = Addon._sectionsById[sectionId]
    local complete = IsSectionCompleteById(sectionId)
    local titleText = tostring((section and section.title) or sectionId)
    if complete then titleText = "[Done] " .. titleText end
    sf._title:SetText(titleText)
    sf._status:SetText("")
end

local function OnCheckboxClick(selfBtn)
    local db = Addon:EnsureDB()
    local checked = selfBtn:GetChecked() and true or nil
    db.checked[selfBtn._dbKey or Key(selfBtn._sectionId, selfBtn._itemId)] = checked

    local sid = selfBtn._sectionId
    local secCompleteNow = IsSectionCompleteById(sid)
    if secCompleteNow then
        SetSectionCollapsed(sid, true)
    end

    local sframe = Addon._activeSections[Addon._sectionsIndexById[sid]]
    if not sframe then return end

    local hideDone = Addon:EnsureDB().hideCompletedSections and true or false

    SetHeaderText(sframe, sid)
    ComputeHeaderHeight(sframe, UI.itemTextWidth + UI.headerTextExtraW)

    local collapsed = IsSectionCollapsed(sid) or false
    if secCompleteNow then collapsed = true end

    LayoutItems(sframe, collapsed)
    UpdateSectionHeight(sframe, collapsed)

    if hideDone and secCompleteNow then
        sframe:Hide()
    else
        sframe:Show()
    end

    LayoutFrom(sframe._index or 1)
end

local function OnHeaderClick(header)
    local sf = header and header._sectionFrame
    if not sf then return end
    local sid = sf._sectionId
    SetSectionCollapsed(sid, not IsSectionCollapsed(sid))
    UpdateSectionVisuals(sf, sid)
    LayoutFrom(sf._index or 1)
end

local function SyncCheckboxesForSection(sf, sectionId)
    local section = Addon._sectionsById[sectionId]
    local items = (section and section.items) or {}

    local want = #items
    local have = #sf._checkboxes

    if have > want then
        for i = have, want + 1, -1 do
            local cb = sf._checkboxes[i]
            cb:Hide()
            cb:ClearAllPoints()
            cb._sectionId = nil
            cb._itemId = nil
            cb:SetScript("OnClick", nil)
            table.insert(Addon._checkboxPool, cb)
            sf._checkboxes[i] = nil
        end
    elseif have < want then
        for i = have + 1, want do
            sf._checkboxes[i] = AcquireCheckbox(sf)
        end
    end

    for i = 1, want do
        local item = items[i]
        local cb = sf._checkboxes[i]

        cb._sectionId = sectionId
        cb._itemId = item.id
        cb._dbKey = Key(sectionId, item.id)

        local txt = cb.text or cb.Text
        if txt then
            txt:SetWidth(UI.itemTextWidth)
            txt:SetText(tostring(item.text or item.id))

            local textHeight = 0
            if txt.GetStringHeight then
                textHeight = txt:GetStringHeight() or 0
            end
            cb:SetHeight(math.max(UI.itemMinH, textHeight + UI.itemTextPad))
        else
            cb:SetHeight(UI.itemMinH)
        end

        cb:SetChecked(IsItemChecked(sectionId, item.id))

        cb:SetScript("OnClick", OnCheckboxClick)
    end
end

local function UpdateSectionVisuals(sf, sectionId)
    local complete = IsSectionCompleteById(sectionId)

    local hideDone = Addon:EnsureDB().hideCompletedSections and true or false
    if hideDone and complete then
        sf:Hide()
        return
    end

    sf:Show()

    if complete then
        SetSectionCollapsed(sectionId, true)
    end

    SetHeaderText(sf, sectionId)
    ComputeHeaderHeight(sf, UI.itemTextWidth + UI.headerTextExtraW)

    local collapsed = IsSectionCollapsed(sectionId) or false
    if complete then collapsed = true end

    for i = 1, #sf._checkboxes do
        local cb = sf._checkboxes[i]
        if cb and cb._itemId ~= nil then
            cb:SetChecked(IsItemChecked(sectionId, cb._itemId))
        end
    end

    LayoutItems(sf, collapsed)
    UpdateSectionHeight(sf, collapsed)
end

local function SyncAllDataAndFrames()
    Addon:EnsureDB()

    local data = Addon:GetListData()
    local sig = CalcDataSig(data)

    -- Only rebuild section indices if the underlying list data changed.
    if Addon._dataSig ~= sig or not Addon._sectionsById or not next(Addon._sectionsById) then
        Addon._sectionsById = {}
        Addon._order = {}
        for i = 1, #data do
            local s = data[i]
            Addon._sectionsById[s.id] = s
            Addon._order[i] = s.id
        end

        for i = #Addon._activeSections, 1, -1 do
            ReleaseSectionFrame(Addon._activeSections[i])
            Addon._activeSections[i] = nil
        end
        Addon._dataSig = sig
    end

    if wipe then
        wipe(Addon._sectionsIndexById)
    else
        Addon._sectionsIndexById = {}
    end

    local want = #Addon._order
    local have = #Addon._activeSections

    if have > want then
        for i = have, want + 1, -1 do
            ReleaseSectionFrame(Addon._activeSections[i])
            Addon._activeSections[i] = nil
        end
    elseif have < want then
        for i = have + 1, want do
            Addon._activeSections[i] = AcquireSectionFrame()
        end
    end

    for i = 1, want do
        local sectionId = Addon._order[i]
        local sf = Addon._activeSections[i]
        sf:SetParent(scrollChild)
        sf._sectionId = sectionId
        sf._index = i
        Addon._sectionsIndexById[sectionId] = i

        SyncCheckboxesForSection(sf, sectionId)

        sf._header._sectionFrame = sf
        sf._header:SetScript("OnClick", OnHeaderClick)

        UpdateSectionVisuals(sf, sectionId)
    end
end

-- =========================
-- Public API
-- =========================
function Addon:Refresh()
    if not frame then return end
    SyncAllDataAndFrames()

    local y = -UI.sectionTopPad
    local paddingX = UI.sectionInsetX

    for i = 1, #self._activeSections do
        local sf = self._activeSections[i]
        if sf:IsShown() then
            sf:ClearAllPoints()
            sf:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", paddingX, y)
            sf:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -paddingX, y)
            y = y - sf:GetHeight() - UI.sectionGap
        end
    end

    scrollChild:SetHeight(math.max(1, -y + UI.sectionGap))

    if self.UpdateTracking then
        self:UpdateTracking()
    end
end

function Addon:CreateFrame()
    if frame then return end

    frame = CreateFrame("Frame", "LariasWeeklyMidnightChecklistFrame", UIParent)
    if not frame.SetBackdrop and BackdropTemplateMixin and Mixin then
        Mixin(frame, BackdropTemplateMixin)
    end

    frame:SetSize(UI.frameW, UI.frameH)
    frame:SetClampedToScreen(true)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    self:ApplyTheme(frame)

    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -UI.closeInset, -UI.closeInset)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    local topRow = CreateFrame("Frame", nil, frame)
    topRow:SetPoint("TOPLEFT", frame, "TOPLEFT", UI.padOuterX, -UI.padOuterTop)
    topRow:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -UI.topRowRightInset, -UI.padOuterTop)
    topRow:SetHeight(UI.topRowH)

    local hideDoneCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    hideDoneCheck:SetPoint("LEFT", topRow, "LEFT", UI.padOuterX, 0)
    local htxt = hideDoneCheck.text or hideDoneCheck.Text
    if htxt then
        htxt:SetText("Hide completed weeks")
        if htxt.SetTextColor then
            htxt:SetTextColor(THEME.text.r, THEME.text.g, THEME.text.b, THEME.text.a)
        end
    end

    local db = self:EnsureDB()
    hideDoneCheck:SetChecked(db.hideCompletedSections)
    hideDoneCheck:SetScript("OnClick", function(selfBtn)
        local d = Addon:EnsureDB()
        d.hideCompletedSections = selfBtn:GetChecked() and true or false
        Addon:Refresh()
    end)

    local showCurrencyCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    showCurrencyCheck:SetPoint("LEFT", hideDoneCheck, "RIGHT", 170, 0)
    local ctxt = showCurrencyCheck.text or showCurrencyCheck.Text
    if ctxt then
        ctxt:SetText("Show weeklies")
        if ctxt.SetTextColor then
            ctxt:SetTextColor(THEME.text.r, THEME.text.g, THEME.text.b, THEME.text.a)
        end
    end

    showCurrencyCheck:SetChecked(db.showCurrency)
    showCurrencyCheck:SetScript("OnClick", function(selfBtn)
    local wantShow = selfBtn:GetChecked() and true or false

    -- If Currency.lua is loaded, this will also create the panel when turning ON.
    if Addon.SetTrackingVisible then
        Addon:SetTrackingVisible(wantShow)
        return
    end

    -- Fallback (Currency.lua not loaded)
    local d = Addon:EnsureDB()
    d.showCurrency = wantShow
    Addon:ApplyScrollLayout()
    Addon:Refresh()
end)

    Addon._showCurrencyCheck = showCurrencyCheck

    local resetBtn = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    resetBtn:SetPoint("RIGHT", topRow, "RIGHT", 0, 0)
    resetBtn:SetSize(90, UI.topRowH)
    resetBtn:SetText("Reset")
    resetBtn:SetScript("OnClick", function()
        local d = Addon:EnsureDB()
        if wipe then
            wipe(d.checked)
            wipe(d.collapsedSections)
        else
            d.checked = {}
            d.collapsedSections = {}
        end
        d.hideCompletedSections = false
        hideDoneCheck:SetChecked(false)

        -- do not force currency on/off; keep user pref
        Addon:ApplyScrollLayout()
        Addon:Refresh()
    end)

    scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", UI.padOuterX, -UI.scrollTop)

    scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(1, 1)
    scrollFrame:SetScrollChild(scrollChild)

    -- If currency tracking is enabled, create the tracking panel now (Currency.lua)
    -- so layout can reserve space immediately.
    if db.showCurrency and self.CreateTrackingPanel and not self._trackingFrame then
        self:CreateTrackingPanel(frame)
    end

    -- Currency.lua will update the tracking frame; we just apply layout
    self:ApplyScrollLayout()
    self:Refresh()
end

function Addon:Toggle()
    self:CreateFrame()
    if frame:IsShown() then
        frame:Hide()
    else
        self:ApplyScrollLayout()
        self:Refresh()
        frame:Show()
    end
end

SLASH_LARIASWEEKLYMIDNIGHTCHECKLIST1 = "/larias"
SLASH_LARIASWEEKLYMIDNIGHTCHECKLIST2 = "/lcl"
SlashCmdList["LARIASWEEKLYMIDNIGHTCHECKLIST"] = function()
    Addon:Toggle()
end
