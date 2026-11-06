local AddonName, ns = ...

local Registry = ns.Registry
local Engine = ns.Engine
local Profiles = ns.Profiles

-- ============================================================================
-- EĹLA (Easy Layout & Location Assistant) Public API (v1)
-- Allows third-party WoW: Forever addons & community plugin packs to register
-- custom windows, presets, and listen to lifecycle callbacks taint-free.
--
-- Usage in third-party addons:
--   local api = ELLA_API or (LibStub and LibStub("ELLA-1.0", true))
--   if api then
--       api:RegisterWindow("MY_ADDON_MAIN", {
--           addon = "MyAddon",
--           frame = "MyAddonMainFrame",
--           label = "My Addon Window",
--           defaultCompactScale = 0.85,
--       })
--   end
-- ============================================================================

local API = {}

function API:GetVersion()
    return ns.Version, 2
end

function API:IsForeverClient()
    return ns.IsForeverClient
end

function API:GetActiveProfile()
    return Profiles:GetActiveProfileName()
end

function API:GetProfiles()
    return Profiles:ListProfiles()
end

function API:SwitchProfile(profileName)
    return Profiles:SwitchProfile(profileName)
end

function API:RegisterWindow(windowId, descriptor)
    return Registry:RegisterWindow(windowId, descriptor)
end

function API:RegisterAddonWindows(addonName, windowsTable)
    if type(addonName) ~= "string" or type(windowsTable) ~= "table" then
        return false, "Expected (addonName: string, windowsTable: table)"
    end
    Registry:RegisterBatch(addonName, windowsTable)
    return true, nil
end

function API:RegisterPreset(presetId, presetDefinition)
    return Registry:RegisterPreset(presetId, presetDefinition)
end

function API:ApplyPreset(presetId)
    return Profiles:ApplyPreset(presetId)
end

function API:SetWindowScale(windowId, scale)
    return Engine:SetWindowScale(windowId, scale, false)
end

function API:SetWindowAlpha(windowId, alpha, mouseoverFade)
    return Engine:SetWindowAlpha(windowId, alpha, mouseoverFade)
end

function API:GetWindowConfig(windowId)
    local cfg = ns:GetWindowConfig(windowId, false)
    if not cfg then
        return nil
    end
    -- Return a shallow copy so external callers cannot mutate internal DB tables arbitrarily
    return {
        scale = cfg.scale,
        mode = cfg.mode,
        locked = cfg.locked,
        alpha = cfg.alpha or 1.0,
        mouseoverFade = cfg.mouseoverFade and true or false,
        uipX = cfg.pos and cfg.pos.uipX or nil,
        uipY = cfg.pos and cfg.pos.uipY or nil,
    }
end

local ALLOWED_PUBLIC_EVENTS = {
    OnWindowRegistered = true,
    OnWindowBound = true,
    OnWindowApplied = true,
    OnWindowConfigChanged = true,
    OnPresetApplied = true,
    OnProfileSwitched = true,
    OnProfileImported = true,
    OnResetAll = true,
    OnCharProfileBindingChanged = true,
}

function API:RegisterCallback(eventName, callback)
    if not ALLOWED_PUBLIC_EVENTS[eventName] or type(callback) ~= "function" then
        return false
    end
    ns:On(eventName, callback)
    return true
end

function API:ToggleManager()
    if ns.ManagerUI and ns.ManagerUI.Toggle then
        ns.ManagerUI:Toggle()
    end
end

function API:ToggleBossKey()
    if ns.Engine and ns.Engine.ToggleBossKey then
        return ns.Engine:ToggleBossKey()
    end
end

function API:ToggleGrid()
    if ns.GridOverlay and ns.GridOverlay.Toggle then
        return ns.GridOverlay:Toggle()
    end
end

-- Expose via documented single global & LibStub("ELLA-1.0")
_G.ELLA_API = API
_G.Ella = API

if _G.LibStub then
    local lib = _G.LibStub:NewLibrary("ELLA-1.0", 2)
    if lib then
        for k, v in pairs(API) do
            lib[k] = v
        end
    end
end
