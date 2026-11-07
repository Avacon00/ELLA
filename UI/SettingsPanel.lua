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
local activeCategoryFilter = "ALL"
local activeMainTab = "WINDOWS"

local TAB_DEFS = {
    { id = "WINDOWS", labelKey = "UI_TAB_WINDOWS" },
    { id = "SETTINGS", labelKey = "UI_TAB_SETTINGS" },
    { id = "PROFILES", labelKey = "UI_TAB_PROFILES" },
}

local FILTER_DEFS = {
    { id = "ALL", labelKey = "FILTER_ALL" },
    { id = "OPEN", labelKey = "FILTER_OPEN" },
    { id = "CAT_CHARACTER", labelKey = "FILTER_CHAR" },
    { id = "CAT_CRAFT_ECON", labelKey = "FILTER_PROF" },
    { id = "CAT_QUEST_WORLD", labelKey = "FILTER_QUEST" },
    { id = "CAT_SOCIAL", labelKey = "FILTER_SOCIAL" },
    { id = "CAT_FOREVER", labelKey = "FILTER_FOREVER" },
    { id = "CAT_CUSTOM", labelKey = "FILTER_CUSTOM" },
}

local MODE_CYCLE = {
    [ns.MODE_SCALE_MOVE] = ns.MODE_SCALE_ONLY,
    [ns.MODE_SCALE_ONLY] = ns.MODE_DISABLED,
    [ns.MODE_DISABLED] = ns.MODE_SCALE_MOVE,
}

local function IsValidFilterId(filterId)
    for i = 1, #FILTER_DEFS do
        if FILTER_DEFS[i].id == filterId then
            return true
        end
    end
    return false
end

local function RegisterSpecialFrameOnce(frameName)
    if not _G.UISpecialFrames or type(frameName) ~= "string" then
        return
    end
    for i = 1, #_G.UISpecialFrames do
        if _G.UISpecialFrames[i] == frameName then
            return
        end
    end
    table.insert(_G.UISpecialFrames, frameName)
end

local function ModeLabel(mode)
    if mode == ns.MODE_SCALE_ONLY then
        return L["MODE_SCALE_ONLY"]
    elseif mode == ns.MODE_DISABLED then
        return L["MODE_DISABLED"]
    end
    return L["MODE_SCALE_MOVE"]
end

local function StyleBox(frame, bgR, bgG, bgB, alpha, edgeR, edgeG, edgeB, edgeA)
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
        frame:SetBackdropBorderColor(edgeR or 0.78, edgeG or 0.65, edgeB or 0.25, edgeA or 0.95)
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
-- Sleek Dark-Slate Flat Control Factory (Replaces noisy crimson 3D row buttons)
-- ============================================================================
local function ApplyFlatButtonTheme(btn, bgR, bgG, bgB, bgA, brR, brG, brB, brA, txR, txG, txB)
    btn._bgR, btn._bgG, btn._bgB, btn._bgA = bgR, bgG, bgB, bgA
    btn._brR, btn._brG, btn._brB, btn._brA = brR, brG, brB, brA
    btn._txR, btn._txG, btn._txB = txR, txG, txB
    if not btn._isHovered then
        if btn.SetBackdropColor then
            btn:SetBackdropColor(bgR, bgG, bgB, bgA)
            btn:SetBackdropBorderColor(brR, brG, brB, brA)
        end
        if btn.text then
            btn.text:SetTextColor(txR, txG, txB)
        end
    end
end

local function CreateFlatButton(parent, width, height, initialText)
    local btn = CreateFrame("Button", nil, parent, BACKDROP_TEMPLATE)
    btn:SetSize(width, height)
    btn:RegisterForClicks("LeftButtonUp")
    if btn.SetBackdrop then
        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
    end

    local txt = nil
    if initialText ~= nil then
        txt = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        txt:SetPoint("CENTER", 0, 0)
        txt:SetJustifyH("CENTER")
        txt:SetWordWrap(false)
        txt:SetText(initialText)
        btn.text = txt
    end

    function btn:SetLabel(str)
        if self.text then
            self.text:SetText(str)
        end
    end

    ApplyFlatButtonTheme(btn, 0.11, 0.13, 0.18, 0.92, 0.26, 0.31, 0.40, 0.85, 0.86, 0.89, 0.94)

    btn:HookScript("OnEnter", function(self)
        self._isHovered = true
        if self.SetBackdropColor then
            self:SetBackdropColor(0.16, 0.21, 0.29, 0.98)
            self:SetBackdropBorderColor(0.0, 0.82, 1.0, 0.95)
        end
        if self.text then
            self.text:SetTextColor(1.0, 1.0, 1.0)
        end
    end)

    btn:HookScript("OnLeave", function(self)
        self._isHovered = false
        if self.SetBackdropColor then
            self:SetBackdropColor(self._bgR, self._bgG, self._bgB, self._bgA)
            self:SetBackdropBorderColor(self._brR, self._brG, self._brB, self._brA)
        end
        if self.text then
            self.text:SetTextColor(self._txR, self._txG, self._txB)
        end
    end)

    btn:HookScript("OnMouseDown", function(self)
        if self.text then
            self.text:SetPoint("CENTER", 0, -1)
        end
        if self.icon then
            self.icon:SetPoint("CENTER", 0, -1)
        end
    end)

    btn:HookScript("OnMouseUp", function(self)
        if self.text then
            self.text:SetPoint("CENTER", 0, 0)
        end
        if self.icon then
            self.icon:SetPoint("CENTER", 0, 0)
        end
    end)

    return btn
end

-- ============================================================================
-- Inline 2-Click Destructive Action Safety Helper
-- ============================================================================
local armedConfirmButtons = {}

local function DisarmButton(btn)
    if not btn or not armedConfirmButtons[btn] then
        return
    end
    armedConfirmButtons[btn] = nil
    if btn._normalLabel then
        btn:SetText(btn._normalLabel)
    end
end

local function DisarmAllConfirmButtons()
    for btn in pairs(armedConfirmButtons) do
        DisarmButton(btn)
    end
end

local function SetupTwoClickConfirm(btn, normalLabel, onConfirmed)
    btn._normalLabel = normalLabel
    btn:SetText(normalLabel)
    btn:SetScript("OnClick", function(self)
        local now = (_G.GetTime and _G.GetTime()) or 0
        local armedUntil = armedConfirmButtons[self]
        if armedUntil and now <= armedUntil then
            DisarmButton(self)
            onConfirmed()
        else
            ns:PlaySound("CLICK")
            local token = now + 3.0
            armedConfirmButtons[self] = token
            self:SetText("|cffff6666" .. L["UI_CONFIRM_CLICK_AGAIN"] .. "|r")
            if _G.C_Timer and _G.C_Timer.After then
                _G.C_Timer.After(3.0, function()
                    if armedConfirmButtons[self] == token then
                        DisarmButton(self)
                    end
                end)
            end
        end
    end)
end

-- ============================================================================
-- Export / Import Modal (with ScrollFrame so text never overlaps buttons!)
-- ============================================================================
local function OpenExportImportModal()
    if not exportModal then
        local m = CreateFrame("Frame", "EllaExportModal", UIParent, BACKDROP_TEMPLATE)
        m:SetSize(520, 290)
        m:SetPoint("CENTER", 0, 30)
        m:SetFrameStrata("FULLSCREEN_DIALOG")
        m:EnableMouse(true)
        m:SetClampedToScreen(true)
        StyleBox(m, 0.05, 0.06, 0.09, 0.98)
        RegisterSpecialFrameOnce("EllaExportModal")

        local title = m:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOPLEFT", 14, -12)
        title:SetPoint("TOPRIGHT", -32, -12)
        title:SetJustifyH("LEFT")
        title:SetText(L["UI_EXPORT_TITLE"])

        local topClose = CreateFrame("Button", nil, m, "UIPanelCloseButton")
        topClose:SetSize(22, 22)
        topClose:SetPoint("TOPRIGHT", -3, -3)
        topClose:SetScript("OnClick", function()
            ns:PlaySound("CLICK")
            m:Hide()
        end)

        local boxBorder = CreateFrame("Frame", nil, m, BACKDROP_TEMPLATE)
        boxBorder:SetPoint("TOPLEFT", 14, -36)
        boxBorder:SetPoint("BOTTOMRIGHT", -14, 76)
        StyleBox(boxBorder, 0.02, 0.03, 0.05, 0.95, 0.24, 0.29, 0.38, 0.85)

        local scroll = CreateFrame("ScrollFrame", nil, boxBorder, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 8, -8)
        scroll:SetPoint("BOTTOMRIGHT", -28, 8)

        local editBox = CreateFrame("EditBox", nil, scroll)
        editBox:SetMultiLine(true)
        editBox:SetAutoFocus(false)
        editBox:SetFontObject("ChatFontNormal")
        editBox:SetWidth(448)
        editBox:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
            m:Hide()
        end)
        scroll:SetScrollChild(editBox)
        m.editBox = editBox

        local summaryText = m:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        summaryText:SetPoint("TOPLEFT", 14, -220)
        summaryText:SetPoint("BOTTOMRIGHT", -14, 42)
        summaryText:SetJustifyH("LEFT")
        summaryText:SetJustifyV("TOP")
        m.summaryText = summaryText

        local copyBtn = CreateFrame("Button", nil, m, "UIPanelButtonTemplate")
        copyBtn:SetSize(136, 24)
        copyBtn:SetPoint("BOTTOMLEFT", 14, 12)
        ApplyCompactButtonFont(copyBtn)
        copyBtn:SetText(L["UI_BTN_COPY_ALL"])
        copyBtn:SetScript("OnClick", function()
            ns:PlaySound("CLICK")
            editBox:HighlightText()
            editBox:SetFocus()
            ns:Print(L["UI_EXPORT_COPY_DONE"])
        end)

        local importBtn = CreateFrame("Button", nil, m, "UIPanelButtonTemplate")
        importBtn:SetSize(184, 24)
        importBtn:SetPoint("LEFT", copyBtn, "RIGHT", 8, 0)
        ApplyCompactButtonFont(importBtn)
        importBtn:SetText(L["UI_BTN_IMPORT"])
        importBtn:SetScript("OnClick", function()
            local ok, msg = Profiles:ImportString(m.editBox:GetText())
            ns:Print(msg)
            if ok then
                ns:PlaySound("PROFILE_SWITCH")
                m:Hide()
                ManagerUI:RefreshList()
            end
        end)
        m.importBtn = importBtn

        local closeBtn = CreateFrame("Button", nil, m, "UIPanelButtonTemplate")
        closeBtn:SetSize(100, 24)
        closeBtn:SetPoint("BOTTOMRIGHT", -14, 12)
        ApplyCompactButtonFont(closeBtn)
        closeBtn:SetText(L["UI_BTN_CLOSE"])
        closeBtn:SetScript("OnClick", function()
            ns:PlaySound("CLICK")
            m:Hide()
        end)

        editBox:SetScript("OnTextChanged", function(self)
            local txt = self:GetText() or ""
            local isValid, count, names, pName = Profiles:InspectImportString(txt)
            if isValid then
                local pInfo = pName and string.format(L["UI_EXPORT_DETECTED_PROFILE"], pName) or ""
                local summaryLine = string.format(L["UI_EXPORT_DETECTED_SUMMARY"], pInfo, count, names)
                m.summaryText:SetText("|cff00ff96" .. L["UI_EXPORT_SUMMARY_DETECTED"] .. "|r\n" .. summaryLine)
                m.importBtn:Enable()
                m.importBtn:SetText(string.format(L["UI_IMPORT_CONFIRM_BTN"], count))
            elseif string.len(txt) < 8 then
                m.summaryText:SetText(L["UI_EXPORT_SUMMARY_INVALID"])
                m.importBtn:Disable()
                m.importBtn:SetText(L["UI_BTN_IMPORT"])
            else
                m.summaryText:SetText("|cffff5555" .. L["UI_EXPORT_SUMMARY_INVALID"] .. "|r")
                m.importBtn:Disable()
                m.importBtn:SetText(L["UI_BTN_IMPORT"])
            end
        end)

        exportModal = m
    end

    local exportStr = Profiles:ExportString()
    exportModal.editBox:SetText(exportStr)
    exportModal:Show()
    exportModal.editBox:HighlightText()
    exportModal.editBox:SetFocus()
end

-- ============================================================================
-- New / Copy Named Profile Modal (v1.1)
-- ============================================================================
local function OpenNewProfileModal()
    if not newProfileModal then
        local m = CreateFrame("Frame", "EllaNewProfileModal", UIParent, BACKDROP_TEMPLATE)
        m:SetSize(420, 138)
        m:SetPoint("CENTER", 0, 40)
        m:SetFrameStrata("FULLSCREEN_DIALOG")
        m:EnableMouse(true)
        m:SetClampedToScreen(true)
        StyleBox(m, 0.05, 0.06, 0.09, 0.98)
        RegisterSpecialFrameOnce("EllaNewProfileModal")

        local prompt = m:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        prompt:SetPoint("TOPLEFT", 14, -14)
        prompt:SetPoint("TOPRIGHT", -32, -14)
        prompt:SetJustifyH("LEFT")
        prompt:SetText(L["UI_PROFILE_PROMPT"])

        local topClose = CreateFrame("Button", nil, m, "UIPanelCloseButton")
        topClose:SetSize(22, 22)
        topClose:SetPoint("TOPRIGHT", -3, -3)
        topClose:SetScript("OnClick", function()
            ns:PlaySound("CLICK")
            m:Hide()
        end)

        local input = CreateFrame("EditBox", nil, m, BACKDROP_TEMPLATE)
        input:SetSize(392, 28)
        input:SetPoint("TOPLEFT", 14, -48)
        input:SetAutoFocus(false)
        input:SetMaxLetters(36)
        input:SetFontObject("ChatFontNormal")
        input:SetTextInsets(8, 8, 0, 0)
        StyleBox(input, 0.02, 0.03, 0.05, 0.95, 0.24, 0.29, 0.38, 0.85)
        input:SetScript("OnEditFocusGained", function(self)
            if self.SetBackdropBorderColor then
                self:SetBackdropBorderColor(0.0, 0.85, 1.0, 0.95)
            end
        end)
        input:SetScript("OnEditFocusLost", function(self)
            if self.SetBackdropBorderColor then
                self:SetBackdropBorderColor(0.24, 0.29, 0.38, 0.85)
            end
        end)
        m.input = input

        local function SubmitNewProfile()
            local txt = input:GetText() or ""
            if Profiles:CreateOrCopyProfile(txt, true) then
                ns:PlaySound("PROFILE_SWITCH")
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
            ns:PlaySound("CLICK")
            m:Hide()
        end)

        newProfileModal = m
    end

    newProfileModal.input:SetText("")
    newProfileModal:Show()
    newProfileModal.input:SetFocus()
end

local DEFAULT_MANAGER_W = 720
local DEFAULT_MANAGER_H = 620
local MIN_MANAGER_W = 680
local MAX_MANAGER_W = 1080
local MIN_MANAGER_H = 440
local MAX_MANAGER_H = 860
local MIN_MANAGER_SCALE = 0.60
local MAX_MANAGER_SCALE = 1.40

local function ApplyRowResponsiveWidth(row, childW)
    local labelW = math.max(182, childW - 422)
    row.label:SetWidth(labelW)
    row.catLabel:SetWidth(labelW)
    row.modeBtn:ClearAllPoints()
    row.modeBtn:SetPoint("LEFT", labelW + 30, 0)
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

local function UpdateGridButtonVisual()
    if not managerFrame or not managerFrame.gridBtn then
        return
    end
    local fs = managerFrame.gridBtn:GetFontString()
    local active = (ns.GridOverlay and ns.GridOverlay:IsShown()) or false
    if fs then
        if active then
            fs:SetTextColor(0.0, 0.92, 1.0)
        else
            fs:SetTextColor(1.0, 0.82, 0.0)
        end
    end
end

local function ApplyManagerResponsiveLayout(f)
    if not f then
        return
    end
    local w = f:GetWidth() or DEFAULT_MANAGER_W
    local innerW = w - 28

    -- Top Navigation Tabs (3 even tabs)
    if f.navTabs and #f.navTabs >= 3 then
        local gap = 6
        local tabW = math.floor((innerW - (2 * gap)) / 3)
        for i = 1, 3 do
            local tab = f.navTabs[i]
            tab:SetSize(tabW, 26)
            tab:ClearAllPoints()
            tab:SetPoint("TOPLEFT", 14 + (i - 1) * (tabW + gap), -36)
        end
    end

    -- Tab 1: WINDOWS
    if f.tabViewWindows then
        if f.searchBox then
            f.searchBox:SetWidth(innerW)
        end

        if f.filterPills then
            local gap = 4
            local numPills = #f.filterPills
            local pillW = math.floor((innerW - ((numPills - 1) * gap)) / numPills)
            for i = 1, numPills do
                local p = f.filterPills[i]
                p:SetSize(pillW, 20)
                p:ClearAllPoints()
                p:SetPoint("TOPLEFT", (i - 1) * (pillW + gap), -58)
            end
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

    -- Tab 2: SETTINGS
    if f.tabViewSettings then
        local col2X = math.max(300, math.floor(innerW * 0.48))
        if f.cardCombat then f.cardCombat:SetWidth(innerW) end
        if f.cardMouse then f.cardMouse:SetWidth(innerW) end
        if f.cardDisplay then f.cardDisplay:SetWidth(innerW) end

        if f.chkInstCompact then f.chkInstCompact:SetPoint("TOPLEFT", col2X, -32) end
        if f.chkStickyDock then f.chkStickyDock:SetPoint("TOPLEFT", col2X, -32) end
        if f.chkClamp then f.chkClamp:SetPoint("TOPLEFT", col2X, -58) end
        if f.chkDefaultScaleOnly then f.chkDefaultScaleOnly:SetPoint("TOPLEFT", col2X, -84) end
        if f.chkMinimap then f.chkMinimap:SetPoint("TOPLEFT", col2X, -32) end
        if f.chkSounds then f.chkSounds:SetPoint("TOPLEFT", col2X, -58) end
    end

    -- Tab 3: PROFILES
    if f.tabViewProfiles then
        if f.cardProf then f.cardProf:SetWidth(innerW) end
        if f.cardPresets then f.cardPresets:SetWidth(innerW) end
        if f.cardSharing then f.cardSharing:SetWidth(innerW) end

        if f.presetBtns then
            local gap = 6
            local pBtnW = math.floor((innerW - 28 - (3 * gap)) / 4)
            for i = 1, #f.presetBtns do
                local b = f.presetBtns[i]
                b:SetSize(pBtnW, 24)
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", 14 + (i - 1) * (pBtnW + gap), -50)
            end
        end
    end
end

-- ============================================================================
-- Window Row Factory (Calm Dark-Slate Controls + Semantic Color States)
-- ============================================================================
local function UpdateRowBackdrop(row)
    if not row or not row.SetBackdropColor then
        return
    end
    if row._hoverCount and row._hoverCount > 0 then
        row:SetBackdropColor(0.15, 0.19, 0.27, 0.72)
    elseif row._rowIndex % 2 == 0 then
        row:SetBackdropColor(0.10, 0.12, 0.16, 0.52)
    else
        row:SetBackdropColor(0.06, 0.07, 0.10, 0.42)
    end
end

local function BindRowHover(row, region)
    region:HookScript("OnEnter", function()
        row._hoverCount = (row._hoverCount or 0) + 1
        UpdateRowBackdrop(row)
    end)
    region:HookScript("OnLeave", function()
        row._hoverCount = math.max(0, (row._hoverCount or 1) - 1)
        UpdateRowBackdrop(row)
    end)
end

local function GetOrCreateRow(parent, index)
    local row = rowPool[index]
    if row then
        return row
    end

    row = CreateFrame("Frame", nil, parent, BACKDROP_TEMPLATE)
    row._rowIndex = index
    row._hoverCount = 0
    row:SetHeight(34)
    row:EnableMouse(true)
    if row.SetBackdrop then
        row:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
        })
        UpdateRowBackdrop(row)
    end
    BindRowHover(row, row)

    local statusDot = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    statusDot:SetPoint("LEFT", 10, 0)
    row.statusDot = statusDot

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", 24, 5)
    label:SetWidth(246)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    row.label = label

    local catLabel = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    catLabel:SetPoint("LEFT", 24, -8)
    catLabel:SetWidth(246)
    catLabel:SetJustifyH("LEFT")
    catLabel:SetWordWrap(false)
    row.catLabel = catLabel

    local modeBtn = CreateFlatButton(row, 180, 22, "")
    modeBtn:SetPoint("LEFT", 278, 0)
    BindRowHover(row, modeBtn)
    row.modeBtn = modeBtn

    ApplyRowResponsiveWidth(row, parent:GetWidth() or 654)

    local minusBtn = CreateFlatButton(row, 24, 22, "-")
    minusBtn:SetPoint("LEFT", modeBtn, "RIGHT", 8, 0)
    BindRowHover(row, minusBtn)
    row.minusBtn = minusBtn

    local scaleTxt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    scaleTxt:SetSize(48, 22)
    scaleTxt:SetPoint("LEFT", minusBtn, "RIGHT", 2, 0)
    scaleTxt:SetJustifyH("CENTER")
    row.scaleTxt = scaleTxt

    local plusBtn = CreateFlatButton(row, 24, 22, "+")
    plusBtn:SetPoint("LEFT", scaleTxt, "RIGHT", 2, 0)
    BindRowHover(row, plusBtn)
    row.plusBtn = plusBtn

    local resetBtn = CreateFlatButton(row, 52, 22, "100%")
    resetBtn:SetPoint("LEFT", plusBtn, "RIGHT", 8, 0)
    BindRowHover(row, resetBtn)
    row.resetBtn = resetBtn

    local eyeBtn = CreateFlatButton(row, 26, 22, nil)
    eyeBtn:SetPoint("LEFT", resetBtn, "RIGHT", 6, 0)
    BindRowHover(row, eyeBtn)
    local eyeIcon = eyeBtn:CreateTexture(nil, "ARTWORK")
    eyeIcon:SetSize(15, 15)
    eyeIcon:SetPoint("CENTER", 0, 0)
    eyeIcon:SetTexture("Interface\\Icons\\INV_Misc_Eye_01")
    eyeIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    eyeBtn.icon = eyeIcon
    row.eyeBtn = eyeBtn
    row.eyeIcon = eyeIcon

    eyeBtn:SetScript("OnClick", function()
        if row.windowId then
            ns:PlaySound("CLICK")
            Registry:ToggleWindowPreview(row.windowId)
            ManagerUI:RefreshList()
        end
    end)
    eyeBtn:HookScript("OnEnter", function(self)
        if _G.GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(L["UI_ROW_TOGGLE_TIP"], 1, 0.82, 0)
            GameTooltip:Show()
        end
    end)
    eyeBtn:HookScript("OnLeave", function()
        if _G.GameTooltip then
            GameTooltip:Hide()
        end
    end)

    modeBtn:SetScript("OnClick", function()
        if not row.windowId then return end
        ns:PlaySound("CLICK")
        local desc = Registry:GetDescriptor(row.windowId)
        local curMode = Engine:GetEffectiveWindowMode(row.windowId, desc)
        local nextMode = MODE_CYCLE[curMode] or ns.MODE_SCALE_MOVE
        Engine:SetWindowMode(row.windowId, nextMode)
    end)
    modeBtn:HookScript("OnEnter", function(self)
        if _G.GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(row.winTitle or "", 1, 0.82, 0)
            GameTooltip:AddLine(L["UI_ROW_MODE_TIP"], 0.9, 0.9, 0.9, true)
            GameTooltip:Show()
        end
    end)
    modeBtn:HookScript("OnLeave", function()
        if _G.GameTooltip then GameTooltip:Hide() end
    end)

    local function ShowStepTooltip(self)
        if _G.GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(row.winTitle or "", 1, 0.82, 0)
            if row.isCapped and row.savedPct then
                GameTooltip:AddLine(string.format(L["UI_COMPACT_CAP_HINT"], row.savedPct), 0.20, 0.90, 1.0)
            end
            GameTooltip:AddLine(L["UI_ROW_STEP_TIP"], 0.9, 0.9, 0.9, true)
            GameTooltip:Show()
        end
    end

    minusBtn:SetScript("OnClick", function()
        if row.windowId then
            ns:PlaySound("CLICK")
            Engine:StepWindowScale(row.windowId, -1, IsShiftKeyDown(), false)
        end
    end)
    minusBtn:HookScript("OnEnter", ShowStepTooltip)
    minusBtn:HookScript("OnLeave", function() if _G.GameTooltip then GameTooltip:Hide() end end)

    plusBtn:SetScript("OnClick", function()
        if row.windowId then
            ns:PlaySound("CLICK")
            Engine:StepWindowScale(row.windowId, 1, IsShiftKeyDown(), false)
        end
    end)
    plusBtn:HookScript("OnEnter", ShowStepTooltip)
    plusBtn:HookScript("OnLeave", function() if _G.GameTooltip then GameTooltip:Hide() end end)

    resetBtn:SetScript("OnClick", function()
        if row.windowId then
            ns:PlaySound("CLICK")
            Engine:ResetWindow(row.windowId, IsShiftKeyDown())
        end
    end)
    resetBtn:HookScript("OnEnter", function(self)
        if _G.GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(row.winTitle or "", 1, 0.82, 0)
            if row.isCapped and row.savedPct then
                GameTooltip:AddLine(string.format(L["UI_COMPACT_CAP_HINT"], row.savedPct), 0.20, 0.90, 1.0)
            end
            GameTooltip:AddLine(L["UI_ROW_RESET_TIP"], 0.9, 0.9, 0.9, true)
            GameTooltip:Show()
        end
    end)
    resetBtn:HookScript("OnLeave", function()
        if _G.GameTooltip then GameTooltip:Hide() end
    end)

    rowPool[index] = row
    return row
end

local function IsCommunityAddonActive(desc)
    if not desc or not desc.isCommunityAddon then
        return true
    end
    if desc.boundFrame ~= nil then
        return true
    end
    local addonName = desc.addon
    if type(addonName) == "string" and addonName ~= "" then
        if _G.C_AddOns and type(_G.C_AddOns.IsAddOnLoaded) == "function" and _G.C_AddOns.IsAddOnLoaded(addonName) then
            return true
        end
        if type(_G.IsAddOnLoaded) == "function" and _G.IsAddOnLoaded(addonName) then
            return true
        end
    end
    return false
end

function ManagerUI:RefreshList()
    if not managerFrame or not managerFrame:IsShown() then
        return
    end

    -- Sync global checkboxes & active profile bar
    local s = ns.db.settings
    if managerFrame.chkEnabled then managerFrame.chkEnabled:SetChecked(s.enabled) end
    if managerFrame.chkBadges then managerFrame.chkBadges:SetChecked(s.showBadges) end
    if managerFrame.chkCtrlWheel then managerFrame.chkCtrlWheel:SetChecked(s.ctrlWheelZoom) end
    if managerFrame.chkClamp then managerFrame.chkClamp:SetChecked(s.clampToScreen) end
    if managerFrame.chkDragOpacity then managerFrame.chkDragOpacity:SetChecked(s.dragOpacity) end
    if managerFrame.chkMagneticSnap then managerFrame.chkMagneticSnap:SetChecked(s.magneticSnap) end
    if managerFrame.chkDefaultScaleOnly then managerFrame.chkDefaultScaleOnly:SetChecked(s.defaultScaleOnly) end
    if managerFrame.chkMinimap then managerFrame.chkMinimap:SetChecked(s.showMinimapButton) end
    if managerFrame.chkSounds then managerFrame.chkSounds:SetChecked(s.enableSounds) end
    if managerFrame.chkCombatClose then managerFrame.chkCombatClose:SetChecked(s.combatAutoClose) end
    if managerFrame.chkInstCompact then managerFrame.chkInstCompact:SetChecked(s.instanceAutoCompact) end
    if managerFrame.chkStickyDock then managerFrame.chkStickyDock:SetChecked(s.stickyDocking) end
    UpdateGridButtonVisual()

    if managerFrame.filterPills then
        local countOpen = 0
        local countCustom = 0
        for _, desc in Registry:IterateWindows() do
            local f = desc.boundFrame
            if f and f:IsShown() then
                countOpen = countOpen + 1
            end
            if desc.isCustom or (desc.category == "CAT_CUSTOM" and IsCommunityAddonActive(desc)) then
                countCustom = countCustom + 1
            end
        end

        for i = 1, #managerFrame.filterPills do
            local pill = managerFrame.filterPills[i]
            local isSel = (pill.filterId == activeCategoryFilter)
            local baseLabel = L[FILTER_DEFS[i].labelKey] or FILTER_DEFS[i].id
            if pill.filterId == "OPEN" then
                pill.text:SetText(string.format("%s (%d)", baseLabel, countOpen))
            elseif pill.filterId == "CAT_CUSTOM" and countCustom > 0 then
                pill.text:SetText(string.format("%s (%d)", baseLabel, countCustom))
            else
                pill.text:SetText(baseLabel)
            end

            if isSel then
                pill:SetBackdropBorderColor(0.0, 0.85, 1.0, 0.95)
                pill:SetBackdropColor(0.0, 0.22, 0.36, 0.78)
                pill.text:SetTextColor(0.0, 0.95, 1.0)
            else
                pill:SetBackdropBorderColor(0.24, 0.29, 0.38, 0.75)
                pill:SetBackdropColor(0.06, 0.07, 0.10, 0.75)
                pill.text:SetTextColor(0.72, 0.76, 0.82)
            end
        end
    end

    local activeProf = Profiles:GetActiveProfileName()
    local isDirty = Profiles:HasUnsavedChanges()
    if managerFrame.profCycleBtn then
        managerFrame.profCycleBtn:SetText("» " .. activeProf .. " «")
    end
    if managerFrame.profCycleBtnQuick then
        managerFrame.profCycleBtnQuick:SetText("» " .. activeProf .. " «")
    end
    if managerFrame.profSaveBtn then
        managerFrame.profSaveBtn:SetText(isDirty and L["UI_PROFILE_SAVE_DIRTY"] or L["UI_PROFILE_SAVE"])
    end
    if managerFrame.profRevertBtn then
        managerFrame.profRevertBtn:SetEnabled(isDirty)
    end
    if managerFrame.profUndoBtn then
        managerFrame.profUndoBtn:SetEnabled(Profiles:CanUndo())
    end
    if managerFrame.profUndoBtnQuick then
        managerFrame.profUndoBtnQuick:SetEnabled(Profiles:CanUndo())
    end
    if managerFrame.profDelBtn then
        if activeProf == "Default" then
            DisarmButton(managerFrame.profDelBtn)
        end
        managerFrame.profDelBtn:SetEnabled(activeProf ~= "Default")
    end
    if managerFrame.chkBindChar then
        managerFrame.chkBindChar:SetChecked(Profiles:IsCharBoundToActiveProfile())
    end

    if managerFrame.presetBtns then
        local activePreset = s.activePreset
        for i = 1, #managerFrame.presetBtns do
            local b = managerFrame.presetBtns[i]
            local fs = b:GetFontString()
            if fs then
                if activePreset and b.presetId == activePreset then
                    fs:SetTextColor(0.0, 1.0, 0.59)
                else
                    fs:SetTextColor(1.0, 0.82, 0.0)
                end
            end
        end
    end

    local content = managerFrame.scrollChild
    local q = string.lower(searchQuery or "")

    -- Collect and sort windows: 1) Open right now, 2) Loaded in memory, 3) On-Demand
    local items = {}
    local orderIndex = 0
    for windowId, desc in Registry:IterateWindows() do
        orderIndex = orderIndex + 1
        local isLoaded = (desc.boundFrame ~= nil)

        -- Hide uninstalled pre-registered third-party community addons unless explicitly searched
        local skipDormantCommunity = (desc.isCommunityAddon and not IsCommunityAddonActive(desc) and q == "")
        if not skipDormantCommunity then
            local winTitle = Registry:GetDisplayLabel(desc)
            local cat = desc.category or "CAT_CUSTOM"
            local catTitle = L[cat] or cat
            local isOpen = (desc.boundFrame and desc.boundFrame:IsShown()) and true or false

            local matchFilter = true
            if activeCategoryFilter == "OPEN" then
                matchFilter = isOpen
            elseif activeCategoryFilter ~= "ALL" then
                matchFilter = (cat == activeCategoryFilter)
            end

            local matchSearch = (q == "" or string.find(string.lower(winTitle), q, 1, true) or string.find(string.lower(catTitle), q, 1, true))

            if matchFilter and matchSearch then
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
        row.winTitle = item.winTitle
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -((visibleIdx - 1) * 36))
        row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -((visibleIdx - 1) * 36))

        local cfg = ns:GetWindowConfig(windowId, false)
        local mode = (cfg and cfg.mode) or desc.defaultMode or (s.defaultScaleOnly and ns.MODE_SCALE_ONLY or ns.MODE_SCALE_MOVE)
        if not s.enabled then
            mode = ns.MODE_DISABLED
        end
        local effScale, savedScale, isCapped = Engine:GetEffectiveWindowScale(windowId, desc)
        local effPct = math.floor(effScale * 100 + 0.5)
        local savedPct = math.floor(savedScale * 100 + 0.5)
        row.isCapped = isCapped
        row.savedPct = savedPct

        local hasCustomPos = (cfg and cfg.pos and cfg.pos.uipX ~= nil and cfg.pos.uipY ~= nil) or false
        local hasCustomAlpha = (cfg and cfg.alpha and cfg.alpha < 0.995) or false
        local isModified = (savedPct ~= 100) or hasCustomPos or hasCustomAlpha

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
        row.modeBtn:SetLabel(ModeLabel(mode))
        if mode == ns.MODE_SCALE_MOVE then
            ApplyFlatButtonTheme(row.modeBtn, 0.07, 0.17, 0.15, 0.92, 0.14, 0.54, 0.43, 0.85, 0.35, 0.96, 0.72)
        elseif mode == ns.MODE_SCALE_ONLY then
            ApplyFlatButtonTheme(row.modeBtn, 0.18, 0.15, 0.07, 0.92, 0.66, 0.53, 0.18, 0.85, 1.0, 0.84, 0.28)
        else
            ApplyFlatButtonTheme(row.modeBtn, 0.09, 0.10, 0.13, 0.78, 0.22, 0.25, 0.32, 0.65, 0.52, 0.55, 0.62)
        end

        row.scaleTxt:SetText(effPct .. "%")
        if isCapped then
            row.scaleTxt:SetTextColor(0.20, 0.92, 1.0)
        elseif isModified then
            row.scaleTxt:SetTextColor(1.0, 0.84, 0.18)
        else
            row.scaleTxt:SetTextColor(0.74, 0.78, 0.84)
        end

        if isModified then
            ApplyFlatButtonTheme(row.resetBtn, 0.14, 0.15, 0.20, 0.94, 0.48, 0.42, 0.22, 0.85, 0.96, 0.84, 0.36)
        else
            ApplyFlatButtonTheme(row.resetBtn, 0.09, 0.10, 0.14, 0.80, 0.22, 0.26, 0.34, 0.70, 0.54, 0.58, 0.66)
        end

        if item.isOpen then
            row.eyeIcon:SetVertexColor(0.0, 1.0, 0.59)
            row.eyeBtn:SetAlpha(1.0)
            ApplyFlatButtonTheme(row.eyeBtn, 0.07, 0.18, 0.15, 0.94, 0.14, 0.56, 0.44, 0.88, 1.0, 1.0, 1.0)
        else
            row.eyeIcon:SetVertexColor(0.82, 0.85, 0.90)
            row.eyeBtn:SetAlpha(0.72)
            ApplyFlatButtonTheme(row.eyeBtn, 0.10, 0.12, 0.16, 0.86, 0.24, 0.29, 0.38, 0.80, 0.85, 0.85, 0.85)
        end

        row:Show()
    end

    for i = #items + 1, #rowPool do
        rowPool[i]:Hide()
    end

    if managerFrame.emptyMsg then
        if #items == 0 then
            if q ~= "" then
                managerFrame.emptyMsg:SetText(L["UI_LIST_EMPTY"])
            elseif activeCategoryFilter == "OPEN" then
                managerFrame.emptyMsg:SetText(L["UI_LIST_EMPTY_OPEN"])
            elseif activeCategoryFilter == "CAT_CUSTOM" then
                managerFrame.emptyMsg:SetText(L["UI_LIST_EMPTY_CUSTOM"])
            else
                managerFrame.emptyMsg:SetText(L["UI_LIST_EMPTY"])
            end
            managerFrame.emptyMsg:Show()
            if managerFrame.emptyResetBtn then
                managerFrame.emptyResetBtn:SetShown(q ~= "" or activeCategoryFilter ~= "ALL")
            end
        else
            managerFrame.emptyMsg:Hide()
            if managerFrame.emptyResetBtn then
                managerFrame.emptyResetBtn:Hide()
            end
        end
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

    local f = CreateFrame("Frame", "EllaManagerFrame", UIParent, BACKDROP_TEMPLATE)
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
    RegisterSpecialFrameOnce("EllaManagerFrame")
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
        ns:PlaySound("CLICK")
        f:Hide()
    end)

    -- Ella Manager's own Titlebar Scale Pill ([100%])
    local selfScaleBtn = CreateFrame("Button", nil, f, BACKDROP_TEMPLATE)
    selfScaleBtn:SetSize(48, 20)
    selfScaleBtn:SetPoint("RIGHT", closeBtn, "LEFT", -4, 0)
    selfScaleBtn:EnableMouse(true)
    selfScaleBtn:EnableMouseWheel(true)
    selfScaleBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    StyleBox(selfScaleBtn, 0.10, 0.12, 0.16, 0.94, 0.36, 0.42, 0.52, 0.90)

    local selfScaleTxt = selfScaleBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    selfScaleTxt:SetPoint("CENTER", 0, 0)
    selfScaleTxt:SetText("100%")
    selfScaleBtn.text = selfScaleTxt
    f.selfScaleBtn = selfScaleBtn

    -- Tutorial Help Button [?]
    local helpBtn = CreateFrame("Button", nil, f, BACKDROP_TEMPLATE)
    helpBtn:SetSize(24, 20)
    helpBtn:SetPoint("RIGHT", selfScaleBtn, "LEFT", -4, 0)
    StyleBox(helpBtn, 0.10, 0.12, 0.16, 0.94, 0.36, 0.42, 0.52, 0.90)
    local helpTxt = helpBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    helpTxt:SetPoint("CENTER", 0, 0)
    helpTxt:SetText("?")
    helpBtn.text = helpTxt
    helpBtn:SetScript("OnClick", function()
        ns:PlaySound("CLICK")
        if ns.Tutorial and ns.Tutorial.Start then
            ns.Tutorial:Start(1)
        end
    end)
    helpBtn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.0, 0.85, 1.0, 0.95)
        if _G.GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(L["TUTORIAL_HELP_BUTTON_TIP"], 1, 0.82, 0)
            GameTooltip:Show()
        end
    end)
    helpBtn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.36, 0.42, 0.52, 0.90)
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
        ns:PlaySound("CLICK")
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
        self:SetBackdropBorderColor(0.0, 0.85, 1.0, 0.95)
        if _G.GameTooltip then
            local pct = math.floor((ns.db.settings.managerScale or 1.00) * 100 + 0.5)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(string.format(L["UI_MANAGER_SCALE_TIP_TITLE"], pct), 1, 0.82, 0)
            GameTooltip:AddLine(L["UI_MANAGER_SCALE_TIP_SCROLL"], 0.9, 0.9, 0.9)
            GameTooltip:AddLine(L["UI_MANAGER_SCALE_TIP_RCLICK"], 0.9, 0.9, 0.9)
            GameTooltip:Show()
        end
    end)
    selfScaleBtn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.36, 0.42, 0.52, 0.90)
        if _G.GameTooltip then
            GameTooltip:Hide()
        end
    end)

    -- Global Settings Toggle Factory (with full-label hitbox & click sound)
    local function CreateToggle(parent, label, x, y, getter, setter)
        local chk = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        chk:SetSize(22, 22)
        chk:SetPoint("TOPLEFT", x, y)
        local txt = chk:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        txt:SetPoint("LEFT", chk, "RIGHT", 4, 0)
        txt:SetText(label)
        local hitW = math.min(270, math.max(130, math.ceil((txt:GetStringWidth() or 150) + 10)))
        chk:SetHitRectInsets(0, -hitW, 0, 0)
        chk:SetChecked(getter())
        chk:SetScript("OnClick", function(self)
            ns:PlaySound("CLICK")
            setter(self:GetChecked() and true or false)
        end)
        return chk
    end

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

    -- ========================================================================
    -- Top Navigation Tabs (3-Tab System)
    -- ========================================================================
    f.navTabs = {}
    for i = 1, #TAB_DEFS do
        local td = TAB_DEFS[i]
        local tabBtn = CreateFrame("Button", nil, f, BACKDROP_TEMPLATE)
        tabBtn.tabId = td.id
        StyleBox(tabBtn, 0.06, 0.08, 0.12, 0.70, 0.28, 0.32, 0.40, 0.75)
        local txt = tabBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        txt:SetPoint("CENTER", 0, 0)
        txt:SetText(L[td.labelKey] or td.id)
        tabBtn.text = txt
        tabBtn:SetScript("OnClick", function()
            ns:PlaySound("CLICK")
            ManagerUI:SelectTab(td.id)
        end)
        f.navTabs[i] = tabBtn
    end

    -- ========================================================================
    -- View Frames for each Tab
    -- ========================================================================
    local tabViewWindows = CreateFrame("Frame", nil, f)
    tabViewWindows:SetPoint("TOPLEFT", 14, -68)
    tabViewWindows:SetPoint("BOTTOMRIGHT", -14, 18)
    f.tabViewWindows = tabViewWindows

    local tabViewSettings = CreateFrame("Frame", nil, f)
    tabViewSettings:SetPoint("TOPLEFT", 14, -68)
    tabViewSettings:SetPoint("BOTTOMRIGHT", -14, 18)
    tabViewSettings:Hide()
    f.tabViewSettings = tabViewSettings

    local tabViewProfiles = CreateFrame("Frame", nil, f)
    tabViewProfiles:SetPoint("TOPLEFT", 14, -68)
    tabViewProfiles:SetPoint("BOTTOMRIGHT", -14, 18)
    tabViewProfiles:Hide()
    f.tabViewProfiles = tabViewProfiles

    -- ========================================================================
    -- TAB 1: WINDOWS & SCALE (tabViewWindows)
    -- ========================================================================
    -- Quick Profile Selector on Windows Tab
    local profCycleBtnQuick = CreateFrame("Button", nil, tabViewWindows, "UIPanelButtonTemplate")
    profCycleBtnQuick:SetSize(160, 24)
    profCycleBtnQuick:SetPoint("TOPLEFT", 0, 0)
    ApplyCompactButtonFont(profCycleBtnQuick)
    profCycleBtnQuick:SetScript("OnClick", function()
        Profiles:CycleNextProfile()
        ManagerUI:RefreshList()
    end)
    profCycleBtnQuick:SetScript("OnEnter", function(self)
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
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L["UI_PROFILE_QUICK_TIP"], 0.75, 0.8, 0.85)
            GameTooltip:Show()
        end
    end)
    profCycleBtnQuick:SetScript("OnLeave", function()
        if _G.GameTooltip then GameTooltip:Hide() end
    end)
    f.profCycleBtnQuick = profCycleBtnQuick

    local profUndoBtnQuick = CreateFrame("Button", nil, tabViewWindows, "UIPanelButtonTemplate")
    profUndoBtnQuick:SetSize(92, 24)
    profUndoBtnQuick:SetPoint("LEFT", profCycleBtnQuick, "RIGHT", 6, 0)
    ApplyCompactButtonFont(profUndoBtnQuick)
    profUndoBtnQuick:SetText(L["UI_BTN_UNDO"])
    profUndoBtnQuick:SetScript("OnClick", function()
        ns:PlaySound("CLICK")
        Profiles:UndoLastChange()
        ManagerUI:RefreshList()
    end)
    AddBtnTooltip(profUndoBtnQuick, L["UI_BTN_UNDO"], L["UI_BTN_UNDO_TIP"])
    f.profUndoBtnQuick = profUndoBtnQuick

    -- Window Tools on Top Right: [Reset] [# Gitter] [+ Picker]
    local rstBtn = CreateFrame("Button", nil, tabViewWindows, "UIPanelButtonTemplate")
    rstBtn:SetSize(98, 24)
    rstBtn:SetPoint("TOPRIGHT", 0, 0)
    ApplyCompactButtonFont(rstBtn)
    SetupTwoClickConfirm(rstBtn, L["UI_RESET_ALL"], function()
        Profiles:ResetAll()
        ManagerUI:RefreshList()
    end)
    AddBtnTooltip(rstBtn, L["UI_RESET_ALL"], L["UI_RESET_ALL_TIP"])
    f.rstBtn = rstBtn

    local gridBtn = CreateFrame("Button", nil, tabViewWindows, "UIPanelButtonTemplate")
    gridBtn:SetSize(82, 24)
    gridBtn:SetPoint("RIGHT", rstBtn, "LEFT", -6, 0)
    ApplyCompactButtonFont(gridBtn)
    gridBtn:SetText(L["UI_BTN_GRID"])
    gridBtn:SetScript("OnClick", function()
        if ns.GridOverlay then
            local state = ns.GridOverlay:Toggle()
            ns:Print(state and L["MSG_GRID_ENABLED"] or L["MSG_GRID_DISABLED"])
            UpdateGridButtonVisual()
        end
    end)
    AddBtnTooltip(gridBtn, L["UI_BTN_GRID"], L["UI_BTN_GRID_TIP"])
    f.gridBtn = gridBtn

    local pickBtn = CreateFrame("Button", nil, tabViewWindows, "UIPanelButtonTemplate")
    pickBtn:SetSize(128, 24)
    pickBtn:SetPoint("RIGHT", gridBtn, "LEFT", -6, 0)
    ApplyCompactButtonFont(pickBtn)
    pickBtn:SetText(L["UI_START_PICKER"])
    pickBtn:SetScript("OnClick", function()
        f:Hide()
        Picker:Start(true)
    end)
    AddBtnTooltip(pickBtn, L["UI_START_PICKER"], L["UI_START_PICKER_TIP"])
    f.pickBtn = pickBtn

    -- Search Box (Full Width, Recessed Slate Border + Cyan Focus + [x] Clear Button)
    local searchBox = CreateFrame("EditBox", nil, tabViewWindows, BACKDROP_TEMPLATE)
    searchBox:SetHeight(24)
    searchBox:SetPoint("TOPLEFT", 0, -30)
    searchBox:SetAutoFocus(false)
    searchBox:SetFontObject("ChatFontNormal")
    searchBox:SetTextInsets(8, 26, 0, 0)
    StyleBox(searchBox, 0.02, 0.03, 0.05, 0.94, 0.24, 0.29, 0.38, 0.85)
    local placeholder = searchBox:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    placeholder:SetPoint("LEFT", 8, 0)
    placeholder:SetText(L["UI_SEARCH_PLACEHOLDER"])

    local searchClearBtn = CreateFrame("Button", nil, searchBox)
    searchClearBtn:SetSize(18, 18)
    searchClearBtn:SetPoint("RIGHT", -5, 0)
    local clearTxt = searchClearBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    clearTxt:SetPoint("CENTER", 0, 0)
    clearTxt:SetText("×")
    clearTxt:SetTextColor(0.65, 0.70, 0.78)
    searchClearBtn:Hide()
    searchClearBtn:SetScript("OnEnter", function(self)
        clearTxt:SetTextColor(1.0, 1.0, 1.0)
        if _G.GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(L["UI_SEARCH_CLEAR_TIP"], 1, 0.82, 0)
            GameTooltip:Show()
        end
    end)
    searchClearBtn:SetScript("OnLeave", function()
        clearTxt:SetTextColor(0.65, 0.70, 0.78)
        if _G.GameTooltip then GameTooltip:Hide() end
    end)
    searchClearBtn:SetScript("OnClick", function()
        ns:PlaySound("CLICK")
        searchBox:SetText("")
        searchBox:ClearFocus()
    end)
    f.searchClearBtn = searchClearBtn

    searchBox:SetScript("OnEditFocusGained", function(self)
        if self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(0.0, 0.85, 1.0, 0.95)
        end
    end)
    searchBox:SetScript("OnEditFocusLost", function(self)
        if self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(0.24, 0.29, 0.38, 0.85)
        end
    end)
    searchBox:SetScript("OnTextChanged", function(self)
        local txt = self:GetText() or ""
        placeholder:SetShown(txt == "")
        searchClearBtn:SetShown(txt ~= "")
        searchQuery = txt
        ManagerUI:RefreshList()
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        if (self:GetText() or "") ~= "" then
            self:SetText("")
        end
        self:ClearFocus()
    end)
    f.searchBox = searchBox

    -- Category Filter Pills (8 Clean Pills)
    f.filterPills = {}
    for i = 1, #FILTER_DEFS do
        local fd = FILTER_DEFS[i]
        local pill = CreateFrame("Button", nil, tabViewWindows, BACKDROP_TEMPLATE)
        pill:SetSize(78, 20)
        pill.filterId = fd.id
        StyleBox(pill, 0.06, 0.07, 0.10, 0.90, 0.24, 0.29, 0.38, 0.80)
        local pTxt = pill:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        pTxt:SetPoint("CENTER", 0, 0)
        pTxt:SetWordWrap(false)
        pTxt:SetText(L[fd.labelKey] or fd.id)
        pill.text = pTxt
        pill:SetScript("OnClick", function()
            ns:PlaySound("CLICK")
            activeCategoryFilter = fd.id
            if ns.db and ns.db.settings then
                ns.db.settings.selectedCategoryFilter = fd.id
            end
            ManagerUI:RefreshList()
        end)
        pill:SetScript("OnEnter", function(self)
            if self.filterId ~= activeCategoryFilter then
                self:SetBackdropBorderColor(0.45, 0.54, 0.68, 0.95)
                self.text:SetTextColor(0.95, 0.97, 1.0)
            end
        end)
        pill:SetScript("OnLeave", function(self)
            if self.filterId ~= activeCategoryFilter then
                self:SetBackdropBorderColor(0.24, 0.29, 0.38, 0.75)
                self.text:SetTextColor(0.72, 0.76, 0.82)
            end
        end)
        f.filterPills[i] = pill
    end

    -- Scrollable Window List (Recessed Slate Container: Starts at y = -84)
    local listBorder = CreateFrame("Frame", nil, tabViewWindows, BACKDROP_TEMPLATE)
    listBorder:SetPoint("TOPLEFT", 0, -84)
    listBorder:SetPoint("BOTTOMRIGHT", 0, 0)
    StyleBox(listBorder, 0.03, 0.04, 0.06, 0.92, 0.24, 0.29, 0.38, 0.85)

    local emptyMsg = listBorder:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    emptyMsg:SetPoint("CENTER", 0, 14)
    emptyMsg:SetWidth(460)
    emptyMsg:SetJustifyH("CENTER")
    emptyMsg:SetSpacing(3)
    emptyMsg:SetText(L["UI_LIST_EMPTY"])
    emptyMsg:Hide()
    f.emptyMsg = emptyMsg

    local emptyResetBtn = CreateFlatButton(listBorder, 196, 24, L["UI_LIST_SHOW_ALL"])
    emptyResetBtn:SetPoint("TOP", emptyMsg, "BOTTOM", 0, -10)
    emptyResetBtn:Hide()
    emptyResetBtn:SetScript("OnClick", function()
        ns:PlaySound("CLICK")
        activeCategoryFilter = "ALL"
        if ns.db and ns.db.settings then
            ns.db.settings.selectedCategoryFilter = "ALL"
        end
        if f.searchBox then
            f.searchBox:SetText("")
            f.searchBox:ClearFocus()
        end
        ManagerUI:RefreshList()
    end)
    f.emptyResetBtn = emptyResetBtn

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

    -- ========================================================================
    -- TAB 2: SETTINGS / OPTIONEN (tabViewSettings)
    -- ========================================================================
    -- Card 1: Kampf & Instanzen
    local cardCombat = CreateFrame("Frame", nil, tabViewSettings, BACKDROP_TEMPLATE)
    cardCombat:SetPoint("TOPLEFT", 0, 0)
    cardCombat:SetHeight(68)
    StyleBox(cardCombat, 0.05, 0.06, 0.09, 0.85, 0.28, 0.33, 0.44, 0.80)
    local tCombat = cardCombat:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tCombat:SetPoint("TOPLEFT", 14, -10)
    tCombat:SetText("» " .. L["UI_SEC_COMBAT_INSTANCE"])
    tCombat:SetTextColor(1.0, 0.82, 0.25)
    f.cardCombat = cardCombat

    f.chkCombatClose = CreateToggle(cardCombat, L["UI_COMBAT_AUTOCLOSE"], 14, -32,
        function() return ns.db.settings.combatAutoClose end,
        function(val) ns.db.settings.combatAutoClose = val end
    )
    AddBtnTooltip(f.chkCombatClose, L["UI_COMBAT_AUTOCLOSE"], L["UI_COMBAT_AUTOCLOSE_TIP"])

    f.chkInstCompact = CreateToggle(cardCombat, L["UI_INSTANCE_AUTOCOMPACT"], 340, -32,
        function() return ns.db.settings.instanceAutoCompact end,
        function(val)
            ns.db.settings.instanceAutoCompact = val
            Engine:UpdateInstanceCompactState()
        end
    )
    AddBtnTooltip(f.chkInstCompact, L["UI_INSTANCE_AUTOCOMPACT"], L["UI_INSTANCE_AUTOCOMPACT_TIP"])

    -- Card 2: Maus- & Bewegungsverhalten (Symmetrical 3x2 Grid)
    local cardMouse = CreateFrame("Frame", nil, tabViewSettings, BACKDROP_TEMPLATE)
    cardMouse:SetPoint("TOPLEFT", 0, -78)
    cardMouse:SetHeight(116)
    StyleBox(cardMouse, 0.05, 0.06, 0.09, 0.85, 0.28, 0.33, 0.44, 0.80)
    local tMouse = cardMouse:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tMouse:SetPoint("TOPLEFT", 14, -10)
    tMouse:SetText("» " .. L["UI_SEC_MOUSE_BEHAVIOR"])
    tMouse:SetTextColor(1.0, 0.82, 0.25)
    f.cardMouse = cardMouse

    f.chkCtrlWheel = CreateToggle(cardMouse, L["UI_CTRL_WHEEL"], 14, -32,
        function() return ns.db.settings.ctrlWheelZoom end,
        function(val) ns.db.settings.ctrlWheelZoom = val end
    )
    AddBtnTooltip(f.chkCtrlWheel, L["UI_CTRL_WHEEL"], L["UI_CTRL_WHEEL_TIP"])

    f.chkDragOpacity = CreateToggle(cardMouse, L["UI_DRAG_OPACITY"], 14, -58,
        function() return ns.db.settings.dragOpacity end,
        function(val) ns.db.settings.dragOpacity = val end
    )
    AddBtnTooltip(f.chkDragOpacity, L["UI_DRAG_OPACITY"], L["UI_DRAG_OPACITY_TIP"])

    f.chkMagneticSnap = CreateToggle(cardMouse, L["UI_MAGNETIC_SNAP"], 14, -84,
        function() return ns.db.settings.magneticSnap end,
        function(val) ns.db.settings.magneticSnap = val end
    )
    AddBtnTooltip(f.chkMagneticSnap, L["UI_MAGNETIC_SNAP"], L["UI_MAGNETIC_SNAP_TIP"])

    f.chkStickyDock = CreateToggle(cardMouse, L["UI_STICKY_DOCKING"], 340, -32,
        function() return ns.db.settings.stickyDocking end,
        function(val) ns.db.settings.stickyDocking = val end
    )
    AddBtnTooltip(f.chkStickyDock, L["UI_STICKY_DOCKING"], L["UI_STICKY_DOCKING_TIP"])

    f.chkClamp = CreateToggle(cardMouse, L["UI_CLAMP_SCREEN"], 340, -58,
        function() return ns.db.settings.clampToScreen end,
        function(val)
            ns.db.settings.clampToScreen = val
            Engine:ReapplyAllShown()
        end
    )
    AddBtnTooltip(f.chkClamp, L["UI_CLAMP_SCREEN"], L["UI_CLAMP_SCREEN_TIP"])

    f.chkDefaultScaleOnly = CreateToggle(cardMouse, L["UI_DEFAULT_SCALE_ONLY"], 340, -84,
        function() return ns.db.settings.defaultScaleOnly end,
        function(val)
            ns.db.settings.defaultScaleOnly = val
            Engine:ReapplyAllShown()
            ManagerUI:RefreshList()
        end
    )
    AddBtnTooltip(f.chkDefaultScaleOnly, L["UI_DEFAULT_SCALE_ONLY"], L["UI_DEFAULT_SCALE_ONLY_TIP"])

    -- Card 3: Anzeige & System
    local cardDisplay = CreateFrame("Frame", nil, tabViewSettings, BACKDROP_TEMPLATE)
    cardDisplay:SetPoint("TOPLEFT", 0, -204)
    cardDisplay:SetHeight(114)
    StyleBox(cardDisplay, 0.05, 0.06, 0.09, 0.85, 0.28, 0.33, 0.44, 0.80)
    local tDisplay = cardDisplay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tDisplay:SetPoint("TOPLEFT", 14, -10)
    tDisplay:SetText("» " .. L["UI_SEC_DISPLAY_SYSTEM"])
    tDisplay:SetTextColor(1.0, 0.82, 0.25)
    f.cardDisplay = cardDisplay

    f.chkEnabled = CreateToggle(cardDisplay, L["UI_GLOBAL_ENABLED"], 14, -32,
        function() return ns.db.settings.enabled end,
        function(val)
            ns.db.settings.enabled = val
            Engine:ReapplyAllShown()
            BadgeUI:RefreshAll()
            ManagerUI:RefreshList()
        end
    )
    AddBtnTooltip(f.chkEnabled, L["UI_GLOBAL_ENABLED"], L["UI_GLOBAL_ENABLED_TIP"])

    f.chkBadges = CreateToggle(cardDisplay, L["UI_SHOW_BADGES"], 14, -58,
        function() return ns.db.settings.showBadges end,
        function(val)
            ns.db.settings.showBadges = val
            BadgeUI:RefreshAll()
        end
    )
    AddBtnTooltip(f.chkBadges, L["UI_SHOW_BADGES"], L["UI_SHOW_BADGES_TIP"])

    f.chkMinimap = CreateToggle(cardDisplay, L["UI_SHOW_MINIMAP_BTN"], 340, -32,
        function() return ns.db.settings.showMinimapButton end,
        function(val)
            ns.db.settings.showMinimapButton = val
            if ns.MinimapButton and ns.MinimapButton.UpdateVisibility then
                ns.MinimapButton:UpdateVisibility()
            end
        end
    )
    AddBtnTooltip(f.chkMinimap, L["UI_SHOW_MINIMAP_BTN"], L["UI_SHOW_MINIMAP_BTN_TIP"])

    f.chkSounds = CreateToggle(cardDisplay, L["UI_ENABLE_SOUNDS"], 340, -58,
        function() return ns.db.settings.enableSounds end,
        function(val) ns.db.settings.enableSounds = val end
    )
    AddBtnTooltip(f.chkSounds, L["UI_ENABLE_SOUNDS"], L["UI_ENABLE_SOUNDS_TIP"])

    local noteDisplay = cardDisplay:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    noteDisplay:SetPoint("TOPLEFT", 14, -86)
    noteDisplay:SetPoint("TOPRIGHT", -14, -86)
    noteDisplay:SetJustifyH("LEFT")
    noteDisplay:SetText(L["UI_SETTINGS_FOOTNOTE"])

    -- ========================================================================
    -- TAB 3: PROFILES & PRESETS (tabViewProfiles)
    -- ========================================================================
    -- Card 1: Aktives Profil & Verwaltung
    local cardProf = CreateFrame("Frame", nil, tabViewProfiles, BACKDROP_TEMPLATE)
    cardProf:SetPoint("TOPLEFT", 0, 0)
    cardProf:SetHeight(98)
    StyleBox(cardProf, 0.05, 0.06, 0.09, 0.85, 0.28, 0.33, 0.44, 0.80)
    local tProf = cardProf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tProf:SetPoint("TOPLEFT", 14, -10)
    tProf:SetText("» " .. L["UI_SEC_ACTIVE_PROFILE"])
    tProf:SetTextColor(1.0, 0.82, 0.25)
    f.cardProf = cardProf

    local profCycleBtn = CreateFrame("Button", nil, cardProf, "UIPanelButtonTemplate")
    profCycleBtn:SetSize(170, 24)
    profCycleBtn:SetPoint("TOPLEFT", 14, -32)
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
        if _G.GameTooltip then GameTooltip:Hide() end
    end)
    f.profCycleBtn = profCycleBtn

    local profSaveBtn = CreateFrame("Button", nil, cardProf, "UIPanelButtonTemplate")
    profSaveBtn:SetSize(110, 24)
    profSaveBtn:SetPoint("LEFT", profCycleBtn, "RIGHT", 6, 0)
    ApplyCompactButtonFont(profSaveBtn)
    profSaveBtn:SetText(L["UI_PROFILE_SAVE"])
    profSaveBtn:SetScript("OnClick", function()
        ns:PlaySound("CLICK")
        Profiles:SaveActiveProfileSnapshot(false)
        ManagerUI:RefreshList()
    end)
    AddBtnTooltip(profSaveBtn, L["UI_PROFILE_SAVE"], L["UI_PROFILE_SAVE_TIP"])
    f.profSaveBtn = profSaveBtn

    local profRevertBtn = CreateFrame("Button", nil, cardProf, "UIPanelButtonTemplate")
    profRevertBtn:SetSize(124, 24)
    profRevertBtn:SetPoint("LEFT", profSaveBtn, "RIGHT", 6, 0)
    ApplyCompactButtonFont(profRevertBtn)
    profRevertBtn:SetText(L["UI_PROFILE_REVERT"])
    profRevertBtn:SetScript("OnClick", function()
        ns:PlaySound("CLICK")
        Profiles:RevertToSavedProfile()
        ManagerUI:RefreshList()
    end)
    AddBtnTooltip(profRevertBtn, L["UI_PROFILE_REVERT"], L["UI_PROFILE_REVERT_TIP"])
    f.profRevertBtn = profRevertBtn

    local profUndoBtn = CreateFrame("Button", nil, cardProf, "UIPanelButtonTemplate")
    profUndoBtn:SetSize(92, 24)
    profUndoBtn:SetPoint("LEFT", profRevertBtn, "RIGHT", 6, 0)
    ApplyCompactButtonFont(profUndoBtn)
    profUndoBtn:SetText(L["UI_BTN_UNDO"])
    profUndoBtn:SetScript("OnClick", function()
        ns:PlaySound("CLICK")
        Profiles:UndoLastChange()
        ManagerUI:RefreshList()
    end)
    AddBtnTooltip(profUndoBtn, L["UI_BTN_UNDO"], L["UI_BTN_UNDO_TIP"])
    f.profUndoBtn = profUndoBtn

    local profNewBtn = CreateFrame("Button", nil, cardProf, "UIPanelButtonTemplate")
    profNewBtn:SetSize(90, 22)
    profNewBtn:SetPoint("TOPLEFT", 14, -64)
    ApplyCompactButtonFont(profNewBtn)
    profNewBtn:SetText(L["UI_PROFILE_NEW"])
    profNewBtn:SetScript("OnClick", function()
        ns:PlaySound("CLICK")
        OpenNewProfileModal()
    end)
    AddBtnTooltip(profNewBtn, L["UI_PROFILE_NEW"], L["UI_PROFILE_NEW_TIP"])
    f.profNewBtn = profNewBtn

    local profDelBtn = CreateFrame("Button", nil, cardProf, "UIPanelButtonTemplate")
    profDelBtn:SetSize(98, 22)
    profDelBtn:SetPoint("LEFT", profNewBtn, "RIGHT", 6, 0)
    ApplyCompactButtonFont(profDelBtn)
    SetupTwoClickConfirm(profDelBtn, L["UI_PROFILE_DELETE"], function()
        Profiles:DeleteProfile(Profiles:GetActiveProfileName())
        ManagerUI:RefreshList()
    end)
    AddBtnTooltip(profDelBtn, L["UI_PROFILE_DELETE"], L["UI_PROFILE_DELETE_TIP"])
    f.profDelBtn = profDelBtn

    f.chkBindChar = CreateToggle(cardProf, L["UI_PROFILE_BIND_CHAR"], 218, -64,
        function() return Profiles:IsCharBoundToActiveProfile() end,
        function(val) Profiles:SetCharProfileBinding(val) end
    )
    AddBtnTooltip(f.chkBindChar, L["UI_PROFILE_BIND_CHAR"], L["UI_PROFILE_BIND_CHAR_TIP"])

    -- Card 2: 1-Klick-Vorlagen (Presets)
    local cardPresets = CreateFrame("Frame", nil, tabViewProfiles, BACKDROP_TEMPLATE)
    cardPresets:SetPoint("TOPLEFT", 0, -108)
    cardPresets:SetHeight(86)
    StyleBox(cardPresets, 0.05, 0.06, 0.09, 0.85, 0.28, 0.33, 0.44, 0.80)
    local tPresets = cardPresets:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tPresets:SetPoint("TOPLEFT", 14, -10)
    tPresets:SetText("» " .. L["UI_SEC_PRESETS"])
    tPresets:SetTextColor(1.0, 0.82, 0.25)
    f.cardPresets = cardPresets

    local subPresets = cardPresets:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subPresets:SetPoint("TOPLEFT", 14, -28)
    subPresets:SetText(L["UI_SEC_PRESETS_SUB"])

    local presetDefs = {
        { id = "DEFAULT_100", label = L["PRESET_DEFAULT_NAME"], desc = L["PRESET_DEFAULT_DESC"] },
        { id = "COMPACT_80", label = L["PRESET_COMPACT80_NAME"], desc = L["PRESET_COMPACT80_DESC"] },
        { id = "WQHD_85", label = L["PRESET_WQHD85_NAME"], desc = L["PRESET_WQHD85_DESC"] },
        { id = "LAPTOP_72", label = L["PRESET_LAPTOP72_NAME"], desc = L["PRESET_LAPTOP72_DESC"] },
    }
    f.presetBtns = {}
    for i = 1, #presetDefs do
        local pd = presetDefs[i]
        local pBtn = CreateFrame("Button", nil, cardPresets, "UIPanelButtonTemplate")
        pBtn.presetId = pd.id
        pBtn:SetSize(150, 24)
        pBtn:SetPoint("TOPLEFT", 14 + (i - 1) * 156, -50)
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
            if _G.GameTooltip then GameTooltip:Hide() end
        end)
        f.presetBtns[i] = pBtn
    end

    -- Card 3: Profil Teilen & Sichern (Export / Import 2.0)
    local cardSharing = CreateFrame("Frame", nil, tabViewProfiles, BACKDROP_TEMPLATE)
    cardSharing:SetPoint("TOPLEFT", 0, -204)
    cardSharing:SetHeight(86)
    StyleBox(cardSharing, 0.05, 0.06, 0.09, 0.85, 0.28, 0.33, 0.44, 0.80)
    local tSharing = cardSharing:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tSharing:SetPoint("TOPLEFT", 14, -10)
    tSharing:SetText("» " .. L["UI_SEC_SHARING"])
    tSharing:SetTextColor(1.0, 0.82, 0.25)
    f.cardSharing = cardSharing

    local subSharing = cardSharing:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subSharing:SetPoint("TOPLEFT", 14, -28)
    subSharing:SetText(L["UI_SEC_SHARING_SUB"])

    local expBtn = CreateFrame("Button", nil, cardSharing, "UIPanelButtonTemplate")
    expBtn:SetSize(248, 26)
    expBtn:SetPoint("TOPLEFT", 14, -50)
    ApplyCompactButtonFont(expBtn)
    expBtn:SetText(L["UI_EXPORT_LIVE_BTN"])
    expBtn:SetScript("OnClick", function()
        ns:PlaySound("CLICK")
        OpenExportImportModal()
    end)
    AddBtnTooltip(expBtn, L["UI_EXPORT_IMPORT"], L["UI_EXPORT_IMPORT_TIP"])
    f.expBtn = expBtn

    -- Bottom-Right Corner Resize Grip (Drag = resize width/height, Right-Click = default 720x620)
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
            ns:PlaySound("CLICK")
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
        DisarmAllConfirmButtons()
        if exportModal and exportModal:IsShown() then
            exportModal:Hide()
        end
        if newProfileModal and newProfileModal:IsShown() then
            newProfileModal:Hide()
        end
        if ns.Tutorial and ns.Tutorial.active then
            ns.Tutorial:Stop()
        end
        -- Alignment Grid intentionally remains active when closing /ella so players
        -- can align game windows unobstructed; toggle via [# Gitter], /ella grid, or keybind.
    end)

    managerFrame = f
    SetManagerScale(ns.db.settings.managerScale or 1.00)
    ApplyManagerResponsiveLayout(f)
    ManagerUI:SelectTab(activeMainTab or "WINDOWS")
    return f
end

function ManagerUI:GetFrame()
    return managerFrame
end

function ManagerUI:GetRow(index)
    return rowPool and rowPool[index]
end

function ManagerUI:IsShown()
    return managerFrame and managerFrame:IsShown() and true or false
end

function ManagerUI:GetActiveTab()
    return activeMainTab or "WINDOWS"
end

function ManagerUI:PrepareForTutorial()
    activeCategoryFilter = "ALL"
    if ns.db and ns.db.settings then
        ns.db.settings.selectedCategoryFilter = "ALL"
    end
    local f = EnsureManagerFrame()
    if f.searchBox then
        f.searchBox:SetText("")
        f.searchBox:ClearFocus()
    end
    if f.scrollFrame and f.scrollFrame.SetVerticalScroll then
        f.scrollFrame:SetVerticalScroll(0)
    end
    ManagerUI:SelectTab("WINDOWS")
    ManagerUI:RefreshList()
end

function ManagerUI:SelectTab(tabId)
    activeMainTab = tabId or "WINDOWS"
    DisarmAllConfirmButtons()
    if exportModal and exportModal:IsShown() and activeMainTab ~= "PROFILES" then
        exportModal:Hide()
    end
    if newProfileModal and newProfileModal:IsShown() and activeMainTab ~= "PROFILES" then
        newProfileModal:Hide()
    end
    if not managerFrame then
        return
    end

    if managerFrame.navTabs then
        for i = 1, #managerFrame.navTabs do
            local tabBtn = managerFrame.navTabs[i]
            local isSel = (tabBtn.tabId == activeMainTab)
            if isSel then
                tabBtn:SetBackdropBorderColor(0.0, 0.85, 1.0, 0.95)
                tabBtn:SetBackdropColor(0.0, 0.18, 0.28, 0.85)
                tabBtn.text:SetTextColor(1.0, 1.0, 1.0)
            else
                tabBtn:SetBackdropBorderColor(0.28, 0.32, 0.40, 0.70)
                tabBtn:SetBackdropColor(0.06, 0.08, 0.12, 0.65)
                tabBtn.text:SetTextColor(0.72, 0.76, 0.82)
            end
        end
    end

    if managerFrame.tabViewWindows then
        managerFrame.tabViewWindows:SetShown(activeMainTab == "WINDOWS")
    end
    if managerFrame.tabViewSettings then
        managerFrame.tabViewSettings:SetShown(activeMainTab == "SETTINGS")
    end
    if managerFrame.tabViewProfiles then
        managerFrame.tabViewProfiles:SetShown(activeMainTab == "PROFILES")
    end

    ManagerUI:RefreshList()
end

function ManagerUI:Show()
    if ns.MinimapButton and ns.MinimapButton.HideQuickMenu then
        ns.MinimapButton:HideQuickMenu()
    end
    if Registry and Registry.ScanUnboundWindows then
        Registry:ScanUnboundWindows()
    end
    if ns.db and ns.db.settings and ns.db.settings.selectedCategoryFilter then
        local savedFilter = ns.db.settings.selectedCategoryFilter
        activeCategoryFilter = IsValidFilterId(savedFilter) and savedFilter or "ALL"
    end
    local f = EnsureManagerFrame()
    f:Show()
    ManagerUI:SelectTab(activeMainTab or "WINDOWS")
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
ns:On("OnCharProfileBindingChanged", function() ManagerUI:RefreshList() end)
ns:On("OnProfileImported", function() ManagerUI:RefreshList() end)
ns:On("OnInstanceCompactChanged", function() ManagerUI:RefreshList() end)
ns:On("OnResetAll", function() ManagerUI:RefreshList() end)
ns:On("OnGridOverlayToggled", function() UpdateGridButtonVisual() end)

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
        ns:PlaySound("CLICK")
        if _G.HideUIPanel and _G.SettingsPanel then
            _G.HideUIPanel(_G.SettingsPanel)
        end
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
                ns:PlaySound("CLICK")
                ns.db.settings.showBadges = not ns.db.settings.showBadges
                BadgeUI:RefreshAll()
            elseif btn == "MiddleButton" then
                Picker:Start()
            else
                ns:PlaySound("CLICK")
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
    elseif cmd == "grid" or cmd == "raster" or cmd == "overlay" then
        if ns.GridOverlay then
            local state = ns.GridOverlay:Toggle()
            ns:Print(state and L["MSG_GRID_ENABLED"] or L["MSG_GRID_DISABLED"])
        end
    elseif cmd == "panic" or cmd == "boss" or cmd == "hideall" then
        Engine:ToggleBossKey()
    elseif cmd == "compact" or cmd == "80" then
        Profiles:ApplyPreset("COMPACT_80")
    elseif cmd == "badges" or cmd == "badge" then
        ns:PlaySound("CLICK")
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
    elseif cmd == "test" or cmd == "selftest" then
        if ns.RunSelfTest then
            ns:RunSelfTest()
        end
    elseif cmd == "reset" then
        Profiles:ResetAll()
    elseif cmd == "help" or cmd == "?" then
        ns:Print(L["SLASH_HELP_HEADER"])
        ns:Print(L["SLASH_HELP_OPEN"])
        ns:Print(L["SLASH_HELP_TOUR"])
        ns:Print(L["SLASH_HELP_PICK"])
        ns:Print(L["SLASH_HELP_GRID"])
        ns:Print(L["SLASH_HELP_PANIC"])
        ns:Print(L["SLASH_HELP_PRESET"])
        ns:Print(L["SLASH_HELP_BADGES"])
        ns:Print(L["SLASH_HELP_PROFILE"])
        ns:Print(L["SLASH_HELP_UNDO"])
        ns:Print(L["SLASH_HELP_TEST"])
        ns:Print(L["SLASH_HELP_RESET"])
    else
        ManagerUI:Toggle()
    end
end
