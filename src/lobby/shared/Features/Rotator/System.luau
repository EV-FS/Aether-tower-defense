--/Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

--/Modules
local Matter = require(ReplicatedStorage.Packages.Matter)
local Components = require(ReplicatedStorage.Shared.Components)

--/Constants
local CAMERA = Workspace.CurrentCamera

local MAX_DISTANCE = 2 ^ 24

local UPDATE_RATE = 1 / 40 --40 fps

--/Variables
local accumulator = 0

local cframeToMove = {}
local partsToMove = {}

return function(world)
	local dt = Matter.useDeltaTime()
	accumulator += dt

	if accumulator < UPDATE_RATE then
		return
	end

	accumulator %= UPDATE_RATE

	for _, rotator in world:query(Components.Rotator) do
		local part = rotator.TargetPart
		local degree = rotator.DegreePerSecond
		local cameraPosition = CAMERA and CAMERA.CFrame.Position

		if cameraPosition then
			local targetPosition = if part:IsA("Model") then part:GetPivot().Position else part.Position
			local offset = targetPosition - cameraPosition
			local distance = offset.Magnitude

			if distance > MAX_DISTANCE then
				continue
			end
		end

		if part:IsA("Model") then
			part:PivotTo(part:GetPivot()
				* CFrame.Angles(
					if rotator.X then math.rad(degree * dt) else 0,
					if rotator.Y then math.rad(degree * dt) else 0,
					if rotator.Z then math.rad(degree * dt) else 0
				)
			)
		else
			local cframe = part.CFrame
				* CFrame.Angles(
					if rotator.X then math.rad(degree * dt) else 0,
					if rotator.Y then math.rad(degree * dt) else 0,
					if rotator.Z then math.rad(degree * dt) else 0
				)

			table.insert(partsToMove, part)
			table.insert(cframeToMove, cframe)
		end
	end

	if #partsToMove > 0 then
		Workspace:BulkMoveTo(partsToMove, cframeToMove, Enum.BulkMoveMode.FireCFrameChanged)
		table.clear(partsToMove)
		table.clear(cframeToMove)
	end
end
