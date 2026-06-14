local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
--/Modules
local EconomyService
local WaveService

-------------------------------------------------
--// FarmComponent
-------------------------------------------------
local FarmComponent = {}
FarmComponent.__index = FarmComponent

function FarmComponent.new(tower)
	local self = setmetatable({}, FarmComponent)
	self.Tower = tower

	return self
end

function FarmComponent:Start()
	EconomyService = EconomyService or ServiceRegistry:GetService("EconomyService")
	WaveService = WaveService or ServiceRegistry:GetService("WaveService")

	self.WaveConnection = WaveService.WaveStarted:Connect(function()
		EconomyService.AddCash(self.Tower.Owner, self.Tower.Stats.Income)
	end)
end

function FarmComponent:Destroy()
	if self.WaveConnection then
		self.WaveConnection:Disconnect()
		self.WaveConnection = nil
	end
end

return FarmComponent
