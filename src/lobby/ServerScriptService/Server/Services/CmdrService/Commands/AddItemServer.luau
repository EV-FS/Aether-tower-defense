local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ItemData = require(ReplicatedStorage.Settings.Data.ItemData)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local PostWebHook = require(ServerScriptService.Server.Services.CmdrService.PostWebHook)

local MAX_AMOUNT = 1_000_000
local DataService

return function(context, player: Player, itemName: string, amount: number)
	local itemInfo = ItemData.ByName[itemName]
	if not itemInfo then
		return `Unknown item: "{itemName}". Check Settings.Data.ItemData.`
	end
	if amount <= 0 or amount > MAX_AMOUNT then
		return `Amount must be between 1 and {MAX_AMOUNT}.`
	end

	DataService = DataService or ServiceRegistry:GetService("DataService")
	local newAmount = DataService:AddData(player, "Inventory", amount, "Items", itemName)
	if newAmount == nil then
		return `Could not add item because {player.Name}'s data is not ready.`
	end

	PostWebHook(
		"Add item command used",
		"An administrator added a material item.",
		context.Executor,
		player,
		{
			["Item"] = itemName,
			["Amount"] = amount,
			["New total"] = newAmount,
		}
	)

	return `Added {amount}x {itemName} to {player.Name}. New total: {newAmount}.`
end
