local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)

return TableUtils.DeepFreeze({
	Gradients = {
		Common = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(199, 199, 199)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(160, 160, 160)),
		}),
		Uncommon = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 255, 140)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 180, 70)),
		}),
		Rare = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(42, 106, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 34, 255)),
		}),
		Epic = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(235, 85, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 32, 170)),
		}),
		Legendary = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 194, 52)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 126, 61)),
		}),
		Mythic = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 14, 18)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(189, 0, 3)),
		}),
		Absolute = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(185, 255, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(239, 189, 255)),
		}),
	},

	Glow = {
		Common = Color3.fromRGB(180, 180, 180),
		Uncommon = Color3.fromRGB(90, 220, 110),
		Rare = Color3.fromRGB(70, 120, 255),
		Epic = Color3.fromRGB(210, 80, 255),
		Legendary = Color3.fromRGB(255, 190, 70),
		Mythic = Color3.fromRGB(255, 60, 60),
		Absolute = Color3.fromRGB(180, 220, 255),
	},

	ShimmerSpeed = {
		Common = 0.75,
		Uncommon = 0.9,
		Rare = 1,
		Epic = 1.15,
		Legendary = 1.3,
		Mythic = 1.45,
		Absolute = 1.6,
	},
})
