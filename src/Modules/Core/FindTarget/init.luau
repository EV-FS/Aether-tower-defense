--/Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--/Modules
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)
local EnemyService
-------------------------------------------------
--// TargetModes
-------------------------------------------------
local Closest = require(script.Mode.Closest)
local Farthest = require(script.Mode.Farthest)
local First = require(script.Mode.First)
local Last = require(script.Mode.Last)
local Strongest = require(script.Mode.Strongest)
local Weakest = require(script.Mode.Weakest)
local ServiceRegistry = require(script.Parent.ServiceRegistry)

local TargetModes = {
	["First"] = First,
	["Last"] = Last,
	["Strongest"] = Strongest,
	["Weakest"] = Weakest,
	["Closest"] = Closest,
	["Farthest"] = Farthest,
	Random = function(enemies)
		local count = TableUtils.Length(enemies)

		if next(enemies) then
			return enemies[Random.new():NextInteger(1, count)]
		else
			return nil
		end
	end,
}

-------------------------------------------------
--// FindTarget
-------------------------------------------------
local FindTarget = {}

function FindTarget.GetEnemiesInRange(self, range: number?)
	EnemyService = EnemyService or ServiceRegistry:GetService("EnemyService")

	local rangeLimit = range or self.Stats.Range

	local potentialEnemies = EnemyService.EnemyGrid:GetEntitiesInRange(self.Position, rangeLimit)

	local enemiesInRange = {}
	for _, enemy in potentialEnemies do
		if enemy.IsDead then
			continue
		end
		table.insert(enemiesInRange, enemy)
	end

	return enemiesInRange
end

function FindTarget.GetTarget(self, range: number?)
	local findFunction = TargetModes[self.TargetMode]
	if not findFunction then
		return nil
	end

	local enemies = FindTarget.GetEnemiesInRange(self, range)
	if self.TargetMode == "Random" then
		return findFunction(enemies)
	end

	local bestEnemy = nil
	for _, enemy in pairs(enemies) do
		if not bestEnemy or findFunction(self, bestEnemy, enemy) then
			bestEnemy = enemy
		end
	end

	return bestEnemy
end

function FindTarget.GetTargetInSplash(stats, targetPosition: Vector3)
	EnemyService = EnemyService or ServiceRegistry:GetService("EnemyService")
	local potentialEnemies = EnemyService.EnemyGrid:GetEntitiesInRange(targetPosition, stats.SplashRange)

	local enemiesInAOE = {}
	for _, enemy in potentialEnemies do
		if enemy.IsDead then
			continue
		end
		table.insert(enemiesInAOE, enemy)
	end

	return enemiesInAOE
end

function FindTarget.GetTargetInAngle(self, stats, startPosition: Vector3, targetPosition: Vector3)
	local enemiesInAngle = {}

	local flatTarget = Vector3.new(targetPosition.X, 0, targetPosition.Z)
	local flatStart = Vector3.new(startPosition.X, 0, startPosition.Z)
	local directionToMainTarget = (flatTarget - flatStart).Unit

	local cosAngle = math.cos(math.rad(stats.Angle / 2))

	for _, enemy in pairs(FindTarget.GetEnemiesInRange(self)) do
		if enemy.IsDead then
			continue
		end

		local directionToEnemy = (Vector3.new(enemy.Position.X, 0, enemy.Position.Z) - flatStart).Unit
		local enemyDot = directionToMainTarget:Dot(directionToEnemy)

		if enemyDot >= cosAngle then
			table.insert(enemiesInAngle, enemy)
		end
	end

	return enemiesInAngle
end

function FindTarget.GetTargetInLine(self, stats, targetPosition: Vector3)
	local enemiesInLine = {}

	local originPos = self.Position
	local targetPos = targetPosition

	local flatTargetPos = Vector3.new(targetPos.X, originPos.Y, targetPos.Z)
	local beamCFrame = CFrame.lookAt(originPos, flatTargetPos)

	for _, enemy in pairs(FindTarget.GetEnemiesInRange(self)) do
		if enemy.IsDead then
			continue
		end

		local localPos = beamCFrame:PointToObjectSpace(enemy.Position)

		if localPos.Z < 0 and math.abs(localPos.X) <= stats.Width / 2 then
			table.insert(enemiesInLine, enemy)
		end
	end

	return enemiesInLine
end

return FindTarget
