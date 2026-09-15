local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local Matter = require(ReplicatedStorage.Packages.Matter)
local UI = require(ReplicatedStorage.UI)

local SharedServices = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Services")

-------------------------------------------------
--// Load Modules
-------------------------------------------------
ServiceRegistry:RegisterServices({
	SharedServices.AudioService,
	SharedServices.NotificationService,
	SharedServices.SettingsClient,
	SharedServices.InventoryClient,
})

ServiceRegistry:Start():andThen(function()
	UI.Init()
end)

-------------------------------------------------
--// Load Matter
-------------------------------------------------
local Leaf = require(ReplicatedStorage.Shared.Features.Leaf)
local NPC = require(ReplicatedStorage.Shared.Features.NPC)

local world = Matter.World.new()
local loop = Matter.Loop.new(world)

local systems = {
	Leaf.System,
	NPC.System,
}

loop:scheduleSystems(systems)

loop:begin({
	default = RunService.PreRender,
})

Leaf.Loader(world)
NPC.Loader(world)
