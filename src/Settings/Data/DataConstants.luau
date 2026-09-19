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
			Skins = {},
			-- Every emote shown in the default radial menu is available to play.
			-- Profile reconciliation adds missing entries for existing players too.
			Emotes = {
				Kyukurarin = 1,
				["Take the L"] = 1,
				Usagiflap = 1,
				Grayzone = 1,
			},
		},
		Collection = {
			Units = {},
			Items = {},
		},
		GamePasses = {},
		DevProducts = {},
		Loadout = {},
		Settings = {},
		RedeemedCodes = {},
		SummonPity = {
			Mythic = 0,
			Absolute = 0,
		},
		Quests = {
			Chapter1Clear = {
				Active = true,
				Progress = 0,
				Target = 1,
				Completed = false,
				Claimed = false,
			},
		},
		AFKRewards = {
			Coins = 0,
			Gems = 0,
		},
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
		Collection = true,
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
		Locked = false,
	},
})
