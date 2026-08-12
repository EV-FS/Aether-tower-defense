--/Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

--/Modules
local Matter = require(ReplicatedStorage.Packages.Matter)
local Components = require(ReplicatedStorage.Shared.Components)

--/Constants
local MAX_DISTANCE = 150
local MAX_DISTANCE_SQ = MAX_DISTANCE * MAX_DISTANCE

local UPDATE_RATE = 1 / 45

local COMPUTE_RATE = 1 / 30

local WIND_DIRECTION = Vector3.new(0.7, 0, 0.4).Unit
local WIND_SPEED = 20
local WIND_POWER = 0.5

local FOLLOW_SPEED = 16

local DEFAULT_SWAY_MULTIPLIER = 1

--/Variables
local updateAccumulator = 0
local computeAccumulator = 0
local elapsedTime = 0

local partsToMove = {}
local cframesToMove = {}

type LeafState = {
	Part: BasePart,

	Origin: CFrame,
	PivotOffset: CFrame,

	Current: CFrame,
	Target: CFrame,

	Seed: number,
	SwayMultiplier: number,

	LastSeenFrame: number,
}

local states: { [number]: LeafState } = {}
local frameId = 0

-------------------------------------------------
--// Local Functions
-------------------------------------------------

local function createLeafState(part: BasePart): LeafState
	local origin = part.CFrame

	return {
		Part = part,

		Origin = origin,
		PivotOffset = part.PivotOffset,

		Current = origin,
		Target = origin,

		Seed = math.random() * 1000,
		SwayMultiplier = part:GetAttribute("SwayMultiplier") or DEFAULT_SWAY_MULTIPLIER,

		LastSeenFrame = frameId,
	}
end

local function computeTarget(state: LeafState)
	local part = state.Part

	state.PivotOffset = part.PivotOffset
	state.SwayMultiplier = part:GetAttribute("SwayMultiplier") or DEFAULT_SWAY_MULTIPLIER

	local origin = state.Origin
	local pivotOffset = state.PivotOffset
	local seed = state.Seed
	local multiplier = state.SwayMultiplier

	local frequency = elapsedTime * (WIND_SPEED * 0.08)
	local amplitude = WIND_POWER * 0.1 * multiplier

	local rotationX = math.noise(frequency, seed, 0) * amplitude
	local rotationY = math.noise(frequency, 0, seed) * amplitude * 0.35
	local rotationZ = math.noise(frequency, seed, seed) * amplitude

	local windNoise = 0.5 + math.noise(frequency * 0.7, seed, -seed)
	local windOffset = WIND_DIRECTION * windNoise * amplitude

	local worldPivot = origin * pivotOffset

	state.Target = (worldPivot * CFrame.Angles(rotationX, rotationY, rotationZ) + windOffset) * pivotOffset:Inverse()
end

local function cleanupUnusedStates()
	for id, state in states do
		if state.LastSeenFrame ~= frameId then
			states[id] = nil
		end
	end
end

-------------------------------------------------
--// System
-------------------------------------------------

return function(world)
	local dt = Matter.useDeltaTime()

	elapsedTime += dt
	updateAccumulator += dt
	computeAccumulator += dt

	if updateAccumulator < UPDATE_RATE then
		return
	end

	local updateDt = updateAccumulator
	updateAccumulator %= UPDATE_RATE

	local shouldCompute = computeAccumulator >= COMPUTE_RATE

	if shouldCompute then
		computeAccumulator %= COMPUTE_RATE
	end

	frameId += 1

	local camera = Workspace.CurrentCamera
	local cameraPosition = camera and camera.CFrame.Position

	local followAlpha = math.min(1, updateDt * FOLLOW_SPEED)

	for id, leaf in world:query(Components.Leaf) do
		local part = leaf.LeafModel

		if not part or not part:IsA("BasePart") or not part.Parent then
			states[id] = nil
			continue
		end

		local state = states[id]

		if not state or state.Part ~= part then
			state = createLeafState(part)
			states[id] = state
		end

		state.LastSeenFrame = frameId

		local originPosition = state.Origin.Position

		if cameraPosition then
			local offset = originPosition - cameraPosition
			local distanceSq = offset:Dot(offset)

			if distanceSq > MAX_DISTANCE_SQ then
				continue
			end
		end

		if shouldCompute then
			computeTarget(state)
		end

		state.Current = state.Current:Lerp(state.Target, followAlpha)

		table.insert(partsToMove, part)
		table.insert(cframesToMove, state.Current)
	end

	cleanupUnusedStates()

	if #partsToMove > 0 then
		Workspace:BulkMoveTo(partsToMove, cframesToMove, Enum.BulkMoveMode.FireCFrameChanged)

		table.clear(partsToMove)
		table.clear(cframesToMove)
	end
end
