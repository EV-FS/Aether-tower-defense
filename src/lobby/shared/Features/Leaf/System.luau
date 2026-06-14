--/Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

--/Modules
local Matter = require(ReplicatedStorage.Packages.Matter)
local Components = require(ReplicatedStorage.Shared.Components)

--/Constants
local CAMERA = Workspace.CurrentCamera

local MAX_DISTANCE = 150
local MAX_DISTANCE_SQ = MAX_DISTANCE * MAX_DISTANCE

local SPEED = 3
local Y_OFFSET = -0.1
local X_SWAY = 1 / 3
local Z_SWAY = 1 / 4

local UPDATE_RATE = 1 / 30

--/Variables
local time = 0
local accumulator = 0

local cframeToMove = {}
local partsToMove = {}

return function(world)
	local dt = Matter.useDeltaTime()
	time += dt * SPEED
	accumulator += dt

	if accumulator < UPDATE_RATE then
		return
	end

	accumulator %= UPDATE_RATE

	for id, leaf in world:query(Components.Leaf) do
		local part = leaf.LeafModel

		local baseCFrame = leaf.BaseCFrame
		local basePosition = leaf.BasePosition
		local cameraPosition = CAMERA and CAMERA.CFrame.Position
		local halfHeight = leaf.HalfHeight
		local timeOffset = leaf.TimeOffset
		local swayMultiplier = leaf.SwayMultiplier

		if not baseCFrame then
			baseCFrame = part.CFrame
			basePosition = part.Position + Vector3.new(0, Y_OFFSET, 0)
			halfHeight = part.Size.Y / 2
			timeOffset = math.random() * 100
			swayMultiplier = part:GetAttribute("SwayMultiplier") or 1

			world:insert(
				id,
				leaf:patch({
					BaseCFrame = baseCFrame,
					BasePosition = basePosition,
					HalfHeight = halfHeight,
					TimeOffset = timeOffset,
					SwayMultiplier = swayMultiplier,
				})
			)
		end

		if cameraPosition then
			local offset = basePosition - cameraPosition
			local distanceSq = offset.X * offset.X + offset.Y * offset.Y + offset.Z * offset.Z

			if distanceSq > MAX_DISTANCE_SQ then
				continue
			end
		end

		local waveTime = time + timeOffset

		local xOffset = math.sin(waveTime + basePosition.X / 5) * math.sin(waveTime / 9) * X_SWAY * swayMultiplier
		local zOffset = math.sin(waveTime + basePosition.Z / 6) * math.sin(waveTime / 12) * Z_SWAY * swayMultiplier

		local tiltX = zOffset / halfHeight
		local tiltZ = -xOffset / halfHeight

		local moveOffset = Vector3.new(xOffset, 0, zOffset)

		local cframe = CFrame.new(basePosition + moveOffset) * baseCFrame.Rotation * CFrame.Angles(tiltX, 0, tiltZ)

		table.insert(partsToMove, part)
		table.insert(cframeToMove, cframe)
	end

	if #partsToMove > 0 then
		Workspace:BulkMoveTo(partsToMove, cframeToMove, Enum.BulkMoveMode.FireCFrameChanged)
		table.clear(partsToMove)
		table.clear(cframeToMove)
	end
end
