local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)
local RarityColor = require(ReplicatedStorage.Settings.Visuals.RarityColor)

local create = Vide.create

return function(props)
	local towerInfo = TowerData.ByName[props.TowerName]
	if not towerInfo then
		warn(`{props.TowerName}의 정보가 존재 하지 않음.`)
		return
	end

	return create("ImageButton")({
		Name = props.TowerName,
		BackgroundTransparency = 1,
		Size = props.Size or UDim2.fromScale(0.2, 0.2),
		SizeConstraint = Enum.SizeConstraint.RelativeXX,

		MouseButton1Click = props.OnActivated,

		create("Frame")({
			Name = "Canvas",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(),
			BackgroundTransparency = 0.1,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.85, 0.85),

			create("TextLabel")({
				Name = "TowerName",
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/GothamSSm.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(0.5, 0.75),
				Size = UDim2.fromScale(0.95, 0.185),
				Text = props.TowerName,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				ZIndex = 2,

				create("UIStroke")({
					Name = "UIStroke",
					Thickness = 2,
				}),
			}),

			create("UIStroke")({
				Name = "Outline",
				Color = RarityColor[towerInfo.Rarity],
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.06,

				create("UIGradient")({
					Name = "UIGradient",
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(76, 76, 76)),
					}),
					Rotation = 90,
				}),
			}),

			create("UIStroke")({
				Color = Color3.fromRGB(63, 63, 63),
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.03,
				ZIndex = 2,
			}),

			create("UICorner")({
				CornerRadius = UDim.new(0.12, 0),
			}),

			create("ImageLabel")({
				Name = "ImageLabel",
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundTransparency = 1,
				Image = towerInfo.TowerImage,
				Position = UDim2.fromScale(0.5, 1),
				Size = UDim2.fromScale(1.2, 1.2),
			}),
		}),
	})
end
