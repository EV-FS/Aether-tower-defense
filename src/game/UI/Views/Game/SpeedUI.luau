local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local ClientSignals = require(StarterPlayer.StarterPlayerScripts.Client.ClientSignals)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)

local TimeService
local currentSpeed = 1

local SpeedUI = {}

function SpeedUI.ChangeSpeed(newSpeed: number): boolean
	TimeService = TimeService or ServiceRegistry:GetService("TimeService")
	return TimeService:SetGameSpeed(newSpeed)
end

function SpeedUI.GetSpeed(): number
	return currentSpeed
end

function SpeedUI.Init()
	TimeService = ServiceRegistry:GetService("TimeService")
end

function SpeedUI.Start()
	currentSpeed = TimeService:GetGameSpeed()
	ClientSignals.GameSpeedChanged:Connect(function(newSpeed: number)
		currentSpeed = newSpeed
	end)
end

return SpeedUI
