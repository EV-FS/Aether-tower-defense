local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local TimeService

local HeavenlyGrace = {}
HeavenlyGrace.__index = HeavenlyGrace

local function isNonNegativeNumber(value)
	return type(value) == "number" and value == value and value >= 0 and value < math.huge
end

function HeavenlyGrace.new(tower, config, fireTriggered)
	local self = setmetatable({}, HeavenlyGrace)
	self.Tower = tower
	self.Config = config
	self.Name = config.Name
	self.FireTriggered = fireTriggered
	self.ReadyAt = 0
	self.IsDestroyed = false
	self._useId = 0

	return self
end

function HeavenlyGrace:SetStats(config)
	self.Config = config
end

function HeavenlyGrace:Validate(): boolean
	return not self.IsDestroyed
		and not self.Tower.IsDestroyed
		and isNonNegativeNumber(self.Tower.Stats.Range)
		and isNonNegativeNumber(self.Config.Amount)
		and isNonNegativeNumber(self.Config.Cooldown)
		and isNonNegativeNumber(self.Config.Duration)
		and self.Config.Duration > 0
end

function HeavenlyGrace:_CancelBuffTimer()
	local buffTimer = self.BuffTimer
	self.BuffTimer = nil
	if buffTimer then
		buffTimer:cancel()
	end
end

function HeavenlyGrace:_RemoveBuff()
	if not self.BuffEndsAt then
		return
	end

	self.BuffEndsAt = nil
	self.Tower:OverrideStats("DamageBuff", nil)
end

function HeavenlyGrace:Use(): boolean
	if not self:Validate() then
		return false
	end

	TimeService = TimeService or ServiceRegistry:GetService("TimeService")
	self._useId += 1
	local useId = self._useId
	local duration = self.Config.Duration
	local amount = self.Config.Amount
	self:_CancelBuffTimer()

	self.BuffEndsAt = TimeService:Now() + duration
	self.BuffTimer = TimeService.DeltaDelay(duration):andThen(function()
		if self.IsDestroyed or self._useId ~= useId then
			return
		end

		self.BuffTimer = nil
		self:_RemoveBuff()
	end)

	self.Tower:OverrideStats("DamageBuff", amount)
	self.FireTriggered(self.Name, {
		Duration = duration,
		Amount = amount,
		Range = self.Tower.Stats.Range,
	})
	return true
end

function HeavenlyGrace:Destroy()
	if self.IsDestroyed then
		return
	end
	self.IsDestroyed = true
	self._useId += 1
	self:_CancelBuffTimer()
	self:_RemoveBuff()
end

return HeavenlyGrace
