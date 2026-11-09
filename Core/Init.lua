local AddonName, ns = ...

ns.AddonName = AddonName
ns.Version = "1.10.0"

-- Internal Project Camelot (WoW: Forever) constant is 18
ns.WOW_PROJECT_CAMELOT = _G.WOW_PROJECT_CAMELOT or 18
ns.IsForeverClient = (_G.WOW_PROJECT_ID == ns.WOW_PROJECT_CAMELOT)

-- Hard safety rails (Golden Rule #7)
ns.MIN_SCALE = 0.50
ns.MAX_SCALE = 1.50
ns.DEFAULT_SCALE = 1.00
ns.STEP_COARSE = 0.05
ns.STEP_FINE = 0.01
ns.MIN_ALPHA = 0.30
ns.MAX_ALPHA = 1.00
ns.MAX_POSITION = 1000000

-- Window Modes
ns.MODE_SCALE_MOVE = "SCALE_AND_MOVE"
ns.MODE_SCALE_ONLY = "SCALE_ONLY"
ns.MODE_DISABLED = "DISABLED"

-- Lightweight internal pub/sub bus (decouples Engine, Badges, Settings & Public API)
local listeners = {}

function ns:On(eventName, callback)
    if type(eventName) ~= "string" or type(callback) ~= "function" then
        return
    end
    local bucket = listeners[eventName]
    if not bucket then
        bucket = {}
        listeners[eventName] = bucket
    end
    bucket[#bucket + 1] = callback
end

function ns:Fire(eventName, ...)
    local bucket = listeners[eventName]
    if not bucket then
        return
    end
    for i = 1, #bucket do
        local ok, err = pcall(bucket[i], ...)
        if not ok and _G.geterrorhandler then
            _G.geterrorhandler()(err)
        end
    end
end

function ns:Print(msg)
    local frame = _G.DEFAULT_CHAT_FRAME
    if frame and frame.AddMessage then
        frame:AddMessage("|cff00ccff[Ella]|r " .. tostring(msg))
    end
end

-- Default SavedVariables structure
local DEFAULT_SETTINGS = {
    enabled = true,
    showBadges = true,
    ctrlWheelZoom = true,
    clampToScreen = true,
    dragOpacity = true,
    magneticSnap = true,
    defaultScaleOnly = false,
    welcomeShown = false,
    activePreset = nil,
    managerScale = 1.00,
    managerWidth = 760,
    managerHeight = 620,
    tutorialPromptShown = false,
    tutorialCompleted = false,
    showMinimapButton = true,
    minimapPos = 220,
    selectedCategoryFilter = "ALL",
    handheldPromptShown = false,
    combatAutoClose = false,
    instanceAutoCompact = false,
    stickyDocking = true,
    enableSounds = true,
}

local databaseWarningShown = false
function ns:InitDatabase()
    local db, status = ns.Database:Initialize(_G.ELLADB, DEFAULT_SETTINGS)
    if status.persist then _G.ELLADB = db end
    ns.db = db
    ns.databaseStatus = status
    if status.code == "recovered" then
        ns:Print(string.format(ns.L["DB_RECOVERED"], status.repairs))
    elseif not status.persist and not databaseWarningShown then
        databaseWarningShown = true
        ns:Print(ns.L[status.code == "unsupported_schema" and "DB_UNSUPPORTED_SCHEMA" or "DB_MIGRATION_FAILED"])
    end
    return db
end

function ns:GetWindowConfig(windowId, createIfMissing)
    if not ns.db then
        if not createIfMissing then
            return nil
        end
        ns:InitDatabase()
    end
    local winTbl = ns.db.windows[windowId]
    if not winTbl and createIfMissing then
        local desc = ns.Registry and ns.Registry.GetDescriptor and ns.Registry:GetDescriptor(windowId)
        local defaultMode = (desc and desc.defaultMode)
            or (ns.db.settings.defaultScaleOnly and ns.MODE_SCALE_ONLY or ns.MODE_SCALE_MOVE)
        winTbl = {
            scale = ns.DEFAULT_SCALE,
            mode = defaultMode,
            prevMode = nil,
            locked = false,
            hideBadge = false,
            pos = nil,
            alpha = 1.00,
            mouseoverFade = false,
        }
        ns.db.windows[windowId] = winTbl
    end
    return winTbl
end

-- ============================================================================
-- Native Sound Engine (Audio Feedback)
-- ============================================================================
function ns:PlaySound(soundType)
    if not ns.db or not ns.db.settings or not ns.db.settings.enableSounds then
        return
    end
    if not _G.PlaySound then
        return
    end

    local SOUNDKIT = _G.SOUNDKIT
    local soundId = nil
    if soundType == "SNAP" then
        soundId = (SOUNDKIT and SOUNDKIT.UI_BAG_SORTING_01) or 21743
    elseif soundType == "PANIC_CLOSE" then
        soundId = (SOUNDKIT and SOUNDKIT.IG_SPELLBOOK_CLOSE) or 829
    elseif soundType == "PANIC_RESTORE" then
        soundId = (SOUNDKIT and SOUNDKIT.IG_SPELLBOOK_OPEN) or 828
    elseif soundType == "PROFILE_SWITCH" then
        soundId = (SOUNDKIT and SOUNDKIT.GS_TITLE_OPTION_OK) or 844
    elseif soundType == "PRESET_APPLY" then
        soundId = (SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPEN) or 850
    elseif soundType == "GRID_ON" or soundType == "GRID_TOGGLE" then
        soundId = (SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) or 856
    elseif soundType == "GRID_OFF" then
        soundId = (SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF) or 857
    elseif soundType == "CLICK" then
        soundId = (SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) or 856
    end

    if soundId then
        pcall(_G.PlaySound, soundId, "SFX")
    end
end

local ellaCiProbeUnused = 42
