local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)
local RarityRegistry = require(ReplicatedStorage.Shared.Modules.Core.Rarity.RarityRegistry)

local Prices = {
	Common = 25,
	Rare = 50,
	Epic = 100,
	Legendary = 250,
	Mythic = 750,
	Absolute = 1_500,
	Secret = 3_000,
}

local Rarities = {}
local ByRarity = {}
for order, rarity in RarityRegistry.ProgressionOrder do
	local entry = {
		Name = rarity,
		SettingName = `AS_{rarity}`,
		Price = Prices[rarity],
		Order = order,
	}
	table.insert(Rarities, entry)
	ByRarity[entry.Name] = entry
end

return TableUtils.DeepFreeze({
	Rarities = Rarities,
	ByRarity = ByRarity,
})
