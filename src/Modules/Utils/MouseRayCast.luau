local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Input = require(ReplicatedStorage.Packages.Input)

local MAX_DISTANCE = 1000
local RAYCAST_PARAMS = RaycastParams.new()
RAYCAST_PARAMS.FilterType = Enum.RaycastFilterType.Exclude
RAYCAST_PARAMS.IgnoreWater = true

return function(isHolding: boolean?): RaycastResult
	if isHolding then
		RAYCAST_PARAMS.CollisionGroup = "HoldingTowerMouse"
	else
		RAYCAST_PARAMS.CollisionGroup = "Mouse"
	end

	local result = Input.Mouse:Raycast(RAYCAST_PARAMS, MAX_DISTANCE)

	return result
end
