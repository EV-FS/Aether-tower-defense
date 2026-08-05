--/Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

--/Modules
local Matter = require(ReplicatedStorage.Packages.Matter)
local Components = require(ReplicatedStorage.Shared.Components)

--/Constants
local MAX_DISTANCE = 150
local MAX_DISTANCE_SQ = MAX_DISTANCE * MAX_DISTANCE

-- 실제 CFrame 적용 빈도
local UPDATE_RATE = 1 / 45

-- 새로운 흔들림 목표를 계산하는 빈도
local COMPUTE_RATE = 1 / 30

local WIND_DIRECTION = Vector3.new(0.7, 0, 0.4).Unit
local WIND_SPEED = 20
local WIND_POWER = 0.5

-- 목표 CFrame을 따라가는 속도
local FOLLOW_SPEED = 8

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

	-- 런타임 중 PivotOffset이 바뀔 가능성이 있다면 계속 읽어도 됨.
	state.PivotOffset = part.PivotOffset
	state.SwayMultiplier = part:GetAttribute("SwayMultiplier") or DEFAULT_SWAY_MULTIPLIER

	local origin = state.Origin
	local pivotOffset = state.PivotOffset
	local seed = state.Seed
	local multiplier = state.SwayMultiplier

	local frequency = elapsedTime * (WIND_SPEED * 0.08)
	local amplitude = WIND_POWER * 0.1 * multiplier

	-- 서로 다른 noise 좌표를 사용해서 축별 움직임이 겹치지 않게 함.
	local rotationX = math.noise(frequency, seed, 0) * amplitude
	local rotationY = math.noise(frequency, 0, seed) * amplitude * 0.35
	local rotationZ = math.noise(frequency, seed, seed) * amplitude

	-- 바람 방향으로 약간 밀리는 움직임
	local windNoise = 0.5 + math.noise(frequency * 0.7, seed, -seed)
	local windOffset = WIND_DIRECTION * windNoise * amplitude

	-- PivotOffset을 기준으로 회전한 뒤 다시 파트 CFrame으로 변환
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

	-- 프레임률이 내려가도 과도하게 보간되지 않도록 제한
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
