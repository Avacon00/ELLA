local AddonName, ns = ...

local L = ns.L
local Guard = ns.Guard
local Registry = ns.Registry

local Picker = {
    active = false,
    reopenManager = false,
}
ns.Picker = Picker

local BACKDROP_TEMPLATE = _G.BackdropTemplateMixin and "BackdropTemplate" or nil
local bannerFrame = nil
local highlightBox = nil
local pickerHud = nil
local pickerOverlay = nil
local snippetModal = nil

local currentHierarchyStack = {}
local currentHierarchyIndex = 1
local lastLeafFrame = nil
local lastTopAncestor = nil

local currentCandidate = nil
local currentCandidateName = nil
local armedForLeftClick = false
local blockedFeedbackPrinted = false

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

-- Compatible mouse-focus helper for WoW 16001 (GetMouseFoci) + fallback
local function GetTopMouseFrame()
    if type(_G.GetMouseFoci) == "function" then
        local foci = _G.GetMouseFoci()
        if type(foci) == "table" then
            for i = 1, #foci do
                local f = foci[i]
                if f and f ~= bannerFrame and f ~= highlightBox and f ~= pickerOverlay and f ~= pickerHud and f ~= snippetModal and not Guard:IsForbidden(f) then
                    return f
                end
            end
        end
    elseif type(_G.GetMouseFocus) == "function" then
        local f = _G.GetMouseFocus()
        if f and f ~= bannerFrame and f ~= highlightBox and f ~= pickerOverlay and f ~= pickerHud and f ~= snippetModal and not Guard:IsForbidden(f) then
            return f
        end
    end
    return nil
end

-- Builds full ancestor chain of named frames from leaf up to UIParent
local function BuildFrameHierarchy(leafFrame)
    local stack = {}
    if not leafFrame or Guard:IsForbidden(leafFrame) then
        return stack
    end

    local cursor = leafFrame
    local depth = 0
    while cursor and cursor ~= _G.UIParent and cursor ~= _G.WorldFrame and depth < 20 do
        if Guard:IsForbidden(cursor) then
            break
        end
        local name = type(cursor.GetName) == "function" and cursor:GetName()
        if name and name ~= "" and _G[name] == cursor then
            stack[#stack + 1] = cursor
        end
        local parent = type(cursor.GetParent) == "function" and cursor:GetParent() or nil
        if not parent or parent == _G.UIParent or parent == _G.WorldFrame then
            break
        end
        cursor = parent
        depth = depth + 1
    end

    return stack
end

local function ShowSnippetModal(frameName)
    if not snippetModal then
        local m = CreateFrame("Frame", "EllaPickerSnippetModal", UIParent, BACKDROP_TEMPLATE)
        m:SetSize(440, 210)
        m:SetPoint("CENTER", 0, 40)
        m:SetFrameStrata("FULLSCREEN_DIALOG")
        m:EnableMouse(true)
        m:SetClampedToScreen(true)
        RegisterSpecialFrameOnce("EllaPickerSnippetModal")
        if m.SetBackdrop then
            m:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true,
                tileSize = 8,
                edgeSize = 12,
                insets = { left = 3, right = 3, top = 3, bottom = 3 },
            })
            m:SetBackdropColor(0.06, 0.07, 0.10, 0.97)
            m:SetBackdropBorderColor(0.85, 0.70, 0.25, 1)
        end

        local title = m:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOPLEFT", 14, -12)
        m.title = title

        local boxBorder = CreateFrame("Frame", nil, m, BACKDROP_TEMPLATE)
        boxBorder:SetPoint("TOPLEFT", 14, -36)
        boxBorder:SetPoint("BOTTOMRIGHT", -14, 42)
        if boxBorder.SetBackdrop then
            boxBorder:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true,
                tileSize = 8,
                edgeSize = 10,
                insets = { left = 2, right = 2, top = 2, bottom = 2 },
            })
            boxBorder:SetBackdropColor(0.02, 0.02, 0.03, 0.95)
            boxBorder:SetBackdropBorderColor(0.4, 0.4, 0.45, 0.9)
        end

        local scroll = CreateFrame("ScrollFrame", nil, boxBorder, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 6, -6)
        scroll:SetPoint("BOTTOMRIGHT", -26, 6)

        local editBox = CreateFrame("EditBox", nil, scroll)
        editBox:SetMultiLine(true)
        editBox:SetAutoFocus(false)
        editBox:SetFontObject("ChatFontNormal")
        editBox:SetWidth(370)
        editBox:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
            m:Hide()
        end)
        scroll:SetScrollChild(editBox)
        m.editBox = editBox

        local closeBtn = CreateFrame("Button", nil, m, "UIPanelButtonTemplate")
        closeBtn:SetSize(110, 24)
        closeBtn:SetPoint("BOTTOMRIGHT", -14, 10)
        closeBtn:SetText(L["UI_BTN_CLOSE"])
        closeBtn:SetScript("OnClick", function()
            m:Hide()
        end)

        snippetModal = m
    end

    local safeKey = string.upper(string.gsub(frameName, "[^%w]", "_"))
    local isProt = (_G[frameName] and _G[frameName].IsProtected and _G[frameName]:IsProtected()) and "true" or "false"
    local snippet = string.format(
        'Registry:RegisterWindow("%s", {\n    frame = "%s",\n    label = "%s",\n    category = "CAT_CUSTOM",\n    defaultCompactScale = 0.82,\n    protected = %s,\n})',
        safeKey,
        frameName,
        frameName,
        isProt
    )

    snippetModal.title:SetText(string.format(L["PICKER_SNIPPET_TITLE"], frameName))
    snippetModal.editBox:SetText(snippet)
    snippetModal:Show()
    snippetModal.editBox:HighlightText()
    snippetModal.editBox:SetFocus()
end

local function EnsurePickerFrames()
    if bannerFrame then
        return
    end

    highlightBox = CreateFrame("Frame", nil, UIParent, BACKDROP_TEMPLATE)
    highlightBox:SetFrameStrata("FULLSCREEN_DIALOG")
    highlightBox:EnableMouse(false)
    if highlightBox.SetBackdrop then
        highlightBox:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 8,
            edgeSize = 12,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
    end
    highlightBox:Hide()

    -- Floating Cursor Inspection HUD Tooltip (Picker 2.0)
    pickerHud = CreateFrame("Frame", nil, UIParent, BACKDROP_TEMPLATE)
    pickerHud:SetSize(410, 86)
    pickerHud:SetFrameStrata("TOOLTIP")
    pickerHud:SetFrameLevel(9000)
    pickerHud:EnableMouse(false)
    if pickerHud.SetBackdrop then
        pickerHud:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 8,
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        pickerHud:SetBackdropColor(0.05, 0.07, 0.11, 0.96)
        pickerHud:SetBackdropBorderColor(0.0, 0.85, 1.0, 0.95)
    end
    pickerHud:Hide()

    local hudName = pickerHud:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hudName:SetPoint("TOPLEFT", 10, -8)
    hudName:SetPoint("TOPRIGHT", -10, -8)
    hudName:SetJustifyH("LEFT")
    pickerHud.hudName = hudName

    local hudSize = pickerHud:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hudSize:SetPoint("TOPLEFT", hudName, "BOTTOMLEFT", 0, -4)
    hudSize:SetPoint("TOPRIGHT", hudName, "BOTTOMRIGHT", 0, -4)
    hudSize:SetJustifyH("LEFT")
    pickerHud.hudSize = hudSize

    local hudStatus = pickerHud:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hudStatus:SetPoint("TOPLEFT", hudSize, "BOTTOMLEFT", 0, -4)
    hudStatus:SetPoint("TOPRIGHT", hudSize, "BOTTOMRIGHT", 0, -4)
    hudStatus:SetJustifyH("LEFT")
    pickerHud.hudStatus = hudStatus

    local hudControls = pickerHud:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hudControls:SetPoint("TOPLEFT", hudStatus, "BOTTOMLEFT", 0, -5)
    hudControls:SetPoint("TOPRIGHT", hudStatus, "BOTTOMRIGHT", 0, -5)
    hudControls:SetJustifyH("LEFT")
    hudControls:SetText(L["PICKER_HUD_CONTROLS"])
    pickerHud.hudControls = hudControls

    -- Fullscreen mousewheel listener that never interferes with underlying frame scripts
    pickerOverlay = CreateFrame("Frame", nil, UIParent)
    pickerOverlay:SetAllPoints(UIParent)
    pickerOverlay:SetFrameStrata("FULLSCREEN_DIALOG")
    pickerOverlay:EnableMouse(false)
    pickerOverlay:EnableMouseWheel(true)
    pickerOverlay:Hide()

    pickerOverlay:SetScript("OnMouseWheel", function(_, delta)
        if not Picker.active or #currentHierarchyStack <= 1 then
            return
        end
        if delta > 0 then
            if currentHierarchyIndex < #currentHierarchyStack then
                currentHierarchyIndex = currentHierarchyIndex + 1
            end
        elseif delta < 0 then
            if currentHierarchyIndex > 1 then
                currentHierarchyIndex = currentHierarchyIndex - 1
            end
        end
    end)

    bannerFrame = CreateFrame("Button", "EllaPickerBanner", UIParent, BACKDROP_TEMPLATE)
    bannerFrame:SetSize(540, 70)
    bannerFrame:SetPoint("TOP", UIParent, "TOP", 0, -24)
    bannerFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    bannerFrame:EnableMouse(true)
    bannerFrame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    RegisterSpecialFrameOnce("EllaPickerBanner")
    if bannerFrame.SetBackdrop then
        bannerFrame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 8,
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        bannerFrame:SetBackdropColor(0.06, 0.08, 0.12, 0.95)
        bannerFrame:SetBackdropBorderColor(0.0, 0.85, 1.0, 0.95)
    end

    local title = bannerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetText(L["PICKER_BANNER_TITLE"] .. " 2.0")

    local help = bannerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    help:SetPoint("TOP", title, "BOTTOM", 0, -4)
    help:SetText(L["PICKER_BANNER_HELP"])

    local status = bannerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    status:SetPoint("BOTTOM", 0, 8)
    bannerFrame.status = status

    bannerFrame:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            Picker:Stop()
        end
    end)
    bannerFrame:SetScript("OnHide", function()
        if Picker.active then
            Picker:Stop()
        end
    end)
    bannerFrame:Hide()
end

local function UpdateFloatingHud(targetFrame, winName, ok, reason, existingDesc)
    if not pickerHud or not targetFrame then
        return
    end

    local fW = math.floor((targetFrame:GetWidth() or 0) + 0.5)
    local fH = math.floor((targetFrame:GetHeight() or 0) + 0.5)

    pickerHud.hudName:SetText(string.format(L["PICKER_HUD_NAME"], winName or "<anonymous>"))
    pickerHud.hudSize:SetText(string.format(L["PICKER_HUD_SIZE"], fW, fH, currentHierarchyIndex, #currentHierarchyStack))

    if existingDesc then
        pickerHud.hudStatus:SetText(string.format(L["PICKER_HUD_MANAGED"], Registry:GetDisplayLabel(existingDesc)))
        pickerHud:SetBackdropBorderColor(1.0, 0.82, 0.15, 0.95)
        if highlightBox.SetBackdropColor then
            highlightBox:SetBackdropColor(0.95, 0.75, 0.10, 0.18)
            highlightBox:SetBackdropBorderColor(1.0, 0.82, 0.15, 0.95)
        end
        bannerFrame.status:SetText(string.format(L["PICKER_ALREADY_MANAGED"], winName, Registry:GetDisplayLabel(existingDesc)))
    elseif ok then
        pickerHud.hudStatus:SetText(L["PICKER_HUD_SAFE"])
        pickerHud:SetBackdropBorderColor(0.0, 0.95, 0.50, 0.95)
        if highlightBox.SetBackdropColor then
            highlightBox:SetBackdropColor(0.0, 0.85, 0.45, 0.18)
            highlightBox:SetBackdropBorderColor(0.0, 0.95, 0.50, 0.95)
        end
        bannerFrame.status:SetText(string.format(L["PICKER_SAFE"], winName))
    else
        pickerHud.hudStatus:SetText(string.format(L["PICKER_HUD_BLOCKED"], tostring(reason or "")))
        pickerHud:SetBackdropBorderColor(0.95, 0.25, 0.25, 0.95)
        if highlightBox.SetBackdropColor then
            highlightBox:SetBackdropColor(0.90, 0.15, 0.15, 0.18)
            highlightBox:SetBackdropBorderColor(0.95, 0.25, 0.25, 0.95)
        end
        bannerFrame.status:SetText(string.format(L["PICKER_BLOCKED"], tostring(winName or "<anonymous>"), tostring(reason or "")))
    end

    local h1 = pickerHud.hudName:GetStringHeight() or 14
    local h2 = pickerHud.hudSize:GetStringHeight() or 12
    local h3 = pickerHud.hudStatus:GetStringHeight() or 14
    local h4 = pickerHud.hudControls:GetStringHeight() or 12
    local hudW = 410
    local hudH = math.max(82, math.ceil(h1 + h2 + h3 + h4 + 30))
    pickerHud:SetSize(hudW, hudH)

    local curX, curY = GetCursorPosition()
    local uipScale = UIParent:GetEffectiveScale() or 1
    local uipW = UIParent:GetWidth() or 1920
    local uipH = UIParent:GetHeight() or 1080

    local cX = curX / uipScale
    local cY = (curY / uipScale) - uipH

    local targetX = cX + 22
    local targetY = cY - 20

    if (targetX + hudW) > (uipW - 12) then
        targetX = cX - hudW - 22
    end
    if (targetY - hudH) < (-uipH + 12) then
        targetY = cY + hudH + 20
    end

    pickerHud:ClearAllPoints()
    pickerHud:SetPoint("TOPLEFT", UIParent, "TOPLEFT", targetX, targetY)
    pickerHud:Show()
end

local function OnPickerUpdate()
    if not Picker.active then
        bannerFrame:SetScript("OnUpdate", nil)
        return
    end

    if IsMouseButtonDown("RightButton") then
        Picker:Stop()
        return
    end

    local leaf = GetTopMouseFrame()
    if leaf ~= lastLeafFrame then
        lastLeafFrame = leaf
        local newStack = BuildFrameHierarchy(leaf)
        if #newStack > 0 then
            local newTop = newStack[#newStack]
            if newTop ~= lastTopAncestor then
                lastTopAncestor = newTop
                currentHierarchyStack = newStack
                currentHierarchyIndex = #newStack
            else
                currentHierarchyStack = newStack
                if currentHierarchyIndex > #newStack then
                    currentHierarchyIndex = #newStack
                end
            end
        else
            currentHierarchyStack = {}
            currentHierarchyIndex = 1
            lastTopAncestor = nil
        end
    end

    local targetWin = currentHierarchyStack[currentHierarchyIndex]

    if not targetWin then
        currentCandidate = nil
        currentCandidateName = nil
        highlightBox:Hide()
        pickerHud:Hide()
        bannerFrame.status:SetText("-")
        return
    end

    local winName = type(targetWin.GetName) == "function" and targetWin:GetName() or nil
    local ok, reason = Guard:ValidateTarget(targetWin)
    if ok and (not winName or winName == "" or _G[winName] ~= targetWin) then
        ok = false
        reason = L["GUARD_ERR_UNSAFE"]
    end

    local existingId, existingDesc = nil, nil
    if winName then
        existingId, existingDesc = Registry:FindByFrameName(winName)
    end

    highlightBox:ClearAllPoints()
    highlightBox:SetAllPoints(targetWin)
    highlightBox:Show()

    currentCandidate = targetWin
    currentCandidateName = winName

    UpdateFloatingHud(targetWin, winName, ok, reason, existingDesc)

    local isLeftDown = IsMouseButtonDown("LeftButton")
    if not isLeftDown then
        armedForLeftClick = true
        blockedFeedbackPrinted = false
    elseif armedForLeftClick and not bannerFrame:IsMouseOver() then
        if (ok or existingDesc) and winName and winName ~= "" then
            local pickedName = winName
            Picker:Stop()
            Picker:RegisterPickedWindow(pickedName)
        elseif not blockedFeedbackPrinted then
            blockedFeedbackPrinted = true
            ns:Print(string.format(L["PICKER_BLOCKED"], tostring(winName or "<anonymous>"), tostring(reason or L["GUARD_ERR_UNSAFE"])))
        end
    end
end

function Picker:RegisterPickedWindow(frameName)
    if not frameName or frameName == "" then
        return
    end
    if Guard.IsBlacklistedName and Guard:IsBlacklistedName(frameName) then
        ns:Print(string.format(L["PICKER_BLOCKED"], tostring(frameName), L["GUARD_ERR_EDITMODE"]))
        return
    end

    local existingId, existingDesc = Registry:FindByFrameName(frameName)
    if existingId and existingDesc then
        ns:Print(string.format(L["PICKER_ALREADY_MANAGED"], frameName, Registry:GetDisplayLabel(existingDesc)))
        if ns.BadgeUI and ns.BadgeUI.OpenPopoverForWindow then
            ns.BadgeUI:OpenPopoverForWindow(existingId)
        end
        return
    end

    ns.db.customWindows[frameName] = {
        label = frameName,
    }
    local windowId = "CUSTOM_" .. frameName
    Registry:RegisterWindow(windowId, {
        frame = frameName,
        label = frameName,
        category = "CAT_CUSTOM",
        defaultCompactScale = 0.85,
        isCustom = true,
        source = "UserPicker",
    })
    ns:Print(string.format(L["PICKER_ADDED"], frameName))

    if ns.BadgeUI then
        if ns.BadgeUI.RefreshAll then
            ns.BadgeUI:RefreshAll()
        end
        if ns.BadgeUI.OpenPopoverForWindow then
            ns.BadgeUI:OpenPopoverForWindow(windowId)
        end
    end

    ShowSnippetModal(frameName)
end

function Picker:Start(reopenManager)
    EnsurePickerFrames()
    Picker.active = true
    Picker.reopenManager = (reopenManager == true)
    armedForLeftClick = not IsMouseButtonDown("LeftButton")
    blockedFeedbackPrinted = false
    currentCandidate = nil
    currentCandidateName = nil
    lastLeafFrame = nil
    lastTopAncestor = nil
    currentHierarchyStack = {}
    currentHierarchyIndex = 1

    ns:PlaySound("CLICK")
    bannerFrame:Show()
    pickerOverlay:Show()
    -- Golden Rule #8: OnUpdate runs ONLY while interactive picker mode is open
    bannerFrame:SetScript("OnUpdate", OnPickerUpdate)
end

function Picker:Stop()
    Picker.active = false
    local shouldReopen = Picker.reopenManager
    Picker.reopenManager = false
    currentCandidate = nil
    currentCandidateName = nil
    lastLeafFrame = nil
    lastTopAncestor = nil
    wipe(currentHierarchyStack)

    if bannerFrame then
        bannerFrame:SetScript("OnUpdate", nil)
        bannerFrame:Hide()
    end
    if pickerOverlay then
        pickerOverlay:Hide()
    end
    if highlightBox then
        highlightBox:Hide()
    end
    if pickerHud then
        pickerHud:Hide()
    end
    if shouldReopen and ns.ManagerUI and type(ns.ManagerUI.Show) == "function" then
        ns.ManagerUI:Show()
    end
end
