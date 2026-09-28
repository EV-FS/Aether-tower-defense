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

	-- Kept for profiles created while the summon banner still used the old roster.
	-- New banner candidates live in SummonBannerPool.
	LegacyUnitRarities = {
		Bacon = "Common",
		Dummy = "Common",
		Noob = "Common",
		["Batter Bacon"] = "Common",
		["Boxer Noob"] = "Common",
		["Fighter Noob"] = "Common",
		["Scyther Dummy"] = "Common",
		["Gunner Dummy"] = "Rare",
		["Katana Noob"] = "Rare",
		["Lancer Dummy"] = "Epic",
		["Poor Bacon"] = "Epic",
		["Minigunner Dummy"] = "Legendary",
		["King Noob"] = "Legendary",
		["Cyborg Dummy"] = "Mythic",
		["Poseidon Noob"] = "Mythic",
		Hacker = "Absolute",
	},

	LegacyUnitImages = {
		Bacon = "rbxassetid://120964210405701",
		Dummy = "rbxassetid://100475259212197",
		Noob = "rbxassetid://82308800052558",
		["Batter Bacon"] = "rbxassetid://101722065001660",
		["Boxer Noob"] = "rbxassetid://96421319964530",
		["Fighter Noob"] = "rbxassetid://96421319964530",
		["Scyther Dummy"] = "rbxassetid://82740074755423",
		["Gunner Dummy"] = "rbxassetid://122275683628692",
		["Katana Noob"] = "rbxassetid://111309604603969",
		["Lancer Dummy"] = "rbxassetid://123924919401262",
		["Poor Bacon"] = "rbxassetid://91237371309389",
		["Minigunner Dummy"] = "rbxassetid://136315237541072",
		["King Noob"] = "rbxassetid://82013737431746",
		["Cyborg Dummy"] = "rbxassetid://139911403374399",
		["Poseidon Noob"] = "rbxassetid://82847297421685",
		Hacker = "rbxassetid://76888510287982",
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
