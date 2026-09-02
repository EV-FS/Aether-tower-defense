--/Service
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

--/Modules
local SFXRecipes = require(ReplicatedStorage.Settings.Visuals.SFXRecipes)
local InstanceCache = require(ReplicatedStorage.Shared.Modules.Core.InstanceCache)
local TimeService

--/Variables
local Caches = workspace:WaitForChild("Caches")
local DeviceOutput = SoundService:WaitForChild("AudioDeviceOutput") or Instance.new("AudioDeviceOutput")
DeviceOutput.Parent = SoundService

local AudioFolder = SoundService:WaitForChild("Audio") or Instance.new("Folder")
AudioFolder.Parent = SoundService

--/Constants
local DEFAULT_DISTANCE = 1000
local DEFAULT_VOLUME = 1

local SFX_FOLDER = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("SFX")

--/Pools
local PlayerStorage
local EmitterStorage
local WireStorage
local FaderStorage

export type Recipes = { SFXRecipes.Step }

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

local function getSound(soundPath: string)
	local current: Instance? = SFX_FOLDER

	for name in string.gmatch(soundPath, "[^/]+") do
		current = current and current:FindFirstChild(name)

		if not current then
			warn(`Sound 에셋을 찾을 수 없음: {soundPath}`)
			return nil
		end
	end

	return current
end

local function resolveInstance(value: any, sourceModel: Model, targetModel: Model)
	if typeof(value) == "Instance" then
		return value
	end

	if type(value) ~= "string" then
		return
	end

	local parts = string.split(value, ".")
	local rootName = parts[1]

	local rootModel
	if rootName == "Source" then
		rootModel = sourceModel
	elseif rootName == "Target" then
		rootModel = targetModel
	else
		warn(`잘못된 경로: {rootName}`)
		return
	end

	if not rootModel or not rootModel.Parent then
		return
	end

	if #parts == 1 then
		return rootModel.PrimaryPart
	end

	local current = rootModel
	for i = 2, #parts do
		current = current:FindFirstChild(parts[i])

		if not current then
			warn(`경로를 찾을 수 없음: {value}`)
			return
		end
	end

	return current
end

-------------------------------------------------
--// AudioService
-------------------------------------------------
local AudioService = {}
AudioService.SFXVolume = 1

function AudioService.GetRecipes(sourceName: string, audioType: string, sourceLevel: number?): Recipes?
	local sourceRecipes = SFXRecipes[sourceName]
	if not sourceRecipes then
		return nil
	end

	local audioRecipes = sourceRecipes[audioType]
	if not audioRecipes then
		return nil
	end

	local level = sourceLevel or 0

	for currentLevel = level, 0, -1 do
		local recipes = audioRecipes[currentLevel]

		if recipes then
			return recipes
		end
	end

	return nil
end

function AudioService.PlayFromRecipes(soundRecipes: Recipes, sourceModel: Model, targetModel: Model)
	for _, recipe in soundRecipes do
		if recipe.Delay and recipe.Delay > 0 then
			local delayedRecipe = table.clone(recipe)
			delayedRecipe.Delay = nil

			TimeService.DeltaDelay(recipe.Delay):andThen(function()
				AudioService.PlayFromRecipes({ delayedRecipe }, sourceModel, targetModel)
			end)

			continue
		end

		local soundAsset = getSound(recipe.Sound)
		local soundId = soundAsset and soundAsset.SoundId or recipe.Sound
		local volume = recipe.Volume or (soundAsset and soundAsset.Volume) or 1

		if recipe.Type == "2D" then
			AudioService.PlayOn2D(soundId, volume)
		elseif recipe.Type == "3D" then
			local soundParent = resolveInstance(recipe.At, sourceModel, targetModel)
			if soundParent then
				AudioService.PlayOn3D(soundId, volume, nil, soundParent)
			end
		else
			warn(`알 수 없는 SFX Type: {recipe.Type}`)
		end
	end
end

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

function AudioService.Init(services)
	TimeService = services:GetService("TimeService")

	PlayerStorage = InstanceCache.new(Instance.new("AudioPlayer"), 30, Caches)
	EmitterStorage = InstanceCache.new(Instance.new("AudioEmitter"), 30, Caches)
	WireStorage = InstanceCache.new(Instance.new("Wire"), 60, Caches)
	FaderStorage = InstanceCache.new(Instance.new("AudioFader"), 30, Caches)
end

function AudioService.Start()
	AudioService.SetBGMState(true, DEFAULT_VOLUME)
end

return AudioService
