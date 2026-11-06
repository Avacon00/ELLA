local AddonName, ns = ...

local L = ns.L
local Guard = ns.Guard

local Registry = {
    windows = {},
    windowOrder = {},
    pendingByAddon = {},
    presets = {},
    presetOrder = {},
}
ns.Registry = Registry

-- Resolves nested frame paths such as "ProfessionsFrame.TitleContainer" safely
function Registry:ResolveFramePath(path)
    if type(path) ~= "string" or path == "" then
        return nil
    end
    local current = _G
    for segment in string.gmatch(path, "[^%.]+") do
        if type(current) ~= "table" then
            return nil
        end
        current = rawget(current, segment)
        if current == nil then
            return nil
        end
    end
    if type(current) == "table" and not Guard:IsForbidden(current) then
        return current
    end
    return nil
end

-- Resolves primary global frame from single name or candidate list
function Registry:ResolveDescriptorFrame(desc)
    if desc.frame then
        local f = Registry:ResolveFramePath(desc.frame)
        if f then
            return f, desc.frame
        end
    end
    if type(desc.candidates) == "table" then
        for i = 1, #desc.candidates do
            local candidateName = desc.candidates[i]
            local f = Registry:ResolveFramePath(candidateName)
            if f then
                return f, candidateName
            end
        end
    end
    return nil, nil
end

local function TryBindDescriptor(desc)
    if desc.boundFrame then
        return true
    end
    local frame, resolvedName = Registry:ResolveDescriptorFrame(desc)
    if not frame then
        return false
    end

    local valid = Guard:ValidateTarget(frame)
    if not valid then
        return false
    end

    desc.boundFrame = frame
    desc.resolvedFrameName = resolvedName
    if ns.Engine and ns.Engine.AttachWindow then
        ns.Engine:AttachWindow(desc.id, frame, desc)
    end
    ns:Fire("OnWindowBound", desc.id, frame, desc)
    return true
end

-- Registers a single declarative window definition
function Registry:RegisterWindow(windowId, spec)
    if type(windowId) ~= "string" or windowId == "" or type(spec) ~= "table" then
        return false, "Invalid windowId or descriptor table"
    end

    local existing = Registry.windows[windowId]
    local desc = existing or { id = windowId }

    desc.frame = spec.frame or desc.frame
    desc.candidates = spec.candidates or desc.candidates
    desc.addon = spec.addon or desc.addon
    desc.label = spec.label or (spec.labelKey and L[spec.labelKey]) or desc.label or windowId
    desc.labelKey = spec.labelKey or desc.labelKey
    desc.category = spec.category or desc.category or "CAT_CUSTOM"
    desc.defaultCompactScale = tonumber(spec.defaultCompactScale) or desc.defaultCompactScale or 0.82
    desc.defaultMode = spec.defaultMode or desc.defaultMode
    desc.protected = (spec.protected == true)
    desc.dragSubFrames = spec.dragSubFrames or desc.dragSubFrames
    desc.linkedFrames = spec.linkedFrames or desc.linkedFrames
    desc.badgeOffsetX = tonumber(spec.badgeOffsetX) or desc.badgeOffsetX or -28
    desc.badgeOffsetY = tonumber(spec.badgeOffsetY) or desc.badgeOffsetY or -5
    desc.isCustom = (spec.isCustom == true)
    desc.source = spec.source or desc.source or AddonName

    if not existing then
        Registry.windows[windowId] = desc
        Registry.windowOrder[#Registry.windowOrder + 1] = windowId
    end

    -- Attempt immediate bind if already in memory
    if not TryBindDescriptor(desc) and desc.addon then
        local bucket = Registry.pendingByAddon[desc.addon]
        if not bucket then
            bucket = {}
            Registry.pendingByAddon[desc.addon] = bucket

            if _G.EventUtil and type(_G.EventUtil.ContinueOnAddOnLoaded) == "function" then
                _G.EventUtil.ContinueOnAddOnLoaded(desc.addon, function()
                    Registry:OnAddOnLoaded(desc.addon)
                end)
            end
        end
        bucket[#bucket + 1] = desc
    end

    ns:Fire("OnWindowRegistered", windowId, desc)
    return true, nil
end

-- Batch helper for Data/Frames_*.lua files
function Registry:RegisterBatch(addonNameOrNil, entries)
    if type(entries) ~= "table" then
        return
    end
    for windowId, spec in pairs(entries) do
        if addonNameOrNil and not spec.addon then
            spec.addon = addonNameOrNil
        end
        Registry:RegisterWindow(windowId, spec)
    end
end

function Registry:OnAddOnLoaded(loadedAddonName)
    local bucket = Registry.pendingByAddon[loadedAddonName]
    if bucket then
        for i = 1, #bucket do
            TryBindDescriptor(bucket[i])
        end
    end

    -- Also retry any unbound window without an explicit addon tag (e.g. Forever custom UI)
    for i = 1, #Registry.windowOrder do
        local desc = Registry.windows[Registry.windowOrder[i]]
        if desc and not desc.boundFrame then
            TryBindDescriptor(desc)
        end
    end
end

function Registry:ScanUnboundWindows()
    for i = 1, #Registry.windowOrder do
        local desc = Registry.windows[Registry.windowOrder[i]]
        if desc and not desc.boundFrame then
            TryBindDescriptor(desc)
        end
    end
end

function Registry:GetDescriptor(windowId)
    return Registry.windows[windowId]
end

-- Finds an existing descriptor managing the given global frame name (built-in preferred over custom)
function Registry:FindByFrameName(frameName)
    if type(frameName) ~= "string" or frameName == "" then
        return nil, nil
    end
    local fallbackId, fallbackDesc = nil, nil
    for i = 1, #Registry.windowOrder do
        local id = Registry.windowOrder[i]
        local desc = Registry.windows[id]
        if desc then
            local matches = (desc.frame == frameName) or (desc.resolvedFrameName == frameName)
            if not matches and type(desc.candidates) == "table" then
                for c = 1, #desc.candidates do
                    if desc.candidates[c] == frameName then
                        matches = true
                        break
                    end
                end
            end
            if matches then
                if not desc.isCustom then
                    return id, desc
                elseif not fallbackId then
                    fallbackId, fallbackDesc = id, desc
                end
            end
        end
    end
    return fallbackId, fallbackDesc
end

function Registry:GetDisplayLabel(desc)
    if not desc then
        return ""
    end
    if desc.labelKey then
        return L[desc.labelKey]
    end
    return desc.label or desc.id
end

function Registry:IterateWindows()
    local index = 0
    local total = #Registry.windowOrder
    return function()
        index = index + 1
        if index <= total then
            local id = Registry.windowOrder[index]
            return id, Registry.windows[id]
        end
    end
end

-- Preset registration (open to third-party extensions)
function Registry:RegisterPreset(presetId, presetDef)
    if type(presetId) ~= "string" or type(presetDef) ~= "table" then
        return false
    end
    if not Registry.presets[presetId] then
        Registry.presetOrder[#Registry.presetOrder + 1] = presetId
    end
    presetDef.id = presetId
    Registry.presets[presetId] = presetDef
    return true
end

function Registry:GetPreset(presetId)
    return Registry.presets[presetId]
end

function Registry:ToggleWindowPreview(windowId)
    local desc = Registry:GetDescriptor(windowId)
    if not desc then
        return false, "Descriptor not found"
    end
    if not desc.boundFrame then
        TryBindDescriptor(desc)
    end
    local f = desc.boundFrame
    if f and f.IsShown and f:IsShown() then
        if f.Hide then
            f:Hide()
            return true, "hidden"
        end
    end

    -- Known Blizzard panel toggles
    if windowId == "CHARACTER" and _G.ToggleCharacter then
        _G.ToggleCharacter("PaperDollFrame")
        return true, "toggled"
    elseif windowId == "SPELLBOOK" and _G.ToggleSpellBook then
        _G.ToggleSpellBook(_G.BOOKTYPE_SPELL or 1)
        return true, "toggled"
    elseif windowId == "QUESTLOG" and _G.ToggleQuestLog then
        _G.ToggleQuestLog()
        return true, "toggled"
    elseif windowId == "QUESTMAP" and _G.ToggleWorldMap then
        _G.ToggleWorldMap()
        return true, "toggled"
    elseif windowId == "FRIENDS" and _G.ToggleFriendsFrame then
        _G.ToggleFriendsFrame(1)
        return true, "toggled"
    elseif windowId == "GUILD" and _G.ToggleGuildFrame then
        _G.ToggleGuildFrame()
        return true, "toggled"
    elseif windowId == "DRESSUP" and _G.DressUpFrame then
        if _G.DressUpFrame:IsShown() then _G.DressUpFrame:Hide() else _G.DressUpFrame:Show() end
        return true, "toggled"
    elseif windowId == "LFG" and _G.ToggleLFDParentFrame then
        _G.ToggleLFDParentFrame()
        return true, "toggled"
    end

    if f and f.Show then
        -- Frames requiring physical world interactables (Bank, Mail, Merchant, Gossip, Quest NPC)
        if windowId == "BANK" or windowId == "MERCHANT" or windowId == "MAIL" or windowId == "GOSSIP" or windowId == "QUEST" then
            if not f:IsShown() then
                ns:Print(L["UI_ROW_TOGGLE_NPC_REQ"])
                return false, "npc_required"
            end
        end
        f:Show()
        return true, "shown"
    end

    ns:Print(L["UI_ROW_TOGGLE_NPC_REQ"])
    return false, "cannot_toggle"
end

function Registry:IteratePresets()
    local idx = 0
    local total = #Registry.presetOrder
    return function()
        idx = idx + 1
        if idx <= total then
            local id = Registry.presetOrder[idx]
            return id, Registry.presets[id]
        end
    end
end
