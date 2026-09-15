local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SidePopup = require(script.Components.SidePopup)
local Vide = require(ReplicatedStorage.Packages.Vide)

local MAX_SIDE_COUNT = 7

local create = Vide.create
local source = Vide.source
local values = Vide.values

local SideNotification = source({})
local SideCount = source(0)

local currentId = 0

local function NotifySide(title: string, description: string, icon: string | number, duration: number)
	local currentNotifications = SideNotification()

	if SideCount() >= MAX_SIDE_COUNT then
		local oldestId = nil
		local oldestTime = math.huge

		for id, data in pairs(currentNotifications) do
			if data.TimeStamp < oldestTime then
				oldestTime = data.TimeStamp
				oldestId = id
			end
		end

		if oldestId then
			currentNotifications[oldestId] = nil
			SideCount(SideCount() - 1)
		end
	end

	duration = duration or 5

	local notificationId = `#{currentId}`
	currentNotifications[notificationId] = {
		Icon = icon,
		Title = title,
		LayoutOrder = currentId,
		Description = description,
		Duration = duration,
		TimeStamp = os.clock(),
	}

	SideCount(SideCount() + 1)
	SideNotification(currentNotifications)
	currentId += 1

	task.delay(duration, function()
		local activeNotifications = SideNotification()
		if activeNotifications[notificationId] then
			activeNotifications[notificationId] = nil
			SideCount(SideCount() - 1)
			SideNotification(activeNotifications)
		end
	end)
end

local NotificationUI = {}

function NotificationUI.Notify(
	displayType: string,
	title: string,
	description: string,
	icon: string | number,
	duration: number
)
	if displayType == "Side" then
		NotifySide(title, description, icon, duration)
	end
end

function NotificationUI.RenderUI()
	return create("Frame")({
		Name = "NotificationFrame",
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 50,

		create("Frame")({
			Name = "SideNotificationFrame",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(0.975, 11, 0.95, 0),
			Size = UDim2.fromScale(0.4, 0.95),
			BackgroundTransparency = 1,

			create("UIListLayout")({
				Name = "UIListLayout",
				SortOrder = Enum.SortOrder.LayoutOrder,
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				VerticalAlignment = Enum.VerticalAlignment.Bottom,
				Padding = UDim.new(0, 10),
			}),

			values(SideNotification, function(popupDataSource, id)
				local data = popupDataSource

				return SidePopup({
					Name = id(),
					Icon = data.Icon,
					Title = data.Title,
					Description = data.Description,
					Duration = data.Duration,
				})
			end),
		}),
	})
end

function NotificationUI.Init() end

function NotificationUI.Start() end

return NotificationUI
