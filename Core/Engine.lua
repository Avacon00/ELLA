local AddonName, ns = ...

local Guard = ns.Guard
local Registry = ns.Registry

local Engine = {}
ns.Engine = Engine

-- Golden Rule #4: Private Weak-Key table for per-frame runtime state.
-- NEVER write properties directly onto Blizzard frames!
local frameState = setmetatable({}, { __mode = "k" })
local frameHooks = setmetatable({}, { __mode = "k" })
local dragRegions = setmetatable({}, { __mode = "k" })

local function CurrentState(frame)
    local state = frameState[frame]
    if state and state.attached and not state.retired
        and Registry:GetDescriptor(state.windowId) == state.desc and state.desc.boundFrame == frame then
        return state
    end
    return nil
end

-- Companion ownership is separate from a frame's own primary-window settings.
local linkedFrameStates = setmetatable({}, { __mode = "k" })
local linkedFrameHooks = setmetatable({}, { __mode = "k" })
local linkedApplyOrder = 0

-- Golden Rule #8: Event & Drag driver has OnUpdate == nil at rest (0.00 ms idle CPU).
local eventFrame = CreateFrame("Frame")
local dragDriver = CreateFrame("Frame")
local activeDrag = nil

-- Magnetic alignment visual guide lines (parented to UIParent, hidden whenever not snapping!)
local snapLineH = UIParent:CreateTexture(nil, "OVERLAY")
snapLineH:SetColorTexture(0.0, 0.85, 1.0, 0.70)
snapLineH:SetHeight(1.5)
snapLineH:Hide()

local snapLineV = UIParent:CreateTexture(nil, "OVERLAY")
snapLineV:SetColorTexture(0.0, 0.85, 1.0, 0.70)
snapLineV:SetWidth(1.5)
snapLineV:Hide()

local SNAP_THRESHOLD = 8
local SIDE_GAP = 6

-- UIParent-parented Ctrl+MouseWheel overlay (never touches EnableMouseWheel on Blizzard frames)
local ctrlWheelCatcher = CreateFrame("Frame", nil, UIParent)
ctrlWheelCatcher:Hide()
ctrlWheelCatcher:EnableMouse(false)
ctrlWheelCatcher:EnableMouseWheel(true)

function Engine:ClampScale(value)
    local num = tonumber(value) or ns.DEFAULT_SCALE
    if num < ns.MIN_SCALE then
        num = ns.MIN_SCALE
    elseif num > ns.MAX_SCALE then
        num = ns.MAX_SCALE
    end
    return math.floor(num * 100 + 0.5) / 100
end

-- Convert frame-local lengths and anchor offsets to and from UIParent units.
local function GetUipScale(frame)
    return frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
end

local function SetUipTopLeft(frame, uipX, uipY)
    local scale = GetUipScale(frame)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", uipX / scale, uipY / scale)
end

-- Reads a frame's current top-left coordinates in UIParent space (origin: UIParent TOPLEFT)
function Engine:ReadUipTopLeft(frame)
    local left = frame:GetLeft()
    local top = frame:GetTop()
    local uipH = UIParent:GetHeight()
    if not left or not top or not uipH or uipH <= 0 then
        return nil, nil
    end
    local s = GetUipScale(frame)
    local uipX = left * s
    local uipY = (top * s) - uipH
    return uipX, uipY
end

local function GetClampBounds(frame, scale)
    local uipW = UIParent:GetWidth() or 1920
    local uipH = UIParent:GetHeight() or 1080
    local rawW = frame:GetWidth() or 350
    local scaledW = rawW * GetUipScale(frame) * scale / (frame:GetScale() or 1)

    local minX = math.min(0, -scaledW + 120)
    local maxX = math.max(0, uipW - 120)
    local minY = -(uipH - 60)
    local maxY = 0
    return minX, maxX, minY, maxY
end

-- Golden Rule #7: Keep at least 120px width and the top titlebar inside the screen
function Engine:ClampUipPosition(frame, scale, uipX, uipY)
    if not ns.db or not ns.db.settings.clampToScreen then
        return uipX, uipY
    end
    local minX, maxX, minY, maxY = GetClampBounds(frame, scale)

    if uipX < minX then uipX = minX end
    if uipX > maxX then uipX = maxX end
    if uipY < minY then uipY = minY end
    if uipY > maxY then uipY = maxY end

    return uipX, uipY
end

function Engine:GetEffectiveWindowMode(windowId, desc)
    local isGlobalEnabled = (ns.db and ns.db.settings and ns.db.settings.enabled)
    if not isGlobalEnabled then
        return ns.MODE_DISABLED
    end
    desc = desc or Registry:GetDescriptor(windowId)
    local cfg = ns:GetWindowConfig(windowId, false)
    return (cfg and cfg.mode)
        or (desc and desc.defaultMode)
        or (ns.db and ns.db.settings and ns.db.settings.defaultScaleOnly and ns.MODE_SCALE_ONLY or ns.MODE_SCALE_MOVE)
end

function Engine:BuildDiagnosticsReport()
    local version, build, _, interface
    if _G.GetBuildInfo then
        version, build, _, interface = _G.GetBuildInfo()
    end
    local lines = {
        "ella_diagnostics=1",
        "addon_version=" .. tostring(ns.Version or "unknown"),
        "client_version=" .. tostring(version or "unknown"),
        "client_build=" .. tostring(build or "unknown"),
        "client_interface=" .. tostring(interface or "unknown"),
        "client_type=" .. (ns.IsForeverClient and "camelot" or "other"),
        "locale=" .. tostring(_G.GetLocale and _G.GetLocale() or "unknown"),
        string.format("ui_parent=%.0fx%.0f scale=%.3f", UIParent:GetWidth() or 0, UIParent:GetHeight() or 0,
            UIParent:GetEffectiveScale() or 1),
        "combat_pending=" .. tostring(Guard:HasQueuedTasks()),
        "drag_active=" .. tostring(activeDrag ~= nil),
    }

    local db = type(ns.db) == "table" and ns.db or {}
    local settings = type(db.settings) == "table" and db.settings or {}
    local windows = type(db.windows) == "table" and db.windows or {}
    local count = 0
    for id, desc in Registry:IterateWindows() do
        count = count + 1
        local cfg = type(windows[id]) == "table" and windows[id] or {}
        local mode = cfg.mode or desc.defaultMode
        if not settings.enabled then
            mode = ns.MODE_DISABLED
        elseif mode ~= ns.MODE_DISABLED and mode ~= ns.MODE_SCALE_ONLY and mode ~= ns.MODE_SCALE_MOVE then
            mode = settings.defaultScaleOnly and ns.MODE_SCALE_ONLY or ns.MODE_SCALE_MOVE
        end
        local frame = desc.boundFrame
        local state = "missing"
        if frame then
            local allowed, reason = Guard:CanModifyNow(frame, desc.protected)
            state = allowed and "bound" or (reason == "DEFERRED_COMBAT" and "combat_deferred" or "blocked")
        end
        -- Extension IDs, frame names, and labels can contain player-provided text.
        lines[#lines + 1] = string.format("window_%d state=%s mode=%s", count, state, mode)
    end
    lines[#lines + 1] = "window_count=" .. count
    return table.concat(lines, "\n")
end

function Engine:GetEffectiveWindowScale(windowId, desc)
    desc = desc or Registry:GetDescriptor(windowId)
    local cfg = ns:GetWindowConfig(windowId, false)
    local mode = Engine:GetEffectiveWindowMode(windowId, desc)
    local savedScale = Engine:ClampScale(cfg and cfg.scale or ns.DEFAULT_SCALE)
    if mode == ns.MODE_DISABLED then
        return ns.DEFAULT_SCALE, savedScale, false
    end
    if Engine.inCompactMode and savedScale > 0.75 then
        return 0.75, savedScale, true
    end
    return savedScale, savedScale, false
end

local function HasLinkedScaleChanges(desc)
    for _, state in pairs(linkedFrameStates[desc] or {}) do
        if state.modified then
            return true
        end
    end
    return false
end

local function FindLinkedScaleOwner(sub, excludedDesc, activeOnly)
    -- Shared companions keep the most recently applied remaining owner's scale.
    local bestDesc, bestState
    for owner, states in pairs(linkedFrameStates) do
        local state = states[sub]
        local isRegistered = Registry:GetDescriptor(owner.id) == owner
        if owner ~= excludedDesc and state and state.modified and (isRegistered or (not activeOnly and owner.retired)) then
            local isActive = isRegistered and Engine:GetEffectiveWindowMode(owner.id, owner) ~= ns.MODE_DISABLED
            if (not activeOnly or isActive) and (not bestState or state.order > bestState.order) then
                bestDesc, bestState = owner, state
            end
        end
    end
    return bestDesc, bestState
end

local SyncLinkedFrames

local function ApplyLinkedScale(windowId, desc, sub, state)
    if (Registry:GetDescriptor(windowId) ~= desc and not desc.retired) or state.applying or Guard:IsForbidden(sub) then
        return
    end

    local isDisabling = desc.retired or Engine:GetEffectiveWindowMode(windowId, desc) == ns.MODE_DISABLED
    if isDisabling and not state.modified then
        return
    end
    local nextOwner = isDisabling and FindLinkedScaleOwner(sub, desc, true) or nil
    local primary = isDisabling and CurrentState(sub) or nil
    local primaryOwner = primary and primary.desc or state.primaryOwner
    local restoreOwner = nextOwner or (isDisabling and primaryOwner)
    local canModify, reason = Guard:CanModifyNow(sub, desc.protected or (restoreOwner and restoreOwner.protected))
    if not canModify then
        if reason == "DEFERRED_COMBAT" then
            -- Reevaluate the whole companion group and current config after combat.
            Guard:EnqueueAfterCombat("linked:" .. desc.generation, Registry:GetDisplayLabel(desc), function()
                SyncLinkedFrames(windowId, desc)
            end)
        end
        return
    end

    local current = sub:GetScale() or 1
    local target = isDisabling and (state.initialScale or 1) or Engine:GetEffectiveWindowScale(windowId, desc)
    if nextOwner then
        target = Engine:GetEffectiveWindowScale(nextOwner.id, nextOwner)
    elseif isDisabling and primaryOwner then
        if Registry:GetDescriptor(primaryOwner.id) == primaryOwner
            and Engine:GetEffectiveWindowMode(primaryOwner.id, primaryOwner) ~= ns.MODE_DISABLED then
            target = Engine:GetEffectiveWindowScale(primaryOwner.id, primaryOwner)
        else
            target = (primary and primary.initialScale) or state.primaryNativeScale or target
        end
    end
    if not isDisabling then
        local _, otherState = FindLinkedScaleOwner(sub, desc, false)
        if state.modified or otherState or math.abs(current - target) > 0.001 then
            if not state.modified then
                state.initialScale = otherState and otherState.initialScale or current
                -- A companion can also be a primary window with its own native snapshot.
                local capturedPrimary = frameState[sub]
                if otherState then
                    state.primaryOwner = otherState.primaryOwner
                    state.primaryNativeScale = otherState.primaryNativeScale
                elseif capturedPrimary and capturedPrimary.attached and Registry:GetDescriptor(capturedPrimary.windowId) == capturedPrimary.desc then
                    state.primaryOwner = capturedPrimary.desc
                    state.primaryNativeScale = capturedPrimary.initialScale or current
                else
                    state.primaryOwner = nil
                    state.primaryNativeScale = nil
                end
            end
            state.modified = true
            linkedApplyOrder = linkedApplyOrder + 1
            state.order = linkedApplyOrder
        end
    end
    if math.abs(current - target) > 0.001 then
        state.applying = true
        sub:SetScale(target)
        state.applying = false
    end
    if isDisabling then
        state.modified = false
    end
end

-- Sync or restore companions, including ones whose main frame never needed a change.
SyncLinkedFrames = function(windowId, desc)
    if Registry:GetDescriptor(windowId) ~= desc and not desc.retired then
        return
    end
    local states = linkedFrameStates[desc]
    if desc.retired or Engine:GetEffectiveWindowMode(windowId, desc) == ns.MODE_DISABLED then
        for sub, state in pairs(states or {}) do
            ApplyLinkedScale(windowId, desc, sub, state)
        end
        return
    end
    if type(desc.linkedFrames) ~= "table" then
        return
    end
    if not states then
        states = setmetatable({}, { __mode = "k" })
        linkedFrameStates[desc] = states
    end
    for i = 1, #desc.linkedFrames do
        local sub = Registry:ResolveFramePath(desc.linkedFrames[i])
        if sub and sub ~= desc.boundFrame and not Guard:IsForbidden(sub) then
            local state = states[sub]
            if not state then
                state = {}
                states[sub] = state
                if type(sub.HookScript) == "function" and not linkedFrameHooks[sub] then
                    linkedFrameHooks[sub] = true
                    sub:HookScript("OnShow", function(sFrame)
                        local owners = {}
                        for owner, snapshots in pairs(linkedFrameStates) do
                            local snapshot = snapshots[sFrame]
                            if snapshot then owners[#owners + 1] = { desc = owner, state = snapshot } end
                        end
                        table.sort(owners, function(a, b)
                            local aOrder, bOrder = a.state.order or 0, b.state.order or 0
                            if aOrder == bOrder then return a.desc.generation < b.desc.generation end
                            return aOrder < bOrder
                        end)
                        for _, owner in ipairs(owners) do
                            ApplyLinkedScale(owner.desc.id, owner.desc, sFrame, owner.state)
                        end
                    end)
                end
            end
            ApplyLinkedScale(windowId, desc, sub, state)
        end
    end
end

local function HookFrameFade(frame, windowId, desc)
    local state = CurrentState(frame)
    local hooks = frameHooks[frame]
    if not state or not hooks or hooks.fadeWatcher then
        return
    end

    local fadeWatcher = CreateFrame("Frame")
    hooks.fadeWatcher = fadeWatcher
    fadeWatcher:Hide()
    fadeWatcher:SetScript("OnUpdate", function(self)
        local current = CurrentState(frame)
        if not current then
            self:Hide()
            return
        end
        local currentId, currentDesc = current.windowId, current.desc
        if not frame:IsShown() or not frame:IsMouseOver() then
            self:Hide()
            if activeDrag and activeDrag.frame == frame then
                return
            end
            local mode = Engine:GetEffectiveWindowMode(currentId, currentDesc)
            if mode == ns.MODE_DISABLED then
                return
            end
            local cfg = ns:GetWindowConfig(currentId, false)
            local a = (cfg and cfg.alpha) or 1.0
            if type(frame.SetAlpha) == "function" then
                frame:SetAlpha(a)
            end
        end
    end)

    if type(frame.HookScript) == "function" then
        frame:HookScript("OnEnter", function(f)
            local current = CurrentState(f)
            if not current then return end
            local mode = Engine:GetEffectiveWindowMode(current.windowId, current.desc)
            if mode == ns.MODE_DISABLED then
                return
            end
            local cfg = ns:GetWindowConfig(current.windowId, false)
            if cfg and cfg.mouseoverFade and not (activeDrag and activeDrag.frame == f) then
                if type(f.SetAlpha) == "function" then
                    f:SetAlpha(1.0)
                end
                fadeWatcher:Show()
            end
        end)
        frame:HookScript("OnHide", function()
            fadeWatcher:Hide()
        end)
    end
end

function Engine:ApplyAlphaToFrame(windowId, frame, desc)
    if not frame or Guard:IsForbidden(frame) then
        return
    end
    local state = CurrentState(frame)
    if not state or state.desc ~= desc or state.windowId ~= windowId then return end
    local mode = Engine:GetEffectiveWindowMode(windowId, desc)
    if mode == ns.MODE_DISABLED then
        if state and state.hasEllaAlpha and type(frame.SetAlpha) == "function" then
            frame:SetAlpha(state.initialAlpha or 1.0)
            state.hasEllaAlpha = false
        end
        return
    end

    HookFrameFade(frame, windowId, desc)

    local cfg = ns:GetWindowConfig(windowId, false)
    local targetAlpha = (cfg and cfg.alpha) or 1.0
    local isMouseoverFade = (cfg and cfg.mouseoverFade) or false

    if activeDrag and activeDrag.frame == frame then
        return
    end

    -- Preserve native third-party frame alpha if the user has not customized opacity/fade in Ella
    if targetAlpha >= 0.999 and not isMouseoverFade and not (state and state.hasEllaAlpha) then
        return
    end

    if state and state.initialAlpha == nil then
        state.initialAlpha = (type(frame.GetAlpha) == "function" and frame:GetAlpha()) or 1.0
    end

    if isMouseoverFade and frame:IsShown() and frame:IsMouseOver() then
        if type(frame.SetAlpha) == "function" then
            frame:SetAlpha(1.0)
            if state then state.hasEllaAlpha = true end
        end
    else
        if type(frame.SetAlpha) == "function" then
            frame:SetAlpha(targetAlpha)
            if state then state.hasEllaAlpha = (targetAlpha < 0.999 or isMouseoverFade) end
        end
    end
end

-- Applies scale and (when in SCALE_AND_MOVE mode with saved pos) scale-compensated anchor
function Engine:ApplyToFrame(windowId, frame, desc)
    local state = CurrentState(frame)
    if not state or state.desc ~= desc or state.windowId ~= windowId or state.applying then
        return
    end

    local cfg = ns:GetWindowConfig(windowId, false)
    local mode = Engine:GetEffectiveWindowMode(windowId, desc)

    -- 100% Hands-Off Guarantee when a window/AddOn is set to Off (MODE_DISABLED):
    -- On /reload or OnShow, if Ella has not modified this frame during the session,
    -- touch NOTHING (zero SetScale, zero SetAlpha, zero SetPoint) so third-party
    -- AddOns retain complete ownership of their native position, scale, and opacity!
    if mode == ns.MODE_DISABLED then
        if not state.hasEllaScaled and not state.hasEllaAlpha and not state.hasCustomPosApplied and not HasLinkedScaleChanges(desc) then
            ns:Fire("OnWindowApplied", windowId, frame, frame:GetScale() or 1, mode)
            return
        end

        local canRestore, restoreReason = Guard:CanModifyNow(frame, desc.protected)
        if not canRestore then
            if restoreReason == "DEFERRED_COMBAT" then
                Guard:EnqueueAfterCombat("apply:" .. windowId, Registry:GetDisplayLabel(desc), function()
                    Engine:ApplyToFrame(windowId, frame, desc)
                end)
            end
            return
        end

        state.applying = true
        if state.hasEllaScaled then
            local linkedOwner = FindLinkedScaleOwner(frame, desc, true)
            local origScale = linkedOwner and Engine:GetEffectiveWindowScale(linkedOwner.id, linkedOwner) or state.initialScale or 1
            frame:SetScale(origScale)
            state.hasEllaScaled = false
        end
        SyncLinkedFrames(windowId, desc)
        Engine:ApplyAlphaToFrame(windowId, frame, desc)
        if state.hasCustomPosApplied and state.initialPoints then
            frame:ClearAllPoints()
            for i = 1, #state.initialPoints do
                local p = state.initialPoints[i]
                frame:SetPoint(p[1], p[2], p[3], p[4], p[5])
            end
            state.hasCustomPosApplied = false
        end
        state.applying = false
        ns:Fire("OnWindowApplied", windowId, frame, frame:GetScale() or 1, mode)
        return
    end

    local targetScale = Engine:GetEffectiveWindowScale(windowId, desc)

    local canModify, reason = Guard:CanModifyNow(frame, desc.protected)
    if not canModify then
        if reason == "DEFERRED_COMBAT" then
            Guard:EnqueueAfterCombat("apply:" .. windowId, Registry:GetDisplayLabel(desc), function()
                Engine:ApplyToFrame(windowId, frame, desc)
            end)
        end
        return
    end

    state.applying = true

    if state.initialScale == nil then
        state.initialScale = frame:GetScale() or 1.0
    end

    -- Snapshot original pristine anchor points once before any custom move
    if not state.initialPoints and type(frame.GetNumPoints) == "function" then
        local numPts = frame:GetNumPoints()
        if numPts and numPts > 0 then
            local pts = {}
            for i = 1, numPts do
                local pt, relTo, relPt, xOfs, yOfs = frame:GetPoint(i)
                pts[#pts + 1] = { pt, relTo, relPt, xOfs, yOfs }
            end
            state.initialPoints = pts
        end
    end

    local currentScale = frame:GetScale() or 1
    if math.abs(currentScale - targetScale) > 0.001 then
        frame:SetScale(targetScale)
        state.hasEllaScaled = true
    elseif math.abs(targetScale - (state.initialScale or 1.0)) > 0.001 then
        state.hasEllaScaled = true
    end
    SyncLinkedFrames(windowId, desc)
    Engine:ApplyAlphaToFrame(windowId, frame, desc)

    if mode == ns.MODE_SCALE_MOVE and cfg and cfg.pos and cfg.pos.uipX and cfg.pos.uipY then
        local clampedX, clampedY = Engine:ClampUipPosition(frame, targetScale, cfg.pos.uipX, cfg.pos.uipY)
        cfg.pos.uipX = clampedX
        cfg.pos.uipY = clampedY
        SetUipTopLeft(frame, clampedX, clampedY)
        state.hasCustomPosApplied = true
    elseif state.hasCustomPosApplied and state.initialPoints then
        frame:ClearAllPoints()
        for i = 1, #state.initialPoints do
            local p = state.initialPoints[i]
            frame:SetPoint(p[1], p[2], p[3], p[4], p[5])
        end
        state.hasCustomPosApplied = false
    end

    state.applying = false
    ns:Fire("OnWindowApplied", windowId, frame, targetScale, mode)
end

-- Changes scale of a window, optionally pivoting around the mouse cursor so the hovered badge/titlebar never jumps away
function Engine:SetWindowScale(windowId, requestedScale, pivotAroundCursor)
    local desc = Registry:GetDescriptor(windowId)
    if not desc then
        return false
    end

    local cfg = ns:GetWindowConfig(windowId, true)
    if ns.Profiles and ns.Profiles.PushUndoSnapshot then
        ns.Profiles:PushUndoSnapshot("scale:" .. windowId)
    end
    if cfg.mode == ns.MODE_DISABLED then
        cfg.mode = ns.db.settings.defaultScaleOnly and ns.MODE_SCALE_ONLY or ns.MODE_SCALE_MOVE
    end

    local newScale = Engine:ClampScale(requestedScale)
    local frame = desc.boundFrame

    if frame and frame:IsShown() then
        local canModify, reason = Guard:CanModifyNow(frame, desc.protected)
        if not canModify then
            cfg.scale = newScale
            if reason == "DEFERRED_COMBAT" then
                Guard:EnqueueAfterCombat("apply:" .. windowId, Registry:GetDisplayLabel(desc), function()
                    Engine:ApplyToFrame(windowId, frame, desc)
                end)
            end
            ns:Fire("OnWindowConfigChanged", windowId, cfg)
            return false
        end

        local oldScale = (cfg.scale and cfg.scale > 0) and cfg.scale or (frame:GetScale() or 1)
        local effOldScale = Engine.inCompactMode and math.min(oldScale, 0.75) or oldScale
        local effNewScale = Engine.inCompactMode and math.min(newScale, 0.75) or newScale
        local readX, readY = Engine:ReadUipTopLeft(frame)
        local oldUipX = (cfg.pos and cfg.pos.uipX) or readX
        local oldUipY = (cfg.pos and cfg.pos.uipY) or readY

        if cfg.mode == ns.MODE_SCALE_MOVE and oldUipX and oldUipY then
            if pivotAroundCursor then
                local curX, curY = GetCursorPosition()
                local uipEff = UIParent:GetEffectiveScale() or 1
                local uipH = UIParent:GetHeight() or 1080
                local cX = curX / uipEff
                local cY = (curY / uipEff) - uipH
                local ratio = effNewScale / effOldScale
                cfg.pos = {
                    uipX = cX - (cX - oldUipX) * ratio,
                    uipY = cY - (cY - oldUipY) * ratio,
                }
            elseif not cfg.pos or not cfg.pos.uipX or not cfg.pos.uipY then
                -- Pin initial top-left position once so scaling via slider/+/- keeps top-left rock-steady
                cfg.pos = {
                    uipX = oldUipX,
                    uipY = oldUipY,
                }
            end
        end

        cfg.scale = newScale
        Engine:ApplyToFrame(windowId, frame, desc)
    else
        cfg.scale = newScale
    end

    ns.db.settings.activePreset = nil
    ns:Fire("OnWindowConfigChanged", windowId, cfg)
    return true
end

function Engine:StepWindowScale(windowId, deltaTicks, isFineStep, pivotAroundCursor)
    if not Registry:GetDescriptor(windowId) then return false end
    local cfg = ns:GetWindowConfig(windowId, true)
    local step = isFineStep and ns.STEP_FINE or ns.STEP_COARSE
    local current = cfg.scale or ns.DEFAULT_SCALE
    return Engine:SetWindowScale(windowId, current + (deltaTicks * step), pivotAroundCursor)
end

function Engine:SetWindowAlpha(windowId, requestedAlpha, mouseoverFade)
    local desc = Registry:GetDescriptor(windowId)
    if not desc then
        return false
    end
    local cfg = ns:GetWindowConfig(windowId, true)
    if ns.Profiles and ns.Profiles.PushUndoSnapshot then
        ns.Profiles:PushUndoSnapshot("alpha:" .. windowId)
    end

    if requestedAlpha ~= nil then
        local a = tonumber(requestedAlpha) or ns.MAX_ALPHA
        if a < ns.MIN_ALPHA then a = ns.MIN_ALPHA elseif a > ns.MAX_ALPHA then a = ns.MAX_ALPHA end
        cfg.alpha = math.floor(a * 100 + 0.5) / 100
    end

    if mouseoverFade ~= nil then
        cfg.mouseoverFade = (mouseoverFade == true)
    end

    if desc.boundFrame then
        Engine:ApplyAlphaToFrame(windowId, desc.boundFrame, desc)
    end

    ns.db.settings.activePreset = nil
    ns:Fire("OnWindowConfigChanged", windowId, cfg)
    return true
end

function Engine:SetWindowMode(windowId, newMode)
    local desc = Registry:GetDescriptor(windowId)
    if not desc then
        return
    end
    if ns.Profiles and ns.Profiles.PushUndoSnapshot then
        ns.Profiles:PushUndoSnapshot("mode:" .. windowId)
    end
    local cfg = ns:GetWindowConfig(windowId, true)
    if newMode == ns.MODE_DISABLED and cfg.mode and cfg.mode ~= ns.MODE_DISABLED then
        cfg.prevMode = cfg.mode
    elseif newMode ~= ns.MODE_DISABLED then
        cfg.prevMode = newMode
    end
    cfg.mode = newMode
    if desc.boundFrame then
        Engine:ApplyToFrame(windowId, desc.boundFrame, desc)
    end
    ns:Fire("OnWindowConfigChanged", windowId, cfg)
end

function Engine:SetWindowEnabled(windowId, enabled)
    local desc = Registry:GetDescriptor(windowId)
    if not desc then
        return false, "unknown_window"
    end
    local cfg = ns:GetWindowConfig(windowId, true)
    if enabled then
        local restoreMode = cfg.prevMode
        if restoreMode ~= ns.MODE_SCALE_MOVE and restoreMode ~= ns.MODE_SCALE_ONLY then
            restoreMode = (ns.db and ns.db.settings and ns.db.settings.defaultScaleOnly) and ns.MODE_SCALE_ONLY or ns.MODE_SCALE_MOVE
        end
        Engine:SetWindowMode(windowId, restoreMode)
    else
        Engine:SetWindowMode(windowId, ns.MODE_DISABLED)
    end
    return true
end

function Engine:ToggleWindowEnabled(windowId)
    local desc = Registry:GetDescriptor(windowId)
    if not desc then
        return false
    end
    local curMode = Engine:GetEffectiveWindowMode(windowId, desc)
    local willEnable = (curMode == ns.MODE_DISABLED)
    Engine:SetWindowEnabled(windowId, willEnable)
    return willEnable
end

function Engine:SetWindowBadgeHidden(windowId, hidden)
    local desc = Registry:GetDescriptor(windowId)
    if not desc then
        return false, "unknown_window"
    end
    if ns.Profiles and ns.Profiles.PushUndoSnapshot then
        ns.Profiles:PushUndoSnapshot("badge:" .. windowId)
    end
    local cfg = ns:GetWindowConfig(windowId, true)
    cfg.hideBadge = (hidden == true)
    ns:Fire("OnWindowConfigChanged", windowId, cfg)
    return true
end

function Engine:ToggleWindowBadge(windowId)
    local cfg = ns:GetWindowConfig(windowId, true)
    local newHidden = not (cfg.hideBadge == true)
    Engine:SetWindowBadgeHidden(windowId, newHidden)
    return not newHidden
end

function Engine:ResetWindow(windowId, resetPositionOnly)
    local desc = Registry:GetDescriptor(windowId)
    local cfg = ns:GetWindowConfig(windowId, false)
    if not cfg then
        return
    end
    if ns.Profiles and ns.Profiles.PushUndoSnapshot then
        ns.Profiles:PushUndoSnapshot("reset:" .. windowId)
    end
    cfg.pos = nil
    if not resetPositionOnly then
        cfg.scale = ns.DEFAULT_SCALE
        cfg.alpha = 1.00
        cfg.mouseoverFade = false
    end
    if desc and desc.boundFrame then
        Engine:ApplyToFrame(windowId, desc.boundFrame, desc)
    end
    ns:Fire("OnWindowConfigChanged", windowId, cfg)
end

-- State for audio feedback during magnetic snapping
local isCurrentlySnapped = false
local lastSnapSoundTime = 0

-- Computes magnetic top-edge / side-by-side snap against other visible windows + Shift 10px grid
local function ApplyMagneticOrGridSnap(draggedFrame, candX, candY)
    snapLineH:Hide()
    snapLineV:Hide()

    if IsShiftKeyDown() then
        isCurrentlySnapped = false
        return math.floor(candX / 10 + 0.5) * 10, math.floor(candY / 10 + 0.5) * 10
    end

    if not ns.db or not ns.db.settings.magneticSnap then
        isCurrentlySnapped = false
        return candX, candY
    end

    local thisW = (draggedFrame:GetWidth() or 350) * GetUipScale(draggedFrame)
    local snappedX, snappedY = candX, candY
    local guideY, guideX = nil, nil

    -- Snap to horizontal screen center if near middle
    local uipW = UIParent:GetWidth() or 1920
    local centerTargetX = (uipW - thisW) * 0.5
    if math.abs(candX - centerTargetX) <= SNAP_THRESHOLD then
        snappedX = centerTargetX
        guideX = uipW * 0.5
    end

    -- Snap against other visible managed windows (top edge alignment + side-by-side docking)
    for _, otherDesc in Registry:IterateWindows() do
        local other = otherDesc.boundFrame
        if other and other ~= draggedFrame and other:IsShown() then
            local oX, oY = Engine:ReadUipTopLeft(other)
            if oX and oY then
                local oScale = GetUipScale(other)
                local oW = (other:GetWidth() or 350) * oScale

                -- Top-edge row alignment
                if not guideY and math.abs(candY - oY) <= SNAP_THRESHOLD then
                    snappedY = oY
                    guideY = oY
                end

                -- Side-by-side docking (left of other, right of other, or left-edge aligned)
                if not guideX then
                    local rightDock = oX + oW + SIDE_GAP
                    local leftDock = oX - thisW - SIDE_GAP
                    if math.abs(candX - rightDock) <= SNAP_THRESHOLD then
                        snappedX = rightDock
                        guideX = oX + oW + (SIDE_GAP * 0.5)
                    elseif math.abs(candX - leftDock) <= SNAP_THRESHOLD then
                        snappedX = leftDock
                        guideX = oX - (SIDE_GAP * 0.5)
                    elseif math.abs(candX - oX) <= SNAP_THRESHOLD then
                        snappedX = oX
                        guideX = oX
                    end
                end
            end
        end
    end

    local isSnapped = (guideY ~= nil or guideX ~= nil)
    if isSnapped then
        if not isCurrentlySnapped then
            local now = _G.GetTime and _G.GetTime() or 0
            if (now - lastSnapSoundTime) > 0.20 then
                ns:PlaySound("SNAP")
                lastSnapSoundTime = now
            end
            isCurrentlySnapped = true
        end
    else
        isCurrentlySnapped = false
    end

    if guideY then
        snapLineH:ClearAllPoints()
        snapLineH:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, guideY)
        snapLineH:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, guideY)
        snapLineH:Show()
    end
    if guideX then
        snapLineV:ClearAllPoints()
        snapLineV:SetPoint("TOPLEFT", UIParent, "TOPLEFT", guideX, 0)
        snapLineV:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", guideX, 0)
        snapLineV:Show()
    end

    return snappedX, snappedY
end

-- Checks if two managed frames share a touching or aligned edge within threshold
local function AreFramesDocked(frameA, frameB)
    local aX, aY = Engine:ReadUipTopLeft(frameA)
    local bX, bY = Engine:ReadUipTopLeft(frameB)
    if not aX or not aY or not bX or not bY then
        return false
    end

    local aScale = GetUipScale(frameA)
    local bScale = GetUipScale(frameB)
    local aW = (frameA:GetWidth() or 350) * aScale
    local aH = (frameA:GetHeight() or 400) * aScale
    local bW = (frameB:GetWidth() or 350) * bScale
    local bH = (frameB:GetHeight() or 400) * bScale

    -- Tolerance for snapping / docking: 16 UIParent pixels
    local TOL = 16

    local hOverlap = (aX <= (bX + bW + TOL)) and ((aX + aW + TOL) >= bX)
    local vOverlap = ((aY - aH - TOL) <= bY) and (aY >= (bY - bH - TOL))

    -- Touching side-by-side (within TOL) and overlapping vertically:
    local touchSide = vOverlap and (math.abs((aX + aW) - bX) <= TOL or math.abs((bX + bW) - aX) <= TOL)
    -- Touching top-to-bottom (within TOL) and overlapping horizontally:
    local touchVert = hOverlap and (math.abs((aY - aH) - bY) <= TOL or math.abs((bY - bH) - aY) <= TOL)
    -- Aligned top edge and close together horizontally:
    local touchAligned = (math.abs(aY - bY) <= TOL) and (math.abs((aX + aW) - bX) <= TOL or math.abs((bX + bW) - aX) <= TOL)

    return touchSide or touchVert or touchAligned
end

function Engine:FindDockedCluster(sourceFrame)
    local cluster = {}
    local visited = { [sourceFrame] = true }
    local queue = { sourceFrame }

    while #queue > 0 do
        local curr = table.remove(queue, 1)
        for otherId, otherDesc in Registry:IterateWindows() do
            local other = otherDesc.boundFrame
            if other and other ~= sourceFrame and other:IsShown() and not visited[other] and not otherDesc.protected and not Guard:IsForbidden(other) then
                local oCfg = ns:GetWindowConfig(otherId, false)
                local oMode = Engine:GetEffectiveWindowMode(otherId, otherDesc)
                local oLocked = (oCfg and oCfg.locked) or false
                if oMode == ns.MODE_SCALE_MOVE and not oLocked then
                    if AreFramesDocked(curr, other) then
                        visited[other] = true
                        local oX, oY = Engine:ReadUipTopLeft(other)
                        if oX and oY then
                            local oScale = other:GetScale() or 1
                            local oAlpha = (type(other.GetAlpha) == "function" and other:GetAlpha()) or 1
                            cluster[#cluster + 1] = {
                                windowId = otherId,
                                frame = other,
                                desc = otherDesc,
                                startUipX = oX,
                                startUipY = oY,
                                lastUipX = oX,
                                lastUipY = oY,
                                scale = oScale,
                                origAlpha = oAlpha,
                            }
                            queue[#queue + 1] = other
                        end
                    end
                end
            end
        end
    end
    return cluster
end

-- Active Drag Loop (ONLY active while Left Mouse Button is held down)
local function OnDragUpdate()
    if not activeDrag then
        dragDriver:SetScript("OnUpdate", nil)
        snapLineH:Hide()
        snapLineV:Hide()
        return
    end

    local frame = activeDrag.frame
    local desc = activeDrag.desc
    if not frame or not frame:IsShown() or not Guard:CanModifyNow(frame, desc.protected) then
        Engine:StopActiveDrag()
        return
    end

    local curX, curY = GetCursorPosition()
    local uipEff = UIParent:GetEffectiveScale() or 1
    local dX = (curX - activeDrag.startCursorX) / uipEff
    local dY = (curY - activeDrag.startCursorY) / uipEff

    local scale = frame:GetScale() or 1
    local rawX = activeDrag.startUipX + dX
    local rawY = activeDrag.startUipY + dY
    local snappedX, snappedY = ApplyMagneticOrGridSnap(frame, rawX, rawY)

    local isAltDown = IsAltKeyDown()
    local hasDocked = (activeDrag.dockedFrames and #activeDrag.dockedFrames > 0)
    local deltaX = snappedX - activeDrag.startUipX
    local deltaY = snappedY - activeDrag.startUipY

    -- Rigid group screen-edge clamping so docked windows never squash into each other
    if not isAltDown and hasDocked and ns.db and ns.db.settings.clampToScreen then
        local pMinX, pMaxX, pMinY, pMaxY = GetClampBounds(frame, scale)
        local minDeltaX = pMinX - activeDrag.startUipX
        local maxDeltaX = pMaxX - activeDrag.startUipX
        local minDeltaY = pMinY - activeDrag.startUipY
        local maxDeltaY = pMaxY - activeDrag.startUipY

        for i = 1, #activeDrag.dockedFrames do
            local docked = activeDrag.dockedFrames[i]
            local dFrame = docked.frame
            if dFrame and dFrame:IsShown() and Guard:CanModifyNow(dFrame, docked.desc.protected) then
                local dMinX, dMaxX, dMinY, dMaxY = GetClampBounds(dFrame, docked.scale)
                minDeltaX = math.max(minDeltaX, dMinX - docked.startUipX)
                maxDeltaX = math.min(maxDeltaX, dMaxX - docked.startUipX)
                minDeltaY = math.max(minDeltaY, dMinY - docked.startUipY)
                maxDeltaY = math.min(maxDeltaY, dMaxY - docked.startUipY)
            end
        end

        if minDeltaX <= maxDeltaX then
            if deltaX < minDeltaX then deltaX = minDeltaX elseif deltaX > maxDeltaX then deltaX = maxDeltaX end
        end
        if minDeltaY <= maxDeltaY then
            if deltaY < minDeltaY then deltaY = minDeltaY elseif deltaY > maxDeltaY then deltaY = maxDeltaY end
        end
    end

    local newUipX, newUipY = Engine:ClampUipPosition(frame, scale, activeDrag.startUipX + deltaX, activeDrag.startUipY + deltaY)
    deltaX = newUipX - activeDrag.startUipX
    deltaY = newUipY - activeDrag.startUipY

    local state = frameState[frame]
    if state then
        state.applying = true
        state.hasCustomPosApplied = true
    end
    SetUipTopLeft(frame, newUipX, newUipY)
    if state then
        state.applying = false
    end

    activeDrag.lastUipX = newUipX
    activeDrag.lastUipY = newUipY

    -- Synchronous Docked Group Dragging
    -- If [Alt] is held down, user explicitly detaches/unsticks this window from the group
    if hasDocked then
        for i = 1, #activeDrag.dockedFrames do
            local docked = activeDrag.dockedFrames[i]
            local dFrame = docked.frame
            if dFrame and dFrame:IsShown() and Guard:CanModifyNow(dFrame, docked.desc.protected) then
                local targetX = isAltDown and docked.startUipX or (docked.startUipX + deltaX)
                local targetY = isAltDown and docked.startUipY or (docked.startUipY + deltaY)
                local cX, cY = Engine:ClampUipPosition(dFrame, docked.scale, targetX, targetY)

                local dState = frameState[dFrame]
                if dState then
                    dState.applying = true
                    dState.hasCustomPosApplied = true
                end
                SetUipTopLeft(dFrame, cX, cY)
                if dState then
                    dState.applying = false
                end
                docked.lastUipX = cX
                docked.lastUipY = cY
            end
        end
    end
end

function Engine:StartWindowDrag(windowId, frame, desc)
    if not ns.db or not ns.db.settings.enabled then
        return
    end
    local binding = CurrentState(frame)
    if not binding or binding.windowId ~= windowId or binding.desc ~= desc then return end
    local cfg = ns:GetWindowConfig(windowId, true)
    if cfg.mode ~= ns.MODE_SCALE_MOVE or cfg.locked then
        return
    end
    if not Guard:CanModifyNow(frame, desc.protected) then
        return
    end

    local uipX, uipY = Engine:ReadUipTopLeft(frame)
    if not uipX or not uipY then
        return
    end

    if ns.Profiles and ns.Profiles.PushUndoSnapshot then
        ns.Profiles:PushUndoSnapshot("drag:" .. windowId)
    end

    local state = frameState[frame]
    if state and not state.initialPoints and type(frame.GetNumPoints) == "function" then
        local numPts = frame:GetNumPoints()
        if numPts and numPts > 0 then
            local pts = {}
            for i = 1, numPts do
                local pt, relTo, relPt, xOfs, yOfs = frame:GetPoint(i)
                pts[#pts + 1] = { pt, relTo, relPt, xOfs, yOfs }
            end
            state.initialPoints = pts
        end
    end

    local origAlpha = (type(frame.GetAlpha) == "function" and frame:GetAlpha()) or 1
    local dragAlphaApplied = ns.db.settings.dragOpacity and origAlpha > 0.78 and type(frame.SetAlpha) == "function"
    if dragAlphaApplied then
        frame:SetAlpha(0.78)
    end

    local dockedCluster = {}
    if ns.db.settings.stickyDocking then
        dockedCluster = Engine:FindDockedCluster(frame)
        if ns.db.settings.dragOpacity then
            for i = 1, #dockedCluster do
                local d = dockedCluster[i]
                if d.frame and d.origAlpha > 0.78 and type(d.frame.SetAlpha) == "function" then
                    d.frame:SetAlpha(0.78)
                    d.dragAlphaApplied = true
                end
            end
        end
    end

    local curX, curY = GetCursorPosition()
    activeDrag = {
        windowId = windowId,
        frame = frame,
        desc = desc,
        originalAlpha = origAlpha,
        dragAlphaApplied = dragAlphaApplied,
        startCursorX = curX,
        startCursorY = curY,
        startUipX = uipX,
        startUipY = uipY,
        lastUipX = uipX,
        lastUipY = uipY,
        dockedFrames = dockedCluster,
    }
    if state then
        state.isDragging = true
    end
    ns:Fire("OnWindowDragStarted", windowId, frame)
    dragDriver:SetScript("OnUpdate", OnDragUpdate)
end

local function RestoreDragAlpha(windowId, frame, desc, originalAlpha, dragAlphaApplied)
    if not frame or Guard:IsForbidden(frame) then
        return
    end
    local canModify, reason = Guard:CanModifyNow(frame, desc and desc.protected)
    if not canModify then
        if reason == "DEFERRED_COMBAT" and desc then
            Guard:EnqueueAfterCombat("drag-alpha:" .. desc.generation, Registry:GetDisplayLabel(desc), function()
                local current = CurrentState(frame)
                if current and current.desc == desc then
                    RestoreDragAlpha(windowId, frame, desc, originalAlpha, dragAlphaApplied)
                end
            end)
        end
        return
    end
    -- Temporary drag opacity is independent of persistent Ella alpha ownership.
    -- Restore it first so a new opacity setting captures the pristine native alpha.
    if dragAlphaApplied and originalAlpha ~= nil and type(frame.SetAlpha) == "function" then
        frame:SetAlpha(originalAlpha)
    end
    if desc then
        Engine:ApplyAlphaToFrame(windowId, frame, desc)
    end
end

function Engine:StopActiveDrag()
    dragDriver:SetScript("OnUpdate", nil)
    snapLineH:Hide()
    snapLineV:Hide()
    isCurrentlySnapped = false
    if not activeDrag then
        return
    end
    local finished = activeDrag
    activeDrag = nil

    RestoreDragAlpha(finished.windowId, finished.frame, finished.desc, finished.originalAlpha, finished.dragAlphaApplied)

    local state = frameState[finished.frame]
    if state then
        state.isDragging = false
    end

    local current = CurrentState(finished.frame)
    if current and current.desc == finished.desc then
        local cfg = ns:GetWindowConfig(finished.windowId, true)
        cfg.pos = { uipX = finished.lastUipX, uipY = finished.lastUipY }
        ns:Fire("OnWindowConfigChanged", finished.windowId, cfg)
    end

    -- Handle docked frames from sticky dragging
    if finished.dockedFrames and #finished.dockedFrames > 0 then
        local isAltDown = IsAltKeyDown()
        for i = 1, #finished.dockedFrames do
            local docked = finished.dockedFrames[i]
            RestoreDragAlpha(docked.windowId, docked.frame, docked.desc, docked.origAlpha, docked.dragAlphaApplied)

            -- Only persist docked positions if not detached with Alt
            local dockedState = CurrentState(docked.frame)
            if not isAltDown and docked.lastUipX and docked.lastUipY and dockedState and dockedState.desc == docked.desc then
                local dCfg = ns:GetWindowConfig(docked.windowId, true)
                dCfg.pos = {
                    uipX = docked.lastUipX,
                    uipY = docked.lastUipY,
                }
                ns:Fire("OnWindowConfigChanged", docked.windowId, dCfg)
            end
        end
    end
    ns:Fire("OnWindowDragStopped", finished.windowId, finished.frame)
end

local function HookDragRegion(region, windowId, rootFrame, desc)
    if not region or Guard:IsForbidden(region) or type(region.HookScript) ~= "function" then
        return
    end
    local binding = dragRegions[region]
    if binding then
        binding.windowId, binding.rootFrame, binding.desc = windowId, rootFrame, desc
        return
    end
    binding = { windowId = windowId, rootFrame = rootFrame, desc = desc }
    dragRegions[region] = binding

    region:HookScript("OnMouseDown", function(_, button)
        local current = CurrentState(binding.rootFrame)
        if not current or current.desc ~= binding.desc then return end
        if button == "LeftButton" and not IsControlKeyDown() then
            Engine:StartWindowDrag(binding.windowId, binding.rootFrame, binding.desc)
        elseif button == "RightButton" and IsControlKeyDown() then
            Engine:ResetWindow(binding.windowId, IsShiftKeyDown())
        end
    end)

    region:HookScript("OnMouseUp", function(_, button)
        local current = CurrentState(binding.rootFrame)
        if button == "LeftButton" and current and current.desc == binding.desc then
            Engine:StopActiveDrag()
        end
    end)
end

local RestoreDetachedFrame
RestoreDetachedFrame = function(frame, state)
    if frameState[frame] ~= state or not state.retired then return false end
    if not state.hasEllaScaled and not state.hasEllaAlpha and not state.hasCustomPosApplied and state.dragRestoreAlpha == nil then
        return true
    end
    local canModify, reason = Guard:CanModifyNow(frame, state.desc.protected)
    if not canModify then
        if reason == "DEFERRED_COMBAT" then
            Guard:EnqueueAfterCombat("detach:" .. state.desc.generation, Registry:GetDisplayLabel(state.desc), function()
                if RestoreDetachedFrame(frame, state) then Registry:ScanUnboundWindows() end
            end)
        end
        return false
    end
    state.applying = true
    if state.hasEllaScaled then
        local linkedOwner = FindLinkedScaleOwner(frame, state.desc, true)
        local scale = linkedOwner and Engine:GetEffectiveWindowScale(linkedOwner.id, linkedOwner) or state.initialScale or 1
        frame:SetScale(scale)
        state.hasEllaScaled = false
    end
    local alpha = state.hasEllaAlpha and (state.initialAlpha or 1) or state.dragRestoreAlpha
    if alpha ~= nil and type(frame.SetAlpha) == "function" then frame:SetAlpha(alpha) end
    state.hasEllaAlpha, state.dragRestoreAlpha = false, nil
    if state.hasCustomPosApplied and state.initialPoints then
        frame:ClearAllPoints()
        for i = 1, #state.initialPoints do
            local p = state.initialPoints[i]
            frame:SetPoint(p[1], p[2], p[3], p[4], p[5])
        end
    end
    state.hasCustomPosApplied = false
    state.applying = false
    return true
end

function Engine:DetachWindow(windowId, frame, desc)
    local state = frame and frameState[frame]
    if state and state.desc == desc then
        state.retired = true
        local hooks = frameHooks[frame]
        if hooks and hooks.fadeWatcher then hooks.fadeWatcher:Hide() end
        if activeDrag then
            local stopping = activeDrag.frame == frame
            if stopping and activeDrag.dragAlphaApplied then state.dragRestoreAlpha = activeDrag.originalAlpha end
            for _, docked in ipairs(activeDrag.dockedFrames or {}) do
                if docked.frame == frame then
                    stopping = true
                    if docked.dragAlphaApplied then state.dragRestoreAlpha = docked.origAlpha end
                end
            end
            if stopping then Engine:StopActiveDrag() end
        end
        RestoreDetachedFrame(frame, state)
    end
    SyncLinkedFrames(windowId, desc)
    if ctrlWheelCatcher.targetWindowId == windowId then
        ctrlWheelCatcher.targetWindowId = nil
        ctrlWheelCatcher:Hide()
    end
end

-- Attaches non-invasive hooks to a Blizzard or third-party window
function Engine:AttachWindow(windowId, frame, desc)
    if Guard:IsForbidden(frame) then
        return false
    end
    local previous = frameState[frame]
    if previous and previous.attached then
        if not previous.retired then
            return previous.desc == desc and previous.windowId == windowId
        end
        if not RestoreDetachedFrame(frame, previous) then return false end
    end

    -- A frame first bound as a primary may already be scaled by a companion owner.
    local _, linkedState = FindLinkedScaleOwner(frame, desc, false)
    local nativeScale = linkedState and (linkedState.primaryNativeScale or linkedState.initialScale)
    frameState[frame] = { attached = true, windowId = windowId, desc = desc, initialScale = nativeScale }
    local hooks = frameHooks[frame]
    if not hooks then
        hooks = {}
        frameHooks[frame] = hooks

        if type(frame.HookScript) == "function" then
            frame:HookScript("OnShow", function(f)
                local current = CurrentState(f)
                if current then
                    Engine:ApplyToFrame(current.windowId, f, current.desc)
                    ns:Fire("OnManagedFrameShown", current.windowId, f, current.desc)
                else
                    local retired = frameState[f]
                    if retired and retired.retired and RestoreDetachedFrame(f, retired) then Registry:ScanUnboundWindows() end
                end
            end)
            frame:HookScript("OnHide", function(f)
                if hooks.fadeWatcher then hooks.fadeWatcher:Hide() end
                local current = CurrentState(f)
                if not current then return end
                if activeDrag and activeDrag.frame == f then Engine:StopActiveDrag() end
                ns:Fire("OnManagedFrameHidden", current.windowId, f, current.desc)
            end)
        end

        hooksecurefunc(frame, "SetPoint", function(f)
            local current = CurrentState(f)
            if not current or current.applying or current.isDragging then return end
            if not ns.db or not ns.db.settings.enabled then return end
            local effMode = Engine:GetEffectiveWindowMode(current.windowId, current.desc)
            local cfg = ns:GetWindowConfig(current.windowId, false)
            if effMode == ns.MODE_SCALE_MOVE and cfg and cfg.pos and cfg.pos.uipX and cfg.pos.uipY then
                Engine:ApplyToFrame(current.windowId, f, current.desc)
            end
        end)
    end

    HookDragRegion(frame, windowId, frame, desc)
    if type(rawget(frame, "TitleContainer")) == "table" then
        HookDragRegion(frame.TitleContainer, windowId, frame, desc)
    end
    if type(desc.dragSubFrames) == "table" then
        for i = 1, #desc.dragSubFrames do
            local sub = rawget(frame, desc.dragSubFrames[i]) or Registry:ResolveFramePath(desc.dragSubFrames[i])
            if sub then
                HookDragRegion(sub, windowId, frame, desc)
            end
        end
    end

    if frame:IsShown() then
        Engine:ApplyToFrame(windowId, frame, desc)
        ns:Fire("OnManagedFrameShown", windowId, frame, desc)
    end
    return true
end

function Engine:ReapplyAllShown()
    for windowId, desc in Registry:IterateWindows() do
        if desc.boundFrame and desc.boundFrame:IsShown() then
            Engine:ApplyToFrame(windowId, desc.boundFrame, desc)
        end
    end
end

function Engine:GetManagedState(frame)
    return frameState[frame]
end

function Engine:OnCombatStart()
    if not ns.db or not ns.db.settings or not ns.db.settings.combatAutoClose then
        return
    end
    local closedCount = 0
    for winId, desc in Registry:IterateWindows() do
        local frame = desc.boundFrame
        local effMode = Engine:GetEffectiveWindowMode(winId, desc)
        local isThirdParty = (desc.isCommunityAddon or desc.isCustom)
        if frame and frame:IsShown() and effMode ~= ns.MODE_DISABLED and not isThirdParty and not desc.protected and not Guard:IsProtectedHierarchy(frame) then
            local closed = false
            if _G.HideUIPanel then
                local ok = pcall(_G.HideUIPanel, frame)
                if ok and not frame:IsShown() then
                    closed = true
                end
            end
            if not closed and frame:IsShown() then
                pcall(function() frame:Hide() end)
                if not frame:IsShown() then
                    closed = true
                end
            end
            if closed then
                closedCount = closedCount + 1
            end
        end
    end
    if closedCount > 0 then
        ns:Print(string.format(ns.L["MSG_COMBAT_AUTOCLOSE"], closedCount))
    end
end

Engine.panicClosedWindows = nil

function Engine:ToggleBossKey()
    -- If we previously panic-closed windows, restore them!
    if Engine.panicClosedWindows and #Engine.panicClosedWindows > 0 then
        local restoredCount = 0
        local toRestore = Engine.panicClosedWindows
        Engine.panicClosedWindows = nil

        for i = 1, #toRestore do
            local winId = toRestore[i]
            local desc = Registry:GetDescriptor(winId)
            if desc and desc.boundFrame and not desc.boundFrame:IsShown() then
                local ok = pcall(function()
                    Registry:ToggleWindowPreview(winId)
                end)
                if ok and desc.boundFrame:IsShown() then
                    restoredCount = restoredCount + 1
                end
            end
        end
        ns:PlaySound("PANIC_RESTORE")
        ns:Print(string.format(ns.L["MSG_BOSSKEY_RESTORED"], restoredCount))
        return "RESTORED", restoredCount
    end

    -- Otherwise, find all currently shown non-protected managed windows and close them!
    local closedList = {}
    for winId, desc in Registry:IterateWindows() do
        local frame = desc.boundFrame
        local effMode = Engine:GetEffectiveWindowMode(winId, desc)
        if frame and frame:IsShown() and effMode ~= ns.MODE_DISABLED and not desc.protected and not Guard:IsProtectedHierarchy(frame) then
            local closed = false
            if _G.HideUIPanel then
                local ok = pcall(_G.HideUIPanel, frame)
                if ok and not frame:IsShown() then
                    closed = true
                end
            end
            if not closed and frame:IsShown() then
                pcall(function() frame:Hide() end)
                if not frame:IsShown() then
                    closed = true
                end
            end
            if closed then
                closedList[#closedList + 1] = winId
            end
        end
    end

    if ns.ManagerUI and ns.ManagerUI.IsShown and ns.ManagerUI:IsShown() then
        ns.ManagerUI:Toggle()
    end

    if #closedList > 0 then
        Engine.panicClosedWindows = closedList
        ns:PlaySound("PANIC_CLOSE")
        ns:Print(string.format(ns.L["MSG_BOSSKEY_PANIC"], #closedList))
        return "CLOSED", #closedList
    else
        ns:Print(ns.L["MSG_BOSSKEY_NONE_OPEN"])
        return "NONE", 0
    end
end

function Engine:UpdateInstanceCompactState()
    if not ns.db or not ns.db.settings then
        return
    end
    local enabled = ns.db.settings.instanceAutoCompact
    local wasCompact = Engine.inCompactMode or false
    local isCompact = false

    if enabled and _G.IsInInstance then
        local inInstance, instanceType = _G.IsInInstance()
        if inInstance and (instanceType == "party" or instanceType == "raid" or instanceType == "pvp" or instanceType == "arena") then
            isCompact = true
        end
    end

    if isCompact ~= wasCompact then
        Engine.inCompactMode = isCompact
        if isCompact then
            ns:Print(ns.L["MSG_INSTANCE_ENTERED"])
        else
            ns:Print(ns.L["MSG_INSTANCE_LEFT"])
        end
        Engine:ReapplyAllShown()
        ns:Fire("OnInstanceCompactChanged", isCompact)
    end
end

function ns:RunSelfTest()
    local L = ns.L
    ns:Print(string.format(L["SELFTEST_HEADER"], ns.Version))
    local passed = 0
    local total = 6

    -- Test 1: Version & DB Schema
    if type(ns.Version) == "string" and ns.Version ~= "" and ns.db and ns.db.schemaVersion == 2 and ns.db.settings then
        ns:Print(string.format(L["SELFTEST_1_PASS"], ns.Version))
        passed = passed + 1
    else
        ns:Print(L["SELFTEST_1_FAIL"])
    end

    -- Test 2: Character-Profile Binding
    local charKey = ns.Profiles and ns.Profiles:GetCharKey() or nil
    if charKey then
        local bound = ns.Profiles:IsCharBoundToActiveProfile()
        ns:Print(string.format(L["SELFTEST_2_PASS"], charKey, bound and L["SELFTEST_YES"] or L["SELFTEST_NO"]))
        passed = passed + 1
    else
        ns:Print(L["SELFTEST_2_FAIL"])
    end

    -- Test 3: Opacity & Fade Engine
    local testWin = "CHARACTER"
    local origCfg = ns:GetWindowConfig(testWin, false)
    local origAlpha = origCfg and origCfg.alpha or 1.00
    local origFade = origCfg and origCfg.mouseoverFade or false

    local okAlpha = Engine:SetWindowAlpha(testWin, 0.85, true)
    local verifyCfg = ns:GetWindowConfig(testWin, false)
    if okAlpha and verifyCfg and verifyCfg.alpha == 0.85 and verifyCfg.mouseoverFade == true then
        Engine:SetWindowAlpha(testWin, origAlpha, origFade)
        ns:Print(L["SELFTEST_3_PASS"])
        passed = passed + 1
    else
        Engine:SetWindowAlpha(testWin, origAlpha, origFade)
        ns:Print(L["SELFTEST_3_FAIL"])
    end

    -- Test 4: Profile Snapshot & Undo-System
    if ns.Profiles and ns.Profiles.PushUndoSnapshot and ns.Profiles.CanUndo then
        ns.Profiles:PushUndoSnapshot("selftest")
        local canUndo = ns.Profiles:CanUndo()
        ns.Profiles:UndoLastChange()
        if canUndo then
            ns:Print(L["SELFTEST_4_PASS"])
            passed = passed + 1
        else
            ns:Print(L["SELFTEST_4_FAIL"])
        end
    else
        ns:Print(L["SELFTEST_4_MISSING"])
    end

    -- Test 5: Window Registry
    local count = 0
    for _ in Registry:IterateWindows() do
        count = count + 1
    end
    if count >= 15 then
        ns:Print(string.format(L["SELFTEST_5_PASS"], count))
        passed = passed + 1
    else
        ns:Print(string.format(L["SELFTEST_5_FAIL"], count))
    end

    -- Test 6: Resolution & Handheld Check
    local uipW = (UIParent and UIParent:GetWidth()) or 0
    local uipH = (UIParent and UIParent:GetHeight()) or 0
    local isHandheld = (uipW <= 1400 and uipH <= 800)
    ns:Print(string.format(L["SELFTEST_6_PASS"], math.floor(uipW), math.floor(uipH), isHandheld and L["SELFTEST_HANDHELD"] or L["SELFTEST_DESKTOP"]))
    passed = passed + 1

    if passed == total then
        ns:Print(string.format(L["SELFTEST_SUMMARY_OK"], passed, total))
    else
        ns:Print(string.format(L["SELFTEST_SUMMARY_WARN"], passed, total))
    end
end

local function IsCtrlWheelActive()
    return ns.db and ns.db.settings.enabled and ns.db.settings.ctrlWheelZoom and IsControlKeyDown()
end

local function UpdateCtrlWheelCatcher()
    if not IsCtrlWheelActive() then
        ctrlWheelCatcher:Hide()
        ctrlWheelCatcher.targetWindowId = nil
        return
    end

    local bestId, bestFrame = nil, nil
    for windowId, desc in Registry:IterateWindows() do
        local f = desc.boundFrame
        if f and not Guard:IsForbidden(f) and f:IsShown() and f:IsMouseOver() and Engine:GetEffectiveWindowMode(windowId, desc) ~= ns.MODE_DISABLED then
            bestId = windowId
            bestFrame = f
        end
    end

    if bestId and bestFrame then
        if ctrlWheelCatcher.targetWindowId == bestId and ctrlWheelCatcher:IsShown() then return end
        ctrlWheelCatcher.targetWindowId = bestId
        ctrlWheelCatcher:SetFrameStrata(bestFrame:GetFrameStrata() or "HIGH")
        ctrlWheelCatcher:SetFrameLevel((bestFrame:GetFrameLevel() or 10) + 50)
        ctrlWheelCatcher:ClearAllPoints()
        ctrlWheelCatcher:SetAllPoints(bestFrame)
        ctrlWheelCatcher:Show()
    else
        ctrlWheelCatcher:Hide()
        ctrlWheelCatcher.targetWindowId = nil
    end
end

-- Keep tracking while Ctrl is held, even when the cursor starts outside every window.
local ctrlWheelElapsed = 0
local function TrackCtrlWheelTarget(self, elapsed)
    if not IsCtrlWheelActive() then
        self:SetScript("OnUpdate", nil)
        UpdateCtrlWheelCatcher()
        return
    end
    ctrlWheelElapsed = ctrlWheelElapsed + elapsed
    if ctrlWheelElapsed >= 0.05 then
        ctrlWheelElapsed = 0
        UpdateCtrlWheelCatcher()
    end
end

ctrlWheelCatcher:SetScript("OnMouseWheel", function(self, delta)
    -- Recheck on input in case the pointer moved since the last update.
    UpdateCtrlWheelCatcher()
    if self.targetWindowId then
        Engine:StepWindowScale(self.targetWindowId, delta, IsShiftKeyDown(), true)
    end
end)

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("DISPLAY_SIZE_CHANGED")
eventFrame:RegisterEvent("UI_SCALE_CHANGED")
eventFrame:RegisterEvent("MODIFIER_STATE_CHANGED")

eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == AddonName then
            ns:InitDatabase()
            if ns.Profiles and ns.Profiles.Init then
                ns.Profiles:Init()
            end
            if ns.Profiles and ns.Profiles.RestoreCustomWindows then
                ns.Profiles:RestoreCustomWindows()
            end
            Registry:EnableBindingAndScan()
        else
            Registry:OnAddOnLoaded(arg1)
        end
    elseif event == "PLAYER_LOGIN" then
        if ns.Profiles and ns.Profiles.RestoreCustomWindows then
            ns.Profiles:RestoreCustomWindows()
        end
        Registry:EnableBindingAndScan()
        if ns.Profiles and ns.Profiles.AutoLoadCharProfile then
            ns.Profiles:AutoLoadCharProfile()
        end
        Engine:UpdateInstanceCompactState()
        Engine:ReapplyAllShown()
        if ns.MinimapButton and ns.MinimapButton.Init then
            ns.MinimapButton:Init()
        end
        local clientTag = ns.IsForeverClient and ns.L["PROJECT_FOREVER"] or ns.L["PROJECT_GENERIC"]
        ns:Print(string.format(ns.L["LOADED_MSG"], ns.Version, clientTag))
        ns:Fire("OnPlayerLogin")
    elseif event == "PLAYER_REGEN_DISABLED" then
        if activeDrag and activeDrag.desc and (activeDrag.desc.protected or Guard:IsProtectedHierarchy(activeDrag.frame)) then
            Engine:StopActiveDrag()
        end
        Engine:OnCombatStart()
    elseif event == "PLAYER_REGEN_ENABLED" then
        Guard:FlushCombatQueue()
    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" then
        if event == "PLAYER_ENTERING_WORLD" then
            Registry:ScanUnboundWindows()
            Engine:ReapplyAllShown()
            if _G.C_Timer and _G.C_Timer.After then
                _G.C_Timer.After(0.25, function()
                    Registry:ScanUnboundWindows()
                    Engine:ReapplyAllShown()
                end)
            end
        end
        Engine:UpdateInstanceCompactState()
    elseif event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" then
        Engine:ReapplyAllShown()
        ns:Fire("OnResolutionChanged")
    elseif event == "MODIFIER_STATE_CHANGED" then
        if arg1 == "LCTRL" or arg1 == "RCTRL" then
            ctrlWheelElapsed = 0
            eventFrame:SetScript("OnUpdate", IsCtrlWheelActive() and TrackCtrlWheelTarget or nil)
            UpdateCtrlWheelCatcher()
        end
    end
end)
