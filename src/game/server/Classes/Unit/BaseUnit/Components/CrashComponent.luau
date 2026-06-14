--/Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

--/Modules
local EnemyService
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)

--/Constants
local DEFAULT_CRASH_RANGE = 2.5

-------------------------------------------------
--// CrashComponent
-------------------------------------------------
local CrashComponent = {}
CrashComponent.__index = CrashComponent

function CrashComponent.new(unit)
	local self = setmetatable({}, CrashComponent)
	self.Unit = unit

	return self
end

function CrashComponent:Start()
	self.HeartbeatConnection = RunService.Heartbeat:Connect(function()
		self:_Crash()
	end)
end

function CrashComponent:Destroy()
	if self.HeartbeatConnection then
		self.HeartbeatConnection:Disconnect()
		self.HeartbeatConnection = nil
	end
end

function CrashComponent:_Crash()
	local unit = self.Unit
	if not unit or unit.IsDestroyed or unit.IsDead then
		return
	end

	local targetEnemy = self:_FindCrashTarget()
	if not targetEnemy then
		return
	end

	local unitHealth = unit.Health
	local enemyHealth = targetEnemy.Health

	local _, isKilled = targetEnemy:TakeDamage(unitHealth)
	if isKilled then
		self.Unit.Summoner:GetEvent("Killed"):Fire(targetEnemy)
	end

	unit:TakeDamage(enemyHealth)
end

function CrashComponent:_FindCrashTarget()
	EnemyService = EnemyService or ServiceRegistry:GetService("EnemyService")

	local unit = self.Unit
	local crashRange = (unit.Stats and unit.Stats.CrashRange) or unit.CrashRange or DEFAULT_CRASH_RANGE
	local unitPosition = unit.Position

	local closestEnemy = nil
	local closestDistance = math.huge

	local potentialEnemies = EnemyService.EnemyGrid:GetEntitiesInRange(unitPosition, crashRange)

	for _, enemy in potentialEnemies do
		if enemy.IsDead or enemy.IsDestroyed then
			continue
		end

		local offset = enemy.Position - unitPosition
		local distance = offset.X ^ 2 + offset.Z ^ 2

		if distance < closestDistance then
			closestEnemy = enemy
			closestDistance = distance
		end
	end

	return closestEnemy
end

return CrashComponent
