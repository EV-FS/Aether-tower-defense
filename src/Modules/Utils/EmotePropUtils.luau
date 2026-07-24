local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EmoteData = require(ReplicatedStorage.Settings.Data.EmoteData)

type PropConfig = EmoteData.PropConfig

local EmotePropUtils = {}

function EmotePropUtils.ClearProps(character: Model)
	local propsFolder = character:FindFirstChild("EmoteProps")
	if propsFolder then
		propsFolder:Destroy()
	end
end

function EmotePropUtils.AttachProps(character: Model, propConfigs: { PropConfig })
	EmotePropUtils.ClearProps(character)

	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
	local propsAssetsFolder = assetsFolder and assetsFolder:FindFirstChild("Props")
	if not propsAssetsFolder then
		return
	end

	local propsFolder = Instance.new("Folder")
	propsFolder.Name = "EmoteProps"
	propsFolder.Parent = character

	for _, propConfig in ipairs(propConfigs) do
		local propTemplate = propsAssetsFolder:FindFirstChild(propConfig.Name)
		if not propTemplate then
			warn(`[EmotePropUtils] Prop asset missing: {propConfig.Name}`)
			continue
		end

		local propClone = propTemplate:Clone()
		local attachPartName = propConfig.AttachmentPart or "RightHand"
		local bodyPart = character:FindFirstChild(attachPartName) :: BasePart?
		if not bodyPart then
			warn(`[EmotePropUtils] Character body part missing: {attachPartName}`)
			propClone:Destroy()
			continue
		end

		local propPrimary: BasePart? = if propClone:IsA("Model")
			then (propClone.PrimaryPart or propClone:FindFirstChildOfClass("BasePart") :: BasePart?)
			else (propClone :: BasePart)

		if not propPrimary then
			warn(`[EmotePropUtils] Prop model has no primary part: {propConfig.Name}`)
			propClone:Destroy()
			continue
		end

		local offset = propConfig.CFrameOffset or CFrame.new()
		if propClone:IsA("Model") then
			propClone:PivotTo(bodyPart.CFrame * offset)
		elseif propClone:IsA("BasePart") then
			propClone.CFrame = bodyPart.CFrame * offset
		end

		if propConfig.Motor6D then
			local motor = Instance.new("Motor6D")
			motor.Name = `{propConfig.Name}Motor`
			motor.Part0 = bodyPart
			motor.Part1 = propPrimary
			motor.C0 = offset
			motor.Parent = propPrimary
		else
			local weld = Instance.new("WeldConstraint")
			weld.Name = `{propConfig.Name}Weld`
			weld.Part0 = bodyPart
			weld.Part1 = propPrimary
			weld.Parent = propPrimary
		end

		propClone.Parent = propsFolder
	end
end

return EmotePropUtils
