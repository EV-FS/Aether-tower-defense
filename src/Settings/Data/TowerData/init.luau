local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)
local TowerStats = require(script.TowerStats)

<<<<<<< HEAD
local RawTowerData = {
	["Bacon"] = {
		Index = 1,
		Rarity = "Common",
		TowerImage = "rbxassetid://120964210405701",
		MaxTowers = 10,
	},
	["Batter Bacon"] = {
		Index = 2,
		Rarity = "Uncommon",
		TowerImage = "rbxassetid://101722065001660",
		MaxTowers = 5,
	},
	["Fighter Noob"] = {
		Index = 3,
		Rarity = "Uncommon",
		TowerImage = "rbxassetid://96421319964530",
		MaxTowers = 6,
	},
	["Cyborg Dummy"] = {
		Index = 4,
		Rarity = "Mythic",
		TowerImage = "rbxassetid://139911403374399",
		MaxTowers = 2,
	},
	["Dummy"] = {
		Index = 5,
		Rarity = "Common",
		TowerImage = "rbxassetid://100475259212197",
		MaxTowers = 10,
	},
	["Hacker"] = {
		Index = 6,
		Rarity = "Absolute",
		TowerImage = "rbxassetid://76888510287982",
		MaxTowers = 3,
	},
	["Gunner Dummy"] = {
		Index = 7,
		Rarity = "Rare",
		TowerImage = "rbxassetid://122275683628692",
		MaxTowers = 6,
	},
	["Katana Noob"] = {
		Index = 8,
		Rarity = "Rare",
		TowerImage = "rbxassetid://111309604603969",
		MaxTowers = 5,
	},
	["King Noob"] = {
		Index = 9,
		Rarity = "Legendary",
		TowerImage = "rbxassetid://82013737431746",
		MaxTowers = 3,
	},
	["Minigunner Dummy"] = {
		Index = 10,
		Rarity = "Legendary",
		TowerImage = "rbxassetid://136315237541072",
		MaxTowers = 3,
	},
	["Noob"] = {
		Index = 11,
		Rarity = "Common",
		TowerImage = "rbxassetid://82308800052558",
		MaxTowers = 10,
	},
	["Poor Bacon"] = {
		Index = 12,
		Rarity = "Epic",
		TowerImage = "rbxassetid://91237371309389",
		MaxTowers = 4,
	},
	["Poseidon Noob"] = {
		Index = 13,
		Rarity = "Mythic",
		TowerImage = "rbxassetid://82847297421685",
		MaxTowers = 2,
	},
	["Laser Noob"] = {
		Index = 14,
		Rarity = "Mythic",
		TowerImage = "rbxassetid://71445703716084",
		MaxTowers = 2,
	},
	["RPG Noob"] = {
		Index = 15,
		Rarity = "Legendary",
		TowerImage = "rbxassetid://101679860987414",
		MaxTowers = 3,
	},
	["Scyther Dummy"] = {
		Index = 16,
		Rarity = "Uncommon",
		TowerImage = "rbxassetid://82740074755423",
		MaxTowers = 4,
	},
	["Sword Master Dummy"] = {
		Index = 18,
		Rarity = "Epic",
		TowerImage = "rbxassetid://97665280501423",
		MaxTowers = 4,
	},
	["Swordsman Dummy"] = {
		Index = 19,
		Rarity = "Uncommon",
		TowerImage = "rbxassetid://126863079208433",
		MaxTowers = 5,
	},
	["Titan Bacon"] = {
		Index = 20,
		Rarity = "Exclusive",
		TowerImage = "rbxassetid://76651098122760",
		MaxTowers = 2,
	},
	["Titan Dummy"] = {
		Index = 21,
		Rarity = "Exclusive",
		TowerImage = "rbxassetid://96925016440567",
		MaxTowers = 2,
	},
	["Titan Glitch"] = {
		Index = 22,
		Rarity = "Absolute",
		TowerImage = "rbxassetid://120632749560376",
		MaxTowers = 1,
	},
	["Titan Noob"] = {
		Index = 23,
		Rarity = "Exclusive",
		TowerImage = "rbxassetid://111862232891362",
		MaxTowers = 2,
	},
	["Lancer Dummy"] = {
		Index = 24,
		Rarity = "Epic",
		TowerImage = "rbxassetid://123924919401262",
		MaxTowers = 3,
	},
	["Mecha Demian"] = {
		Index = 25,
		Rarity = "Absolute",
		TowerImage = "rbxassetid://76385185084113",
		MaxTowers = 1,
	},
	["Mecha Fist"] = {
		Index = 26,
		Rarity = "Mythic",
		TowerImage = "rbxassetid://131633537645734",
		MaxTowers = 2,
	},
	["Cowboy Dummy"] = {
		Index = 27,
		Rarity = "Absolute",
		TowerImage = "rbxassetid://109654149961084",
		MaxTowers = 3,
	},
	["Emperor Noob"] = {
		Index = 28,
		Rarity = "Mythic",
		TowerImage = "rbxassetid://77361846905595",
		MaxTowers = 2,
	},
	["Bomb"] = {
		Index = 29,
		Rarity = "Exclusive",
		TowerImage = "rbxassetid://85951254264036",
		MaxTowers = 2,
	},
	["Wizard Noob"] = {
		Index = 30,
		Rarity = "Absolute",
		TowerImage = "rbxassetid://127595189045553",
		MaxTowers = 2,
=======
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
>>>>>>> e39fe9f2014e9526e8e2313cb3547d99142b2e82
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
		["Ranger Super Tower"] = {
			Index = 31,
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
