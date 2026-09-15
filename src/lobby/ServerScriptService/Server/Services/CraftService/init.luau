--/Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--/Modules
local CraftRecipes = require(ReplicatedStorage.Settings.Data.CraftRecipes)
local ItemData = require(ReplicatedStorage.Settings.Data.ItemData)
local Net = require(ReplicatedStorage.Shared.Net.server)
local DataService

-------------------------------------------------
--// Local Functions
-------------------------------------------------
local function GetCraftable(player: Player, craftInfo: CraftRecipes.Recipe): boolean
	local playerData = DataService:GetData(player)
	if not playerData then
		return false
	end

	local items = playerData.Inventory and playerData.Inventory.Items or {}
	for _, ingredient in craftInfo.Ingredients do
		if (items[ingredient.Name] or 0) < ingredient.Amount then
			return false
		end
	end

	return true
end

local function ApplyDeductions(player: Player, craftInfo: CraftRecipes.Recipe)
	for _, ingredient in craftInfo.Ingredients do
		DataService:AddData(player, "Inventory", -ingredient.Amount, "Items", ingredient.Name)
	end
end

local function GrantResult(player: Player, craftInfo: CraftRecipes.Recipe)
	DataService:AddData(player, "Inventory", craftInfo.ResultAmount, "Items", craftInfo.ResultName)
end

-------------------------------------------------
--// CraftService
-------------------------------------------------
local CraftService = {}

function CraftService.Init(services)
	DataService = services:GetService("DataService")

	for craftKey, craftInfo in CraftRecipes do
		assert(ItemData.ByName[craftInfo.ResultName], `Craft result "{craftInfo.ResultName}" in "{craftKey}" is missing from ItemData`)
		assert(craftInfo.ResultAmount > 0 and craftInfo.ResultAmount % 1 == 0, `Invalid result amount in "{craftKey}"`)
		for _, ingredient in craftInfo.Ingredients do
			assert(ItemData.ByName[ingredient.Name], `Craft ingredient "{ingredient.Name}" in "{craftKey}" is missing from ItemData`)
			assert(ingredient.Amount > 0 and ingredient.Amount % 1 == 0, `Invalid ingredient amount in "{craftKey}"`)
		end
	end
end

function CraftService.Start()
	Net.CraftService.Craft.On(
		function(player: Player, data: { consumedTowers: { [string]: { string } }, craftKey: string })
			return CraftService:Craft(player, data.craftKey)
		end
	)
end

function CraftService:Craft(player: Player, craftKey: string): boolean
	local craftInfo = CraftRecipes[craftKey]
	if not craftInfo then
		warn(`{craftKey}에 해당하는 Recipe가 존재하지 않음.`)
		return false
	end

	if not GetCraftable(player, craftInfo) then
		return false
	end

	ApplyDeductions(player, craftInfo)
	GrantResult(player, craftInfo)

	return true
end

return CraftService
