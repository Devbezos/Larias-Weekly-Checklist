local Harness = { counter = 0 }

local Frame = {}
Frame.__index = function(_, key)
    local method = Frame[key]
    if method then return method end
    return function(frame, ...)
        frame.calls[key] = { ... }
        return frame
    end
end

function Frame:SetScript(name, callback) self.scripts[name] = callback end
function Frame:GetScript(name) return self.scripts[name] end
function Frame:HookScript(name, callback)
    local previous = self.scripts[name]
    self.scripts[name] = function(...)
        if previous then previous(...) end
        callback(...)
    end
end
function Frame:RegisterEvent(name) self.events[name] = true end
function Frame:UnregisterEvent(name) self.events[name] = nil end
function Frame:UnregisterAllEvents() self.events = {} end
function Frame:IsEventRegistered(name) return self.events[name] == true end
function Frame:Show() self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
function Frame:Hide() self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
function Frame:IsShown() return self.shown == true end
function Frame:SetShown(value) if value then self:Show() else self:Hide() end end
function Frame:SetPoint(...) self.points = { ... } end
function Frame:GetPoint() return unpack(self.points or {}) end
function Frame:ClearAllPoints() self.points = {} end
function Frame:SetSize(width, height) self.width, self.height = width, height end
function Frame:SetWidth(width) self.width = width end
function Frame:SetHeight(height) self.height = height end
function Frame:GetWidth() return self.width or 100 end
function Frame:GetHeight() return self.height or 100 end
function Frame:GetLeft() return self.left or 0 end
function Frame:GetRight() return self.right or ((self.left or 0) + self:GetWidth()) end
function Frame:GetTop() return self.top or self:GetHeight() end
function Frame:GetBottom() return self.bottom or 0 end
function Frame:SetScale(scale) self.scale = scale end
function Frame:GetScale() return rawget(self, "scale") or 1 end
function Frame:GetEffectiveScale() return rawget(self, "scale") or 1 end
function Frame:SetAlpha(alpha) self.alpha = alpha end
function Frame:GetAlpha() return rawget(self, "alpha") or 1 end
function Frame:SetText(text) self.text = text end
function Frame:GetText() return self.text or "" end
function Frame:GetStringWidth() return #(self.text or "") * 6 end
function Frame:SetChecked(value) self.checked = value and true or false end
function Frame:GetChecked() return self.checked end
function Frame:SetEnabled(value) self.enabled = value and true or false end
function Frame:IsEnabled() return self.enabled ~= false end
function Frame:GetFrameLevel() return self.frameLevel or 1 end
function Frame:SetFrameLevel(level) self.frameLevel = level end
function Frame:GetFrameStrata() return self.frameStrata or "MEDIUM" end
function Frame:SetFrameStrata(value) self.frameStrata = value end
function Frame:GetParent() return self.parent end
function Frame:CreateTexture() return Harness.newFrame(self) end
function Frame:CreateFontString() return Harness.newFrame(self) end
function Frame:GetFontString()
    self.fontString = self.fontString or Harness.newFrame(self)
    return self.fontString
end
function Frame:SetScrollChild(child) self.scrollChild = child end
function Frame:GetVerticalScroll() return self.verticalScroll or 0 end
function Frame:SetVerticalScroll(value) self.verticalScroll = value end
function Frame:GetVerticalScrollRange() return self.verticalScrollRange or 0 end
function Frame:Click(button)
    if self.scripts.OnClick then self.scripts.OnClick(self, button or "LeftButton") end
end
function Frame:Fire(event, ...)
    if self.scripts.OnEvent then self.scripts.OnEvent(self, event, ...) end
end

function Harness.newFrame(parent)
    return setmetatable({
        parent = parent,
        shown = false,
        enabled = true,
        scripts = {},
        events = {},
        calls = {},
        points = {},
    }, Frame)
end

local function split(delimiter, value)
    local result = {}
    local start = 1
    while true do
        local position = string.find(value, delimiter, start, true)
        if not position then
            result[#result + 1] = string.sub(value, start)
            break
        end
        result[#result + 1] = string.sub(value, start, position - 1)
        start = position + #delimiter
    end
    return unpack(result)
end

function Harness.installGlobals()
    Harness.frames = {}
    Harness.timers = {}
    Harness.sentMessages = {}
    Harness.currencyInfo = {}
    Harness.itemInfo = {}
    Harness.popupCalls = {}

    _G.wipe = function(tbl) for key in pairs(tbl) do tbl[key] = nil end return tbl end
    _G.strsplit = split
    _G.strmatch = string.match
    _G.min, _G.max, _G.abs = math.min, math.max, math.abs
    _G.tinsert = table.insert
    _G.tremove = table.remove
    _G.CreateFrame = function(_, _, parent)
        local frame = Harness.newFrame(parent)
        Harness.frames[#Harness.frames + 1] = frame
        return frame
    end
    _G.UIParent = Harness.newFrame(nil)
    _G.UIParent.shown = true
    _G.UIParent:SetSize(1920, 1080)
    _G.GetScreenWidth = function() return 1920 end
    _G.GetScreenHeight = function() return 1080 end
    _G.IsAltKeyDown = function() return false end
    _G.ChatFrame1 = { AddMessage = function() end }
    _G.LibStub = nil
    _G.GameTooltip = Harness.newFrame(_G.UIParent)
    _G.StaticPopupDialogs = {}
    _G.StaticPopup_Show = function(name, text)
        Harness.popupCalls[#Harness.popupCalls + 1] = { name = name, text = text }
        return Harness.newFrame(_G.UIParent)
    end
    _G.StaticPopup_Hide = function() end
    _G.CANCEL = "Cancel"
    _G.YES = "Yes"
    _G.NO = "No"
    _G.ACCEPT = "Accept"
    _G.CLOSE = "Close"
    _G.OKAY = "Okay"
    _G.C_Timer = {
        After = function(delay, callback)
            Harness.timers[#Harness.timers + 1] = { delay = delay, callback = callback }
        end,
    }
    _G.C_CurrencyInfo = {
        GetCurrencyInfo = function(id) return Harness.currencyInfo[tonumber(id)] end,
    }
    _G.GetItemInfo = function(id)
        local info = Harness.itemInfo[tonumber(id)]
        if not info then return nil end
        return info.name, info.link, info.quality, nil, nil, nil, nil, nil, nil, info.icon
    end
    _G.GetItemCount = function(id) return (Harness.itemInfo[tonumber(id)] or {}).count or 0 end
    _G.GetCursorPosition = function() return 50, 75 end
    _G.IsMouseButtonDown = function() return true end
    _G.GetRealmName = function() return "Realm" end
    _G.UnitName = function(unit) if unit == "player" then return "Tester" end return nil end
    _G.UnitClass = function() return "Warrior", "WARRIOR" end
    _G.UnitLevel = function() return 80 end
    _G.GetMaxPlayerLevel = function() return 80 end
    _G.MAX_PLAYER_LEVEL = 80
    _G.RAID_CLASS_COLORS = { WARRIOR = { r = 0.8, g = 0.6, b = 0.4 } }
    _G.Ambiguate = function(value) return value:match("^[^-]+") or value end
    _G.time = function() return 123456 end
    _G.date = function() return "2026-01-01" end
    _G.C_ChatInfo = {
        SendAddonMessage = function(prefix, message, channel)
            Harness.sentMessages[#Harness.sentMessages + 1] = {
                prefix = prefix, message = message, channel = channel,
            }
        end,
        RegisterAddonMessagePrefix = function() return true end,
    }
    _G.IsInGroup = function() return false end
    _G.IsInRaid = function() return false end
    _G.IsInGuild = function() return false end
    _G.LE_PARTY_CATEGORY_INSTANCE = 2
    _G.Enum = {
        WeeklyRewardChestThresholdType = { MythicPlus = 1, Raid = 3 },
        WeeklyRewardChestActivityType = { MythicPlus = 1, Raid = 3, World = 2 },
    }
    _G.GetLocale = function() return "enUS" end
    _G.IsInInstance = function() return false, "none" end
    _G.GetInstanceInfo = function() return "", "none", 0, "", 0, 0, false, 0 end
    _G.C_AddOns = { GetAddOnMetadata = function() return "1.0.0" end }
    _G.UISpecialFrames = {}
    _G.SOUNDKIT = {}
    _G.PlaySound = function() end
end

function Harness.loadLibWindow()
    dofile("lib/LibStub/LibStub.lua")
    dofile("lib/LibWindow-1.1/LibWindow-1.1/LibWindow-1.1.lua")
    return _G.LibStub("LibWindow-1.1")
end

function Harness.runTimers(limit)
    local count = 0
    while #Harness.timers > 0 do
        count = count + 1
        if limit and count > limit then error("timer limit exceeded") end
        local timer = table.remove(Harness.timers, 1)
        timer.callback()
    end
end

function Harness.load(addon, path)
    local chunk, loadError = loadfile(path)
    if not chunk then error(loadError) end
    chunk(addon.__name)
    return addon
end

function Harness.newAddon(overrides)
    Harness.installGlobals()
    Harness.counter = Harness.counter + 1
    local name = "LWMC_TEST_ADDON_" .. Harness.counter
    local addon = {
        __name = name,
        L = {},
        UI = { frameW = 920, frameH = 560 },
        THEME = {
            bg = { r = 0.1, g = 0.1, b = 0.1, a = 1 },
            text = { r = 1, g = 1, b = 1, a = 1 },
            header = { r = 1, g = 0.82, b = 0, a = 1 },
        },
        TRACKING = {
            crestCurrencyIDs = { 101, 102, 103, 104, 105 },
            crestColors = { "00ff00", "0088ff", "aa00ff", "ff8800", "ffd700" },
            ilvlBase = 100,
            ilvlTrackStep = 10,
            ilvlRankOffsets = { 0, 2, 4, 6, 8, 10 },
            gearSlotIDs = { 1, 2, 3 },
            crestTradeBatch = { 30, 10 },
        },
        SNAP_TYPES = {
            CURRENCY = "currency", CATALYST = "catalyst", SPARKS = "sparks",
            COFFERKEYS = "cofferkeys", WEAPUPG = "weapupg", QUEST = "quest",
            CREST = "crest",
        },
    }
    for key, value in pairs(overrides or {}) do addon[key] = value end
    _G[name] = addon
    Harness.load(addon, "features/services/general/LariasWeeklyChecklist_CoreLogic.lua")
    return addon
end

return Harness
