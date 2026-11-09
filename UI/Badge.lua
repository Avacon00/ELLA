local AddonName, ns = ...

local L = ns.L
local Registry = ns.Registry
local Engine = ns.Engine

local BadgeUI = {}
ns.BadgeUI = BadgeUI

-- Map of windowId -> badge button (all parented to UIParent, NEVER to Blizzard frames!)
local badgesByWindow = {}
local popover = nil

local BACKDROP_TEMPLATE = _G.BackdropTemplateMixin and "BackdropTemplate" or nil

-- Strata hierarchy so badges render above HIGH NineSlice/TitleContainer chrome,
-- while remaining cleanly underneath DIALOG / FULLSCREEN_DIALOG / TOOLTIP windows.
local STRATA_RANK = {
    BACKGROUND = 1,
    LOW = 2,
    MEDIUM = 3,
    HIGH = 4,
    DIALOG = 5,
    FULLSCREEN = 6,
    FULLSCREEN_DIALOG = 7,
    TOOLTIP = 8,
}
local RANK_TO_STRATA = {
    "BACKGROUND",
    "LOW",
    "MEDIUM",
    "HIGH",
    "DIALOG",
    "FULLSCREEN",
    "FULLSCREEN_DIALOG",
    "TOOLTIP",
}

local function ApplyPillBackdrop(frame, bgAlpha, borderR, borderG, borderB)
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 8,
            edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        frame:SetBackdropColor(0.08, 0.09, 0.12, bgAlpha or 0.90)
        frame:SetBackdropBorderColor(borderR or 0.78, borderG or 0.65, borderB or 0.25, 0.95)
    end
end

-- ============================================================================
-- Shared Quick Popover (Slider + Lock + Scale-Only Toggle)
-- ============================================================================
local function AttachTooltip(widget, titleKey, bodyKey)
    widget:SetScript("OnEnter", function(self)
        if _G.GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(L[titleKey], 1, 0.82, 0)
            GameTooltip:AddLine(L[bodyKey], 0.9, 0.9, 0.9, true)
            GameTooltip:Show()
        end
    end)
    widget:SetScript("OnLeave", function()
        if _G.GameTooltip then
            GameTooltip:Hide()
        end
    end)
end

local function GetOrCreatePopover()
    if popover then
        return popover
    end

    local p = CreateFrame("Frame", "EllaBadgePopover", UIParent, BACKDROP_TEMPLATE)
    p:SetSize(304, 246)
    p:SetFrameStrata("DIALOG")
    p:SetFrameLevel(220)
    p:EnableMouse(true)
    p:EnableMouseWheel(true)
    p:SetMovable(true)
    p:RegisterForDrag("LeftButton")
    p:SetClampedToScreen(true)
    ApplyPillBackdrop(p, 0.97, 0.85, 0.70, 0.28)
    p:SetScript("OnDragStart", p.StartMoving)
    p:SetScript("OnDragStop", p.StopMovingOrSizing)
    p:Hide()
    if _G.UISpecialFrames then
        table.insert(_G.UISpecialFrames, "EllaBadgePopover")
    end

    local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetPoint("TOPRIGHT", -28, -10)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    p.title = title

    local closeBtn = CreateFrame("Button", nil, p, "UIPanelCloseButton")
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function()
        ns:PlaySound("CLICK")
        p:Hide()
    end)

    local scaleLabel = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    scaleLabel:SetPoint("TOPLEFT", 12, -30)
    p.scaleLabel = scaleLabel

    local slider = CreateFrame("Slider", nil, p, BACKDROP_TEMPLATE)
    slider:SetSize(280, 14)
    slider:SetPoint("TOPLEFT", 12, -46)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(50, 150)
    slider:SetValueStep(1)
    slider:EnableMouseWheel(true)
    if slider.SetObeyStepOnDrag then
        slider:SetObeyStepOnDrag(true)
    end
    ApplyPillBackdrop(slider, 0.85, 0.32, 0.36, 0.46)

    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    thumb:SetSize(24, 24)
    slider:SetThumbTexture(thumb)
    slider:SetScript("OnMouseDown", function(self)
        self.isDraggingThumb = true
    end)
    slider:SetScript("OnMouseUp", function(self)
        self.isDraggingThumb = false
    end)
    slider:SetScript("OnMouseWheel", function(_, delta)
        if not p.windowId then
            return
        end
        Engine:StepWindowScale(p.windowId, delta, IsShiftKeyDown(), false)
    end)
    p.slider = slider

    slider:SetScript("OnValueChanged", function(_, value)
        if p.updating or p.inSliderCallback or not p.windowId then
            return
        end
        local pct = math.floor(value + 0.5)
        p.scaleLabel:SetText(string.format(L["POPOVER_SCALE"], pct))
        if p.lastAppliedPct == pct then
            return
        end
        p.lastAppliedPct = pct
        p.inSliderCallback = true
        Engine:SetWindowScale(p.windowId, pct / 100, false)
        p.inSliderCallback = false
    end)

    local alphaLabel = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    alphaLabel:SetPoint("TOPLEFT", 12, -66)
    p.alphaLabel = alphaLabel

    local alphaSlider = CreateFrame("Slider", nil, p, BACKDROP_TEMPLATE)
    alphaSlider:SetSize(280, 14)
    alphaSlider:SetPoint("TOPLEFT", 12, -82)
    alphaSlider:SetOrientation("HORIZONTAL")
    alphaSlider:SetMinMaxValues(30, 100)
    alphaSlider:SetValueStep(1)
    alphaSlider:EnableMouseWheel(true)
    if alphaSlider.SetObeyStepOnDrag then
        alphaSlider:SetObeyStepOnDrag(true)
    end
    ApplyPillBackdrop(alphaSlider, 0.85, 0.32, 0.36, 0.46)

    local aThumb = alphaSlider:CreateTexture(nil, "OVERLAY")
    aThumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    aThumb:SetSize(24, 24)
    alphaSlider:SetThumbTexture(aThumb)
    alphaSlider:SetScript("OnMouseDown", function(self)
        self.isDraggingThumb = true
    end)
    alphaSlider:SetScript("OnMouseUp", function(self)
        self.isDraggingThumb = false
    end)
    alphaSlider:SetScript("OnMouseWheel", function(_, delta)
        if not p.windowId then
            return
        end
        local cfg = ns:GetWindowConfig(p.windowId, true)
        local curA = cfg.alpha or 1.00
        local step = IsShiftKeyDown() and 0.01 or 0.05
        Engine:SetWindowAlpha(p.windowId, curA + (delta * step), nil)
    end)
    p.alphaSlider = alphaSlider

    alphaSlider:SetScript("OnValueChanged", function(_, value)
        if p.updating or p.inAlphaCallback or not p.windowId then
            return
        end
        local pct = math.floor(value + 0.5)
        p.alphaLabel:SetText(string.format(L["POPOVER_ALPHA"], pct))
        if p.lastAppliedAlphaPct == pct then
            return
        end
        p.lastAppliedAlphaPct = pct
        p.inAlphaCallback = true
        Engine:SetWindowAlpha(p.windowId, pct / 100, nil)
        p.inAlphaCallback = false
    end)

    p:SetScript("OnMouseWheel", function(_, delta)
        if not p.windowId then
            return
        end
        Engine:StepWindowScale(p.windowId, delta, IsShiftKeyDown(), false)
    end)

    -- Scale-Only Checkbox
    local scaleOnlyChk = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
    scaleOnlyChk:SetSize(22, 22)
    scaleOnlyChk:SetPoint("TOPLEFT", 10, -104)
    scaleOnlyChk:SetHitRectInsets(0, -210, 0, 0)
    local soText = scaleOnlyChk:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    soText:SetPoint("LEFT", scaleOnlyChk, "RIGHT", 4, 0)
    soText:SetText(L["POPOVER_SCALE_ONLY"])
    p.scaleOnlyChk = scaleOnlyChk

    scaleOnlyChk:SetScript("OnClick", function(self)
        if not p.windowId then
            return
        end
        ns:PlaySound("CLICK")
        local newMode = self:GetChecked() and ns.MODE_SCALE_ONLY or ns.MODE_SCALE_MOVE
        Engine:SetWindowMode(p.windowId, newMode)
    end)
    AttachTooltip(scaleOnlyChk, "POPOVER_SCALE_ONLY", "POPOVER_SCALE_ONLY_TIP")

    -- Mouseover Fade Checkbox
    local fadeChk = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
    fadeChk:SetSize(22, 22)
    fadeChk:SetPoint("TOPLEFT", 10, -126)
    fadeChk:SetHitRectInsets(0, -210, 0, 0)
    local fadeText = fadeChk:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fadeText:SetPoint("LEFT", fadeChk, "RIGHT", 4, 0)
    fadeText:SetText(L["POPOVER_MOUSEOVER_FADE"])
    p.fadeChk = fadeChk

    fadeChk:SetScript("OnClick", function(self)
        if not p.windowId then
            return
        end
        ns:PlaySound("CLICK")
        Engine:SetWindowAlpha(p.windowId, nil, self:GetChecked() and true or false)
    end)
    AttachTooltip(fadeChk, "POPOVER_MOUSEOVER_FADE", "POPOVER_MOUSEOVER_FADE_TIP")

    -- Lock Position Checkbox
    local lockChk = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
    lockChk:SetSize(22, 22)
    lockChk:SetPoint("TOPLEFT", 10, -148)
    lockChk:SetHitRectInsets(0, -210, 0, 0)
    local lockText = lockChk:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lockText:SetPoint("LEFT", lockChk, "RIGHT", 4, 0)
    lockText:SetText(L["POPOVER_LOCK_POS"])
    p.lockChk = lockChk

    lockChk:SetScript("OnClick", function(self)
        if not p.windowId then
            return
        end
        ns:PlaySound("CLICK")
        local cfg = ns:GetWindowConfig(p.windowId, true)
        cfg.locked = self:GetChecked() and true or false
        ns:Fire("OnWindowConfigChanged", p.windowId, cfg)
    end)
    AttachTooltip(lockChk, "POPOVER_LOCK_POS", "POPOVER_LOCK_POS_TIP")

    -- Per-Window Show %-Badge Checkbox
    local showBadgeChk = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
    showBadgeChk:SetSize(22, 22)
    showBadgeChk:SetPoint("TOPLEFT", 10, -170)
    showBadgeChk:SetHitRectInsets(0, -220, 0, 0)
    local sbText = showBadgeChk:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sbText:SetPoint("LEFT", showBadgeChk, "RIGHT", 4, 0)
    sbText:SetText(L["POPOVER_SHOW_BADGE"])
    p.showBadgeChk = showBadgeChk

    showBadgeChk:SetScript("OnClick", function(self)
        if not p.windowId then
            return
        end
        ns:PlaySound("CLICK")
        local hideIt = not self:GetChecked()
        Engine:SetWindowBadgeHidden(p.windowId, hideIt)
        if hideIt then
            local desc = Registry:GetDescriptor(p.windowId)
            ns:Print(string.format(L["MSG_BADGE_HIDDEN_WIN"], Registry:GetDisplayLabel(desc)))
        end
    end)
    AttachTooltip(showBadgeChk, "POPOVER_SHOW_BADGE", "POPOVER_SHOW_BADGE_TIP")

    -- Bottom Action Buttons: [Zurück / Undo] [100% Reset] [Pos. Reset]
    local function ApplySmallBtnFont(btn)
        if btn.SetNormalFontObject then
            btn:SetNormalFontObject("GameFontNormalSmall")
            btn:SetHighlightFontObject("GameFontHighlightSmall")
            btn:SetDisabledFontObject("GameFontDisableSmall")
        end
    end

    local undoBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    undoBtn:SetSize(88, 22)
    undoBtn:SetPoint("BOTTOMLEFT", 12, 12)
    ApplySmallBtnFont(undoBtn)
    undoBtn:SetText(L["POPOVER_UNDO"])
    undoBtn:SetScript("OnClick", function()
        ns:PlaySound("CLICK")
        if p.windowId and ns.Profiles and ns.Profiles.RestoreWindowToSavedOrUndo then
            ns.Profiles:RestoreWindowToSavedOrUndo(p.windowId)
        end
    end)
    AttachTooltip(undoBtn, "POPOVER_UNDO", "POPOVER_UNDO_TIP")
    p.undoBtn = undoBtn

    local resetScaleBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    resetScaleBtn:SetSize(88, 22)
    resetScaleBtn:SetPoint("BOTTOM", 0, 12)
    ApplySmallBtnFont(resetScaleBtn)
    resetScaleBtn:SetText(L["POPOVER_RESET_SCALE"])
    resetScaleBtn:SetScript("OnClick", function()
        ns:PlaySound("CLICK")
        if p.windowId then
            Engine:SetWindowScale(p.windowId, 1.00, false)
            Engine:SetWindowAlpha(p.windowId, 1.00, false)
        end
    end)
    AttachTooltip(resetScaleBtn, "POPOVER_RESET_SCALE", "POPOVER_RESET_SCALE_TIP")

    local resetPosBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    resetPosBtn:SetSize(88, 22)
    resetPosBtn:SetPoint("BOTTOMRIGHT", -12, 12)
    ApplySmallBtnFont(resetPosBtn)
    resetPosBtn:SetText(L["POPOVER_RESET_POS"])
    resetPosBtn:SetScript("OnClick", function()
        ns:PlaySound("CLICK")
        if p.windowId then
            Engine:ResetWindow(p.windowId, true)
        end
    end)
    AttachTooltip(resetPosBtn, "POPOVER_RESET_POS", "POPOVER_RESET_POS_TIP")

    popover = p
    return p
end

local function RefreshPopover()
    if not popover or not popover:IsShown() or not popover.windowId then
        return
    end
    local desc = Registry:GetDescriptor(popover.windowId)
    local cfg = ns:GetWindowConfig(popover.windowId, true)
    local effScale, savedScale, isCapped = Engine:GetEffectiveWindowScale(popover.windowId, desc)
    local pct = math.floor(savedScale * 100 + 0.5)
    local effPct = math.floor(effScale * 100 + 0.5)
    local aVal = (cfg.alpha ~= nil) and math.floor(cfg.alpha * 100 + 0.5) or 100

    popover.updating = true
    popover.lastAppliedPct = pct
    popover.lastAppliedAlphaPct = aVal
    popover.title:SetText(Registry:GetDisplayLabel(desc))
    if isCapped then
        popover.scaleLabel:SetText(string.format(L["POPOVER_SCALE"], effPct) .. " |cff00d8ff(" .. pct .. "%)|r")
    else
        popover.scaleLabel:SetText(string.format(L["POPOVER_SCALE"], pct))
    end
    -- Avoid fighting the user's mouse while the slider is actively firing OnValueChanged
    if not popover.inSliderCallback and not popover.slider.isDraggingThumb then
        popover.slider:SetValue(pct)
    end
    popover.alphaLabel:SetText(string.format(L["POPOVER_ALPHA"], aVal))
    if not popover.inAlphaCallback and not popover.alphaSlider.isDraggingThumb then
        popover.alphaSlider:SetValue(aVal)
    end
    local effMode = Engine:GetEffectiveWindowMode(popover.windowId, desc)
    popover.scaleOnlyChk:SetChecked(effMode == ns.MODE_SCALE_ONLY)
    popover.fadeChk:SetChecked(cfg.mouseoverFade and true or false)
    popover.lockChk:SetChecked(cfg.locked and true or false)
    if popover.showBadgeChk then
        popover.showBadgeChk:SetChecked(not (cfg.hideBadge == true))
    end
    popover.updating = false
end

local function AnchorPopoverNearBadge(p, badge)
    p:ClearAllPoints()
    if not badge or not badge:IsShown() then
        p:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
        return
    end

    -- Anchor popover to fixed UIParent coordinates (NOT to the moving badge!)
    -- with smart horizontal/vertical edge-flip so it never covers the badge.
    local uipScale = UIParent:GetEffectiveScale() or 1
    local bScale = badge:GetEffectiveScale() or uipScale
    local ratio = bScale / uipScale
    local uipW = UIParent:GetWidth() or 1920
    local uipH = UIParent:GetHeight() or 1080
    local popW = p:GetWidth() or 304
    local popH = p:GetHeight() or 246

    local bLeft = (badge:GetLeft() or 400) * ratio
    local bRight = (badge:GetRight() or 444) * ratio
    local bTop = (badge:GetTop() or 420) * ratio
    local bBottom = (badge:GetBottom() or 400) * ratio

    local targetLeft = bRight - popW
    if targetLeft < 12 then
        targetLeft = math.min(bLeft, uipW - popW - 12)
    end
    if (targetLeft + popW) > (uipW - 12) then
        targetLeft = uipW - popW - 12
    end

    local targetTop = bBottom - 4
    if (targetTop - popH) < 12 then
        targetTop = math.min(bTop + popH + 4, uipH - 12)
    end

    p:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", targetLeft, targetTop)
end

local function TogglePopoverForBadge(windowId, badge)
    local p = GetOrCreatePopover()
    ns:PlaySound("CLICK")
    if p:IsShown() and p.windowId == windowId then
        p:Hide()
        return
    end
    p.windowId = windowId
    AnchorPopoverNearBadge(p, badge)
    p:Show()
    RefreshPopover()
end

-- ============================================================================
-- Per-Window Titlebar Pill Badge
-- ============================================================================
local function UpdateBadgeVisual(windowId, badge)
    local desc = Registry:GetDescriptor(windowId)
    if not desc or not desc.boundFrame then
        badge:Hide()
        return
    end
    if not ns.db or not ns.db.settings.enabled or not ns.db.settings.showBadges or not desc.boundFrame:IsShown() then
        badge:Hide()
        return
    end
    local effMode = Engine:GetEffectiveWindowMode(windowId, desc)
    local cfg = ns:GetWindowConfig(windowId, false)
    if effMode == ns.MODE_DISABLED or (cfg and cfg.hideBadge) then
        badge:Hide()
        return
    end

    local effScale, _, isCapped = Engine:GetEffectiveWindowScale(windowId, desc)
    local pct = math.floor(effScale * 100 + 0.5)

    badge.text:SetText(pct .. "%")
    if isCapped then
        badge.text:SetTextColor(0.20, 0.92, 1.0)
        ApplyPillBackdrop(badge, 0.92, 0.0, 0.82, 1.0)
    elseif math.abs(effScale - 1.00) > 0.005 then
        badge.text:SetTextColor(1.0, 0.84, 0.15)
        ApplyPillBackdrop(badge, 0.92, 0.90, 0.72, 0.20)
    else
        badge.text:SetTextColor(0.80, 0.82, 0.86)
        ApplyPillBackdrop(badge, 0.82, 0.45, 0.45, 0.52)
    end

    local target = desc.boundFrame
    local nineSlice = rawget(target, "NineSlice")
    local titleContainer = rawget(target, "TitleContainer")
    local closeBtn = rawget(target, "CloseButton") or _G[(target:GetName() or "") .. "CloseButton"]

    local maxRank = math.max(
        STRATA_RANK[target:GetFrameStrata() or "MEDIUM"] or 3,
        STRATA_RANK["HIGH"],
        (type(nineSlice) == "table" and nineSlice.GetFrameStrata and STRATA_RANK[nineSlice:GetFrameStrata() or ""]) or 0,
        (type(titleContainer) == "table" and titleContainer.GetFrameStrata and STRATA_RANK[titleContainer:GetFrameStrata() or ""]) or 0,
        (type(closeBtn) == "table" and closeBtn.GetFrameStrata and STRATA_RANK[closeBtn:GetFrameStrata() or ""]) or 0
    )

    local baseLevel = target:GetFrameLevel() or 10
    local nineSliceLevel = (type(nineSlice) == "table" and nineSlice.GetFrameLevel and nineSlice:GetFrameLevel()) or 0
    local titleLevel = (type(titleContainer) == "table" and titleContainer.GetFrameLevel and titleContainer:GetFrameLevel()) or 0
    local closeLevel = (type(closeBtn) == "table" and closeBtn.GetFrameLevel and closeBtn:GetFrameLevel()) or 0
    local topLevel = math.max(baseLevel + 550, nineSliceLevel + 25, titleLevel + 25, closeLevel + 15)

    -- A detached badge for a frameless window should not float over unrelated panels.
    local hasChrome = type(nineSlice) == "table" or type(titleContainer) == "table" or type(closeBtn) == "table"
    if hasChrome or desc.hasExplicitBadgeOffset then
        badge:SetFrameStrata(RANK_TO_STRATA[maxRank] or "HIGH")
        badge:SetFrameLevel(math.min(topLevel, 9000))
    else
        badge:SetFrameStrata(target:GetFrameStrata() or "MEDIUM")
        badge:SetFrameLevel(baseLevel + 1)
    end
    badge:ClearAllPoints()
    if type(closeBtn) == "table" and not ns.Guard:IsForbidden(closeBtn) then
        badge:SetPoint("RIGHT", closeBtn, "LEFT", -28, 0)
    elseif desc.hasExplicitBadgeOffset or type(nineSlice) == "table" or type(titleContainer) == "table" then
        badge:SetPoint("TOPRIGHT", target, "TOPRIGHT", desc.badgeOffsetX or -28, desc.badgeOffsetY or -5)
    else
        -- Frameless / compact third-party AddOns (e.g. Auto Heal, TomTom):
        -- Place badge cleanly outside the top-right edge so it never covers clickable frame contents!
        local uipH = UIParent:GetHeight() or 1080
        local tTop = (target:GetTop() or 0) * (target:GetScale() or 1)
        if tTop > (uipH - 24) then
            badge:SetPoint("TOPRIGHT", target, "BOTTOMRIGHT", -2, -2)
        else
            badge:SetPoint("BOTTOMRIGHT", target, "TOPRIGHT", -2, 2)
        end
    end
    badge:Show()
end

local function GetOrCreateBadge(windowId)
    local existing = badgesByWindow[windowId]
    if existing then
        return existing
    end

    local btn = CreateFrame("Button", nil, UIParent, BACKDROP_TEMPLATE)
    btn:SetSize(44, 18)
    btn:EnableMouse(true)
    btn:EnableMouseWheel(true)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
    ApplyPillBackdrop(btn, 0.88, 0.75, 0.62, 0.24)
    btn:Hide()

    local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    txt:SetPoint("CENTER", 0, 0)
    txt:SetText("100%")
    btn.text = txt

    btn:SetScript("OnEnter", function(self)
        ApplyPillBackdrop(self, 0.98, 1.0, 0.86, 0.35)
        local desc = Registry:GetDescriptor(windowId)
        local cfg = ns:GetWindowConfig(windowId, false)
        local effScale, savedScale, isCapped = Engine:GetEffectiveWindowScale(windowId, desc)
        local effPct = math.floor(effScale * 100 + 0.5)
        local savedPct = math.floor(savedScale * 100 + 0.5)
        if _G.GameTooltip then
            local uipScale = UIParent:GetEffectiveScale() or 1
            local effS = self:GetEffectiveScale() or uipScale
            local cx = ((self:GetCenter() or 0) * effS) / uipScale
            local tipAnchor = (cx < 340) and "ANCHOR_BOTTOMRIGHT" or "ANCHOR_BOTTOMLEFT"
            GameTooltip:SetOwner(self, tipAnchor)
            GameTooltip:AddLine(string.format(L["BADGE_TOOLTIP_TITLE"], Registry:GetDisplayLabel(desc), effPct), 1, 0.82, 0)
            if isCapped then
                GameTooltip:AddLine(string.format(L["UI_COMPACT_CAP_HINT"], savedPct), 0.20, 0.90, 1.0)
            end
            GameTooltip:AddLine((cfg and cfg.locked) and L["BADGE_LOCKED"] or L["BADGE_UNLOCKED"], 0.85, 0.85, 0.85)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L["BADGE_TOOLTIP_SCROLL"], 0.9, 0.9, 0.9)
            GameTooltip:AddLine(L["BADGE_TOOLTIP_LCLICK"], 0.9, 0.9, 0.9)
            GameTooltip:AddLine(L["BADGE_TOOLTIP_RCLICK"], 0.9, 0.9, 0.9)
            GameTooltip:AddLine(L["BADGE_TOOLTIP_SRCLICK"], 0.9, 0.9, 0.9)
            GameTooltip:AddLine(L["BADGE_TOOLTIP_ALTCLICK"], 0.95, 0.65, 0.65)
            GameTooltip:Show()
        end
    end)

    btn:SetScript("OnLeave", function(self)
        if _G.GameTooltip then
            GameTooltip:Hide()
        end
        UpdateBadgeVisual(windowId, self)
    end)

    btn:SetScript("OnMouseWheel", function(_, delta)
        Engine:StepWindowScale(windowId, delta, IsShiftKeyDown(), true)
    end)

    btn:SetScript("OnClick", function(self, mouseButton)
        if IsAltKeyDown() or mouseButton == "MiddleButton" then
            ns:PlaySound("CLICK")
            if _G.GameTooltip then
                GameTooltip:Hide()
            end
            if popover and popover:IsShown() and popover.windowId == windowId then
                popover:Hide()
            end
            Engine:SetWindowBadgeHidden(windowId, true)
            local desc = Registry:GetDescriptor(windowId)
            ns:Print(string.format(L["MSG_BADGE_HIDDEN_WIN"], Registry:GetDisplayLabel(desc)))
            return
        end
        if mouseButton == "LeftButton" then
            TogglePopoverForBadge(windowId, self)
        elseif mouseButton == "RightButton" then
            ns:PlaySound("CLICK")
            if IsShiftKeyDown() then
                Engine:ResetWindow(windowId, true)
            else
                Engine:SetWindowScale(windowId, 1.00, true)
            end
        end
    end)

    badgesByWindow[windowId] = btn
    return btn
end

function BadgeUI:RefreshAll()
    for windowId, desc in Registry:IterateWindows() do
        if desc.boundFrame and desc.boundFrame:IsShown() then
            local b = GetOrCreateBadge(windowId)
            UpdateBadgeVisual(windowId, b)
        elseif badgesByWindow[windowId] then
            badgesByWindow[windowId]:Hide()
        end
    end
    if popover and popover:IsShown() and (not ns.db or not ns.db.settings.enabled) then
        popover:Hide()
    else
        RefreshPopover()
    end
end

function BadgeUI:OpenPopoverForWindow(windowId)
    local p = GetOrCreatePopover()
    p.windowId = windowId
    local badge = badgesByWindow[windowId]
    AnchorPopoverNearBadge(p, badge)
    p:Show()
    RefreshPopover()
end

function BadgeUI:HideWindowBadge(windowId)
    local b = badgesByWindow[windowId]
    if b then
        b:Hide()
    end
    if popover and popover.windowId == windowId then
        popover:Hide()
    end
end

ns:On("OnWindowUnregistered", function(windowId)
    BadgeUI:HideWindowBadge(windowId)
end)

ns:On("OnManagedFrameShown", function(windowId)
    local b = GetOrCreateBadge(windowId)
    UpdateBadgeVisual(windowId, b)
end)

ns:On("OnManagedFrameHidden", function(windowId)
    local b = badgesByWindow[windowId]
    if b then
        b:Hide()
    end
    if popover and popover.windowId == windowId then
        popover:Hide()
    end
end)

ns:On("OnWindowDragStarted", function()
    if popover and popover:IsShown() then
        popover:Hide()
    end
end)

ns:On("OnWindowApplied", function(windowId)
    local b = badgesByWindow[windowId]
    if b then
        UpdateBadgeVisual(windowId, b)
    end
    RefreshPopover()
end)

ns:On("OnWindowConfigChanged", function(windowId)
    local b = badgesByWindow[windowId]
    if b then
        UpdateBadgeVisual(windowId, b)
    end
    RefreshPopover()
end)

ns:On("OnPresetApplied", function()
    BadgeUI:RefreshAll()
end)

ns:On("OnProfileSwitched", function()
    BadgeUI:RefreshAll()
end)

ns:On("OnProfileImported", function()
    BadgeUI:RefreshAll()
end)

ns:On("OnInstanceCompactChanged", function()
    BadgeUI:RefreshAll()
end)

ns:On("OnResetAll", function()
    BadgeUI:RefreshAll()
end)

ns:On("OnPlayerLogin", function()
    BadgeUI:RefreshAll()
end)
