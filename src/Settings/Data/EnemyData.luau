local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)

local RawEnemyData = {
	["Goblin"] = {
		Index = 1,
		MaxHealth = 40,
		WalkSpeed = 3.5,
	},
	["Red Goblin"] = {
		Index = 2,
		MaxHealth = 30,
		WalkSpeed = 7,
	},
	["Golden Goblin"] = {
		Index = 3,
		MaxHealth = 70,
		WalkSpeed = 6,
	},
	["Big Goblin"] = {
		Index = 4,
		MaxHealth = 350,
		WalkSpeed = 3,
	},
	["Necromancer Goblin"] = {
		Index = 5,
		MaxHealth = 5_000,
		WalkSpeed = 2,
		SummonCooldown = 7,
		SummonCount = 3,
		MinionName = "Big Goblin",
	},
	["Goblin Warrior"] = {
		Index = 6,
		MaxHealth = 4_500,
		WalkSpeed = 2.5,
	},
	["Smith Goblin"] = {
		Index = 7,
		MaxHealth = 5_500,
		WalkSpeed = 2.5,
	},
	["Elite Goblin"] = {
		Index = 8,
		MaxHealth = 30_000,
		WalkSpeed = 2,
	},
	["King Goblin"] = {
		Index = 9,
		MaxHealth = 55_000,
		WalkSpeed = 2,
	},
	["Elite Tanker Goblin"] = {
		Index = 10,
		MaxHealth = 60_000,
		WalkSpeed = 3.5,
	},
	["Ogre Goblin"] = {
		Index = 11,
		MaxHealth = 400_000,
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
