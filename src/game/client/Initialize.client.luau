local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GetPath = require(ReplicatedStorage.Shared.Modules.Core.GetPath)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local UI = require(ReplicatedStorage.UI)

local SharedServices = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Services")
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local function finishLoading()
	UI.HideLoading()
end

UI.ShowLoading()

if not game:IsLoaded() then
	game.Loaded:Wait()
end

ServiceRegistry:RegisterServices({
	SharedServices.Entities.EnemyService.EnemyClient,
	SharedServices.Entities.TowerService.TowerClient,
	SharedServices.Entities.UnitService.UnitClient,

	SharedServices.System.GameClient,

	SharedServices.System.UIController,

	SharedServices.System.EconomyService,
	SharedServices.System.TimeService,
	SharedServices.System.VisualService,
	SharedServices.System.AnimationService,
	SharedServices.System.AudioService,
	SharedServices.System.InputService,
	SharedServices.System.VFXService,
	SharedServices.System.SettingsClient,
	SharedServices.System.NotificationService,
	SharedServices.System.LootClient,
	SharedServices.System.SprintClient,
})

local mapFolder = workspace:WaitForChild("Map")
while not mapFolder:GetAttribute("SelectedMap") do
	mapFolder:GetAttributeChangedSignal("SelectedMap"):Wait()
end

GetPath.Init()

ServiceRegistry:Start():andThen(function()
	UI.Init()

	task.spawn(function()
		local ContentProvider = game:GetService("ContentProvider")
		pcall(function()
			ContentProvider:PreloadAsync({ ReplicatedStorage, workspace, playerGui })
		end)
		finishLoading()
	end)
end):catch(function(err)
	warn(`Client initialization failed: {err}`)
	finishLoading()
end)
