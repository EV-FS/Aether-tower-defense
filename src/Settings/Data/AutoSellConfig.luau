local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)

-- Absolute is intentionally excluded. The highest summon tier should never be
-- removed by a broad convenience setting without a separate confirmation flow.
local Rarities = {
	{ Name = "Common", SettingName = "AS_Common", Price = 25 },
	{ Name = "Rare", SettingName = "AS_Rare", Price = 50 },
	{ Name = "Epic", SettingName = "AS_Epic", Price = 100 },
	{ Name = "Legendary", SettingName = "AS_Legendary", Price = 250 },
	{ Name = "Mythic", SettingName = "AS_Mythic", Price = 750 },
	{ Name = "Secret", SettingName = "AS_Secret", Price = 1_500 },
}

local ByRarity = {}
for order, entry in Rarities do
	entry.Order = order
	ByRarity[entry.Name] = entry
end

return TableUtils.DeepFreeze({
	Rarities = Rarities,
	ByRarity = ByRarity,
})
