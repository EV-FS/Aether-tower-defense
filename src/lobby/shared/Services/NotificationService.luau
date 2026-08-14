--/Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DEFAULT_DURATION = 3

--/Modules
local Net = require(ReplicatedStorage.Shared.Net)
local NotificationUI = require(ReplicatedStorage.UI.Views.Game.NotificationUI)

-------------------------------------------------
--// NotificationService
-------------------------------------------------
local NotificationService = {}

function NotificationService:Pull(player: Player?, message: string, logType: string, duration: number?)
	if not RunService:IsClient() then
		if typeof(player) == "Instance" and player:IsA("Player") and message then
			Net.NotificationService.Popup.Fire(player, {
				Message = message,
				LogType = logType,
				DurationMs = (duration or DEFAULT_DURATION) * 1000,
			})
		end
		return
	end

	NotificationUI.Pull(message, logType, duration)
end

function NotificationService:PullAll(message: string, logType: string, duration: number?)
	if not RunService:IsClient() then
		Net.NotificationService.Popup.FireAll({
			Message = message,
			LogType = logType,
			DurationMs = (duration or DEFAULT_DURATION) * 1000,
		})
		return
	end

	for _, player in Players:GetPlayers() do
		self:Pull(player, message, logType, duration)
	end
end

function NotificationService.Init()
	if not RunService:IsClient() then
		return
	end

	Net.NotificationService.Popup.On(function(data)
		NotificationService:Pull(nil, data.Message, data.LogType, data.DurationMs)
	end)
end

return NotificationService
