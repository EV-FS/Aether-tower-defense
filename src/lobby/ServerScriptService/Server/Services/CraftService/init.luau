--/Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--/Modules
local CraftRecipes = require(ReplicatedStorage.Settings.Data.CraftRecipes)
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)
local Net = require(ReplicatedStorage.Shared.Net.server)
local DataService

-------------------------------------------------
--// Local Functions
-------------------------------------------------
local function GetCraftable(player: Player, pending, consumedTowers): boolean
	local playerData = DataService:GetData(player)
	if not playerData then
		return false
	end

	for towerName, amount in pending.Tower do
		if not playerData.OwnedTowers[towerName] then
			return false
		end
		if not consumedTowers[towerName] then
			return false
		end

		local usedKeys = {}
		for _, towerKey in consumedTowers[towerName] do
			if playerData.OwnedTowers[towerName][towerKey] and not usedKeys[towerKey] then
				usedKeys[towerKey] = true
			end
		end
		if TableUtils.Length(usedKeys) < amount then
			return false
		end
	end
	for itemName, amount in pending.Item do
		local itemCount = playerData.Inventory.Items[itemName] or 0
		if itemCount < amount then
			return false
		end
	end
	for currencyName, amount in pending.Currency do
		if playerData[currencyName] < amount then
			return false
		end
	end

	return true
end

local function ApplyDeductions(player: Player, pending, consumedTowers)
	local playerData = DataService:GetData(player)
	if not playerData then
		return
	end

	for towerName, amount in pending.Tower do
		local count = 0
		local usedKeys = {}
		for _, towerKey in consumedTowers[towerName] do
			if count >= amount then
				break
			end

			if playerData.OwnedTowers[towerName][towerKey] and not usedKeys[towerKey] then
				usedKeys[towerKey] = true
				DataService:RemoveTower(player, towerName, towerKey)
				count += 1
			end
		end
	end

	for itemName, amount in pending.Item do
		DataService:AddData(player, "Inventory", -amount, "Items", itemName)
	end

	for currencyName, amount in pending.Currency do
		DataService:AddData(player, currencyName, -amount)
	end
end

local function GrantResult(player: Player, craftInfo: CraftRecipes.Recipe)
	if craftInfo.ResultType == "Tower" then
		for _ = 1, craftInfo.ResultAmount do
			DataService:AddTower(player, craftInfo.ResultName)
		end
	elseif craftInfo.ResultType == "Item" then
		DataService:AddData(player, "Inventory", craftInfo.ResultAmount, "Items", craftInfo.ResultName)
	elseif craftInfo.ResultType == "Currency" then
		DataService:AddData(player, craftInfo.ResultName, craftInfo.ResultAmount)
	end
end

-------------------------------------------------
--// CraftService
-------------------------------------------------
local CraftService = {}

function CraftService.Init(services)
	DataService = services:GetService("DataService")
end

function CraftService.Start()
	Net.CraftService.Craft.On(
		function(player: Player, data: { consumedTowers: { [string]: { string } }, craftKey: string })
			return CraftService:Craft(player, data.craftKey, data.consumedTowers)
		end
	)
end

function CraftService:Craft(player: Player, craftKey: string, consumedTowers: { [string]: { string } }): boolean
	local craftInfo = CraftRecipes[craftKey]
	if not craftInfo then
		warn(`{craftKey}에 해당하는 Recipe가 존재하지 않음.`)
		return false
	end

	local pending = { Tower = {}, Item = {}, Currency = {} }
	for _, ingredient in craftInfo.Ingredients do
		local targetPending = pending[ingredient.Type]
		if not targetPending then
			continue
		end

		targetPending[ingredient.Name] = ingredient.Amount
	end

	consumedTowers = consumedTowers or {}
	if not GetCraftable(player, pending, consumedTowers) then
		return false
	end

	ApplyDeductions(player, pending, consumedTowers)
	GrantResult(player, craftInfo)

	return true
end

return CraftService
