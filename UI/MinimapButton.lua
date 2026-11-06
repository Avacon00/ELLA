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

local function ShowQuickMenu(anchorFrame)
    if not menuFrame then
        menuFrame = CreateFrame("Frame", "EllaMinimapQuickMenu", UIParent, "UIDropDownMenuTemplate")
    end

    local activeProf = Profiles and Profiles.GetActiveProfileName and Profiles:GetActiveProfileName() or "Default"
    local allProfs = Profiles and Profiles.ListProfiles and Profiles:ListProfiles() or { "Default" }

    local profSubmenu = {}
    for i = 1, #allProfs do
        local pName = allProfs[i]
        profSubmenu[#profSubmenu + 1] = {
            text = pName,
            checked = (pName == activeProf),
            func = function()
                if Profiles and Profiles.SwitchProfile then
                    Profiles:SwitchProfile(pName)
                    if ns.ManagerUI and ns.ManagerUI.RefreshList then
                        ns.ManagerUI:RefreshList()
                    end
                end
            end,
        }
    end

    local presetDefs = {
        { id = "DEFAULT_100", label = L["PRESET_DEFAULT_NAME"] },
        { id = "COMPACT_80", label = L["PRESET_COMPACT80_NAME"] },
        { id = "WQHD_85", label = L["PRESET_WQHD85_NAME"] },
        { id = "LAPTOP_72", label = L["PRESET_LAPTOP72_NAME"] },
    }
    local presetSubmenu = {}
    for i = 1, #presetDefs do
        local pd = presetDefs[i]
        presetSubmenu[#presetSubmenu + 1] = {
            text = pd.label,
            notCheckable = true,
            func = function()
                if Profiles and Profiles.ApplyPreset then
                    Profiles:ApplyPreset(pd.id)
                    if ns.ManagerUI and ns.ManagerUI.RefreshList then
                        ns.ManagerUI:RefreshList()
                    end
                end
            end,
        }
    end

    local menuList = {
        { text = "|cffffd100" .. L["QUICKMENU_TITLE"] .. "|r", isTitle = true, notCheckable = true },
        { text = " ", notCheckable = true, disabled = true },
        {
            text = L["QUICKMENU_PROFILES"] .. " (|cff00ff96" .. activeProf .. "|r)",
            hasArrow = true,
            notCheckable = true,
            menuList = profSubmenu,
        },
        {
            text = L["QUICKMENU_PRESETS"],
            hasArrow = true,
            notCheckable = true,
            menuList = presetSubmenu,
        },
        { text = " ", notCheckable = true, disabled = true },
        {
            text = L["QUICKMENU_PICKER"],
            notCheckable = true,
            func = function()
                if ns.Picker and ns.Picker.Start then
                    ns.Picker:Start(false)
                end
            end,
        },
        {
            text = L["QUICKMENU_TUTORIAL"],
            notCheckable = true,
            func = function()
                if ns.Tutorial and ns.Tutorial.Start then
                    ns.Tutorial:Start(1)
                end
            end,
        },
    }

    if _G.EasyMenu then
        _G.EasyMenu(menuList, menuFrame, anchorFrame or "cursor", 0, 0, "MENU")
    end
end

function MinimapButton:Init()
    if btn or not _G.Minimap then
        return
    end

    btn = CreateFrame("Button", "EllaMinimapButton", _G.Minimap)
    btn:SetSize(32, 32)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:EnableMouse(true)
    btn:SetMovable(true)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
    btn:RegisterForDrag("LeftButton")

    -- Dark circular backdrop behind icon
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20)
    bg:SetPoint("CENTER", 0, 0)
    bg:SetColorTexture(0.05, 0.06, 0.09, 0.95)

    -- Custom Ella Logo Icon
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("CENTER", 0, 0)
    icon:SetTexture(ICON_PATH)
    btn.icon = icon

    -- Circular Blizzard border overlay
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(52, 52)
    border:SetPoint("TOPLEFT", 0, 0)
    border:SetTexture(BORDER_PATH)

    -- Subtle hover highlight
    local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetSize(22, 22)
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
        if button == "RightButton" then
            ShowQuickMenu(self)
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
                    if clickBtn == "RightButton" then
                        ShowQuickMenu(clickedFrame)
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
                    tooltip:AddLine(L["MINIMAP_TOOLTIP_MCLICK"], 1, 1, 1)
                end,
            })
        end
    end
end

-- Initialize on PLAYER_LOGIN / VARIABLES_LOADED
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    MinimapButton:Init()
end)
