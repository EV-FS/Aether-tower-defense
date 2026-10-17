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
	self.IsExecuting = false
	self.IsDestroyed = false

	return self
end

function Summon:Start()
	EnemyService = EnemyService or ServiceRegistry:GetService("EnemyService")
	TimeService = TimeService or ServiceRegistry:GetService("TimeService")

	self.NextSummonAt = TimeService:Now() + (self.Config.Cooldown or 5)
end

function Summon:Execute(now: number)
	self.RemainingCount = self.Config.Count or 1
	self.NextSummonAt = now + (self.Config.Cooldown or 5)
	self.FireTriggered(self.Config.Type, {
		EnemyName = self.Config.EnemyName,
		Count = self.RemainingCount,
	})

	local spacing = self.Config.Spacing or 0
	local summmonDelay = self.Config.Delay or 0
	if spacing > 0 then
		self.Enemy:ApplyDebuff("Slow", spacing * self.RemainingCount + summmonDelay, 99)
	end

	if summmonDelay > 0 then
		TimeService.DeltaWait(summmonDelay)
	end

	while self.RemainingCount > 0 do
		if self.IsDestroyed or self.Enemy.IsDead or self.Enemy.IsDestroyed then
			break
		end

		self.RemainingCount -= 1
		EnemyService.SetupNewEnemy(self.Config.EnemyName, false, self.Enemy.PathAlpha, self.Enemy.PathId)
		if self.RemainingCount > 0 and spacing > 0 then
			TimeService.DeltaWait(spacing)
		end
	end
	self.RemainingCount = 0
	self.IsExecuting = false
end

function Summon:Update(now: number, gameDt: number)
	if self.IsDestroyed or self.Enemy.IsDead or self.Enemy.IsDestroyed or gameDt <= 0 then
		return
	end

	if self.IsExecuting or now < self.NextSummonAt then
		return
	end

	self.IsExecuting = true
	task.spawn(self.Execute, self, now)
end

function Summon:Destroy()
	self.IsDestroyed = true
	self.RemainingCount = 0
	self.IsExecuting = false
end

return Summon
