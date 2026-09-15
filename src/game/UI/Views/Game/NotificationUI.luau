local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local LogMessage = require(ReplicatedStorage.UI.Components.LogMessage)

local create = Vide.create
local source = Vide.source
local values = Vide.values

local notification = source({})

local DEFAULT_LIFETIME = 3

local NotificationUI = {}

function NotificationUI.Pull(message: string, logType: string, lifeTime: number?)
	local newValue = table.clone(notification())
	local newLog = {
		Message = message or "",
		LogType = logType or "Normal",
		State = source("Entering"),
	}

	table.insert(newValue, newLog)
	notification(newValue)

	task.defer(function()
		newLog.State("Alive")
	end)

	task.delay(lifeTime or DEFAULT_LIFETIME, function()
		newLog.State("Leaving")

		task.wait(0.3)

		local current = table.clone(notification())
		local index = table.find(current, newLog)

		if index then
			table.remove(current, index)
			notification(current)
		end
	end)
end

function NotificationUI.RenderUI()
	return create("Frame")({
		Name = "Log",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.2),
		Size = UDim2.fromScale(0.45, 0.8),
		ZIndex = 50,

		values(notification, function(value)
			return LogMessage({
				Message = value.Message,
				LogType = value.LogType,
				State = value.State,
			})
		end),

		create("UIListLayout")({
			Name = "UIListLayout",
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0.01, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),

		create("UIListLayout")({
			Name = "UIListLayout",
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0.01, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
		}),
	})
end

function NotificationUI.Init() end

function NotificationUI.Start() end

return NotificationUI
