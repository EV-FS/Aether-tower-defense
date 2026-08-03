local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NotificationUI = require(script.Parent)
local Vide = require(ReplicatedStorage.Packages.Vide)

local mount = Vide.mount

return function(target: Instance)
	local testContainer = Instance.new("Frame")
	testContainer.Name = "NotificationStoryContainer"
	testContainer.Size = UDim2.fromScale(1, 1)
	testContainer.BackgroundTransparency = 1
	testContainer.Parent = target

	local destroyVide = mount(function()
		return NotificationUI.RenderUI()
	end, testContainer)

	local index = 1
	local notifications = {
		{
			Title = "System Update",
			Description = "A new game update is available soon!",
			Icon = 9405931578,
			Duration = 4,
		},
		{
			Title = "Towers Summoned",
			Description = "Demian has been summoned successfully.",
			Icon = 9405931578,
			Duration = 5,
		},
		{
			Title = "Wave Cleared!",
			Description = "You have successfully cleared Wave 15.",
			Icon = 9405931578,
			Duration = 3,
		},
		{
			Title = "Warning",
			Description = "Boss enemy is spawning in 5 seconds!",
			Icon = 9405931578,
			Duration = 6,
		},
	}

	local thread = task.spawn(function()
		task.wait(1)
		while true do
			local data = notifications[index]
			NotificationUI.Notify("Side", data.Title, data.Description, data.Icon, data.Duration)
			
			index = (index % #notifications) + 1
			task.wait(2.5)
		end
	end)

	return function()
		task.cancel(thread)
		destroyVide()
		testContainer:Destroy()
	end
end
