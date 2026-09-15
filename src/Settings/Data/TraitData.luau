local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)

local RawTraitData = {
	["Power"] = {
		Index = 1,
		Chance = 40,
	},
	["Eye"] = {
		Index = 2,
		Chance = 25,
	},
	["Speed"] = {
		Index = 3,
		Chance = 15,
	},
	["Ember Heart"] = {
		Index = 4,
		Chance = 7.5,
	},
	["Crystal"] = {
		Index = 5,
		Chance = 6,
	},
	["Multi"] = {
		Index = 5,
		Chance = 3.5,
	},
	["Healing"] = {
		Index = 6,
		Chance = 2,
	},
}

local TraitData = {
	ByName = RawTraitData,
	ByIndex = {},
}

for name, data in pairs(RawTraitData) do
	data.Name = name

	TraitData.ByIndex[data.Index] = data
end

return TableUtils.DeepFreeze(TraitData)
