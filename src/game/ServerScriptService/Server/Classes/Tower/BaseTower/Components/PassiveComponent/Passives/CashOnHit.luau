local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local EconomyService

local CashOnHit = {}
CashOnHit.__index = CashOnHit

function CashOnHit.new(tower, config, fireTriggered)
	local self = setmetatable({}, CashOnHit)
	self.Config = config

	self.Connection = tower:GetEvent("AfterDamaged"):Connect(function()
		local amount = self.Config.Amount

		EconomyService = EconomyService or ServiceRegistry:GetService("EconomyService")
		EconomyService.AddCash(tower.Owner, amount)

		fireTriggered(self.Config.Type, amount)
	end)

	return self
end

function CashOnHit:UpdateConfig(newConfig)
	self.Config = newConfig
end

function CashOnHit:Destroy()
	self.Connection:Disconnect()
end

return CashOnHit
