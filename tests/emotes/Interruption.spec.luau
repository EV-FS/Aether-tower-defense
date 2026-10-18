local function signal()
    local callbacks = {}
    local event = {}
    function event:Connect(fn)
        callbacks[fn] = true
        return { Disconnect = function() callbacks[fn] = nil end }
    end
    function event:Once(fn)
        local connection
        connection = self:Connect(function(...) connection:Disconnect(); fn(...) end)
        return connection
    end
    function event:Fire(...)
        local snapshot = table.clone(callbacks)
        for fn in snapshot do if callbacks[fn] then fn(...) end end
    end
    function event:Count() local count = 0; for _ in callbacks do count += 1 end; return count end
    return event
end
local Enum = {
    HumanoidStateType = { Running = "Running", RunningNoPhysics = "RunningNoPhysics", Landed = "Landed", Freefall = "Freefall", Seated = "Seated", Swimming = "Swimming", Climbing = "Climbing", Dead = "Dead" },
    AnimationPriority = { Action = "Action" }, UserInputState = { Begin = "Begin" },
    ActuatorRelativeTo = { World = "World" }, VelocityConstraintMode = { Vector = "Vector" }, ForceLimitMode = { PerAxis = "PerAxis" },
}
local timeNow = 10
local os = { clock = function() return timeNow end }
local warn = print
local function vector(x, y, z)
    return setmetatable({ X = x, Y = y, Z = z, Magnitude = math.sqrt(x*x+y*y+(z or 0)^2), Unit = {X=x,Y=y,Z=z} }, {
        __mul = function(a, b) return { X = a.X*b, Y = a.Y*b, Z = (a.Z or 0)*b } end,
    })
end
local Vector2 = { new = vector }
local Vector3 = { new = vector }
local tracks = {}
local failAnimation = nil
local Instance = { new = function(kind)
    return { AnimationId = "", Parent = nil, Destroy = function(self) self.Destroyed = true end }
end }
local animator = {}
function animator:LoadAnimation(animation)
    if animation.AnimationId == failAnimation then error("test load failure") end
    local track = { Stopped = signal(), IsPlaying = false, Animation = animation, KeyframeReached = signal(), Length = 0 }
    function track:Play(_, _, speed) self.IsPlaying = true; self.Speed = speed end
    function track:Stop() self.IsPlaying = false; self.Stopped:Fire() end
    function track:Destroy() self.Destroyed = true end
    table.insert(tracks, track)
    return track
end
local function character()
    local h = { Health = 100, WalkSpeed = 16, Parent = true, State = "Running", Jumping = signal(), StateChanged = signal(), Died = signal(), MoveDirection = vector(0,0,0) }
    function h:FindFirstChildOfClass(name) return if name == "Animator" then animator else nil end
    function h:GetState() return self.State end
    local root = { AssemblyMass = 1, CFrame = { LookVector = vector(0,0,-1), RightVector = vector(1,0,0) } }
    function root:FindFirstChild() return nil end
    local c = { Humanoid = h, Root = root, ChildAdded = signal(), Attributes = {} }
    function c:FindFirstChildOfClass(name) return if name == "Humanoid" then h else nil end
    function c:FindFirstChild(name) return if name == "HumanoidRootPart" then root else nil end
    function c:GetAttribute(name) return self.Attributes[name] end
    function c:SetAttribute(name, value) self.Attributes[name] = value end
    return c, h
end
local c, h = character()
local player = { Character = c, CharacterAdded = signal(), CharacterRemoving = signal(), Attributes = {}, AttributeChanged = signal() }
function player:GetAttribute(name) return self.Attributes[name] end
function player:GetAttributeChangedSignal() return self.AttributeChanged end
local Players = { LocalPlayer = player, PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return { player } end }
local data = { ByName = { Dance = { AnimationId = "dance", Looped = true, WalkSpeed = 4, PlaybackSpeed = 1.5 } } }
local emitted = {}
local stopRequests = 0
local promise = { catch = function(self) return self end, andThen = function(self) return self end }
local Net = { EmoteService = {
    RequestPlayEmote = { Invoke = function() return promise end },
    RequestStopEmote = { Invoke = function() stopRequests += 1; return promise end },
    EmoteStarted = { On = function(fn) emitted.Started = fn end, FireAll = function() end },
    EmoteStopped = { On = function(fn) emitted.Stopped = fn end, FireAll = function() end },
} }
Net.client = Net
Net.server = Net
local utils = { Get = function() return nil end }
local ReplicatedStorage = {
    Settings = { Data = { EmoteData = data } },
    Shared = { Net = Net, Controllers = { InputController = {} }, Modules = {
        Core = { ServiceRegistry = {} },
        UI = { Emote = {}, SetMobileStyle = {} },
        Utils = { EmitParticles = {}, EmotePropUtils = { AttachProps = function() end, ClearProps = function(char) char.PropsCleared = true end } },
    } },
    FindFirstChild = function() return nil end,
}
local workspace = { CurrentCamera = {} }
local services = { Players = Players, ReplicatedStorage = ReplicatedStorage, ContextActionService = { GetButton = function() return nil end }, UserInputService = {}, Debris = { AddItem = function() end }, RunService = {} }
local game = { GetService = function(_, name) return services[name] end }
local require = function(value) return value end
local task = { delay = function() end, spawn = function(fn, ...) fn(...) end }
local script = { CharacterUtils = {}, ServiceUtils = utils, CharacterEmoteObserver = { new = function() return { Destroy = function() end } end }, Parent = { CharacterUtils = {}, ServiceUtils = utils } }
local LocalPlayer = (function()
--[[LOCAL_PLAYER]]
end)()
ReplicatedStorage.Shared.Modules.UI.Emote.LocalEmotePlayer = LocalPlayer
local lobbySprint = (function()
--[[LOBBY_SPRINT]]
end)()
local gameSprint = (function()
--[[GAME_SPRINT]]
end)()
local fov = { SetDefaultFOV = function() end, SetFOV = function() end }
lobbySprint.Service.Init({ GetService = function() return fov end })
local lp = LocalPlayer.new()
local autoStops = 0
local function start()
    player.Character = c
    h.State = "Running"
    h.Health = 100
    h.WalkSpeed = 16
    lp.OnAutoStopped = function() autoStops += 1 end
    assert(lp:Start("Dance", data.ByName.Dance))
    assert(lp.CurrentTrack.Speed == 1.5)
end
for _, sprint in {lobbySprint, gameSprint} do
    sprint.Attach(h)
    start()
    sprint.Service.Disable()
    lp.OnAutoStopped = function() autoStops += 1; sprint.Service.Enable() end
    sprint.Handle(nil, "Begin")
    assert(not lp:IsPlaying() and sprint.Service.IsSprinting() and h.WalkSpeed > 16)
end
print("PASS: lobby and game sprint cancel emotes before enabling sprint")
local dash = (function()
--[[DASH]]
end)()
start()
dash:Dash()
assert(not lp:IsPlaying() and c:GetAttribute("Dashing"))
assert(not lp:Start("Dance", data.ByName.Dance))
c:SetAttribute("Dashing", nil)
print("PASS: dash cancels emotes and blocks playback during the dash")
for _, state in {"Freefall", "Seated", "Swimming", "Climbing", "Dead"} do
    start()
    h.StateChanged:Fire("Running", state)
    assert(not lp:IsPlaying() and h.WalkSpeed == 16)
    assert(h.StateChanged:Count() == 0 and c.ChildAdded:Count() == 0)
end
start()
c.ChildAdded:Fire({ IsA = function(_, name) return name == "Tool" end })
assert(not lp:IsPlaying())
start()
h.Died:Fire()
assert(not lp:IsPlaying())
print("PASS: incompatible states, equipped tools, and death release playback and listeners")
start()
local newCharacter, newHumanoid = character()
newHumanoid.WalkSpeed = 77
player.Character = newCharacter
player.CharacterRemoving:Fire(c)
assert(not lp:IsPlaying() and newHumanoid.WalkSpeed == 77 and h.WalkSpeed == 16)
player.Character = c
print("PASS: character replacement never restores speed onto the replacement humanoid")
start()
local previous = autoStops
LocalPlayer.Interrupt(c)
LocalPlayer.Interrupt(c)
assert(autoStops == previous + 1 and not lp:IsPlaying())
start()
player.Attributes.SummonControlsLocked = true
player.AttributeChanged:Fire()
assert(not lp:IsPlaying() and not lp:Start("Dance", data.ByName.Dance))
player.Attributes.SummonControlsLocked = nil
print("PASS: repeated cancellation is idempotent and summon control locks stop emotes")
failAnimation = "missing"
assert(not lp:Start("Bad", { AnimationId = "missing", WalkSpeed = 0 }))
assert(h.WalkSpeed == 16 and not lp:IsPlaying() and #lp.Connections == 0)
failAnimation = nil
assert(lp:Start("Intro", { AnimationId = "dance", IntroAnimationId = "intro", Looped = true }))
lp.CurrentTrack:Stop()
assert(lp.CurrentTrack.Animation.AnimationId == "dance" and lp:IsPlaying())
lp:Stop()
print("PASS: animation load failure restores movement and intro transitions still work")
local client = (function()
--[[CLIENT]]
end)()
client.Init()
client.Start()
client.PlayEmote("Dance")
LocalPlayer.Interrupt(c)
local before = stopRequests
emitted.Started({ Player = player, EmoteId = "Dance" })
assert(stopRequests == before + 1 and not LocalPlayer.Interrupt(c))
print("PASS: delayed server confirmation cannot restart an emote superseded by an action")
local stoppedSounds = 0
local destroyedStates = 0
script.Parent.CharacterUtils.GetRootPart = function(char) return char.Root end
utils.Get = function(name)
    if name == "AudioController" then
        return { PlayOn3D = function() return { Stop = function() stoppedSounds += 1 end } end }
    end
    return nil
end
local TrackState = (function()
--[[TRACK_STATE]]
end)()
local effectTrack = animator:LoadAnimation({ AnimationId = "effect" })
local effectState = TrackState.new(c, effectTrack, { SoundId = 1, KeyframeEvents = { Hit = { SFX = 2 } } }, function() destroyedStates += 1 end)
assert(effectTrack.Length == 0 and effectTrack.KeyframeReached:Count() == 1)
effectTrack.KeyframeReached:Fire("Hit")
effectState:Destroy()
effectState:Destroy()
assert(stoppedSounds == 2 and destroyedStates == 1 and effectTrack.KeyframeReached:Count() == 0 and effectTrack.Stopped:Count() == 0)
print("PASS: unloaded tracks connect without orphaned waits and sounds clean up exactly once")
local ServerState = (function()
--[[SERVER_STATE]]
end)()
local state = ServerState.new(player)
assert(state:Play("Dance", data.ByName.Dance))
player.Character = newCharacter
state:Stop()
assert(c.PropsCleared and not newCharacter.PropsCleared and newHumanoid.WalkSpeed == 77)
player.Character = c
print("PASS: server cleanup restores the original character and clears its props")
timeNow += 1
assert(state:Play("Dance", data.ByName.Dance))
h.StateChanged:Fire("Running", "Seated")
assert(state.CurrentEmote == nil and h.WalkSpeed == 16 and #state.Connections == 0)
print("PASS: server also cancels incompatible states and restores movement")
