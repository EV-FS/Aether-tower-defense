--/Types
export type newHashGrid = {
	CellSize: number,
	Grid: {},
	EntityCells: {},

	Update: (entity: any, position: Vector3) -> nil,
	Remove: (entity: any) -> nil,
	GetEntitiesInRange: (position: Vector3, range: number) -> { any },
	Clear: () -> nil,
}

export type SpatialHashGrid = {
	new: (cellSize: number) -> newHashGrid,
	Update: (self: newHashGrid, entity: any, position: Vector3) -> nil,
	Remove: (self: newHashGrid, entity: any) -> nil,
	GetEntitiesInRange: (self: newHashGrid, position: Vector3, range: number) -> { any },
	Clear: (self: newHashGrid) -> nil,
}

-------------------------------------------------
--// Local Functions
-------------------------------------------------
local function GetCellKey(x: number, z: number, cellSize: number)
	local cx = math.floor(x / cellSize)
	local cz = math.floor(z / cellSize)
	return cx .. "," .. cz
end

-------------------------------------------------
--// SpaitalHashGrid
-------------------------------------------------
local SpatialHashGrid = {} :: SpatialHashGrid
SpatialHashGrid.__index = SpatialHashGrid

function SpatialHashGrid.new(cellSize: number)
	local self = setmetatable({}, SpatialHashGrid)
	self.CellSize = cellSize
	self.Grid = {}
	self.EntityCells = {}
	return self
end

function SpatialHashGrid:Update(entity, position: Vector3)
	local newKey = GetCellKey(position.X, position.Z, self.CellSize)
	local oldKey = self.EntityCells[entity]

	if oldKey == newKey then
		return
	end

	if oldKey then
		local cell = self.Grid[oldKey]
		if cell then
			cell[entity] = nil
			if next(cell) == nil then
				self.Grid[oldKey] = nil
			end
		end
	end

	if not self.Grid[newKey] then
		self.Grid[newKey] = {}
	end
	self.Grid[newKey][entity] = true
	self.EntityCells[entity] = newKey
end

function SpatialHashGrid:Remove(entity)
	local oldKey = self.EntityCells[entity]
	if oldKey then
		local cell = self.Grid[oldKey]
		if cell then
			cell[entity] = nil
			if next(cell) == nil then
				self.Grid[oldKey] = nil
			end
		end
		self.EntityCells[entity] = nil
	end
end

function SpatialHashGrid:GetEntitiesInRange(position: Vector3, range: number)
	local entities = {}
	local cellSize = self.CellSize

	local minX = math.floor((position.X - range) / cellSize)
	local maxX = math.floor((position.X + range) / cellSize)
	local minZ = math.floor((position.Z - range) / cellSize)
	local maxZ = math.floor((position.Z + range) / cellSize)

	local rangeSq = range ^ 2

	for cx = minX, maxX do
		for cz = minZ, maxZ do
			local cellKey = cx .. "," .. cz
			local cell = self.Grid[cellKey]
			if cell then
				for entity in pairs(cell) do
					local entityPos = entity.Position
					if entityPos then
						local dx = entityPos.X - position.X
						local dz = entityPos.Z - position.Z
						if dx ^ 2 + dz ^ 2 <= rangeSq then
							table.insert(entities, entity)
						end
					end
				end
			end
		end
	end

	return entities
end

function SpatialHashGrid:Clear()
	table.clear(self.Grid)
	table.clear(self.EntityCells)
end

return SpatialHashGrid
