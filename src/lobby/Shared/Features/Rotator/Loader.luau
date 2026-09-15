local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Components = require(ReplicatedStorage.Shared.Components)

local registered = {}
local addedConnection

local function registerRotator(world, target, degree, rotateX, rotateY, rotateZ)
	if registered[target] then
		return
	end
	registered[target] = true

	world:spawn(Components.Rotator({
		TargetPart = target,
		DegreePerSecond = degree or 0,
		X = rotateX,
		Y = rotateY,
		Z = rotateZ,
	}))
end

return function(world)
	if not addedConnection then
		addedConnection = CollectionService:GetInstanceAddedSignal("Rotator"):Connect(function(target)
			local degree = target:GetAttribute("Degree")
			local rotateX = target:GetAttribute("RotateX")
			local rotateY = target:GetAttribute("RotateY")
			local rotateZ = target:GetAttribute("RotateZ")
			registerRotator(world, target, degree, rotateX, rotateY, rotateZ)
		end)
	end

	for _, target in CollectionService:GetTagged("Rotator") do
		local degree = target:GetAttribute("Degree")
		local rotateX = target:GetAttribute("RotateX")
		local rotateY = target:GetAttribute("RotateY")
		local rotateZ = target:GetAttribute("RotateZ")
		registerRotator(world, target, degree, rotateX, rotateY, rotateZ)
	end
end
