local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GetPath = require(ReplicatedStorage.Shared.Modules.Core.GetPath)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local UI = require(ReplicatedStorage.UI)

local SharedServices = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Services")

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
while mapFolder:GetAttribute("MapReady") ~= true do
	assert(not mapFolder:GetAttribute("LoadError"), "Map load failed: " .. tostring(mapFolder:GetAttribute("LoadError")))
	task.wait(0.1)
end

GetPath.Init()

ServiceRegistry:Start():andThen(function()
	UI.Init()
	-- Map/path/services are ready. Do not wait for every unused map/unit asset.
	-- Cutscene-critical audio/images still use their own readiness preloads.
	finishLoading()
end):catch(function(err)
	warn(`Client initialization failed: {err}`)
	finishLoading()
end)
