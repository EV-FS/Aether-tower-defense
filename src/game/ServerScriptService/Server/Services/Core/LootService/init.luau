local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LootData = require(ReplicatedStorage.Settings.Data.LootData)
local Net = require(ReplicatedStorage.Shared.Net)
local DataService
local EnemyService

local RANDOM = Random.new()

local LootService = {}

function LootService.Init(services)
	DataService = services:GetService("DataService")
	EnemyService = services:GetService("EnemyService")
end
function LootService.Start()
	EnemyService.EnemyDefeated:Connect(function(enemy)
		LootService:ProcessEnemyLoot(enemy)
	end)
end

function LootService:ProcessEnemyLoot(enemy: any)
	if not enemy or not enemy.IsDead then
		return
	end
	local dropPool = LootData[enemy.Name]
	if not dropPool then
		return
	end
	local activePlayers = Players:GetPlayers()
	if #activePlayers == 0 then
		return
	end

	for _, player in ipairs(activePlayers) do
		self:RollLootForPlayer(player, dropPool)
	end
end

function LootService:RollLootForPlayer(player: Player, dropPool: {any})
	for _, drop in ipairs(dropPool) do
		local roll = RANDOM:NextNumber()
		if roll > drop.Chance then
			continue
		end

		local amount = RANDOM:NextInteger(drop.MinAmount, drop.MaxAmount)
		self:AwardLoot(player, drop.ItemName, amount)
	end
end
function LootService:AwardLoot(player: Player, itemName: string, amount: number)
	DataService:AddData(player, "Inventory", amount, "Items", itemName)

	Net.LootService.ReplicateDrop.Fire(player, {
		itemName = itemName,
		amount = amount,
	})
end

return LootService
