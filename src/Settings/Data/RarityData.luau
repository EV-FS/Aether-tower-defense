local TableUtils = require(script.Parent.Parent.Parent.Shared.Modules.Utils.TableUtils)

return TableUtils.DeepFreeze({
	DisplayNames = {
		Common = "Common",
		Uncommon = "Common",
		Rare = "Rare",
		Epic = "Epic",
		Legendary = "Legendary",
		Mythic = "Mythic",
		Exclusive = "Exclusive",
		Absolute = "Absolute",
	},
})
