local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)

local DEFAULT_DIFFICULTIES = {
	"Easy",
	"Normal",
	"Hard",
	"Extreme",
	"Eternal",
}

return TableUtils.DeepFreeze({
	["Chapter 1"] = {
		MapImage = "rbxassetid://139254798620970",
		Difficulties = DEFAULT_DIFFICULTIES,
		DifficultyWaves = {
			Easy = 15,
			Normal = 20,
			Hard = 25,
			Extreme = 30,
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
		MapImage = "rbxassetid://110942856285140",
		Difficulties = DEFAULT_DIFFICULTIES,
		DifficultyWaves = {
			Easy = 15,
			Normal = 20,
			Hard = 25,
			Extreme = 30,
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
				WinCoins = 550,
				WinExp = 150,
				WinGems = 0,
				LoseCoinsPerWave = 20,
				LoseExpPerWave = 6,
			},
			Extreme = {
				WinCoins = 800,
				WinExp = 200,
				WinGems = 1,
				LoseCoinsPerWave = 25,
				LoseExpPerWave = 8,
			},
			Eternal = {
				WinCoins = 1200,
				WinExp = 300,
				WinGems = 5,
				LoseCoinsPerWave = 30,
				LoseExpPerWave = 10,
			},
		},
	},
})
