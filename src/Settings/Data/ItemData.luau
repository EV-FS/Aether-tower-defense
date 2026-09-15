local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)

--/Types
export type ItemInfo = {
	Name: string,
	Index: number,
	Rarity: string,
	ItemImage: string,
	Description: string?,
}

export type ItemData = {
	ByName: { [string]: ItemInfo },
	ByIndex: { [number]: ItemInfo },
}

local RawItemData = {
	["Blaster Gun"] = {
		Index = 1,
		Rarity = "Legendary",
		ItemImage = "rbxassetid://101679860987414",
		Description = "A powerful energy gun used for crafting high-tech units.",
	},
	["Crown"] = {
		Index = 2,
		Rarity = "Legendary",
		ItemImage = "rbxassetid://82013737431746",
		Description = "A shiny golden crown representing royal authority.",
	},
	["Emperor's Cloak"] = {
		Index = 3,
		Rarity = "Mythic",
		ItemImage = "rbxassetid://77361846905595",
		Description = "An elegant cloak worn only by supreme rulers.",
	},
	["Warrior's helmet"] = {
		Index = 4,
		Rarity = "Rare",
		ItemImage = "rbxassetid://101722065001660",
		Description = "A sturdy iron helmet worn by experienced warriors.",
	},
	["Dual Sword"] = {
		Index = 5,
		Rarity = "Epic",
		ItemImage = "rbxassetid://111309604603969",
		Description = "A pair of sharp swords that strike with extreme speed.",
	},
	["Event Chest"] = {
		Index = 6,
		Rarity = "Epic",
		ItemImage = "rbxassetid://74082959709680",
		Description = "A limited chest purchased from the Wandering Merchant.",
	},
	["Premium Event Chest"] = {
		Index = 7,
		Rarity = "Mythic",
		ItemImage = "rbxassetid://74082959709680",
		Description = "A premium chest containing rarer Kitsune event rewards.",
	},
	["Kitsune Emoticon"] = {
		Index = 8,
		Rarity = "Exclusive",
		ItemImage = "rbxassetid://74082959709680",
		Description = "A limited emoticon from the Kitsune event.",
	},
	["Kitsune Unit Frame"] = {
		Index = 9,
		Rarity = "Exclusive",
		ItemImage = "rbxassetid://103789559110745",
		Description = "A limited Kitsune-themed unit frame.",
	},
	["Maid Kitsune"] = {
		Index = 10,
		Rarity = "Exclusive",
		ItemImage = "rbxassetid://74082959709680",
		Description = "A limited Maid Kitsune skin.",
	},
} :: { [string]: ItemInfo }

local ItemData = {
	ByName = RawItemData :: { [string]: ItemInfo },
	ByIndex = {} :: { [number]: ItemInfo },
}

for name, data in RawItemData do
	data.Name = name
	assert(ItemData.ByIndex[data.Index] == nil, `Duplicate item index: {data.Index}`)
	ItemData.ByIndex[data.Index] = data :: ItemInfo
end

return TableUtils.DeepFreeze(ItemData) :: ItemData
