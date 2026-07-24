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
local LevelBarFrame = MainGui:WaitForChild("LevelBar")

--/React State
local Level = scope:Value(0)
local Exp = scope:Value(0)
-------------------------------------------------
--// Local Functions
-------------------------------------------------
local function ExpLogic(currentLevel: number)
	return 50 * (currentLevel + math.ceil(currentLevel / 10)) + 50
end

-------------------------------------------------
--// LevelBarController
-------------------------------------------------
local LevelBarController = {}

function LevelBarController:Hydrate()
	local animateExp = scope:Spring(Exp, 10, 1)

	scope:Hydrate(LevelBarFrame.Level)({
		Text = scope:Computed(function(use)
			return `Level {use(Level)}: [{math.floor(use(animateExp))} / {ExpLogic(use(Level))}]`
		end),
	})
	scope:Hydrate(LevelBarFrame.Canvas.Bar)({
		Size = scope:Computed(function(use)
			return UDim2.fromScale(use(animateExp) / ExpLogic(use(Level)), 1)
		end),
	})
end

function LevelBarController.Init()
	Net.DataService.CurrencyChanged.On(function(data: { CurrencyName: string, CurrencyValue: number })
		if data.CurrencyName == "Exp" then
			Exp:set(data.CurrencyValue)
		end
		if data.CurrencyName == "Level" then
			Level:set(data.CurrencyValue)
		end
	end)

	task.spawn(function()
		Level:set(Net.DataService.GetDataValue.Invoke("Level"):expect())
		Exp:set(Net.DataService.GetDataValue.Invoke("Exp"):expect())

		LevelBarController:Hydrate()
	end)
end

return LevelBarController
