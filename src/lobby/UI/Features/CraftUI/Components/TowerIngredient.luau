local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create
local derive = Vide.derive

return function(props)
	local canAfford = derive(function()
		return props.CurrentAmount() >= props.NeedAmount()
	end)

	return create("ImageButton")({
		Name = "TowerIngredient",

		BackgroundColor3 = function()
			return if canAfford() then Color3.fromRGB(0, 38, 0) else Color3.fromRGB(38, 25, 0)
		end,
		BackgroundTransparency = 0.1,
		Size = UDim2.fromScale(0.2, 0.2),
		SizeConstraint = Enum.SizeConstraint.RelativeXX,

		MouseButton1Click = props.OnActivated,

		create("UICorner")({
			CornerRadius = UDim.new(0.12, 0),
		}),

		create("ImageLabel")({
			Name = "TowerImage",
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			Image = props.TowerImage,
			ImageTransparency = 0.2,
			Position = UDim2.fromScale(0.5, 1.1),
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromScale(1.3, 1.35),
		}),

		create("UIStroke")({
			Color = function()
				return if canAfford() then Color3.new(0, 1, 0) else Color3.fromRGB(255, 170, 0)
			end,
			StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
			Thickness = 0.035,
			ZIndex = 2,
		}),

		create("TextLabel")({
			Name = "Amount",
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			FontFace = Font.new(
				"rbxasset://fonts/families/GothamSSm.json",
				Enum.FontWeight.Bold,
				Enum.FontStyle.Normal
			),
			Position = UDim2.fromScale(0.5, 0.7),
			Size = UDim2.fromScale(0.75, 0.25),
			Text = function()
				return `{props.CurrentAmount()}/{props.NeedAmount()}`
			end,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			ZIndex = 2,

			create("UIStroke")({
				Name = "UIStroke",
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.2,
			}),
		}),

		create("TextLabel")({
			Name = "Plus",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			FontFace = Font.new(
				"rbxasset://fonts/families/GothamSSm.json",
				Enum.FontWeight.Bold,
				Enum.FontStyle.Normal
			),
			Position = UDim2.fromScale(0.5, 0.45),
			Size = UDim2.fromScale(0.7, 0.7),
			Text = "+",
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			ZIndex = 2,

			create("UIStroke")({
				Name = "UIStroke",
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.07,
			}),
		}),
	})
end
