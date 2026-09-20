local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)
local RarityColor = require(ReplicatedStorage.Settings.Visuals.RarityColor)
local RarityGradient = require(ReplicatedStorage.Settings.Visuals.RarityGradient)

export type RarityName = "Common" | "Rare" | "Epic" | "Legendary" | "Mythic" | "Secret" | "Absolute"

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

local Definitions: { [string]: RarityEntity } = {
	Common = {
		Identity = { Name = "Common", DisplayName = "Common" },
		Progression = { Order = 7, Power = 1 },
		Presentation = {
			Color = RarityColor.Common,
			Gradient = RarityGradient.Gradients.Common,
			Glow = RarityGradient.Glow.Common,
			ShimmerSpeed = RarityGradient.ShimmerSpeed.Common,
		},
	},
	Rare = {
		Identity = { Name = "Rare", DisplayName = "Rare" },
		Progression = { Order = 6, Power = 2 },
		Presentation = {
			Color = RarityColor.Rare,
			Gradient = RarityGradient.Gradients.Rare,
			Glow = RarityGradient.Glow.Rare,
			ShimmerSpeed = RarityGradient.ShimmerSpeed.Rare,
		},
	},
	Epic = {
		Identity = { Name = "Epic", DisplayName = "Epic" },
		Progression = { Order = 5, Power = 3 },
		Presentation = {
			Color = RarityColor.Epic,
			Gradient = RarityGradient.Gradients.Epic,
			Glow = RarityGradient.Glow.Epic,
			ShimmerSpeed = RarityGradient.ShimmerSpeed.Epic,
		},
	},
	Legendary = {
		Identity = { Name = "Legendary", DisplayName = "Legendary" },
		Progression = { Order = 4, Power = 4 },
		Presentation = {
			Color = RarityColor.Legendary,
			Gradient = RarityGradient.Gradients.Legendary,
			Glow = RarityGradient.Glow.Legendary,
			ShimmerSpeed = RarityGradient.ShimmerSpeed.Legendary,
		},
	},
	Mythic = {
		Identity = { Name = "Mythic", DisplayName = "Mythic" },
		Progression = { Order = 3, Power = 5 },
		Presentation = {
			Color = RarityColor.Mythic,
			Gradient = RarityGradient.Gradients.Mythic,
			Glow = RarityGradient.Glow.Mythic,
			ShimmerSpeed = RarityGradient.ShimmerSpeed.Mythic,
		},
	},
	Absolute = {
		Identity = { Name = "Absolute", DisplayName = "Absolute" },
		Progression = { Order = 2, Power = 6 },
		Presentation = {
			Color = RarityColor.Absolute,
			Gradient = RarityGradient.Gradients.Absolute,
			Glow = RarityGradient.Glow.Absolute,
			ShimmerSpeed = RarityGradient.ShimmerSpeed.Absolute,
		},
	},
    	Secret = {
		Identity = { Name = "Secret", DisplayName = "Secret" },
		Progression = { Order = 1, Power = 7 },
		Presentation = {
			Color = RarityColor.Secret,
			Gradient = RarityGradient.Gradients.Secret,
			Glow = RarityGradient.Glow.Secret,
			ShimmerSpeed = RarityGradient.ShimmerSpeed.Secret,
		},
	},
}

local DisplayNames = {}
for rarity, entity in Definitions do
	DisplayNames[rarity] = entity.Identity.DisplayName
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

return TableUtils.DeepFreeze(RarityRegistry)
