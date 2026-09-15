--/Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--/Modules
local CraftRecipes = require(ReplicatedStorage.Settings.Data.CraftRecipes)
<<<<<<< HEAD
local ItemData = require(ReplicatedStorage.Settings.Data.ItemData)
=======
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)
>>>>>>> parent of b55c1aa (어드민타워 적용 딩딩과 18키로)
local Net = require(ReplicatedStorage.Shared.Net.server)
local DataService

-------------------------------------------------
--// Local Functions
-------------------------------------------------
<<<<<<< HEAD
local function GetCraftable(player: Player, craftInfo: CraftRecipes.Recipe): boolean
=======
local function GetCraftable(player: Player, pending, consumedTowers): boolean
>>>>>>> parent of b55c1aa (어드민타워 적용 딩딩과 18키로)
	local playerData = DataService:GetData(player)
	if not playerData then
		return false
	end

<<<<<<< HEAD
	local items = playerData.Inventory and playerData.Inventory.Items or {}
	for _, ingredient in craftInfo.Ingredients do
		if (items[ingredient.Name] or 0) < ingredient.Amount then
=======
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
>>>>>>> parent of b55c1aa (어드민타워 적용 딩딩과 18키로)
			return false
		end
	end

	return true
end

<<<<<<< HEAD
local function ApplyDeductions(player: Player, craftInfo: CraftRecipes.Recipe)
	for _, ingredient in craftInfo.Ingredients do
		DataService:AddData(player, "Inventory", -ingredient.Amount, "Items", ingredient.Name)
=======
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
>>>>>>> parent of b55c1aa (어드민타워 적용 딩딩과 18키로)
	end
end

local function GrantResult(player: Player, craftInfo: CraftRecipes.Recipe)
<<<<<<< HEAD
	DataService:AddData(player, "Inventory", craftInfo.ResultAmount, "Items", craftInfo.ResultName)
=======
	if craftInfo.ResultType == "Tower" then
		for _ = 1, craftInfo.ResultAmount do
			DataService:AddTower(player, craftInfo.ResultName)
		end
	elseif craftInfo.ResultType == "Item" then
		DataService:AddData(player, "Inventory", craftInfo.ResultAmount, "Items", craftInfo.ResultName)
	elseif craftInfo.ResultType == "Currency" then
		DataService:AddData(player, craftInfo.ResultName, craftInfo.ResultAmount)
	end
>>>>>>> parent of b55c1aa (어드민타워 적용 딩딩과 18키로)
end

-------------------------------------------------
--// CraftService
-------------------------------------------------
local CraftService = {}

function CraftService.Init(services)
	DataService = services:GetService("DataService")
<<<<<<< HEAD

	for craftKey, craftInfo in CraftRecipes do
		assert(ItemData.ByName[craftInfo.ResultName], `Craft result "{craftInfo.ResultName}" in "{craftKey}" is missing from ItemData`)
		assert(craftInfo.ResultAmount > 0 and craftInfo.ResultAmount % 1 == 0, `Invalid result amount in "{craftKey}"`)
		for _, ingredient in craftInfo.Ingredients do
			assert(ItemData.ByName[ingredient.Name], `Craft ingredient "{ingredient.Name}" in "{craftKey}" is missing from ItemData`)
			assert(ingredient.Amount > 0 and ingredient.Amount % 1 == 0, `Invalid ingredient amount in "{craftKey}"`)
		end
	end
=======
>>>>>>> parent of b55c1aa (어드민타워 적용 딩딩과 18키로)
end

function CraftService.Start()
	Net.CraftService.Craft.On(
		function(player: Player, data: { consumedTowers: { [string]: { string } }, craftKey: string })
<<<<<<< HEAD
			return CraftService:Craft(player, data.craftKey)
=======
			return CraftService:Craft(player, data.craftKey, data.consumedTowers)
>>>>>>> parent of b55c1aa (어드민타워 적용 딩딩과 18키로)
		end
	)
end

<<<<<<< HEAD
function CraftService:Craft(player: Player, craftKey: string): boolean
=======
function CraftService:Craft(player: Player, craftKey: string, consumedTowers: { [string]: { string } }): boolean
>>>>>>> parent of b55c1aa (어드민타워 적용 딩딩과 18키로)
	local craftInfo = CraftRecipes[craftKey]
	if not craftInfo then
		warn(`{craftKey}에 해당하는 Recipe가 존재하지 않음.`)
		return false
	end

<<<<<<< HEAD
	if not GetCraftable(player, craftInfo) then
		return false
	end

	ApplyDeductions(player, craftInfo)
=======
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
>>>>>>> parent of b55c1aa (어드민타워 적용 딩딩과 18키로)
	GrantResult(player, craftInfo)

	return true
end

return CraftService
