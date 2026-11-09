local AddonName, ns = ...

local L = ns.L
local Registry = ns.Registry
local Engine = ns.Engine

local Profiles = {}
ns.Profiles = Profiles

local undoStack = {}
local MAX_UNDO_STEPS = 25
local lastUndoTag = nil
local lastUndoTime = 0

local function DeepCopyWindows(src)
    local out = {}
    if type(src) ~= "table" then
        return out
    end
    for winId, cfg in pairs(src) do
        if type(cfg) == "table" then
            out[winId] = {
                scale = cfg.scale,
                mode = cfg.mode,
                prevMode = cfg.prevMode,
                locked = cfg.locked,
                hideBadge = cfg.hideBadge and true or false,
                alpha = cfg.alpha,
                mouseoverFade = cfg.mouseoverFade,
                pos = (type(cfg.pos) == "table" and cfg.pos.uipX and cfg.pos.uipY)
                    and { uipX = cfg.pos.uipX, uipY = cfg.pos.uipY }
                    or nil,
            }
        end
    end
    return out
end

local function ReplaceWindowsInPlace(dest, src)
    wipe(dest)
    local copy = DeepCopyWindows(src)
    for k, v in pairs(copy) do
        dest[k] = v
    end
end

local function WindowConfigsEqual(winId, a, b)
    local sA = math.floor(((a and a.scale) or 1.00) * 100 + 0.5)
    local sB = math.floor(((b and b.scale) or 1.00) * 100 + 0.5)
    if sA ~= sB then
        return false
    end
    local alA = math.floor(((a and a.alpha) or 1.00) * 100 + 0.5)
    local alB = math.floor(((b and b.alpha) or 1.00) * 100 + 0.5)
    if alA ~= alB then
        return false
    end
    local fA = (a and a.mouseoverFade) and true or false
    local fB = (b and b.mouseoverFade) and true or false
    if fA ~= fB then
        return false
    end
    local lA = (a and a.locked) and true or false
    local lB = (b and b.locked) and true or false
    if lA ~= lB then
        return false
    end
    local hbA = (a and a.hideBadge) and true or false
    local hbB = (b and b.hideBadge) and true or false
    if hbA ~= hbB then
        return false
    end
    local desc = winId and Registry:GetDescriptor(winId) or nil
    local defMode = (desc and desc.defaultMode)
        or ((ns.db and ns.db.settings and ns.db.settings.defaultScaleOnly) and ns.MODE_SCALE_ONLY or ns.MODE_SCALE_MOVE)
    local mA = (a and a.mode) or defMode
    local mB = (b and b.mode) or defMode
    if mA ~= mB then
        return false
    end
    local pA = a and a.pos
    local pB = b and b.pos
    local hasPA = (type(pA) == "table" and pA.uipX ~= nil and pA.uipY ~= nil)
    local hasPB = (type(pB) == "table" and pB.uipX ~= nil and pB.uipY ~= nil)
    if hasPA ~= hasPB then
        return false
    end
    if hasPA and hasPB then
        if math.abs(pA.uipX - pB.uipX) > 1.0 or math.abs(pA.uipY - pB.uipY) > 1.0 then
            return false
        end
    end
    return true
end

function Profiles:Init()
    -- 1. Blizzard Default (100%)
    Registry:RegisterPreset("DEFAULT_100", {
        nameKey = "PRESET_DEFAULT_NAME",
        descKey = "PRESET_DEFAULT_DESC",
        fallbackScale = 1.00,
        scales = {},
    })

    -- 2. Classic Compact (80%) - Flagship preset for WoW: Forever
    Registry:RegisterPreset("COMPACT_80", {
        nameKey = "PRESET_COMPACT80_NAME",
        descKey = "PRESET_COMPACT80_DESC",
        fallbackScale = 0.80,
        scales = {
            CHARACTER = 0.85,
            SPELLBOOK = 0.80,
            TALENTS = 0.78,
            QUESTLOG = 0.82,
            QUESTMAP = 0.82,
            QUEST_DIALOG = 0.85,
            GOSSIP = 0.85,
            MERCHANT = 0.85,
            MAIL = 0.85,
            BANK = 0.82,
            PROFESSIONS = 0.76,
            TRADESKILL_CLASSIC = 0.82,
            AUCTION = 0.78,
            TRAINER = 0.82,
            COLLECTIONS = 0.78,
            COMMUNITIES = 0.78,
            ENCOUNTER_JOURNAL = 0.80,
            GROUP_FINDER = 0.82,
            FOREVER_LEGACY = 0.80,
            FOREVER_CAMPING = 0.82,
            FOREVER_FACTIONS = 0.82,
        },
    })

    -- 3. WQHD / 4K Balanced (85%)
    Registry:RegisterPreset("WQHD_85", {
        nameKey = "PRESET_WQHD85_NAME",
        descKey = "PRESET_WQHD85_DESC",
        fallbackScale = 0.86,
        scales = {
            PROFESSIONS = 0.82,
            TALENTS = 0.84,
            AUCTION = 0.84,
            COLLECTIONS = 0.84,
            COMMUNITIES = 0.84,
            QUESTMAP = 0.85,
            SPELLBOOK = 0.85,
        },
    })

    -- 4. Laptop / Steam Deck (72%)
    Registry:RegisterPreset("LAPTOP_72", {
        nameKey = "PRESET_LAPTOP72_NAME",
        descKey = "PRESET_LAPTOP72_DESC",
        fallbackScale = 0.72,
        scales = {
            PROFESSIONS = 0.68,
            TALENTS = 0.70,
            AUCTION = 0.70,
            COLLECTIONS = 0.70,
            CHARACTER = 0.75,
            QUEST_DIALOG = 0.76,
            GOSSIP = 0.76,
        },
    })

    Profiles:EnsureProfileSnapshots()
end

-- ============================================================================
-- Saved Profile Checkpoints & Undo History (v1.1.2)
-- ============================================================================
function Profiles:EnsureProfileSnapshots()
    if not ns.db or type(ns.db.profiles) ~= "table" then
        return
    end
    for _, prof in pairs(ns.db.profiles) do
        if type(prof) == "table" then
            if type(prof.windows) ~= "table" then
                prof.windows = {}
            end
            if type(prof.savedSnapshot) ~= "table" then
                prof.savedSnapshot = DeepCopyWindows(prof.windows)
            end
        end
    end
end

function Profiles:PushUndoSnapshot(tag)
    if not ns.db or type(ns.db.windows) ~= "table" then
        return
    end
    local now = (type(_G.GetTime) == "function" and _G.GetTime()) or 0
    if tag and tag == lastUndoTag and (now - lastUndoTime) < 1.5 then
        lastUndoTime = now
        return
    end
    lastUndoTag = tag
    lastUndoTime = now

    undoStack[#undoStack + 1] = {
        tag = tag,
        windows = DeepCopyWindows(ns.db.windows),
    }
    if #undoStack > MAX_UNDO_STEPS then
        table.remove(undoStack, 1)
    end
end

function Profiles:CanUndo()
    return #undoStack > 0
end

function Profiles:UndoLastChange()
    if not ns.db or #undoStack == 0 then
        ns:Print(L["UI_UNDO_EMPTY"])
        return false
    end
    local entry = table.remove(undoStack)
    lastUndoTag = nil
    ReplaceWindowsInPlace(ns.db.windows, entry.windows)
    Engine:ReapplyAllShown()
    ns:Print(L["UI_UNDO_APPLIED"])
    ns:Fire("OnProfileSwitched", ns.db.activeProfile)
    return true
end

function Profiles:HasUnsavedChanges()
    if not ns.db or not ns.db.activeProfile or not ns.db.profiles[ns.db.activeProfile] then
        return false
    end
    local prof = ns.db.profiles[ns.db.activeProfile]
    local saved = prof.savedSnapshot or {}
    local live = ns.db.windows or {}

    for winId, cfg in pairs(live) do
        if not WindowConfigsEqual(winId, cfg, saved[winId]) then
            return true
        end
    end
    for winId, cfg in pairs(saved) do
        if not WindowConfigsEqual(winId, live[winId], cfg) then
            return true
        end
    end
    return false
end

function Profiles:SaveActiveProfileSnapshot(silent)
    if not ns.db then
        ns:InitDatabase()
    end
    local active = ns.db.activeProfile or "Default"
    local prof = ns.db.profiles[active]
    if not prof then
        return false
    end
    prof.savedSnapshot = DeepCopyWindows(ns.db.windows)
    if not silent then
        ns:Print(string.format(L["UI_PROFILE_SAVED"], active))
    end
    ns:Fire("OnProfileSwitched", active)
    return true
end

function Profiles:RevertToSavedProfile()
    if not ns.db then
        ns:InitDatabase()
    end
    local active = ns.db.activeProfile or "Default"
    local prof = ns.db.profiles[active]
    if not prof or type(prof.savedSnapshot) ~= "table" then
        return false
    end
    Profiles:PushUndoSnapshot("revert_profile:" .. active)
    lastUndoTag = nil
    ReplaceWindowsInPlace(ns.db.windows, prof.savedSnapshot)
    Engine:ReapplyAllShown()
    ns:Print(string.format(L["UI_PROFILE_REVERTED"], active))
    ns:Fire("OnProfileSwitched", active)
    return true
end

-- Restores a single window to its saved profile checkpoint (or last undo state if unchanged in profile)
function Profiles:RestoreWindowToSavedOrUndo(windowId)
    if not ns.db or not windowId then
        return false
    end
    local active = ns.db.activeProfile or "Default"
    local prof = ns.db.profiles[active]
    local savedCfg = prof and prof.savedSnapshot and prof.savedSnapshot[windowId] or nil
    local liveCfg = ns.db.windows[windowId]

    if not WindowConfigsEqual(windowId, liveCfg, savedCfg) then
        Profiles:PushUndoSnapshot("restore_win:" .. windowId)
        lastUndoTag = nil
        if savedCfg then
            ns.db.windows[windowId] = DeepCopyWindows({ [windowId] = savedCfg })[windowId]
        else
            ns.db.windows[windowId] = nil
        end
        local desc = Registry:GetDescriptor(windowId)
        if desc and desc.boundFrame then
            Engine:ApplyToFrame(windowId, desc.boundFrame, desc)
        end
        ns:Fire("OnWindowConfigChanged", windowId, ns.db.windows[windowId])
        return true
    elseif #undoStack > 0 then
        return Profiles:UndoLastChange()
    end
    return false
end

-- ============================================================================
-- Named Profile Management (v1.1)
-- ============================================================================
function Profiles:GetActiveProfileName()
    if not ns.db then
        ns:InitDatabase()
    end
    return ns.db.activeProfile or "Default"
end

function Profiles:ListProfiles()
    if not ns.db then
        ns:InitDatabase()
    end
    local names = {}
    for name in pairs(ns.db.profiles) do
        if name ~= "Default" then
            names[#names + 1] = name
        end
    end
    table.sort(names)
    table.insert(names, 1, "Default")
    return names
end

local function SanitizeProfileName(rawName)
    if type(rawName) ~= "string" then
        return nil
    end
    local stripped = string.gsub(rawName, "[;:]", "")
    local clean = string.match(stripped, "^%s*(.-)%s*$")
    if not clean or clean == "" then
        return nil
    end
    return clean
end

function Profiles:SwitchProfile(profileName, silent)
    local clean = SanitizeProfileName(profileName)
    if not clean then
        return false
    end
    if not ns.db then
        ns:InitDatabase()
    end

    if not ns.db.profiles[clean] then
        ns.db.profiles[clean] = { windows = {}, savedSnapshot = {} }
    elseif type(ns.db.profiles[clean].windows) ~= "table" then
        ns.db.profiles[clean].windows = {}
    end
    if type(ns.db.profiles[clean].savedSnapshot) ~= "table" then
        ns.db.profiles[clean].savedSnapshot = DeepCopyWindows(ns.db.profiles[clean].windows)
    end

    ns.db.activeProfile = clean
    ns.db.windows = ns.db.profiles[clean].windows
    wipe(undoStack)
    lastUndoTag = nil

    Engine:ReapplyAllShown()
    if not silent then
        ns:PlaySound("PROFILE_SWITCH")
        ns:Print(string.format(L["UI_PROFILE_SWITCHED"], clean))
    end
    ns:Fire("OnProfileSwitched", clean)
    return true
end

function Profiles:CycleNextProfile()
    local list = Profiles:ListProfiles()
    local current = Profiles:GetActiveProfileName()
    local nextIdx = 1
    for i = 1, #list do
        if list[i] == current then
            nextIdx = (i % #list) + 1
            break
        end
    end
    return Profiles:SwitchProfile(list[nextIdx])
end

function Profiles:CreateOrCopyProfile(newName, copyFromCurrent)
    local clean = SanitizeProfileName(newName)
    if not clean then
        return false
    end
    if not ns.db then
        ns:InitDatabase()
    end

    -- Reject collisions before replacing a checkpoint, switching profiles or clearing undo.
    if ns.db.profiles[clean] ~= nil then
        ns:Print(string.format(L["UI_PROFILE_EXISTS"], clean))
        return false, "profile_exists"
    end

    local sourceWindows = copyFromCurrent and ns.db.windows or nil
    ns.db.profiles[clean] = {
        windows = DeepCopyWindows(sourceWindows),
        savedSnapshot = DeepCopyWindows(sourceWindows),
    }
    Profiles:SwitchProfile(clean, true)
    ns:Print(string.format(L["UI_PROFILE_CREATED"], clean))
    return true
end

function Profiles:DeleteProfile(profileName)
    if not ns.db then
        ns:InitDatabase()
    end
    local target = profileName or ns.db.activeProfile
    if target == "Default" then
        ns:Print(L["UI_PROFILE_CANNOT_DEL"])
        return false
    end
    if not ns.db.profiles[target] then
        return false
    end

    ns.db.profiles[target] = nil
    if type(ns.db.charProfiles) == "table" then
        for cKey, pName in pairs(ns.db.charProfiles) do
            if pName == target then
                ns.db.charProfiles[cKey] = nil
            end
        end
    end
    if ns.db.activeProfile == target then
        Profiles:SwitchProfile("Default", true)
    end
    ns:Print(string.format(L["UI_PROFILE_DELETED"], target))
    ns:Fire("OnProfileSwitched", ns.db.activeProfile)
    return true
end

-- ============================================================================
-- Character-Bound Profiles (v1.4.0)
-- ============================================================================
function Profiles:GetCharKey()
    local name = _G.UnitName and _G.UnitName("player")
    if not name or name == "" or name == "Unknown" or (_G.UNKNOWNOBJECT and name == _G.UNKNOWNOBJECT) then
        return nil
    end
    local realm = _G.GetRealmName and _G.GetRealmName()
    if realm and realm ~= "" then
        return name .. " - " .. realm
    end
    return name
end

function Profiles:IsCharBoundToActiveProfile()
    if not ns.db or type(ns.db.charProfiles) ~= "table" then
        return false
    end
    local charKey = Profiles:GetCharKey()
    if not charKey then
        return false
    end
    local boundProfile = ns.db.charProfiles[charKey]
    local currentProfile = Profiles:GetActiveProfileName()
    return boundProfile ~= nil and boundProfile == currentProfile
end

function Profiles:SetCharProfileBinding(enabled)
    if not ns.db then
        ns:InitDatabase()
    end
    if type(ns.db.charProfiles) ~= "table" then
        ns.db.charProfiles = {}
    end
    local charKey = Profiles:GetCharKey()
    if not charKey then
        return
    end
    local currentProfile = Profiles:GetActiveProfileName()
    if enabled then
        ns.db.charProfiles[charKey] = currentProfile
    else
        if ns.db.charProfiles[charKey] == currentProfile then
            ns.db.charProfiles[charKey] = nil
        end
    end
    ns:Fire("OnCharProfileBindingChanged", charKey, enabled and currentProfile or nil)
end

function Profiles:AutoLoadCharProfile()
    if not ns.db or type(ns.db.charProfiles) ~= "table" then
        return false
    end
    local charKey = Profiles:GetCharKey()
    if not charKey then
        return false
    end
    local targetProfile = ns.db.charProfiles[charKey]
    if targetProfile and ns.db.profiles and ns.db.profiles[targetProfile] then
        if ns.db.activeProfile ~= targetProfile then
            Profiles:SwitchProfile(targetProfile, true)
            local charName = _G.UnitName and _G.UnitName("player") or charKey
            ns:Print(string.format(L["UI_PROFILE_AUTOLOADED"], targetProfile, charName))
            return true
        end
    end
    return false
end

-- ============================================================================
-- Presets & Reset
-- ============================================================================
function Profiles:ApplyPreset(presetId)
    local preset = Registry:GetPreset(presetId)
    if not preset then
        return false
    end

    Profiles:PushUndoSnapshot("preset:" .. tostring(presetId))
    lastUndoTag = nil

    for windowId, desc in Registry:IterateWindows() do
        local isThirdParty = (desc.isCommunityAddon or desc.isCustom)
        local isDormantComm = (desc.isCommunityAddon and not Registry:IsCommunityAddonActive(desc))
        if not isDormantComm then
            local effMode = Engine:GetEffectiveWindowMode(windowId, desc)
            -- Respect per-AddOn Off state: never auto-enable disabled third-party AddOns on preset click!
            if not (isThirdParty and effMode == ns.MODE_DISABLED) then
                local cfg = ns:GetWindowConfig(windowId, true)
                local targetScale = (preset.scales and preset.scales[windowId])
                    or (presetId == "COMPACT_80" and desc.defaultCompactScale)
                    or preset.fallbackScale
                    or ns.DEFAULT_SCALE

                cfg.scale = Engine:ClampScale(targetScale)
                if not isThirdParty and cfg.mode == ns.MODE_DISABLED and presetId ~= "DEFAULT_100" then
                    cfg.mode = ns.db.settings.defaultScaleOnly and ns.MODE_SCALE_ONLY or ns.MODE_SCALE_MOVE
                end
            end
        end
    end

    ns.db.settings.activePreset = presetId
    Engine:ReapplyAllShown()

    local presetTitle = preset.nameKey and L[preset.nameKey] or preset.name or presetId
    ns:PlaySound("PRESET_APPLY")
    ns:Print(string.format(L["PRESET_APPLIED"], presetTitle))
    ns:Fire("OnPresetApplied", presetId)
    return true
end

function Profiles:ResetAll()
    if not ns.db then
        return
    end
    Profiles:PushUndoSnapshot("reset_all")
    lastUndoTag = nil
    wipe(ns.db.windows)
    ns.db.settings.activePreset = "DEFAULT_100"
    ns:PlaySound("PRESET_APPLY")

    for windowId, desc in Registry:IterateWindows() do
        if desc.boundFrame and desc.boundFrame:IsShown() then
            Engine:ApplyToFrame(windowId, desc.boundFrame, desc)
        end
    end

    ns:Print(L["UI_RESET_CONFIRM"])
    ns:Fire("OnResetAll")
end

-- Restores custom user-picked third-party frames stored in ELLADB.customWindows
function Profiles:RestoreCustomWindows()
    if not ns.db or type(ns.db.customWindows) ~= "table" then
        return
    end
    for frameName, meta in pairs(ns.db.customWindows) do
        local isBlacklisted = (ns.Guard and ns.Guard.IsBlacklistedName and ns.Guard:IsBlacklistedName(frameName)) or false
        local existingId, existingDesc = Registry:FindByFrameName(frameName)
        if isBlacklisted or (existingId and existingDesc and not existingDesc.isCustom) then
            -- Purge blacklisted HUD/EditMode containers or legacy built-in duplicates
            ns.db.customWindows[frameName] = nil
            local customKey = "CUSTOM_" .. tostring(frameName)
            if type(ns.db.profiles) == "table" then
                for _, prof in pairs(ns.db.profiles) do
                    if type(prof) == "table" then
                        if type(prof.windows) == "table" then
                            prof.windows[customKey] = nil
                        end
                        if type(prof.savedSnapshot) == "table" then
                            prof.savedSnapshot[customKey] = nil
                        end
                    end
                end
            end
        else
            local windowId = "CUSTOM_" .. frameName
            Registry:RegisterWindow(windowId, {
                frame = frameName,
                label = meta.label or frameName,
                category = "CAT_CUSTOM",
                defaultCompactScale = 0.85,
                isCustom = true,
                source = "UserPicker",
            })
        end
    end
end

function Profiles:RemoveCustomWindow(windowId)
    local desc = Registry:GetDescriptor(windowId)
    if not desc or not desc.isCustom then
        return false
    end
    local frameName = desc.frame or string.gsub(windowId, "^CUSTOM_", "")
    local label = Registry:GetDisplayLabel(desc)

    if ns.BadgeUI and ns.BadgeUI.HideWindowBadge then
        ns.BadgeUI:HideWindowBadge(windowId)
    end

    if ns.db and type(ns.db.customWindows) == "table" then
        ns.db.customWindows[frameName] = nil
    end
    if ns.db and type(ns.db.profiles) == "table" then
        for _, prof in pairs(ns.db.profiles) do
            if type(prof) == "table" then
                if type(prof.windows) == "table" then
                    prof.windows[windowId] = nil
                end
                if type(prof.savedSnapshot) == "table" then
                    prof.savedSnapshot[windowId] = nil
                end
            end
        end
    end
    Registry:UnregisterWindow(windowId)
    ns:Print(string.format(L["MSG_CUSTOM_REMOVED"], label))
    ns:Fire("OnCustomWindowRemoved", windowId)
    return true
end

-- Safe, deterministic ASCII profile export (NO loadstring ever used!)
local MODE_TO_SHORT = {
    [ns.MODE_SCALE_MOVE] = "M",
    [ns.MODE_SCALE_ONLY] = "S",
    [ns.MODE_DISABLED] = "D",
}
local SHORT_TO_MODE = {
    M = ns.MODE_SCALE_MOVE,
    S = ns.MODE_SCALE_ONLY,
    D = ns.MODE_DISABLED,
}

function Profiles:ExportString()
    if not ns.db then
        return "!ELLA:v2:Default"
    end
    local profName = SanitizeProfileName(Profiles:GetActiveProfileName()) or "Default"
    local parts = { "!ELLA:v2:" .. profName }
    for windowId in Registry:IterateWindows() do
        local cfg = ns.db.windows[windowId]
        if cfg then
            local s = math.floor((cfg.scale or 1) * 100 + 0.5)
            local m = MODE_TO_SHORT[cfg.mode] or "M"
            local l = cfg.locked and "1" or "0"
            local px = (cfg.pos and cfg.pos.uipX) and tostring(math.floor(cfg.pos.uipX + 0.5)) or ""
            local py = (cfg.pos and cfg.pos.uipY) and tostring(math.floor(cfg.pos.uipY + 0.5)) or ""
            local a = math.floor(((cfg.alpha ~= nil and cfg.alpha) or 1) * 100 + 0.5)
            local f = cfg.mouseoverFade and "1" or "0"
            local hb = cfg.hideBadge and "1" or "0"
            parts[#parts + 1] = string.format("%s=%d,%s,%s,%s,%s,%d,%s,%s", windowId, s, m, l, px, py, a, f, hb)
        end
    end
    return table.concat(parts, ";")
end

local MAX_IMPORT_BYTES = 65536
local MAX_IMPORT_ENTRIES = 1024
local IMPORT_ERRORS = {
    too_large = "UI_IMPORT_TOO_LARGE",
    too_many_entries = "UI_IMPORT_TOO_MANY",
    invalid_number = "UI_IMPORT_NUMBER",
    invalid_position = "UI_IMPORT_POSITION",
    duplicate_window = "UI_IMPORT_DUPLICATE",
    no_known_windows = "UI_IMPORT_NO_WINDOWS",
}

function Profiles:GetImportErrorMessage(code)
    return L[IMPORT_ERRORS[code] or "UI_IMPORT_ERROR"]
end

local function ParseNumber(text, unsignedInteger)
    if type(text) ~= "string" then return nil end
    if unsignedInteger then
        if not string.match(text, "^%d+$") then return nil end
    elseif not string.match(text, "^%-?%d+%.?%d*$") and not string.match(text, "^%-?%.%d+$") then
        return nil
    end
    local number = tonumber(text)
    if not number or number ~= number or number == math.huge or number == -math.huge then return nil end
    return number
end

-- Shared by preview and application. No config creation, events or undo writes here.
local function ParseImport(raw)
    if type(raw) ~= "string" then return nil, "invalid_type" end
    if #raw > MAX_IMPORT_BYTES then return nil, "too_large" end
    local trimmed = string.match(raw, "^%s*(.-)%s*$")
    local separator = string.find(trimmed, ";", 1, true)
    local header = separator and string.sub(trimmed, 1, separator - 1) or trimmed
    local profileName = string.match(header, "^!ELLA:v2:([^;:]+)$") or string.match(header, "^ELLA2:([^;:]+)$")
    if header ~= "ELLA1" and header ~= "FSCALE1" and header ~= "ELLA2" and header ~= "!ELLA:v2" and not profileName then
        return nil, "invalid_header"
    end
    if profileName then
        profileName = SanitizeProfileName(profileName)
        if not profileName or string.find(profileName, "%c") then return nil, "invalid_header" end
    end
    if not separator then return nil, "no_known_windows" end

    local result = { entries = {}, profileName = profileName }
    local seen, count = {}, 0
    for token in string.gmatch(string.sub(trimmed, separator + 1) .. ";", "(.-);") do
        count = count + 1
        if count > MAX_IMPORT_ENTRIES then return nil, "too_many_entries" end
        local id, payload = string.match(token, "^([%w_%.%-]+)=(.*)$")
        if not id or string.find(payload, "=", 1, true) then return nil, "invalid_entry" end
        if seen[id] then return nil, "duplicate_window" end
        seen[id] = true
        local fields = {}
        for field in string.gmatch(payload .. ",", "(.-),") do
            fields[#fields + 1] = field
            if #fields > 8 then return nil, "invalid_entry" end
        end
        if #fields < 5 or not SHORT_TO_MODE[fields[2]] or (fields[3] ~= "0" and fields[3] ~= "1") then
            return nil, "invalid_entry"
        end
        local scale = ParseNumber(fields[1], true)
        if not scale then return nil, "invalid_number" end
        local entry = { id = id, scale = Engine:ClampScale(scale / 100), mode = SHORT_TO_MODE[fields[2]], locked = fields[3] == "1" }
        if fields[4] ~= "" or fields[5] ~= "" then
            local x, y = ParseNumber(fields[4]), ParseNumber(fields[5])
            if not x or not y or math.abs(x) > ns.MAX_POSITION or math.abs(y) > ns.MAX_POSITION then
                return nil, "invalid_position"
            end
            entry.pos = { uipX = x, uipY = y }
        end
        if fields[6] and fields[6] ~= "" then
            local alpha = ParseNumber(fields[6], true)
            if not alpha then return nil, "invalid_number" end
            entry.alpha = math.min(ns.MAX_ALPHA, math.max(ns.MIN_ALPHA, alpha / 100))
        end
        for index = 7, 8 do
            local value = fields[index]
            if value and value ~= "" then
                if value ~= "0" and value ~= "1" then return nil, "invalid_entry" end
                entry[index == 7 and "mouseoverFade" or "hideBadge"] = value == "1"
            end
        end
        -- Valid unknown IDs may belong to another client/addon; never create them.
        if Registry:GetDescriptor(id) then result.entries[#result.entries + 1] = entry end
    end
    if #result.entries == 0 then return nil, "no_known_windows" end
    return result
end

function Profiles:InspectImportString(raw)
    local parsed, reason = ParseImport(raw)
    if not parsed then return false, 0, "", nil, reason end
    local names = {}
    for i = 1, math.min(4, #parsed.entries) do
        names[i] = Registry:GetDisplayLabel(Registry:GetDescriptor(parsed.entries[i].id))
    end
    local summary = table.concat(names, ", ")
    if #parsed.entries > #names then
        summary = summary .. string.format(L["UI_EXPORT_MORE_WINDOWS"], #parsed.entries - #names)
    end
    return true, #parsed.entries, summary, parsed.profileName
end

function Profiles:ImportString(raw)
    local parsed, reason = ParseImport(raw)
    if not parsed then return false, Profiles:GetImportErrorMessage(reason), reason end
    if not ns.db then ns:InitDatabase() end
    Profiles:PushUndoSnapshot("import")
    lastUndoTag = nil -- Each accepted import remains a separate undo step.
    for _, entry in ipairs(parsed.entries) do
        local cfg = ns:GetWindowConfig(entry.id, true)
        cfg.scale, cfg.mode, cfg.locked, cfg.pos = entry.scale, entry.mode, entry.locked, entry.pos
        for _, key in ipairs({ "alpha", "mouseoverFade", "hideBadge" }) do
            if entry[key] ~= nil then cfg[key] = entry[key] end
        end
    end
    ns.db.settings.activePreset = nil
    Engine:ReapplyAllShown()
    ns:Fire("OnProfileImported", #parsed.entries)
    return true, string.format(L["UI_IMPORT_SUCCESS"], #parsed.entries)
end
