local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)

local kyukurarinModule = script:FindFirstChild("Kyukurarin")
local zaakoModule = script:FindFirstChild("Zaako")
local usagiflapModule = script:FindFirstChild("Usagiflap")
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
local Zaako = if zaakoModule and zaakoModule:IsA("ModuleScript")
	then require(zaakoModule)
	else {
		Name = "Zaako",
		Index = 2,
		DisplayName = "Zaako",
		AnimationId = "rbxassetid://136212709851148",
		SoundId = "rbxassetid://130251752855636",
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
	[Zaako.Name] = Zaako,
	[Usagiflap.Name] = Usagiflap,
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
