local Matter = require(game:GetService("ReplicatedStorage").Packages.Matter)
local Components = require(script.Parent.Components)
local SampleTrack = require(script.Parent.SampleTrack)
local CameraSystem = require(script.Parent.CameraSystem)
local VFXSystem = require(script.Parent.VFXSystem)
local AudioSystem = require(script.Parent.AudioSystem)
local ImpactSystem = require(script.Parent.ImpactSystem)
local ScreenEffectSystem = require(script.Parent.ScreenEffectSystem)
local ScreenEffects = require(script.Parent.Parent.ScreenEffects)
local ImpactFrames = require(script.Parent.Parent.ImpactFrames)
local VFXContext = require(script.Parent.Parent.VFXContext)
local PlaybackClock = require(script.Parent.Parent.PlaybackClock)
local Prepare = require(script.Parent.Parent.Prepare)

local CameraRuntime = {}
CameraRuntime.__index = CameraRuntime

function CameraRuntime.new(state, reference, config, tracks)
	local world = Matter.World.new()
	local entity = world:spawn(
		Components.Session({ State = state, Elapsed = 0 }),
		Components.CameraTarget({ Reference = reference })
	)
	local fov = config and config.Camera.FOV
	local vfx = config and config.VFX
	if fov then
		assert(not fov.FPS or fov.FPS > 0, "FOV FPS must be positive")
		world:insert(entity, Components.FOVTrack({
			Samples = fov.Samples, Keys = SampleTrack.Keys(fov.Samples), FPS = fov.FPS, Cuts = fov.Cuts,
		}))
	end
	local jobs = {}
	local sound = nil
	if config and config.Audio then
		sound = Instance.new("Sound")
		sound.Name = "CutsceneAudio"
		sound.SoundId = "rbxassetid://" .. config.Audio.SoundId
		sound.Volume = config.Audio.Volume or 1
		sound.Looped = false
		sound.Parent = game:GetService("SoundService")
		jobs.Audio = { Timeout = 8, Run = function()
			game:GetService("ContentProvider"):PreloadAsync({ sound })
		end }
		world:insert(entity, Components.AudioTrack({ Sound = sound, Started = false }))
	end
	if vfx then
		jobs.VFX = { Timeout = 25, Run = function() return VFXContext.new(state, vfx.Events) end }
	end
	if config and config.ImpactFrames then
		jobs.Impact = { Timeout = 10, Run = function() return ImpactFrames.new(config.ImpactFrames) end }
	end
	if config and config.ScreenEffects then
		jobs.Screen = { Timeout = 5, Run = function() return ScreenEffects.new(config.ScreenEffects) end }
	end
	local prepared = Prepare.All(jobs)
	local context = prepared.VFX and prepared.VFX.Success and prepared.VFX.Value or nil
	if context then
		local keys = {}
		for frame in vfx.Events do table.insert(keys, frame) end
		table.sort(keys)
		world:insert(entity, Components.VFXTrack({
			Events = vfx.Events, Keys = keys, NextIndex = 1, EndFrame = vfx.EndFrame, FPS = vfx.FPS,
			Run = function(event) context:Run(event) end,
		}))
	end
	local impactView = prepared.Impact and prepared.Impact.Success and prepared.Impact.Value or nil
	local screenView = prepared.Screen and prepared.Screen.Success and prepared.Screen.Value or nil
	if screenView then
		local screen = config.ScreenEffects
		world:insert(entity, Components.ScreenEffectTrack({
			View = screenView, EndFrame = screen.EndFrame, FPS = screen.FPS,
		}))
	end
	if impactView then
		local impact = config.ImpactFrames
		world:insert(entity, Components.ImpactTrack({
			Events = impact.Events, EndFrame = impact.EndFrame, FPS = impact.FPS, View = impactView,
		}))
	end
	return setmetatable({
		World = world, Entity = entity, State = state, Tracks = tracks,
		Sound = sound, ImpactView = impactView, VFXContext = context, ScreenView = screenView,
	}, CameraRuntime)
end

-- Called before Animator evaluates poses. Rendering uses this exact sample.
function CameraRuntime:PreAnimation()
	local elapsed = PlaybackClock.Elapsed(self.State, workspace:GetServerTimeNow())
	PlaybackClock.Apply(self.Tracks, elapsed)
	self.World:insert(self.Entity, Components.Session({ State = self.State, Elapsed = elapsed }))
end

function CameraRuntime:Step()
	CameraSystem(self.World)
	ScreenEffectSystem(self.World)
	ImpactSystem(self.World)
	AudioSystem(self.World)
	VFXSystem(self.World)
end

function CameraRuntime:Destroy()
	if self.ScreenView then
		self.ScreenView:Destroy()
		self.ScreenView = nil
	end
	if self.VFXContext then
		self.VFXContext:Destroy()
		self.VFXContext = nil
	end
	if self.ImpactView then
		self.ImpactView:Destroy()
		self.ImpactView = nil
	end
	if self.Sound then
		self.Sound:Stop()
		self.Sound:Destroy()
		self.Sound = nil
	end
	self.World:despawn(self.Entity)
end

return CameraRuntime
