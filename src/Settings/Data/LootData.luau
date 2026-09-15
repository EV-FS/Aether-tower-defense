--/Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--/Modules
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)

--/Types

export type Data = {}

-------------------------------------------------
--// LootData
-------------------------------------------------
local LootData: { [string]: Data } = {
	["Golden Goblin"] = {
		{ ItemName = "Gold", Chance = 0.10, MinAmount = 1, MaxAmount = 1 },
	},
	["King Goblin"] = {
		{ ItemName = "Crown", Chance = 0.03, MinAmount = 1, MaxAmount = 1 },
		{ ItemName = "Emperor's Cloak", Chance = 0.05, MinAmount = 1, MaxAmount = 1 },
	},
	["Elite Goblin"] = {
		{ ItemName = "Warrior's helmet", Chance = 0.08, MinAmount = 1, MaxAmount = 1 },
	},
}

return TableUtils.DeepFreeze(LootData)
