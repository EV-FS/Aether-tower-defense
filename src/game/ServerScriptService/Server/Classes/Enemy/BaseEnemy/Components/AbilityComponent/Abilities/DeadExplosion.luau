local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local TowerService
local TimeService

local DeadExplosion = {}
DeadExplosion.__index = DeadExplosion

function DeadExplosion.new(enemy, config, fireTriggered)
	local self = setmetatable({}, DeadExplosion)
	self.Enemy = enemy
	self.Config = config
	self.FireTriggered = fireTriggered
	self.RemainingCount = 0
	self.IsExecuting = false
	self.IsDestroyed = false

	return self
end

function DeadExplosion:Start()
	TowerService = TowerService or ServiceRegistry:GetService("TowerService")
	TimeService = TimeService or ServiceRegistry:GetService("TimeService")

	self.DiedConnection = self.Enemy:GetEvent("Died"):Connect(function()
		self:Execute()
	end)
end

function DeadExplosion:Execute()
	if self.IsDestroyed or self.Enemy.IsDestroyed then
		return
	end

	local range = self.Config.Range or 0
	if range <= 0 then
		return
	end

	self.FireTriggered(self.Config.Type, {
		Range = range,
	})

	for _, tower in TowerService.GetAll() do
		if tower.IsDestroyed then
			continue
		end

		local offset = tower.Position - self.Enemy.Position

		if offset.X ^ 2 + offset.Z ^ 2 <= range ^ 2 then
			tower:Stun(self.Config.StunTime or 0)
		end
	end
end

function DeadExplosion:Destroy()
	self.IsDestroyed = true
	if self.DiedConnection then
		self.DiedConnection:Disconnect()
		self.DiedConnection = nil
	end
end

return DeadExplosion
