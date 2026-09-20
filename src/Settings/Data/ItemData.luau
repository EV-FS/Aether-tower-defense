local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)
local RarityData = require(ReplicatedStorage.Settings.Data.RarityData)

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
	["Iron"] = {
		Index = 11,
		Rarity = "Rare",
		ItemImage = "rbxassetid://121958957894369",
		Description = "A sturdy piece of iron used for crafting various items.",
	},
	["Gold"] = {
		Index = 12,
		Rarity = "Legendary",
		ItemImage = "rbxassetid://120030689917508",
		Description = "A precious metal that can be used to craft powerful items.",
	},
	["Dragon's Heart"] = {
		Index = 13,
		Rarity = "Secret",
		ItemImage = "rbxassetid://127171900014847",
		Description = "A rare and mystical item, said to contain the essence of a dragon's soul.",
	},
} :: { [string]: ItemInfo }

local ItemData = {
	ByName = RawItemData :: { [string]: ItemInfo },
	ByIndex = {} :: { [number]: ItemInfo },
}

for name, data in RawItemData do
	data.Name = name
	assert(RarityData.IsValid(data.Rarity), `Invalid rarity "{data.Rarity}" for item "{name}"`)
	assert(ItemData.ByIndex[data.Index] == nil, `Duplicate item index: {data.Index}`)
	ItemData.ByIndex[data.Index] = data :: ItemInfo
end

return TableUtils.DeepFreeze(ItemData) :: ItemData
