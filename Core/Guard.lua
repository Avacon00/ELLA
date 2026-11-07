local AddonName, ns = ...

local L = ns.L
local Guard = {}
ns.Guard = Guard

-- Golden Rule #2: Strict Edit Mode & HUD Blacklist
-- None of these frames may ever be scaled, moved, or picked by Ella.
local EDITMODE_BLACKLIST = {
    UIParent = true,
    WorldFrame = true,
    EditModeManagerFrame = true,
    PlayerFrame = true,
    TargetFrame = true,
    FocusFrame = true,
    PetFrame = true,
    PartyFrame = true,
    CompactPartyFrame = true,
    CompactRaidFrameContainer = true,
    CompactRaidFrameManager = true,
    MainMenuBar = true,
    MainActionBar = true,
    MultiBarBottomLeft = true,
    MultiBarBottomRight = true,
    MultiBarRight = true,
    MultiBarLeft = true,
    MultiBar5 = true,
    MultiBar6 = true,
    MultiBar7 = true,
    StanceBar = true,
    PetActionBar = true,
    PossessActionBar = true,
    OverrideActionBar = true,
    ExtraAbilityContainer = true,
    ZoneAbilityFrame = true,
    BuffFrame = true,
    DebuffFrame = true,
    MinimapCluster = true,
    Minimap = true,
    ObjectiveTrackerFrame = true,
    QuestWatchFrame = true,
    CastingBarFrame = true,
    PlayerCastingBarFrame = true,
    OverlayPlayerCastingBarFrame = true,
    TalkingHeadFrame = true,
    ChatFrame1 = true,
    ChatFrame2 = true,
    GeneralDockManager = true,
    StatusTrackingBarManager = true,
    DurabilityFrame = true,
    VehicleSeatIndicator = true,
    UIErrorsFrame = true,
    RaidWarningFrame = true,
    Boss1TargetFrame = true,
    Boss2TargetFrame = true,
    Boss3TargetFrame = true,
    Boss4TargetFrame = true,
    Boss5TargetFrame = true,
    ArenaEnemyFramesContainer = true,
    RightManagedFrameContainer = true,
    UIParentRightManagedFrameContainer = true,
    UIParentBottomManagedFrameContainer = true,
    TopManagedFrameContainer = true,
    BottomManagedFrameContainer = true,
    PlayerPowerBarAlt = true,
    MirrorTimerContainer = true,
    ObjectiveTrackerBonusBannerFrame = true,
    SubZoneTextFrame = true,
    ZoneTextFrame = true,
    UIWidgetTopCenterContainerFrame = true,
    UIWidgetBelowMinimapContainerFrame = true,
    QueueStatusButton = true,
    MicroButtonAndBagsBar = true,
    BagsBar = true,
    MicroMenuContainer = true,
}

function Guard:IsBlacklistedName(name)
    if type(name) ~= "string" or name == "" then
        return false
    end
    if EDITMODE_BLACKLIST[name] then
        return true
    end
    if string.match(name, "^NamePlate%d+")
        or string.match(name, "^ChatFrame%d+")
        or string.match(name, "^CompactRaid")
        or string.match(name, "ManagedFrameContainer$")
    then
        return true
    end
    return false
end

-- Golden Rule #5: Mandatory IsForbidden check before touching any frame method
function Guard:IsForbidden(frame)
    if type(frame) ~= "table" then
        return true
    end
    if type(frame.IsForbidden) == "function" then
        local ok, forbidden = pcall(frame.IsForbidden, frame)
        if not ok or forbidden then
            return true
        end
    end
    return false
end

function Guard:IsEditModeFrame(frame)
    if Guard:IsForbidden(frame) then
        return false
    end
    local name = type(frame.GetName) == "function" and frame:GetName() or nil
    if name and Guard:IsBlacklistedName(name) then
        return true
    end
    -- Dynamic runtime check for Blizzard's EditModeSystemMixin frames
    if rawget(frame, "systemIndex") ~= nil and type(frame.HighlightSystem) == "function" then
        return true
    end
    return false
end

function Guard:IsProtectedHierarchy(frame)
    local cursor = frame
    local depth = 0
    while cursor and cursor ~= _G.UIParent and depth < 12 do
        if Guard:IsForbidden(cursor) then
            return true
        end
        if type(cursor.IsProtected) == "function" and cursor:IsProtected() then
            return true
        end
        cursor = type(cursor.GetParent) == "function" and cursor:GetParent() or nil
        depth = depth + 1
    end
    return false
end

-- Validates whether a candidate frame is allowed to be managed at all
function Guard:ValidateTarget(frame)
    if Guard:IsForbidden(frame) then
        return false, L["GUARD_ERR_FORBIDDEN"]
    end
    if Guard:IsEditModeFrame(frame) then
        return false, L["GUARD_ERR_EDITMODE"]
    end
    if type(frame.SetScale) ~= "function" or type(frame.SetPoint) ~= "function" then
        return false, L["GUARD_ERR_FORBIDDEN"]
    end
    return true, nil
end

-- Golden Rule #1: Never mutate protected frames during InCombatLockdown()
function Guard:CanModifyNow(frame, forceProtectedHint)
    local ok, reason = Guard:ValidateTarget(frame)
    if not ok then
        return false, reason
    end

    if _G.InCombatLockdown and _G.InCombatLockdown() then
        if forceProtectedHint or Guard:IsProtectedHierarchy(frame) then
            return false, "DEFERRED_COMBAT"
        end
    end

    return true, nil
end

-- Out-of-Combat execution queue (drained cleanly on PLAYER_REGEN_ENABLED)
local combatQueue = {}
local combatQueueOrder = {}
local warnedInCombat = {}

function Guard:EnqueueAfterCombat(taskKey, label, callback)
    if type(taskKey) ~= "string" or type(callback) ~= "function" then
        return
    end
    if not combatQueue[taskKey] then
        combatQueueOrder[#combatQueueOrder + 1] = taskKey
    end
    combatQueue[taskKey] = callback

    if label and not warnedInCombat[taskKey] then
        warnedInCombat[taskKey] = true
        ns:Print(string.format(L["GUARD_DEFERRED_COMBAT"], tostring(label)))
    end
end

function Guard:FlushCombatQueue()
    if _G.InCombatLockdown and _G.InCombatLockdown() then
        return
    end
    if #combatQueueOrder == 0 then
        return
    end

    local count = 0
    for i = 1, #combatQueueOrder do
        local key = combatQueueOrder[i]
        local fn = combatQueue[key]
        combatQueue[key] = nil
        warnedInCombat[key] = nil
        if fn then
            local ok, err = pcall(fn)
            if ok then
                count = count + 1
            elseif _G.geterrorhandler then
                _G.geterrorhandler()(err)
            end
        end
    end
    wipe(combatQueueOrder)

    if count > 0 then
        ns:Print(string.format(L["GUARD_COMBAT_APPLIED"], count))
    end
end

function Guard:HasQueuedTasks()
    return #combatQueueOrder > 0
end
