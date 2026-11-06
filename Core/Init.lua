local AddonName, ns = ...

ns.AddonName = AddonName
ns.Version = "1.1.2"

-- Internal Project Camelot (WoW: Forever) constant is 18
ns.WOW_PROJECT_CAMELOT = _G.WOW_PROJECT_CAMELOT or 18
ns.IsForeverClient = (_G.WOW_PROJECT_ID == ns.WOW_PROJECT_CAMELOT)

-- Hard safety rails (Golden Rule #7)
ns.MIN_SCALE = 0.50
ns.MAX_SCALE = 1.50
ns.DEFAULT_SCALE = 1.00
ns.STEP_COARSE = 0.05
ns.STEP_FINE = 0.01

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
    managerWidth = 720,
    managerHeight = 580,
}

function ns:InitDatabase()
    if type(_G.ELLADB) ~= "table" then
        _G.ELLADB = {}
    end
    local db = _G.ELLADB

    if type(db.settings) ~= "table" then
        db.settings = {}
    end
    for k, v in pairs(DEFAULT_SETTINGS) do
        if db.settings[k] == nil then
            db.settings[k] = v
        end
    end

    -- Schema v2: Named Profiles (seamless migration from v1 db.windows)
    if type(db.profiles) ~= "table" then
        db.profiles = {}
        if type(db.windows) == "table" and next(db.windows) ~= nil then
            db.profiles["Default"] = { windows = db.windows }
        else
            db.profiles["Default"] = { windows = {} }
        end
        db.profiles["Laptop / Deck"] = { windows = {} }
    end

    if type(db.profiles["Default"]) ~= "table" then
        db.profiles["Default"] = { windows = {} }
    end
    if type(db.profiles["Default"].windows) ~= "table" then
        db.profiles["Default"].windows = {}
    end

    if type(db.activeProfile) ~= "string" or not db.profiles[db.activeProfile] then
        db.activeProfile = "Default"
    end

    db.schemaVersion = 2
    db.windows = db.profiles[db.activeProfile].windows

    if type(db.customWindows) ~= "table" then
        db.customWindows = {}
    end

    ns.db = db
    return db
end

function ns:GetWindowConfig(windowId, createIfMissing)
    if not ns.db then
        ns:InitDatabase()
    end
    local winTbl = ns.db.windows[windowId]
    if not winTbl and createIfMissing then
        local defaultMode = ns.db.settings.defaultScaleOnly and ns.MODE_SCALE_ONLY or ns.MODE_SCALE_MOVE
        winTbl = {
            scale = ns.DEFAULT_SCALE,
            mode = defaultMode,
            locked = false,
            pos = nil,
        }
        ns.db.windows[windowId] = winTbl
    end
    return winTbl
end
