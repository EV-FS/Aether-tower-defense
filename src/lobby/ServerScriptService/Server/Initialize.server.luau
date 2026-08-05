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
	ServerServices.LoadoutService,
	ServerServices.SettingsService,
	ServerServices.StoreService,
	ServerServices.SummonService,
	ServerServices.GlobalExistService,
	ServerServices.CraftService,
	ServerServices.EmoteService,
	ServerServices.EmojiService,
	ServerServices.TimerService,

	SharedServices.NotificationService,
})

ServiceRegistry:Start():andThen(function()
	print("서버 로드 완료.")
end)

-------------------------------------------------
--// Load Matter
-------------------------------------------------
