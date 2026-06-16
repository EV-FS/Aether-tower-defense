local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)

--/Types
export type ItemInfo = {
	Name: string,
	Rarity: string,
	ItemImage: string,
	Description: string?,
}

export type ItemData = {
	ByName: { [string]: ItemInfo },
}

local RawItemData = {
	["Blaster Gun"] = {
		Rarity = "Legendary",
		ItemImage = "rbxassetid://101679860987414",
		Description = "A powerful energy gun used for crafting high-tech units.",
	},
	["Crown"] = {
		Rarity = "Legendary",
		ItemImage = "rbxassetid://82013737431746",
		Description = "A shiny golden crown representing royal authority.",
	},
	["Emperor's Cloak"] = {
		Rarity = "Mythic",
		ItemImage = "rbxassetid://77361846905595",
		Description = "An elegant cloak worn only by supreme rulers.",
	},
	["Warrior's helmet"] = {
		Rarity = "Rare",
		ItemImage = "rbxassetid://101722065001660",
		Description = "A sturdy iron helmet worn by experienced warriors.",
	},
	["Dual Sword"] = {
		Rarity = "Epic",
		ItemImage = "rbxassetid://111309604603969",
		Description = "A pair of sharp swords that strike with extreme speed.",
	},
} :: { [string]: ItemInfo }

local ItemData = {
	ByName = RawItemData :: { [string]: ItemInfo },
}

for name, data in RawItemData do
	data.Name = name
end

return TableUtils.DeepFreeze(ItemData) :: ItemData
