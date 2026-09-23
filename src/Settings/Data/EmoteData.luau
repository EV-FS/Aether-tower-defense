local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)

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
	IntroAnimationId: (number | string)?,
	AnimationId: number | string,
	Looped: boolean?,
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
	IntroAnimationId: (number | string)?,
	AnimationId: number | string,
	Looped: boolean?,
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

local EmoteData = {
	ByName = {} :: { [string]: EmoteConfig },
	ByIndex = {} :: { [number]: EmoteConfig },
	ByAnimationId = {} :: { [string]: EmoteConfig },
}

local emoteFolder = script.Parent:FindFirstChild("Emotes")
assert(emoteFolder and emoteFolder:IsA("Folder"), "EmoteData requires a Settings.Data.Emotes folder")

local emoteModules = {}
for _, child in emoteFolder:GetChildren() do
	if child:IsA("ModuleScript") then
		table.insert(emoteModules, child)
	end
end
table.sort(emoteModules, function(left, right)
	return left.Name < right.Name
end)

for _, emoteModule in emoteModules do
	local data = require(emoteModule) :: RawEmoteConfig
	local name = data.Name or emoteModule.Name
	assert(EmoteData.ByName[name] == nil, `Duplicate emote name: {name}`)
	assert(EmoteData.ByIndex[data.Index] == nil, `Duplicate emote index: {data.Index}`)
	data.Name = name
	local animIdStr: string = typeof(data.AnimationId) == "number" and `rbxassetid://{data.AnimationId}`
		or tostring(data.AnimationId)
	data.AnimationId = animIdStr
	if data.IntroAnimationId then
		local introId = tostring(data.IntroAnimationId)
		data.IntroAnimationId = if string.sub(introId, 1, 13) == "rbxassetid://" then introId else `rbxassetid://{introId}`
	end

	EmoteData.ByName[name] = data
	EmoteData.ByIndex[data.Index] = data
	assert(EmoteData.ByAnimationId[animIdStr] == nil, `Duplicate emote animation ID: {animIdStr}`)
	EmoteData.ByAnimationId[animIdStr] = data
	if data.IntroAnimationId then
		local introId = tostring(data.IntroAnimationId)
		EmoteData.ByAnimationId[introId] = data
		local rawIntroId = string.match(introId, "%d+")
		if rawIntroId then
			EmoteData.ByAnimationId[rawIntroId] = data
			EmoteData.ByAnimationId[`rbxassetid://{rawIntroId}`] = data
		end
	end

	local rawIdStr: string? = string.match(animIdStr, "%d+")
	if rawIdStr then
		EmoteData.ByAnimationId[rawIdStr] = data
		EmoteData.ByAnimationId[`rbxassetid://{rawIdStr}`] = data
	end
end

return TableUtils.DeepFreeze(EmoteData)
