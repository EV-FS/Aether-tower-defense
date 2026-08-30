local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)
local TowerStats = require(script.TowerStats)

--/Types
export type SummonUnitInfo = {
	SummonUnit: string,
	SummonCooldown: number,
	SummonDelay: number?,
	UnitStats: {
		MaxHealth: number,
		Damage: number,
		Cooldown: number,
		Range: number,
		StopWhenAttacking: boolean,
		AttackDelay: number,
		AttackType: string,
	},
}

export type TowerInfo = {
	Name: string,
	Index: number,
	Rarity: string,
	TowerImage: string,
	MaxTowers: number,
	Stats: { [number]: { [string]: any } },
}

export type TowerData = {
	ByName: { [string]: TowerInfo },
	ByIndex: { [number]: TowerInfo },
}

local RawTowerData: {
	[string]: {
		Index: number,
		Rarity: string,
		TowerImage: string,
		MaxTowers: number,
		Stats: { [number]: { [string]: any } }?,
		Name: string?,
	},
} =
	{
		["Fighter"] = {
			Index = 1,
			Rarity = "Common",
			TowerImage = "rbxassetid://96421319964530",
			MaxTowers = 12,
		},
		["Harvester"] = {
			Index = 2,
			Rarity = "Common",
			TowerImage = "rbxassetid://96421319964530",
			MaxTowers = 8,
		},
		["Eolin-yongsa"] = {
			Index = 3,
			Rarity = "Rare",
			TowerImage = "rbxassetid://96421319964530",
			MaxTowers = 12,
		},
		["Cowboy"] = {
			Index = 4,
			Rarity = "Epic",
			TowerImage = "rbxassetid://96421319964530",
			MaxTowers = 6,
		},
		["Wizard"] = {
			Index = 67,
			Rarity = "Absolute",
			TowerImage = "rbxassetid://127595189045553",
			MaxTowers = 2,
		},
		["Galahad"] = {
			Index = 11,
			Rarity = "Absolute",
			TowerImage = "rbxassetid://127595189045553",
			MaxTowers = 4,
		},
		["Ranger Super Tower"] = {
			Index = 67,
			Rarity = "Absolute",
			TowerImage = "rbxassetid://127595189045553",
			MaxTowers = 1,
		},
	}

for towerName, towerData in RawTowerData do
	local targetStats = TowerStats[towerName]
	if not targetStats then
		continue
	end

	towerData.Stats = targetStats
end

local TowerData = {
	ByName = RawTowerData :: { [string]: TowerInfo },
	ByIndex = {} :: { [number]: TowerInfo },
}

for name, data in RawTowerData do
	data.Name = name

	TowerData.ByIndex[data.Index] = data :: TowerInfo
end

return TableUtils.DeepFreeze(TowerData) :: TowerData
