local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local EconomyService

local CashOnHit = {}
CashOnHit.__index = CashOnHit

function CashOnHit.new(tower, config, fireTriggered)
	local self = setmetatable({}, CashOnHit)

	self.Connection = tower:GetEvent("AfterDamaged"):Connect(function()
		local amount = config.Amount

		EconomyService = EconomyService or ServiceRegistry:GetService("EconomyService")
		EconomyService:AddCash(tower.Owner, amount)

		fireTriggered(config.Type, amount)
	end)

	return self
end

function CashOnHit:Destroy()
	self.Connection:Disconnect()
end

return CashOnHit
