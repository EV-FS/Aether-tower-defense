local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)

-- The individual emote modules are siblings of this module in Settings.Data.
-- Looking beneath `script` made every config silently use its stale fallback.
local dataFolder = script.Parent
local kyukurarinModule = dataFolder:FindFirstChild("Kyukurarin")
local takeTheLModule = dataFolder:FindFirstChild("TakeTheL")
local usagiflapModule = dataFolder:FindFirstChild("Usagiflap")
local grayzoneModule = dataFolder:FindFirstChild("Grayzone")
local Kyukurarin = if kyukurarinModule and kyukurarinModule:IsA("ModuleScript")
	then require(kyukurarinModule)
	else {
		Name = "Kyukurarin",
		Index = 1,
		DisplayName = "Kyukurarin",
		AnimationId = "rbxassetid://135619554552444",
		SoundId = "rbxassetid://75781288305318",
		SoundVolume = 1,
		SoundDistance = 80,
		SoundLooped = true,
		PlaybackSpeed = 0.9,
		WalkSpeed = 4,
		Priority = Enum.AnimationPriority.Action4,
	}
local TakeTheL = if takeTheLModule and takeTheLModule:IsA("ModuleScript")
	then require(takeTheLModule)
	else {
		Name = "Take the L",
		Index = 2,
		DisplayName = "Take the L",
		AnimationId = "rbxassetid://88824884403975",
		SoundId = "rbxassetid://120518826488481",
		SoundVolume = 1,
		SoundDistance = 80,
		SoundLooped = true,
		PlaybackSpeed = 0.9,
		WalkSpeed = 4,
		Priority = Enum.AnimationPriority.Action4,
	}
local Usagiflap = if usagiflapModule and usagiflapModule:IsA("ModuleScript")
	then require(usagiflapModule)
	else {
		Name = "Usagiflap",
		Index = 3,
		DisplayName = "Usagiflap",
		AnimationId = "rbxassetid://121766824032548",
		SoundId = "rbxassetid://73854560511013",
		SoundVolume = 1,
		SoundDistance = 80,
		SoundLooped = true,
		PlaybackSpeed = 0.9,
		WalkSpeed = 4,
		Priority = Enum.AnimationPriority.Action4,
	}
local Grayzone = if grayzoneModule and grayzoneModule:IsA("ModuleScript")
	then require(grayzoneModule)
	else {
		Name = "Grayzone",
		Index = 4,
		DisplayName = "Grayzone",
		AnimationId = "rbxassetid://123113221439398",
		SoundId = "rbxassetid://135082326035068",
		SoundVolume = 1,
		SoundDistance = 80,
		SoundLooped = true,
		PlaybackSpeed = 0.9,
		WalkSpeed = 4,
		Priority = Enum.AnimationPriority.Action4,
	}

export type KeyframeEventData = {
	SFX: (number | string)?,
	Volume: number?,
	Distance: number?,
	VFX: string?,
	VFXRecipes: any?,
	EmitCount: number?,
}

export type PropConfig = {
	Name: string,
	AttachmentPart: string?,
	CFrameOffset: CFrame?,
	Motor6D: boolean?,
	Motor6DName: string?,
}

export type EmoteConfig = {
	Name: string,
	Index: number,
	DisplayName: string?,
	AnimationId: number | string,
	Priority: Enum.AnimationPriority?,
	WalkSpeed: number?,
	SoundId: (number | string)?,
	SoundVolume: number?,
	SoundDistance: number?,
	SoundLooped: boolean?,
	PlaybackSpeed: number?,
	Props: { PropConfig }?,
	KeyframeEvents: { [string]: KeyframeEventData }?,
}

export type RawEmoteConfig = {
	Name: string?,
	Index: number,
	DisplayName: string?,
	AnimationId: number | string,
	Priority: Enum.AnimationPriority?,
	WalkSpeed: number?,
	SoundId: (number | string)?,
	SoundVolume: number?,
	SoundDistance: number?,
	SoundLooped: boolean?,
	PlaybackSpeed: number?,
	Props: { PropConfig }?,
	KeyframeEvents: { [string]: KeyframeEventData }?,
}

local RawEmoteData: { [string]: RawEmoteConfig } = {
	[Kyukurarin.Name] = Kyukurarin,
	[TakeTheL.Name] = TakeTheL,
	[Usagiflap.Name] = Usagiflap,
	[Grayzone.Name] = Grayzone,
}

local EmoteData = {
	ByName = {} :: { [string]: EmoteConfig },
	ByIndex = {} :: { [number]: EmoteConfig },
	ByAnimationId = {} :: { [string]: EmoteConfig },
}

for name, rawData in pairs(RawEmoteData) do
	local data = rawData :: EmoteConfig
	data.Name = name
	local animIdStr: string = typeof(data.AnimationId) == "number" and `rbxassetid://{data.AnimationId}`
		or tostring(data.AnimationId)
	data.AnimationId = animIdStr

	EmoteData.ByName[name] = data
	EmoteData.ByIndex[data.Index] = data
	EmoteData.ByAnimationId[animIdStr] = data

	local rawIdStr: string? = string.match(animIdStr, "%d+")
	if rawIdStr then
		EmoteData.ByAnimationId[rawIdStr] = data
		EmoteData.ByAnimationId[`rbxassetid://{rawIdStr}`] = data
	end
end

return TableUtils.DeepFreeze(EmoteData)
