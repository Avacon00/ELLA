-- Explicit frame doubles for Lua behavior tests; not a WoW security simulation.
-- The isolated runtime deliberately supplies these test/client globals.
-- luacheck: globals frames errors messages combat alt cursorX cursorY clientLocale ns RegisterTestWindow
-- luacheck: globals GetTime GetLocale InCombatLockdown IsControlKeyDown IsAltKeyDown IsShiftKeyDown
-- luacheck: globals GetCursorPosition geterrorhandler wipe DEFAULT_CHAT_FRAME CreateFrame UIParent hooksecurefunc
frames = {}
errors = {}
messages = {}
combat = false
alt = false
cursorX, cursorY = 300, 700

function wipe(t)
    for key in pairs(t) do t[key] = nil end
    return t
end

function GetTime() return 100 end
function GetLocale() return clientLocale or "enUS" end
function InCombatLockdown() return combat end
function IsControlKeyDown() return false end
function IsAltKeyDown() return alt end
function IsShiftKeyDown() return false end
function GetCursorPosition() return cursorX, cursorY end
function geterrorhandler()
    return function(message) errors[#errors + 1] = tostring(message) end
end

DEFAULT_CHAT_FRAME = {
    AddMessage = function(_, message) messages[#messages + 1] = message end,
}

local Frame = {}

function CreateFrame(_, name, parent)
    local frame = setmetatable({
        name = name,
        parent = parent,
        scale = 1,
        scaleWrites = 0,
        alpha = 1,
        alphaWrites = 0,
        width = 350,
        height = 400,
        left = 100,
        top = 900,
        shown = true,
        scripts = {},
        hooks = {},
        events = {},
        points = { { "TOPLEFT", parent, "TOPLEFT", 100, -180 } },
        strata = "MEDIUM",
        level = 1,
    }, { __index = Frame })
    frames[#frames + 1] = frame
    if name then _G[name] = frame end
    return frame
end

function Frame:IsForbidden() return self.forbidden or false end
function Frame:IsProtected() return self.protected or false end
function Frame:GetName() return self.name end
function Frame:GetParent() return self.parent end
function Frame:GetScale() return self.scale end
function Frame:GetEffectiveScale()
    return self.scale * (self.parent and self.parent:GetEffectiveScale() or 1)
end
function Frame:SetScale(value)
    self.scale = value
    self.scaleWrites = self.scaleWrites + 1
end
function Frame:GetAlpha() return self.alpha end
function Frame:SetAlpha(value)
    self.alpha = value
    self.alphaWrites = self.alphaWrites + 1
end
function Frame:GetWidth() return self.width end
function Frame:GetHeight() return self.height end
function Frame:SetWidth(value) self.width = value end
function Frame:SetHeight(value) self.height = value end
function Frame:GetLeft() return self.left end
function Frame:GetTop() return self.top end
function Frame:GetNumPoints() return #self.points end
function Frame:GetPoint(index) return unpack(self.points[index]) end
function Frame:ClearAllPoints() self.points = {} end
function Frame:SetPoint(...) self.points[#self.points + 1] = { ... } end
function Frame:SetAllPoints(frame) self.allPoints = frame end
function Frame:GetFrameStrata() return self.strata end
function Frame:SetFrameStrata(value) self.strata = value end
function Frame:GetFrameLevel() return self.level end
function Frame:SetFrameLevel(value) self.level = value end
function Frame:EnableMouse(value) self.mouseEnabled = value end
function Frame:EnableMouseWheel(value) self.wheelEnabled = value end
function Frame:SetColorTexture() end
function Frame:CreateTexture() return CreateFrame("Texture", nil, self) end
function Frame:RegisterEvent(event) self.events[event] = true end
function Frame:SetScript(event, callback) self.scripts[event] = callback end
function Frame:GetScript(event) return self.scripts[event] end
function Frame:HookScript(event, callback)
    local hooks = self.hooks[event] or {}
    self.hooks[event] = hooks
    hooks[#hooks + 1] = callback
end
function Frame:Run(event, ...)
    if self.scripts[event] then self.scripts[event](self, ...) end
    for _, callback in ipairs(self.hooks[event] or {}) do callback(self, ...) end
end
function Frame:Show()
    local wasShown = self.shown
    self.shown = true
    if not wasShown then self:Run("OnShow") end
end
function Frame:Hide()
    local wasShown = self.shown
    self.shown = false
    if wasShown then self:Run("OnHide") end
end
function Frame:IsShown() return self.shown end
function Frame:IsMouseOver() return self.mouseover or false end

function hooksecurefunc(frame, method, callback)
    local original = frame[method]
    frame[method] = function(self, ...)
        original(self, ...)
        callback(self, ...)
    end
end

UIParent = CreateFrame("Frame", "UIParent")
UIParent.width, UIParent.height = 1920, 1080

function RegisterTestWindow(id, options)
    options = options or {}
    local frame = CreateFrame("Frame", "TestFrame_" .. id, UIParent)
    frame.alpha = options.alpha or 1
    frame.left = options.left or 100
    frame.protected = options.protected
    ns.Registry:RegisterWindow(id, { frame = frame:GetName(), protected = options.protected })
    return frame, ns.Registry:GetDescriptor(id)
end
