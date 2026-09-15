local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create
local spring = Vide.spring

local LOG_COLOR = {
	Normal = {
		TextColor = Color3.new(1, 1, 1),
		StrokeColor = Color3.new(),
	},
	Error = {
		TextColor = Color3.fromRGB(255, 76, 79),
		StrokeColor = Color3.fromRGB(97, 0, 3),
	},
}

return function(props)
	return create("Frame")({
		Name = "Example",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(0.5, 0.025),

		create("TextLabel")({
			Name = "Title",
			BackgroundTransparency = 1,
			FontFace = Font.new(
				"rbxasset://fonts/families/GothamSSm.json",
				Enum.FontWeight.ExtraBold,
				Enum.FontStyle.Normal
			),
			RichText = true,
			Position = spring(function()
				local currentState = props.State()
				if currentState == "Entering" then
					return UDim2.fromScale(-1, 0)
				elseif currentState == "Alive" then
					return UDim2.fromScale(0, 0)
				elseif currentState == "Leaving" then
					return UDim2.fromScale(1, 0)
				end

				return UDim2.fromScale(0, 0)
			end, 0.3, 1),

			Size = UDim2.fromScale(1, 1),
			Text = props.Message or "",
			TextColor3 = LOG_COLOR[props.LogType or "Normal"].TextColor,
			TextScaled = true,
			TextTransparency = spring(function()
				return if props.State() == "Alive" then 0 else 1
			end, 0.3, 1),

			create("UIStroke")({
				Name = "UIStroke",
				Color = LOG_COLOR[props.LogType or "Normal"].StrokeColor,
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.075,
				Transparency = spring(function()
					return if props.State() == "Alive" then 0 else 1
				end, 0.3, 1),
			}),
		}),
	})
end
