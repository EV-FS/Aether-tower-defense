local Matter = require(game:GetService("ReplicatedStorage").Packages.Matter)
local Components = require(script.Parent.Components)
local SampleTrack = require(script.Parent.SampleTrack)
local CameraSystem = require(script.Parent.CameraSystem)
local VFXSystem = require(script.Parent.VFXSystem)
local AudioSystem = require(script.Parent.AudioSystem)
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
	local sound = nil
	if config and config.Audio then
		sound = Instance.new("Sound")
		sound.Name = "CutsceneAudio"
		sound.SoundId = "rbxassetid://" .. config.Audio.SoundId
		sound.Volume = config.Audio.Volume or 1
		sound.Looped = false
		sound.Parent = game:GetService("SoundService")
		Prepare.Try("Audio preload", 8, function()
			game:GetService("ContentProvider"):PreloadAsync({ sound })
		end)
		world:insert(entity, Components.AudioTrack({ Sound = sound, Started = false }))
	end
	if vfx then
		local keys = {}
		for frame in vfx.Events do table.insert(keys, frame) end
		table.sort(keys)
		local ok, run = Prepare.Try("VFX initialization", 8, function()
			return VFXContext.new(state, vfx.Events)
		end)
		world:insert(entity, Components.VFXTrack({
			Events = vfx.Events, Keys = keys, NextIndex = 1,
			EndFrame = vfx.EndFrame, FPS = vfx.FPS,
			Run = if ok then run else function() end,
		}))
	end
	if fov then
		assert(not fov.FPS or fov.FPS > 0, "FOV FPS must be positive")
		world:insert(entity, Components.FOVTrack({
			Samples = fov.Samples,
			Keys = SampleTrack.Keys(fov.Samples),
			FPS = fov.FPS,
			Cuts = fov.Cuts,
		}))
	end
	return setmetatable({ World = world, Entity = entity, State = state, Tracks = tracks, Sound = sound }, CameraRuntime)
end

-- Called before Animator evaluates poses. Rendering uses this exact sample.
function CameraRuntime:PreAnimation()
	local elapsed = PlaybackClock.Elapsed(self.State, workspace:GetServerTimeNow())
	PlaybackClock.Apply(self.Tracks, elapsed)
	self.World:insert(self.Entity, Components.Session({ State = self.State, Elapsed = elapsed }))
end

function CameraRuntime:Step()
	CameraSystem(self.World)
	AudioSystem(self.World)
	VFXSystem(self.World)
end

function CameraRuntime:Destroy()
	if self.Sound then
		self.Sound:Stop()
		self.Sound:Destroy()
		self.Sound = nil
	end
	self.World:despawn(self.Entity)
end

return CameraRuntime
