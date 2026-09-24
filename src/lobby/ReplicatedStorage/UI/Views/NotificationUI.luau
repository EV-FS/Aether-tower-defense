local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NotificationFeed = require(ReplicatedStorage.Shared.Modules.UI.Notifications.NotificationFeed)

local NotificationUI = {}

NotificationUI.Pull = NotificationFeed.Pull
NotificationUI.PullItem = NotificationFeed.PullItem

function NotificationUI.RenderUI()
	return NotificationFeed.RenderUI()
end

function NotificationUI.Init() end

function NotificationUI.Start() end

return NotificationUI
