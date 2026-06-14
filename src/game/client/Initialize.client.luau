local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GetPath = require(ReplicatedStorage.Shared.Modules.Core.GetPath)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local UI = require(ReplicatedStorage.UI)

local SharedServices = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Services")

ServiceRegistry:RegisterServices({
	SharedServices.Entities.EnemyService.EnemyClient,
	SharedServices.Entities.TowerService.TowerClient,
	SharedServices.Entities.UnitService.UnitClient,

	SharedServices.System.GameClient,

	SharedServices.System.EconomyService,
	SharedServices.System.TimeService,
	SharedServices.System.VisualService,
	SharedServices.System.AnimationService,
	SharedServices.System.AudioService,
	SharedServices.System.InputService,
	SharedServices.System.VFXService,
	SharedServices.System.SettingsClient,
	SharedServices.System.NotificationService,
})

GetPath.Init()
ServiceRegistry:Start():andThen(function()
	UI.Init()
end)
