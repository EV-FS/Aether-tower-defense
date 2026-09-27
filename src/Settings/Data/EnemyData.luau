local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)

local RawEnemyData = {
	["Goblin"] = {
		Index = 1,
		MaxHealth = 4,
		WalkSpeed = 6,
	},
	["Red Goblin"] = {
		Index = 2,
		MaxHealth = 4,
		WalkSpeed = 10,
	},
	["Golden Goblin"] = {
		Index = 3,
		MaxHealth = 8,
		WalkSpeed = 8,
	},
	["Big Goblin"] = {
		Index = 4,
		MaxHealth = 30,
		WalkSpeed = 5,
	},
	["Goblin Warrior"] = {
		Index = 5,
		MaxHealth = 400,
		WalkSpeed = 3,
	},
	["Necromancer Goblin"] = {
		Index = 6,
		MaxHealth = 500,
		WalkSpeed = 2.5,
		SummonCooldown = 5,
		SummonCount = 2,
		MinionName = "Skeleton",
	},
	["Smith Goblin"] = {
		Index = 7,
		MaxHealth = 750,
		WalkSpeed = 3.5,
	},
	["Elite Goblin"] = {
		Index = 8,
		MaxHealth = 2000,
		WalkSpeed = 2.5,
	},
	["King Goblin"] = {
		Index = 9,
		MaxHealth = 4_500,
		WalkSpeed = 2,
	},
	["Elite Tanker Goblin"] = {
		Index = 10,
		MaxHealth = 8_500,
		WalkSpeed = 3.5,
	},
	["Ogre Goblin"] = {
		Index = 11,
		MaxHealth = 50_000,
		WalkSpeed = 1.5,
	},
	["Skeleton"] = {
		Index = 12,
		MaxHealth = 50,
		WalkSpeed = 3,
	},
	["JiangShi"] = {
		Index = 13,
		MaxHealth = 10,
		WalkSpeed = 4,
	},
	["Wraith"] = {
		Index = 14,
		MaxHealth = 15,
		WalkSpeed = 5,
	},
	["Soul"] = {
		Index = 15,
		MaxHealth = 35,
		WalkSpeed = 7,
	},
	["Speedy Soul"] = {
		Index = 16,
		MaxHealth = 45,
		WalkSpeed = 12,
	},
	["Crystal"] = {
		Index = 17,
		MaxHealth = 5,
		WalkSpeed = 6,
	},
	["Crystal Spider"] = {
		Index = 18,
		MaxHealth = 6,
		WalkSpeed = 8,
	},
	["Theif"] = {
		Index = 19,
		MaxHealth = 15,
		WalkSpeed = 10,
	},
	["Butcher"] = {
		Index = 20,
		MaxHealth = 200,
		WalkSpeed = 4,
	},
	["Crystal Guardian"] = {
		Index = 21,
		MaxHealth = 750,
		WalkSpeed = 4,
	},
	["Carnage"] = {
		Index = 22,
		MaxHealth = 2000,
		WalkSpeed = 3.5,
	},
	["Giant Skull"] = {
		Index = 23,
		MaxHealth = 10000,
		WalkSpeed = 3,
	},
	["Crystal Golem"] = {
		Index = 24,
		MaxHealth = 125000,
		WalkSpeed = 1.5,
	},
}

local EnemyData = {
	ByName = RawEnemyData,
	ByIndex = {},
}

for name, data in pairs(RawEnemyData) do
	data.Name = name

	EnemyData.ByIndex[data.Index] = data
end

return TableUtils.DeepFreeze(EnemyData)
