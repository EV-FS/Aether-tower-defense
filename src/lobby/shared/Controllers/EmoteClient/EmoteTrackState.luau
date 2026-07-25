--// EmoteTrackState
-- Manages the lifecycle of a single emote AnimationTrack:
-- sound playback, keyframe events (SFX/VFX), and automatic cleanup.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EmitParticles = require(ReplicatedStorage.Shared.Modules.Utils.EmitParticles)
local EmoteData = require(ReplicatedStorage.Settings.Data.EmoteData)
local CharacterUtils = require(script.Parent.CharacterUtils)
local ServiceUtils = require(script.Parent.ServiceUtils)

-------------------------------------------------
--// Types
-------------------------------------------------
type EmoteConfig = EmoteData.EmoteConfig
type KeyframeEventData = EmoteData.KeyframeEventData

-------------------------------------------------
--// Constants
-------------------------------------------------
local DEFAULT_SOUND_VOLUME = 1
local DEFAULT_SOUND_DISTANCE = 100

-------------------------------------------------
--// EmoteTrackState Class
-------------------------------------------------
local EmoteTrackState = {}
EmoteTrackState.__index = EmoteTrackState

export type EmoteTrackState = typeof(setmetatable({} :: {
	Character: Model,
	Track: AnimationTrack,
	EmoteConfig: EmoteConfig,
	OnDestroy: () -> (),
	Connections: { RBXScriptConnection },
	Sounds: { any },
}, EmoteTrackState))

function EmoteTrackState.new(
	character: Model,
	track: AnimationTrack,
	emoteConfig: EmoteConfig,
	onDestroy: () -> ()
): EmoteTrackState
	local self = setmetatable({
		Character = character,
		Track = track,
		EmoteConfig = emoteConfig,
		OnDestroy = onDestroy,
		Connections = {} :: { RBXScriptConnection },
		Sounds = {} :: { any },
	}, EmoteTrackState)

	self:_initialize()
	return self
end

-------------------------------------------------
--// Initialization
-------------------------------------------------

function EmoteTrackState._initialize(self: EmoteTrackState)
	self:_setupSound()
	self:_setupKeyframeEvents()

	local stopConn = self.Track.Stopped:Once(function()
		self:Destroy()
	end)
	table.insert(self.Connections, stopConn)
end

function EmoteTrackState._setupSound(self: EmoteTrackState)
	local soundId = self.EmoteConfig.SoundId
	if not soundId then
		return
	end

	local rootPart = CharacterUtils.GetRootPart(self.Character)
	if not rootPart then
		return
	end

	local audioCtrl = ServiceUtils.Get("AudioController")
	if not audioCtrl then
		return
	end

	local soundPlayer = audioCtrl.PlayOn3D(
		soundId,
		self.EmoteConfig.SoundVolume or DEFAULT_SOUND_VOLUME,
		self.EmoteConfig.SoundDistance or DEFAULT_SOUND_DISTANCE,
		rootPart,
		self.EmoteConfig.SoundLooped
	)
	if soundPlayer then
		table.insert(self.Sounds, soundPlayer)
	end
end

function EmoteTrackState._setupKeyframeEvents(self: EmoteTrackState)
	local keyframeEvents = self.EmoteConfig.KeyframeEvents
	if not keyframeEvents then
		return
	end

	task.spawn(function()
		if self.Track.Length == 0 then
			self.Track:GetPropertyChangedSignal("Length"):Wait()
		end

		local keyframeConn = self.Track.KeyframeReached:Connect(function(keyframeName)
			local eventData = keyframeEvents[keyframeName]
			if eventData then
				self:_handleKeyframeEvent(eventData)
			end
		end)
		table.insert(self.Connections, keyframeConn)
	end)
end

-------------------------------------------------
--// Keyframe Event Handlers
-------------------------------------------------

function EmoteTrackState._handleKeyframeEvent(self: EmoteTrackState, eventData: KeyframeEventData)
	local rootPart = CharacterUtils.GetRootPart(self.Character)
	if not rootPart then
		return
	end

	if eventData.SFX then
		self:_playKeyframeSFX(eventData, rootPart)
	end

	if eventData.VFXRecipes then
		self:_playKeyframeVFXRecipes(eventData)
		return
	end

	if eventData.VFX then
		self:_playKeyframeVFX(eventData)
	end
end

function EmoteTrackState._playKeyframeSFX(self: EmoteTrackState, eventData: KeyframeEventData, rootPart: BasePart)
	local audioCtrl = ServiceUtils.Get("AudioController")
	if not audioCtrl then
		return
	end

	local soundPlayer = audioCtrl.PlayOn3D(
		eventData.SFX,
		eventData.Volume or DEFAULT_SOUND_VOLUME,
		eventData.Distance or DEFAULT_SOUND_DISTANCE,
		rootPart
	)
	if soundPlayer then
		table.insert(self.Sounds, soundPlayer)
	end
end

function EmoteTrackState._playKeyframeVFXRecipes(self: EmoteTrackState, eventData: KeyframeEventData)
	local vfxCtrl = ServiceUtils.Get("VFXController")
	if not vfxCtrl then
		return
	end

	local recipes = if typeof(eventData.VFXRecipes) == "table"
		then eventData.VFXRecipes
		else (vfxCtrl.GetRecipes(eventData.VFXRecipes, "Emote") or vfxCtrl.GetRecipes("Emote", eventData.VFXRecipes))

	if recipes then
		vfxCtrl.PlayVFX(recipes, self.Character, self.Character)
	end
end

function EmoteTrackState._playKeyframeVFX(self: EmoteTrackState, eventData: KeyframeEventData)
	local vfxCtrl = ServiceUtils.Get("VFXController")
	local recipes = vfxCtrl
		and vfxCtrl.GetRecipes
		and (vfxCtrl.GetRecipes(eventData.VFX, "Emote") or vfxCtrl.GetRecipes("Emote", eventData.VFX))

	if recipes then
		vfxCtrl.PlayVFX(recipes, self.Character, self.Character)
		return
	end

	local vfxTarget = self.Character:FindFirstChild(eventData.VFX, true)
	if vfxTarget then
		EmitParticles(vfxTarget)
	end
end

-------------------------------------------------
--// Cleanup
-------------------------------------------------

function EmoteTrackState.Destroy(self: EmoteTrackState)
	for _, sound in ipairs(self.Sounds) do
		if sound and typeof(sound.Stop) == "function" then
			sound:Stop()
		end
	end
	table.clear(self.Sounds)

	for _, conn in ipairs(self.Connections) do
		conn:Disconnect()
	end
	table.clear(self.Connections)

	if self.OnDestroy then
		self.OnDestroy()
	end
end

return EmoteTrackState
