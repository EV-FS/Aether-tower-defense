local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local Net = require(ReplicatedStorage.Shared.Net)
local NotificationService

local GROUP_ID = 492293332

local inProcessPlayer = {}

Net.GroupReward.SendPromptJoin.On(function()
	if inProcessPlayer[Players.LocalPlayer] then
		return
	end

	task.spawn(function()
		inProcessPlayer[Players.LocalPlayer] = true
		local success, result = pcall(function()
			return GroupService:PromptJoinAsync(GROUP_ID)
		end)

		if success then
			if result == Enum.GroupMembershipStatus.Joined then
				NotificationService = NotificationService or ServiceRegistry:GetService("NotificationService")
				NotificationService:Pull(
					Players.LocalPlayer,
					"Thanks for joining! Auto skip is now available.",
					"Normal"
				)
			end
		else
			warn("프롬프트 실패:", result)
		end
	end)
end)
