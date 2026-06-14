local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Matter = require(ReplicatedStorage.Packages.Matter)
local Components = require(ReplicatedStorage.Shared.Components)
local LocalPlayer = Players.LocalPlayer

return function(world)
	local dt = Matter.useDeltaTime()

	local char = LocalPlayer.Character
	local playerHRP = char and char:FindFirstChild("HumanoidRootPart")
	local playerHead = char and char:FindFirstChild("Head")

	for _, npcRig in world:query(Components.NPCRig) do
		if not npcRig.Neck or not npcRig.Head or not npcRig.HumanoidRootPart then
			continue
		end

		local torso = npcRig.Neck.Parent
		if not torso then
			continue
		end

		local targetPos = nil
		local radius = npcRig.LookRadius or 20

		if playerHRP and playerHead then
			local dist = (playerHRP.Position - npcRig.HumanoidRootPart.Position).Magnitude
			if dist <= radius then
				targetPos = playerHead.Position
			end
		end

		if targetPos then
			local direction = targetPos - npcRig.Head.Position
			local localDir = torso.CFrame:VectorToObjectSpace(direction)

			local yaw = -math.atan2(localDir.X, -localDir.Z)
			local pitch = math.asin(localDir.Y / localDir.Magnitude)

			yaw = math.clamp(yaw, -math.rad(65), math.rad(65))
			pitch = math.clamp(pitch, -math.rad(30), math.rad(30))

			local targetCFrame
			if npcRig.RigType == Enum.HumanoidRigType.R6 then
				targetCFrame = npcRig.BaseC0 * CFrame.Angles(-pitch, 0, yaw)
			else
				targetCFrame = npcRig.BaseC0 * CFrame.Angles(pitch, yaw, 0)
			end

			npcRig.Neck.C0 = npcRig.Neck.C0:Lerp(targetCFrame, dt * 10)
		else
			npcRig.Neck.C0 = npcRig.Neck.C0:Lerp(npcRig.BaseC0, dt * 5)
		end
	end
end
