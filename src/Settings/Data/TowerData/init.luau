local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)
local TowerStats = require(script.TowerStats)

--/Types
export type AttackType = "Single" | "Splash" | "Angle" | "Line"

export type HitConfig = {
	Delay: number,
	AttackType: AttackType?,
	DamageScale: number?,
	Range: number?,
	SplashRange: number?,
	Angle: number?,
	Width: number?,
}

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
		AttackType: AttackType,
	},
}

export type TowerInfo = {
	Name: string,
	Index: number,
	Rarity: string,
	TowerImage: string,
	MaxTowers: number,
	SellPrice: number?,
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
		SellPrice: number?,
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
			TowerImage = "rbxassetid://82740074755423",
			MaxTowers = 6,
		},
		["YoungkkYongSa"] = {
			Index = 3,
			Rarity = "Rare",
			TowerImage = "rbxassetid://88067744482503",
			MaxTowers = 6,
		},
		["Cowboy"] = {
			Index = 4,
			Rarity = "Epic",
			TowerImage = "rbxassetid://126863079208433",
			MaxTowers = 5,
		},
		["Elder Wizard"] = {
			Index = 5,
			Rarity = "Epic",
			TowerImage = "rbxassetid://126863079208433",
			MaxTowers = 5,
		},
		["Lancer"] = {
			Index = 6,
			Rarity = "Epic",
			TowerImage = "rbxassetid://126863079208433",
			MaxTowers = 5,
		},
		["Ganet"] = {
			Index = 7,
			Rarity = "Epic",
			TowerImage = "rbxassetid://126863079208433",
			MaxTowers = 5,
		},
		["장애인해적"] = {
			Index = 8,
			Rarity = "Legendary",
			TowerImage = "rbxassetid://126863079208433",
			MaxTowers = 5,
		},
		["Knight"] = {
			Index = 9,
			Rarity = "Legendary",
			TowerImage = "rbxassetid://126863079208433",
			MaxTowers = 5,
		},
		--[[["어린용사(진화)"] = {
			Index = 10,
			Rarity = "Mythic",
			TowerImage = "rbxassetid://126863079208433",
			MaxTowers = 5,
		},--]]
		["Poseidon"] = {
			Index = 10,
			Rarity = "Mythic",
			TowerImage = "rbxassetid://126863079208433",
			MaxTowers = 5,
		},
		["Emperor"] = {
			Index = 11,
			Rarity = "Mythic",
			TowerImage = "rbxassetid://126863079208433",
			MaxTowers = 5,
		},
		["Chronos"] = {
			Index = 12,
			Rarity = "Mythic",
			TowerImage = "rbxassetid://126863079208433",
			MaxTowers = 2,
		},
		["Wizard"] = {
			Index = 13,
			Rarity = "Absolute",
			TowerImage = "rbxassetid://127595189045553",
			MaxTowers = 2,
		},
		["Kitsune Samurai"] = {
			Index = 14,
			Rarity = "Absolute",
			TowerImage = "rbxassetid://127595189045553",
			MaxTowers = 3,
		},
		["Galahad"] = {
			Index = 15,
			Rarity = "Absolute",
			TowerImage = "rbxassetid://127595189045553",
			MaxTowers = 3,
		},
		["Dragon Slayer"] = {
			Index = 16,
			Rarity = "Absolute",
			TowerImage = "rbxassetid://127595189045553",
			MaxTowers = 1,
		},
		["Onion_fire18"] = {
			Index = 18,
			Rarity = "Absolute",
			TowerImage = "rbxassetid://130148747698173",
			MaxTowers = 1818,
			SellPrice = 1818,
		},
		["Saint"] = {
			Index = 19,
			Rarity = "Mythic",
			TowerImage = "rbxassetid://130148747698173",
			MaxTowers = 2,
		},
		["Ranger Super Tower"] = {
			Index = 31,
			Rarity = "Absolute",
			TowerImage = "rbxassetid://127595189045553",
			MaxTowers = 1,
		},
		["dingding"] = {
			Index = 32,
			Rarity = "Absolute",
			TowerImage = "rbxassetid://101401673871794",
			MaxTowers = 64,
			SellPrice = 32,
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
