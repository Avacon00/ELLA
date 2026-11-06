local AddonName, ns = ...

local L = ns.L
local Registry = ns.Registry
local Engine = ns.Engine
local Profiles = ns.Profiles
local BadgeUI = ns.BadgeUI
local Picker = ns.Picker

local ManagerUI = {}
ns.ManagerUI = ManagerUI

local BACKDROP_TEMPLATE = _G.BackdropTemplateMixin and "BackdropTemplate" or nil
local ICON_PATH = "Interface\\AddOns\\ELLA\\Media\\Icon"
local managerFrame = nil
local exportModal = nil
local newProfileModal = nil
local rowPool = {}
local searchQuery = ""

local MODE_CYCLE = {
    [ns.MODE_SCALE_MOVE] = ns.MODE_SCALE_ONLY,
    [ns.MODE_SCALE_ONLY] = ns.MODE_DISABLED,
    [ns.MODE_DISABLED] = ns.MODE_SCALE_MOVE,
}

local function ModeLabel(mode)
    if mode == ns.MODE_SCALE_ONLY then
        return L["MODE_SCALE_ONLY"]
    elseif mode == ns.MODE_DISABLED then
        return L["MODE_DISABLED"]
    end
    return L["MODE_SCALE_MOVE"]
end

local function StyleBox(frame, bgR, bgG, bgB, alpha)
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
        frame:SetBackdropBorderColor(0.78, 0.65, 0.25, 0.95)
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
-- Export / Import Modal (with ScrollFrame so text never overlaps buttons!)
-- ============================================================================
local function OpenExportImportModal()
    if not exportModal then
        local m = CreateFrame("Frame", nil, UIParent, BACKDROP_TEMPLATE)
        m:SetSize(500, 250)
        m:SetPoint("CENTER", 0, 30)
        m:SetFrameStrata("FULLSCREEN_DIALOG")
        m:EnableMouse(true)
        m:SetClampedToScreen(true)
        StyleBox(m, 0.05, 0.06, 0.09, 0.98)

        local title = m:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOPLEFT", 14, -12)
        title:SetPoint("TOPRIGHT", -32, -12)
        title:SetJustifyH("LEFT")
        title:SetText(L["UI_EXPORT_TITLE"])

        local boxBorder = CreateFrame("Frame", nil, m, BACKDROP_TEMPLATE)
        boxBorder:SetPoint("TOPLEFT", 14, -38)
        boxBorder:SetPoint("BOTTOMRIGHT", -14, 46)
        StyleBox(boxBorder, 0.02, 0.02, 0.03, 0.95)

        local scroll = CreateFrame("ScrollFrame", nil, boxBorder, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 8, -8)
        scroll:SetPoint("BOTTOMRIGHT", -28, 8)

        local editBox = CreateFrame("EditBox", nil, scroll)
        editBox:SetMultiLine(true)
        editBox:SetAutoFocus(false)
        editBox:SetFontObject("ChatFontNormal")
        editBox:SetWidth(428)
        editBox:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
            m:Hide()
        end)
        scroll:SetScrollChild(editBox)
        m.editBox = editBox

        local importBtn = CreateFrame("Button", nil, m, "UIPanelButtonTemplate")
        importBtn:SetSize(140, 24)
        importBtn:SetPoint("BOTTOMLEFT", 14, 12)
        importBtn:SetText(L["UI_BTN_IMPORT"])
        importBtn:SetScript("OnClick", function()
            local ok, msg = Profiles:ImportString(m.editBox:GetText())
            ns:Print(msg)
            if ok then
                m:Hide()
                ManagerUI:RefreshList()
            end
        end)

        local closeBtn = CreateFrame("Button", nil, m, "UIPanelButtonTemplate")
        closeBtn:SetSize(120, 24)
        closeBtn:SetPoint("BOTTOMRIGHT", -14, 12)
        closeBtn:SetText(L["UI_BTN_CLOSE"])
        closeBtn:SetScript("OnClick", function()
            m:Hide()
        end)

        exportModal = m
    end

    exportModal.editBox:SetText(Profiles:ExportString())
    exportModal:Show()
    exportModal.editBox:HighlightText()
    exportModal.editBox:SetFocus()
end

-- ============================================================================
-- New / Copy Named Profile Modal (v1.1)
-- ============================================================================
local function OpenNewProfileModal()
    if not newProfileModal then
        local m = CreateFrame("Frame", nil, UIParent, BACKDROP_TEMPLATE)
        m:SetSize(420, 134)
        m:SetPoint("CENTER", 0, 40)
        m:SetFrameStrata("FULLSCREEN_DIALOG")
        m:EnableMouse(true)
        m:SetClampedToScreen(true)
        StyleBox(m, 0.05, 0.06, 0.09, 0.98)

        local prompt = m:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        prompt:SetPoint("TOPLEFT", 14, -14)
        prompt:SetPoint("TOPRIGHT", -14, -14)
        prompt:SetJustifyH("LEFT")
        prompt:SetText(L["UI_PROFILE_PROMPT"])

        local input = CreateFrame("EditBox", nil, m, BACKDROP_TEMPLATE)
        input:SetSize(392, 28)
        input:SetPoint("TOPLEFT", 14, -48)
        input:SetAutoFocus(false)
        input:SetMaxLetters(36)
        input:SetFontObject("ChatFontNormal")
        input:SetTextInsets(8, 8, 0, 0)
        StyleBox(input, 0.02, 0.02, 0.04, 0.95)
        m.input = input

        local function SubmitNewProfile()
            local txt = input:GetText() or ""
            if Profiles:CreateOrCopyProfile(txt, true) then
                input:SetText("")
                input:ClearFocus()
                m:Hide()
                ManagerUI:RefreshList()
            end
        end

        input:SetScript("OnEnterPressed", SubmitNewProfile)
        input:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
            m:Hide()
        end)

        local createBtn = CreateFrame("Button", nil, m, "UIPanelButtonTemplate")
        createBtn:SetSize(160, 24)
        createBtn:SetPoint("BOTTOMLEFT", 14, 12)
        createBtn:SetText(L["UI_PROFILE_CREATE_BTN"])
        createBtn:SetScript("OnClick", SubmitNewProfile)

        local closeBtn = CreateFrame("Button", nil, m, "UIPanelButtonTemplate")
        closeBtn:SetSize(120, 24)
        closeBtn:SetPoint("BOTTOMRIGHT", -14, 12)
        closeBtn:SetText(L["UI_BTN_CLOSE"])
        closeBtn:SetScript("OnClick", function()
            m:Hide()
        end)

        newProfileModal = m
    end

    newProfileModal.input:SetText("")
    newProfileModal:Show()
    newProfileModal.input:SetFocus()
end

local DEFAULT_MANAGER_W = 720
local DEFAULT_MANAGER_H = 580
local MIN_MANAGER_W = 680
local MAX_MANAGER_W = 1080
local MIN_MANAGER_H = 440
local MAX_MANAGER_H = 860
local MIN_MANAGER_SCALE = 0.60
local MAX_MANAGER_SCALE = 1.40

local function ApplyRowResponsiveWidth(row, childW)
    local labelW = math.max(206, childW - 408)
    row.label:SetWidth(labelW)
    row.catLabel:SetWidth(labelW)
    row.modeBtn:ClearAllPoints()
    row.modeBtn:SetPoint("LEFT", labelW + 32, 0)
end

local function SetManagerScale(requestedScale)
    local s = tonumber(requestedScale) or 1.00
    if s < MIN_MANAGER_SCALE then
        s = MIN_MANAGER_SCALE
    elseif s > MAX_MANAGER_SCALE then
        s = MAX_MANAGER_SCALE
    end
    s = math.floor(s * 100 + 0.5) / 100
    ns.db.settings.managerScale = s
    if managerFrame then
        managerFrame:SetScale(s)
        if managerFrame.selfScaleBtn then
            local pct = math.floor(s * 100 + 0.5)
            managerFrame.selfScaleBtn.text:SetText(pct .. "%")
            if math.abs(s - 1.00) > 0.005 then
                managerFrame.selfScaleBtn.text:SetTextColor(1.0, 0.84, 0.15)
            else
                managerFrame.selfScaleBtn.text:SetTextColor(0.85, 0.87, 0.90)
            end
        end
    end
end

local function ApplyManagerResponsiveLayout(f)
    if not f then
        return
    end
    local w = f:GetWidth() or DEFAULT_MANAGER_W
    local innerW = w - 28
    local rightColX = math.max(336, math.floor(w * 0.486))

    if f.chkBadges then f.chkBadges:SetPoint("TOPLEFT", rightColX, -40) end
    if f.chkClamp then f.chkClamp:SetPoint("TOPLEFT", rightColX, -64) end
    if f.chkMagneticSnap then f.chkMagneticSnap:SetPoint("TOPLEFT", rightColX, -88) end

    if f.presetBtns then
        local gap = 6
        local btnW = math.floor((innerW - (3 * gap)) / 4)
        for i = 1, #f.presetBtns do
            local b = f.presetBtns[i]
            b:SetSize(btnW, 24)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", 14 + (i - 1) * (btnW + gap), -148)
        end
    end

    if f.searchBox then
        -- 152 (pick) + 148 (export) + 136 (reset) + 24 (3x8px gaps) = 460
        f.searchBox:SetWidth(math.max(190, innerW - 460))
    end

    if f.scrollChild then
        local childW = math.max(614, w - 66)
        f.scrollChild:SetWidth(childW)
        for i = 1, #rowPool do
            if rowPool[i] then
                ApplyRowResponsiveWidth(rowPool[i], childW)
            end
        end
    end
end

-- ============================================================================
-- Window Row Factory
-- ============================================================================
local function GetOrCreateRow(parent, index)
    local row = rowPool[index]
    if row then
        return row
    end

    row = CreateFrame("Frame", nil, parent, BACKDROP_TEMPLATE)
    row:SetHeight(34)
    if row.SetBackdrop then
        row:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
        })
        if index % 2 == 0 then
            row:SetBackdropColor(0.11, 0.13, 0.17, 0.55)
        else
            row:SetBackdropColor(0.07, 0.08, 0.11, 0.45)
        end
    end

    local statusDot = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    statusDot:SetPoint("LEFT", 10, 0)
    row.statusDot = statusDot

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", 24, 5)
    label:SetWidth(246)
    label:SetJustifyH("LEFT")
    row.label = label

    local catLabel = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    catLabel:SetPoint("LEFT", 24, -8)
    catLabel:SetWidth(246)
    catLabel:SetJustifyH("LEFT")
    row.catLabel = catLabel

    local modeBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    modeBtn:SetSize(192, 22)
    modeBtn:SetPoint("LEFT", 278, 0)
    ApplyCompactButtonFont(modeBtn)
    row.modeBtn = modeBtn

    ApplyRowResponsiveWidth(row, parent:GetWidth() or 654)

    local minusBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    minusBtn:SetSize(26, 22)
    minusBtn:SetPoint("LEFT", modeBtn, "RIGHT", 10, 0)
    minusBtn:SetText("-")
    row.minusBtn = minusBtn

    local scaleTxt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    scaleTxt:SetSize(48, 22)
    scaleTxt:SetPoint("LEFT", minusBtn, "RIGHT", 2, 0)
    scaleTxt:SetJustifyH("CENTER")
    row.scaleTxt = scaleTxt

    local plusBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    plusBtn:SetSize(26, 22)
    plusBtn:SetPoint("LEFT", scaleTxt, "RIGHT", 2, 0)
    plusBtn:SetText("+")
    row.plusBtn = plusBtn

    local resetBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    resetBtn:SetSize(56, 22)
    resetBtn:SetPoint("LEFT", plusBtn, "RIGHT", 8, 0)
    ApplyCompactButtonFont(resetBtn)
    resetBtn:SetText("100%")
    row.resetBtn = resetBtn

    modeBtn:SetScript("OnClick", function()
        if not row.windowId then return end
        local cfg = ns:GetWindowConfig(row.windowId, true)
        local nextMode = MODE_CYCLE[cfg.mode or ns.MODE_SCALE_MOVE] or ns.MODE_SCALE_MOVE
        Engine:SetWindowMode(row.windowId, nextMode)
    end)

    minusBtn:SetScript("OnClick", function()
        if row.windowId then
            Engine:StepWindowScale(row.windowId, -1, IsShiftKeyDown(), false)
        end
    end)

    plusBtn:SetScript("OnClick", function()
        if row.windowId then
            Engine:StepWindowScale(row.windowId, 1, IsShiftKeyDown(), false)
        end
    end)

    resetBtn:SetScript("OnClick", function()
        if row.windowId then
            Engine:ResetWindow(row.windowId, IsShiftKeyDown())
        end
    end)

    rowPool[index] = row
    return row
end

function ManagerUI:RefreshList()
    if not managerFrame or not managerFrame:IsShown() then
        return
    end

    -- Sync global checkboxes & active profile bar
    local s = ns.db.settings
    managerFrame.chkEnabled:SetChecked(s.enabled)
    managerFrame.chkBadges:SetChecked(s.showBadges)
    managerFrame.chkCtrlWheel:SetChecked(s.ctrlWheelZoom)
    managerFrame.chkClamp:SetChecked(s.clampToScreen)
    managerFrame.chkDragOpacity:SetChecked(s.dragOpacity)
    managerFrame.chkMagneticSnap:SetChecked(s.magneticSnap)

    local activeProf = Profiles:GetActiveProfileName()
    local isDirty = Profiles:HasUnsavedChanges()
    managerFrame.profCycleBtn:SetText("» " .. activeProf .. " «")
    if managerFrame.profSaveBtn then
        managerFrame.profSaveBtn:SetText(isDirty and L["UI_PROFILE_SAVE_DIRTY"] or L["UI_PROFILE_SAVE"])
    end
    if managerFrame.profRevertBtn then
        managerFrame.profRevertBtn:SetEnabled(isDirty)
    end
    if managerFrame.profUndoBtn then
        managerFrame.profUndoBtn:SetEnabled(Profiles:CanUndo())
    end
    managerFrame.profDelBtn:SetEnabled(activeProf ~= "Default")

    local content = managerFrame.scrollChild
    local q = string.lower(searchQuery or "")

    -- Collect and sort windows: 1) Open right now, 2) Loaded in memory, 3) On-Demand
    local items = {}
    local orderIndex = 0
    for windowId, desc in Registry:IterateWindows() do
        orderIndex = orderIndex + 1
        local winTitle = Registry:GetDisplayLabel(desc)
        local catTitle = L[desc.category or "CAT_CUSTOM"]
        if q == "" or string.find(string.lower(winTitle), q, 1, true) or string.find(string.lower(catTitle), q, 1, true) then
            local isOpen = (desc.boundFrame and desc.boundFrame:IsShown()) and true or false
            local isLoaded = (desc.boundFrame ~= nil)
            local rank = isOpen and 1 or (isLoaded and 2 or 3)
            items[#items + 1] = {
                id = windowId,
                desc = desc,
                winTitle = winTitle,
                catTitle = catTitle,
                isOpen = isOpen,
                isLoaded = isLoaded,
                rank = rank,
                orderIndex = orderIndex,
            }
        end
    end

    table.sort(items, function(a, b)
        if a.rank ~= b.rank then
            return a.rank < b.rank
        end
        return a.orderIndex < b.orderIndex
    end)

    for visibleIdx = 1, #items do
        local item = items[visibleIdx]
        local windowId = item.id
        local desc = item.desc
        local row = GetOrCreateRow(content, visibleIdx)
        row.windowId = windowId
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -((visibleIdx - 1) * 36))
        row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -((visibleIdx - 1) * 36))

        local cfg = ns:GetWindowConfig(windowId, false)
        local mode = (cfg and cfg.mode) or desc.defaultMode or (s.defaultScaleOnly and ns.MODE_SCALE_ONLY or ns.MODE_SCALE_MOVE)
        local pct = math.floor(((cfg and cfg.scale) or 1) * 100 + 0.5)

        if item.isOpen then
            row.statusDot:SetText("|cff00ff96•|r")
            row.catLabel:SetText(item.catTitle .. " • |cff00ff96" .. L["UI_STATUS_OPEN"] .. "|r")
        elseif item.isLoaded then
            row.statusDot:SetText("|cffffd100•|r")
            row.catLabel:SetText(item.catTitle .. " • " .. L["UI_STATUS_LOADED"])
        else
            row.statusDot:SetText("|cff666677•|r")
            row.catLabel:SetText(item.catTitle .. " • " .. L["UI_STATUS_LOD"])
        end

        row.label:SetText(item.winTitle)
        row.modeBtn:SetText(ModeLabel(mode))
        row.scaleTxt:SetText(pct .. "%")
        row:Show()
    end

    for i = #items + 1, #rowPool do
        rowPool[i]:Hide()
    end

    content:SetHeight(math.max(280, #items * 36 + 8))
end

-- ============================================================================
-- Standalone Window Manager (/ella) – Movable, Resizable & Self-Scalable!
-- ============================================================================
local function EnsureManagerFrame()
    if managerFrame then
        return managerFrame
    end

    local initW = math.min(MAX_MANAGER_W, math.max(MIN_MANAGER_W, tonumber(ns.db.settings.managerWidth) or DEFAULT_MANAGER_W))
    local initH = math.min(MAX_MANAGER_H, math.max(MIN_MANAGER_H, tonumber(ns.db.settings.managerHeight) or DEFAULT_MANAGER_H))

    local f = CreateFrame("Frame", nil, UIParent, BACKDROP_TEMPLATE)
    f:SetSize(initW, initH)
    f:SetPoint("CENTER", 0, 20)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(100)
    f:EnableMouse(true)
    f:EnableMouseWheel(true)
    f:SetMovable(true)
    f:SetResizable(true)
    if type(f.SetResizeBounds) == "function" then
        f:SetResizeBounds(MIN_MANAGER_W, MIN_MANAGER_H, MAX_MANAGER_W, MAX_MANAGER_H)
    elseif type(f.SetMinResize) == "function" then
        f:SetMinResize(MIN_MANAGER_W, MIN_MANAGER_H)
        f:SetMaxResize(MAX_MANAGER_W, MAX_MANAGER_H)
    end
    f:RegisterForDrag("LeftButton")
    f:SetClampedToScreen(true)
    StyleBox(f, 0.05, 0.06, 0.09, 0.96)
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetScript("OnMouseWheel", function(_, delta)
        if IsControlKeyDown() then
            local step = IsShiftKeyDown() and 0.01 or 0.05
            SetManagerScale((ns.db.settings.managerScale or 1.00) + (delta * step))
        end
    end)
    f:Hide()

    local iconTex = f:CreateTexture(nil, "ARTWORK")
    iconTex:SetSize(24, 24)
    iconTex:SetPoint("TOPLEFT", 16, -10)
    iconTex:SetTexture(ICON_PATH)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", iconTex, "RIGHT", 8, 0)
    title:SetText(L["UI_MANAGER_TITLE"] .. " |cff8899aa(v" .. ns.Version .. ")|r")

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function()
        f:Hide()
    end)

    -- Ella Manager's own Titlebar Scale Pill ([100%])
    local selfScaleBtn = CreateFrame("Button", nil, f, BACKDROP_TEMPLATE)
    selfScaleBtn:SetSize(48, 20)
    selfScaleBtn:SetPoint("RIGHT", closeBtn, "LEFT", -4, 0)
    selfScaleBtn:EnableMouse(true)
    selfScaleBtn:EnableMouseWheel(true)
    selfScaleBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    StyleBox(selfScaleBtn, 0.10, 0.12, 0.16, 0.94)

    local selfScaleTxt = selfScaleBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    selfScaleTxt:SetPoint("CENTER", 0, 0)
    selfScaleTxt:SetText("100%")
    selfScaleBtn.text = selfScaleTxt
    f.selfScaleBtn = selfScaleBtn

    -- Tutorial Help Button [?]
    local helpBtn = CreateFrame("Button", nil, f, BACKDROP_TEMPLATE)
    helpBtn:SetSize(24, 20)
    helpBtn:SetPoint("RIGHT", selfScaleBtn, "LEFT", -4, 0)
    StyleBox(helpBtn, 0.10, 0.12, 0.16, 0.94)
    local helpTxt = helpBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    helpTxt:SetPoint("CENTER", 0, 0)
    helpTxt:SetText("?")
    helpBtn.text = helpTxt
    helpBtn:SetScript("OnClick", function()
        if ns.Tutorial and ns.Tutorial.Start then
            ns.Tutorial:Start(1)
        end
    end)
    helpBtn:SetScript("OnEnter", function(self)
        if _G.GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(L["TUTORIAL_HELP_BUTTON_TIP"], 1, 0.82, 0)
            GameTooltip:Show()
        end
    end)
    helpBtn:SetScript("OnLeave", function()
        if _G.GameTooltip then
            GameTooltip:Hide()
        end
    end)
    f.helpBtn = helpBtn

    selfScaleBtn:SetScript("OnMouseWheel", function(_, delta)
        local step = IsShiftKeyDown() and 0.01 or 0.05
        SetManagerScale((ns.db.settings.managerScale or 1.00) + (delta * step))
    end)
    selfScaleBtn:SetScript("OnClick", function(_, btn)
        if btn == "RightButton" then
            SetManagerScale(1.00)
        else
            -- Handy trackpad / click cycle: 100% -> 90% -> 80% -> 110% -> 100%
            local cur = math.floor((ns.db.settings.managerScale or 1.00) * 100 + 0.5)
            local nextScale = 1.00
            if cur >= 98 and cur <= 102 then
                nextScale = 0.90
            elseif cur > 85 and cur < 98 then
                nextScale = 0.80
            elseif cur <= 85 then
                nextScale = 1.10
            end
            SetManagerScale(nextScale)
        end
    end)
    selfScaleBtn:SetScript("OnEnter", function(self)
        if _G.GameTooltip then
            local pct = math.floor((ns.db.settings.managerScale or 1.00) * 100 + 0.5)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(string.format(L["UI_MANAGER_SCALE_TIP_TITLE"], pct), 1, 0.82, 0)
            GameTooltip:AddLine(L["UI_MANAGER_SCALE_TIP_SCROLL"], 0.9, 0.9, 0.9)
            GameTooltip:AddLine(L["UI_MANAGER_SCALE_TIP_RCLICK"], 0.9, 0.9, 0.9)
            GameTooltip:Show()
        end
    end)
    selfScaleBtn:SetScript("OnLeave", function()
        if _G.GameTooltip then
            GameTooltip:Hide()
        end
    end)

    -- Global Settings Toggles (3x2 compact grid)
    local function CreateToggle(label, x, y, getter, setter)
        local chk = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
        chk:SetSize(24, 24)
        chk:SetPoint("TOPLEFT", x, y)
        local txt = chk:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        txt:SetPoint("LEFT", chk, "RIGHT", 4, 0)
        txt:SetText(label)
        chk:SetChecked(getter())
        chk:SetScript("OnClick", function(self)
            setter(self:GetChecked() and true or false)
        end)
        return chk
    end

    f.chkEnabled = CreateToggle(L["UI_GLOBAL_ENABLED"], 14, -40,
        function() return ns.db.settings.enabled end,
        function(val)
            ns.db.settings.enabled = val
            Engine:ReapplyAllShown()
            BadgeUI:RefreshAll()
        end
    )

    f.chkBadges = CreateToggle(L["UI_SHOW_BADGES"], 350, -40,
        function() return ns.db.settings.showBadges end,
        function(val)
            ns.db.settings.showBadges = val
            BadgeUI:RefreshAll()
        end
    )

    f.chkCtrlWheel = CreateToggle(L["UI_CTRL_WHEEL"], 14, -64,
        function() return ns.db.settings.ctrlWheelZoom end,
        function(val) ns.db.settings.ctrlWheelZoom = val end
    )

    f.chkClamp = CreateToggle(L["UI_CLAMP_SCREEN"], 350, -64,
        function() return ns.db.settings.clampToScreen end,
        function(val)
            ns.db.settings.clampToScreen = val
            Engine:ReapplyAllShown()
        end
    )

    f.chkDragOpacity = CreateToggle(L["UI_DRAG_OPACITY"], 14, -88,
        function() return ns.db.settings.dragOpacity end,
        function(val) ns.db.settings.dragOpacity = val end
    )

    f.chkMagneticSnap = CreateToggle(L["UI_MAGNETIC_SNAP"], 350, -88,
        function() return ns.db.settings.magneticSnap end,
        function(val) ns.db.settings.magneticSnap = val end
    )

    -- Named Profile Bar with Save Checkpoint, Revert to Saved & Undo (v1.1.2)
    local profLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    profLabel:SetPoint("TOPLEFT", 16, -124)
    profLabel:SetText(L["UI_PROFILE_LABEL"])

    local function AddBtnTooltip(btn, titleText, bodyText)
        btn:SetScript("OnEnter", function(self)
            if _G.GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:AddLine(titleText, 1, 0.82, 0)
                GameTooltip:AddLine(bodyText, 0.9, 0.9, 0.9, true)
                GameTooltip:Show()
            end
        end)
        btn:SetScript("OnLeave", function()
            if _G.GameTooltip then
                GameTooltip:Hide()
            end
        end)
    end

    local profCycleBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    profCycleBtn:SetSize(148, 24)
    profCycleBtn:SetPoint("TOPLEFT", 60, -118)
    ApplyCompactButtonFont(profCycleBtn)
    profCycleBtn:SetScript("OnClick", function()
        Profiles:CycleNextProfile()
        ManagerUI:RefreshList()
    end)
    profCycleBtn:SetScript("OnEnter", function(self)
        if _G.GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(L["UI_PROFILE_LABEL"], 1, 0.82, 0)
            local active = Profiles:GetActiveProfileName()
            local all = Profiles:ListProfiles()
            for i = 1, #all do
                local pName = all[i]
                if pName == active then
                    GameTooltip:AddLine("» " .. pName, 0, 1, 0.59)
                else
                    GameTooltip:AddLine("• " .. pName, 0.8, 0.8, 0.8)
                end
            end
            GameTooltip:Show()
        end
    end)
    profCycleBtn:SetScript("OnLeave", function()
        if _G.GameTooltip then
            GameTooltip:Hide()
        end
    end)
    f.profCycleBtn = profCycleBtn

    local profSaveBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    profSaveBtn:SetSize(118, 24)
    profSaveBtn:SetPoint("LEFT", profCycleBtn, "RIGHT", 4, 0)
    ApplyCompactButtonFont(profSaveBtn)
    profSaveBtn:SetText(L["UI_PROFILE_SAVE"])
    profSaveBtn:SetScript("OnClick", function()
        Profiles:SaveActiveProfileSnapshot(false)
        ManagerUI:RefreshList()
    end)
    AddBtnTooltip(profSaveBtn, L["UI_PROFILE_SAVE"], L["UI_PROFILE_SAVE_TIP"])
    f.profSaveBtn = profSaveBtn

    local profRevertBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    profRevertBtn:SetSize(126, 24)
    profRevertBtn:SetPoint("LEFT", profSaveBtn, "RIGHT", 4, 0)
    ApplyCompactButtonFont(profRevertBtn)
    profRevertBtn:SetText(L["UI_PROFILE_REVERT"])
    profRevertBtn:SetScript("OnClick", function()
        Profiles:RevertToSavedProfile()
        ManagerUI:RefreshList()
    end)
    AddBtnTooltip(profRevertBtn, L["UI_PROFILE_REVERT"], L["UI_PROFILE_REVERT_TIP"])
    f.profRevertBtn = profRevertBtn

    local profUndoBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    profUndoBtn:SetSize(92, 24)
    profUndoBtn:SetPoint("LEFT", profRevertBtn, "RIGHT", 4, 0)
    ApplyCompactButtonFont(profUndoBtn)
    profUndoBtn:SetText(L["UI_BTN_UNDO"])
    profUndoBtn:SetScript("OnClick", function()
        Profiles:UndoLastChange()
        ManagerUI:RefreshList()
    end)
    AddBtnTooltip(profUndoBtn, L["UI_BTN_UNDO"], L["UI_BTN_UNDO_TIP"])
    f.profUndoBtn = profUndoBtn

    local profNewBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    profNewBtn:SetSize(82, 24)
    profNewBtn:SetPoint("LEFT", profUndoBtn, "RIGHT", 4, 0)
    ApplyCompactButtonFont(profNewBtn)
    profNewBtn:SetText(L["UI_PROFILE_NEW"])
    profNewBtn:SetScript("OnClick", function()
        OpenNewProfileModal()
    end)
    AddBtnTooltip(profNewBtn, L["UI_PROFILE_NEW"], L["UI_PROFILE_NEW_TIP"])
    f.profNewBtn = profNewBtn

    local profDelBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    profDelBtn:SetSize(72, 24)
    profDelBtn:SetPoint("LEFT", profNewBtn, "RIGHT", 4, 0)
    ApplyCompactButtonFont(profDelBtn)
    profDelBtn:SetText(L["UI_PROFILE_DELETE"])
    profDelBtn:SetScript("OnClick", function()
        Profiles:DeleteProfile(Profiles:GetActiveProfileName())
        ManagerUI:RefreshList()
    end)
    f.profDelBtn = profDelBtn

    -- Preset Bar (4 evenly spaced responsive buttons)
    local presetDefs = {
        { id = "DEFAULT_100", label = L["PRESET_DEFAULT_NAME"], desc = L["PRESET_DEFAULT_DESC"] },
        { id = "COMPACT_80", label = L["PRESET_COMPACT80_NAME"], desc = L["PRESET_COMPACT80_DESC"] },
        { id = "WQHD_85", label = L["PRESET_WQHD85_NAME"], desc = L["PRESET_WQHD85_DESC"] },
        { id = "LAPTOP_72", label = L["PRESET_LAPTOP72_NAME"], desc = L["PRESET_LAPTOP72_DESC"] },
    }
    f.presetBtns = {}
    for i = 1, #presetDefs do
        local pd = presetDefs[i]
        local pBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        pBtn:SetSize(168, 24)
        pBtn:SetPoint("TOPLEFT", 14 + (i - 1) * 174, -148)
        ApplyCompactButtonFont(pBtn)
        pBtn:SetText(pd.label)
        pBtn:SetScript("OnClick", function()
            Profiles:ApplyPreset(pd.id)
            ManagerUI:RefreshList()
        end)
        pBtn:SetScript("OnEnter", function(self)
            if _G.GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:AddLine(pd.label, 1, 0.82, 0)
                GameTooltip:AddLine(pd.desc, 0.9, 0.9, 0.9, true)
                GameTooltip:Show()
            end
        end)
        pBtn:SetScript("OnLeave", function()
            if _G.GameTooltip then
                GameTooltip:Hide()
            end
        end)
        f.presetBtns[i] = pBtn
    end

    -- Search Box + Utility Buttons
    local searchBox = CreateFrame("EditBox", nil, f, BACKDROP_TEMPLATE)
    searchBox:SetSize(232, 24)
    searchBox:SetPoint("TOPLEFT", 14, -180)
    searchBox:SetAutoFocus(false)
    searchBox:SetFontObject("ChatFontNormal")
    searchBox:SetTextInsets(8, 8, 0, 0)
    StyleBox(searchBox, 0.02, 0.02, 0.04, 0.92)
    local placeholder = searchBox:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    placeholder:SetPoint("LEFT", 8, 0)
    placeholder:SetText(L["UI_SEARCH_PLACEHOLDER"])
    f.searchBox = searchBox

    searchBox:SetScript("OnTextChanged", function(self)
        local txt = self:GetText() or ""
        placeholder:SetShown(txt == "")
        searchQuery = txt
        ManagerUI:RefreshList()
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    local pickBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    pickBtn:SetSize(152, 24)
    pickBtn:SetPoint("LEFT", searchBox, "RIGHT", 8, 0)
    ApplyCompactButtonFont(pickBtn)
    pickBtn:SetText(L["UI_START_PICKER"])
    pickBtn:SetScript("OnClick", function()
        f:Hide()
        Picker:Start(true)
    end)
    f.pickBtn = pickBtn

    local expBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    expBtn:SetSize(148, 24)
    expBtn:SetPoint("LEFT", pickBtn, "RIGHT", 8, 0)
    ApplyCompactButtonFont(expBtn)
    expBtn:SetText(L["UI_EXPORT_IMPORT"])
    expBtn:SetScript("OnClick", function()
        OpenExportImportModal()
    end)

    local rstBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    rstBtn:SetSize(136, 24)
    rstBtn:SetPoint("LEFT", expBtn, "RIGHT", 8, 0)
    ApplyCompactButtonFont(rstBtn)
    rstBtn:SetText(L["UI_RESET_ALL"])
    rstBtn:SetScript("OnClick", function()
        Profiles:ResetAll()
        ManagerUI:RefreshList()
    end)

    -- Scrollable Window List
    local listBorder = CreateFrame("Frame", nil, f, BACKDROP_TEMPLATE)
    listBorder:SetPoint("TOPLEFT", 14, -210)
    listBorder:SetPoint("BOTTOMRIGHT", -14, 18)
    StyleBox(listBorder, 0.03, 0.04, 0.06, 0.90)

    local scrollFrame = CreateFrame("ScrollFrame", nil, listBorder, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 6, -6)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 6)
    local origScrollWheel = scrollFrame:GetScript("OnMouseWheel")
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        if IsControlKeyDown() then
            local step = IsShiftKeyDown() and 0.01 or 0.05
            SetManagerScale((ns.db.settings.managerScale or 1.00) + (delta * step))
            return
        end
        if origScrollWheel then
            origScrollWheel(self, delta)
        end
    end)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(654)
    scrollChild:SetHeight(300)
    scrollFrame:SetScrollChild(scrollChild)
    f.scrollFrame = scrollFrame
    f.scrollChild = scrollChild

    -- Bottom-Right Corner Resize Grip (Drag = resize width/height, Right-Click = default 720x580)
    local resizeGrip = CreateFrame("Button", nil, f)
    resizeGrip:SetSize(16, 16)
    resizeGrip:SetPoint("BOTTOMRIGHT", -2, 2)
    resizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeGrip:RegisterForClicks("RightButtonUp")
    resizeGrip:SetScript("OnMouseDown", function(_, btn)
        if btn == "LeftButton" then
            f:StartSizing("BOTTOMRIGHT")
        end
    end)
    resizeGrip:SetScript("OnMouseUp", function(_, btn)
        if btn == "LeftButton" then
            f:StopMovingOrSizing()
            ns.db.settings.managerWidth = math.floor((f:GetWidth() or DEFAULT_MANAGER_W) + 0.5)
            ns.db.settings.managerHeight = math.floor((f:GetHeight() or DEFAULT_MANAGER_H) + 0.5)
            ApplyManagerResponsiveLayout(f)
        end
    end)
    resizeGrip:SetScript("OnClick", function(_, btn)
        if btn == "RightButton" then
            f:SetSize(DEFAULT_MANAGER_W, DEFAULT_MANAGER_H)
            ns.db.settings.managerWidth = DEFAULT_MANAGER_W
            ns.db.settings.managerHeight = DEFAULT_MANAGER_H
            ApplyManagerResponsiveLayout(f)
        end
    end)
    resizeGrip:SetScript("OnEnter", function(self)
        if _G.GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
            GameTooltip:AddLine(L["UI_MANAGER_RESIZE_TIP"], 0.9, 0.9, 0.9)
            GameTooltip:Show()
        end
    end)
    resizeGrip:SetScript("OnLeave", function()
        if _G.GameTooltip then
            GameTooltip:Hide()
        end
    end)
    f.resizeGrip = resizeGrip

    f:SetScript("OnSizeChanged", function(self)
        ApplyManagerResponsiveLayout(self)
    end)

    f:SetScript("OnHide", function()
        if ns.Tutorial and ns.Tutorial.active then
            ns.Tutorial:Stop()
        end
    end)

    managerFrame = f
    SetManagerScale(ns.db.settings.managerScale or 1.00)
    ApplyManagerResponsiveLayout(f)
    return f
end

function ManagerUI:GetFrame()
    return managerFrame
end

function ManagerUI:GetRow(index)
    return rowPool and rowPool[index]
end

function ManagerUI:Show()
    local f = EnsureManagerFrame()
    f:Show()
    ManagerUI:RefreshList()
    if ns.Tutorial and ns.Tutorial.PromptIfFirstOpen then
        ns.Tutorial:PromptIfFirstOpen()
    end
end

function ManagerUI:Toggle()
    local f = EnsureManagerFrame()
    if f:IsShown() then
        f:Hide()
    else
        ManagerUI:Show()
    end
end

ns:On("OnWindowConfigChanged", function() ManagerUI:RefreshList() end)
ns:On("OnWindowRegistered", function() ManagerUI:RefreshList() end)
ns:On("OnWindowBound", function() ManagerUI:RefreshList() end)
ns:On("OnManagedFrameShown", function() ManagerUI:RefreshList() end)
ns:On("OnManagedFrameHidden", function() ManagerUI:RefreshList() end)
ns:On("OnPresetApplied", function() ManagerUI:RefreshList() end)
ns:On("OnProfileSwitched", function() ManagerUI:RefreshList() end)
ns:On("OnProfileImported", function() ManagerUI:RefreshList() end)
ns:On("OnResetAll", function() ManagerUI:RefreshList() end)

-- ============================================================================
-- Native Blizzard Settings Panel (ESC -> Options -> AddOns -> Ella)
-- Uses unique category.ID to prevent Settings taint bugs.
-- ============================================================================
local function RegisterBlizzardSettingsCanvas()
    if not _G.Settings or type(_G.Settings.RegisterCanvasLayoutCategory) ~= "function" then
        return
    end

    local canvas = CreateFrame("Frame", nil, UIParent)
    canvas:Hide()

    local icon = canvas:CreateTexture(nil, "ARTWORK")
    icon:SetSize(36, 36)
    icon:SetPoint("TOPLEFT", 16, -16)
    icon:SetTexture(ICON_PATH)

    local header = canvas:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -2)
    header:SetText(L["ADDON_TITLE"] .. " v" .. ns.Version)

    local sub = canvas:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    sub:SetText(L["ADDON_SUBTITLE"])

    local openBtn = CreateFrame("Button", nil, canvas, "UIPanelButtonTemplate")
    openBtn:SetSize(260, 30)
    openBtn:SetPoint("TOPLEFT", 16, -68)
    openBtn:SetText(L["UI_OPEN_MANAGER"])
    openBtn:SetScript("OnClick", function()
        ManagerUI:Show()
    end)

    local compactBtn = CreateFrame("Button", nil, canvas, "UIPanelButtonTemplate")
    compactBtn:SetSize(260, 28)
    compactBtn:SetPoint("TOPLEFT", openBtn, "BOTTOMLEFT", 0, -10)
    compactBtn:SetText(L["WELCOME_BTN_COMPACT"])
    compactBtn:SetScript("OnClick", function()
        Profiles:ApplyPreset("COMPACT_80")
    end)

    local pickBtn = CreateFrame("Button", nil, canvas, "UIPanelButtonTemplate")
    pickBtn:SetSize(260, 28)
    pickBtn:SetPoint("TOPLEFT", compactBtn, "BOTTOMLEFT", 0, -10)
    pickBtn:SetText(L["UI_START_PICKER"])
    pickBtn:SetScript("OnClick", function()
        if _G.HideUIPanel and _G.SettingsPanel then
            _G.HideUIPanel(_G.SettingsPanel)
        end
        Picker:Start()
    end)

    local category = _G.Settings.RegisterCanvasLayoutCategory(canvas, L["ADDON_TITLE"], "ELLA_SettingsCategory")
    if category then
        category.ID = "ELLA_SettingsCategory"
        _G.Settings.RegisterAddOnCategory(category)
    end
end

-- ============================================================================
-- Native Minimap AddonCompartment Registration (Zero Globals Needed!)
-- ============================================================================
local function RegisterMinimapCompartment()
    local compartment = _G.AddonCompartmentFrame
    if not compartment or type(compartment.RegisterAddon) ~= "function" then
        return
    end

    compartment:RegisterAddon({
        text = L["ADDON_TITLE"],
        icon = ICON_PATH,
        notCheckable = true,
        registerForAnyClick = true,
        func = function(_, menuInputData)
            local btn = menuInputData and menuInputData.buttonName or "LeftButton"
            if btn == "RightButton" then
                ns.db.settings.showBadges = not ns.db.settings.showBadges
                BadgeUI:RefreshAll()
            elseif btn == "MiddleButton" then
                Picker:Start()
            else
                ManagerUI:Toggle()
            end
        end,
        funcOnEnter = function(menuItem)
            if _G.GameTooltip then
                GameTooltip:SetOwner(menuItem, "ANCHOR_LEFT")
                GameTooltip:AddLine(L["ADDON_TITLE"], 1, 0.82, 0)
                GameTooltip:AddLine(L["COMPARTMENT_LEFT"], 0.9, 0.9, 0.9)
                GameTooltip:AddLine(L["COMPARTMENT_RIGHT"], 0.9, 0.9, 0.9)
                GameTooltip:AddLine(L["COMPARTMENT_MIDDLE"], 0.9, 0.9, 0.9)
                GameTooltip:Show()
            end
        end,
        funcOnLeave = function()
            if _G.GameTooltip then
                GameTooltip:Hide()
            end
        end,
    })
end

ns:On("OnPlayerLogin", function()
    RegisterBlizzardSettingsCanvas()
    RegisterMinimapCompartment()
end)

-- ============================================================================
-- Slash Commands (/ella & /fscale alias)
-- ============================================================================
_G.SLASH_ELLA1 = "/ella"
_G.SLASH_ELLA2 = "/fscale"

_G.SlashCmdList["ELLA"] = function(rawMsg)
    local cmd, rest = string.match(rawMsg or "", "^%s*(%S*)%s*(.-)%s*$")
    cmd = string.lower(cmd or "")
    if cmd == "tour" or cmd == "tutorial" then
        if ns.Tutorial and ns.Tutorial.Start then
            ns.Tutorial:Start(1)
        end
    elseif cmd == "pick" or cmd == "inspect" then
        Picker:Start()
    elseif cmd == "compact" or cmd == "80" then
        Profiles:ApplyPreset("COMPACT_80")
    elseif cmd == "badges" or cmd == "badge" then
        ns.db.settings.showBadges = not ns.db.settings.showBadges
        BadgeUI:RefreshAll()
    elseif cmd == "profile" or cmd == "prof" then
        if rest and rest ~= "" then
            Profiles:SwitchProfile(rest)
        else
            Profiles:CycleNextProfile()
        end
    elseif cmd == "undo" or cmd == "z" then
        Profiles:UndoLastChange()
    elseif cmd == "revert" then
        Profiles:RevertToSavedProfile()
    elseif cmd == "save" then
        Profiles:SaveActiveProfileSnapshot(false)
    elseif cmd == "reset" then
        Profiles:ResetAll()
    elseif cmd == "help" or cmd == "?" then
        ns:Print(L["SLASH_HELP_HEADER"])
        ns:Print(L["SLASH_HELP_OPEN"])
        ns:Print(L["SLASH_HELP_TOUR"])
        ns:Print(L["SLASH_HELP_PICK"])
        ns:Print(L["SLASH_HELP_PRESET"])
        ns:Print(L["SLASH_HELP_BADGES"])
        ns:Print(L["SLASH_HELP_PROFILE"])
        ns:Print(L["SLASH_HELP_RESET"])
    else
        ManagerUI:Toggle()
    end
end
