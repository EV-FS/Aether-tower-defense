local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local useButtonEffect = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useButtonEffect)

local create = Vide.create
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")

type Props = {
	MapName: string,
	DisplayName: string,
	Image: string,
	LayoutOrder: number,
	Visible: () -> boolean,
	Locked: () -> boolean,
	Hint: () -> string,
	Selected: () -> boolean,
	Activated: () -> (),
}

local function textLabel(name: string, value: string | (() -> string), position: UDim2, size: UDim2, textSize: number)
	return create("TextLabel")({
		Name = name,
		BackgroundTransparency = 1,
		FontFace = FONT,
		Position = position,
		Size = size,
		Text = value,
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = textSize,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		create("UIStroke")({ Thickness = 1.5, Color = Color3.fromRGB(16, 15, 26) }),
	})
end

return function(props: Props)
	return create("ImageButton")({
		Name = props.MapName,
		LayoutOrder = props.LayoutOrder,
		BackgroundTransparency = 1,
		Image = props.Image,
		AutoButtonColor = false,
		ScaleType = Enum.ScaleType.Crop,
		Size = UDim2.new(1, -2, 0, 90),
		ClipsDescendants = false,
		Visible = props.Visible,
		Activated = props.Activated,
		useButtonEffect(0.97, 1.025),
		create("UIAspectRatioConstraint")({ AspectRatio = 2.7, DominantAxis = Enum.DominantAxis.Width }),
		create("UICorner")({ CornerRadius = UDim.new(0, 7) }),
		create("UIStroke")({
			Color = function()
				return if props.Selected() then Color3.fromRGB(255, 233, 89) else Color3.fromRGB(227, 227, 227)
			end,
			Thickness = function()
				return if props.Selected() then 4 else 2
			end,
		}),
		create("Frame")({
			Name = "LockedShade",
			BackgroundColor3 = Color3.new(),
			BackgroundTransparency = 0.48,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Visible = props.Locked,
		}),
		textLabel("Map", props.DisplayName, UDim2.fromScale(0.03, 0.04), UDim2.fromScale(0.9, 0.31), 19),
		textLabel("Chapter", props.MapName, UDim2.fromScale(0.04, 0.61), UDim2.fromScale(0.5, 0.18), 15),
		create("Frame")({
			Name = "InfoStrip",
			BackgroundColor3 = Color3.new(),
			BackgroundTransparency = 0.1,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.01, 0.82),
			Size = UDim2.fromScale(0.98, 0.16),
			textLabel("SelectHint", props.Hint, UDim2.fromScale(0.53, 0), UDim2.fromScale(0.41, 1), 11),
		}),
		create("ImageLabel")({
			Name = "SelectArrow",
			BackgroundTransparency = 1,
			Image = "rbxassetid://131761289623234",
			Position = UDim2.fromScale(0.87, 0.07),
			Size = UDim2.fromOffset(20, 20),
		}),
	})
end
