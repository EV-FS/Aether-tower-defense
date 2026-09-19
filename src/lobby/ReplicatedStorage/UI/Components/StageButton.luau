local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create
local spring = Vide.spring

return function(props)
	return create("ImageButton")({
		Name = props.MapName,
		BackgroundTransparency = 1,
		Image = props.MapImage,
		LayoutOrder = props.LayoutOrder,
		Position = UDim2.fromScale(0.523439, 0.150166),
		Size = UDim2.fromScale(0.476561, 0.280332),
		Activated = props.Activated,
		Interactable = props.Interactable,

		create("UIScale")({
			Scale = spring(function()
				return if props.SelectedMap() == props.MapId then 1.015 else 1
			end, 0.35, 0.78),
		}),

		create("UIAspectRatioConstraint")({
			Name = "UIAspectRatioConstraint",
			AspectRatio = 2.42,
		}),

		create("UICorner")({
			Name = "UICorner",
			BottomLeftRadius = UDim.new(0, 5),
			BottomRightRadius = UDim.new(0, 5),
			TopLeftRadius = UDim.new(0, 5),
			TopRightRadius = UDim.new(0, 5),
		}),

		create("UIStroke")({
			Name = "UIStroke",
			Color = function()
				return if props.SelectedMap() == props.MapId
					then Color3.fromRGB(255, 231, 112)
					else Color3.new(1, 1, 1)
			end,
			Thickness = spring(function()
				return if props.SelectedMap() == props.MapId then 4 else 3
			end, 0.35, 0.8),
			Transparency = spring(function()
				return if props.SelectedMap() == props.MapId then 0 else 0.2
			end, 0.35, 0.85),
		}),

		create("Frame")({
			Name = "OnSelected",
			BackgroundColor3 = Color3.new(),
			BackgroundTransparency = 0.7,
			Size = UDim2.fromScale(1, 1),
			Visible = function()
				return props.SelectedMap() == props.MapId
			end,

			create("TextLabel")({
				Name = "TextLabel",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
				Interactable = false,
				Position = UDim2.fromScale(0.5, 0.5),
				RichText = true,
				Size = UDim2.fromScale(0.5, 0.3),
				Text = "SELECTED  •  TAP TO CLOSE",
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextTransparency = 0.2,
			}),
		}),

		create("TextLabel")({
			Name = "TextLabel",
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
			Position = UDim2.fromScale(0.0252202, 0.773082),
			Size = UDim2.fromScale(0.47478, 0.16432),
			Text = props.MapName,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,

			create("UIGradient")({
				Name = "UIGradient",
				Rotation = 90,
			}),
		}),
	})
end
