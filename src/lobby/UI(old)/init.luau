--/Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--/Modules
local Vide = require(ReplicatedStorage.Packages.Vide)
local App = require(script.App)
local UIOffsetScaler = require(script.Utils.UIOffsetScaler)

local mount = Vide.mount

local Controllers = {
	ButtonController = require(script.Controllers.ButtonController),
	HUDController = require(script.Controllers.HUDController),
	InventoryController = require(script.Controllers.InventoryController),
	LoadoutController = require(script.Controllers.LoadoutController),
	SummonController = require(script.Controllers.SummonController),
	UIController = require(script.Controllers.UIController),
	PlayController = require(script.Controllers.PlayController),
	StoreController = require(script.Controllers.StoreController),
	SettingsController = require(script.Controllers.SettingsController),
	LevelBarController = require(script.Controllers.LevelBarController),
}

local UI = {}

function UI.Init()
	UIOffsetScaler.Init()

	local features = {}

	for _, controller in Controllers do
		controller.Init(Controllers)
	end

	for _, module in script.Features:GetDescendants() do
		if module:IsA("ModuleScript") and module.Name:match("UI$") then
			local feature = require(module)
			table.insert(features, feature)

			if feature.Init then
				feature.Init()
			end
		end
	end

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	mount(function()
		local uiElements = {}
		for _, feature in features do
			if feature.RenderUI then
				table.insert(uiElements, feature.RenderUI())
			end
		end
		return App(uiElements)
	end, playerGui)

	for _, feature in features do
		if feature.Start then
			task.spawn(feature.Start)
		end
	end
end

return UI
