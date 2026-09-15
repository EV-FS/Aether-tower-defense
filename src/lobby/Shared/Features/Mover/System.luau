--/Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

--/Modules
local Matter = require(ReplicatedStorage.Packages.Matter)
local Components = require(ReplicatedStorage.Shared.Components)

return function(world)
	local dt = Matter.useDeltaTime()
	local time = os.clock()

	for id, mover in world:query(Components.Mover) do
		local part = mover.TargetPart
		
		-- Smooth sine-based movement
		local newProgress = (math.sin(time * mover.Speed * 0.5) + 1) / 2
		
		-- Calculate Position (Lerp + Small sine bob)
		local basePosition = mover.StartPosition:Lerp(mover.EndPosition, newProgress)
		local bob = Vector3.new(0, math.sin(time * 2) * 0.5, 0)
		local newPosition = basePosition + bob
		
		-- Apply transformation
		if part:IsA("Model") then
			local pivot = part:GetPivot()
			part:PivotTo(CFrame.new(newPosition) * (pivot - pivot.Position))
		else
			part.CFrame = CFrame.new(newPosition) * (part.CFrame - part.CFrame.Position)
		end
	end
end
