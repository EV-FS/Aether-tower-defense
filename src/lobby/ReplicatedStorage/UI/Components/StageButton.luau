local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

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
		Visible = function()
			if props.SelectedMap() == "" then
				return true
			end

			return props.SelectedMap() == props.MapId
		end,

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
			Thickness = 3,
		}),

		create("Frame")({
			Name = "OnSelected",
			BackgroundColor3 = Color3.new(),
			BackgroundTransparency = 0.5,
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
				Text = "Tap to Unselect",
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextTransparency = 0.5,
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
