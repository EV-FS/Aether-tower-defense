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
	Ingredients: { Ingredient },
}

-------------------------------------------------
--// CraftRecipes
-------------------------------------------------
local CraftRecipes: { [string]: Recipe } = {
	-- Add recipes here only when both the result and every ingredient exist in ItemData.
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
}

return TableUtils.DeepFreeze(CraftRecipes)
