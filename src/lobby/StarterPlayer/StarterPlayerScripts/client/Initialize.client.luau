local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local Matter = require(ReplicatedStorage.Packages.Matter)
local UI = require(ReplicatedStorage.UI)

local SharedServices = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Services")
local Controllers = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Controllers")

UI.ShowLoading()

if not game:IsLoaded() then
	game.Loaded:Wait()
end

-------------------------------------------------
--// Load Modules
-------------------------------------------------
ServiceRegistry:RegisterServices({
	SharedServices.NotificationService,

	Controllers.FOVController,
	Controllers.AudioController,
	Controllers.VFXController,
	Controllers.SettingsClient,
	Controllers.DataClient,
	Controllers.InventoryClient,
	Controllers.IndexClient,
	Controllers.TraitClient,
	Controllers.EmoteClient,
	Controllers.EmojiClient,
	Controllers.SprintClient,
	Controllers.DashClient,
	Controllers.ChatController,
	Controllers.InputController,
	Controllers.UIController,
	Controllers.DialogueClient,
	Controllers.PartyController,
})

ServiceRegistry:Start()
	:andThen(function()
		print("클라이언트 로드 완료.")
		-- Prepare the complete interface while the loading cover is still visible.
		UI.Init()
		print("UI 로드 완료.")
		UI.HideLoading()
	end)
	:catch(function(err)
		warn(`클라이언트 초기화 실패: {err}`)
		UI.HideLoading()
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
