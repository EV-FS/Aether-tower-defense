--/Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--/Modules
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)

--/Types
export type ItemType = "Tower" | "Item" | "Currency"
export type Ingredient = {
	Type: ItemType,
	Name: string,
	Amount: number,
}

export type Recipe = {
	ResultType: ItemType,
	ResultName: string,
	ResultAmount: number,

	Ingredients: { Ingredient },
}

-------------------------------------------------
--// CraftRecipes
-------------------------------------------------
local CraftRecipes: { [string]: Recipe } = {
	["Mecha Demian"] = {
		ResultType = "Tower",
		ResultName = "Mecha Demian",
		ResultAmount = 1,

		Ingredients = {
			{ Type = "Item", Name = "Blaster Gun", Amount = 1 },
			{ Type = "Tower", Name = "Mecha Fist", Amount = 1 },
			{ Type = "Tower", Name = "Mecha", Amount = 10 },
			{ Type = "Currency", Name = "Coins", Amount = 7500 },
		},
	},
	["Cowboy Dummy"] = {
		ResultType = "Tower",
		ResultName = "Cowboy Dummy",
		ResultAmount = 1,

		Ingredients = {
			{ Type = "Item", Name = "Blaster Gun", Amount = 1 },
			{ Type = "Tower", Name = "Mecha Fist", Amount = 1 },
			{ Type = "Tower", Name = "Mecha", Amount = 10 },
			{ Type = "Currency", Name = "Coins", Amount = 7500 },
		},
	},
	["Emperor Noob"] = {
		ResultType = "Tower",
		ResultName = "Emperor Noob",
		ResultAmount = 1,

		Ingredients = {
			{ Type = "Item", Name = "Crown", Amount = 1 },
			{ Type = "Item", Name = "Emperor's Cloak", Amount = 1 },
			{ Type = "Tower", Name = "King Noob", Amount = 5 },
			{ Type = "Currency", Name = "Coins", Amount = 5000 },
		},
	},
	["Sword Master Dummy"] = {
		ResultType = "Tower",
		ResultName = "Sword Master Dummy",
		ResultAmount = 1,

		Ingredients = {
			{ Type = "Item", Name = "Blaster Gun", Amount = 1 },
			{ Type = "Tower", Name = "Mecha Fist", Amount = 1 },
			{ Type = "Tower", Name = "Mecha", Amount = 10 },
			{ Type = "Currency", Name = "Coins", Amount = 7500 },
		},
	},
	["Dual Sword"] = {
		ResultType = "Item",
		ResultName = "Dual Sword",
		ResultAmount = 1,

		Ingredients = {
			{ Type = "Tower", Name = "Swordsman Dummy", Amount = 10 },
		},
	},
}

return TableUtils.DeepFreeze(CraftRecipes)
