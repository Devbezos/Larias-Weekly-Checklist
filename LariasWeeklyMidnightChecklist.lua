-- Larias Weekly Midnight Checklist
local addonName = ...

local Addon = {}
_G[addonName] = Addon

local DB_NAME = "LariasWeeklyMidnightChecklistDB"

local LIST_DATA_KEY = addonName .. "_LIST_DATA"

local frame
local scrollFrame
local scrollChild

local THEME = {
    bg = { r = 0.10, g = 0.10, b = 0.10, a = 0.65 },
    border = { r = 0.30, g = 0.30, b = 0.30, a = 0.90 },
    header = { r = 1.00, g = 0.82, b = 0.00, a = 1.00 },
    text = { r = 1.00, g = 1.00, b = 1.00, a = 1.00 },
    textDim = { r = 1.00, g = 1.00, b = 1.00, a = 0.85 },
}

-- Checklist data (weeks as sections)


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
    if db.didMigrateFromRefinedVibes == nil then db.didMigrateFromRefinedVibes = false end
end

local function TryMigrateFromRefinedVibes()
    EnsureDB()
    local db = DB()
    if db.didMigrateFromRefinedVibes then return end

    local old = _G.RefinedVibesDB
    if type(old) ~= "table" or type(old.piglist) ~= "table" then
        db.didMigrateFromRefinedVibes = true
        return
    end

    local oldChecked = old.piglist.checked
    local oldCollapsed = old.piglist.collapsedSections

    if type(oldChecked) == "table" and next(db.checked) == nil then
        for k, v in pairs(oldChecked) do
            if v then db.checked[k] = true end
        end
    end

    if type(oldCollapsed) == "table" and next(db.collapsedSections) == nil then
        for k, v in pairs(oldCollapsed) do
            if v then db.collapsedSections[k] = true end
        end
    end

    if type(old.piglist.hideCompletedSections) == "boolean" then
        db.hideCompletedSections = old.piglist.hideCompletedSections
    end

    db.didMigrateFromRefinedVibes = true
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
    local db = DB()
    return db.checked[Key(sectionId, itemId)] and true or false
end

local function SetItemChecked(sectionId, itemId, checked)
    EnsureDB()
    local db = DB()
    db.checked[Key(sectionId, itemId)] = checked and true or nil
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
    local db = DB()
    return db.collapsedSections[sectionId] or false
end

local function SetSectionCollapsed(sectionId, collapsed)
    EnsureDB()
    local db = DB()
    db.collapsedSections[sectionId] = collapsed and true or nil
end

local function ClearChildren(parent)
    if not parent or not parent.GetChildren then return end
    local children = { parent:GetChildren() }
    for _, child in ipairs(children) do
        child:Hide()
        child:SetParent(nil)
    end
end

local function LayoutSections(sectionFrames)
    local y = -10
    local paddingX = 14

    for _, sf in ipairs(sectionFrames) do
        if sf:IsShown() then
            sf:ClearAllPoints()
            sf:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", paddingX, y)
            sf:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -paddingX, y)
            y = y - sf:GetHeight() - 10
        end
    end

    local height = math.max(1, -y + 10)
    scrollChild:SetHeight(height)
end

function Addon:Refresh()
    if not frame then return end
    TryMigrateFromRefinedVibes()
    EnsureDB()

    local db = DB()

    -- Fixed wrap widths for the fixed-size window.
    local itemTextWidth = 420
    local headerTextWidth = itemTextWidth + 28
    local headerMinHeight = 22
    local headerBottomPad = 4

    ClearChildren(scrollChild)

    local sectionFrames = {}

    for _, section in ipairs(GetListData()) do
        local complete = IsSectionComplete(section)
        if complete and db.hideCompletedSections then
            -- hide completed sections entirely
        else
            local sf = CreateFrame("Frame", nil, scrollChild)
            sf:SetWidth(1)

            local header = CreateFrame("Button", nil, sf)
            header:SetPoint("TOPLEFT", sf, "TOPLEFT", 0, 0)
            header:SetPoint("TOPRIGHT", sf, "TOPRIGHT", 0, 0)
            header:SetHeight(headerMinHeight)

            local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            title:SetPoint("LEFT", header, "LEFT", 0, 0)
            title:SetTextColor(THEME.header.r, THEME.header.g, THEME.header.b, THEME.header.a)

            title:SetJustifyH("LEFT")
            if title.SetWordWrap then title:SetWordWrap(true) end
            title:SetWidth(headerTextWidth)

            local status = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            status:SetPoint("RIGHT", header, "RIGHT", 0, 0)
            status:SetTextColor(THEME.textDim.r, THEME.textDim.g, THEME.textDim.b, THEME.textDim.a)

            local function UpdateHeaderLayout()
                title:SetWidth(headerTextWidth)
                local th = 0
                if title.GetStringHeight then
                    th = title:GetStringHeight() or 0
                end
                local hh = math.max(headerMinHeight, th + 6)
                header:SetHeight(hh)
                sf._headerBlockHeight = hh + headerBottomPad
            end

            local function UpdateHeaderText()
                local isComplete = IsSectionComplete(section)
                if isComplete then
                    title:SetText("[Done] " .. tostring(section.title or section.id))
                    status:SetText("")
                else
                    title:SetText(tostring(section.title or section.id))
                    status:SetText("")
                end

                UpdateHeaderLayout()
            end

            local collapsed = IsSectionCollapsed(section.id)
            if complete then
                collapsed = true
                SetSectionCollapsed(section.id, true)
            end

            UpdateHeaderText()

            local function RelayoutItems()
                local y = -(sf._headerBlockHeight or (headerMinHeight + headerBottomPad))
                local total = 0
                for _, cb in ipairs(sf._checkboxes or {}) do
                    cb:ClearAllPoints()
                    cb:SetPoint("TOPLEFT", sf, "TOPLEFT", 0, y)
                    local rh = cb.GetHeight and cb:GetHeight() or 24
                    y = y - rh
                    total = total + rh
                end
                sf._itemsHeight = total
            end

            local itemY = -(sf._headerBlockHeight or (headerMinHeight + headerBottomPad))
            local anyItems = false

            local function RecomputeCompletion()
                local isCompleteNow = IsSectionComplete(section)
                if isCompleteNow then
                    SetSectionCollapsed(section.id, true)
                    collapsed = true
                end
                UpdateHeaderText()

                RelayoutItems()

                if isCompleteNow and db.hideCompletedSections then
                    sf:Hide()
                    LayoutSections(sectionFrames)
                    return
                end

                for _, cb in ipairs(sf._checkboxes or {}) do
                    cb:SetShown(not collapsed)
                end

                local h = (sf._headerBlockHeight or (headerMinHeight + headerBottomPad))
                if not collapsed then
                    h = h + (sf._itemsHeight or 0)
                end
                sf:SetHeight(h)
            end

            header:SetScript("OnClick", function()
                collapsed = not collapsed
                SetSectionCollapsed(section.id, collapsed)
                RecomputeCompletion()
                LayoutSections(sectionFrames)
            end)

            sf._checkboxes = {}
            sf._itemsHeight = 0

            for _, item in ipairs(section.items or {}) do
                anyItems = true
                local cb = CreateFrame("CheckButton", nil, sf, "UICheckButtonTemplate")
                cb:SetPoint("TOPLEFT", sf, "TOPLEFT", 0, itemY)
                local itemText = tostring(item.text or item.id)
                cb.text:SetText(itemText)
                if cb.text then
                    if cb.text.SetTextColor then
                        cb.text:SetTextColor(THEME.text.r, THEME.text.g, THEME.text.b, THEME.text.a)
                    end

                    -- Allow long lines to wrap and resize the row accordingly.
                    cb.text:SetJustifyH("LEFT")
                    if cb.text.SetWordWrap then cb.text:SetWordWrap(true) end

                    -- Wrap to the current window width.
                    cb.text:SetWidth(itemTextWidth)
                end

                local textHeight = 0
                if cb.text and cb.text.GetStringHeight then
                    textHeight = cb.text:GetStringHeight() or 0
                end
                local rowHeight = math.max(24, textHeight + 8)
                cb:SetHeight(rowHeight)

                local savedKey = Key(section.id, item.id)
                local saved = db.checked[savedKey]
                -- By default, items are unchecked unless saved in the DB.

                cb:SetChecked(IsItemChecked(section.id, item.id))
                cb:SetScript("OnClick", function(selfBtn)
                    SetItemChecked(section.id, item.id, selfBtn:GetChecked())
                    RecomputeCompletion()
                    LayoutSections(sectionFrames)
                end)

                table.insert(sf._checkboxes, cb)
                itemY = itemY - rowHeight
            end

            if anyItems then
                sf._itemsHeight = (-itemY) - (sf._headerBlockHeight or (headerMinHeight + headerBottomPad))
            end

            for _, cb in ipairs(sf._checkboxes) do
                cb:SetShown(not collapsed)
            end

            local initialH = (sf._headerBlockHeight or (headerMinHeight + headerBottomPad))
            if not collapsed then
                initialH = initialH + (sf._itemsHeight or 0)
            end
            sf:SetHeight(initialH)

            table.insert(sectionFrames, sf)
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

    frame:SetSize(520, 650)
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
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    local topRow = CreateFrame("Frame", nil, frame)
    topRow:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -10)
    topRow:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -34, -10)
    topRow:SetHeight(26)

    local hideDoneCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    hideDoneCheck:SetPoint("LEFT", topRow, "LEFT", 14, 0)
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
    resetBtn:SetSize(90, 26)
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
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -44)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 16)

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

