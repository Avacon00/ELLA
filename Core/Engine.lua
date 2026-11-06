local AddonName, ns = ...

local Guard = ns.Guard
local Registry = ns.Registry

local Engine = {}
ns.Engine = Engine

-- Golden Rule #4: Private Weak-Key table for per-frame runtime state.
-- NEVER write properties directly onto Blizzard frames!
local frameState = setmetatable({}, { __mode = "k" })

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

-- Reads a frame's current top-left coordinates in UIParent space (origin: UIParent TOPLEFT)
function Engine:ReadUipTopLeft(frame)
    local left = frame:GetLeft()
    local top = frame:GetTop()
    local uipH = UIParent:GetHeight()
    if not left or not top or not uipH or uipH <= 0 then
        return nil, nil
    end
    local s = frame:GetScale() or 1
    local uipX = left * s
    local uipY = (top * s) - uipH
    return uipX, uipY
end

-- Golden Rule #7: Keep at least 120px width and the top titlebar inside the screen
function Engine:ClampUipPosition(frame, scale, uipX, uipY)
    if not ns.db or not ns.db.settings.clampToScreen then
        return uipX, uipY
    end
    local uipW = UIParent:GetWidth() or 1920
    local uipH = UIParent:GetHeight() or 1080
    local rawW = frame:GetWidth() or 350
    local scaledW = rawW * scale

    local minX = math.min(0, -scaledW + 120)
    local maxX = math.max(0, uipW - 120)
    local minY = -(uipH - 60)
    local maxY = 0

    if uipX < minX then uipX = minX end
    if uipX > maxX then uipX = maxX end
    if uipY < minY then uipY = minY end
    if uipY > maxY then uipY = maxY end

    return uipX, uipY
end

-- Syncs scale onto optional companion sub-frames (e.g. QuestLogPopupDetailFrame, Orders panel)
local function SyncLinkedFrames(windowId, desc, targetScale)
    if type(desc.linkedFrames) ~= "table" then
        return
    end
    for i = 1, #desc.linkedFrames do
        local sub = Registry:ResolveFramePath(desc.linkedFrames[i])
        if sub and not Guard:IsForbidden(sub) then
            local subState = frameState[sub]
            if not subState or not subState.linkedHooked then
                subState = subState or {}
                subState.linkedHooked = true
                frameState[sub] = subState
                if type(sub.HookScript) == "function" then
                    sub:HookScript("OnShow", function(sFrame)
                        local isGlobalEnabled = (ns.db and ns.db.settings.enabled)
                        local cfg = ns:GetWindowConfig(windowId, false)
                        local mode = (not isGlobalEnabled and ns.MODE_DISABLED)
                            or (cfg and cfg.mode)
                            or desc.defaultMode
                            or (ns.db and ns.db.settings.defaultScaleOnly and ns.MODE_SCALE_ONLY or ns.MODE_SCALE_MOVE)
                        local sTarget = (mode == ns.MODE_DISABLED) and ns.DEFAULT_SCALE or Engine:ClampScale(cfg and cfg.scale or ns.DEFAULT_SCALE)
                        if Guard:CanModifyNow(sFrame, desc.protected) then
                            local c = sFrame:GetScale() or 1
                            if math.abs(c - sTarget) > 0.001 then
                                sFrame:SetScale(sTarget)
                            end
                        end
                    end)
                end
            end
            if Guard:CanModifyNow(sub, desc.protected) then
                local cur = sub:GetScale() or 1
                if math.abs(cur - targetScale) > 0.001 then
                    sub:SetScale(targetScale)
                end
            end
        end
    end
end

-- Applies scale and (when in SCALE_AND_MOVE mode with saved pos) scale-compensated anchor
function Engine:ApplyToFrame(windowId, frame, desc)
    local state = frameState[frame]
    if not state or state.applying then
        return
    end

    local isGlobalEnabled = (ns.db and ns.db.settings.enabled)
    local cfg = ns:GetWindowConfig(windowId, false)
    local mode = (not isGlobalEnabled and ns.MODE_DISABLED)
        or (cfg and cfg.mode)
        or desc.defaultMode
        or (ns.db and ns.db.settings.defaultScaleOnly and ns.MODE_SCALE_ONLY or ns.MODE_SCALE_MOVE)
    local targetScale = (mode == ns.MODE_DISABLED) and ns.DEFAULT_SCALE or Engine:ClampScale(cfg and cfg.scale or ns.DEFAULT_SCALE)

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

    -- Snapshot original pristine Blizzard anchor points once before any custom move
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
    end
    SyncLinkedFrames(windowId, desc, targetScale)

    if mode == ns.MODE_SCALE_MOVE and cfg and cfg.pos and cfg.pos.uipX and cfg.pos.uipY then
        local clampedX, clampedY = Engine:ClampUipPosition(frame, targetScale, cfg.pos.uipX, cfg.pos.uipY)
        cfg.pos.uipX = clampedX
        cfg.pos.uipY = clampedY
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", clampedX / targetScale, clampedY / targetScale)
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
                local ratio = newScale / oldScale
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
    local cfg = ns:GetWindowConfig(windowId, true)
    local step = isFineStep and ns.STEP_FINE or ns.STEP_COARSE
    local current = cfg.scale or ns.DEFAULT_SCALE
    return Engine:SetWindowScale(windowId, current + (deltaTicks * step), pivotAroundCursor)
end

function Engine:SetWindowMode(windowId, newMode)
    local desc = Registry:GetDescriptor(windowId)
    if not desc then
        return
    end
    local cfg = ns:GetWindowConfig(windowId, true)
    cfg.mode = newMode
    if desc.boundFrame then
        Engine:ApplyToFrame(windowId, desc.boundFrame, desc)
    end
    ns:Fire("OnWindowConfigChanged", windowId, cfg)
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
    end
    if desc and desc.boundFrame then
        Engine:ApplyToFrame(windowId, desc.boundFrame, desc)
    end
    ns:Fire("OnWindowConfigChanged", windowId, cfg)
end

-- Computes magnetic top-edge / side-by-side snap against other visible windows + Shift 10px grid
local function ApplyMagneticOrGridSnap(draggedFrame, scale, candX, candY)
    snapLineH:Hide()
    snapLineV:Hide()

    if IsShiftKeyDown() then
        return math.floor(candX / 10 + 0.5) * 10, math.floor(candY / 10 + 0.5) * 10
    end

    if not ns.db or not ns.db.settings.magneticSnap then
        return candX, candY
    end

    local thisW = (draggedFrame:GetWidth() or 350) * scale
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
                local oScale = other:GetScale() or 1
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
    local snappedX, snappedY = ApplyMagneticOrGridSnap(frame, scale, rawX, rawY)
    local newUipX, newUipY = Engine:ClampUipPosition(frame, scale, snappedX, snappedY)

    local state = frameState[frame]
    if state then
        state.applying = true
        state.hasCustomPosApplied = true
    end
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", newUipX / scale, newUipY / scale)
    if state then
        state.applying = false
    end

    activeDrag.lastUipX = newUipX
    activeDrag.lastUipY = newUipY
end

function Engine:StartWindowDrag(windowId, frame, desc)
    if not ns.db or not ns.db.settings.enabled then
        return
    end
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
    if ns.db.settings.dragOpacity and type(frame.SetAlpha) == "function" then
        frame:SetAlpha(math.min(origAlpha, 0.78))
    end

    local curX, curY = GetCursorPosition()
    activeDrag = {
        windowId = windowId,
        frame = frame,
        desc = desc,
        originalAlpha = origAlpha,
        startCursorX = curX,
        startCursorY = curY,
        startUipX = uipX,
        startUipY = uipY,
        lastUipX = uipX,
        lastUipY = uipY,
    }
    if state then
        state.isDragging = true
    end
    dragDriver:SetScript("OnUpdate", OnDragUpdate)
end

function Engine:StopActiveDrag()
    dragDriver:SetScript("OnUpdate", nil)
    snapLineH:Hide()
    snapLineV:Hide()
    if not activeDrag then
        return
    end
    local finished = activeDrag
    activeDrag = nil

    if finished.frame and finished.originalAlpha and type(finished.frame.SetAlpha) == "function" then
        finished.frame:SetAlpha(finished.originalAlpha)
    end

    local state = frameState[finished.frame]
    if state then
        state.isDragging = false
    end

    local cfg = ns:GetWindowConfig(finished.windowId, true)
    cfg.pos = {
        uipX = finished.lastUipX,
        uipY = finished.lastUipY,
    }
    ns:Fire("OnWindowConfigChanged", finished.windowId, cfg)
end

local function HookDragRegion(region, windowId, rootFrame, desc)
    if not region or Guard:IsForbidden(region) or type(region.HookScript) ~= "function" then
        return
    end
    local rState = frameState[region]
    if rState and rState.dragHooked then
        return
    end
    frameState[region] = rState or {}
    frameState[region].dragHooked = true

    region:HookScript("OnMouseDown", function(_, button)
        if button == "LeftButton" and not IsControlKeyDown() then
            Engine:StartWindowDrag(windowId, rootFrame, desc)
        elseif button == "RightButton" and IsControlKeyDown() then
            Engine:ResetWindow(windowId, IsShiftKeyDown())
        end
    end)

    region:HookScript("OnMouseUp", function(_, button)
        if button == "LeftButton" then
            Engine:StopActiveDrag()
        end
    end)
end

-- Attaches non-invasive hooks to a Blizzard or third-party window
function Engine:AttachWindow(windowId, frame, desc)
    if Guard:IsForbidden(frame) then
        return
    end
    local state = frameState[frame]
    if state and state.attached then
        return
    end

    state = state or {}
    state.attached = true
    state.windowId = windowId
    state.desc = desc
    frameState[frame] = state

    if type(frame.HookScript) == "function" then
        frame:HookScript("OnShow", function(f)
            Engine:ApplyToFrame(windowId, f, desc)
            ns:Fire("OnManagedFrameShown", windowId, f, desc)
        end)
        frame:HookScript("OnHide", function(f)
            if activeDrag and activeDrag.frame == f then
                Engine:StopActiveDrag()
            end
            ns:Fire("OnManagedFrameHidden", windowId, f, desc)
        end)
    end

    hooksecurefunc(frame, "SetPoint", function(f)
        local st = frameState[f]
        if not st or st.applying or st.isDragging then
            return
        end
        if not ns.db or not ns.db.settings.enabled then
            return
        end
        local cfg = ns:GetWindowConfig(windowId, false)
        if cfg and cfg.mode == ns.MODE_SCALE_MOVE and cfg.pos and cfg.pos.uipX and cfg.pos.uipY then
            Engine:ApplyToFrame(windowId, f, desc)
        end
    end)

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

local function UpdateCtrlWheelCatcher()
    if not ns.db or not ns.db.settings.enabled or not ns.db.settings.ctrlWheelZoom or not IsControlKeyDown() then
        ctrlWheelCatcher:Hide()
        ctrlWheelCatcher.targetWindowId = nil
        return
    end

    local bestId, bestFrame = nil, nil
    for windowId, desc in Registry:IterateWindows() do
        local f = desc.boundFrame
        if f and f:IsShown() and f:IsMouseOver() then
            bestId = windowId
            bestFrame = f
        end
    end

    if bestId and bestFrame then
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

ctrlWheelCatcher:SetScript("OnMouseWheel", function(self, delta)
    if not IsControlKeyDown() or not self.targetWindowId then
        self:Hide()
        return
    end
    Engine:StepWindowScale(self.targetWindowId, delta, IsShiftKeyDown(), true)
end)

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
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
        else
            Registry:OnAddOnLoaded(arg1)
        end
    elseif event == "PLAYER_LOGIN" then
        Registry:ScanUnboundWindows()
        if ns.Profiles and ns.Profiles.RestoreCustomWindows then
            ns.Profiles:RestoreCustomWindows()
        end
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
    elseif event == "PLAYER_REGEN_ENABLED" then
        Guard:FlushCombatQueue()
    elseif event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" then
        Engine:ReapplyAllShown()
    elseif event == "MODIFIER_STATE_CHANGED" then
        if arg1 == "LCTRL" or arg1 == "RCTRL" then
            UpdateCtrlWheelCatcher()
        end
    end
end)
