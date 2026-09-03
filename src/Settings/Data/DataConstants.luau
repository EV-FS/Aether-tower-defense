local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)

return TableUtils.DeepFreeze({
	KST_OFFSET = 9 * 3600,
	MAX_LOADOUT_SIZE = 5,
	MAX_TOWER_LEVEL = 30,
	STARTER_TOWER = "Fighter",

	PROFILE_TEMPLATE = {
		Coins = 200,
		Gems = 0,
		Blossom = 0,
		Wins = 0,
		Level = 1,
		Exp = 0,
		OwnedTowers = {},
		Inventory = {
			Crates = {},
			Items = {},
			Emotes = {},
		},
		GamePasses = {},
		DevProducts = {},
		Loadout = {},
		Settings = {},
		SummonPity = {
			Mythic = 0,
			Absolute = 0,
		},
		Quests = {},
		TutorialCompleted = false,
		_NextId = 1,
		_StructureVersion = "v2",
		_StarterTowerReceived = false,
	},

	PUBLIC_DATA_KEYS = {
		Coins = true,
		Gems = true,
		Blossom = true,
		Wins = true,
		Level = true,
		Exp = true,
		OwnedTowers = true,
		Inventory = true,
		GamePass = true,
		DevProducts = true,
		Loadout = true,
		Settings = true,
		Quests = true,
	},

	VALID_PURCHASE_TYPES = {
		Owned = true,
		Gifted = true,
		Token = true,
	},

	TOWER_TEMPLATE = {
		Lv = 0,
		Exp = 0,
	},
})
