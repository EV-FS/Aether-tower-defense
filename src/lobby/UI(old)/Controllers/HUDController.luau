--/Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--/Modules
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local NumberUtils = require(ReplicatedStorage.Shared.Modules.Utils.NumberUtils)
local Net = require(ReplicatedStorage.Shared.Net.client)

--/Fusion setup
local scope = Fusion:scoped()

--/Variables
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local MainGui = PlayerGui:WaitForChild("MainGui")
local CurrencyFrame = MainGui:WaitForChild("Currency")

--/React State
local CurrencyState = {
	Coins = scope:Value(0),
	Gems = scope:Value(0),
}

-------------------------------------------------
--// HUDController
-------------------------------------------------
local HUDController = {}

function HUDController:Hydrate()
	local animateCoins = scope:Spring(CurrencyState.Coins, 40, 1)
	local animateGems = scope:Spring(CurrencyState.Gems, 40, 1)

	scope:Hydrate(CurrencyFrame.Coins.TextLabel)({
		Text = scope:Computed(function(use)
			return NumberUtils.FormatComma(math.round(use(animateCoins) or 0))
		end),
	})
	scope:Hydrate(CurrencyFrame.Gems.TextLabel)({
		Text = scope:Computed(function(use)
			return NumberUtils.FormatComma(math.round(use(animateGems) or 0))
		end),
	})
end

function HUDController.Init()
	Net.DataService.CurrencyChanged.On(function(data: { CurrencyName: string, CurrencyValue: number })
		CurrencyState[data.CurrencyName] = CurrencyState[data.CurrencyName] or scope:Value(0)
		CurrencyState[data.CurrencyName]:set(data.CurrencyValue)
	end)

	task.spawn(function()
		CurrencyState.Coins:set(Net.DataService.GetDataValue.Invoke("Coins"):expect())
		CurrencyState.Gems:set(Net.DataService.GetDataValue.Invoke("Gems"):expect())

		HUDController:Hydrate()
	end)
end

return HUDController
