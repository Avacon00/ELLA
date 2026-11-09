local AddonName, ns = ...

local L = ns.L
local Guard = ns.Guard

local Registry = {
    windows = {},
    windowOrder = {},
    pendingByAddon = {},
    presets = {},
    presetOrder = {},
    readyToBind = false,
}
ns.Registry = Registry
local nextGeneration = 0

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
        if f and Guard:ValidateTarget(f) then
            return f, desc.frame
        end
    end
    if type(desc.candidates) == "table" then
        for i = 1, #desc.candidates do
            local candidateName = desc.candidates[i]
            local f = Registry:ResolveFramePath(candidateName)
            if f and Guard:ValidateTarget(f) then
                return f, candidateName
            end
        end
    end
    return nil, nil
end

local function TryBindDescriptor(desc)
    if not Registry.readyToBind or desc.retired or Registry.windows[desc.id] ~= desc then
        return false
    end
    if desc.boundFrame then
        return true
    end
    local frame, resolvedName = Registry:ResolveDescriptorFrame(desc)
    if not frame then
        return false
    end

    desc.boundFrame = frame
    desc.resolvedFrameName = resolvedName
    if ns.Engine and ns.Engine.AttachWindow then
        if not ns.Engine:AttachWindow(desc.id, frame, desc) then
            desc.boundFrame = nil
            desc.resolvedFrameName = nil
            return false
        end
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
    if not existing then
        nextGeneration = nextGeneration + 1
    end
    local desc = existing or { id = windowId, generation = nextGeneration }

    desc.frame = spec.frame or desc.frame
    desc.candidates = spec.candidates or desc.candidates
    desc.addon = spec.addon or desc.addon
    desc.addonNames = spec.addonNames or desc.addonNames
    desc.label = spec.label or (spec.labelKey and L[spec.labelKey]) or desc.label or windowId
    desc.labelKey = spec.labelKey or desc.labelKey
    desc.category = spec.category or desc.category or "CAT_CUSTOM"
    desc.defaultCompactScale = tonumber(spec.defaultCompactScale) or desc.defaultCompactScale or 0.82
    desc.defaultMode = spec.defaultMode or desc.defaultMode
    desc.protected = (spec.protected == true)
    desc.dragSubFrames = spec.dragSubFrames or desc.dragSubFrames
    desc.linkedFrames = spec.linkedFrames or desc.linkedFrames
    if spec.badgeOffsetX ~= nil or spec.badgeOffsetY ~= nil then
        desc.hasExplicitBadgeOffset = true
    end
    desc.badgeOffsetX = tonumber(spec.badgeOffsetX) or desc.badgeOffsetX or -28
    desc.badgeOffsetY = tonumber(spec.badgeOffsetY) or desc.badgeOffsetY or -5
    desc.isCustom = (spec.isCustom == true)
    desc.isCommunityAddon = (spec.isCommunityAddon == true) or (desc.isCommunityAddon == true)
    desc.source = spec.source or desc.source or AddonName

    if not existing then
        Registry.windows[windowId] = desc
        Registry.windowOrder[#Registry.windowOrder + 1] = windowId
    end

    -- Attempt immediate bind only after SavedVariables (ELLADB) are initialized
    local boundNow = Registry.readyToBind and TryBindDescriptor(desc) or false
    if not boundNow and desc.addon then
        local bucket = Registry.pendingByAddon[desc.addon]
        if not bucket then
            bucket = {}
            Registry.pendingByAddon[desc.addon] = bucket

            if _G.EventUtil and type(_G.EventUtil.ContinueOnAddOnLoaded) == "function" then
                local addonToWatch = desc.addon
                _G.EventUtil.ContinueOnAddOnLoaded(addonToWatch, function()
                    if Registry.readyToBind then
                        Registry:OnAddOnLoaded(addonToWatch)
                    end
                end)
            end
        end
        local alreadyQueued = false
        for i = 1, #bucket do
            if bucket[i] == desc then
                alreadyQueued = true
                break
            end
        end
        if not alreadyQueued then
            bucket[#bucket + 1] = desc
        end
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
    if not Registry.readyToBind then
        return
    end
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
    if not Registry.readyToBind then
        return
    end
    for i = 1, #Registry.windowOrder do
        local desc = Registry.windows[Registry.windowOrder[i]]
        if desc and not desc.boundFrame then
            TryBindDescriptor(desc)
        end
    end
end

function Registry:EnableBindingAndScan()
    Registry.readyToBind = true
    Registry:ScanUnboundWindows()
end

function Registry:GetDescriptor(windowId)
    return Registry.windows[windowId]
end

local function IsSingleAddonLoaded(addonName)
    if type(addonName) ~= "string" or addonName == "" then
        return false
    end
    if _G.C_AddOns and type(_G.C_AddOns.IsAddOnLoaded) == "function" and _G.C_AddOns.IsAddOnLoaded(addonName) then
        return true
    end
    if type(_G.IsAddOnLoaded) == "function" and _G.IsAddOnLoaded(addonName) then
        return true
    end
    return false
end

function Registry:IsCommunityAddonActive(desc)
    if not desc or not desc.isCommunityAddon then
        return true
    end
    if desc.boundFrame ~= nil then
        return true
    end
    if IsSingleAddonLoaded(desc.addon) then
        return true
    end
    if type(desc.addonNames) == "table" then
        for i = 1, #desc.addonNames do
            if IsSingleAddonLoaded(desc.addonNames[i]) then
                return true
            end
        end
    end
    return false
end

function Registry:UnregisterWindow(windowId)
    if type(windowId) ~= "string" or not Registry.windows[windowId] then
        return false
    end
    local desc = Registry.windows[windowId]
    Registry.windows[windowId] = nil
    desc.retired = true
    for i = #Registry.windowOrder, 1, -1 do
        if Registry.windowOrder[i] == windowId then
            table.remove(Registry.windowOrder, i)
        end
    end
    for addon, bucket in pairs(Registry.pendingByAddon) do
        for i = #bucket, 1, -1 do
            if bucket[i] == desc then table.remove(bucket, i) end
        end
        if #bucket == 0 then Registry.pendingByAddon[addon] = nil end
    end
    if ns.Engine and ns.Engine.DetachWindow then
        ns.Engine:DetachWindow(windowId, desc.boundFrame, desc)
    end
    desc.boundFrame = nil
    desc.resolvedFrameName = nil
    ns:Fire("OnWindowUnregistered", windowId)
    Registry:ScanUnboundWindows()
    return true
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
local function IsFiniteScale(value)
    return type(value) == "number" and value > -math.huge and value < math.huge
end

function Registry:RegisterPreset(presetId, presetDef)
    if type(presetId) ~= "string" or presetId == "" then
        return false, "invalid_id"
    end
    if type(presetDef) ~= "table" then
        return false, "invalid_definition"
    end

    local preset = { id = presetId }
    for _, field in ipairs({ "name", "nameKey", "desc", "descKey" }) do
        local value = presetDef[field]
        if value ~= nil and type(value) ~= "string" then
            return false, "invalid_" .. field
        end
        preset[field] = value
    end
    if presetDef.fallbackScale ~= nil and not IsFiniteScale(presetDef.fallbackScale) then
        return false, "invalid_fallback_scale"
    end
    preset.fallbackScale = presetDef.fallbackScale

    if presetDef.scales ~= nil then
        if type(presetDef.scales) ~= "table" then
            return false, "invalid_scales"
        end
        preset.scales = {}
        for windowId, scale in pairs(presetDef.scales) do
            if type(windowId) ~= "string" or windowId == "" or not IsFiniteScale(scale) then
                return false, "invalid_scales"
            end
            preset.scales[windowId] = scale
        end
    end

    if not Registry.presets[presetId] then
        Registry.presetOrder[#Registry.presetOrder + 1] = presetId
    end
    Registry.presets[presetId] = preset
    return true
end

function Registry:GetPreset(presetId)
    return Registry.presets[presetId]
end

local NPC_REQUIRED_WINDOWS = {
    BANK = true,
    MERCHANT = true,
    MAIL = true,
    GOSSIP = true,
    QUEST_DIALOG = true,
    AUCTION = true,
    LOOT = true,
    TRAINER = true,
    TABARD = true,
    TAXI = true,
    ITEMTEXT = true,
    INSPECT = true,
}

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
        if _G.HideUIPanel then
            local ok = pcall(_G.HideUIPanel, f)
            if ok and not f:IsShown() then
                return true, "hidden"
            end
        end
        if f.Hide then
            f:Hide()
            return true, "hidden"
        end
    end

    -- Known Blizzard panel toggles (Interface 16001 + Classic fallbacks)
    if windowId == "CHARACTER" and _G.ToggleCharacter then
        _G.ToggleCharacter("PaperDollFrame")
        return true, "toggled"
    elseif windowId == "SPELLBOOK" then
        if _G.PlayerSpellsUtil and type(_G.PlayerSpellsUtil.ToggleSpellBookFrame) == "function" then
            _G.PlayerSpellsUtil.ToggleSpellBookFrame()
            return true, "toggled"
        elseif _G.ToggleSpellBook then
            _G.ToggleSpellBook(_G.BOOKTYPE_SPELL or 1)
            return true, "toggled"
        end
    elseif windowId == "TALENTS" then
        if _G.PlayerSpellsUtil and type(_G.PlayerSpellsUtil.ToggleClassTalentFrame) == "function" then
            _G.PlayerSpellsUtil.ToggleClassTalentFrame()
            return true, "toggled"
        elseif _G.ToggleTalentFrame then
            _G.ToggleTalentFrame()
            return true, "toggled"
        end
    elseif windowId == "QUESTLOG" and _G.ToggleQuestLog then
        _G.ToggleQuestLog()
        return true, "toggled"
    elseif windowId == "QUESTMAP" and _G.ToggleWorldMap then
        _G.ToggleWorldMap()
        return true, "toggled"
    elseif windowId == "FRIENDS" and _G.ToggleFriendsFrame then
        _G.ToggleFriendsFrame(1)
        return true, "toggled"
    elseif (windowId == "COMMUNITIES" or windowId == "GUILD") then
        if _G.ToggleGuildFrame then
            _G.ToggleGuildFrame()
            return true, "toggled"
        elseif _G.ToggleCommunitiesFrame then
            _G.ToggleCommunitiesFrame()
            return true, "toggled"
        end
    elseif windowId == "DRESSUP" and _G.DressUpFrame then
        if _G.DressUpFrame:IsShown() then _G.DressUpFrame:Hide() else _G.DressUpFrame:Show() end
        return true, "toggled"
    elseif (windowId == "GROUP_FINDER" or windowId == "LFG") then
        if _G.PVEFrame_ToggleFrame then
            _G.PVEFrame_ToggleFrame()
            return true, "toggled"
        elseif _G.ToggleLFDParentFrame then
            _G.ToggleLFDParentFrame()
            return true, "toggled"
        end
    elseif windowId == "COLLECTIONS" and _G.ToggleCollectionsJournal then
        _G.ToggleCollectionsJournal()
        return true, "toggled"
    elseif windowId == "ENCOUNTER_JOURNAL" and _G.ToggleEncounterJournal then
        _G.ToggleEncounterJournal()
        return true, "toggled"
    elseif windowId == "MACRO" and _G.ShowMacroFrame then
        _G.ShowMacroFrame()
        return true, "toggled"
    elseif windowId == "CALENDAR" and _G.ToggleCalendar then
        _G.ToggleCalendar()
        return true, "toggled"
    end

    if NPC_REQUIRED_WINDOWS[windowId] then
        ns:Print(L["UI_ROW_TOGGLE_NPC_REQ"])
        return false, "npc_required"
    end

    if f and f.Show then
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
