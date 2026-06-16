local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local ItemData = require(ReplicatedStorage.Settings.Data.ItemData)

local create = Vide.create
local derive = Vide.derive

local DEFAULT_ITEM_ICON = "rbxassetid://105048264604047"

return function(props)
	local canAfford = derive(function()
		return props.CurrentAmount() >= props.NeedAmount()
	end)

	local itemInfo = ItemData.ByName[props.ItemName]
	local itemImage = itemInfo and itemInfo.ItemImage or DEFAULT_ITEM_ICON

	return create("Frame")({
		Name = "ItemIngredient",

		BackgroundColor3 = function()
			return if canAfford() then Color3.fromRGB(0, 38, 0) else Color3.fromRGB(38, 25, 0)
		end,
		BackgroundTransparency = 0.1,
		Size = UDim2.fromScale(0.2, 0.2),
		SizeConstraint = Enum.SizeConstraint.RelativeXX,

		create("UICorner")({
			CornerRadius = UDim.new(0.12, 0),
		}),

		create("ImageLabel")({
			Name = "ItemImage",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = itemImage,
			ImageTransparency = 0.2,
			Position = UDim2.fromScale(0.5, 0.45),
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromScale(0.75, 0.75),
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
			Size = UDim2.fromScale(0.85, 0.25),
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
	})
end
