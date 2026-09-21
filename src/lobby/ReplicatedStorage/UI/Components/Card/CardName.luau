local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local create = Vide.create

return function(props)
	return create("TextLabel")({
		Name = props.Name or "CardName",
		BackgroundTransparency = 1,
		FontFace = props.FontFace or Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold),
		Position = props.Position or UDim2.fromScale(0.076, 0.73),
		Size = props.Size or UDim2.fromScale(0.849, 0.173),
		Text = props.Text,
		TextColor3 = props.TextColor3 or Color3.new(1, 1, 1),
		TextScaled = true,
		TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left,
		Visible = props.Visible,
		ZIndex = props.ZIndex or 10,
		create("UIStroke")({ Thickness = props.StrokeThickness or 2 }),
	})
end
