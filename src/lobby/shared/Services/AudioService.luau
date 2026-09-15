--/Service
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

--/Modules
local InstanceCache = require(ReplicatedStorage.Shared.Modules.Core.InstanceCache)

--/Variables
local Caches = workspace:WaitForChild("Caches")
local DeviceOutput = SoundService:WaitForChild("AudioDeviceOutput") or Instance.new("AudioDeviceOutput")
DeviceOutput.Parent = SoundService

local AudioFolder = SoundService:WaitForChild("Audio") or Instance.new("Folder")
AudioFolder.Parent = SoundService

--/Constants
local DEFAULT_DISTANCE = 1000
local DEFAULT_VOLUME = 1

--/Pools
local PlayerStorage
local EmitterStorage
local WireStorage
local FaderStorage

-------------------------------------------------
--// Local Functions
-------------------------------------------------
local function GetInverseAttenuation(minDist, maxDist)
	local attenuation = {}
	attenuation[0] = 1
	attenuation[minDist] = 1

	local steps = 5
	for i = 1, steps do
		local distance = minDist + (maxDist - minDist) * (i / steps)
		local volume = minDist / distance
		attenuation[distance] = math.clamp(volume, 0, 1)
	end

	attenuation[maxDist] = 0
	return attenuation
end

-------------------------------------------------
--// AudioService
-------------------------------------------------
local AudioService = {}
AudioService.SFXVolume = 1

function AudioService.PlayOn2D(soundId, volume: number?)
	soundId = typeof(soundId) == "string" and soundId or `rbxassetid://{soundId}`

	local audioPlayer: AudioPlayer = PlayerStorage:GetInstance()
	audioPlayer.Asset = soundId
	audioPlayer.Parent = SoundService

	local fader
	local faderWire

	if volume or AudioService.SFXVolume ~= 1 then
		fader = FaderStorage:GetInstance() :: AudioFader
		fader.Volume = (volume or 1) * AudioService.SFXVolume
		fader.Parent = SoundService

		faderWire = WireStorage:GetInstance() :: Wire
		faderWire.SourceInstance = fader
		faderWire.TargetInstance = DeviceOutput
		faderWire.Parent = SoundService
	end

	local wire: Wire = WireStorage:GetInstance()
	wire.SourceInstance = audioPlayer
	wire.TargetInstance = fader or DeviceOutput
	wire.Parent = SoundService

	audioPlayer:Play()

	audioPlayer.Ended:Once(function()
		PlayerStorage:ReturnInstance(audioPlayer)
		WireStorage:ReturnInstance(wire)

		if fader then
			FaderStorage:ReturnInstance(fader)
		end
		if faderWire then
			WireStorage:ReturnInstance(faderWire)
		end
	end)

	return audioPlayer
end

function AudioService.PlayOn3D(soundId, volume: number?, distance: number?, parent: Instance | Vector3)
	soundId = typeof(soundId) == "string" and soundId or `rbxassetid://{soundId}`

	local parentInst
	local isVector3 = typeof(parent) == "Vector3"

	if isVector3 then
		parentInst = Instance.new("Part")
		parentInst.Size = Vector3.zero
		parentInst.Transparency = 1
		parentInst.CanCollide = false
		parentInst.CanQuery = false
		parentInst.CanTouch = false
		parentInst.Anchored = true
		parentInst.Position = parent

		parentInst.Parent = workspace.Terrain
	else
		parentInst = parent
	end

	local audioPlayer: AudioPlayer = PlayerStorage:GetInstance()
	audioPlayer.Asset = soundId
	audioPlayer.Parent = SoundService

	local emitter: AudioEmitter = EmitterStorage:GetInstance()
	emitter:SetDistanceAttenuation(GetInverseAttenuation(0, distance or DEFAULT_DISTANCE))
	emitter.Parent = parentInst

	local fader
	local faderWire

	if volume or AudioService.SFXVolume ~= 1 then
		fader = FaderStorage:GetInstance()
		fader.Volume = (volume or 1) * AudioService.SFXVolume
		fader.Parent = parentInst

		faderWire = WireStorage:GetInstance()
		faderWire.SourceInstance = fader
		faderWire.TargetInstance = emitter
		faderWire.Parent = parentInst
	end

	local wire: Wire = WireStorage:GetInstance()
	wire.SourceInstance = audioPlayer
	wire.TargetInstance = fader or emitter
	wire.Parent = parentInst

	audioPlayer:Play()

	audioPlayer.Ended:Once(function()
		if isVector3 and parentInst then
			parentInst:Destroy()
		end

		PlayerStorage:ReturnInstance(audioPlayer)
		EmitterStorage:ReturnInstance(emitter)
		WireStorage:ReturnInstance(wire)

		if fader then
			FaderStorage:ReturnInstance(fader)
		end
		if faderWire then
			WireStorage:ReturnInstance(faderWire)
		end
	end)

	return audioPlayer
end

function AudioService.SetBGMState(playing: boolean?, volume: number?, newBGMId)
	local bgmSound: Sound = SoundService:WaitForChild("BGM")
	if newBGMId then
		newBGMId = typeof(newBGMId) == "string" and newBGMId or `rbxassetid://{newBGMId}`
		bgmSound.TimePosition = 0
	end

	bgmSound.Volume = volume or bgmSound.Volume
	bgmSound.SoundId = newBGMId or bgmSound.SoundId
	bgmSound.Looped = true

	bgmSound.Parent = SoundService

	if playing then
		bgmSound:Play()
	elseif playing == false then
		bgmSound:Stop()
	end
end

function AudioService.Init()
	PlayerStorage = InstanceCache.new(Instance.new("AudioPlayer"), 30, Caches)
	EmitterStorage = InstanceCache.new(Instance.new("AudioEmitter"), 30, Caches)
	WireStorage = InstanceCache.new(Instance.new("Wire"), 60, Caches)
	FaderStorage = InstanceCache.new(Instance.new("AudioFader"), 30, Caches)

	AudioService.SetBGMState(true, DEFAULT_VOLUME)
end

return AudioService
