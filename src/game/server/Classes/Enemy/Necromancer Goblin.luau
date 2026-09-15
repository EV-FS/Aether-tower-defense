local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local BaseEnemy = require(script.Parent.BaseEnemy)
local EnemyService
local TimeService

local NecromancerGoblin = setmetatable({}, BaseEnemy)
NecromancerGoblin.__index = NecromancerGoblin

function NecromancerGoblin.new(id: number, name: string, isBoss: boolean?, pathId: number?, pathAlpha: number?)
	local self = BaseEnemy.new(id, name, isBoss, pathId, pathAlpha)
	setmetatable(self, NecromancerGoblin)

	local EnemyData = require(ReplicatedStorage.Settings.Data.EnemyData)

	self.Stats = EnemyData.ByName[name]
	self._LastSummonTime = os.clock()

	self.SummonCooldown = (self.Stats and self.Stats.SummonCooldown) or 5
	self.SummonCount = (self.Stats and self.Stats.SummonCount) or 3
	self.MinionName = (self.Stats and self.Stats.MinionName) or "Goblin"

	self._SummonConnection = RunService.Heartbeat:Connect(function()
		if self.IsDead or self.IsDestroyed then
			self:_StopSummoning()
			return
		end

		if os.clock() - self._LastSummonTime >= self.SummonCooldown then
			self._LastSummonTime = os.clock()
			self:Summon()
		end
	end)

	return self
end

function NecromancerGoblin:Summon()
	EnemyService = EnemyService or ServiceRegistry:GetService("EnemyService")
	TimeService = TimeService or ServiceRegistry:GetService("TimeService")

	task.spawn(function()
		for _ = 1, self.SummonCount do
			if self.IsDead or self.IsDestroyed then
				break
			end

			EnemyService.SetupNewEnemy(self.MinionName, false, self.PathAlpha, self.PathId)
			TimeService.DeltaWait(0.4)
		end
	end)
end

function NecromancerGoblin:_StopSummoning()
	if self._summonConnection then
		self._summonConnection:Disconnect()
		self._summonConnection = nil
	end
end

function NecromancerGoblin:Destroy(forcing: boolean?)
	self:_StopSummoning()
	BaseEnemy.Destroy(self, forcing)
end

return NecromancerGoblin
