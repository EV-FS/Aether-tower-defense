-------------------------------------------------
--// EnemyRegistry
-------------------------------------------------
local EnemyRegistry = {}

local registry = {}
local currentEnemyId = 0

function EnemyRegistry.generateId(): number
	currentEnemyId += 1
	return currentEnemyId
end

function EnemyRegistry.add(enemy)
	if not enemy or not enemy.Id then
		return
	end
	registry[enemy.Id] = enemy
end

function EnemyRegistry.get(enemyId: number)
	return registry[enemyId]
end

function EnemyRegistry.getAll()
	return registry
end

function EnemyRegistry.remove(enemyId: number)
	registry[enemyId] = nil
end

return EnemyRegistry
