local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)

local RawPurchaseData = {
	GamePasses = {
		["Double Coins"] = {
			Id = 1849463517,
			Type = "GamePass",
		},
		["VIP"] = {
			Id = 1850423497,
			Type = "GamePass",
		},
		["Lucky"] = {
			Id = 1849451640,
			Type = "GamePass",
		},
		["+500 Backpack"] = {
			Id = 1791286364,
			Type = "GamePass",
		},
		["Absolute Hunter"] = {
			Id = 1853106303,
			Type = "GamePass",
		},
	},
	DevProducts = {
		["Wizard"] = {
			Id = 3601842516,
			Rewards = {
				{ Type = "Tower", Target = "Wizard", Amount = 1 },
			},
		},
		--/Pack
		["Starter Pack"] = {
			Id = 3597090474,
			MaxPurchases = 1,
			Rewards = {
				{ Type = "Tower", Target = "Minigunner Dummy", Amount = 1 },
				{ Type = "Currency", Target = "Coins", Amount = 1000 },
			},
		},

		--/Coins
		["500 Coins"] = {
			Id = 3572729648,
			Rewards = {
				{ Type = "Currency", Target = "Coins", Amount = 500 },
			},
		},
		["1000 Coins"] = {
			Id = 3572731104,
			Rewards = {
				{ Type = "Currency", Target = "Coins", Amount = 1000 },
			},
		},
		["2500 Coins"] = {
			Id = 3572731971,
			Rewards = {
				{ Type = "Currency", Target = "Coins", Amount = 2500 },
			},
		},
		["10000 Coins"] = {
			Id = 3572731446,
			Rewards = {
				{ Type = "Currency", Target = "Coins", Amount = 10000 },
			},
		},
		["25000 Coins"] = {
			Id = 3597077765,
			Rewards = {
				{ Type = "Currency", Target = "Coins", Amount = 25000 },
			},
		},

		--/Gems
		["10 Gems"] = {
			Id = 3573263947,
			Rewards = {
				{ Type = "Currency", Target = "Gems", Amount = 10 },
			},
		},
		["50 Gems"] = {
			Id = 3573264174,
			Rewards = {
				{ Type = "Currency", Target = "Gems", Amount = 50 },
			},
		},
		["200 Gems"] = {
			Id = 3573264387,
			Rewards = {
				{ Type = "Currency", Target = "Gems", Amount = 200 },
			},
		},
		["500 Gems"] = {
			Id = 3597079530,
			Rewards = {
				{ Type = "Currency", Target = "Gems", Amount = 500 },
			},
		},
		["2000 Gems"] = {
			Id = 3597079795,
			Rewards = {
				{ Type = "Currency", Target = "Gems", Amount = 2000 },
			},
		},
	},
}

local PurchaseData = {
	ByName = RawPurchaseData,
	ById = {},
}

for category, items in pairs(RawPurchaseData) do
	for name, data in pairs(items) do
		data.Name = name
		data.Category = category

		if PurchaseData.ById[data.Id] then
			warn(`중복 Id: {data.Id} 감지. 기존: {PurchaseData.ById[data.Id].Name}, 신규: {name}`)
		end

		PurchaseData.ById[data.Id] = data
	end
end

return TableUtils.DeepFreeze(PurchaseData)
