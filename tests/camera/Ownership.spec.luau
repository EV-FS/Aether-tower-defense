local function signal()
    local callbacks = {}
    local event = {}
    function event:Connect(fn)
        callbacks[fn] = true
        return { Disconnect = function() callbacks[fn] = nil end }
    end
    function event:Fire(...)
        for fn in table.clone(callbacks) do if callbacks[fn] then fn(...) end end
    end
    function event:Count() local n = 0; for _ in callbacks do n += 1 end; return n end
    return event
end
local Enum = { CameraType = { Scriptable = "Scriptable", Custom = "Custom" }, RenderPriority = { Last = { Value = 2000 } } }
local bindings = {}
local RunService = { PreRender = signal(), Heartbeat = signal(), RenderStepped = signal(), IsRunning = function() return true end }
function RunService:BindToRenderStep(name, _, fn) bindings[name] = fn end
function RunService:UnbindFromRenderStep(name) bindings[name] = nil end
local function camera()
    local c = { CameraType = "Custom", FieldOfView = 70, Attributes = {}, Parent = true }
    function c:GetAttribute(name) return self.Attributes[name] end
    function c:SetAttribute(name, value) self.Attributes[name] = value end
    return c
end
local cam = camera()
local workspace = { CurrentCamera = cam }
local ReplicatedStorage = { Packages = {} }
local game = { GetService = function(_, name) return if name == "RunService" then RunService else ReplicatedStorage end }
local fov = (function()
--[[FOV]]
end)()
fov.Start()
fov.Start()
assert(RunService.PreRender:Count() == 1)
cam.CameraType = "Scriptable"
cam.FieldOfView = 19.417
fov.SetFOV(90)
RunService.PreRender:Fire(1/60)
assert(cam.FieldOfView == 19.417, "normal FOV smoothing must not fight a cinematic")
fov.ResetFOV(true)
assert(cam.FieldOfView == 19.417, "instant reset must also respect cinematic ownership")
cam.CameraType = "Custom"
RunService.PreRender:Fire(1/60)
assert(cam.FieldOfView > 19.417 and cam.FieldOfView < 70)
workspace.CurrentCamera = nil
fov.SetFOV(80, true)
assert(fov.GetFOV() == 80)
workspace.CurrentCamera = cam
fov.Destroy()
assert(RunService.PreRender:Count() == 0)
print("PASS: normal FOV writes yield to cinematics, resume afterward, and own a single connection")

local vecMt = {}
local function vec(value) return setmetatable({Value=value, x=0,y=0,z=0}, vecMt) end
vecMt.__add = function(a,b) return vec(a.Value+b.Value) end
vecMt.__mul = function(a,b) return vec(a.Value*b) end
local vector = { zero = vec(0), one = vec(1) }
local cfMt = {}
local function cf(value) return setmetatable({Value=value}, cfMt) end
cfMt.__mul = function(a,b) return cf(a.Value+b.Value) end
local CFrame = { identity = cf(0), new = function(value) return cf(if type(value)=="table" then value.Value else value or 0) end, Angles = function() return cf(0) end }
local callbacks = {}
local shakeAllocations = 0
local Shake = {
    NextRenderName = function() return "sample" end,
    new = function()
        shakeAllocations += 1
        return { BindToRenderStep = function(_, _, _, fn) table.insert(callbacks, fn) end, Start = function() end }
    end,
}
ReplicatedStorage.Packages.Shake = Shake
local dependencies = {
    ["../mod/attributes"] = { get = function(_, _, default) return default end },
    ["../mod/tween"] = {}, ["../types"] = {},
    ["../mod/utility"] = { RENDER_PRIORITY = 100, getGameDelta = function(dt) return dt end },
}
local require = function(value) return if type(value)=="string" then dependencies[value] else value end
local task = { spawn = function(thread) assert(coroutine.resume(thread)) end }
local shake = (function()
--[[SHAKE]]
end)()
shake.init()
cam.CameraType = "Custom"
cam.CFrame = cf(10)
local scope = { depth = 0 }
local ref = { FindFirstAncestorOfClass = function() return nil end, FindFirstAncestorWhichIsA = function() return nil end }
local emitThread = coroutine.create(function() shake.emit(ref, scope) end)
assert(coroutine.resume(emitThread))
callbacks[1](vec(3), vec(0), false)
cam.CameraType = "Scriptable"
cam.CFrame = cf(30)
RunService.Heartbeat:Fire()
assert(cam.CFrame.Value == 30, "a stale VFX sample must not roll back the authored camera")
bindings.forge_updateCameraShake()
assert(cam.CFrame.Value == 33, "authored VFX shakes must still play on the cutscene camera")
cam.CameraType = "Custom"
callbacks[1](vec(3), vec(0), false)
local replacement = camera()
replacement.CFrame = cf(50)
workspace.CurrentCamera = replacement
RunService.Heartbeat:Fire()
assert(replacement.CFrame.Value == 50, "a stale sample must not overwrite a replacement camera")
workspace.CurrentCamera = cam
callbacks[1](vec(0), vec(0), true)
for _, connection in ipairs(scope) do connection:Disconnect() end
shake.deinit()
assert(RunService.Heartbeat:Count() == 0 and bindings.forge_updateCameraShake == nil)
print("PASS: VFX preserves authored shakes without rolling back scripted or replacement cameras")

