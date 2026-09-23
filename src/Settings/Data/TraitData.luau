local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)
local RarityRegistry = require(ReplicatedStorage.Shared.Modules.Core.Rarity.RarityRegistry)

local entries = {
	{
		Name = "Fighter", Rarity = "Common", Chance = 44,
		Image = "rbxassetid://98116220440913",
		Description = "Damage increased by 5%",
		Effects = { { Handler = "DamageMultiflier", Value = 0.05 } },
	},
	{
		Name = "Eye", Rarity = "Common", Chance = 27.5,
		Image = "rbxassetid://81879271401853",
		Description = "Range increased by 7.5%",
		Effects = { { Handler = "RangeMultiflier", Value = 0.075 } },
	},
	{
		Name = "Speed", Rarity = "Rare", Chance = 17,
		Image = "rbxassetid://80975270409639",
		Description = "Cooldown reduced by 5%",
		Effects = { { Handler = "CooldownMultiflier", Value = 0.05 } },
	},
	{
		Name = "Crystal", Rarity = "Epic", Chance = 6.9,
		Image = "rbxassetid://77432475153470",
		Description = "Unit income increased by 10%",
		Effects = { { Handler = "IncomeMultiplier", Value = 0.10 } },
	},
	{
		Name = "Multi", Rarity = "Legendary", Chance = 3.5,
		Image = "rbxassetid://132499122108288",
		Description = "Summoned unit HP increased by 10%",
		Effects = { { Handler = "SummonHealthMultiplier", Value = 0.10 } },
	},
	{
		Name = "Hunter", Rarity = "Mythic", Chance = 0.8,
		Image = "rbxassetid://95946030326540",
		Description = "Damage and range increased by 15%",
		Effects = { { Handler = "DamageMultiflier", Value = 0.15 }, { Handler = "RangeMultiflier", Value = 0.15 } },
	},
	{
		Name = "Dragon", Rarity = "Absolute", Chance = 0.3,
		Image = "rbxassetid://134842199706722",
		Description = "Damage +30%, attack speed -15%, range +15%",
		Effects = { { Handler = "DamageMultiflier", Value = 0.30 }, { Handler = "CooldownMultiflier", Value = 1 - 1 / 0.85 }, { Handler = "RangeMultiflier", Value = 0.15 } },
	},
}

local TraitData = { RollCost = 5, ByName = {}, ByIndex = entries }
local totalWeight = 0
for _, entry in entries do totalWeight += entry.Chance end
assert(math.abs(totalWeight - 100) < 0.000001, "Trait probabilities must total 100%")
for index, entry in entries do
	entry.Index = index
	entry.Color = RarityRegistry.Get(entry.Rarity).Presentation.Color
	entry.Probability = entry.Chance / totalWeight * 100
	TraitData.ByName[entry.Name] = entry
end

-- Retired IDs are migrated at profile load; they are not available in the roll pool.
function TraitData.MigrateOwnedTowers(ownedTowers)
	local replacements = { Power = "Fighter", ["Ember Heart"] = "Hunter", Healing = "Dragon" }
	for _, towers in ownedTowers do
		for _, tower in towers do
			if type(tower) == "table" and replacements[tower.Trait] then
				tower.Trait = replacements[tower.Trait]
			end
		end
	end
end

return TableUtils.DeepFreeze(TraitData)
