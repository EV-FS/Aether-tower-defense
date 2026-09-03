local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)

return TableUtils.DeepFreeze({
	Prices = {
		[1] = 100,
		[10] = 900,
	},

	BannerTimerDuration = 30 * 60,

	Pity = {
		Mythic = {
			Limit = 100,
			Attribute = "SummonMythicPity",
		},
		Absolute = {
			Limit = 1000,
			Attribute = "SummonAbsolutePity",
		},
	},

	UnitPool = {
		Common = { "Bacon", "Dummy", "Noob", "Batter Bacon", "Boxer Noob", "Scyther Dummy" },
		Rare = { "Gunner Dummy", "Katana Noob" },
		Epic = { "Lancer Dummy", "Poor Bacon" },
		Legendary = { "Minigunner Dummy", "King Noob" },
		Mythic = { "Cyborg Dummy", "Poseidon Noob" },
		Absolute = { "Hacker" },
	},

	RarityRates = {
		{ Rarity = "Common", Weight = 75 },
		{ Rarity = "Rare", Weight = 17.89 },
		{ Rarity = "Epic", Weight = 6 },
		{ Rarity = "Legendary", Weight = 1 },
		{ Rarity = "Mythic", Weight = 0.1 },
		{ Rarity = "Absolute", Weight = 0.01 },
	},

	FeaturedRarities = { "Legendary", "Absolute", "Mythic" },
	RateDisplayOrder = { "Absolute", "Mythic", "Legendary", "Epic", "Rare", "Common" },

	RarityGradients = {
		Common = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 228, 228)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(85, 76, 76)),
		}),
		Rare = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(42, 46, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(52, 160, 255)),
		}),
		Epic = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(228, 76, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(102, 88, 255)),
		}),
		Legendary = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 123, 57)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 227, 88)),
		}),
		Mythic = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 65, 68)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(211, 79, 255)),
		}),
		Absolute = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(164, 246, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 138, 255)),
		}),
	},
})
