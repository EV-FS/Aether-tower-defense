local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)

export type RarityName = "Common" | "Rare" | "Epic" | "Legendary" | "Mythic" | "Absolute" | "Secret"

export type RarityEntity = {
	Identity: {
		Name: RarityName,
		DisplayName: string,
	},
	Progression: {
		Order: number,
		Power: number,
	},
	Presentation: {
		Color: Color3,
		Gradient: ColorSequence,
		Glow: Color3,
		ShimmerSpeed: number,
	},
}

local PresentationData = {
	Common = {
		Color = Color3.new(1, 1, 1),
		Gradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(177, 158, 158)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 228, 228)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(177, 158, 158)),
		}),
		Glow = Color3.fromRGB(180, 180, 180),
		ShimmerSpeed = 3,
	},
	Rare = {
		Color = Color3.new(0, 1, 1),
		Gradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(53, 76, 231)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(58, 212, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(53, 76, 231)),
		}),
		Glow = Color3.fromRGB(70, 120, 255),
		ShimmerSpeed = 3,
	},
	Epic = {
		Color = Color3.new(0.5, 0, 1),
		Gradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(131, 0, 131)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 99, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(131, 0, 131)),
		}),
		Glow = Color3.fromRGB(210, 80, 255),
		ShimmerSpeed = 2,
	},
	Legendary = {
		Color = Color3.new(1, 1, 0),
		Gradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(226, 88, 46)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 30)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(226, 88, 46)),
		}),
		Glow = Color3.fromRGB(255, 190, 70),
		ShimmerSpeed = 1.8,
	},
	Mythic = {
		Color = Color3.new(1, 0, 0),
		Gradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(202, 0, 7)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 0, 234)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(218, 0, 4)),
		}),
		Glow = Color3.fromRGB(255, 60, 60),
		ShimmerSpeed = 3,
	},
	Absolute = {
		Color = Color3.new(0.15, 0.15, 1),
		Gradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(239, 189, 255)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(185, 255, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(239, 189, 255)),
		}),
		Glow = Color3.fromRGB(83, 46, 250),
		ShimmerSpeed = 4.5,
	},
	Secret = {
		Color = Color3.new(1, 0, 1),
		Gradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(62, 0, 2)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 0, 8)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(62, 0, 2)),
		}),
		Glow = Color3.fromRGB(62, 0, 2),
		ShimmerSpeed = 3,
	},
}

-- Canonical progression order. All rarity-driven systems should derive their
-- low-to-high presentation from this list instead of declaring another order.
local ProgressionOrder = {
	"Common",
	"Rare",
	"Epic",
	"Legendary",
	"Mythic",
	"Absolute",
	"Secret",
}

local ProgressionData = {}
for power, rarity in ProgressionOrder do
	ProgressionData[rarity] = {
		-- Existing card sorting displays the strongest rarity first.
		Order = #ProgressionOrder - power + 1,
		Power = power,
	}
end

local Definitions: { [string]: RarityEntity } = {}
for rarity, progression in ProgressionData do
	Definitions[rarity] = {
		Identity = { Name = rarity :: RarityName, DisplayName = rarity },
		Progression = progression,
		Presentation = PresentationData[rarity],
	}
end

local DisplayNames = {}
for rarity, entity in Definitions do
	DisplayNames[rarity] = entity.Identity.DisplayName
end

local DisplayOrder = table.create(#ProgressionOrder)
for index = #ProgressionOrder, 1, -1 do
	table.insert(DisplayOrder, ProgressionOrder[index])
end

local RarityRegistry = {}

function RarityRegistry.Get(rarity: string): RarityEntity
	return Definitions[rarity] or Definitions["Common"]
end

function RarityRegistry.IsValid(rarity: string): boolean
	return Definitions[rarity :: RarityName] ~= nil
end

function RarityRegistry.GetOrder(rarity: string): number
	return RarityRegistry.Get(rarity).Progression.Order
end

function RarityRegistry.GetDisplayName(rarity: string): string
	return RarityRegistry.Get(rarity).Identity.DisplayName
end

function RarityRegistry.Compare(left: string, right: string): boolean
	return RarityRegistry.GetOrder(left) < RarityRegistry.GetOrder(right)
end

function RarityRegistry.Sort(values: { string }): { string }
	local sorted = table.clone(values)
	table.sort(sorted, RarityRegistry.Compare)
	return sorted
end

RarityRegistry.DisplayNames = DisplayNames
RarityRegistry.Entities = Definitions
RarityRegistry.ProgressionOrder = ProgressionOrder
RarityRegistry.DisplayOrder = DisplayOrder

return TableUtils.DeepFreeze(RarityRegistry)
