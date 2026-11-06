local AddonName, ns = ...

local L = ns.L

local Tutorial = {
    active = false,
    currentStep = 0,
    TOTAL_STEPS = 13,
}
ns.Tutorial = Tutorial

local BACKDROP_TEMPLATE = _G.BackdropTemplateMixin and "BackdropTemplate" or nil
local ICON_PATH = "Interface\\AddOns\\ELLA\\Media\\Icon"

local promptDialog = nil
local dimmerFrame = nil
local spotlightBox = nil
local cardFrame = nil

local function StyleBox(frame, bgR, bgG, bgB, alpha, borderR, borderG, borderB)
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 8,
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        frame:SetBackdropColor(bgR or 0.06, bgG or 0.07, bgB or 0.10, alpha or 0.96)
        frame:SetBackdropBorderColor(borderR or 0.78, borderG or 0.65, borderB or 0.25, 0.95)
    end
end

local function ApplyCompactButtonFont(btn)
    if btn.SetNormalFontObject then
        btn:SetNormalFontObject("GameFontNormalSmall")
        btn:SetHighlightFontObject("GameFontHighlightSmall")
        btn:SetDisabledFontObject("GameFontDisableSmall")
    end
end

-- ============================================================================
-- 1. Opt-In Prompt Dialog ("Kleines Tutorial gefällig?")
-- ============================================================================
local function EnsurePromptDialog()
    if promptDialog then
        return promptDialog
    end

    local f = CreateFrame("Frame", nil, UIParent, BACKDROP_TEMPLATE)
    f:SetSize(450, 210)
    f:SetPoint("CENTER", 0, 40)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    StyleBox(f, 0.05, 0.06, 0.09, 0.98, 0.88, 0.72, 0.25)
    f:Hide()

    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetSize(28, 28)
    icon:SetPoint("TOPLEFT", 18, -14)
    icon:SetTexture(ICON_PATH)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", icon, "RIGHT", 10, 0)
    title:SetText(L["TUTORIAL_PROMPT_TITLE"])

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function()
        ns.db.settings.tutorialPromptShown = true
        f:Hide()
    end)

    local body = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    body:SetPoint("TOPLEFT", 18, -52)
    body:SetPoint("TOPRIGHT", -18, -52)
    body:SetJustifyH("LEFT")
    body:SetSpacing(4)
    body:SetText(L["TUTORIAL_PROMPT_BODY"])

    local startBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    startBtn:SetSize(210, 28)
    startBtn:SetPoint("BOTTOMLEFT", 18, 16)
    startBtn:SetText(L["TUTORIAL_PROMPT_START"])
    startBtn:SetScript("OnClick", function()
        f:Hide()
        Tutorial:Start(1)
    end)

    local laterBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    laterBtn:SetSize(180, 28)
    laterBtn:SetPoint("BOTTOMRIGHT", -18, 16)
    laterBtn:SetText(L["TUTORIAL_PROMPT_LATER"])
    laterBtn:SetScript("OnClick", function()
        ns.db.settings.tutorialPromptShown = true
        f:Hide()
    end)

    promptDialog = f
    return f
end

function Tutorial:PromptIfFirstOpen()
    if not ns.db or ns.db.settings.tutorialPromptShown then
        return
    end
    if _G.InCombatLockdown and _G.InCombatLockdown() then
        return
    end
    local p = EnsurePromptDialog()
    p:Show()
end

-- ============================================================================
-- 2. Spotlight Dimmer & Callout Card
-- ============================================================================
local userMovedCard = false

local function PositionCard(target)
    if not cardFrame then
        return
    end

    cardFrame:ClearAllPoints()
    local mf = ns.ManagerUI and ns.ManagerUI.GetFrame and ns.ManagerUI:GetFrame()
    if not mf or not mf:IsShown() then
        cardFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -20)
        return
    end

    local uipScale = UIParent:GetEffectiveScale() or 1.0
    local mfScale = mf:GetEffectiveScale() or 1.0
    local scaleRatio = mfScale / uipScale

    local uipW = UIParent:GetWidth() or 1920
    local mfRightUIP = (mf:GetRight() or 0) * scaleRatio
    local mfLeftUIP = (mf:GetLeft() or 0) * scaleRatio
    local cardW = cardFrame:GetWidth() or 390

    -- 1) Prefer side-docking when screen space allows (1080p, 1440p, 4K)
    if (uipW - mfRightUIP) >= (cardW + 20) then
        cardFrame:SetPoint("LEFT", mf, "RIGHT", 14, 0)
        return
    end

    if mfLeftUIP >= (cardW + 20) then
        cardFrame:SetPoint("RIGHT", mf, "LEFT", -14, 0)
        return
    end

    -- 2) Narrow screen fallback (e.g. 1024x576 or 1280x720)
    -- Position card opposite to the highlighted target so it NEVER covers it
    if target then
        local tFrame = target.tl or target
        local tTop = (tFrame.GetTop and tFrame:GetTop()) or 0
        local mfTop = (mf.GetTop and mf:GetTop()) or 0
        local mfHeight = (mf.GetHeight and mf:GetHeight()) or 520
        local relY = mfTop - tTop
        -- If target is in the upper 45% of manager, dock card to BOTTOM
        if relY < (mfHeight * 0.45) then
            cardFrame:SetPoint("BOTTOM", mf, "BOTTOM", 0, 14)
            return
        else
            -- Target is in the lower half, dock card near TOP
            cardFrame:SetPoint("TOP", mf, "TOP", 0, -32)
            return
        end
    end

    cardFrame:SetPoint("BOTTOM", mf, "BOTTOM", 0, 14)
end

local function EnsureTutorialFrames()
    if cardFrame then
        return
    end

    -- Semi-transparent screen dimmer on strata "HIGH"
    -- This dims the 3D world, chat, actionbars and minimap,
    -- but leaves Ella Manager (strata "DIALOG") 100% bright, crisp and vibrant!
    dimmerFrame = CreateFrame("Frame", "EllaTutorialDimmer", UIParent)
    dimmerFrame:SetAllPoints(UIParent)
    dimmerFrame:SetFrameStrata("HIGH")
    dimmerFrame:SetFrameLevel(50)
    dimmerFrame:EnableMouse(true)
    dimmerFrame:SetScript("OnMouseDown", function()
        -- Absorb background clicks so user doesn't accidentally click the 3D world during the tour
    end)
    dimmerFrame:Hide()

    local dimTex = dimmerFrame:CreateTexture(nil, "BACKGROUND")
    dimTex:SetAllPoints(dimmerFrame)
    dimTex:SetColorTexture(0.01, 0.02, 0.04, 0.50)

    -- Glowing spotlight border around highlighted elements
    local mf = ns.ManagerUI and ns.ManagerUI.GetFrame and ns.ManagerUI:GetFrame()
    spotlightBox = CreateFrame("Frame", "EllaTutorialSpotlight", mf or UIParent, BACKDROP_TEMPLATE)
    spotlightBox:SetFrameStrata("DIALOG")
    spotlightBox:SetFrameLevel(250)
    spotlightBox:EnableMouse(false)
    if spotlightBox.SetBackdrop then
        spotlightBox:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 8,
            edgeSize = 14,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        spotlightBox:SetBackdropColor(0.0, 0.85, 1.0, 0.08)
        spotlightBox:SetBackdropBorderColor(0.0, 0.90, 1.0, 0.95)
    end
    spotlightBox:Hide()

    -- Interactive Tutorial Card (Draggable Callout)
    local c = CreateFrame("Frame", "EllaTutorialCard", UIParent, BACKDROP_TEMPLATE)
    c:SetSize(400, 195)
    c:SetPoint("CENTER", 0, -40)
    c:SetFrameStrata("FULLSCREEN_DIALOG")
    c:SetFrameLevel(200)
    c:EnableMouse(true)
    c:SetMovable(true)
    c:RegisterForDrag("LeftButton")
    c:SetClampedToScreen(true)
    StyleBox(c, 0.05, 0.06, 0.09, 0.98, 0.90, 0.74, 0.28)
    c:SetScript("OnDragStart", c.StartMoving)
    c:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        userMovedCard = true
    end)
    c:SetScript("OnHide", function()
        if Tutorial.active then
            Tutorial:Stop()
        end
    end)
    c:Hide()

    if _G.UISpecialFrames then
        table.insert(_G.UISpecialFrames, "EllaTutorialCard")
    end

    local icon = c:CreateTexture(nil, "ARTWORK")
    icon:SetSize(22, 22)
    icon:SetPoint("TOPLEFT", 12, -10)
    icon:SetTexture(ICON_PATH)

    local title = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    c.title = title

    local stepCounter = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    stepCounter:SetPoint("TOPRIGHT", -32, -12)
    stepCounter:SetTextColor(0.0, 0.85, 1.0)
    c.stepCounter = stepCounter

    local closeBtn = CreateFrame("Button", nil, c, "UIPanelCloseButton")
    closeBtn:SetSize(24, 24)
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function()
        Tutorial:Stop()
    end)

    local body = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    body:SetPoint("TOPLEFT", 12, -38)
    body:SetPoint("TOPRIGHT", -12, -38)
    body:SetJustifyH("LEFT")
    body:SetSpacing(3)
    c.body = body

    -- Navigation Buttons
    local btnPrev = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    btnPrev:SetSize(84, 22)
    btnPrev:SetPoint("BOTTOMLEFT", 12, 10)
    ApplyCompactButtonFont(btnPrev)
    btnPrev:SetText(L["TUTORIAL_BTN_PREV"])
    btnPrev:SetScript("OnClick", function()
        Tutorial:ShowStep(Tutorial.currentStep - 1)
    end)
    c.btnPrev = btnPrev

    local btnExit = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    btnExit:SetSize(130, 22)
    btnExit:SetPoint("LEFT", btnPrev, "RIGHT", 6, 0)
    ApplyCompactButtonFont(btnExit)
    btnExit:SetText(L["TUTORIAL_BTN_EXIT"])
    btnExit:SetScript("OnClick", function()
        Tutorial:Stop()
    end)
    c.btnExit = btnExit

    local btnNext = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    btnNext:SetSize(110, 22)
    btnNext:SetPoint("BOTTOMRIGHT", -12, 10)
    ApplyCompactButtonFont(btnNext)
    btnNext:SetText(L["TUTORIAL_BTN_NEXT"])
    btnNext:SetScript("OnClick", function()
        if Tutorial.currentStep >= Tutorial.TOTAL_STEPS then
            Tutorial:Stop()
        else
            Tutorial:ShowStep(Tutorial.currentStep + 1)
        end
    end)
    c.btnNext = btnNext

    cardFrame = c
end

-- ============================================================================
-- 3. Step Definitions & Target Anchoring
-- ============================================================================
-- NOTE FOR DEVELOPERS & CONTRIBUTORS:
-- When adding new major user-facing features or UI controls (e.g. presets,
-- opacity, profiles, picker upgrades), ALWAYS verify and update these 8 steps
-- and their locale strings to keep in-game onboarding perfectly synchronized!
-- ============================================================================
local STEPS = {
    [1] = {
        tab = "WINDOWS",
        titleKey = "TUTORIAL_STEP1_TITLE",
        bodyKey = "TUTORIAL_STEP1_BODY",
        getTarget = function()
            return ns.ManagerUI and ns.ManagerUI.GetFrame and ns.ManagerUI:GetFrame()
        end,
    },
    [2] = {
        tab = "WINDOWS",
        titleKey = "TUTORIAL_STEP2_TITLE",
        bodyKey = "TUTORIAL_STEP2_BODY",
        getTarget = function()
            local row = ns.ManagerUI and ns.ManagerUI.GetRow and ns.ManagerUI:GetRow(1)
            if row and row.minusBtn and (row.eyeBtn or row.resetBtn) then
                return { tl = row.minusBtn, br = (row.eyeBtn and row.eyeBtn:IsShown() and row.eyeBtn) or row.resetBtn }
            end
            local mf = ns.ManagerUI and ns.ManagerUI.GetFrame and ns.ManagerUI:GetFrame()
            return mf and mf.scrollFrame
        end,
    },
    [3] = {
        tab = "WINDOWS",
        titleKey = "TUTORIAL_STEP3_TITLE",
        bodyKey = "TUTORIAL_STEP3_BODY",
        getTarget = function()
            local row = ns.ManagerUI and ns.ManagerUI.GetRow and ns.ManagerUI:GetRow(1)
            return row and row.modeBtn
        end,
    },
    [4] = {
        tab = "WINDOWS",
        titleKey = "TUTORIAL_STEP4_TITLE",
        bodyKey = "TUTORIAL_STEP4_BODY",
        getTarget = function()
            local mf = ns.ManagerUI and ns.ManagerUI.GetFrame and ns.ManagerUI:GetFrame()
            if mf and mf.searchBox and mf.filterPills and #mf.filterPills > 0 then
                return { tl = mf.searchBox, br = mf.filterPills[#mf.filterPills] }
            end
            return mf and mf.searchBox
        end,
    },
    [5] = {
        tab = "WINDOWS",
        titleKey = "TUTORIAL_STEP5_TITLE",
        bodyKey = "TUTORIAL_STEP5_BODY",
        getTarget = function()
            local mf = ns.ManagerUI and ns.ManagerUI.GetFrame and ns.ManagerUI:GetFrame()
            return mf and mf.pickBtn
        end,
    },
    [6] = {
        tab = "WINDOWS",
        titleKey = "TUTORIAL_STEP6_TITLE",
        bodyKey = "TUTORIAL_STEP6_BODY",
        getTarget = function()
            local mf = ns.ManagerUI and ns.ManagerUI.GetFrame and ns.ManagerUI:GetFrame()
            return mf and mf.gridBtn
        end,
    },
    [7] = {
        tab = "PROFILES",
        titleKey = "TUTORIAL_STEP7_TITLE",
        bodyKey = "TUTORIAL_STEP7_BODY",
        getTarget = function()
            local mf = ns.ManagerUI and ns.ManagerUI.GetFrame and ns.ManagerUI:GetFrame()
            return mf and (mf.cardPresets or (mf.presetBtns and #mf.presetBtns > 0 and { tl = mf.presetBtns[1], br = mf.presetBtns[#mf.presetBtns] }))
        end,
    },
    [8] = {
        tab = "PROFILES",
        titleKey = "TUTORIAL_STEP8_TITLE",
        bodyKey = "TUTORIAL_STEP8_BODY",
        getTarget = function()
            local mf = ns.ManagerUI and ns.ManagerUI.GetFrame and ns.ManagerUI:GetFrame()
            return mf and (mf.cardProf or (mf.profCycleBtn and mf.chkBindChar and { tl = mf.profCycleBtn, br = mf.chkBindChar }))
        end,
    },
    [9] = {
        tab = "PROFILES",
        titleKey = "TUTORIAL_STEP9_TITLE",
        bodyKey = "TUTORIAL_STEP9_BODY",
        getTarget = function()
            local mf = ns.ManagerUI and ns.ManagerUI.GetFrame and ns.ManagerUI:GetFrame()
            return mf and (mf.cardSharing or mf.expBtn)
        end,
    },
    [10] = {
        tab = "SETTINGS",
        titleKey = "TUTORIAL_STEP10_TITLE",
        bodyKey = "TUTORIAL_STEP10_BODY",
        getTarget = function()
            local mf = ns.ManagerUI and ns.ManagerUI.GetFrame and ns.ManagerUI:GetFrame()
            return mf and (mf.cardMouse or (mf.chkCtrlWheel and mf.chkClamp and { tl = mf.chkCtrlWheel, br = mf.chkClamp }))
        end,
    },
    [11] = {
        tab = "SETTINGS",
        titleKey = "TUTORIAL_STEP11_TITLE",
        bodyKey = "TUTORIAL_STEP11_BODY",
        getTarget = function()
            local mf = ns.ManagerUI and ns.ManagerUI.GetFrame and ns.ManagerUI:GetFrame()
            return mf and (mf.cardCombat or (mf.chkCombatClose and mf.chkInstCompact and { tl = mf.chkCombatClose, br = mf.chkInstCompact }))
        end,
    },
    [12] = {
        tab = "SETTINGS",
        titleKey = "TUTORIAL_STEP12_TITLE",
        bodyKey = "TUTORIAL_STEP12_BODY",
        getTarget = function()
            local mf = ns.ManagerUI and ns.ManagerUI.GetFrame and ns.ManagerUI:GetFrame()
            return mf and (mf.cardDisplay or mf.chkBadges)
        end,
    },
    [13] = {
        tab = "WINDOWS",
        titleKey = "TUTORIAL_STEP13_TITLE",
        bodyKey = "TUTORIAL_STEP13_BODY",
        getTarget = function()
            local mf = ns.ManagerUI and ns.ManagerUI.GetFrame and ns.ManagerUI:GetFrame()
            if mf and mf.helpBtn and mf.selfScaleBtn then
                return { tl = mf.helpBtn, br = mf.selfScaleBtn }
            end
            return mf and mf.helpBtn
        end,
    },
}

function Tutorial:ShowStep(index)
    if index < 1 or index > Tutorial.TOTAL_STEPS then
        return
    end
    Tutorial.currentStep = index

    EnsureTutorialFrames()
    local s = STEPS[index]
    if not s then
        return
    end

    if s.tab and ns.ManagerUI and ns.ManagerUI.SelectTab then
        ns.ManagerUI:SelectTab(s.tab)
    end

    cardFrame.title:SetText(L[s.titleKey])
    cardFrame.body:SetText(L[s.bodyKey])
    cardFrame.stepCounter:SetText(string.format(L["TUTORIAL_STEP_COUNTER"], index, Tutorial.TOTAL_STEPS))

    cardFrame.btnPrev:SetEnabled(index > 1)
    if index == Tutorial.TOTAL_STEPS then
        cardFrame.btnNext:SetText(L["TUTORIAL_BTN_FINISH"])
    else
        cardFrame.btnNext:SetText(L["TUTORIAL_BTN_NEXT"])
    end

    local target = s.getTarget and s.getTarget()
    local mf = ns.ManagerUI and ns.ManagerUI.GetFrame and ns.ManagerUI:GetFrame()
    if mf and spotlightBox:GetParent() ~= mf then
        spotlightBox:SetParent(mf)
    end

    if target then
        local tl = target.tl or target
        local br = target.br or target
        if tl and tl:IsShown() and br and br:IsShown() then
            spotlightBox:ClearAllPoints()
            spotlightBox:SetPoint("TOPLEFT", tl, "TOPLEFT", -6, 6)
            spotlightBox:SetPoint("BOTTOMRIGHT", br, "BOTTOMRIGHT", 6, -6)
            spotlightBox:Show()
        else
            spotlightBox:Hide()
        end
    else
        spotlightBox:Hide()
    end

    if not userMovedCard then
        PositionCard(target)
    end

    dimmerFrame:Show()
    cardFrame:Show()
end

function Tutorial:Start(stepIndex)
    if _G.InCombatLockdown and _G.InCombatLockdown() then
        ns:Print(L["GUARD_ERR_FORBIDDEN"])
        return
    end

    if promptDialog then
        promptDialog:Hide()
    end
    if ns.db then
        ns.db.settings.tutorialPromptShown = true
    end

    if ns.ManagerUI and ns.ManagerUI.Show then
        ns.ManagerUI:Show()
    end

    local mf = ns.ManagerUI and ns.ManagerUI.GetFrame and ns.ManagerUI:GetFrame()
    if mf then
        mf:SetFrameStrata("DIALOG")
        mf:SetFrameLevel(100)
    end

    userMovedCard = false
    Tutorial.active = true
    Tutorial:ShowStep(stepIndex or 1)
end

function Tutorial:Stop()
    Tutorial.active = false
    if dimmerFrame then
        dimmerFrame:Hide()
    end
    if spotlightBox then
        spotlightBox:Hide()
    end
    if cardFrame then
        cardFrame:Hide()
    end

    if Tutorial.currentStep >= Tutorial.TOTAL_STEPS and ns.db then
        ns.db.settings.tutorialCompleted = true
        ns:Print(L["TUTORIAL_FINISHED_MSG"])
    end
    Tutorial.currentStep = 0
end

-- ============================================================================
-- Anti-Taint & Combat Quarantine
-- ============================================================================
local combatWatcher = CreateFrame("Frame")
combatWatcher:RegisterEvent("PLAYER_REGEN_DISABLED")
combatWatcher:SetScript("OnEvent", function()
    if promptDialog and promptDialog:IsShown() then
        promptDialog:Hide()
    end
    if Tutorial.active then
        Tutorial:Stop()
    end
end)
