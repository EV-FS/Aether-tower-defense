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
	AnimationId: number | string,
	Priority: Enum.AnimationPriority?,
	WalkSpeed: number?,
	SoundId: (number | string)?,
	SoundVolume: number?,
	SoundDistance: number?,
	SoundLooped: boolean?,
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
	Props: { PropConfig }?,
	KeyframeEvents: { [string]: KeyframeEventData }?,
}

local RawEmoteData: { [string]: RawEmoteConfig } = {
	["Mesmerizer"] = {
		Index = 1,
		AnimationId = "rbxassetid://103556706215217",
		SoundId = "rbxassetid://109907034200284",
		SoundVolume = 1,
		SoundDistance = 80,
		SoundLooped = true,
		WalkSpeed = 0,
		Priority = Enum.AnimationPriority.Action4,
	},
	["Shutter"] = {
		Index = 2,
		AnimationId = "rbxassetid://132177421118009",
		WalkSpeed = 4,
		Priority = Enum.AnimationPriority.Action,
		Props = {
			{
				Name = "Camera",
				AttachmentPart = "Right Arm",
				CFrameOffset = CFrame.new(-0.415, -0.698, -0.711),
				Motor6D = true,
			},
		},
		KeyframeEvents = {
			["CameraFlash"] = {
				VFXRecipes = "CameraFlash",
				SFX = "rbxassetid://70793938100698",
				Volume = 10,
				Distance = 80,
			},
		},
	},
	["Aura Monster"] = {
		Index = 3,
		AnimationId = "rbxassetid://92364767557182",
		WalkSpeed = 0,
		Priority = Enum.AnimationPriority.Action4,
		Props = {
			{
				Name = "stair1",
				AttachmentPart = "Right Arm",
				CFrameOffset = CFrame.new(-1.657, -2.5, -0.024),
				Motor6D = true,
			},
			{
				Name = "stair2",
				AttachmentPart = "Right Arm",
				CFrameOffset = CFrame.new(-1.657, -2.5, -0.024),
				Motor6D = true,
			},
			{
				Name = "stair3",
				AttachmentPart = "Right Arm",
				CFrameOffset = CFrame.new(-1.657, -2.5, -0.024),
				Motor6D = true,
			},
		},
	},
	["Yararara"] = {
		Index = 4,
		AnimationId = "rbxassetid://132998445704945",
		WalkSpeed = 6,
		Priority = Enum.AnimationPriority.Action,
		Props = {
			{
				Name = "Bat",
				AttachmentPart = "Right Arm",
				CFrameOffset = CFrame.new(0.012, -0.715, -2.021) * CFrame.Angles(0, math.rad(-90), math.rad(90)),
				Motor6D = true,
			},
		},
	},
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
