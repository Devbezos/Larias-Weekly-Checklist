local addonName = ...
local Addon = _G[addonName] or {}
_G[addonName] = Addon

local L = Addon.L or {}

if Addon.InitConstants then
    Addon:InitConstants(addonName)
end

local frame
local scrollFrame
local scrollChild
local THEME = Addon.THEME
local UI = Addon.UI
local type, tostring = type, tostring
local pairs, ipairs, next = pairs, ipairs, next
local max = math.max
local tinsert, tremove, tconcat = table.insert, table.remove, table.concat
local CreateFrame = CreateFrame

local COMM_PREFIX = "LWMC"
local BROADCAST_THROTTLE_SECONDS = 30
local REPLY_THROTTLE_SECONDS = 5

local function GetAddonVersion(name)
    name = name or addonName
    local versionString
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        versionString = C_AddOns.GetAddOnMetadata(name, "Version")
    elseif GetAddOnMetadata then
        versionString = GetAddOnMetadata(name, "Version")
    end
    versionString = tostring(versionString or "")
    versionString = versionString:gsub("^%s+", ""):gsub("%s+$", "")
    return versionString
end

function Addon:GetMyVersion()
    if self._myVersion == nil then
        self._myVersion = GetAddonVersion(addonName)
    end
    return self._myVersion or ""
end

local function IsVersionNewer(a, b)
    if a == b then return false end
    if a == "" then return false end
    if b == "" then return true end

    local function SplitNums(s)
        local out = {}
        for n in tostring(s):gmatch("%d+") do
            out[#out + 1] = tonumber(n) or 0
        end
        return out
    end

    local aParts = SplitNums(a)
    local bParts = SplitNums(b)
    local maxParts = max(#aParts, #bParts)
    for index = 1, maxParts do
        local aValue = aParts[index] or 0
        local bValue = bParts[index] or 0
        if aValue ~= bValue then
            return aValue > bValue
        end
    end

    return a > b
end

function Addon:ShouldShowUpdateNotice()
    local database = self:EnsureDB()
    local myVersion = self:GetMyVersion()
    local newestSeenVersion = tostring(database._newestSeenRemoteVersion or "")
    if newestSeenVersion == "" or myVersion == "" then return false end
    if not IsVersionNewer(newestSeenVersion, myVersion) then return false end
    if tostring(database._dismissedRemoteVersion or "") == newestSeenVersion then return false end
    return true
end

function Addon:DismissUpdateNotice()
    local database = self:EnsureDB()
    database._dismissedRemoteVersion = tostring(database._newestSeenRemoteVersion or "")
end

function Addon:EnsureUpdatePopup()
    if self._updatePopupRegistered then return end
    self._updatePopupRegistered = true

    if not StaticPopupDialogs then return end

    StaticPopupDialogs["LARIASWEEKLYMIDNIGHTCHECKLIST_UPDATE"] = {
        text = "%s",
        button1 = (OKAY or "OK"),
        button2 = (CANCEL or "Later"),
        OnAccept = function()
            Addon:DismissUpdateNotice()
        end,
        OnCancel = function()
            -- Keep pending; we'll remind next time they open the list.
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end

function Addon:ShowUpdatePopupIfNeeded()
    if not self:ShouldShowUpdateNotice() then return end
    if self._updatePopupShownThisOpen then return end

    self:EnsureUpdatePopup()
    if not (StaticPopup_Show and StaticPopupDialogs) then return end

    local displayName = (self.DISPLAY_NAME or (L and L.DISPLAY_NAME) or addonName)
    local popupText
    if type(L.UPDATE_AVAILABLE_FMT) == "string" and L.UPDATE_AVAILABLE_FMT ~= "" then
        popupText = string.format(L.UPDATE_AVAILABLE_FMT, tostring(displayName))
    else
        popupText = (L.UPDATE_AVAILABLE_TEXT or L.UPDATE_AVAILABLE_TITLE or "New version available")
    end

    StaticPopup_Show("LARIASWEEKLYMIDNIGHTCHECKLIST_UPDATE", popupText)
    self._updatePopupShownThisOpen = true
end

local function SafeRegisterPrefix(prefix)
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        pcall(C_ChatInfo.RegisterAddonMessagePrefix, prefix)
    elseif RegisterAddonMessagePrefix then
        pcall(RegisterAddonMessagePrefix, prefix)
    end
end

local function SafeSendAddonMessage(prefix, msg, channel)
    if not channel or channel == "" then return end
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        pcall(C_ChatInfo.SendAddonMessage, prefix, msg, channel)
        return
    end
    if SendAddonMessage then
        pcall(SendAddonMessage, prefix, msg, channel)
    end
end

local function GetGroupChannel()
    local instCat = (LE_PARTY_CATEGORY_INSTANCE ~= nil) and LE_PARTY_CATEGORY_INSTANCE or 2
    if IsInGroup and IsInGroup(instCat) then return "INSTANCE_CHAT" end
    if IsInRaid and IsInRaid() then return "RAID" end
    if IsInGroup and IsInGroup() then return "PARTY" end
    return nil
end

function Addon:BroadcastVersion(force)
    local nowSeconds = (GetTime and GetTime()) or 0
    if not force then
        local lastBroadcastAt = tonumber(self._lastVersionBroadcastAt or 0) or 0
        if (nowSeconds - lastBroadcastAt) < BROADCAST_THROTTLE_SECONDS then
            return
        end
    end

    local myVersion = self:GetMyVersion()
    if myVersion == "" then return end
    local payload = "V:" .. myVersion

    local channel = GetGroupChannel()
    if channel then
        SafeSendAddonMessage(COMM_PREFIX, payload, channel)
    end
    if IsInGuild and IsInGuild() then
        SafeSendAddonMessage(COMM_PREFIX, payload, "GUILD")
    end

    self._lastVersionBroadcastAt = nowSeconds
end

function Addon:RequestVersions(force)
    local nowSeconds = (GetTime and GetTime()) or 0
    if not force then
        local lastQueryAt = tonumber(self._lastVersionQueryAt or 0) or 0
        if (nowSeconds - lastQueryAt) < BROADCAST_THROTTLE_SECONDS then
            return
        end
    end

    local channel = GetGroupChannel()
    if channel then
        SafeSendAddonMessage(COMM_PREFIX, "Q", channel)
    end
    if IsInGuild and IsInGuild() then
        SafeSendAddonMessage(COMM_PREFIX, "Q", "GUILD")
    end

    self._lastVersionQueryAt = nowSeconds
end

function Addon:OnAddonMessage(prefix, message, sender)
    if prefix ~= COMM_PREFIX then return end
    if type(message) ~= "string" then return end

    if message == "Q" then
        local nowSeconds = (GetTime and GetTime()) or 0
        local lastReplyAt = tonumber(self._lastVersionReplyAt or 0) or 0
        if (nowSeconds - lastReplyAt) < REPLY_THROTTLE_SECONDS then
            return
        end
        self._lastVersionReplyAt = nowSeconds
        self:BroadcastVersion(true)
        return
    end

    if message:sub(1, 2) ~= "V:" then return end

    local remoteVersion = message:sub(3) or ""
    remoteVersion = tostring(remoteVersion):gsub("^%s+", ""):gsub("%s+$", "")
    if remoteVersion == "" then return end

    local myVersion = self:GetMyVersion()
    if myVersion == "" then return end

    if sender and sender ~= "" and UnitName then
        local me = UnitName("player")
        if me and me ~= "" then
            local s = sender
            if Ambiguate then
                s = Ambiguate(sender, "none")
            end
            if s == me then
                return
            end
        end
    end

    if IsVersionNewer(remoteVersion, myVersion) then
        local database = self:EnsureDB()
        local newestSeenVersion = tostring(database._newestSeenRemoteVersion or "")
        if newestSeenVersion == "" or IsVersionNewer(remoteVersion, newestSeenVersion) then
            database._newestSeenRemoteVersion = remoteVersion
            database._newestSeenRemoteSender = tostring(sender or "")
        end
    end
end

Addon._commFrame = Addon._commFrame or CreateFrame("Frame")
Addon._commFrame:RegisterEvent("PLAYER_LOGIN")
Addon._commFrame:RegisterEvent("CHAT_MSG_ADDON")
Addon._commFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        SafeRegisterPrefix(COMM_PREFIX)
        Addon._myVersion = GetAddonVersion(addonName)
        -- Announce once on login so others can compare.
        Addon:BroadcastVersion(true)
        return
    end
    if event == "CHAT_MSG_ADDON" then
        local prefix, messageText, _, sender = ...
        Addon:OnAddonMessage(prefix, messageText, sender)
        return
    end
end)

local function Wipe(t)
    if not t then return end
    if wipe then
        wipe(t)
        return
    end
    for k in pairs(t) do
        t[k] = nil
    end
end

Addon._sectionPool = Addon._sectionPool or {}
Addon._checkboxPool = Addon._checkboxPool or {}
Addon._activeSections = Addon._activeSections or {}

Addon._dataSig = Addon._dataSig or ""
Addon._sectionsById = Addon._sectionsById or {}
Addon._order = Addon._order or {}
Addon._sectionsIndexById = Addon._sectionsIndexById or {}

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
    if db._migratedFromAccountDB ~= true then
        local legacyName = self._ACCOUNT_DB_NAME
        local legacy = legacyName and _G[legacyName] or nil
        if type(legacy) == "table" then
            local hasAnyChecks = (type(db.checked) == "table") and (next(db.checked) ~= nil)
            if not hasAnyChecks then
                if type(legacy.checked) == "table" then db.checked = CopyTableShallow(legacy.checked) end
                if type(legacy.collapsedSections) == "table" then db.collapsedSections = CopyTableShallow(legacy.collapsedSections) end
                if legacy.hideCompletedSections ~= nil then db.hideCompletedSections = legacy.hideCompletedSections and true or false end
                if legacy.showCurrency ~= nil then
                    local show = legacy.showCurrency and true or false
                    db.showGreatVault = show
                    db.showCurrency = show
                end
            end
        end
        db._migratedFromAccountDB = true
    end

    db.checked = db.checked or {}
    db.collapsedSections = db.collapsedSections or {}
    if db.hideCompletedSections == nil then db.hideCompletedSections = false end
    if db.showGreatVault == nil then db.showGreatVault = true end
    if db.showCurrency == nil then db.showCurrency = true end

    -- Addon update notice state (per-character). (ElvUI-style: compares with versions seen from other players.)
    if db._newestSeenRemoteVersion == nil then db._newestSeenRemoteVersion = "" end
    if db._dismissedRemoteVersion == nil then db._dismissedRemoteVersion = "" end
    return db
end

function Addon:EnsureOptionsPanel()
    if self._optionsPanel then return self._optionsPanel end

    local displayName = (Addon.DISPLAY_NAME or addonName)

    local panel = CreateFrame("Frame")
    panel.name = displayName

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(displayName)

    local function MakeCheck(y, labelText)
        local cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 16, y)
        local t = cb.text or cb.Text
        if t then
            t:SetText(labelText)
        end
        return cb
    end

    local gvCheck = MakeCheck(-50, L.OPTIONS_SHOW_GREAT_VAULT or "")
    local currencyCheck = MakeCheck(-78, L.OPTIONS_SHOW_CURRENCY or "")

    panel:SetScript("OnShow", function()
        local db = Addon:EnsureDB()
        gvCheck:SetChecked(db.showGreatVault and true or false)
        currencyCheck:SetChecked(db.showCurrency and true or false)
    end)

    gvCheck:SetScript("OnClick", function(selfBtn)
        local db = Addon:EnsureDB()
        db.showGreatVault = selfBtn:GetChecked() and true or false
        if Addon.UpdateTracking then Addon:UpdateTracking() end
        Addon:ApplyScrollLayout()
        Addon:Refresh()
    end)

    currencyCheck:SetScript("OnClick", function(selfBtn)
        local db = Addon:EnsureDB()
        db.showCurrency = selfBtn:GetChecked() and true or false
        if Addon.UpdateTracking then Addon:UpdateTracking() end
        Addon:ApplyScrollLayout()
        Addon:Refresh()
    end)

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        self._settingsCategory = category
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end

    self._optionsPanel = panel
    return panel
end

function Addon:OpenOptions()
    local panel = self:EnsureOptionsPanel()
    if Settings and Settings.OpenToCategory and self._settingsCategory and self._settingsCategory.GetID then
        Settings.OpenToCategory(self._settingsCategory:GetID())
        return
    end
    if InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(panel)
        InterfaceOptionsFrame_OpenToCategory(panel)
    end
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
function Addon:ApplyScrollLayout()
    if not (frame and scrollFrame) then return end
    local db = self:EnsureDB()

    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", UI.padOuterX, -UI.scrollTop)

    local extra = 0
    if (db.showGreatVault or db.showCurrency) and self._trackingFrame and self._trackingFrame.IsShown and self._trackingFrame:IsShown() then
        local h = (self._trackingFrame.GetHeight and self._trackingFrame:GetHeight()) or UI.trackH
        h = tonumber(h) or UI.trackH
        extra = h + UI.trackTopPad
    end

    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -UI.scrollRight, UI.scrollBottom + extra)
end

local function Key(sectionId, itemId)
    if type(sectionId) == "string" and type(itemId) == "string" then
        return sectionId .. ":" .. itemId
    end
    return tostring(sectionId) .. ":" .. tostring(itemId)
end

local function IsItemChecked(sectionId, itemId, db)
    db = db or Addon:EnsureDB()
    return db.checked[Key(sectionId, itemId)] and true or false
end

local function SetItemChecked(sectionId, itemId, checked, db)
    db = db or Addon:EnsureDB()
    db.checked[Key(sectionId, itemId)] = checked and true or nil
end

local function IsSectionCollapsed(sectionId, db)
    db = db or Addon:EnsureDB()
    return db.collapsedSections[sectionId] or false
end

local function SetSectionCollapsed(sectionId, collapsed, db)
    db = db or Addon:EnsureDB()
    db.collapsedSections[sectionId] = collapsed and true or nil
end

local function IsSectionCompleteById(sectionId, db)
    local section = Addon._sectionsById[sectionId]
    if not section then return false end

    db = db or Addon:EnsureDB()
    local checked = db.checked
    local items = section.items or {}
    for i = 1, #items do
        if not checked[Key(sectionId, items[i].id)] then
            return false
        end
    end
    return true
end

local function AcquireSectionFrame()
    local sf = tremove(Addon._sectionPool)
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
            tinsert(Addon._checkboxPool, cb)
            sf._checkboxes[i] = nil
        end
    end

    sf._header:SetScript("OnClick", nil)
    tinsert(Addon._sectionPool, sf)
end

local function AcquireCheckbox(sf)
    local cb = tremove(Addon._checkboxPool)
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
local UpdateSectionVisuals

local function ComputeHeaderHeight(sf, headerTextWidth)
    sf._title:SetWidth(headerTextWidth)
    local th = 0
    if sf._title.GetStringHeight then
        th = sf._title:GetStringHeight() or 0
    end
    local hh = max(UI.headerMinH, th + 6)
    sf._header:SetHeight(hh)
    sf._headerBlockHeight = hh + UI.headerBottomPad
end

local function LayoutItems(sf, collapsed)
    local y = -(sf._headerBlockHeight or (UI.headerMinH + UI.headerBottomPad))
    local total = 0
    local boxes = sf._checkboxes
    for i = 1, #boxes do
        local cb = boxes[i]
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

    local height = max(1, -y + UI.sectionGap)
    scrollChild:SetHeight(height)
end

local function CalcDataSig(data)
    if type(data) ~= "table" then return "" end
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
    local sig = tconcat(parts, "|")
    data.__lariasSig = sig
    data.__lariasSigN = #data
    return sig
end

local function SetHeaderText(sf, sectionId, complete)
    local section = Addon._sectionsById[sectionId]
    if complete == nil then
        complete = IsSectionCompleteById(sectionId)
    end
    local titleText = tostring((section and section.title) or sectionId)
    if complete then titleText = (L.DONE_PREFIX or "") .. titleText end
    sf._title:SetText(titleText)
    sf._status:SetText("")
end

local function OnCheckboxClick(selfBtn)
    local db = Addon:EnsureDB()
    local checked = selfBtn:GetChecked() and true or nil
    db.checked[selfBtn._dbKey or Key(selfBtn._sectionId, selfBtn._itemId)] = checked

    local sid = selfBtn._sectionId
    local secCompleteNow = IsSectionCompleteById(sid, db)
    if secCompleteNow then
        SetSectionCollapsed(sid, true, db)
    end

    local sframe = Addon._activeSections[Addon._sectionsIndexById[sid]]
    if not sframe then return end

    local hideDone = db.hideCompletedSections and true or false

    SetHeaderText(sframe, sid, secCompleteNow)
    ComputeHeaderHeight(sframe, UI.itemTextWidth + UI.headerTextExtraW)

    local collapsed = IsSectionCollapsed(sid, db) or false
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
    if UpdateSectionVisuals then
        UpdateSectionVisuals(sf, sid)
    end
    LayoutFrom(sf._index or 1)
end

local function SyncCheckboxesForSection(sf, sectionId, db)
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
            tinsert(Addon._checkboxPool, cb)
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
        local minRowH = max(32, UI.itemMinH or 0)
        if txt then
            txt:SetWidth(UI.itemTextWidth)
            txt:SetText(tostring(item.text or item.id))

            local textHeight = 0
            if txt.GetStringHeight then
                textHeight = txt:GetStringHeight() or 0
            end
            cb:SetHeight(max(minRowH, textHeight + (UI.itemTextPad or 0)))
        else
            cb:SetHeight(minRowH)
        end

        cb:SetChecked(IsItemChecked(sectionId, item.id, db))

        cb:SetScript("OnClick", OnCheckboxClick)
    end
end

UpdateSectionVisuals = function(sf, sectionId)
    local db = Addon:EnsureDB()
    local complete = IsSectionCompleteById(sectionId, db)

    local hideDone = db.hideCompletedSections and true or false
    if hideDone and complete then
        sf:Hide()
        return
    end

    sf:Show()

    if complete then
        SetSectionCollapsed(sectionId, true, db)
    end

    SetHeaderText(sf, sectionId, complete)
    ComputeHeaderHeight(sf, UI.itemTextWidth + UI.headerTextExtraW)

    local collapsed = IsSectionCollapsed(sectionId, db) or false
    if complete then collapsed = true end

    for i = 1, #sf._checkboxes do
        local cb = sf._checkboxes[i]
        if cb and cb._itemId ~= nil then
            cb:SetChecked(IsItemChecked(sectionId, cb._itemId, db))
        end
    end

    LayoutItems(sf, collapsed)
    UpdateSectionHeight(sf, collapsed)
end

local function SyncAllDataAndFrames()
    local db = Addon:EnsureDB()

    local data = Addon:GetListData()
    local sig = CalcDataSig(data)

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

    Wipe(Addon._sectionsIndexById)

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

        SyncCheckboxesForSection(sf, sectionId, db)

        sf._header._sectionFrame = sf
        sf._header:SetScript("OnClick", OnHeaderClick)

        UpdateSectionVisuals(sf, sectionId)

    end
end

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

    scrollChild:SetHeight(max(1, -y + UI.sectionGap))

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

    if UISpecialFrames and frame.GetName then
        local n = frame:GetName()
        if n and n ~= "" then
            local exists = false
            for i = 1, #UISpecialFrames do
                if UISpecialFrames[i] == n then
                    exists = true
                    break
                end
            end
            if not exists then
                tinsert(UISpecialFrames, n)
            end
        end
    end

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
        htxt:SetText(L.HIDE_COMPLETED_WEEKS or "")
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

    local optionsBtn = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    optionsBtn:SetPoint("RIGHT", topRow, "RIGHT", 0, 0)
    optionsBtn:SetSize(90, UI.topRowH)
    optionsBtn:SetText(L.OPTIONS_BUTTON or "")
    optionsBtn:SetScript("OnClick", function()
        Addon:OpenOptions()
    end)

    local resetBtn = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    resetBtn:SetPoint("RIGHT", optionsBtn, "LEFT", -8, 0)
    resetBtn:SetSize(90, UI.topRowH)
    resetBtn:SetText(L.RESET_BUTTON or "")
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

        Addon:ApplyScrollLayout()
        Addon:Refresh()
    end)

    scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", UI.padOuterX, -UI.scrollTop)

    scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(1, 1)
    scrollFrame:SetScrollChild(scrollChild)

    if (db.showGreatVault or db.showCurrency) and self.CreateTrackingPanel and not self._trackingFrame then
        self:CreateTrackingPanel(frame)
    end

    self:ApplyScrollLayout()
    self:Refresh()
end

function Addon:Toggle()
    self:CreateFrame()
    if frame:IsShown() then
        frame:Hide()
    else
        self._updatePopupShownThisOpen = nil
        self:BroadcastVersion(false)
        self:RequestVersions(false)
        self:ApplyScrollLayout()
        self:Refresh()
        self:ShowUpdatePopupIfNeeded()
        frame:Show()
    end
end

SLASH_LARIASWEEKLYMIDNIGHTCHECKLIST1 = "/larias"
SLASH_LARIASWEEKLYMIDNIGHTCHECKLIST2 = "/lcl"
SlashCmdList["LARIASWEEKLYMIDNIGHTCHECKLIST"] = function()
    Addon:Toggle()
end
