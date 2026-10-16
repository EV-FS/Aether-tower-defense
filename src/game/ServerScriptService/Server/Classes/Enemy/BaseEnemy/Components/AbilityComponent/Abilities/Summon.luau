local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local EnemyService
local TimeService

local Summon = {}
Summon.__index = Summon

function Summon.new(enemy, config, fireTriggered)
	local self = setmetatable({}, Summon)
	self.Enemy = enemy
	self.Config = config
	self.FireTriggered = fireTriggered
	self.RemainingCount = 0
	self.IsDestroyed = false

	return self
end

function Summon:Start()
	EnemyService = EnemyService or ServiceRegistry:GetService("EnemyService")
	TimeService = TimeService or ServiceRegistry:GetService("TimeService")

	self.NextSummonAt = TimeService:Now() + (self.Config.Cooldown or 5)
end

function Summon:Update(now: number, gameDt: number)
	if self.IsDestroyed or self.Enemy.IsDead or self.Enemy.IsDestroyed or gameDt <= 0 then
		return
	end

	if self.RemainingCount <= 0 then
		if now < self.NextSummonAt then
			return
		end

		self.RemainingCount = self.Config.Count or 1
		self.NextSummonAt = now + (self.Config.Cooldown or 5)
		self.NextSpawnAt = now
		self.FireTriggered(self.Config.Type, {
			EnemyName = self.Config.EnemyName,
			Count = self.RemainingCount,
		})
	end

	while self.RemainingCount > 0 and now >= self.NextSpawnAt do
		if self.IsDestroyed or self.Enemy.IsDead or self.Enemy.IsDestroyed then
			return
		end

		self.RemainingCount -= 1
		self.NextSpawnAt = now + (self.Config.Spacing or 0)
		EnemyService.SetupNewEnemy(self.Config.EnemyName, false, self.Enemy.PathAlpha, self.Enemy.PathId)
	end
end

function Summon:Destroy()
	self.IsDestroyed = true
	self.RemainingCount = 0
end

return Summon
