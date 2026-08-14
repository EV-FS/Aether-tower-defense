local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local TouchZone = require(ReplicatedStorage.Shared.Modules.Utils.TouchZone)
local Net = require(ReplicatedStorage.Shared.Net)
local NotificationService

local touchPart = workspace:WaitForChild("TouchZone"):WaitForChild("GroupTouch")

local GROUP_ID = 492293332

local InPlayer = {}

local zone = TouchZone.new(touchPart)
zone:Start()

zone.Touched:Connect(function(player: Player)
	InPlayer[player] = true

	if not player:IsInGroupAsync(GROUP_ID) then
		Net.GroupReward.SendPromptJoin.Fire(player)
		return
	end

	NotificationService = NotificationService or ServiceRegistry:GetService("NotificationService")
	NotificationService:Pull(player, "You are already a member of this group!", "Normal", 1)
end)

zone.TouchEnded:Connect(function(player: Player)
	InPlayer[player] = false
end)
