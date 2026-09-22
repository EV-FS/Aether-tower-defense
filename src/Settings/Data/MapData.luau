local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)

--/Types
export type Difficulty = "Normal" | "Hard" | "Eternal"

export type RewardDetail = {
	WinCoins: number,
	WinExp: number,
	WinGems: number,
	LoseCoinsPerWave: number,
	LoseExpPerWave: number,
}

export type MapInfo = {
	MapImage: string,
	IntroCutscene: string?,
	Difficulties: { Difficulty },
	DifficultyWaves: { [Difficulty]: number },
	Rewards: { [Difficulty]: RewardDetail },
}

export type MapData = { [string]: MapInfo }

local DEFAULT_DIFFICULTIES: { Difficulty } = {
	"Normal",
	"Hard",
	"Eternal",
}

return TableUtils.DeepFreeze({
	["Chapter 1"] = {
		MapName = "Chapter 1 - Goblin Cave",
		MapImage = "rbxassetid://139254798620970",
		LayoutOrder = 1,
		Difficulties = DEFAULT_DIFFICULTIES,
		DifficultyWaves = {
			Normal = 20,
			Hard = 30,
			Eternal = 40,
		},

		Rewards = {
			Easy = {
				WinCoins = 150,
				WinExp = 50,
				WinGems = 0,
				LoseCoinsPerWave = 10,
				LoseExpPerWave = 3,
			},
			Normal = {
				WinCoins = 300,
				WinExp = 100,
				WinGems = 0,
				LoseCoinsPerWave = 15,
				LoseExpPerWave = 5,
			},
			Hard = {
				WinCoins = 700,
				WinExp = 150,
				WinGems = 0,
				LoseCoinsPerWave = 20,
				LoseExpPerWave = 6,
			},
			Extreme = {
				WinCoins = 1200,
				WinExp = 200,
				WinGems = 1,
				LoseCoinsPerWave = 25,
				LoseExpPerWave = 8,
			},
			Eternal = {
				WinCoins = 4000,
				WinExp = 300,
				WinGems = 5,
				LoseCoinsPerWave = 30,
				LoseExpPerWave = 10,
			},
		},
	},
	["Chapter 2"] = {
		MapName = "Chapter 2 - Monster Canyon",
		MapImage = "rbxassetid://139254798620970",
		LayoutOrder = 2,
		Difficulties = DEFAULT_DIFFICULTIES,
		DifficultyWaves = {
			Normal = 20,
			Hard = 30,
			Eternal = 40,
		},

		Rewards = {
			Easy = {
				WinCoins = 150,
				WinExp = 50,
				WinGems = 0,
				LoseCoinsPerWave = 10,
				LoseExpPerWave = 3,
			},
			Normal = {
				WinCoins = 300,
				WinExp = 100,
				WinGems = 0,
				LoseCoinsPerWave = 15,
				LoseExpPerWave = 5,
			},
			Hard = {
				WinCoins = 700,
				WinExp = 150,
				WinGems = 0,
				LoseCoinsPerWave = 20,
				LoseExpPerWave = 6,
			},
			Extreme = {
				WinCoins = 1200,
				WinExp = 200,
				WinGems = 1,
				LoseCoinsPerWave = 25,
				LoseExpPerWave = 8,
			},
			Eternal = {
				WinCoins = 4000,
				WinExp = 300,
				WinGems = 5,
				LoseCoinsPerWave = 30,
				LoseExpPerWave = 10,
			},
		},
	},

	["Kitsune Raid"] = {
		MapName = "Kitsune Raid",
		MapImage = "rbxassetid://139254798620970",
		LayoutOrder = 3,
		Difficulties = {
			"Normal",
		},
		DifficultyWaves = {
			Normal = 30,
		},

		Rewards = {
			Easy = {
				WinCoins = 150,
				WinExp = 50,
				WinGems = 0,
				LoseCoinsPerWave = 10,
				LoseExpPerWave = 3,
			},
			Normal = {
				WinCoins = 300,
				WinExp = 100,
				WinGems = 0,
				LoseCoinsPerWave = 15,
				LoseExpPerWave = 5,
			},
			Hard = {
				WinCoins = 700,
				WinExp = 150,
				WinGems = 0,
				LoseCoinsPerWave = 20,
				LoseExpPerWave = 6,
			},
			Extreme = {
				WinCoins = 1200,
				WinExp = 200,
				WinGems = 1,
				LoseCoinsPerWave = 25,
				LoseExpPerWave = 8,
			},
			Eternal = {
				WinCoins = 4000,
				WinExp = 300,
				WinGems = 5,
				LoseCoinsPerWave = 30,
				LoseExpPerWave = 10,
			},
		},
	},
	["Raid"] = {
		IntroCutscene = "RaidIntro",
		MapImage = "rbxassetid://139254798620970",
		LayoutOrder = 4,
		Difficulties = {
			"Normal",
		},
		DifficultyWaves = {
			Normal = 30,
		},

		Rewards = {
			Easy = {
				WinCoins = 150,
				WinExp = 50,
				WinGems = 0,
				LoseCoinsPerWave = 10,
				LoseExpPerWave = 3,
			},
			Normal = {
				WinCoins = 300,
				WinExp = 100,
				WinGems = 0,
				LoseCoinsPerWave = 15,
				LoseExpPerWave = 5,
			},
			Hard = {
				WinCoins = 700,
				WinExp = 150,
				WinGems = 0,
				LoseCoinsPerWave = 20,
				LoseExpPerWave = 6,
			},
			Extreme = {
				WinCoins = 1200,
				WinExp = 200,
				WinGems = 1,
				LoseCoinsPerWave = 25,
				LoseExpPerWave = 8,
			},
			Eternal = {
				WinCoins = 4000,
				WinExp = 300,
				WinGems = 5,
				LoseCoinsPerWave = 30,
				LoseExpPerWave = 10,
			},
		},
	},
}) :: MapData
