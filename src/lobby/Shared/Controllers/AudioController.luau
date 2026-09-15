--/Service
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")

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
local function GetInverseAttenuation(minDist: number, maxDist: number): { [number]: number }
	local attenuation: { [number]: number } = {}
	local rollOffMin = math.max(minDist, 10)
	attenuation[0] = 1
	attenuation[rollOffMin] = 1

	local steps = 5
	for i = 1, steps do
		local distance = rollOffMin + (maxDist - rollOffMin) * (i / steps)
		local volume = rollOffMin / distance
		attenuation[distance] = math.clamp(volume, 0, 1)
	end

	attenuation[maxDist] = 0
	return attenuation
end

local function setupAudioListener()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local listener = camera:FindFirstChildOfClass("AudioListener") or Instance.new("AudioListener")
	listener.Parent = camera

	local listenerWire = SoundService:FindFirstChild("AudioListenerWire") :: Wire?
	if listenerWire and listenerWire.SourceInstance == listener and listenerWire.TargetInstance == DeviceOutput then
		return
	end

	for _, wire in listener:GetConnectedWires("Output") do
		if wire.TargetInstance == DeviceOutput then
			return
		end
	end

	if not listenerWire then
		if #DeviceOutput:GetConnectedWires("Input") > 0 then
			return
		end

		listenerWire = Instance.new("Wire")
		listenerWire.Name = "AudioListenerWire"
		listenerWire.Parent = SoundService
	else
		-- 기존 카메라 Listener에서 분리한 뒤 새 Listener로 옮긴다.
		listenerWire.TargetInstance = nil
	end

	listenerWire.SourceInstance = listener
	listenerWire.TargetInstance = DeviceOutput
end

-------------------------------------------------
--// AudioController
-------------------------------------------------
local AudioController = {}
AudioController.SFXVolume = 1

function AudioController.PlayOn2D(soundId: any, volume: number?, looped: boolean?)
	soundId = typeof(soundId) == "string" and soundId or `rbxassetid://{soundId}`

	local audioPlayer: AudioPlayer = PlayerStorage:GetInstance()
	audioPlayer.PlaybackSpeed = 1
	audioPlayer.Asset = soundId
	audioPlayer.TimePosition = 0
	audioPlayer.Looping = looped == true
	pcall(function()
		audioPlayer.Parent = SoundService
	end)

	local fader: AudioFader?
	local faderWire: Wire?

	if volume or AudioController.SFXVolume ~= 1 then
		fader = FaderStorage:GetInstance() :: AudioFader
		fader.Volume = (volume or 1) * AudioController.SFXVolume
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

	local isCleaned = false
	local endedConn: RBXScriptConnection?

	local function cleanup()
		if isCleaned then
			return
		end
		isCleaned = true

		if endedConn then
			endedConn:Disconnect()
			endedConn = nil
		end

		audioPlayer.Looping = false
		audioPlayer:Stop()
		audioPlayer.TimePosition = 0
		audioPlayer.PlaybackSpeed = 1
		PlayerStorage:ReturnInstance(audioPlayer)
		WireStorage:ReturnInstance(wire)

		if fader then
			FaderStorage:ReturnInstance(fader)
		end
		if faderWire then
			WireStorage:ReturnInstance(faderWire)
		end
	end

	endedConn = audioPlayer.Ended:Once(cleanup)

	return {
		Player = audioPlayer,
		Stop = cleanup,
	}
end

function AudioController.PlayOn3D(
	soundId: any,
	volume: number?,
	distance: number?,
	parent: Instance | Vector3,
	looped: boolean?,
	duckBGMDistance: number?
)
	soundId = typeof(soundId) == "string" and soundId or `rbxassetid://{soundId}`

	local parentInst: Instance
	local isVector3 = typeof(parent) == "Vector3"

	if isVector3 then
		local part = Instance.new("Part")
		part.Size = Vector3.zero
		part.Transparency = 1
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Anchored = true
		part.Position = parent
		part.Parent = workspace.Terrain
		parentInst = part
	else
		parentInst = parent
	end

	local audioPlayer: AudioPlayer = PlayerStorage:GetInstance()
	audioPlayer.PlaybackSpeed = 1
	audioPlayer.Asset = soundId
	audioPlayer.TimePosition = 0
	audioPlayer.Looping = looped == true
	pcall(function()
		audioPlayer.Parent = SoundService
	end)

	local emitter: AudioEmitter = EmitterStorage:GetInstance()
	emitter:SetDistanceAttenuation(GetInverseAttenuation(0, distance or DEFAULT_DISTANCE))
	emitter.Parent = parentInst

	local fader: AudioFader?
	local faderWire: Wire?

	if volume or AudioController.SFXVolume ~= 1 then
		fader = FaderStorage:GetInstance()
		if fader then
			fader.Volume = (volume or 1) * AudioController.SFXVolume
			fader.Parent = parentInst
		end

		faderWire = WireStorage:GetInstance()
		if faderWire and fader then
			faderWire.SourceInstance = fader
			faderWire.TargetInstance = emitter
			faderWire.Parent = parentInst
		end
	end

	local wire: Wire = WireStorage:GetInstance()
	wire.SourceInstance = audioPlayer
	wire.TargetInstance = fader or emitter
	wire.Parent = parentInst

	audioPlayer:Play()

	local bgmSound: Sound? = nil
	local originalBGMVolume: number? = nil
	local bgmDuckConnection: RBXScriptConnection? = nil
	if duckBGMDistance then
		bgmSound = SoundService:FindFirstChild("BGM") :: Sound?
		if bgmSound then
			originalBGMVolume = bgmSound.Volume
			local maxDistance = duckBGMDistance
			bgmDuckConnection = RunService.Heartbeat:Connect(function()
				local camera = workspace.CurrentCamera
				if not camera or not parentInst.Parent then
					return
				end

				local sourcePosition = if parentInst:IsA("BasePart")
					then parentInst.Position
					else camera.CFrame.Position
				local distanceFromSource = (camera.CFrame.Position - sourcePosition).Magnitude
				local proximity = math.clamp(1 - distanceFromSource / maxDistance, 0, 1)
				bgmSound.Volume = originalBGMVolume * (1 - proximity * 0.65)
			end)
		end
	end

	local isCleaned = false
	local endedConn: RBXScriptConnection?

	local function cleanup()
		if isCleaned then
			return
		end
		isCleaned = true
		if bgmDuckConnection then
			bgmDuckConnection:Disconnect()
			bgmDuckConnection = nil
		end
		if bgmSound and originalBGMVolume then
			bgmSound.Volume = originalBGMVolume
		end

		if endedConn then
			endedConn:Disconnect()
			endedConn = nil
		end

		if isVector3 and parentInst then
			parentInst:Destroy()
		end

		audioPlayer.Looping = false
		audioPlayer:Stop()
		audioPlayer.TimePosition = 0
		audioPlayer.PlaybackSpeed = 1
		PlayerStorage:ReturnInstance(audioPlayer)
		EmitterStorage:ReturnInstance(emitter)
		WireStorage:ReturnInstance(wire)

		if fader then
			FaderStorage:ReturnInstance(fader)
		end
		if faderWire then
			WireStorage:ReturnInstance(faderWire)
		end
	end

	endedConn = audioPlayer.Ended:Once(cleanup)

	return {
		Player = audioPlayer,
		Stop = cleanup,
	}
end

function AudioController.SetBGMState(playing: boolean?, volume: number?, newBGMId)
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

function AudioController.Init()
	PlayerStorage = InstanceCache.new(Instance.new("AudioPlayer"), 30, Caches)
	EmitterStorage = InstanceCache.new(Instance.new("AudioEmitter"), 30, Caches)
	WireStorage = InstanceCache.new(Instance.new("Wire"), 60, Caches)
	FaderStorage = InstanceCache.new(Instance.new("AudioFader"), 30, Caches)

	setupAudioListener()
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(setupAudioListener)

	AudioController.SetBGMState(true, DEFAULT_VOLUME)
end

return AudioController
