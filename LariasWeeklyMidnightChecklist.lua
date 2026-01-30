local addonName = ...

local Addon = {}
_G[addonName] = Addon

local DB_NAME = "LariasWeeklyMidnightChecklistDB"
local LIST_DATA_KEY = addonName .. "_LIST_DATA"

local frame
local scrollFrame
local scrollChild

local THEME = {
    bg      = { r = 0.10, g = 0.10, b = 0.10, a = 0.65 },
    border  = { r = 0.30, g = 0.30, b = 0.30, a = 0.90 },
    header  = { r = 1.00, g = 0.82, b = 0.00, a = 1.00 },
    text    = { r = 1.00, g = 1.00, b = 1.00, a = 1.00 },
    textDim = { r = 1.00, g = 1.00, b = 1.00, a = 0.85 },
}

local UI = {
    frameW = 520,
    frameH = 650,
    padOuterX = 14,
    padOuterTop = 10,
    closeInset = 4,
    topRowH = 26,
    topRowRightInset = 34,
    scrollTop = 44,
    scrollBottom = 16,
    scrollRight = 30,
    sectionGap = 10,
    sectionTopPad = 10,
    headerMinH = 22,
    headerBottomPad = 4,
    headerTextExtraW = 28,
    itemMinH = 24,
    itemTextPad = 8,
    itemTextWidth = 420,
    sectionInsetX = 14,
}

Addon._sectionPool = Addon._sectionPool or {}
Addon._checkboxPool = Addon._checkboxPool or {}
Addon._activeSections = Addon._activeSections or {}

local function DB()
    return _G[DB_NAME]
end

local function EnsureDB()
    if not DB() then
        _G[DB_NAME] = {}
    end
    local db = DB()
    db.checked = db.checked or {}
    db.collapsedSections = db.collapsedSections or {}
    if db.hideCompletedSections == nil then db.hideCompletedSections = false end
end

local function GetListData()
    local data = _G[LIST_DATA_KEY]
    if type(data) == "table" then
        return data
    end
    return {}
end

local function ApplyTheme(f)
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

local function Key(sectionId, itemId)
    return tostring(sectionId) .. ":" .. tostring(itemId)
end

local function IsItemChecked(sectionId, itemId)
    EnsureDB()
    return DB().checked[Key(sectionId, itemId)] and true or false
end

local function SetItemChecked(sectionId, itemId, checked)
    EnsureDB()
    DB().checked[Key(sectionId, itemId)] = checked and true or nil
end

local function IsSectionComplete(section)
    for _, item in ipairs(section.items or {}) do
        if not IsItemChecked(section.id, item.id) then
            return false
        end
    end
    return true
end

local function IsSectionCollapsed(sectionId)
    EnsureDB()
    return DB().collapsedSections[sectionId] or false
end

local function SetSectionCollapsed(sectionId, collapsed)
    EnsureDB()
    DB().collapsedSections[sectionId] = collapsed and true or nil
end

local function AcquireSectionFrame()
    local sf = table.remove(Addon._sectionPool)
    if sf then
        sf:Show()
        sf._inUse = true
        return sf
    end

    sf = CreateFrame("Frame", nil, scrollChild)
    sf:SetWidth(1)
    sf._checkboxes = {}
    sf._inUse = true

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
    sf._inUse = false
    sf:Hide()
    sf:ClearAllPoints()

    if sf._checkboxes then
        for i = 1, #sf._checkboxes do
            local cb = sf._checkboxes[i]
            cb:Hide()
            cb:ClearAllPoints()
            cb._inUse = false
            table.insert(Addon._checkboxPool, cb)
            sf._checkboxes[i] = nil
        end
    end

    table.insert(Addon._sectionPool, sf)
end

local function AcquireCheckbox(sf)
    local cb = table.remove(Addon._checkboxPool)
    if cb then
        cb:SetParent(sf)
        cb:Show()
        cb._inUse = true
        return cb
    end

    cb = CreateFrame("CheckButton", nil, sf, "UICheckButtonTemplate")
    cb._inUse = true

    if cb.text then
        cb.text:SetJustifyH("LEFT")
        if cb.text.SetWordWrap then cb.text:SetWordWrap(true) end
        cb.text:SetTextColor(THEME.text.r, THEME.text.g, THEME.text.b, THEME.text.a)
    end

    return cb
end

local function LayoutSections(sectionFrames)
    local y = -UI.sectionTopPad
    local paddingX = UI.sectionInsetX

    for _, sf in ipairs(sectionFrames) do
        if sf:IsShown() then
            sf:ClearAllPoints()
            sf:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", paddingX, y)
            sf:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -paddingX, y)
            y = y - sf:GetHeight() - UI.sectionGap
        end
    end

    local height = math.max(1, -y + UI.sectionGap)
    scrollChild:SetHeight(height)
end

local function ComputeHeaderHeight(sf, headerTextWidth)
    local title = sf._title
    title:SetWidth(headerTextWidth)

    local th = 0
    if title and title.GetStringHeight then
        th = title:GetStringHeight() or 0
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

function Addon:Refresh()
    if not frame then return end
    EnsureDB()

    local db = DB()

    if self._activeSections then
        for _, old in ipairs(self._activeSections) do
            ReleaseSectionFrame(old)
        end
    end
    self._activeSections = {}

    local itemTextWidth = UI.itemTextWidth
    local headerTextWidth = itemTextWidth + UI.headerTextExtraW

    local sectionFrames = {}

    for _, section in ipairs(GetListData()) do
        local complete = IsSectionComplete(section)
        if not (complete and db.hideCompletedSections) then
            local sf = AcquireSectionFrame()
            sf:SetParent(scrollChild)
            sf:Show()

            local collapsed = IsSectionCollapsed(section.id)
            if complete then
                collapsed = true
                SetSectionCollapsed(section.id, true)
            end

            local titleText = tostring(section.title or section.id)
            if complete then
                titleText = "[Done] " .. titleText
            end
            sf._title:SetText(titleText)
            sf._status:SetText("")

            ComputeHeaderHeight(sf, headerTextWidth)

            if sf._checkboxes and #sf._checkboxes > 0 then
                for i = 1, #sf._checkboxes do
                    local oldcb = sf._checkboxes[i]
                    oldcb:Hide()
                    oldcb:ClearAllPoints()
                    oldcb._inUse = false
                    table.insert(self._checkboxPool, oldcb)
                    sf._checkboxes[i] = nil
                end
            end

            for _, item in ipairs(section.items or {}) do
                local cb = AcquireCheckbox(sf)

                local itemText = tostring(item.text or item.id)
                if cb.text then
                    cb.text:SetWidth(itemTextWidth)
                    cb.text:SetText(itemText)

                    local textHeight = 0
                    if cb.text.GetStringHeight then
                        textHeight = cb.text:GetStringHeight() or 0
                    end
                    local rowHeight = math.max(UI.itemMinH, textHeight + UI.itemTextPad)
                    cb:SetHeight(rowHeight)
                else
                    cb:SetHeight(UI.itemMinH)
                end

                cb:SetChecked(IsItemChecked(section.id, item.id))
                cb._sectionId = section.id
                cb._itemId = item.id

                cb:SetScript("OnClick", function(selfBtn)
                    SetItemChecked(selfBtn._sectionId, selfBtn._itemId, selfBtn:GetChecked())
                    if IsSectionComplete(section) then
                        SetSectionCollapsed(section.id, true)
                    end
                    Addon:Refresh()
                end)

                table.insert(sf._checkboxes, cb)
            end

            sf._header:SetScript("OnClick", function()
                SetSectionCollapsed(section.id, not IsSectionCollapsed(section.id))
                Addon:Refresh()
            end)

            LayoutItems(sf, collapsed)
            UpdateSectionHeight(sf, collapsed)

            table.insert(sectionFrames, sf)
            table.insert(self._activeSections, sf)
        end
    end

    LayoutSections(sectionFrames)
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

    ApplyTheme(frame)

    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -UI.closeInset, -UI.closeInset)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    local topRow = CreateFrame("Frame", nil, frame)
    topRow:SetPoint("TOPLEFT", frame, "TOPLEFT", UI.padOuterX, -UI.padOuterTop)
    topRow:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -UI.topRowRightInset, -UI.padOuterTop)
    topRow:SetHeight(UI.topRowH)

    local hideDoneCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    hideDoneCheck:SetPoint("LEFT", topRow, "LEFT", UI.padOuterX, 0)
    hideDoneCheck.text:SetText("Hide completed weeks")
    if hideDoneCheck.text and hideDoneCheck.text.SetTextColor then
        hideDoneCheck.text:SetTextColor(THEME.text.r, THEME.text.g, THEME.text.b, THEME.text.a)
    end

    EnsureDB()
    hideDoneCheck:SetChecked(DB().hideCompletedSections)
    hideDoneCheck:SetScript("OnClick", function(selfBtn)
        EnsureDB()
        DB().hideCompletedSections = selfBtn:GetChecked() and true or false
        Addon:Refresh()
    end)

    local resetBtn = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    resetBtn:SetPoint("RIGHT", topRow, "RIGHT", 0, 0)
    resetBtn:SetSize(90, UI.topRowH)
    resetBtn:SetText("Reset")
    resetBtn:SetScript("OnClick", function()
        EnsureDB()
        wipe(DB().checked)
        wipe(DB().collapsedSections)
        DB().hideCompletedSections = false
        hideDoneCheck:SetChecked(false)
        Addon:Refresh()
    end)

    scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", UI.padOuterX, -UI.scrollTop)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -UI.scrollRight, UI.scrollBottom)

    scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(1, 1)
    scrollFrame:SetScrollChild(scrollChild)

    self:Refresh()
end

function Addon:Toggle()
    self:CreateFrame()
    if frame:IsShown() then
        frame:Hide()
    else
        self:Refresh()
        frame:Show()
    end
end

SLASH_LARIASWEEKLYMIDNIGHTCHECKLIST1 = "/larias"
SLASH_LARIASWEEKLYMIDNIGHTCHECKLIST2 = "/lcl"
SlashCmdList["LARIASWEEKLYMIDNIGHTCHECKLIST"] = function()
    Addon:Toggle()
end
