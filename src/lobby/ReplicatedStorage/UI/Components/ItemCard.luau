local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local ItemData = require(ReplicatedStorage.Settings.Data.ItemData)
local CardFrame = require(ReplicatedStorage.UI.Components.Card.CardFrame)
local CardName = require(ReplicatedStorage.UI.Components.Card.CardName)
local CardQuantity = require(ReplicatedStorage.UI.Components.Card.CardQuantity)

local create = Vide.create

export type Props = {
	ItemName: string,
	Count: number,
	Category: string,
	LayoutOrder: number | (() -> number),
	IsSelected: () -> boolean,
	Activated: () -> (),
}

return function(props: Props)
	local info = ItemData.ByName[props.ItemName] or {
		Rarity = if props.Category == "Skin" then "Secret" else "Common",
		ItemImage = "",
	}

	return CardFrame({
		Name = props.ItemName,
		Active = true,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.fromScale(0.239841, 0.354932),
		CornerRadius = UDim.new(0.06, 0),
		Rarity = info.Rarity,
		Selected = props.IsSelected,
		ShimmerEnabled = false,
		GlowEnabled = false,
		RarityBorderEnabled = false,
		PressedScale = 0.96,
		HoverScale = 1.025,
		HoverEnabled = false,
		Activated = props.Activated,
		Content = {
			create("UIAspectRatioConstraint")({ Name = "UIAspectRatioConstraint" }),
			create("ImageLabel")({
				Name = "Item",
				BackgroundTransparency = 1,
				Image = info.ItemImage or "",
				Position = UDim2.fromScale(0.11, 0.102),
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromScale(0.784, 0.66),
				ZIndex = 5,
			}),
			CardQuantity({ Text = `{props.Count}x` }),
			CardName({ Text = props.ItemName, Name = "ItemName" }),
		},
	})
end
