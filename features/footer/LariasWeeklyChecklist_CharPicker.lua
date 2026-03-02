local addonName = ...
local Addon = _G[addonName]
if not Addon then return end

-- ── Character profile helpers ────────────────────────────────────────────────

-- Returns a sorted list of all characters that have ever logged in with the addon.
-- Primary source: AceDB's sv.profileKeys (populated on every login automatically).
-- Secondary: global.chars keys (in case a char only has the new-format data).
function Addon:GetCharProfileKeys()
    local seen = {}
    local keys = {}

    local sv = self.db and self.db.sv
    if sv and sv.profileKeys then
        for charKey in pairs(sv.profileKeys) do
            if not seen[charKey] then
                seen[charKey] = true
                tinsert(keys, charKey)
            end
        end
    end

    -- Also include any chars that exist in global.chars but not in sv.profileKeys.
    local chars = self.db and self.db.global and self.db.global.chars
    if chars then
        for charKey in pairs(chars) do
            if not seen[charKey] then
                seen[charKey] = true
                tinsert(keys, charKey)
            end
        end
    end

    table.sort(keys)
    return keys
end

-- Switches the viewed character.  profileKey=nil means own character.
-- Character data lives in db.global.chars[key] so no profile switching is
-- needed \u2014 just update _viewingChar and refresh the UI.
function Addon:SetViewingChar(profileKey)
    local ownKey = self:GetCurrentProfileKey()
    if profileKey == nil or profileKey == ownKey then
        self._viewingChar = nil
    else
        self._viewingChar = profileKey
    end
    if self._cpUpdateLabel then self._cpUpdateLabel() end
    -- Switch to list tab in case the user was on the Options tab.
    if self.SelectMainTab and not self._inLayoutHeaderButtons then
        self:SelectMainTab(1)
    end
    -- Guard against re-entry: LayoutHeaderButtons_ may reset _viewingChar directly
    -- to avoid this exact call, but protect here too in case other callers exist.
    if not self._inLayoutHeaderButtons then
        if self.LayoutHeaderButtons then self:LayoutHeaderButtons() end
    end
    if self.RequestRefresh then self:RequestRefresh() else self:Refresh() end
end

-- Returns true when there is at least one character the picker can switch to.
-- Used by LayoutHeaderButtons_ and SyncGearPopup to decide visibility.
function Addon:HasPickableChars()
    if self._viewingChar then return true end  -- "back to me" row is available
    if not (self.GetCharProfileKeys and self.GetCurrentProfileKey) then return false end
    local ownKey = self:GetCurrentProfileKey()
    local gdb    = self.db and self.db.global
    for _, charKey in ipairs(self:GetCharProfileKeys()) do
        local isOwn    = (charKey == ownKey) or (charKey:lower() == ownKey:lower())
        local isHidden = gdb and gdb.hiddenChars and gdb.hiddenChars[charKey]
        if not isOwn and not isHidden then
            local classToken = gdb and gdb.charClasses and gdb.charClasses[charKey]
            local snap = gdb and gdb.chars and gdb.chars[charKey] and gdb.chars[charKey].trackingSnapshot
            local usable = snap and (
                snap.leftLines ~= nil or
                (function()
                    if type(snap.rightRows) ~= "table" then return false end
                    for _, row in ipairs(snap.rightRows) do
                        if row.qty and row.qty > 0 then return true end
                    end
                    return false
                end)()
            )
            if classToken and usable then return true end
        end
    end
    return false
end

-- ── UI construction ───────────────────────────────────────────────────────────
-- Called once from CreateFrame (main file) after StyleMainTabButton is available.
-- Installs behaviour hooks on Addon so LayoutHeaderButtons_ can call them without
-- keeping direct upvalue references to the closures below.
function Addon:InitCharPickerUI(frame, styleFunc)
    local CPICK_PAD   = 6
    local CPICK_ROW_H = 20

    local charPickerBtn   -- lazy Button on `frame`
    local charPickerPanel -- floating dropdown Frame

    -- ── Button ────────────────────────────────────────────────────────────────
    local function EnsureBtn()
        if charPickerBtn then return charPickerBtn end
        local btn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        btn:SetSize(108, 22)
        if styleFunc then styleFunc(btn) end
        charPickerBtn              = btn
        frame._lariasCharPickerBtn = btn
        btn:SetScript("OnEnter", function(self_)
            local L = Addon.L or {}
            GameTooltip:SetOwner(self_, "ANCHOR_BOTTOMLEFT")
            GameTooltip:SetText(L.CHAR_PICKER_BUTTON or "Swap Profile", 1, 1, 1)
            GameTooltip:AddLine(L.CHAR_PICKER_TOOLTIP_REMOVE or "To remove a character, use the Options menu.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return btn
    end

    local function UpdateLabel()
        local btn = charPickerBtn
        if not btn then return end
        local L   = Addon.L or {}
        local lbl = L.CHAR_PICKER_BUTTON or "Swap Profile"
        local panelOpen = charPickerPanel and charPickerPanel.IsShown and charPickerPanel:IsShown()
        local arrowTex  = panelOpen
            and "|TInterface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up:10:10|t"
            or  "|TInterface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up:10:10|t"
        btn:SetText(lbl .. " " .. arrowTex)
        local tr = btn.Text or (btn.GetFontString and btn:GetFontString())
        if tr and Addon.THEME and Addon.THEME.text then
            local t = Addon.THEME.text
            tr:SetTextColor(t.r, t.g, t.b, 1)
        end
    end

    -- ── Panel ─────────────────────────────────────────────────────────────────
    local function EnsurePanel()
        if charPickerPanel then return charPickerPanel end
        local p = Addon.Controls.NewPopupPanel("HIGH", 0.15)
        p:SetSize(160, 40)
        p._buttons    = {}
        p._buttonPool = {}
        charPickerPanel = p
        -- Keep the toggle-button arrow in sync with panel visibility.
        p:HookScript("OnShow", function() UpdateLabel() end)
        p:HookScript("OnHide", function() UpdateLabel() end)
        return p
    end

    local function ReleaseBtns(p)
        if not (p and p._buttons and p._buttonPool) then return end
        for i = #p._buttons, 1, -1 do
            local btn = p._buttons[i]
            p._buttons[i] = nil
            if btn then
                btn:Hide()
                btn:ClearAllPoints()
                btn:SetScript("OnClick", nil)
                btn:SetScript("OnEnter", nil)
                btn:SetScript("OnLeave", nil)
                tinsert(p._buttonPool, btn)
            end
        end
        p._buttons = {}
    end

    local function AcquireBtn(p)
        local btn = tremove(p._buttonPool)
        if not btn then
            btn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
            btn:SetFrameStrata("HIGH")
            if styleFunc then styleFunc(btn) end
            -- StyleMainTabButton resets backdrop colors; re-apply theme after it runs.
            Addon:ApplyTheme(btn)
            local tr = btn.Text or (btn.GetFontString and btn:GetFontString())
            if tr then
                if tr.SetJustifyH then tr:SetJustifyH("LEFT") end
                if tr.SetJustifyV then tr:SetJustifyV("MIDDLE") end
                -- StyleMainTabButton pins text to CENTER; override to fill left-to-right.
                if tr.ClearAllPoints and tr.SetPoint then
                    tr:ClearAllPoints()
                    tr:SetPoint("LEFT",  btn, "LEFT",  6, 0)
                    tr:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
                end
            end
        end
        btn:Show()
        return btn
    end

    -- Helper: look up class token for a charKey.
    -- Only direct charKey lookups are used; profile-name fallbacks are
    -- intentionally omitted to avoid inheriting colours from shared AceDB
    -- profiles (e.g. "Default") which may belong to a different class.
    local function classFor(charKey)
        local gdb = Addon.db and Addon.db.global
        if not (gdb and gdb.charClasses) then return nil end
        return gdb.charClasses[charKey] or nil
    end

    -- Helper: returns true only if the char has enough saved data to be
    -- worth showing.  A char with only all-zero currency rows (e.g. first
    -- login before doing any weeklies) is treated as having no usable data.
    local function hasUsableData(charKey)
        local gdb = Addon.db and Addon.db.global
        local cdb = gdb and gdb.chars and gdb.chars[charKey]
        if not cdb then return false end
        local snap = cdb.trackingSnapshot
        if not snap then return false end
        -- Weekly-task tracking lines present → definitely has data.
        if snap.leftLines ~= nil then return true end
        -- Currency rows present, but only count if at least one is non-zero.
        if type(snap.rightRows) == "table" then
            for _, row in ipairs(snap.rightRows) do
                if row.qty and row.qty > 0 then return true end
            end
        end
        return false
    end

    local function Populate()
        local CHECK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12|t"
        local p       = EnsurePanel()
        ReleaseBtns(p)
        local ownKey  = Addon:GetCurrentProfileKey()
        local allKeys = Addon:GetCharProfileKeys()
        local gdb     = Addon.db and Addon.db.global
        local posY    = -CPICK_PAD

        -- When viewing another character, show a "back to me" entry first.
        if Addon._viewingChar then
            local myName = (UnitName and UnitName("player")) or "My character"
            local btn = AcquireBtn(p)
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT",  p, "TOPLEFT",  0, posY)
            btn:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, posY)
            btn:SetHeight(CPICK_ROW_H)
            btn:SetText("<< " .. myName)  -- back to own char
            local tr = btn.Text or (btn.GetFontString and btn:GetFontString())
            local th = Addon.THEME.text
            if tr then tr:SetTextColor(th.r, th.g, th.b, 0.7) end
            btn:SetScript("OnEnter", function(self_)
                local fs = self_.Text or (self_.GetFontString and self_:GetFontString())
                if fs then fs:SetTextColor(1, 1, 0, 1) end
            end)
            btn:SetScript("OnLeave", function(self_)
                local fs = self_.Text or (self_.GetFontString and self_:GetFontString())
                if fs then fs:SetTextColor(th.r, th.g, th.b, 0.7) end
            end)
            btn:SetScript("OnClick", function()
                p:Hide()
                Addon:SetViewingChar(nil)
            end)
            tinsert(p._buttons, btn)
            posY = posY - CPICK_ROW_H
        end

        for _, profileKey in ipairs(allKeys) do
            -- Skip own character.
            local isOwn     = (profileKey == ownKey)
            -- Also compare case-insensitively for safety (realm capitalisation).
            if not isOwn then
                isOwn = (profileKey:lower() == ownKey:lower())
            end
            local isViewing = (profileKey == Addon._viewingChar)
            local isHidden  = (gdb and gdb.hiddenChars and gdb.hiddenChars[profileKey]) and true or false
            if not isOwn and not isHidden then
                local classToken = classFor(profileKey)
                -- Skip chars with no class entry or no saved snapshot data.
                if classToken and hasUsableData(profileKey) then
                local charName = (profileKey:match("^(.-)%s*%-") or profileKey):gsub("^%s+",""):gsub("%s+$","")
                if charName == "" then charName = profileKey end

                local r, g, b = 1, 1, 1
                local cc = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
                if cc then r, g, b = cc.r, cc.g, cc.b end

                local btn = AcquireBtn(p)
                btn:ClearAllPoints()
                -- Name button spans the full panel width.
                btn:SetPoint("TOPLEFT",  p, "TOPLEFT",  0, posY)
                btn:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, posY)
                btn:SetHeight(CPICK_ROW_H)

                if isViewing then
                    -- Currently viewed: show ✔ prefix, disable clicking; no X.
                    btn:SetText(CHECK .. " " .. charName)
                    btn:SetEnabled(false)
                    local tr = btn.Text or (btn.GetFontString and btn:GetFontString())
                    if tr then tr:SetTextColor(0, 1, 0, 0.9) end
                    btn:SetScript("OnClick", nil)
                    btn:SetScript("OnEnter", nil)
                    btn:SetScript("OnLeave", nil)
                else
                    btn:SetText(charName)
                    btn:SetEnabled(true)
                    local tr = btn.Text or (btn.GetFontString and btn:GetFontString())
                    if tr then tr:SetTextColor(r, g, b, 1) end

                    local _r, _g, _b, _pk = r, g, b, profileKey
                    btn:SetScript("OnEnter", function(self_)
                        local fs = self_.Text or (self_.GetFontString and self_:GetFontString())
                        if fs then fs:SetTextColor(1, 1, 0, 1) end
                    end)
                    btn:SetScript("OnLeave", function(self_)
                        local fs = self_.Text or (self_.GetFontString and self_:GetFontString())
                        if fs then fs:SetTextColor(_r, _g, _b, 1) end
                    end)
                    btn:SetScript("OnClick", function()
                        p:Hide()
                        Addon:SetViewingChar(_pk)
                    end)
                end
                tinsert(p._buttons, btn)
                posY = posY - CPICK_ROW_H
                end  -- classToken guard
            end
        end

        -- No entries built → nothing to show; close and bail out.
        if #p._buttons == 0 then
            p:Hide()
            return
        end

        p:SetHeight(math.max(40, -posY + CPICK_PAD))

        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                if not (p and p.IsShown and p:IsShown()) then return end
                local bestW = 0
                for _, b in ipairs(p._buttons) do
                    local tr = b.Text or (b.GetFontString and b:GetFontString())
                    local w
                    if tr then
                        if tr.GetUnboundedStringWidth then w = tonumber(tr:GetUnboundedStringWidth())
                        elseif tr.GetStringWidth      then w = tonumber(tr:GetStringWidth()) end
                    end
                    if not w and b.GetTextWidth then w = tonumber(b:GetTextWidth()) end
                    if w and w > bestW then bestW = w end
                end
                -- Buttons fill via TOPLEFT+TOPRIGHT anchors; only panel width needed.
                -- +10 for text insets (LEFT+6, RIGHT-4). X sits outside panel.
                local totalW = math.max(90, math.min(260, math.ceil(bestW) + 10))
                p:SetWidth(totalW)
            end)
        end
    end  -- end Populate

    -- ── OnClick for the header button ─────────────────────────────────────────
    local function OnPickerBtnClick()
        local p = EnsurePanel()
        if p and p._lariasClosedAt and (GetTime() - p._lariasClosedAt) < 0.20 then p._lariasClosedAt = nil; return end
        if p and p.IsShown and p:IsShown() then
            p:Hide()
            return
        end
        local btn = EnsureBtn()
        p:ClearAllPoints()
        p:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -4)
        p:Show()
        if C_Timer and C_Timer.After then
            C_Timer.After(0, Populate)
        else
            Populate()
        end
    end

    -- ── Store hooks on Addon so LayoutHeaderButtons_ can call them ────────────
    Addon._cpEnsureBtn     = EnsureBtn
    Addon._cpUpdateLabel   = UpdateLabel
    Addon._cpPopulate      = Populate
    Addon._cpOnClick       = OnPickerBtnClick
    Addon._cpClose         = function()
        if charPickerPanel and charPickerPanel.IsShown and charPickerPanel:IsShown() then
            charPickerPanel:Hide()
        end
    end
    -- Also expose UpdateLabel under the old name used by SetViewingChar above.
    Addon.UpdateCharPickerBtnLabel = UpdateLabel
end
