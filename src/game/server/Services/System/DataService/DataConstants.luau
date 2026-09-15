local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)

return TableUtils.DeepFreeze({
	KST_OFFSET = 9 * 3600,
	MAX_LOADOUT_SIZE = 5,
	MAX_TOWER_LEVEL = 30,

	PROFILE_TEMPLATE = {
		Coins = 200,
		Gems = 0,
		Wins = 0,
		Level = 1,
		Exp = 0,
		OwnedTowers = {},
		Inventory = {
			Crates = {},
			Items = {},
<<<<<<< HEAD
<<<<<<< HEAD:src/Settings/Data/DataConstants.luau
			Skins = {},
			Emotes = {},
=======
>>>>>>> parent of b55c1aa (어드민타워 적용 딩딩과 18키로):src/game/server/Services/System/DataService/DataConstants.luau
		},
		Collection = {
			Units = {},
			Items = {},
=======
>>>>>>> parent of b55c1aa (어드민타워 적용 딩딩과 18키로)
		},
		GamePasses = {},
		DevProducts = {},
		Loadout = {},
		Settings = {},
		_NextId = 1,
		_StructureVersion = "v2",
	},

	PUBLIC_DATA_KEYS = {
		Coins = true,
		Gems = true,
		Wins = true,
		Level = true,
		Exp = true,
		OwnedTowers = true,
		Inventory = true,
<<<<<<< HEAD
		Collection = true,
=======
>>>>>>> parent of b55c1aa (어드민타워 적용 딩딩과 18키로)
		GamePass = true,
		DevProducts = true,
		Loadout = true,
		Settings = true,
	},

	VALID_PURCHASE_TYPES = {
		Owned = true,
		Gifted = true,
		Token = true,
	},

	TOWER_TEMPLATE = {
		Lv = 0,
		Exp = 0,
<<<<<<< HEAD
		Locked = false,
=======
>>>>>>> parent of b55c1aa (어드민타워 적용 딩딩과 18키로)
	},
})
