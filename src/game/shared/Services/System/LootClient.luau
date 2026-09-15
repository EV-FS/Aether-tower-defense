--/Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--/Modules
local Net = require(ReplicatedStorage.Shared.Net.client)

local NotificationService

-------------------------------------------------
--// LootClient
-------------------------------------------------
local LootClient = {}

function LootClient.Init(services)
	NotificationService = services:GetService("NotificationService")
end

function LootClient.Start()
	Net.LootService.ReplicateDrop.On(function(data)
		LootClient:AnimateDrop(data.itemName, data.amount)
	end)
end

function LootClient:AnimateDrop(itemName: string, amount: number)
	if NotificationService then
		NotificationService:Pull(nil, `+{itemName} x{amount}`, "Normal", 3)
	end
end

return LootClient
