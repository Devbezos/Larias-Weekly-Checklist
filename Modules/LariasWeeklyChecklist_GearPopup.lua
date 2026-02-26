-- Gear popup: small floating panel with the 6 display toggles.
-- Appears when the gear icon in the main window header is clicked.
local addonName = ...
local Addon = _G[addonName]
if not Addon then return end

local function SetCheckText(checkButton, text)
    if not checkButton then return end
    local textRegion = checkButton.text or checkButton.Text
    if textRegion and textRegion.SetText then
        textRegion:SetText(text)
        if textRegion.SetTextColor and Addon.THEME and Addon.THEME.text then
            textRegion:SetTextColor(Addon.THEME.text.r, Addon.THEME.text.g, Addon.THEME.text.b, Addon.THEME.text.a)
        end
    end
end

-- Tints the standard UICheckButtonTemplate textures to match the dark theme.
-- Normal (unchecked box) → grey;  Checked mark → gold accent;  Hover → subtle white.
local function StyleCheckButton(cb)
    if not cb then return end
    local norm = cb.GetNormalTexture and cb:GetNormalTexture()
    if norm then norm:SetVertexColor(0.55, 0.55, 0.55, 1) end
    local chk = cb.GetCheckedTexture and cb:GetCheckedTexture()
    if chk then
        local th = Addon.THEME and Addon.THEME.header
        if th then chk:SetVertexColor(th.r, th.g, th.b, 1) end
    end
    local hi = cb.GetHighlightTexture and cb:GetHighlightTexture()
    if hi then hi:SetVertexColor(1, 1, 1, 0.12) end
end

function Addon:SyncGearPopup()
    local p = self._gearPopup
    if not p then return end
    local db = self:EnsureDB()
    local L  = self.L or {}
    local function Sync(cb, checked, label)
        if cb then
            cb:SetChecked(checked)
            SetCheckText(cb, label)
        end
    end
    Sync(p._cbHideCompleted,    db.hideCompletedSections and true or false,
         L.HIDE_COMPLETED_WEEKS      or "Hide completed weeks")
    Sync(p._cbHideGreatVault,   not db.showGreatVault,
         L.OPTIONS_HIDE_GREAT_VAULT  or "Hide Great Vault")
    Sync(p._cbHideCurrency,     not db.showCurrency,
         L.OPTIONS_HIDE_CURRENCY     or "Hide Currency")
    Sync(p._cbHideChangeWeek,   db.showChangeWeekBtn == false,
         L.OPTIONS_HIDE_CHANGE_WEEK_BTN or "Hide week selector")
    Sync(p._cbHideIlvlRef,      db.showIlvlRefBtn == false,
         L.OPTIONS_HIDE_ILVL_REF_BTN or "Hide ilvl references")
    Sync(p._cbHideCharPicker,   db.showCharPickerBtn == false,
         L.OPTIONS_HIDE_CHAR_SELECT  or "Hide character selector")
end

function Addon:ToggleGearPopup(anchor)
    local p = self._gearPopup
    if p and p.IsShown and p:IsShown() then
        p:Hide()
        return
    end

    -- Create lazily.
    if not p then
        if BackdropTemplateMixin then
            p = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        else
            p = CreateFrame("Frame", nil, UIParent)
            if BackdropTemplateMixin and Mixin then Mixin(p, BackdropTemplateMixin) end
        end
        p:SetFrameStrata("DIALOG")
        p:SetClampedToScreen(true)
        p:SetSize(230, 10)   -- height set after rows are placed
        p:Hide()
        if p.SetToplevel   then p:SetToplevel(true)   end
        if p.SetFrameLevel then p:SetFrameLevel(200)  end

        -- Backdrop
        if p.SetBackdrop then
            p:SetBackdrop({
                bgFile   = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                tile = false, edgeSize = 1,
                insets = { left=1, right=1, top=1, bottom=1 },
            })
            if Addon.THEME then
                p:SetBackdropColor(Addon.THEME.bg.r, Addon.THEME.bg.g, Addon.THEME.bg.b, 1)
                p:SetBackdropBorderColor(Addon.THEME.border.r, Addon.THEME.border.g, Addon.THEME.border.b, 1)
            end
        end

        -- Outside-click catcher.
        local catcher = CreateFrame("Button", nil, UIParent)
        catcher:SetAllPoints(UIParent)
        catcher:SetFrameStrata("DIALOG")
        catcher:SetFrameLevel(p:GetFrameLevel() - 1)
        catcher:EnableMouse(true)
        catcher:Hide()
        catcher:SetScript("OnClick", function() p:Hide() end)
        p:SetScript("OnHide", function() catcher:Hide() end)
        p:SetScript("OnShow", function()
            catcher:Show()
            if UIFrameFadeIn then UIFrameFadeIn(p, 0.12, 0, 1)
            else p:SetAlpha(1) end
        end)

        -- Build the 6 checkboxes.
        local PAD    = 10
        local ROW_H  = 26   -- UICheckButtonTemplate actual height
        local checks = {
            { key = "_cbHideCompleted",  },
            { key = "_cbHideGreatVault", },
            { key = "_cbHideCurrency",   },
            { key = "_cbHideChangeWeek", },
            { key = "_cbHideIlvlRef",    },
            { key = "_cbHideCharPicker", },
        }
        local callbacks = {
            _cbHideCompleted  = function(checked)
                local db = Addon:EnsureDB()
                db.hideCompletedSections = checked
                if Addon.RequestRefresh then Addon:RequestRefresh() else Addon:Refresh() end
            end,
            _cbHideGreatVault = function(checked)
                local db = Addon:EnsureDB()
                db.showGreatVault = not checked
                if Addon.RequestRefresh then Addon:RequestRefresh() else Addon:Refresh() end
            end,
            _cbHideCurrency   = function(checked)
                local db = Addon:EnsureDB()
                db.showCurrency = not checked
                if Addon.RequestRefresh then Addon:RequestRefresh() else Addon:Refresh() end
            end,
            _cbHideChangeWeek = function(checked)
                local db = Addon:EnsureDB()
                db.showChangeWeekBtn = not checked
                if Addon.LayoutHeaderButtons then Addon:LayoutHeaderButtons() end
            end,
            _cbHideIlvlRef    = function(checked)
                local db = Addon:EnsureDB()
                db.showIlvlRefBtn = not checked
                if Addon.LayoutHeaderButtons then Addon:LayoutHeaderButtons() end
            end,
            _cbHideCharPicker = function(checked)
                local db = Addon:EnsureDB()
                db.showCharPickerBtn = not checked
                if Addon.LayoutHeaderButtons then Addon:LayoutHeaderButtons() end
            end,
        }

        local N      = #checks
        local TILE_H = ROW_H + 8          -- height of each equal slice
        local totalH = N * TILE_H
        p:SetHeight(totalH)

        for i, info in ipairs(checks) do
            -- Each tile occupies an equal vertical slice of the popup.
            local tileTopY = -((i - 1) * TILE_H)
            local cbOffY   = tileTopY - math.floor((TILE_H - ROW_H) / 2)

            local cb = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
            cb:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, cbOffY)
            StyleCheckButton(cb)
            local _key = info.key
            local function FireToggle(newState)
                callbacks[_key](newState)
                if Addon.SyncOptionsTabControls then Addon:SyncOptionsTabControls() end
            end
            cb:SetScript("OnClick", function(self_)
                FireToggle(self_:GetChecked() and true or false)
            end)
            p[info.key] = cb

            -- Hit region: full popup width × 1/N height, zero gaps.
            local hit = CreateFrame("Button", nil, p)
            hit:SetPoint("TOPLEFT",  p, "TOPLEFT",  0, tileTopY)
            hit:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, tileTopY)
            hit:SetHeight(TILE_H)
            hit:SetFrameLevel(p:GetFrameLevel())   -- below CheckButton (p+1)
            local hl = hit:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints(hit)
            hl:SetColorTexture(1, 1, 1, 0.06)
            hit:SetScript("OnClick", function()
                local newVal = not (cb:GetChecked() and true or false)
                cb:SetChecked(newVal)
                FireToggle(newVal)
            end)
        end

        -- No deferred resize needed; height is fixed from the tile formula.

        self._gearPopup = p
    end

    -- Sync current values and labels.
    self:SyncGearPopup()

    -- Position below the anchor (gear button) or center if no anchor.
    p:ClearAllPoints()
    if anchor then
        p:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -4)
    else
        p:SetPoint("CENTER", UIParent, "CENTER")
    end
    p:Show()
end
