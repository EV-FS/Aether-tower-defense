local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Slot = require(ReplicatedStorage.UI.Components.Slot)

type Props = {
	CurrencyName: string,
	Amount: () -> number,
	LayoutOrder: number,
	Size: UDim2?,
}

return function(props: Props)
	return Slot({
		Name = `{props.CurrencyName}Reward`,
		Active = false,
		LayoutOrder = props.LayoutOrder,
		Size = props.Size or UDim2.fromScale(0.2, 0.82),
		Visible = function()
			return props.Amount() > 0
		end,
		AssetType = "Currency",
		AssetProps = {
			CurrencyName = props.CurrencyName,
			CurrencyQuantity = props.Amount,
		},
		Rarity = props.CurrencyName,
	})
end
