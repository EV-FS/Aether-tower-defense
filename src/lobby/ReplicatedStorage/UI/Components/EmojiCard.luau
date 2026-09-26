local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local EmojiData = require(ReplicatedStorage.Settings.Data.EmojiData)
local CardFrame = require(ReplicatedStorage.UI.Components.Card.CardFrame)

local create = Vide.create

return function(props)
	local info = EmojiData.ByName[props.EmojiId]
	return CardFrame({
		Name = props.EmojiId,
		Active = true,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.fromScale(0.239841, 0.354932),
		CornerRadius = UDim.new(0.06, 0),
		Rarity = "Rare",
		Selected = props.IsSelected,
		ShimmerEnabled = false,
		GlowEnabled = false,
		RarityBorderEnabled = false,
		PressedScale = 0.96,
		HoverScale = 1.025,
		HoverEnabled = false,
		Activated = props.Activated,
		Content = {
			create("UIAspectRatioConstraint")({}),
			create("ImageLabel")({
				Name = "Preview",
				BackgroundTransparency = 1,
				Image = if info then info.Image else "",
				Position = UDim2.fromScale(0.12, 0.1),
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromScale(0.76, 0.66),
				Visible = info ~= nil and info.Image ~= "",
				ZIndex = 5,
			}),
			create("TextLabel")({
				Name = "Symbol",
				BackgroundTransparency = 1,
				FontFace = Font.fromEnum(Enum.Font.FredokaOne),
				Position = UDim2.fromScale(0.12, 0.1),
				Size = UDim2.fromScale(0.76, 0.66),
				Text = if info then info.Symbol else "?",
				TextColor3 = Color3.fromRGB(115, 215, 255),
				TextScaled = true,
				Visible = info == nil or info.Image == "",
				ZIndex = 5,
			}),
			create("TextLabel")({
				Name = "EmojiName",
				AnchorPoint = Vector2.new(0, 1),
				BackgroundTransparency = 1,
				FontFace = Font.fromEnum(Enum.Font.FredokaOne),
				Position = UDim2.fromScale(0.075, 0.94),
				Size = UDim2.fromScale(0.82, 0.14),
				Text = if info then info.DisplayName else props.EmojiId,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 9,
				create("UIStroke")({ Thickness = 2 }),
			}),
			create("ImageLabel")({
				Name = "EquippedCheck",
				AnchorPoint = Vector2.new(1, 0),
				BackgroundTransparency = 1,
				Image = "rbxassetid://91966631627808",
				Position = UDim2.fromScale(0.96, 0.04),
				Size = UDim2.fromScale(0.2, 0.2),
				ScaleType = Enum.ScaleType.Fit,
				Visible = props.IsEquipped,
				ZIndex = 10,
				create("UIAspectRatioConstraint")({}),
			}),
		},
	})
end
