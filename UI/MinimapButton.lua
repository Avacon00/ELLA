local AddonName, ns = ...

local L = ns.L
local Profiles = ns.Profiles

local MinimapButton = {}
ns.MinimapButton = MinimapButton

local ICON_PATH = "Interface\\AddOns\\ELLA\\Media\\Icon"
local BORDER_PATH = "Interface\\Minimap\\MiniMap-TrackingBorder"

local btn = nil
local isDragging = false
local menuFrame = nil

local function GetMinimapRadius()
    if _G.Minimap then
        local w = _G.Minimap:GetWidth() or 140
        if w < 50 then
            w = 140
        end
        return (w / 2) + 8
    end
    return 78
end

function MinimapButton:UpdatePosition()
    if not btn or not _G.Minimap then
        return
    end
    local deg = tonumber(ns.db and ns.db.settings and ns.db.settings.minimapPos) or 220
    local rad = math.rad(deg)
    local radius = GetMinimapRadius()
    local x = math.cos(rad) * radius
    local y = math.sin(rad) * radius

    btn:ClearAllPoints()
    btn:SetPoint("CENTER", _G.Minimap, "CENTER", x, y)
end

function MinimapButton:UpdateVisibility()
    if not btn then
        return
    end
    if ns.db and ns.db.settings and ns.db.settings.showMinimapButton then
        btn:Show()
    else
        btn:Hide()
    end
end

local function OnDragUpdate(self)
    if not _G.Minimap then
        return
    end
    local mx, my = _G.Minimap:GetCenter()
    if not mx or not my then
        return
    end
    local cx, cy = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale() or 1.0
    cx, cy = cx / scale, cy / scale

    local deg = math.deg(math.atan2(cy - my, cx - mx))
    if deg < 0 then
        deg = deg + 360
    end
    deg = math.floor(deg + 0.5)

    if ns.db and ns.db.settings then
        ns.db.settings.minimapPos = deg
    end
    MinimapButton:UpdatePosition()
end

local BACKDROP_TEMPLATE = _G.BackdropTemplateMixin and "BackdropTemplate" or nil

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

local quickMenuFrame = nil

local function GetOrCreateQuickMenu()
    if quickMenuFrame then
        return quickMenuFrame
    end

    local qm = CreateFrame("Frame", "EllaMinimapQuickMenuFrame", UIParent, BACKDROP_TEMPLATE)
    qm:SetSize(220, 320)
    qm:SetFrameStrata("DIALOG")
    qm:SetFrameLevel(250)
    qm:EnableMouse(true)
    qm:SetClampedToScreen(true)
    StyleBox(qm, 0.05, 0.06, 0.09, 0.98, 0.78, 0.65, 0.25, 0.95)

    if _G.UISpecialFrames then
        table.insert(_G.UISpecialFrames, "EllaMinimapQuickMenuFrame")
    end

    local title = qm:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetText(L["QUICKMENU_TITLE"] or "Ella Schnellauswahl")
    title:SetTextColor(1.0, 0.82, 0.25)
    qm.title = title

    local closeBtn = CreateFrame("Button", nil, qm, "UIPanelCloseButton")
    closeBtn:SetSize(20, 20)
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function()
        qm:Hide()
    end)

    local profHeader = qm:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    profHeader:SetPoint("TOPLEFT", 12, -34)
    profHeader:SetText("» " .. (L["QUICKMENU_PROFILES"] or "Profile") .. ":")
    profHeader:SetTextColor(0.0, 0.85, 1.0)
    qm.profHeader = profHeader

    qm.profileButtons = {}

    local presetHeader = qm:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    presetHeader:SetText("» " .. (L["QUICKMENU_PRESETS"] or "Presets") .. ":")
    presetHeader:SetTextColor(0.0, 0.85, 1.0)
    qm.presetHeader = presetHeader

    local presetDefs = {
        { id = "DEFAULT_100", label = L["PRESET_DEFAULT_NAME"] or "Standard (100%)" },
        { id = "COMPACT_80", label = L["PRESET_COMPACT80_NAME"] or "Classic (80%)" },
        { id = "WQHD_85", label = L["PRESET_WQHD85_NAME"] or "WQHD / 4K (85%)" },
        { id = "LAPTOP_72", label = L["PRESET_LAPTOP72_NAME"] or "Laptop / Deck (72%)" },
    }
    qm.presetButtons = {}
    for i = 1, #presetDefs do
        local pd = presetDefs[i]
        local pBtn = CreateFrame("Button", nil, qm, "UIPanelButtonTemplate")
        pBtn:SetSize(196, 20)
        ApplyCompactButtonFont(pBtn)
        pBtn:SetText(pd.label)
        pBtn:SetScript("OnClick", function()
            if Profiles and Profiles.ApplyPreset then
                Profiles:ApplyPreset(pd.id)
                if ns.ManagerUI and ns.ManagerUI.RefreshList then
                    ns.ManagerUI:RefreshList()
                end
            end
            qm:Hide()
        end)
        qm.presetButtons[i] = pBtn
    end

    local toolsHeader = qm:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    toolsHeader:SetText("» " .. (L["UI_SEC_DISPLAY_SYSTEM"] or "Werkzeuge") .. ":")
    toolsHeader:SetTextColor(0.0, 0.85, 1.0)
    qm.toolsHeader = toolsHeader

    local pickerBtn = CreateFrame("Button", nil, qm, "UIPanelButtonTemplate")
    pickerBtn:SetSize(196, 20)
    ApplyCompactButtonFont(pickerBtn)
    pickerBtn:SetText(L["QUICKMENU_PICKER"] or "Fenster-Picker...")
    pickerBtn:SetScript("OnClick", function()
        qm:Hide()
        if ns.Picker and ns.Picker.Start then
            ns.Picker:Start(false)
        end
    end)
    qm.pickerBtn = pickerBtn

    local gridBtn = CreateFrame("Button", nil, qm, "UIPanelButtonTemplate")
    gridBtn:SetSize(196, 20)
    ApplyCompactButtonFont(gridBtn)
    gridBtn:SetText(L["UI_BTN_GRID"] or "# Bildschirm-Gitter")
    gridBtn:SetScript("OnClick", function()
        qm:Hide()
        if ns.GridOverlay then
            local state = ns.GridOverlay:Toggle()
            ns:Print(state and L["MSG_GRID_ENABLED"] or L["MSG_GRID_DISABLED"])
        end
    end)
    qm.gridBtn = gridBtn

    local tourBtn = CreateFrame("Button", nil, qm, "UIPanelButtonTemplate")
    tourBtn:SetSize(196, 20)
    ApplyCompactButtonFont(tourBtn)
    tourBtn:SetText(L["QUICKMENU_TUTORIAL"] or "Tutorial Tour starten...")
    tourBtn:SetScript("OnClick", function()
        qm:Hide()
        if ns.Tutorial and ns.Tutorial.Start then
            ns.Tutorial:Start(1)
        end
    end)
    qm.tourBtn = tourBtn

    local hint = qm:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("BOTTOM", 0, 8)
    hint:SetText(L["MINIMAP_TOOLTIP_SHIFT"] or "Shift + Klick: Nächstes Profil")
    qm.hint = hint

    quickMenuFrame = qm
    return qm
end

local function RefreshQuickMenu()
    local qm = GetOrCreateQuickMenu()
    local activeProf = (Profiles and Profiles.GetActiveProfileName and Profiles:GetActiveProfileName()) or "Default"
    local allProfs = (Profiles and Profiles.ListProfiles and Profiles:ListProfiles()) or { "Default" }

    local curY = -50
    for i = 1, #allProfs do
        local pName = allProfs[i]
        local pBtn = qm.profileButtons[i]
        if not pBtn then
            pBtn = CreateFrame("Button", nil, qm, "UIPanelButtonTemplate")
            pBtn:SetSize(196, 22)
            ApplyCompactButtonFont(pBtn)
            qm.profileButtons[i] = pBtn
        end
        pBtn:ClearAllPoints()
        pBtn:SetPoint("TOPLEFT", 12, curY)
        pBtn:SetText((pName == activeProf and "» " or "") .. pName .. (pName == activeProf and " «" or ""))
        local fs = pBtn:GetFontString()
        if fs then
            if pName == activeProf then
                fs:SetTextColor(0.0, 1.0, 0.59)
            else
                fs:SetTextColor(0.9, 0.9, 0.9)
            end
        end
        pBtn:SetScript("OnClick", function()
            if Profiles and Profiles.SwitchProfile then
                Profiles:SwitchProfile(pName)
                if ns.ManagerUI and ns.ManagerUI.RefreshList then
                    ns.ManagerUI:RefreshList()
                end
            end
            qm:Hide()
        end)
        pBtn:Show()
        curY = curY - 24
    end

    for i = #allProfs + 1, #qm.profileButtons do
        qm.profileButtons[i]:Hide()
    end

    curY = curY - 6
    qm.presetHeader:ClearAllPoints()
    qm.presetHeader:SetPoint("TOPLEFT", 12, curY)
    curY = curY - 18

    for i = 1, #qm.presetButtons do
        local pBtn = qm.presetButtons[i]
        pBtn:ClearAllPoints()
        pBtn:SetPoint("TOPLEFT", 12, curY)
        curY = curY - 22
    end

    curY = curY - 6
    qm.toolsHeader:ClearAllPoints()
    qm.toolsHeader:SetPoint("TOPLEFT", 12, curY)
    curY = curY - 18

    qm.pickerBtn:ClearAllPoints()
    qm.pickerBtn:SetPoint("TOPLEFT", 12, curY)
    curY = curY - 22

    qm.gridBtn:ClearAllPoints()
    qm.gridBtn:SetPoint("TOPLEFT", 12, curY)
    curY = curY - 22

    qm.tourBtn:ClearAllPoints()
    qm.tourBtn:SetPoint("TOPLEFT", 12, curY)
    curY = curY - 24

    local totalH = math.abs(curY) + 24
    qm:SetHeight(totalH)
end

local function ToggleQuickMenu(anchorFrame)
    local qm = GetOrCreateQuickMenu()
    if qm:IsShown() then
        qm:Hide()
        return
    end

    RefreshQuickMenu()

    local btnFrame = anchorFrame or btn
    qm:ClearAllPoints()

    if btnFrame and btnFrame.GetCenter then
        local uipScale = UIParent:GetEffectiveScale() or 1.0
        local bScale = btnFrame:GetEffectiveScale() or uipScale
        local scaleRatio = bScale / uipScale
        local left = (btnFrame:GetLeft() or 0) * scaleRatio
        local right = (btnFrame:GetRight() or 0) * scaleRatio
        local top = (btnFrame:GetTop() or 0) * scaleRatio
        local bottom = (btnFrame:GetBottom() or 0) * scaleRatio
        local uipW = UIParent:GetWidth() or 1920
        local uipH = UIParent:GetHeight() or 1080

        if left > (uipW * 0.5) then
            qm:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", left - 8, math.min(top + 10, uipH - 20))
        else
            qm:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", right + 8, math.min(top + 10, uipH - 20))
        end
    else
        qm:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    qm:Show()
end

function MinimapButton:Init()
    if btn or not _G.Minimap then
        return
    end

    -- Parent to MinimapBackdrop, MinimapCluster, or UIParent (NEVER _G.Minimap directly!)
    -- Minimap has an internal mask texture that clips children outside its circular viewport.
    local parentFrame = _G.MinimapBackdrop or _G.MinimapCluster or _G.UIParent
    btn = CreateFrame("Button", "EllaMinimapButton", parentFrame)
    btn:SetSize(32, 32)
    btn:SetFrameStrata("HIGH")
    btn:SetFrameLevel(20)
    btn:EnableMouse(true)
    btn:SetMovable(true)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
    btn:RegisterForDrag("LeftButton")

    -- Dark circular backdrop behind icon
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(22, 22)
    bg:SetPoint("CENTER", 0, 0)
    bg:SetColorTexture(0.05, 0.06, 0.09, 0.95)

    -- Custom Ella Logo Icon
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", 0, 0)
    icon:SetTexture(ICON_PATH)
    btn.icon = icon

    -- Circular Blizzard border overlay
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(52, 52)
    border:SetPoint("TOPLEFT", btn, "TOPLEFT", -2, 2)
    border:SetTexture(BORDER_PATH)

    -- Subtle hover highlight
    local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetSize(24, 24)
    highlight:SetPoint("CENTER", 0, 0)
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetBlendMode("ADD")

    -- Dragging around Minimap
    btn:SetScript("OnDragStart", function(self)
        isDragging = true
        self:SetScript("OnUpdate", OnDragUpdate)
    end)
    btn:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        if _G.C_Timer and _G.C_Timer.After then
            _G.C_Timer.After(0.1, function()
                isDragging = false
            end)
        else
            isDragging = false
        end
    end)

    -- Click actions
    btn:SetScript("OnClick", function(self, button)
        if isDragging then
            return
        end
        if _G.IsShiftKeyDown and _G.IsShiftKeyDown() then
            if Profiles and Profiles.CycleNextProfile then
                Profiles:CycleNextProfile()
                if ns.ManagerUI and ns.ManagerUI.RefreshList then
                    ns.ManagerUI:RefreshList()
                end
            end
            return
        end
        if button == "RightButton" then
            ToggleQuickMenu(self)
        elseif button == "MiddleButton" then
            if ns.Picker and ns.Picker.Start then
                ns.Picker:Start(false)
            end
        else
            if ns.ManagerUI and ns.ManagerUI.Toggle then
                ns.ManagerUI:Toggle()
            end
        end
    end)

    -- Tooltip
    btn:SetScript("OnEnter", function(self)
        if _G.GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:AddLine(L["MINIMAP_TOOLTIP_TITLE"], 1, 0.82, 0)
            local curProf = Profiles and Profiles.GetActiveProfileName and Profiles:GetActiveProfileName() or "Default"
            GameTooltip:AddLine(string.format("» Profil: |cff00ff96%s|r", curProf), 0.9, 0.9, 0.9)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L["MINIMAP_TOOLTIP_LCLICK"], 1, 1, 1)
            GameTooltip:AddLine(L["MINIMAP_TOOLTIP_RCLICK"], 1, 1, 1)
            GameTooltip:AddLine(L["MINIMAP_TOOLTIP_SHIFT"], 1, 1, 1)
            GameTooltip:AddLine(L["MINIMAP_TOOLTIP_MCLICK"], 1, 1, 1)
            GameTooltip:AddLine(L["MINIMAP_TOOLTIP_DRAG"], 1, 1, 1)
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function()
        if _G.GameTooltip then
            GameTooltip:Hide()
        end
    end)

    MinimapButton:UpdatePosition()
    MinimapButton:UpdateVisibility()

    -- LibDataBroker Support (TitanPanel, ChocolateBar, Bazooka)
    if _G.LibStub then
        local ldb = _G.LibStub:GetLibrary("LibDataBroker-1.1", true)
        if ldb and not ldb:GetDataObjectByName("ELLA") then
            ldb:NewDataObject("ELLA", {
                type = "launcher",
                icon = ICON_PATH,
                OnClick = function(clickedFrame, clickBtn)
                    if _G.IsShiftKeyDown and _G.IsShiftKeyDown() then
                        if Profiles and Profiles.CycleNextProfile then
                            Profiles:CycleNextProfile()
                            if ns.ManagerUI and ns.ManagerUI.RefreshList then
                                ns.ManagerUI:RefreshList()
                            end
                        end
                        return
                    end
                    if clickBtn == "RightButton" then
                        ToggleQuickMenu(clickedFrame)
                    elseif clickBtn == "MiddleButton" then
                        if ns.Picker and ns.Picker.Start then
                            ns.Picker:Start(false)
                        end
                    else
                        if ns.ManagerUI and ns.ManagerUI.Toggle then
                            ns.ManagerUI:Toggle()
                        end
                    end
                end,
                OnTooltipShow = function(tooltip)
                    tooltip:AddLine(L["MINIMAP_TOOLTIP_TITLE"], 1, 0.82, 0)
                    local curProf = Profiles and Profiles.GetActiveProfileName and Profiles:GetActiveProfileName() or "Default"
                    tooltip:AddLine(string.format("» Profil: |cff00ff96%s|r", curProf), 0.9, 0.9, 0.9)
                    tooltip:AddLine(" ")
                    tooltip:AddLine(L["MINIMAP_TOOLTIP_LCLICK"], 1, 1, 1)
                    tooltip:AddLine(L["MINIMAP_TOOLTIP_RCLICK"], 1, 1, 1)
                    tooltip:AddLine(L["MINIMAP_TOOLTIP_SHIFT"], 1, 1, 1)
                    tooltip:AddLine(L["MINIMAP_TOOLTIP_MCLICK"], 1, 1, 1)
                end,
            })
        end
    end
end

-- Initialize safely on PLAYER_LOGIN, or immediately if player is already logged in
if _G.IsLoggedIn and _G.IsLoggedIn() then
    MinimapButton:Init()
else
    local initFrame = CreateFrame("Frame")
    initFrame:RegisterEvent("PLAYER_LOGIN")
    initFrame:SetScript("OnEvent", function()
        MinimapButton:Init()
    end)
end
