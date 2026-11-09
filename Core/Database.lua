local AddonName, ns = ...

local Database = { schemaVersion = 2, migrations = {} }
ns.Database = Database

local function Copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}
    seen[value] = result
    for key, item in pairs(value) do result[Copy(key, seen)] = Copy(item, seen) end
    return result
end

local function IsFinite(value)
    return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function IsName(value)
    return type(value) == "string" and value ~= ""
end

local function Path(parent, key)
    return parent .. "[" .. (type(key) == "string" and string.format("%q", key) or tostring(key)) .. "]"
end

-- A migration operates on a copy; only a complete successful chain is persisted.
Database.migrations[1] = function(db)
    if type(db.profiles) ~= "table" then
        db.profiles = {
            Default = { windows = type(db.windows) == "table" and db.windows or {} },
            ["Laptop / Deck"] = { windows = {} },
        }
    end
end

local function EmptyDatabase(defaults)
    local windows = {}
    return {
        schemaVersion = Database.schemaVersion, settings = Copy(defaults),
        profiles = { Default = { windows = windows, savedSnapshot = {} }, ["Laptop / Deck"] = { windows = {}, savedSnapshot = {} } },
        activeProfile = "Default", windows = windows, customWindows = {}, charProfiles = {},
    }
end

function Database:Initialize(saved, defaults)
    local sourceVersion = type(saved) == "table" and saved.schemaVersion or nil
    local validVersion = IsFinite(sourceVersion) and sourceVersion >= 1 and sourceVersion == math.floor(sourceVersion)
    local fromVersion = validVersion and sourceVersion or 1
    local future = validVersion and fromVersion > Database.schemaVersion
    local migrating = fromVersion < Database.schemaVersion
    local db = type(saved) == "table" and ((future or migrating) and Copy(saved) or saved) or {}
    local repairs = 0

    local function Recover(path, value, reason)
        if value == nil then return end
        local recovery = db.recovery
        if type(recovery) ~= "table" or type(recovery.entries) ~= "table" then
            recovery = { entries = {}, previous = Copy(recovery) }
            db.recovery = recovery
        end
        if recovery.entries[path] == nil then
            recovery.entries[path] = { value = Copy(value), reason = reason }
            repairs = repairs + 1
        end
    end

    local function Table(parent, key, path)
        if type(parent[key]) ~= "table" then
            Recover(path, parent[key], "expected_table")
            parent[key] = {}
        end
        return parent[key]
    end

    local function Number(parent, key, path, fallback, minimum, maximum)
        local value = parent[key]
        if value ~= nil and (not IsFinite(value) or value < minimum or value > maximum) then
            Recover(path, value, "invalid_number")
            parent[key] = IsFinite(value) and math.max(minimum, math.min(maximum, value)) or fallback
        end
    end

    local function Windows(windows, path)
        for id, cfg in pairs(windows) do
            local cfgPath = Path(path, id)
            if not IsName(id) or type(cfg) ~= "table" then
                Recover(cfgPath, cfg, "invalid_window")
                windows[id] = nil
            else
                Number(cfg, "scale", cfgPath .. ".scale", ns.DEFAULT_SCALE, ns.MIN_SCALE, ns.MAX_SCALE)
                Number(cfg, "alpha", cfgPath .. ".alpha", ns.MAX_ALPHA, ns.MIN_ALPHA, ns.MAX_ALPHA)
                for _, key in ipairs({ "mode", "prevMode" }) do
                    local mode = cfg[key]
                    if mode ~= nil and mode ~= ns.MODE_DISABLED and mode ~= ns.MODE_SCALE_ONLY and mode ~= ns.MODE_SCALE_MOVE then
                        Recover(cfgPath .. "." .. key, mode, "invalid_mode")
                        cfg[key] = nil
                    end
                end
                for _, key in ipairs({ "locked", "hideBadge", "mouseoverFade" }) do
                    if cfg[key] ~= nil and type(cfg[key]) ~= "boolean" then
                        Recover(cfgPath .. "." .. key, cfg[key], "expected_boolean")
                        cfg[key] = false
                    end
                end
                local pos = cfg.pos
                if pos ~= nil and (type(pos) ~= "table" or not IsFinite(pos.uipX) or not IsFinite(pos.uipY)
                    or math.abs(pos.uipX) > ns.MAX_POSITION or math.abs(pos.uipY) > ns.MAX_POSITION) then
                    Recover(cfgPath .. ".pos", pos, "invalid_position")
                    cfg.pos = nil
                end
            end
        end
    end

    if type(saved) ~= "table" then Recover("ELLADB", saved, "expected_table") end
    if sourceVersion ~= nil and not validVersion then Recover("schemaVersion", sourceVersion, "invalid_version") end
    if db.windows ~= nil and type(db.windows) ~= "table" then Recover("windows", db.windows, "expected_table") end
    if migrating then
        -- Preserve damaged containers before the legacy migration replaces them.
        if db.profiles ~= nil and type(db.profiles) ~= "table" then Recover("profiles", db.profiles, "expected_table") end
        local ok, err = pcall(function()
            for version = fromVersion, Database.schemaVersion - 1 do
                assert(Database.migrations[version], AddonName .. ": Missing database migration: " .. version)(db)
                db.schemaVersion = version + 1
            end
        end)
        if not ok then
            local fallback = EmptyDatabase(defaults)
            fallback.settings.enabled = false
            return fallback, { code = "migration_failed", fromVersion = fromVersion, error = tostring(err), persist = false }
        end
    end

    local settings = Table(db, "settings", "settings")
    for key, fallback in pairs(defaults) do
        if settings[key] ~= nil and type(settings[key]) ~= type(fallback) then
            Recover("settings." .. key, settings[key], "invalid_type")
            settings[key] = nil
        end
        if settings[key] == nil then settings[key] = fallback end
    end
    Number(settings, "managerScale", "settings.managerScale", defaults.managerScale, .6, 1.4)
    Number(settings, "managerWidth", "settings.managerWidth", defaults.managerWidth, 720, 1080)
    Number(settings, "managerHeight", "settings.managerHeight", defaults.managerHeight, 440, 860)
    Number(settings, "minimapPos", "settings.minimapPos", defaults.minimapPos, -360, 360)
    if settings.activePreset ~= nil and type(settings.activePreset) ~= "string" then
        Recover("settings.activePreset", settings.activePreset, "expected_string")
        settings.activePreset = nil
    end
    if settings.widthMigratedV110 ~= nil and type(settings.widthMigratedV110) ~= "boolean" then
        Recover("settings.widthMigratedV110", settings.widthMigratedV110, "expected_boolean")
        settings.widthMigratedV110 = nil
    end
    if not settings.widthMigratedV110 then
        settings.managerWidth = math.max(760, settings.managerWidth)
        settings.managerHeight = math.max(620, settings.managerHeight)
        settings.widthMigratedV110 = true
    end

    local profiles = Table(db, "profiles", "profiles")
    if profiles.Default == nil then profiles.Default = {} end
    for name, profile in pairs(profiles) do
        local path = Path("profiles", name)
        if not IsName(name) then
            Recover(path, profile, "invalid_profile_name")
            profiles[name] = nil
        else
            profile = Table(profiles, name, path)
            if type(profile.windows) ~= "table" then
                Recover(path .. ".windows", profile.windows, "expected_table")
                local useLegacy = name == db.activeProfile or (name == "Default" and not profiles[db.activeProfile or "Default"])
                    or (name == "Default" and db.activeProfile == nil)
                profile.windows = useLegacy and type(db.windows) == "table" and db.windows or {}
            end
            Windows(profile.windows, path .. ".windows")
            if type(profile.savedSnapshot) ~= "table" or profile.savedSnapshot == profile.windows then
                Recover(path .. ".savedSnapshot", profile.savedSnapshot,
                    profile.savedSnapshot == profile.windows and "shared_checkpoint" or "expected_table")
                profile.savedSnapshot = Copy(profile.windows)
            else
                Windows(profile.savedSnapshot, path .. ".savedSnapshot")
            end
        end
    end
    if not IsName(db.activeProfile) or not profiles[db.activeProfile] then
        Recover("activeProfile", db.activeProfile, "unknown_profile")
        db.activeProfile = "Default"
    end
    local activeWindows = profiles[db.activeProfile].windows
    if type(db.windows) == "table" and db.windows ~= activeWindows and next(db.windows) ~= nil then
        Recover("windows", db.windows, "detached_alias")
    end
    db.windows = activeWindows

    local custom = Table(db, "customWindows", "customWindows")
    for frameName, meta in pairs(custom) do
        local path = Path("customWindows", frameName)
        if not IsName(frameName) then
            Recover(path, meta, "invalid_frame_name")
            custom[frameName] = nil
        else
            meta = Table(custom, frameName, path)
            if meta.label ~= nil and type(meta.label) ~= "string" then
                Recover(path .. ".label", meta.label, "expected_string")
                meta.label = nil
            end
            if meta.label == nil then meta.label = frameName end
        end
    end
    local characters = Table(db, "charProfiles", "charProfiles")
    for character, name in pairs(characters) do
        if not IsName(character) or not IsName(name) or not profiles[name] then
            Recover(Path("charProfiles", character), name, "unknown_profile")
            characters[character] = nil
        end
    end

    if future then
        settings.enabled = false
        return db, { code = "unsupported_schema", sourceVersion = sourceVersion, persist = false }
    end
    db.schemaVersion = Database.schemaVersion
    return db, { code = repairs > 0 and "recovered" or "ok", repairs = repairs, fromVersion = fromVersion,
        toVersion = Database.schemaVersion, persist = true }
end
