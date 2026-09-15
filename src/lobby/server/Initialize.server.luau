local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ServerServices = ServerScriptService:WaitForChild("Server"):WaitForChild("Services")
local SharedServices = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Services")

local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)

-------------------------------------------------
--// Load Modules
-------------------------------------------------
ServiceRegistry:RegisterServices({
	ServerServices.CmdrService,
	ServerServices.DataService,
	ServerServices.InventoryActionService,
	ServerServices.EventShopService,
	ServerServices.TraitService,
	ServerServices.LoadoutService,
	ServerServices.RoomService,
	ServerServices.SettingsService,
	ServerServices.StoreService,
	ServerServices.SummonService,
	ServerServices.GlobalExistService,
	ServerServices.CraftService,

	SharedServices.NotificationService,
})

ServiceRegistry:Start()

-------------------------------------------------
--// Load Matter
-------------------------------------------------
