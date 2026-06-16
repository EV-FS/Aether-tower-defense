--/Services
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--/Modules
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)
local NumberUtils = require(ReplicatedStorage.Shared.Modules.Utils.NumberUtils)

--/Constants
local OFFSET = 0.01

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
}

-------------------------------------------------
--// Local Functions
-------------------------------------------------

local function isPointInPart(point: Vector3, part: BasePart?)
	if not part then
		return false
	end

	local objectPoint = part.CFrame:PointToObjectSpace(point)
	local halfSize = part.Size / 2

	return math.abs(objectPoint.X) <= halfSize.X + OFFSET
		and math.abs(objectPoint.Y) <= halfSize.Y + OFFSET
		and math.abs(objectPoint.Z) <= halfSize.Z + OFFSET
end

local function isPointInTowerArea(point: Vector3)
	for _, taggedInstance in CollectionService:GetTagged("TowerArea") do
		if not taggedInstance:IsA("BasePart") then
			continue
		end

		if not taggedInstance:IsDescendantOf(workspace) then
			continue
		end

		if isPointInPart(point, taggedInstance) then
			return true
		end
	end
	return false
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
	if not isPointInTowerArea(data.SpawnPosition) then
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
