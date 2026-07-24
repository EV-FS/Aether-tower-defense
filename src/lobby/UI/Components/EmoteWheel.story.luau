local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local EmoteWheel = require(script.Parent.EmoteWheel)
local Vide = require(ReplicatedStorage.Packages.Vide)

local mount = Vide.mount
local source = Vide.source

return function(target: Instance)
	local testContainer: ImageLabel = Instance.new("ImageLabel")
	testContainer.Name = "EmoteWheelStoryContainer"
	testContainer.Size = UDim2.fromScale(1, 1)
	testContainer.BackgroundTransparency = 0
	testContainer.Image = "rbxassetid://139254798620970"
	testContainer.ScaleType = Enum.ScaleType.Crop
	testContainer.Parent = target

	local mockProps = {
		Emote1 = source(),
		Emote2 = source({ EmoteName = "Mesmerizer", AnimationId = "103556706215217" }),
		Emote3 = source(),
		Emote4 = source(),
	}

	local destroyVide = mount(function()
		local ew = EmoteWheel(mockProps)

		task.spawn(function()
			ew.Rotation = 90
			ew.Size = UDim2.fromScale(0, 0)

			TweenService
				:Create(ew, TweenInfo.new(0.75, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), { Rotation = 0 })
				:Play()
			TweenService:Create(
				ew,
				TweenInfo.new(0.75, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out),
				{ Size = UDim2.fromScale(0.49, 0.49) }
			):Play()

			while true do
				task.wait(3)
				mockProps.Emote1({ EmoteName = "Dance", AnimationId = "rbxassetid://77721607146931" })
				task.wait(3)
				mockProps.Emote1(nil)
			end
		end)

		return ew
	end, testContainer)

	return function()
		destroyVide()
		testContainer:Destroy()
	end
end
