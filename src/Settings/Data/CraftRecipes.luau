--/Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--/Modules
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)

--/Types
export type Ingredient = {
	Name: string,
	Amount: number,
}

export type Recipe = {
	ResultName: string,
	ResultAmount: number,
	ResultType: string?,
	Ingredients: { Ingredient },
	Currencies: { [string]: number }?,
}

-------------------------------------------------
--// CraftRecipes
-------------------------------------------------
local CraftRecipes: { [string]: Recipe } = {
	-- Item results and ingredients must exist in ItemData; tower results must exist in TowerData.
	["Gold"] = {
		ResultName = "Gold",
		ResultAmount = 1,
		Ingredients = {
			{ Name = "Iron", Amount = 5 },
		},
	},
	["Dragon's Heart"] = {
		ResultName = "Dragon's Heart",
		ResultAmount = 1,
		Ingredients = {
			{ Name = "Gold", Amount = 5 },
		},
	},
	["Dragon Slayer"] = {
		ResultName = "Dragon Slayer",
		ResultType = "Tower",
		ResultAmount = 1,
		Ingredients = {
			{ Name = "Dragon's Breath", Amount = 1 },
			{ Name = "Sword Jam", Amount = 1 },
			{ Name = "Dragon's Heart", Amount = 1 },
			{ Name = "Dragon Sword", Amount = 1 },
			{ Name = "ShardStone", Amount = 15 },
			{ Name = "Iron", Amount = 75 },
			{ Name = "Diamond", Amount = 500 },
		},
		Currencies = { Coins = 25_000 },
	},
}

return TableUtils.DeepFreeze(CraftRecipes)
