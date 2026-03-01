-- Minimap icon (LibDataBroker + LibDBIcon).
-- Remove this file from the TOC to disable the minimap button entirely;
-- the addon will still be accessible via the /larias slash command.
local addonName = ...
local Addon = _G[addonName]
if not Addon then return end

local L = Addon.L or {}

function Addon:SetupMinimapIcon()
    local LDB = LibStub("LibDataBroker-1.1")
    local icon = LibStub("LibDBIcon-1.0")

    local dataObject = LDB:NewDataObject(addonName, {
        type = "data source",
        text = addonName,
        icon = "Interface\\AddOns\\LariasWeeklyChecklist\\assets\\icon",
        OnClick = function(self_, button)
            if button == "LeftButton" then
                if Addon.CreateFrame then
                    Addon:CreateFrame()
                end
                Addon:Toggle()
            elseif button == "RightButton" then
                -- Dismiss any visible tooltip so it doesn't overlap the popup.
                if GameTooltip then GameTooltip:Hide() end
                -- Open the gear popup anchored to the minimap button.
                if Addon.ToggleGearPopup then
                    Addon:ToggleGearPopup(self_)
                end
            elseif button == "MiddleButton" then
                if Addon.ToggleIlvlRefWindow then
                    Addon:ToggleIlvlRefWindow()
                end
            end
        end,
        OnTooltipShow = function(tooltip)
            if not tooltip then return end
            tooltip:AddLine(L.DISPLAY_NAME or addonName, 1, 0.82, 0)
            tooltip:AddLine(L.MINIMAP_TOOLTIP_LEFT_CLICK_TOGGLE or "", 1, 1, 1)
            tooltip:AddLine(L.MINIMAP_TOOLTIP_RIGHT_CLICK_OPTIONS or "", 1, 1, 1)
            tooltip:AddLine(L.MINIMAP_TOOLTIP_MIDDLE_CLICK_ILVL or "Middle-click: toggle ilvl refs", 1, 1, 1)

            if Addon.ShouldShowLocalizationCompanionHint and Addon:ShouldShowLocalizationCompanionHint() then
                tooltip:AddLine(" ")
                tooltip:AddLine(Addon.LOCALIZATION_COMPANION_HINT_TEXT, 0.9, 0.9, 0.9)
            end
        end,
    })

    -- Store minimap config in the global DB so LibDBIcon persists the icon
    -- position and hide-state across sessions, and so Reset List never touches it.
    local gdb = Addon.db and Addon.db.global
    if gdb then
        gdb.minimap = gdb.minimap or {}
    end
    local minimapCfg = (gdb and gdb.minimap) or {}
    icon:Register(addonName, dataObject, minimapCfg)
end
