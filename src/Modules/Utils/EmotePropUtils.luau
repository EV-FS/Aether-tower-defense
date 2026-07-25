local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EmoteData = require(ReplicatedStorage.Settings.Data.EmoteData)

type PropConfig = EmoteData.PropConfig

local EmotePropUtils = {}

local R6_PART_ALIASES: { [string]: string } = {
	["RightHand"] = "Right Arm",
	["LeftHand"] = "Left Arm",
	["UpperTorso"] = "Torso",
	["LowerTorso"] = "Torso",
	["RightFoot"] = "Right Leg",
	["LeftFoot"] = "Left Leg",
}

local function resolveBodyPart(character: Model, partName: string?): BasePart?
	if not partName then
		partName = "Right Arm"
	end

	local part = character:FindFirstChild(partName) :: BasePart?
	if part then
		return part
	end

	local alias = R6_PART_ALIASES[partName]
	if alias then
		local aliasPart = character:FindFirstChild(alias) :: BasePart?
		if aliasPart then
			return aliasPart
		end
	end

	return (character:FindFirstChild("Right Arm") or character.PrimaryPart) :: BasePart?
end

local function setupPropPhysicsAndWelds(propInstance: Instance, primaryPart: BasePart)
	for _, descendant in ipairs(propInstance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.Massless = true

			if descendant ~= primaryPart then
				local existingWeld = descendant:FindFirstChildOfClass("WeldConstraint")
					or descendant:FindFirstChildOfClass("Motor6D")
					or descendant:FindFirstChildOfClass("Weld")
				if not existingWeld then
					local weld = Instance.new("WeldConstraint")
					weld.Name = `{descendant.Name}SubWeld`
					weld.Part0 = primaryPart
					weld.Part1 = descendant
					weld.Parent = descendant
				end
			end
		end
	end
end

function EmotePropUtils.ClearProps(character: Model)
	for _, child in ipairs(character:GetChildren()) do
		if child.Name == "EmoteProps" then
			child:Destroy()
		end
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
		local bodyPart = resolveBodyPart(character, propConfig.AttachmentPart)
		if not bodyPart then
			warn(`[EmotePropUtils] Could not resolve attachment body part for prop: {propConfig.Name}`)
			propClone:Destroy()
			continue
		end

		local propPrimary: BasePart? = if propClone:IsA("Model")
			then (propClone.PrimaryPart or propClone:FindFirstChildOfClass("BasePart") :: BasePart?)
			else propClone :: BasePart

		if not propPrimary then
			warn(`[EmotePropUtils] Prop model has no primary part: {propConfig.Name}`)
			propClone:Destroy()
			continue
		end

		setupPropPhysicsAndWelds(propClone, propPrimary)

		local offset = propConfig.CFrameOffset or CFrame.new()
		if propClone:IsA("Model") then
			propClone:PivotTo(bodyPart.CFrame * offset)
		elseif propClone:IsA("BasePart") then
			propClone.CFrame = bodyPart.CFrame * offset
		end

		if propConfig.Motor6D then
			local motorName = propConfig.Motor6DName or `{propConfig.Name}Motor`
			local motor = Instance.new("Motor6D")
			motor.Name = motorName
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

