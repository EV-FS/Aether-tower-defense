local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)

return TableUtils.DeepFreeze({
	KST_OFFSET = 9 * 3600,
	MAX_LOADOUT_SIZE = 5,
	MAX_TOWER_LEVEL = 40,
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
			Emotes = {
				["Look Out"] = 1,
			},
			Emojis = {
				Wave = 1,
				Laugh = 1,
				Love = 1,
				Surprised = 1,
			},
		},
		EmoteLoadout = {},
		EmojiLoadout = {},
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
		Quests = {},
		AFKRewards = {
			Coins = 0,
			Gems = 0,
		},
		_NextId = 1,
		_StructureVersion = "v2",
		_StarterTowerReceived = false,
		_EmojiLoadoutInitialized = false,
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
		EmoteLoadout = true,
		EmojiLoadout = true,
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
