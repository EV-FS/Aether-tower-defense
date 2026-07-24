local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

return function(props)
	return Vide.create("Frame")({
		Name = props.Rarity .. "Bar",
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.fromScale(0.979, 0.05),
		SizeConstraint = Enum.SizeConstraint.RelativeXX,
		Visible = props.Exist,

		Vide.create("TextLabel")({
			Name = "TextLabel",
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
			Size = UDim2.fromScale(0.75, 1),
			Text = "• " .. props.Rarity,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Vide.create("UIGradient")({ Color = props.GradientColors, Rotation = 90 }),
		}),
		Vide.create("TextButton")({
			Name = "Fold",
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
			Position = UDim2.fromScale(0.95, 0),
			RichText = true,
			Rotation = function()
				return props.Opened() and 180 or 0
			end,
			Size = UDim2.fromScale(1, 1),
			Text = `<font family="rbxasset://LuaPackages/Packages/_Index/BuilderIcons/BuilderIcons/BuilderIcons.json">chevron-small-up-to-line</font>`,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			Activated = function()
				props.Opened(not props.Opened())
			end,
			Vide.create("UIAspectRatioConstraint")({}),
		}),
	})
end
