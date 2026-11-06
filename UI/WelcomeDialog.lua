local AddonName, ns = ...

local L = ns.L
local Profiles = ns.Profiles

local Welcome = {}
ns.Welcome = Welcome

local BACKDROP_TEMPLATE = _G.BackdropTemplateMixin and "BackdropTemplate" or nil
local dialog = nil

function Welcome:ShowIfFirstRun()
    if not ns.db or ns.db.settings.welcomeShown then
        return
    end

    if _G.InCombatLockdown and _G.InCombatLockdown() then
        ns.Guard:EnqueueAfterCombat("welcome_dialog", nil, function()
            Welcome:ShowIfFirstRun()
        end)
        return
    end

    if not dialog then
        local f = CreateFrame("Frame", nil, UIParent, BACKDROP_TEMPLATE)
        f:SetSize(430, 218)
        f:SetPoint("CENTER", 0, 90)
        f:SetFrameStrata("DIALOG")
        f:EnableMouse(true)
        f:SetClampedToScreen(true)
        if f.SetBackdrop then
            f:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true,
                tileSize = 8,
                edgeSize = 14,
                insets = { left = 3, right = 3, top = 3, bottom = 3 },
            })
            f:SetBackdropColor(0.06, 0.07, 0.10, 0.96)
            f:SetBackdropBorderColor(0.88, 0.72, 0.25, 1)
        end

        local icon = f:CreateTexture(nil, "ARTWORK")
        icon:SetSize(24, 24)
        icon:SetPoint("TOPLEFT", 18, -12)
        icon:SetTexture("Interface\\AddOns\\ELLA\\Media\\Icon")

        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("LEFT", icon, "RIGHT", 8, 0)
        title:SetText(L["WELCOME_TITLE"])

        local body = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        body:SetPoint("TOPLEFT", 18, -42)
        body:SetPoint("TOPRIGHT", -18, -42)
        body:SetJustifyH("LEFT")
        body:SetSpacing(3)
        body:SetText(L["WELCOME_BODY"])

        local btnCompact = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        btnCompact:SetSize(394, 26)
        btnCompact:SetPoint("BOTTOM", 0, 72)
        btnCompact:SetText(L["WELCOME_BTN_COMPACT"])
        btnCompact:SetScript("OnClick", function()
            ns.db.settings.welcomeShown = true
            Profiles:ApplyPreset("COMPACT_80")
            f:Hide()
        end)

        local btnWqhd = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        btnWqhd:SetSize(394, 26)
        btnWqhd:SetPoint("BOTTOM", 0, 42)
        btnWqhd:SetText(L["WELCOME_BTN_WQHD"])
        btnWqhd:SetScript("OnClick", function()
            ns.db.settings.welcomeShown = true
            Profiles:ApplyPreset("WQHD_85")
            f:Hide()
        end)

        local btnKeep = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        btnKeep:SetSize(394, 24)
        btnKeep:SetPoint("BOTTOM", 0, 12)
        btnKeep:SetText(L["WELCOME_BTN_KEEP100"])
        btnKeep:SetScript("OnClick", function()
            ns.db.settings.welcomeShown = true
            f:Hide()
        end)

        dialog = f
    end

    dialog:Show()
end

ns:On("OnPlayerLogin", function()
    Welcome:ShowIfFirstRun()
end)
