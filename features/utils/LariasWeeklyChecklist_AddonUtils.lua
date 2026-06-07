-- AddonUtils: general-purpose utilities shared across body and other feature modules.
-- Must be loaded before any feature module that references Addon.AddonUtils.
--
-- Exposes Addon.AddonUtils:
--   COLORS              - palette table { red, yellow, green, white, dim, gold }
--   ColorWrap(hex, txt) - wraps text in a WoW color escape.
--   Wipe(t)             - empties table t in-place (nil-safe).
--   IsNonEmptyText(txt) - true when string contains visible characters.
--   FormatXY(cur, cap)  - formats progress as "cur/cap" or "cur".
--   ColorForXY(cur, cap)- returns red/yellow/green based on progress.
--
-- Also exposes Addon.RIGHT_LINE_COUNT (right-panel row cap used by Overlay + Currency).

local addonName = ...
local Addon = _G[addonName]
if not Addon then return end

local AddonUtils = {}
Addon.AddonUtils = AddonUtils

-- Shared WoW color-escape palette used by tracking rows and tooltips.
AddonUtils.COLORS = {
    red    = "ffff4040",
    yellow = "ffffd34d",
    green  = "ff40ff40",
    white  = "ffffffff",
    dim    = "ff808080",
    gold   = "ffcc9a28",  -- warm WoW gold for currency labels
}
local COLORS = AddonUtils.COLORS

-- Wraps text in a precomputed WoW ARGB color code (for example "ffff4040").
function AddonUtils.ColorWrap(hex, txt)
    return "|c" .. hex .. tostring(txt or "") .. "|r"
end

function AddonUtils.Wipe(t)
    if not t then return end
    if wipe then wipe(t); return end
    for k in pairs(t) do t[k] = nil end
end

function AddonUtils.IsNonEmptyText(text)
    if type(text) ~= "string" then return false end
    text = text:gsub("|[cr][%x]*", "")
    return text:match("%S") ~= nil
end

function AddonUtils.FormatXY(cur, cap)
    cur = tonumber(cur) or 0
    cap = tonumber(cap) or 0
    if cap > 0 then return ("%d/%d"):format(cur, cap) end
    return tostring(cur)
end

function AddonUtils.ColorForXY(cur, cap)
    cur = tonumber(cur) or 0
    cap = tonumber(cap) or 0
    if cur <= 0 then return COLORS.red end
    if cap > 0 and cur >= cap then return COLORS.green end
    return COLORS.yellow
end

function AddonUtils.SetTooltip(frame, text, anchor)
    GameTooltip:SetOwner(frame, anchor or "ANCHOR_RIGHT")
    GameTooltip:SetText(text, 1, 1, 1, 1, true)
    GameTooltip:Show()
end

function AddonUtils.HideTooltip()
    GameTooltip:Hide()
end

-- Safe frame visibility check.  Works on any object shape (frames, regions, etc).
function AddonUtils.IsFrameShown(f)
    return f and f.IsShown and f:IsShown()
end

-- Multi-line tooltip.  lines = array of strings or {text, r, g, b} tables.
-- First entry uses SetText; subsequent entries use AddLine.
function AddonUtils.SetTooltipLines(frame, lines, anchor)
    GameTooltip:SetOwner(frame, anchor or "ANCHOR_RIGHT")
    for i, line in ipairs(lines) do
        local text = type(line) == "table" and (line.text or line[1]) or tostring(line)
        local r    = type(line) == "table" and (line.r    or line[2] or 1) or 1
        local g    = type(line) == "table" and (line.g    or line[3] or 1) or 1
        local b    = type(line) == "table" and (line.b    or line[4] or 1) or 1
        if i == 1 then
            GameTooltip:SetText(text, r, g, b, 1, true)
        else
            GameTooltip:AddLine(text, r, g, b, true)
        end
    end
    GameTooltip:Show()
end

-- Maximum rows in the right column; owned here so Overlay and Currency stay in sync.
Addon.RIGHT_LINE_COUNT = 10
