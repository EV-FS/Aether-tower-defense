-------------------------------------------------
--// UnitRegistry
-------------------------------------------------
local UnitRegistry = {}

local registry = {}
local currentUnitId = 0

function UnitRegistry.generateId(): number
	currentUnitId += 1
	return currentUnitId
end

function UnitRegistry.add(unit)
	if not unit or not unit.Id then
		return
	end
	registry[unit.Id] = unit
end

function UnitRegistry.get(unitId: number)
	return registry[unitId]
end

function UnitRegistry.getAll()
	return registry
end

function UnitRegistry.remove(unitId: number)
	registry[unitId] = nil
end

return UnitRegistry
