local AddonName, ns = ...

local L = ns.L

local Tutorial = {
    active = false,
    currentStep = 0,
    TOTAL_STEPS = 8,
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
local function EnsureTutorialFrames()
    if cardFrame then
        return
    end

    -- Semi-transparent screen dimmer
    dimmerFrame = CreateFrame("Frame", nil, UIParent)
    dimmerFrame:SetAllPoints(UIParent)
    dimmerFrame:SetFrameStrata("DIALOG")
    dimmerFrame:SetFrameLevel(150)
    dimmerFrame:EnableMouse(true)
    dimmerFrame:Hide()

    local dimTex = dimmerFrame:CreateTexture(nil, "BACKGROUND")
    dimTex:SetAllPoints(dimmerFrame)
    dimTex:SetColorTexture(0.02, 0.03, 0.06, 0.55)

    -- Glowing spotlight border around highlighted elements
    spotlightBox = CreateFrame("Frame", nil, UIParent, BACKDROP_TEMPLATE)
    spotlightBox:SetFrameStrata("DIALOG")
    spotlightBox:SetFrameLevel(160)
    spotlightBox:EnableMouse(false)
    if spotlightBox.SetBackdrop then
        spotlightBox:SetBackdrop({
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 8,
            edgeSize = 14,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        spotlightBox:SetBackdropBorderColor(0.0, 0.85, 1.0, 0.95)
    end
    spotlightBox:Hide()

    -- Interactive Tutorial Card (Draggable Callout)
    local c = CreateFrame("Frame", nil, UIParent, BACKDROP_TEMPLATE)
    c:SetSize(430, 230)
    c:SetPoint("CENTER", 0, -40)
    c:SetFrameStrata("FULLSCREEN_DIALOG")
    c:SetFrameLevel(200)
    c:EnableMouse(true)
    c:SetMovable(true)
    c:RegisterForDrag("LeftButton")
    c:SetClampedToScreen(true)
    StyleBox(c, 0.05, 0.06, 0.09, 0.98, 0.90, 0.74, 0.28)
    c:SetScript("OnDragStart", c.StartMoving)
    c:SetScript("OnDragStop", c.StopMovingOrSizing)
    c:Hide()

    local icon = c:CreateTexture(nil, "ARTWORK")
    icon:SetSize(24, 24)
    icon:SetPoint("TOPLEFT", 14, -12)
    icon:SetTexture(ICON_PATH)

    local title = c:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    c.title = title

    local stepCounter = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    stepCounter:SetPoint("TOPRIGHT", -36, -14)
    stepCounter:SetTextColor(0.0, 0.85, 1.0)
    c.stepCounter = stepCounter

    local closeBtn = CreateFrame("Button", nil, c, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function()
        Tutorial:Stop()
    end)

    local body = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    body:SetPoint("TOPLEFT", 14, -44)
    body:SetPoint("TOPRIGHT", -14, -44)
    body:SetJustifyH("LEFT")
    body:SetSpacing(3)
    c.body = body

    -- Navigation Buttons
    local btnPrev = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    btnPrev:SetSize(88, 24)
    btnPrev:SetPoint("BOTTOMLEFT", 14, 12)
    ApplyCompactButtonFont(btnPrev)
    btnPrev:SetText(L["TUTORIAL_BTN_PREV"])
    btnPrev:SetScript("OnClick", function()
        Tutorial:ShowStep(Tutorial.currentStep - 1)
    end)
    c.btnPrev = btnPrev

    local btnExit = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    btnExit:SetSize(126, 24)
    btnExit:SetPoint("LEFT", btnPrev, "RIGHT", 6, 0)
    ApplyCompactButtonFont(btnExit)
    btnExit:SetText(L["TUTORIAL_BTN_EXIT"])
    btnExit:SetScript("OnClick", function()
        Tutorial:Stop()
    end)
    c.btnExit = btnExit

    local btnNext = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    btnNext:SetSize(116, 24)
    btnNext:SetPoint("BOTTOMRIGHT", -14, 12)
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
local STEPS = {
    [1] = {
        titleKey = "TUTORIAL_STEP1_TITLE",
        bodyKey = "TUTORIAL_STEP1_BODY",
        getTarget = function()
            return ns.ManagerUI and ns.ManagerUI.GetFrame and ns.ManagerUI:GetFrame()
        end,
        cardPosition = "BELOW",
    },
    [2] = {
        titleKey = "TUTORIAL_STEP2_TITLE",
        bodyKey = "TUTORIAL_STEP2_BODY",
        getTarget = function()
            local mf = ns.ManagerUI and ns.ManagerUI.GetFrame and ns.ManagerUI:GetFrame()
            return mf and mf.presetBtns and mf.presetBtns[1]
        end,
        cardPosition = "CENTER",
    },
    [3] = {
        titleKey = "TUTORIAL_STEP3_TITLE",
        bodyKey = "TUTORIAL_STEP3_BODY",
        getTarget = function()
            local mf = ns.ManagerUI and ns.ManagerUI.GetFrame and ns.ManagerUI:GetFrame()
            return mf and mf.scrollFrame
        end,
        cardPosition = "CENTER",
    },
    [4] = {
        titleKey = "TUTORIAL_STEP4_TITLE",
        bodyKey = "TUTORIAL_STEP4_BODY",
        getTarget = function()
            local mf = ns.ManagerUI and ns.ManagerUI.GetFrame and ns.ManagerUI:GetFrame()
            return mf and mf.scrollFrame
        end,
        cardPosition = "CENTER",
    },
    [5] = {
        titleKey = "TUTORIAL_STEP5_TITLE",
        bodyKey = "TUTORIAL_STEP5_BODY",
        getTarget = function()
            local mf = ns.ManagerUI and ns.ManagerUI.GetFrame and ns.ManagerUI:GetFrame()
            return mf and mf.profCycleBtn
        end,
        cardPosition = "CENTER",
    },
    [6] = {
        titleKey = "TUTORIAL_STEP6_TITLE",
        bodyKey = "TUTORIAL_STEP6_BODY",
        getTarget = function()
            return nil
        end,
        cardPosition = "CENTER",
    },
    [7] = {
        titleKey = "TUTORIAL_STEP7_TITLE",
        bodyKey = "TUTORIAL_STEP7_BODY",
        getTarget = function()
            return nil
        end,
        cardPosition = "CENTER",
    },
    [8] = {
        titleKey = "TUTORIAL_STEP8_TITLE",
        bodyKey = "TUTORIAL_STEP8_BODY",
        getTarget = function()
            local mf = ns.ManagerUI and ns.ManagerUI.GetFrame and ns.ManagerUI:GetFrame()
            return mf and mf.selfScaleBtn
        end,
        cardPosition = "CENTER",
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
    if target and target:IsShown() then
        spotlightBox:ClearAllPoints()
        spotlightBox:SetPoint("TOPLEFT", target, "TOPLEFT", -6, 6)
        spotlightBox:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 6, -6)
        spotlightBox:Show()
    else
        spotlightBox:Hide()
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
