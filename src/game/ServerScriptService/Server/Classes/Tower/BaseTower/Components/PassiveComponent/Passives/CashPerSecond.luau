local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local TimeService
local EconomyService
local GameService

local CashPerSecond = {}
CashPerSecond.__index = CashPerSecond

function CashPerSecond.new(tower, config, fireTriggered)
	local self = setmetatable({}, CashPerSecond)
	self.Config = config

	TimeService = TimeService or ServiceRegistry:GetService("TimeService")
	GameService = GameService or ServiceRegistry:GetService("GameService")

	self.Connection = task.spawn(function()
		while true do
			while not GameService.IsGameRunning do
				task.wait()
			end

			TimeService.DeltaWait(self.Config.Delay)

			if GameService.IsGameRunning then
				EconomyService = EconomyService or ServiceRegistry:GetService("EconomyService")
				EconomyService.AddCash(tower.Owner, self.Config.Amount)

				fireTriggered(self.Config.Type, self.Config.Amount)
			end
		end
	end)

	return self
end

function CashPerSecond:UpdateConfig(newConfig)
	self.Config = newConfig
end

function CashPerSecond:Destroy()
	task.cancel(self.Connection)
end

return CashPerSecond
