-- Completion easter egg: "touch grass" animation when all items are checked.
-- Remove this file from the TOC to disable the easter egg entirely; the addon
-- will work normally but the completion animation and scrollbar hide will not appear.
local addonName = ...
local Addon = _G[addonName]
if not Addon then return end

function Addon:CreateCompletionEasterEgg(scrollFrame)
    -- Build the "touch grass" (hand + plus + grass) display frame.
    -- Called from CreateFrame() right after the scroll frame is created.
    local frame = Addon._mainFrame
    if not (frame and scrollFrame) then return end

    -- Easter egg: "touch grass" trio -- hand + plus + grass icons.
    local egg = CreateFrame("Frame", nil, scrollFrame)
    egg:SetPoint("CENTER", scrollFrame, "CENTER", 0, 0)
    egg:SetSize(1, 1)
    egg:Hide()

    local handTex = egg:CreateTexture(nil, "ARTWORK")
    handTex:SetTexture("Interface\\Icons\\Spell_Holy_LayOnHands")
    if handTex.SetTexCoord then handTex:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    handTex:SetAlpha(0.95)

    local plusFS = egg:CreateFontString(nil, "OVERLAY")
    plusFS:SetFont("Fonts\\FRIZQT__.TTF", 32, "OUTLINE")
    plusFS:SetText("+")
    plusFS:SetTextColor(1, 1, 1, 0.95)
    plusFS:SetJustifyH("CENTER")
    plusFS:SetJustifyV("MIDDLE")

    local grassTex = egg:CreateTexture(nil, "ARTWORK")
    grassTex:SetTexture("Interface\\Icons\\Ability_Druid_Flourish")
    if grassTex.SetTexCoord then grassTex:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    grassTex:SetAlpha(0.95)

    -- Override SetSize so the three elements reflow whenever the caller
    -- resizes the container (icons scale with available scroll area).
    local _rawSetSize = egg.SetSize
    function egg:SetSize(w, h)
        local iconSize = math.max(32, math.min(160, math.floor(h * 0.43)))
        local gap      = math.max(4,  math.floor(iconSize * 0.10))
        local plusW    = math.max(16, math.floor(iconSize * 0.45))
        local totalW   = iconSize + gap + plusW + gap + iconSize
        _rawSetSize(self, totalW, iconSize)

        handTex:SetSize(iconSize, iconSize)
        handTex:ClearAllPoints()
        handTex:SetPoint("LEFT", self, "LEFT", 0, 0)

        plusFS:SetSize(plusW, iconSize)
        plusFS:ClearAllPoints()
        plusFS:SetPoint("LEFT", handTex, "RIGHT", gap, 0)
        plusFS:SetFont("Fonts\\FRIZQT__.TTF",
            math.max(14, math.floor(iconSize * 0.55)), "OUTLINE")

        grassTex:SetSize(iconSize, iconSize)
        grassTex:ClearAllPoints()
        grassTex:SetPoint("LEFT", plusFS, "RIGHT", gap, 0)
    end

    frame._lariasPigTexture = egg
end

function Addon:UpdateCompletionEasterEgg(db)
    -- Fun cosmetic: show pig icon when everything is done.
    -- Also hides the scrollbar when the list is complete.
    local frame       = Addon._mainFrame
    local scrollFrame = Addon._scrollFrame
    if not (frame and scrollFrame) then return end

    db = db or self:EnsureDB()
    local isComplete = self:IsListComplete(db)

    local visibleSections = 0
    if self._activeSections then
        for i = 1, #self._activeSections do
            local sectionFrame = self._activeSections[i]
            if sectionFrame and sectionFrame.IsShown and sectionFrame:IsShown() then
                visibleSections = visibleSections + 1
                break
            end
        end
    end

    local showPig = isComplete and (visibleSections == 0)

    local pig = frame._lariasPigTexture
    if pig and pig.SetShown then
        pig:SetShown(showPig)
        if showPig and scrollFrame and scrollFrame.GetWidth and scrollFrame.GetHeight then
            local scrollWidth  = tonumber(scrollFrame:GetWidth())  or 0
            local scrollHeight = tonumber(scrollFrame:GetHeight()) or 0
            local size = math.min(scrollWidth  > 0 and scrollWidth  or 260,
                                  scrollHeight > 0 and scrollHeight or 260)
            size = math.max(120, size)
            if pig.SetSize then
                pig:SetSize(size, size)
            end
        end
    end

    local sb = scrollFrame.ScrollBar
    if sb and sb.SetShown then
        sb:SetShown(not isComplete)
    elseif sb and isComplete and sb.Hide then
        sb:Hide()
    elseif sb and (not isComplete) and sb.Show then
        sb:Show()
    end
end
