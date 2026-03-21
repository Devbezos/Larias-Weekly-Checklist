-- IlvlUtils: shared helpers for item-level tier lookup and crest-palette colouring.
-- Must be loaded before any feature module that uses tier colours.
--
-- Exposes Addon.IlvlUtils:
--   GetTier(ilvl)          → crest tier index 1-5, or nil
--   GetRank(ilvl, tier)    → upgrade rank 1-6 within the tier, or nil
--   GetColorHex(ilvl)      → "ffRRGGBB" string ready for |c colour codes
--   GetEscapePrefix(tier)  → "|cFFRRGGBB" WoW colour-escape prefix
--   GetTrackLabel(ilvl)    → e.g. "Champion 1", or nil

local addonName = ...
local Addon = _G[addonName]
if not Addon then return end

local IlvlUtils = {}
Addon.IlvlUtils = IlvlUtils

-- Returns the crest tier index (1-5) matching the given ilvl.
function IlvlUtils.GetTier(ilvl)
    local bases = Addon.TRACKING and Addon.TRACKING.ilvlBases
    if not bases or (ilvl or 0) <= 0 then return nil end
    for i = #bases, 1, -1 do
        if ilvl >= (bases[i] or 0) then return i end
    end
    return 1
end

-- Returns the upgrade rank (1-6) within a tier for a given ilvl.
function IlvlUtils.GetRank(ilvl, tier)
    local tracking = Addon.TRACKING
    local bases    = tracking and tracking.ilvlBases
    local offsets  = tracking and tracking.ilvlRankOffsets
    if not (bases and offsets and tier) then return nil end
    local rel = (ilvl or 0) - (bases[tier] or 0)
    for r = #offsets, 1, -1 do
        if rel >= (offsets[r] or 0) then return r end
    end
    return 1
end

-- Returns an 8-char "ffRRGGBB" hex string for |c colour codes (lowercase prefix).
-- Falls back to opaque white if the tier cannot be determined.
function IlvlUtils.GetColorHex(ilvl)
    local tier   = IlvlUtils.GetTier(ilvl)
    local colors = Addon.TRACKING and Addon.TRACKING.crestColors
    if tier and colors and colors[tier] then
        return "ff" .. colors[tier]
    end
    return "ffffffff"
end

-- Returns a "|cFFRRGGBB" WoW colour-escape prefix for the given tier index.
-- Falls back to opaque white.
function IlvlUtils.GetEscapePrefix(tier)
    local colors = Addon.TRACKING and Addon.TRACKING.crestColors
    if tier and colors and colors[tier] then
        return "|cFF" .. colors[tier]
    end
    return "|cFFFFFFFF"
end

-- Returns a human-readable track+rank label for a given ilvl, e.g. "Champion 1".
-- Returns nil if the tier or rank cannot be determined.
function IlvlUtils.GetTrackLabel(ilvl)
    local tier  = IlvlUtils.GetTier(ilvl)
    local rank  = IlvlUtils.GetRank(ilvl, tier)
    local names = Addon.TRACKING and Addon.TRACKING.crestTrackNames
    if not (tier and rank and names and names[tier]) then return nil end
    return names[tier] .. " " .. rank
end
