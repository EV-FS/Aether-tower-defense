local Components = require(script.Parent.Parent.Components)

return table.freeze({
	Id = "Chapter1Clear",
	Presentation = Components.Presentation(
		"GUIDE",
		"FIRST ADVENTURE",
		"Clear Chapter 1."
	),
	Objective = Components.MapClearObjective("Chapter 1"),
	Lifecycle = Components.Lifecycle(true, true),
	Rewards = Components.Rewards({
		Coins = 500,
		Gems = 5,
		Exp = 100,
	}),
})
