-- AddonUtils: general-purpose utilities shared across body and other feature modules.
-- Must be loaded before any feature module that references Addon.AddonUtils.
--
-- Exposes Addon.AddonUtils:
--   COLORS              → palette table { red, yellow, green, white, dim }
--   ColorWrap(hex, txt) → "|c<hex><txt>|r"
--   Wipe(t)             → empties table t in-place (nil-safe)
--   IsNonEmptyText(txt) → true if string contains visible characters after stripping colour codes
--   FormatXY(cur, cap)  → "cur/cap" or "cur" when cap ≤ 0
--   ColorForXY(cur, cap)→ COLORS.red / yellow / green based on progress
--
-- Also exposes Addon.RIGHT_LINE_COUNT (right-panel row cap used by Overlay + Currency).

local addonName = ...
local Addon = _G[addonName]
if not Addon then return end

local AddonUtils = {}
Addon.AddonUtils = AddonUtils

-- ── Color palette ──────────────────────────────────────────────────────────────
AddonUtils.COLORS = {
    red    = "ffff4040",
    yellow = "ffffd34d",
    green  = "ff40ff40",
    white  = "ffffffff",
    dim    = "ff808080",
}
local COLORS = AddonUtils.COLORS

-- ── Helpers ────────────────────────────────────────────────────────────────────
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
    cur = tonumber(cur) or 0; cap = tonumber(cap) or 0
    if cap > 0 then return ("%d/%d"):format(cur, cap) end
    return tostring(cur)
end

function AddonUtils.ColorForXY(cur, cap)
    cur = tonumber(cur) or 0; cap = tonumber(cap) or 0
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

-- ── Shared layout constants ────────────────────────────────────────────────────
-- Maximum rows in the right column; owned here so Overlay and Currency stay in sync.
Addon.RIGHT_LINE_COUNT = 10
