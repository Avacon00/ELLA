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
                locked = cfg.locked,
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

local function WindowConfigsEqual(a, b)
    local sA = math.floor(((a and a.scale) or 1.00) * 100 + 0.5)
    local sB = math.floor(((b and b.scale) or 1.00) * 100 + 0.5)
    if sA ~= sB then
        return false
    end
    local defMode = (ns.db and ns.db.settings and ns.db.settings.defaultScaleOnly) and ns.MODE_SCALE_ONLY or ns.MODE_SCALE_MOVE
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
            REPUTATION = 0.82,
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
        if not WindowConfigsEqual(cfg, saved[winId]) then
            return true
        end
    end
    for winId, cfg in pairs(saved) do
        if not WindowConfigsEqual(live[winId], cfg) then
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

    if not WindowConfigsEqual(liveCfg, savedCfg) then
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

function Profiles:SwitchProfile(profileName, silent)
    if type(profileName) ~= "string" then
        return false
    end
    local clean = string.match(profileName, "^%s*(.-)%s*$")
    if not clean or clean == "" then
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
    if type(newName) ~= "string" then
        return false
    end
    local clean = string.match(newName, "^%s*(.-)%s*$")
    if not clean or clean == "" then
        return false
    end
    if not ns.db then
        ns:InitDatabase()
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
    if ns.db.activeProfile == target then
        Profiles:SwitchProfile("Default", true)
    end
    ns:Print(string.format(L["UI_PROFILE_DELETED"], target))
    ns:Fire("OnProfileSwitched", ns.db.activeProfile)
    return true
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
        local cfg = ns:GetWindowConfig(windowId, true)
        local targetScale = (preset.scales and preset.scales[windowId])
            or (presetId == "COMPACT_80" and desc.defaultCompactScale)
            or preset.fallbackScale
            or ns.DEFAULT_SCALE

        cfg.scale = Engine:ClampScale(targetScale)
        if cfg.mode == ns.MODE_DISABLED and presetId ~= "DEFAULT_100" then
            cfg.mode = ns.db.settings.defaultScaleOnly and ns.MODE_SCALE_ONLY or ns.MODE_SCALE_MOVE
        end
    end

    ns.db.settings.activePreset = presetId
    Engine:ReapplyAllShown()

    local presetTitle = preset.nameKey and L[preset.nameKey] or preset.name or presetId
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
        local existingId, existingDesc = Registry:FindByFrameName(frameName)
        if existingId and existingDesc and not existingDesc.isCustom then
            -- Clean up legacy duplicate if a built-in descriptor already manages this frame
            ns.db.customWindows[frameName] = nil
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
        return "ELLA1"
    end
    local parts = { "ELLA1" }
    for windowId in Registry:IterateWindows() do
        local cfg = ns.db.windows[windowId]
        if cfg then
            local s = math.floor((cfg.scale or 1) * 100 + 0.5)
            local m = MODE_TO_SHORT[cfg.mode] or "M"
            local l = cfg.locked and "1" or "0"
            local px = (cfg.pos and cfg.pos.uipX) and tostring(math.floor(cfg.pos.uipX + 0.5)) or ""
            local py = (cfg.pos and cfg.pos.uipY) and tostring(math.floor(cfg.pos.uipY + 0.5)) or ""
            parts[#parts + 1] = string.format("%s=%d,%s,%s,%s,%s", windowId, s, m, l, px, py)
        end
    end
    return table.concat(parts, ";")
end

function Profiles:ImportString(raw)
    if type(raw) ~= "string" then
        return false, L["UI_IMPORT_ERROR"]
    end
    local trimmed = string.match(raw, "^%s*(.-)%s*$")
    if not trimmed or (not string.match(trimmed, "^ELLA1") and not string.match(trimmed, "^FSCALE1")) then
        return false, L["UI_IMPORT_ERROR"]
    end

    local importedCount = 0
    for token in string.gmatch(trimmed, "[^;]+") do
        if token ~= "ELLA1" and token ~= "FSCALE1" then
            local winId, payload = string.match(token, "^([%w_%-]+)=(.+)$")
            if winId and payload and Registry:GetDescriptor(winId) then
                local sStr, mStr, lStr, xStr, yStr = string.match(payload, "^(%d+),([MSD]),([01]),([%-%.%d]*),([%-%.%d]*)$")
                if sStr and mStr then
                    local cfg = ns:GetWindowConfig(winId, true)
                    cfg.scale = Engine:ClampScale((tonumber(sStr) or 100) / 100)
                    cfg.mode = SHORT_TO_MODE[mStr] or ns.MODE_SCALE_MOVE
                    cfg.locked = (lStr == "1")
                    local nx, ny = tonumber(xStr), tonumber(yStr)
                    if nx and ny then
                        cfg.pos = { uipX = nx, uipY = ny }
                    else
                        cfg.pos = nil
                    end
                    importedCount = importedCount + 1
                end
            end
        end
    end

    if importedCount == 0 and trimmed ~= "ELLA1" and trimmed ~= "FSCALE1" then
        return false, L["UI_IMPORT_ERROR"]
    end

    ns.db.settings.activePreset = nil
    Engine:ReapplyAllShown()
    ns:Fire("OnProfileImported", importedCount)
    return true, string.format(L["UI_IMPORT_SUCCESS"], importedCount)
end
