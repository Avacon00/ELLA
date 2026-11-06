local AddonName, ns = ...

local L = ns.L
local Guard = ns.Guard
local Registry = ns.Registry

local Picker = {
    active = false,
}
ns.Picker = Picker

local BACKDROP_TEMPLATE = _G.BackdropTemplateMixin and "BackdropTemplate" or nil
local bannerFrame = nil
local highlightBox = nil
local snippetModal = nil
local currentCandidate = nil
local currentCandidateName = nil

-- Compatible mouse-focus helper for WoW 16001 (GetMouseFoci) + fallback
local function GetTopMouseFrame()
    if type(_G.GetMouseFoci) == "function" then
        local foci = _G.GetMouseFoci()
        if type(foci) == "table" then
            for i = 1, #foci do
                local f = foci[i]
                if f and f ~= bannerFrame and f ~= highlightBox and not Guard:IsForbidden(f) then
                    return f
                end
            end
        end
    elseif type(_G.GetMouseFocus) == "function" then
        local f = _G.GetMouseFocus()
        if f and f ~= bannerFrame and f ~= highlightBox and not Guard:IsForbidden(f) then
            return f
        end
    end
    return nil
end

-- Walks up parent chain to locate the top-level window right below UIParent
local function ResolveTopWindow(leafFrame)
    if not leafFrame or Guard:IsForbidden(leafFrame) then
        return nil
    end
    local cursor = leafFrame
    local lastNamed = nil
    local depth = 0
    while cursor and cursor ~= _G.UIParent and cursor ~= _G.WorldFrame and depth < 18 do
        if Guard:IsForbidden(cursor) then
            return nil
        end
        local parent = type(cursor.GetParent) == "function" and cursor:GetParent() or nil
        if type(cursor.GetName) == "function" and cursor:GetName() then
            lastNamed = cursor
        end
        if parent == _G.UIParent then
            return cursor
        end
        cursor = parent
        depth = depth + 1
    end
    return lastNamed
end

local function ShowSnippetModal(frameName)
    if not snippetModal then
        local m = CreateFrame("Frame", nil, UIParent, BACKDROP_TEMPLATE)
        m:SetSize(440, 210)
        m:SetPoint("CENTER", 0, 40)
        m:SetFrameStrata("FULLSCREEN_DIALOG")
        m:EnableMouse(true)
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
    highlightBox:SetFrameStrata("TOOLTIP")
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

    bannerFrame = CreateFrame("Button", nil, UIParent, BACKDROP_TEMPLATE)
    bannerFrame:SetSize(500, 68)
    bannerFrame:SetPoint("TOP", UIParent, "TOP", 0, -24)
    bannerFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    bannerFrame:EnableMouse(true)
    bannerFrame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
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
        bannerFrame:SetBackdropBorderColor(0.0, 0.80, 1.0, 0.95)
    end

    local title = bannerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetText(L["PICKER_BANNER_TITLE"])

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
    bannerFrame:Hide()
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
    local topWin = ResolveTopWindow(leaf)

    if not topWin then
        currentCandidate = nil
        currentCandidateName = nil
        highlightBox:Hide()
        bannerFrame.status:SetText("—")
        return
    end

    local winName = type(topWin.GetName) == "function" and topWin:GetName() or nil
    local ok, reason = Guard:ValidateTarget(topWin)
    if ok and (not winName or winName == "" or _G[winName] ~= topWin) then
        ok = false
        reason = L["GUARD_ERR_UNSAFE"]
    end

    highlightBox:ClearAllPoints()
    highlightBox:SetAllPoints(topWin)
    highlightBox:Show()

    if ok then
        currentCandidate = topWin
        currentCandidateName = winName
        if highlightBox.SetBackdropColor then
            highlightBox:SetBackdropColor(0.0, 0.85, 0.45, 0.18)
            highlightBox:SetBackdropBorderColor(0.0, 0.95, 0.50, 0.95)
        end
        bannerFrame.status:SetText(string.format(L["PICKER_SAFE"], winName))

        if IsMouseButtonDown("LeftButton") and not bannerFrame:IsMouseOver() then
            local pickedName = currentCandidateName
            Picker:Stop()
            Picker:RegisterPickedWindow(pickedName)
        end
    else
        currentCandidate = nil
        currentCandidateName = nil
        if highlightBox.SetBackdropColor then
            highlightBox:SetBackdropColor(0.90, 0.15, 0.15, 0.18)
            highlightBox:SetBackdropBorderColor(0.95, 0.25, 0.25, 0.95)
        end
        bannerFrame.status:SetText(string.format(L["PICKER_BLOCKED"], tostring(winName or "<anonymous>"), tostring(reason or "")))
    end
end

function Picker:RegisterPickedWindow(frameName)
    if not frameName or frameName == "" then
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
    ShowSnippetModal(frameName)
end

function Picker:Start()
    EnsurePickerFrames()
    Picker.active = true
    currentCandidate = nil
    currentCandidateName = nil
    bannerFrame:Show()
    -- Golden Rule #8: OnUpdate runs ONLY while interactive picker mode is open
    bannerFrame:SetScript("OnUpdate", OnPickerUpdate)
end

function Picker:Stop()
    Picker.active = false
    if bannerFrame then
        bannerFrame:SetScript("OnUpdate", nil)
        bannerFrame:Hide()
    end
    if highlightBox then
        highlightBox:Hide()
    end
end
