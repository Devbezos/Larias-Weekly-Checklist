-- Footer module: status banner, slider visibility, and opacity management.
-- Exposes the Addon: methods that manage the bottom chrome of the main frame.
local addonName = ...
local Addon = _G[addonName]
if not Addon then return end

-- The shared registry key must match the literal string used in the main file.
local LOCALE_REGISTRY_KEY = "LARIASWEEKLYCHECKLIST_LOCALE_REGISTRY"

-- Banner sizing constants (kept here close to the functions that use them).
local BANNER_H   = 14  -- banner height in scaled frame pixels
local BANNER_PAD = 3   -- gap between banner bottom and frame bottom edge

-- ── Addon:CreateStatusBanner ──────────────────────────────────────────────────
-- Creates the one-line informational bar at the very bottom of the main frame.
-- Called once from CreateTrackingPanel (features/body/LariasWeeklyChecklist_Currency.lua).
function Addon:CreateStatusBanner(parentFrame)
    if self._statusBanner then return end
    local inset = Addon.UI.sectionInsetX or 14
    local bannerFrame = CreateFrame("Frame", nil, parentFrame)
    bannerFrame:SetHeight(BANNER_H)
    bannerFrame:SetPoint("BOTTOMLEFT",  parentFrame, "BOTTOMLEFT",   inset,  BANNER_PAD)
    bannerFrame:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", -inset,  BANNER_PAD)
    -- Always shown so it permanently reserves its space; content changes, not visibility.
    bannerFrame:Show()
    local lbl = bannerFrame:CreateFontString(nil, "OVERLAY")
    lbl:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    lbl:SetAllPoints(bannerFrame)
    lbl:SetJustifyH("CENTER")
    lbl:SetJustifyV("MIDDLE")
    lbl:SetWordWrap(false)
    bannerFrame._label    = lbl
    self._statusBanner    = bannerFrame
    self._statusBannerH   = BANNER_H
    self._statusBannerPad = BANNER_PAD
end

-- ── Addon:UpdateStatusBanner ──────────────────────────────────────────────────
-- Redraws the banner with the highest-priority message.  Priority order:
--   1. Red   – a newer addon version is available.
--   2. Amber – the client locale has no translation.
--   3. Gray  – a translation exists (encourage contributors).
--   4. Dim   – attribution credit (right-aligned, enUS default state).
function Addon:UpdateStatusBanner()
    local banner = self._statusBanner
    if not banner then return end
    local db = self:EnsureDB()
    local L  = self.L or {}

    -- Priority 1: update available.
    if db.hideUpdateNotice ~= true and self.ShouldShowUpdateNotice and self:ShouldShowUpdateNotice() then
        local myVer  = (self.GetMyVersion and self:GetMyVersion()) or ""
        local newVer = tostring(db._newestSeenRemoteVersion or "")
        local fmt    = L.STATUS_UPDATE_AVAILABLE_FMT or "Update available! You have %s, newest is %s."
        banner._label:SetJustifyH("CENTER")
        banner._label:SetText(string.format(fmt, myVer, newVer))
        banner._label:SetTextColor(1, 0.2, 0.2, 1)
        return
    end

    -- Priority 2/3: locale status notice for non-English clients.
    -- GetEffectiveLocaleCode() falls back to GetLocale() when no override is set.
    local wowLocale = (self.GetEffectiveLocaleCode and self:GetEffectiveLocaleCode())
                   or (GetLocale and GetLocale())
                   or "enUS"
    if wowLocale ~= "enUS" then
        local reg = _G[LOCALE_REGISTRY_KEY]
        local hasLocale = reg
            and type(reg.strings) == "table"
            and type(reg.strings[wowLocale]) == "table"
        if not hasLocale then
            local fmt = L.STATUS_NO_TRANSLATION_FMT
                     or "No translation available for %s. Consider contributing!"
            banner._label:SetJustifyH("CENTER")
            banner._label:SetText(string.format(fmt, wowLocale))
            banner._label:SetTextColor(0.9, 0.7, 0.3, 1)
        else
            local txt = L.STATUS_TRANSLATION_NOTICE
                     or "This is a translation of the English guide. Notice any issues? Consider contributing!"
            banner._label:SetJustifyH("CENTER")
            banner._label:SetText(txt)
            banner._label:SetTextColor(0.65, 0.65, 0.65, 0.8)
        end
        return
    end

    -- Default: attribution credit (right-aligned).
    banner._label:SetJustifyH("RIGHT")
    banner._label:SetText("Built by Dev \xE2\x80\xA2 Approved by Larias")
    banner._label:SetTextColor(0.45, 0.45, 0.45, 0.8)
end

-- ── Addon:ApplyScaleSliderVisibility ─────────────────────────────────────────
-- Shows or hides the scale/opacity slider panes and re-anchors all bottom-row
-- elements (tracking panel, char-picker button) accordingly.
function Addon:ApplyScaleSliderVisibility()
    local sf = self._inFrameScaleSlider
    if not sf then return end
    local db           = self:EnsureDB()
    local scaleShown   = db.showScaleSlider   ~= false
    local opacityShown = db.showOpacitySlider ~= false
    local anySlider    = scaleShown or opacityShown

    if sf._scalePane   then sf._scalePane:SetShown(scaleShown)     end
    if sf._opacityPane then sf._opacityPane:SetShown(opacityShown) end
    if sf._layout      then sf._layout() end
    sf:SetShown(anySlider)

    -- The banner always reserves its space; include it in offset calculations.
    local bannerExtra = self._statusBanner
        and ((self._statusBannerH or BANNER_H) + (self._statusBannerPad or BANNER_PAD))
        or 0
    sf._bannerBotExtra = bannerExtra

    if sf.AdjustForCpBtn then sf.AdjustForCpBtn(nil) end

    -- Determine whether the char-picker button is visible in the bottom row.
    local featureOn = (self.FEATURE_FLAGS and self.FEATURE_FLAGS.ENABLE_CHAR_SELECTOR) ~= false
    local hasChars  = featureOn and (self.HasPickableChars and self:HasPickableChars())
    local cpVisible = featureOn and hasChars and (db.showCharPickerBtn ~= false)

    local cpBtnRef = self._mainFrame and self._mainFrame._lariasCharPickerBtn
    if cpBtnRef and cpBtnRef.IsShown and cpBtnRef:IsShown() then
        local _cpY = (Addon.UI.sliderBottomPad or 4) + bannerExtra
        if anySlider then _cpY = _cpY + (sf:GetHeight() or 36) + 4 end
        cpBtnRef:ClearAllPoints()
        cpBtnRef:SetPoint("BOTTOMRIGHT", self._mainFrame, "BOTTOMRIGHT",
            -(Addon.UI.sectionInsetX or 14), _cpY)
    end

    -- Re-anchor the tracking panel above the slider/banner row.
    local tf = self._trackingFrame
    if tf then
        local inset     = Addon.UI.sectionInsetX or 14
        local botPad    = (Addon.UI.sliderBottomPad or 4) + bannerExtra
        local topPad    = Addon.UI.sliderTopPad    or 4
        local sliderTot = (Addon.UI.sliderH or 20) + (Addon.UI.sliderLabelH or 14) + 2
        local botY
        if anySlider and cpVisible then
            botY = botPad + sliderTot + 4 + 22 + topPad
        elseif anySlider then
            botY = botPad + sliderTot + topPad
        elseif cpVisible then
            botY = botPad + 22 + topPad
        else
            botY = botPad
        end
        tf:ClearAllPoints()
        tf:SetPoint("BOTTOMLEFT",  tf:GetParent(), "BOTTOMLEFT",  inset,  botY)
        tf:SetPoint("BOTTOMRIGHT", tf:GetParent(), "BOTTOMRIGHT", -inset, botY)
    end
    if self.ApplyScrollLayout then self:ApplyScrollLayout() end
end

-- ── Addon:ApplyOpacity ────────────────────────────────────────────────────────
-- Sets the background texture alpha from the saved opacity percentage.
-- Drives only the dedicated bg texture so child widgets remain fully opaque.
function Addon:ApplyOpacity()
    local pct   = (self.db and self.db.global and tonumber(self.db.global.uiOpacityPct)) or 65
    local alpha = math.max(0, math.min(1.0, pct / 100))
    local mf    = self._mainFrame
    if mf and mf._lariaBgTex then
        mf._lariaBgTex:SetAlpha(alpha)
    end
    local sf = self._inFrameScaleSlider
    if sf and sf.SyncOpacity then sf.SyncOpacity() end
end
