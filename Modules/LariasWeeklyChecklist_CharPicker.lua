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
        return btn
    end

    local function UpdateLabel()
        local btn = charPickerBtn
        if not btn then return end
        local ownKey     = Addon:GetCurrentProfileKey()
        local displayKey = Addon._viewingChar or ownKey
        -- For the logged-in character use the actual player name so the button never
        -- shows "Default" when AceDB is using a shared profile key by that name.
        local charName
        if not Addon._viewingChar then
            charName = (UnitName and UnitName("player")) or ""
            if charName == "" then
                charName = (displayKey:match("^(.-)%s*%-") or displayKey):gsub("^%s+",""):gsub("%s+$","")
            end
        else
            charName = (displayKey:match("^(.-)%s*%-") or displayKey):gsub("^%s+",""):gsub("%s+$","")
        end
        if charName == "" then charName = "Me" end
        btn:SetText(charName .. " |TInterface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up:10:10|t")
        local gdb        = Addon.db and Addon.db.global
        local classToken = gdb and gdb.charClasses and gdb.charClasses[displayKey]
        local tr         = btn.Text or (btn.GetFontString and btn:GetFontString())
        if tr then
            local cc = classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
            if cc then
                tr:SetTextColor(cc.r, cc.g, cc.b, 1)
            else
                tr:SetTextColor(Addon.THEME.text.r, Addon.THEME.text.g, Addon.THEME.text.b, 1)
            end
        end
    end

    -- ── Panel ─────────────────────────────────────────────────────────────────
    local function EnsurePanel()
        if charPickerPanel then return charPickerPanel end
        local p
        if BackdropTemplateMixin then
            p = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        else
            p = CreateFrame("Frame", nil, UIParent)
            if BackdropTemplateMixin and Mixin and not p.SetBackdrop then
                Mixin(p, BackdropTemplateMixin)
            end
        end
        p:SetFrameStrata("HIGH")
        p:SetClampedToScreen(true)
        p:SetSize(160, 40)
        p:Hide()
        if p.SetToplevel   then p:SetToplevel(true)  end
        if p.SetFrameLevel then p:SetFrameLevel(200) end
        Addon:ApplyTheme(p)
        if p.SetBackdropColor then
            p:SetBackdropColor(Addon.THEME.bg.r, Addon.THEME.bg.g, Addon.THEME.bg.b, 1.0)
        end
        p._buttons     = {}
        p._buttonPool  = {}
        p._xButtons    = {}
        p._xButtonPool = {}
        -- Invisible full-screen button: catches outside clicks and closes the panel.
        local catcher = CreateFrame("Button", nil, UIParent)
        catcher:SetAllPoints(UIParent)
        catcher:SetFrameStrata("HIGH")
        catcher:SetFrameLevel(199)
        catcher:EnableMouse(true)
        catcher:Hide()
        catcher:SetScript("OnClick", function() p:Hide() end)
        p:SetScript("OnShow", function()
            catcher:Show()
            if UIFrameFadeIn then UIFrameFadeIn(p, 0.15, 0, 1)
            else p:SetAlpha(1) end
        end)
        p:SetScript("OnHide", function() catcher:Hide() end)
        charPickerPanel = p
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
        if p._xButtons then
            for i = #p._xButtons, 1, -1 do
                local xBtn = p._xButtons[i]
                p._xButtons[i] = nil
                if xBtn then
                    xBtn:Hide()
                    xBtn:ClearAllPoints()
                    xBtn:SetScript("OnClick", nil)
                    p._xButtonPool = p._xButtonPool or {}
                    tinsert(p._xButtonPool, xBtn)
                end
            end
            p._xButtons = {}
        end
    end

    local function AcquireBtn(p)
        local btn = tremove(p._buttonPool)
        if not btn then
            btn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
            btn:SetFrameStrata("HIGH")
            if styleFunc then styleFunc(btn) end
            if btn.SetTextInsets then btn:SetTextInsets(4, 4, 0, 0) end
            local tr = btn.Text or (btn.GetFontString and btn:GetFontString())
            if tr then
                if tr.SetJustifyH then tr:SetJustifyH("LEFT") end
                if tr.SetJustifyV then tr:SetJustifyV("MIDDLE") end
            end
        end
        btn:Show()
        return btn
    end

    local function AcquireXBtn(p)
        local btn = p._xButtonPool and tremove(p._xButtonPool)
        if not btn then
            btn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
            btn:SetFrameStrata("HIGH")
            if styleFunc then styleFunc(btn) end
            local tr = btn.Text or (btn.GetFontString and btn:GetFontString())
            if tr then
                if tr.SetJustifyH then tr:SetJustifyH("CENTER") end
            end
        end
        btn:SetSize(20, CPICK_ROW_H)
        if btn.SetTextInsets then btn:SetTextInsets(0, 0, 0, 0) end
        btn:SetText("|TInterface\\RaidFrame\\ReadyCheck-NotReady:12:12|t")
        btn:Show()
        return btn
    end

    local function Populate()
        local CHECK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12|t"
        local p       = EnsurePanel()
        ReleaseBtns(p)
        local ownKey  = Addon:GetCurrentProfileKey()
        local allKeys = Addon:GetCharProfileKeys()
        local gdb     = Addon.db and Addon.db.global
        local sv      = Addon.db and Addon.db.sv
        local posY    = -CPICK_PAD

        -- Helper: look up class token for a charKey, falling back to the
        -- AceDB profile name in case charClasses was written under the old key.
        local function classFor(charKey)
            if not (gdb and gdb.charClasses) then return nil end
            local t = gdb.charClasses[charKey]
            if t then return t end
            -- Fallback: look via the profile name this char maps to.
            local profName = sv and sv.profileKeys and sv.profileKeys[charKey]
            return profName and gdb.charClasses[profName]
        end

        -- When viewing another character, show a "back to me" entry first.
        if Addon._viewingChar then
            local myName = (UnitName and UnitName("player")) or "My character"
            local btn = AcquireBtn(p)
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", p, "TOPLEFT", CPICK_PAD, posY)
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
                local charName = (profileKey:match("^(.-)%s*%-") or profileKey):gsub("^%s+",""):gsub("%s+$","")
                if charName == "" then charName = profileKey end

                local classToken = classFor(profileKey)
                local r, g, b    = 1, 1, 1
                if classToken then
                    local cc = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
                    if cc then r, g, b = cc.r, cc.g, cc.b end
                end

                local btn = AcquireBtn(p)
                btn:ClearAllPoints()
                btn:SetPoint("TOPLEFT", p, "TOPLEFT", CPICK_PAD, posY)
                btn:SetHeight(CPICK_ROW_H)

                if isViewing then
                    -- Currently viewed: show ✔ prefix, disable clicking.
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

                -- X button: only on non-viewed characters (can't hide while viewing).
                if not isViewing then
                    local xBtn = AcquireXBtn(p)
                    xBtn:ClearAllPoints()
                    xBtn:SetPoint("LEFT", btn, "RIGHT", 4, 0)
                    local _pkHide = profileKey
                    xBtn:SetScript("OnClick", function()
                        p:Hide()
                        local gdbH = Addon.db and Addon.db.global
                        if gdbH then
                            gdbH.hiddenChars = gdbH.hiddenChars or {}
                            gdbH.hiddenChars[_pkHide] = true
                        end
                        -- If currently viewing the hidden char, return to own.
                        if Addon._viewingChar == _pkHide then
                            Addon:SetViewingChar(nil)  -- also calls LayoutHeaderButtons
                        elseif Addon.LayoutHeaderButtons then
                            -- Re-evaluate button visibility (may now be empty).
                            Addon:LayoutHeaderButtons()
                        end
                        if Addon.RefreshHiddenCharsList then
                            Addon:RefreshHiddenCharsList()
                        end
                    end)
                    tinsert(p._xButtons, xBtn)
                end
                posY = posY - CPICK_ROW_H
            end
        end

        p:SetHeight(math.max(40, -posY + CPICK_PAD))

        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                if not (p and p.IsShown and p:IsShown()) then return end
                local bestW = 120
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
                local btnW  = math.max(140, math.min(260, math.ceil(bestW + CPICK_PAD * 2 + 12)))
                local totalW = btnW + 4 + 20 + CPICK_PAD  -- name btn + gap + X btn + right pad
                p:SetWidth(totalW)
                for _, b in ipairs(p._buttons) do
                    if b.SetWidth then b:SetWidth(btnW) end
                end
                for _, xb in ipairs(p._xButtons or {}) do
                    if xb.SetWidth then xb:SetWidth(20) end
                end
            end)
        end
    end  -- end Populate

    -- ── OnClick for the header button ─────────────────────────────────────────
    local function OnPickerBtnClick()
        local p = EnsurePanel()
        if p and p.IsShown and p:IsShown() then
            p:Hide()
            return
        end
        local btn = EnsureBtn()
        p:ClearAllPoints()
        p:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -6)
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
    -- Also expose UpdateLabel under the old name used by SetViewingChar above.
    Addon.UpdateCharPickerBtnLabel = UpdateLabel
end
