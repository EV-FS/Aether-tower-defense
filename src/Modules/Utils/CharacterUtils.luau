local Players = game:GetService("Players")

local CharacterUtils = {}
CharacterUtils.HipHeight = {}

function CharacterUtils.GetHipHeight(character: Model): number
	if CharacterUtils.HipHeight[character] then
		return CharacterUtils.HipHeight[character]
	end

	local hipHeight = tonumber(character:GetAttribute("HipHeight"))
	if hipHeight then
		CharacterUtils.HipHeight[character] = hipHeight
		return hipHeight
	end

	local leftLeg = character:FindFirstChild("Left Leg")
	local primaryPart = character.PrimaryPart

	if not (leftLeg and primaryPart) then
		local humanoid = character:FindFirstChild("Humanoid")

		CharacterUtils.HipHeight[character] = humanoid.HipHeight or 2
		return humanoid.HipHeight or 2
	end

	CharacterUtils.HipHeight[character] = leftLeg.Size.Y + (primaryPart.Size.Y / 2)
	return leftLeg.Size.Y + (primaryPart.Size.Y / 2)
end

function CharacterUtils.LoadAvatar(rig: Model, user: number | string): boolean
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		warn("Rig에 Humanoid가 없음!")
		return false
	end

	local userId = nil
	if typeof(user) == "number" then
		userId = user
	else
		local success, id = pcall(function()
			return Players:GetUserIdFromNameAsync(user)
		end)
		if success then
			userId = id
		end
	end

	if not userId then
		warn("유효하지 않은 유저: " .. tostring(user))
		return false
	end

	local success, description = pcall(function()
		return Players:GetHumanoidDescriptionFromUserIdAsync(userId)
	end)

	if success and description then
		humanoid:ApplyDescriptionAsync(description)
		return true
	else
		warn("아바타 로드 실패 - UserID: " .. tostring(userId))
		return false
	end
end

function CharacterUtils.SetCollisionGroup(targetInstance: Instance, groupName: string, onApply: (part: BasePart) -> ()?)
	for _, object in targetInstance:GetDescendants() do
		if object:IsA("BasePart") then
			object.CollisionGroup = groupName

			if onApply then
				onApply(object)
			end
		end
	end

	targetInstance.DescendantAdded:Connect(function(part)
		if part:IsA("BasePart") then
			part.CollisionGroup = groupName

			if onApply then
				onApply(part)
			end
		end
	end)
end

return CharacterUtils
