local Components = require(script.Parent.Parent.Components)

return table.freeze({
	Id = "BlossomCollector",
	Presentation = Components.Presentation(
		"EVENT",
		"BLOSSOM COLLECTOR",
		"Collect 1,500 Blossoms for the Kitsune purification.",
		"WanderingMerchant"
	),
	Objective = Components.CurrencyObjective("Blossom", 1500),
	Lifecycle = Components.Lifecycle(false, false),
	Rewards = Components.Rewards({
		Coins = 5000,
		Gems = 50,
		Exp = 200,
	}),
})
