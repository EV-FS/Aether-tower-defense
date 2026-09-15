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
	-- Every recipe consumes inventory items and produces another inventory item.
	-- Item visuals and descriptions are configured in ItemData.luau.
	["Emperor's Cloak"] = {
		ResultName = "Emperor's Cloak",
		ResultAmount = 1,
		Ingredients = {
			{ Name = "Crown", Amount = 1 },
			{ Name = "Warrior's helmet", Amount = 2 },
		},
	},
	["Dual Sword"] = {
		ResultName = "Dual Sword",
		ResultAmount = 1,
		Ingredients = {
			{ Name = "Blaster Gun", Amount = 1 },
			{ Name = "Warrior's helmet", Amount = 1 },
		},
	},
}

return TableUtils.DeepFreeze(CraftRecipes)
