local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local CurrencyData = require(ReplicatedStorage.Settings.Data.CurrencyData)

type Reactive<T> = T | (() -> T)
type Props = {
	CurrencyName: Reactive<string>,
	CurrencyQuantity: Reactive<number>?,
	CurrencyQuantityText: Reactive<string>?,
	QuantityColor: Reactive<Color3>?,
}

local create = Vide.create
local read = Vide.read
local derive = Vide.derive

return function(props: Props)
	local currencyInfo = derive(function()
		return CurrencyData.ByName[read(props.CurrencyName)]
	end)

	return create("Frame")({
		Name = "Content",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),

		create("ImageLabel")({
			Name = "ItemIcon",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.465),
			Size = UDim2.fromScale(0.7, 0.7),
			Image = function()
				return if currencyInfo() then currencyInfo().CurrencyImage else ""
			end,
		}),

		create("TextLabel")({
			Name = "Name",
			BackgroundTransparency = 1,
			FontFace = Font.new(
				"rbxasset://fonts/families/SourceSansPro.json",
				Enum.FontWeight.Bold,
				Enum.FontStyle.Normal
			),
			Position = UDim2.fromScale(0.076095, 0.730419),
			Size = UDim2.fromScale(0.84887, 0.172688),
			Text = props.CurrencyName,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 10,

			create("UIStroke")({
				Name = "UIStroke",
				Thickness = 2,
			}),
		}),

		create("ImageLabel")({
			Name = "Quantity",
			BackgroundTransparency = 1,
			Image = "rbxassetid://104083646922843",
			Position = UDim2.fromScale(-0.0129994, -0.05),
			Size = if props.CurrencyQuantityText then UDim2.fromScale(0.94, 0.238322) else UDim2.fromScale(0.653434, 0.238322),
			ZIndex = 10,
			Visible = function()
				return props.CurrencyQuantityText ~= nil or read(props.CurrencyQuantity) ~= nil
			end,

			create("UIAspectRatioConstraint")({
				Name = "UIAspectRatioConstraint",
				AspectRatio = 3.2,
			}),

			create("TextLabel")({
				Name = "TextLabel",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/SourceSansPro.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = if props.CurrencyQuantityText then UDim2.fromScale(0.5, 0.489) else UDim2.fromScale(0.3, 0.489),
				Size = if props.CurrencyQuantityText then UDim2.fromScale(0.84, 0.75514) else UDim2.fromScale(0.477775, 0.75514),
				Text = function()
					return if props.CurrencyQuantityText then read(props.CurrencyQuantityText) else `{read(props.CurrencyQuantity)}x`
				end,
				TextColor3 = props.QuantityColor or Color3.new(1, 1, 1),
				TextScaled = true,

				create("UIStroke")({
					Name = "UIStroke",
					Thickness = 2,
				}),

				create("UIGradient")({
					Name = "UIGradient",
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(104, 106, 211)),
					}),
					Rotation = 90,
				}),
			}),
		}),
	})
end
