local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)

type CurrencyData = {
	[string]: {
		Index: number,
		CurrencyImage: string,
	},
}

local RawCurrencyData: CurrencyData = {
	["Coins"] = {
		Index = 1,
		CurrencyImage = "rbxassetid://117112996963807",
	},
	["Gems"] = {
		Index = 2,
		CurrencyImage = "rbxassetid://104268323693949",
	},
	["Blossom"] = {
		Index = 3,
		CurrencyImage = "rbxassetid://129066851213188",
	},
}

local CurrencyData = {
	ByName = RawCurrencyData,
	ByIndex = {},
}

for name, data in pairs(RawCurrencyData) do
	data.Name = name

	CurrencyData.ByIndex[data.Index] = data
end

return TableUtils.DeepFreeze(CurrencyData)
