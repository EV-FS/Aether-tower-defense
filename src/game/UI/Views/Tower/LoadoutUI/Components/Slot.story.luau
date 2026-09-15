local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Slot = require(script.Parent.Slot)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create
local source = Vide.source
local mount = Vide.mount

return function(target: Instance)
	local testContainer = Instance.new("Frame")
	testContainer.Name = "SlotsStoryContainer"
	testContainer.Size = UDim2.fromScale(1, 1)
	testContainer.BackgroundTransparency = 1
	testContainer.Parent = target

	local mockLoadout = source({})
	local mockOwnedTowers = source({})
	local mockCash = source(0)

	local destroyVide = mount(function()
		local slots = {}
		for i = 1, 5 do
			table.insert(
				slots,
				Slot({
					slotNumber = i,
					loadout = mockLoadout,
					ownedTowers = mockOwnedTowers,
					playerCash = mockCash,
					Activated = function()
						print(`💥 [스토리] 슬롯 {i}번이 클릭되었습니다!`)
					end,
				})
			)
		end

		return create("Frame")({
			Name = "Slots",
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.new(1, 0, 0.07, 50),
			ZIndex = 5,

			create("Frame")({
				Name = "TowerSlots",
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.5, 0.97),
				Size = UDim2.fromScale(11.3, 1),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				ZIndex = 2,

				create("UIListLayout")({
					Name = "UIListLayout",
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Padding = UDim.new(-0.005, 0),
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Wraps = true,
				}),

				unpack(slots),
			}),

			create("Frame")({
				Name = "Background",
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundColor3 = Color3.new(),
				BackgroundTransparency = 0.2,
				BorderColor3 = Color3.new(),
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.5, 1),
				Size = UDim2.fromScale(4.8, 0.4),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,

				create("UIGradient")({
					Name = "UIGradient",
					Rotation = 90,
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 1),
						NumberSequenceKeypoint.new(1, 0),
					}),
				}),
			}),
		})
	end, testContainer)

	local thread = task.spawn(function()
		while true do
			mockLoadout({})
			task.wait(2)

			mockLoadout({
				["1"] = { Name = "Hacker", Key = "t_1", Level = 1 },
				["3"] = { Name = "Cyborg Dummy", Key = "t_2", Level = 15 },
				["5"] = { Name = "Mecha Demian", Key = "t_3", Level = 50 },
			})
			task.wait(2)
		end
	end)

	return function()
		task.cancel(thread)
		destroyVide()
		testContainer:Destroy()
	end
end
