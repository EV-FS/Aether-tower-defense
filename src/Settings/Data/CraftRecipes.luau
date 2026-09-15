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
<<<<<<< HEAD
			{ Name = "Crown", Amount = 1 },
			{ Name = "Warrior's helmet", Amount = 2 },
		},
	},
	["Dual Sword"] = {
		ResultName = "Dual Sword",
=======
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
>>>>>>> parent of b55c1aa (어드민타워 적용 딩딩과 18키로)
		ResultAmount = 1,
		Ingredients = {
<<<<<<< HEAD
			{ Name = "Blaster Gun", Amount = 1 },
			{ Name = "Warrior's helmet", Amount = 1 },
=======
			{ Type = "Item", Name = "Blaster Gun", Amount = 1 },
			{ Type = "Tower", Name = "Mecha Fist", Amount = 1 },
			{ Type = "Tower", Name = "Mecha", Amount = 10 },
			{ Type = "Currency", Name = "Coins", Amount = 7500 },
>>>>>>> parent of b55c1aa (어드민타워 적용 딩딩과 18키로)
		},
	},
}

return TableUtils.DeepFreeze(CraftRecipes)
