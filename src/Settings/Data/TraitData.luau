local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)

local RawTraitData = {
	["Power"] = {
		Index = 1,
		Chance = 40,
		Description = "+8% DAMAGE",
		Image = "rbxassetid://74159169499938",
		Color = Color3.fromRGB(255, 91, 70),
		Effects = { { Handler = "DamageMultiflier", Value = 0.08 } },
	},
	["Eye"] = {
		Index = 2,
		Chance = 25,
		Description = "+8% RANGE",
		Image = "rbxassetid://100463457721493",
		Color = Color3.fromRGB(81, 171, 255),
		Effects = { { Handler = "RangeMultiflier", Value = 0.08 } },
	},
	["Speed"] = {
		Index = 3,
		Chance = 15,
		Description = "-6% COOLDOWN",
		Image = "rbxassetid://126800652570353",
		Color = Color3.fromRGB(73, 255, 169),
		Effects = { { Handler = "CooldownMultiflier", Value = 0.06 } },
	},
	["Ember Heart"] = {
		Index = 4,
		Chance = 7.5,
		Description = "+15% DAMAGE",
		Image = "rbxassetid://74159169499938",
		Color = Color3.fromRGB(255, 120, 31),
		Effects = { { Handler = "DamageMultiflier", Value = 0.15 } },
	},
	["Crystal"] = {
		Index = 5,
		Chance = 6,
		Description = "+10% DAMAGE & RANGE",
		Image = "rbxassetid://100463457721493",
		Color = Color3.fromRGB(203, 114, 255),
		Effects = {
			{ Handler = "DamageMultiflier", Value = 0.10 },
			{ Handler = "RangeMultiflier", Value = 0.10 },
		},
	},
	["Multi"] = {
		Index = 6,
		Chance = 3.5,
		Description = "+20% DAMAGE, +5% RANGE",
		Image = "rbxassetid://126800652570353",
		Color = Color3.fromRGB(255, 89, 212),
		Effects = {
			{ Handler = "DamageMultiflier", Value = 0.20 },
			{ Handler = "RangeMultiflier", Value = 0.05 },
		},
	},
	["Healing"] = {
		Index = 7,
		Chance = 2,
		Description = "+30% DAMAGE, -12% COOLDOWN",
		Image = "rbxassetid://74159169499938",
		Color = Color3.fromRGB(255, 232, 86),
		Effects = {
			{ Handler = "DamageMultiflier", Value = 0.30 },
			{ Handler = "CooldownMultiflier", Value = 0.12 },
		},
	},
}

local TraitData = { RollCost = 5, ByName = RawTraitData, ByIndex = {} }
for name, data in RawTraitData do
	data.Name = name
	TraitData.ByIndex[data.Index] = data
end

return TableUtils.DeepFreeze(TraitData)
