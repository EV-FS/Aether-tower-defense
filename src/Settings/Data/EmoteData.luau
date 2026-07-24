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
	Props: { PropConfig }?,
	KeyframeEvents: { [string]: KeyframeEventData }?,
}

local RawEmoteData: { [string]: RawEmoteConfig } = {
	["Mesmerizer"] = {
		Index = 1,
		AnimationId = "rbxassetid://103556706215217",
		WalkSpeed = 0,
		Priority = Enum.AnimationPriority.Action4,
		-- 소품(Prop) 장착 예시:
		-- Props = {
		-- 	{
		-- 		Name = "MicProp", -- ReplicatedStorage.Assets.Props.MicProp 모델/파츠
		-- 		AttachmentPart = "RightHand", -- 장착할 신체 부위 (기본값 "RightHand")
		-- 		CFrameOffset = CFrame.new(0, 0, 0), -- 필요시 오프셋 CFrame
		-- 		Motor6D = false, -- true일 경우 애니메이션 조인트를 위한 Motor6D 생성
		-- 	},
		-- },
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
