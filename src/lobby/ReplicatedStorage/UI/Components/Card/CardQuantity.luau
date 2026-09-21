local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local create = Vide.create

return function(props)
	return create("ImageLabel")({
		Name = props.Name or "CardQuantity",
		BackgroundTransparency = 1,
		Image = props.Image or "rbxassetid://104083646922843",
		Position = props.Position or UDim2.fromScale(0.015, 0.015),
		Size = props.Size or UDim2.fromScale(0.62, 0.22),
		Visible = props.Visible,
		ZIndex = props.ZIndex or 20,
		create("UIAspectRatioConstraint")({ AspectRatio = 3.2 }),
		create("TextLabel")({
			Name = "Amount",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold),
			Position = UDim2.fromScale(0.365, 0.4),
			Size = UDim2.fromScale(0.608, 0.889),
			Text = props.Text,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			ZIndex = (props.ZIndex or 20) + 1,
			create("UIStroke")({ Thickness = 2 }),
		}),
	})
end
