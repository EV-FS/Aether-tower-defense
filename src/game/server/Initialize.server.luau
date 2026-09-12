local CharacterGuard = require(script.Parent.CharacterGuard)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)

local ServerServices = ServerScriptService:WaitForChild("Server"):WaitForChild("Services")
local SharedServices = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Services")

ServiceRegistry:RegisterServices({
	--/Core
	ServerServices.Core.BaseService,
	ServerServices.Core.GameService,
	ServerServices.Core.MapService,
	ServerServices.Core.WaveService,
	ServerServices.Core.LootService,

	--/System
	SharedServices.System.EconomyService,
	SharedServices.System.TimeService,
	ServerServices.System.DataService,
	ServerServices.System.SettingsService,
	ServerServices.System.GlobalExistService,
	ServerServices.System.RoleTagService,
	SharedServices.System.AudioService,

	--/Entities
	ServerServices.Entities.EnemyService,
	ServerServices.Entities.TowerService,
	ServerServices.Entities.UnitService,
})

ServiceRegistry:Start()
