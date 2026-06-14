--/Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

--/Modules
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local UnitService
local TimeService

-------------------------------------------------
--// SummonComponent
-------------------------------------------------
local SummonComponent = {}
SummonComponent.__index = SummonComponent

function SummonComponent.new(tower, stats)
	local self = setmetatable({}, SummonComponent)
	self.Tower = tower
	self.Stats = stats
	self.IsSummoning = false
	self._summonToken = 0

	self.CooldownTimer = self:_GetCooldown()

	return self
end

function SummonComponent:SetStats(stats)
	self.Stats = stats
end

function SummonComponent:Start()
	TimeService = TimeService or ServiceRegistry:GetService("TimeService")

	self.HeartbeatConnection = RunService.Heartbeat:Connect(function(dt)
		self.CooldownTimer -= dt * TimeService:GetGameSpeed()

		if self.CooldownTimer > 0 or self.IsSummoning then
			return
		end

		if self:_Summon() then
			self.CooldownTimer += self:_GetCooldown()
		else
			self.CooldownTimer = 0
		end
	end)
end

function SummonComponent:Destroy()
	self._summonToken += 1
	self.IsSummoning = false

	if self.HeartbeatConnection then
		self.HeartbeatConnection:Disconnect()
		self.HeartbeatConnection = nil
	end
end

function SummonComponent:_GetCooldown(): number
	local stats = self.Stats or self.Tower.Stats
	return stats.SummonCooldown or stats.Cooldown or 1
end

function SummonComponent:_Summon(): boolean
	local stats = self.Stats or self.Tower.Stats
	local unitName = stats.SummonUnit
	if not unitName then
		return false
	end

	local summonCount = stats.SummonCount or 1
	local summonDelay = stats.SummonDelay or 0
	local summonToken = self._summonToken

	self.IsSummoning = true

	task.spawn(function()
		for _ = 1, summonCount do
			if summonDelay > 0 then
				TimeService = TimeService or ServiceRegistry:GetService("TimeService")
				TimeService.DeltaWait(summonDelay)
			end

			if summonToken ~= self._summonToken or not self.Tower or self.Tower.IsDestroyed then
				break
			end

			UnitService = UnitService or ServiceRegistry:GetService("UnitService")
			UnitService.Spawn(self.Tower, unitName, nil, nil, stats.UnitStats)
		end

		if summonToken == self._summonToken then
			self.IsSummoning = false
		end
	end)

	return true
end

return SummonComponent
