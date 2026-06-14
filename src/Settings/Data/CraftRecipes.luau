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
	["Cowboy"] = {
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
	["Emperor Noob"] = {
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
}

return TableUtils.DeepFreeze(CraftRecipes)
