return {
	Name = "AddItem",
	Aliases = { "ai", "giveitem", "gi" },
	Description = "Adds a material item to a player's inventory.",
	Group = "Admin",

	Args = {
		{
			Type = "player",
			Name = "Player",
			Description = "Player who will receive the item.",
		},
		{
			Type = "string",
			Name = "ItemName",
			Description = "Exact item name. Use quotes when the name contains spaces.",
		},
		{
			Type = "integer",
			Name = "Amount",
			Description = "Positive amount to add.",
		},
	},
}
