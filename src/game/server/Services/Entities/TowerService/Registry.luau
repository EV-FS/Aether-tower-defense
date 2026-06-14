-------------------------------------------------
--// TowerRegistry
-------------------------------------------------
local TowerRegistry = {}

local registry = {}
local currentTowerId = 0

function TowerRegistry.generateId(): number
	currentTowerId += 1
	return currentTowerId
end

function TowerRegistry.add(tower)
	if not tower or not tower.Id then
		return
	end
	registry[tower.Id] = tower
end

function TowerRegistry.get(towerId: number)
	return registry[towerId]
end

function TowerRegistry.getAll()
	return registry
end

function TowerRegistry.remove(towerId: number)
	registry[towerId] = nil
end

return TowerRegistry
