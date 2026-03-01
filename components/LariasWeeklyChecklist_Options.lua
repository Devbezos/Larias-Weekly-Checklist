local addonName = ...
local Addon = _G[addonName]
if not Addon then return end

function Addon:SyncOptionsTabControls()
    -- Options tab removed; keep as stub so existing call-sites don't error.
    if self.SyncGearPopup then self:SyncGearPopup() end
end

function Addon:UpdateOptionsLocalizedUI()
    -- Refresh gear popup labels when locale changes.
    if self.SyncGearPopup then self:SyncGearPopup() end
end

-- CreateBlizzOptionsPanel: no longer registers with Blizzard Interface -> AddOns.
-- Options are now accessed via the gear icon / minimap right-click (gear popup).
function Addon:CreateBlizzOptionsPanel()
    -- Intentionally a no-op; kept so call-sites don't error.
end
