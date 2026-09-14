--/Services
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--/Modules
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)
local NumberUtils = require(ReplicatedStorage.Shared.Modules.Utils.NumberUtils)

--/Constants
local SURFACE_TOLERANCE = 0.01
local SURFACE_RAY_HEIGHT = 1
local SURFACE_RAY_OFFSET = Vector3.new(0, SURFACE_RAY_HEIGHT, 0)
local SURFACE_RAY_DIRECTION = Vector3.new(0, -(SURFACE_RAY_HEIGHT + SURFACE_TOLERANCE), 0)

local SURFACE_RAY_PARAMS = RaycastParams.new()
SURFACE_RAY_PARAMS.FilterType = Enum.RaycastFilterType.Exclude
SURFACE_RAY_PARAMS.CollisionGroup = "HoldingTowerMouse"
SURFACE_RAY_PARAMS.IgnoreWater = true
SURFACE_RAY_PARAMS.RespectCanCollide = false

--/Variables
local borderCache = {}

--/Types
export type requestData = {
	TowerName: string,
	SpawnPosition: Vector3,
	BorderRadius: number,
	CurrentCash: number?,
	CurrentCount: number,
	IgnoreId: any?,
	SurfaceHit: RaycastResult?,
}

-------------------------------------------------
--// Local Functions
-------------------------------------------------

local function isTowerAreaSurface(result: RaycastResult): boolean
	return result.Instance:IsA("BasePart")
		and CollectionService:HasTag(result.Instance, "TowerArea")
		and result.Normal.Y > 0
end

local function isPointOnTowerArea(point: Vector3)
	if
		typeof(point) ~= "Vector3"
		or not (math.abs(point.X) < math.huge and math.abs(point.Y) < math.huge and math.abs(point.Z) < math.huge)
	then
		return false
	end

	local result = workspace:Raycast(point + SURFACE_RAY_OFFSET, SURFACE_RAY_DIRECTION, SURFACE_RAY_PARAMS)
	if not result then
		return false
	end

	return isTowerAreaSurface(result) and (result.Position - point).Magnitude <= SURFACE_TOLERANCE
end

local function isBorderOverlap(currentPos, radius, ignoreId)
	for id, data in pairs(borderCache) do
		if id == ignoreId then
			continue
		end

		local distSq = (currentPos.X - data.x) ^ 2 + (currentPos.Z - data.z) ^ 2
		local radiusSum = (radius + data.r) ^ 2

		if distSq < radiusSum then
			return true
		end
	end
	return false
end

-------------------------------------------------
--// PlaceValidator
-------------------------------------------------
local PlaceValidator = {}

function PlaceValidator.CheckSpawn(data: requestData, isPlaceHolder: boolean?)
	if data.SurfaceHit and not isTowerAreaSurface(data.SurfaceHit) then
		return false, "You can't place here!"
	end

	if not isPointOnTowerArea(data.SpawnPosition) then
		return false, "You can't place here!"
	end

	if isBorderOverlap(data.SpawnPosition, data.BorderRadius, data.IgnoreId) then
		return false, "You can't place near towers!"
	end

	local towerInfo = TowerData.ByName[data.TowerName]
	if not towerInfo then
		return false, `[Game Error] Invalid tower "{data.TowerName}"!`
	end

	if not isPlaceHolder and data.CurrentCash < towerInfo.Stats[0].Cost then
		return false, `You don't enough {NumberUtils.FormatComma(towerInfo.Stats[0].Cost - data.CurrentCash)} cash!`
	end

	if data.CurrentCount >= towerInfo.MaxTowers then
		return false, `You can place only {towerInfo.MaxTowers} of this tower!`
	end

	return true
end

function PlaceValidator.AddBorder(id: any, borderData: { x: number, z: number, r: number })
	if not borderData.x or not borderData.z or not borderData.r then
		return
	end
	borderCache[id] = borderData
end

function PlaceValidator.RemoveBorder(id: any)
	borderCache[id] = nil
end

function PlaceValidator.ClearBorders()
	table.clear(borderCache)
end

return PlaceValidator
