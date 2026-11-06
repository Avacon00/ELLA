local AddonName, ns = ...

local L = ns.L
local Registry = ns.Registry
local Engine = ns.Engine

local Profiles = {}
ns.Profiles = Profiles

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
end

function Profiles:ApplyPreset(presetId)
    local preset = Registry:GetPreset(presetId)
    if not preset then
        return false
    end

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

-- Safe, deterministic ASCII profile export (NO loadstring ever used!)
-- Format: FSCALE1;ID=scale,mode,locked,x,y;ID2=...
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

    if importedCount == 0 and trimmed ~= "FSCALE1" then
        return false, L["UI_IMPORT_ERROR"]
    end

    ns.db.settings.activePreset = nil
    Engine:ReapplyAllShown()
    ns:Fire("OnProfileImported", importedCount)
    return true, string.format(L["UI_IMPORT_SUCCESS"], importedCount)
end
