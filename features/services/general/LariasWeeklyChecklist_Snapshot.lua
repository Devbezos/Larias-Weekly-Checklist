-- LariasWeeklyChecklist_Snapshot.lua
-- Captures tracking data without depending on tracking-panel UI state.
local addonName = ...
local Addon = _G[addonName]
if not Addon then return end

local API = Addon.TrackingSnapshotAPI or {}
Addon.TrackingSnapshotAPI = API

local API_DEFAULTS = {
    TooltipInfo = function() return C_TooltipInfo end,
    MythicPlus = function() return C_MythicPlus end,
    ChallengeMode = function() return C_ChallengeMode end,
    ItemUpgrade = function() return C_ItemUpgrade end,
    ItemLocation = function() return ItemLocation end,
    GetInventoryItemLink = function() return GetInventoryItemLink end,
    GetDetailedItemLevelInfo = function() return GetDetailedItemLevelInfo end,
    GetInventoryItemLevel = function() return GetInventoryItemLevel end,
}

-- Tests can assign any API field directly. Missing fields resolve against the
-- live WoW globals on access, including APIs loaded on demand after login.
setmetatable(API, {
    __index = function(_, key)
        local provider = API_DEFAULTS[key]
        return provider and provider() or nil
    end,
})

local function IsItemEmbellished(itemLink)
    if not (itemLink and API.TooltipInfo and API.TooltipInfo.GetHyperlink) then
        return false
    end

    local data = API.TooltipInfo.GetHyperlink(itemLink)
    if not (data and data.lines) then return false end

    for _, line in ipairs(data.lines) do
        local leftText = line and line.leftText
        local rightText = line and line.rightText
        if leftText and tostring(leftText):lower():find("embellish", 1, true) then
            return true
        end
        if rightText and tostring(rightText):lower():find("embellish", 1, true) then
            return true
        end
    end

    return false
end

local function CopySlotData(slotData)
    if type(slotData) ~= "table" then return nil end
    local copy = {}
    for k, v in pairs(slotData) do
        copy[k] = v
    end
    return copy
end

local function GetSlotWatermarkScore(slotData)
    if type(slotData) ~= "table" then
        return 0, 0, 0, 0, 0
    end

    local ilvl = tonumber(slotData.ilvl) or 0
    local tierIdx = tonumber(slotData.tierIdx) or 0
    local rank = tonumber(slotData.rank) or 0
    local trueMaxRank = tonumber(slotData.trueMaxRank) or 0
    local maxRank = tonumber(slotData.maxRank) or 0
    return ilvl, tierIdx, rank, trueMaxRank, maxRank
end

local function ShouldReplaceWatermarkSlot(current, previous)
    if type(current) ~= "table" then return false end
    if type(previous) ~= "table" then return true end

    local ci, ct, cr, ctm, cm = GetSlotWatermarkScore(current)
    local pi, pt, pr, ptm, pm = GetSlotWatermarkScore(previous)
    if ci ~= pi then return ci > pi end
    if ct ~= pt then return ct > pt end
    if cr ~= pr then return cr > pr end
    if ctm ~= ptm then return ctm > ptm end
    if cm ~= pm then return cm > pm end
    if current.link and not previous.link then return true end
    return false
end

function Addon:BuildTrackingSnapshot(snap)
    -- Left column: Great Vault via the GreatVault module API.
    local gridBlocks, gvLines = Addon:GetGVData()

    snap.leftLines = snap.leftLines or {}
    for i = 1, 9 do snap.leftLines[i] = (gvLines and gvLines[i]) or "" end

    if gridBlocks then
        snap.leftGrid = snap.leftGrid or {{},{},{}}
        for bi = 1, 3 do
            local src = gridBlocks[bi]
            local dst = snap.leftGrid[bi]
            if src and dst then
                dst.available = src.available
                dst.complete  = src.complete
                dst.maxIlvl   = src.maxIlvl
                dst.slots     = dst.slots or {{},{},{}}
                for si = 1, 3 do
                    if src.slots and src.slots[si] and dst.slots[si] then
                        dst.slots[si].thresh = src.slots[si].thresh
                        dst.slots[si].ilvl   = src.slots[si].ilvl
                    end
                end
            end
        end
    end

    -- Right column: currency data via the Currency module API.
    Addon:FillCurrencySnapshot(snap)

    -- Keystone: current M+ key held by the logged-in character.
    do
        local ksLevel = API.MythicPlus
                        and type(API.MythicPlus.GetOwnedKeystoneLevel) == "function"
                        and API.MythicPlus.GetOwnedKeystoneLevel() or nil
        local ksMapID = API.MythicPlus
                        and type(API.MythicPlus.GetOwnedKeystoneChallengeMapID) == "function"
                        and API.MythicPlus.GetOwnedKeystoneChallengeMapID() or nil
        local ksName
        if ksMapID and API.ChallengeMode and type(API.ChallengeMode.GetMapUIInfo) == "function" then
            ksName = API.ChallengeMode.GetMapUIInfo(ksMapID)
        end
        snap.keystone = snap.keystone or {}
        snap.keystone.level = tonumber(ksLevel) or 0
        snap.keystone.name  = ksName or ""
    end

    -- Equipment slots: full item data for the gear popup and upgrade-cost rows.
    -- tier and rank are derived from the equipped item's ilvl using IlvlUtils.
    local previousBestGearSlots = type(snap.bestGearSlots) == "table" and snap.bestGearSlots
                               or type(snap.gearSlots) == "table" and snap.gearSlots
                               or nil
    snap.gearSlots = {}
    local snapSlotIDs = (Addon.TRACKING and Addon.TRACKING.gearSlotIDs)
                        or {1,2,3,5,6,7,8,9,10,11,12,13,14,15,16,17}
    local maxRankCount = Addon.TRACKING and Addon.TRACKING.ilvlRankOffsets
                         and #Addon.TRACKING.ilvlRankOffsets or 6
    for _, sid in ipairs(snapSlotIDs) do
        local link = API.GetInventoryItemLink and API.GetInventoryItemLink("player", sid)
        -- API.GetDetailedItemLevelInfo parses upgrade bonus IDs from the link directly;
        -- it is more reliable than API.GetInventoryItemLevel for upgraded items.
        local ilvl = 0
        if link and API.GetDetailedItemLevelInfo then
            local effIlvl = API.GetDetailedItemLevelInfo(link)
            ilvl = tonumber(effIlvl) or 0
        end
        -- Only fall back to API.GetInventoryItemLevel when we have a real item link.
        -- Without this guard, API.GetInventoryItemLevel("player", 17) echoes the 2H
        -- weapon ilvl for an empty off-hand slot, causing double upgrade cost.
        if ilvl == 0 and link then
            local rawIlvl = API.GetInventoryItemLevel and API.GetInventoryItemLevel("player", sid)
            ilvl = tonumber(rawIlvl) or 0
        end

        local tierIdx, rank, maxRank
        if ilvl > 0 and Addon.IlvlUtils then
            tierIdx = Addon.IlvlUtils.GetTier(ilvl)
            if tierIdx then
                rank    = Addon.IlvlUtils.GetRank(ilvl, tierIdx)
                maxRank = maxRankCount
            end
        end

        snap.gearSlots[sid] = {
            link          = link,
            ilvl          = ilvl,
            rank          = rank,
            maxRank       = maxRank,
            tierIdx       = tierIdx,
            isEmbellished = IsItemEmbellished(link) or nil,
        }
    end

    -- Weapon slot comparison: prefer 2H (slot 16 only) over dual-wield (slots 16+17)
    -- when the 2H ilvl is >= the off-hand ilvl, OR when slot 17 has no real item.
    -- The link-gated fallback above already keeps slot 17 at ilvl=0 for 2H users;
    -- this block is a safety net in case any stray ilvl bled through.
    do
        local ws16 = snap.gearSlots[16]
        local ws17 = snap.gearSlots[17]
        if ws16 and ws17 then
            local ilvl16 = ws16.ilvl or 0
            local ilvl17 = ws17.ilvl or 0
            -- If 2H is highest (slot 17 has no real link but echoed an ilvl), clear it.
            if ilvl16 > 0 and ilvl16 >= ilvl17 and not ws17.link then
                snap.gearSlots[17] = { link=nil, ilvl=0, rank=nil, maxRank=nil, tierIdx=nil }
            end
        end
    end

    -- Auto-detect per-tier upgrade cost and true max rank via API.ItemUpgrade.
    -- WoW only returns reliable upgrade details in some contexts, so missing or
    -- empty API data must not mark an item as capped.  When details are missing,
    -- Alt Summary falls back to rank math and default crest costs.
    snap.upgradeCostPerStep = {}
    snap.upgradeDetailsAvailable = false
    if API.ItemUpgrade and API.ItemUpgrade.SetItemUpgradeFromLocation
            and API.ItemUpgrade.GetItemUpgradeItemInfo and API.ItemLocation then
        local TRACKING = Addon.TRACKING
        local crestIDs = TRACKING and TRACKING.crestCurrencyIDs
        local checkedTiers = {}
        for _, sid in ipairs(snapSlotIDs) do
            local gs = snap.gearSlots[sid]
            if gs and gs.link and gs.tierIdx and gs.rank and gs.maxRank then
                local tierIdx = gs.tierIdx
                local crestID = crestIDs and crestIDs[tierIdx]
                local upgradeReadOK = pcall(function()
                    API.ItemUpgrade.SetItemUpgradeFromLocation(
                        API.ItemLocation:CreateFromEquipmentSlot(sid))
                    local info = API.ItemUpgrade.GetItemUpgradeItemInfo()
                    if info and type(info.upgradeLevelInfos) == "table" then
                        snap.upgradeDetailsAvailable = true
                        -- Read the next upgrade step once; reused for tier correction,
                        -- embellished detection, and cost capture below.
                        -- NOTE: #upgradeLevelInfos is REMAINING levels from current rank,
                        -- not an absolute index.  The nextLevel index may be out of range
                        -- if currUpgrade counts from the track start; the [1] fallback
                        -- always gives us the next remaining upgrade.
                        local nextLevel = (info.currUpgrade or 0) + 1
                        local levelInfo = info.upgradeLevelInfos[nextLevel]
                                      or info.upgradeLevelInfos[1]
                        local costs = levelInfo and levelInfo.currencyCostsToUpgrade
                        local remainingCrestCost, sawRemainingCrestCost = 0, false

                        -- Correct tier BEFORE computing trueMaxRank.
                        -- Items at rank 5/6 of tier N share ilvl values with rank 1/2
                        -- of tier N+1, so GetTier() can assign the wrong tier.  A
                        -- Champion rank-5 item (ilvl 259) appears as Hero rank-1 and
                        -- would be falsely flagged embellished (trueMaxRank = 1+1 = 2 < 6)
                        -- without this correction.  The upgrade currency resolves the
                        -- ambiguity definitively.
                        if costs and crestIDs then
                            local actualTierIdx = Addon:GetCrestTierFromCosts(costs)
                            if actualTierIdx and actualTierIdx ~= tierIdx then
                                local newRank = Addon.IlvlUtils
                                    and Addon.IlvlUtils.GetRank(gs.ilvl, actualTierIdx)
                                if newRank then
                                    snap.gearSlots[sid].tierIdx = actualTierIdx
                                    snap.gearSlots[sid].rank    = newRank
                                    gs.tierIdx = actualTierIdx
                                    gs.rank    = newRank
                                    tierIdx    = actualTierIdx
                                    crestID    = crestIDs[actualTierIdx]
                                end
                            end
                        end

                        -- Detect embellished/crafted caps using the now-corrected rank.
                        -- Empty upgradeLevelInfos is not enough proof of a cap; WoW can
                        -- return that when upgrade details are temporarily unavailable.
                        local nLevels     = #info.upgradeLevelInfos
                        local trueMaxRank = (nLevels > 0) and (gs.rank + nLevels) or nil
                        if trueMaxRank and trueMaxRank < gs.maxRank then
                            snap.gearSlots[sid].trueMaxRank = trueMaxRank
                        end

                        if crestID and nLevels > 0 then
                            -- Sum the exact remaining crest cost reported by WoW for
                            -- this slot. This captures crest discounts per item/tier,
                            -- including fully discounted steps where no crest is due.
                            for _, upgradeInfo in ipairs(info.upgradeLevelInfos) do
                                local stepCosts = upgradeInfo and upgradeInfo.currencyCostsToUpgrade
                                local stepHasCrest = false
                                if stepCosts then
                                    for _, ce in ipairs(stepCosts) do
                                        if ce.currencyID == crestID then
                                            stepHasCrest = true
                                            sawRemainingCrestCost = true
                                            remainingCrestCost = remainingCrestCost + (tonumber(ce.cost) or 0)
                                            break
                                        end
                                    end
                                end
                                -- If WoW gives remaining upgrade levels but omits the
                                -- crest currency on a step, treat that step as discounted
                                -- to zero crests rather than capping the item.
                                if not stepHasCrest then sawRemainingCrestCost = true end
                            end
                        end
                        if sawRemainingCrestCost then
                            snap.gearSlots[sid].upgradeCostRemaining = remainingCrestCost
                        end

                        -- Capture per-tier cost from the first upgradable slot found.
                        if crestID and not checkedTiers[tierIdx]
                                and snap.gearSlots[sid].rank < snap.gearSlots[sid].maxRank then
                            if levelInfo and levelInfo.currencyCostsToUpgrade then
                                for _, ce in ipairs(levelInfo.currencyCostsToUpgrade) do
                                    if ce.currencyID == crestID then
                                        snap.upgradeCostPerStep[tierIdx] = ce.cost
                                        checkedTiers[tierIdx] = true
                                        break
                                    end
                                end
                            end
                        end
                    else
                        -- No reliable item-upgrade details for this slot. Leave
                        -- trueMaxRank unset so display code uses the normal tier cap.
                        snap.gearSlots[sid].upgradeInfoUnavailable = true
                    end
                end)
                if not upgradeReadOK then
                    snap.gearSlots[sid].upgradeInfoUnavailable = true
                end
            end
        end
        if API.ItemUpgrade.ClearItemUpgrade then API.ItemUpgrade.ClearItemUpgrade() end
    end

    snap.bestGearSlots = {}
    for _, sid in ipairs(snapSlotIDs) do
        local currentSlot = snap.gearSlots[sid]
        local previousSlot = previousBestGearSlots and previousBestGearSlots[sid]
        if ShouldReplaceWatermarkSlot(currentSlot, previousSlot) then
            snap.bestGearSlots[sid] = CopySlotData(currentSlot)
        else
            snap.bestGearSlots[sid] = CopySlotData(previousSlot) or CopySlotData(currentSlot)
        end
    end
end
