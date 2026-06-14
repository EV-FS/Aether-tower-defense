local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Components = require(ReplicatedStorage.Shared.Components)

local currentWorld

local function spawnNPCEntity(modelPath, radius)
	if not currentWorld then
		return
	end

	task.spawn(function()
		local model = modelPath
		local torso = model:WaitForChild("Torso", 10)
		if not torso then
			return
		end

		local neck = torso:WaitForChild("Neck")
		local head = model:WaitForChild("Head")
		local hrp = model:WaitForChild("HumanoidRootPart")
		local humanoid = model:FindFirstChildOfClass("Humanoid")

		currentWorld:spawn(Components.NPCRig({
			Model = model,
			HumanoidRootPart = hrp,
			Head = head,
			Neck = neck,
			BaseC0 = neck.C0,
			RigType = humanoid and humanoid.RigType or Enum.HumanoidRigType.R6,
			LookRadius = radius,
		}))
	end)
end

return function(world)
	currentWorld = world

	for _, npcModel in CollectionService:GetTagged("LookNPC") do
		spawnNPCEntity(npcModel, 30)
	end
end
