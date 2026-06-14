local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local NumberUtils = require(ReplicatedStorage.Shared.Modules.Utils.NumberUtils)

local create = Vide.create

export type CashFrameProps = {
	Cash: () -> number,
}

return function(props: CashFrameProps)
	return create("Frame")({
		Name = "CashFrame",
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Color3.new(),
		BorderColor3 = Color3.new(),
		BorderSizePixel = 0,
		Position = UDim2.new(0.5, 0, 0.915, -50),
		Size = UDim2.new(0.095, 60, 0.005, 50),

		create("TextLabel")({
			Name = "Money",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			FontFace = Font.new(
				"rbxasset://fonts/families/GothamSSm.json",
				Enum.FontWeight.Bold,
				Enum.FontStyle.Normal
			),
			Position = UDim2.fromScale(0.47, 0.5),
			Size = UDim2.fromScale(0.7, 0.7),
			Text = function()
				local roundedCash = math.round(props.Cash())
				return `${NumberUtils.FormatComma(roundedCash)}`
			end,
			TextColor3 = Color3.fromRGB(255, 217, 0),
			TextScaled = true,

			create("UIStroke")({
				Name = "UIStroke",
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.1,
			}),

			create("UIGradient")({
				Name = "UIGradient",
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 162, 0)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 238, 0)),
				}),
				Rotation = -100,
			}),
		}),

		create("UIAspectRatioConstraint")({
			Name = "UIAspectRatioConstraint",
			AspectRatio = 6.23337,
		}),

		create("UIGradient")({
			Name = "UIGradient",
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0.381),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})
end
