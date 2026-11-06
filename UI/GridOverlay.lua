local AddonName, ns = ...

local GridOverlay = {}
ns.GridOverlay = GridOverlay

local gridFrame = nil
local gridLines = {}
local GRID_STEP = 32

local function CreateLine(parent)
    local line = parent:CreateTexture(nil, "BACKGROUND")
    line:SetColorTexture(1, 1, 1, 1)
    return line
end

local function BuildGrid()
    if not gridFrame then
        gridFrame = CreateFrame("Frame", "EllaGridOverlay", UIParent)
        gridFrame:SetAllPoints(UIParent)
        gridFrame:SetFrameStrata("BACKGROUND")
        gridFrame:SetFrameLevel(1)
        gridFrame:EnableMouse(false)
        gridFrame:Hide()
    end

    for i = 1, #gridLines do
        gridLines[i]:Hide()
    end
    local lineIdx = 0

    local uipW = UIParent:GetWidth() or 1920
    local uipH = UIParent:GetHeight() or 1080
    local midX = uipW * 0.5
    local midY = uipH * 0.5

    local function AddHLine(y, r, g, b, a, h)
        lineIdx = lineIdx + 1
        local line = gridLines[lineIdx] or CreateLine(gridFrame)
        gridLines[lineIdx] = line
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -y)
        line:SetPoint("TOPRIGHT", UIParent, "TOPLEFT", uipW, -y)
        line:SetHeight(h or 1)
        line:SetColorTexture(r, g, b, a)
        line:Show()
    end

    local function AddVLine(x, r, g, b, a, w)
        lineIdx = lineIdx + 1
        local line = gridLines[lineIdx] or CreateLine(gridFrame)
        gridLines[lineIdx] = line
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, 0)
        line:SetPoint("BOTTOMLEFT", UIParent, "TOPLEFT", x, -uipH)
        line:SetWidth(w or 1)
        line:SetColorTexture(r, g, b, a)
        line:Show()
    end

    -- 1. Standard 32px grid lines (subtle dark blue/white)
    local x = GRID_STEP
    while x < uipW do
        AddVLine(x, 0.4, 0.7, 1.0, 0.08, 1)
        x = x + GRID_STEP
    end

    local y = GRID_STEP
    while y < uipH do
        AddHLine(y, 0.4, 0.7, 1.0, 0.08, 1)
        y = y + GRID_STEP
    end

    -- 2. Rule of Thirds guidelines (Gold accent)
    local thirdW = uipW / 3
    local thirdH = uipH / 3
    AddVLine(thirdW, 1.0, 0.82, 0.0, 0.40, 1.5)
    AddVLine(thirdW * 2, 1.0, 0.82, 0.0, 0.40, 1.5)
    AddHLine(thirdH, 1.0, 0.82, 0.0, 0.40, 1.5)
    AddHLine(thirdH * 2, 1.0, 0.82, 0.0, 0.40, 1.5)

    -- 3. Center Crosshair (Cyan/Gold glowing center lines)
    AddVLine(midX, 0.0, 0.85, 1.0, 0.75, 2)
    AddHLine(midY, 0.0, 0.85, 1.0, 0.75, 2)
end

function GridOverlay:Show()
    if not gridFrame or #gridLines == 0 then
        BuildGrid()
    end
    gridFrame:Show()
    ns:Fire("OnGridOverlayToggled", true)
end

function GridOverlay:Hide()
    if gridFrame then
        gridFrame:Hide()
    end
    ns:Fire("OnGridOverlayToggled", false)
end

function GridOverlay:Toggle()
    if self:IsShown() then
        self:Hide()
        return false
    else
        self:Show()
        return true
    end
end

function GridOverlay:IsShown()
    return gridFrame and gridFrame:IsShown() or false
end

ns:On("OnResolutionChanged", function()
    if gridFrame and gridFrame:IsShown() then
        BuildGrid()
    end
end)
