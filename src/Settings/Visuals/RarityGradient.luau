local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)

return TableUtils.DeepFreeze({
	Gradients = {
		Common = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(177, 158, 158)),
			ColorSequenceKeypoint.new(0.508503, Color3.fromRGB(255, 228, 228)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(177, 158, 158)),
		}),
		Rare = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(53, 76, 231)),
			ColorSequenceKeypoint.new(0.518707, Color3.fromRGB(58, 212, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(53, 76, 231)),
		}),
		Epic = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(131, 0, 131)),
			ColorSequenceKeypoint.new(0.508503, Color3.fromRGB(255, 99, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(131, 0, 131)),
		}),
		Legendary = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(226, 88, 46)),
			ColorSequenceKeypoint.new(0.510204, Color3.fromRGB(255, 255, 30)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(226, 88, 46)),
		}),
		Mythic = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(202, 0, 7)),
			ColorSequenceKeypoint.new(0.511905, Color3.fromRGB(255, 0, 234)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(218, 0, 4)),
		}),
		Exclusive = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 38, 154)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(139, 32, 255)),
		}),
		Absolute = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(83, 46, 250)),
			ColorSequenceKeypoint.new(0.513605, Color3.new(0, 0.568627, 1)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(83, 46, 250)),
		}),
		Secret = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(62, 0, 2)),
			ColorSequenceKeypoint.new(0.498299, Color3.fromRGB(255, 0, 8)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(62, 0, 2)),
		}),
	},

	Glow = {
		Common = Color3.fromRGB(180, 180, 180),
		Rare = Color3.fromRGB(70, 120, 255),
		Epic = Color3.fromRGB(210, 80, 255),
		Legendary = Color3.fromRGB(255, 190, 70),
		Mythic = Color3.fromRGB(255, 60, 60),
		Exclusive = Color3.fromRGB(255, 64, 190),
		Absolute = Color3.fromRGB(83, 46, 250),
		Secret = Color3.fromRGB(62, 0, 2),
	},

	ShimmerSpeed = {
		Common = 3,
		Rare = 3,
		Epic = 2,
		Legendary = 1.8,
		Mythic = 3,
		Exclusive = 3,
		Absolute = 4.5,
		Secret = 3,
	},
})
