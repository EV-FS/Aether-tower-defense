local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local Matter = require(ReplicatedStorage.Packages.Matter)
local UI = require(ReplicatedStorage.UI)

local SharedServices = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Services")
local Controllers = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Controllers")

-------------------------------------------------
--// Load Modules
-------------------------------------------------
ServiceRegistry:RegisterServices({
	SharedServices.NotificationService,

	Controllers.AudioController,
	Controllers.VFXController,
	Controllers.SettingsClient,
	Controllers.InventoryClient,
	Controllers.EmoteClient,
	Controllers.EmojiClient,
	Controllers.SprintClient,
	Controllers.DashClient,
	Controllers.ChatController,
	Controllers.InputController,
	Controllers.UIController,
	Controllers.DialogueClient,
	Controllers.ChatController,
})

ServiceRegistry:Start():andThen(function()
	print("클라이언트 로드 완료.")
	UI.Init()
	print("UI 로드 완료.")
end)

-------------------------------------------------
--// Load Matter
-------------------------------------------------
local Leaf = require(ReplicatedStorage.Shared.Features.Leaf)
local NPC = require(ReplicatedStorage.Shared.Features.NPC)
local Rotator = require(ReplicatedStorage.Shared.Features.Rotator)
local Mover = require(ReplicatedStorage.Shared.Features.Mover)

local world = Matter.World.new()
local loop = Matter.Loop.new(world)

local systems = {
	Leaf.System,
	NPC.System,
	Rotator.System,
	Mover.System,
}

loop:scheduleSystems(systems)

loop:begin({
	default = RunService.Heartbeat,
})

Leaf.Loader(world)
NPC.Loader(world)
Rotator.Loader(world)
Mover.Loader(world)
