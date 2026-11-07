local AddonName, ns = ...

local L = ns.L
local Profiles = ns.Profiles

local HandheldDialog = {}
ns.HandheldDialog = HandheldDialog

local BACKDROP_TEMPLATE = _G.BackdropTemplateMixin and "BackdropTemplate" or nil
local dialog = nil

function HandheldDialog:CheckAndPrompt()
    if not ns.db or ns.db.settings.handheldPromptShown then
        return
    end

    if _G.InCombatLockdown and _G.InCombatLockdown() then
        ns.Guard:EnqueueAfterCombat("handheld_dialog", nil, function()
            HandheldDialog:CheckAndPrompt()
        end)
        return
    end

    local uipW = (UIParent and UIParent:GetWidth()) or 1920
    local uipH = (UIParent and UIParent:GetHeight()) or 1080

    -- Handheld detection: Steam Deck (1280x800), GPD, ROG Ally or small laptop screens <= 1400x800
    if uipW > 1400 or uipH > 800 then
        return
    end

    if not dialog then
        local f = CreateFrame("Frame", "EllaHandheldDialog", UIParent, BACKDROP_TEMPLATE)
        f:SetSize(440, 196)
        f:SetPoint("CENTER", 0, 70)
        f:SetFrameStrata("DIALOG")
        f:EnableMouse(true)
        f:SetClampedToScreen(true)
        if _G.UISpecialFrames then
            table.insert(_G.UISpecialFrames, "EllaHandheldDialog")
        end
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
        title:SetText(L["HANDHELD_DIALOG_TITLE"])

        local body = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        body:SetPoint("TOPLEFT", 18, -44)
        body:SetPoint("TOPRIGHT", -18, -44)
        body:SetJustifyH("LEFT")
        body:SetSpacing(3)
        body:SetText(string.format(L["HANDHELD_DIALOG_BODY"], math.floor(uipW + 0.5), math.floor(uipH + 0.5)))
        f.body = body

        local btnAccept = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        btnAccept:SetSize(404, 26)
        btnAccept:SetPoint("BOTTOM", 0, 42)
        btnAccept:SetText(L["HANDHELD_DIALOG_ACCEPT"])
        btnAccept:SetScript("OnClick", function()
            ns.db.settings.handheldPromptShown = true
            ns.db.settings.welcomeShown = true
            Profiles:ApplyPreset("LAPTOP_72")
            f:Hide()
        end)

        local btnDecline = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        btnDecline:SetSize(404, 24)
        btnDecline:SetPoint("BOTTOM", 0, 12)
        btnDecline:SetText(L["HANDHELD_DIALOG_DECLINE"])
        btnDecline:SetScript("OnClick", function()
            ns.db.settings.handheldPromptShown = true
            ns.db.settings.welcomeShown = true
            ns:PlaySound("CLICK")
            f:Hide()
        end)

        dialog = f
    else
        dialog.body:SetText(string.format(L["HANDHELD_DIALOG_BODY"], math.floor(uipW + 0.5), math.floor(uipH + 0.5)))
    end

    local bodyH = (dialog.body and dialog.body:GetStringHeight()) or 64
    dialog:SetHeight(math.max(196, math.ceil(bodyH + 128)))
    dialog:Show()
end

ns:On("OnPlayerLogin", function()
    HandheldDialog:CheckAndPrompt()
end)
