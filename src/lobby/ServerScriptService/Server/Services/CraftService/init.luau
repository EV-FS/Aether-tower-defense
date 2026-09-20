--/Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--/Modules
local CraftRecipes = require(ReplicatedStorage.Settings.Data.CraftRecipes)
local ItemData = require(ReplicatedStorage.Settings.Data.ItemData)
local Net = require(ReplicatedStorage.Shared.Net.server)
local DataService
local invalidRecipes: { [string]: string } = {}

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

local function GetRecipeError(craftKey: string, craftInfo: CraftRecipes.Recipe): string?
	if not ItemData.ByName[craftInfo.ResultName] then
		return `Craft result "{craftInfo.ResultName}" in "{craftKey}" is missing from ItemData`
	end
	if typeof(craftInfo.ResultAmount) ~= "number" or craftInfo.ResultAmount <= 0 or craftInfo.ResultAmount % 1 ~= 0 then
		return `Invalid result amount in "{craftKey}"`
	end
	for _, ingredient in craftInfo.Ingredients do
		if not ItemData.ByName[ingredient.Name] then
			return `Craft ingredient "{ingredient.Name}" in "{craftKey}" is missing from ItemData`
		end
		if typeof(ingredient.Amount) ~= "number" or ingredient.Amount <= 0 or ingredient.Amount % 1 ~= 0 then
			return `Invalid ingredient amount in "{craftKey}"`
		end
	end
	return nil
end

function CraftService.Init(services)
	DataService = services:GetService("DataService")

	table.clear(invalidRecipes)
	for craftKey, craftInfo in CraftRecipes do
		local recipeError = GetRecipeError(craftKey, craftInfo)
		if recipeError then
			invalidRecipes[craftKey] = recipeError
			warn(`[CraftService] Disabled invalid recipe: {recipeError}`)
		end
	end
end

function CraftService.Start()
	Net.CraftService.Craft.On(
		function(player: Player, data: { consumedTowers: { [string]: { string } }, craftKey: string })
			if type(data) ~= "table" or type(data.craftKey) ~= "string" then
				return false
			end
			return CraftService:Craft(player, data.craftKey)
		end
	)
end

function CraftService:Craft(player: Player, craftKey: string): boolean
	local craftInfo = CraftRecipes[craftKey]
	if invalidRecipes[craftKey] then
		warn(`[CraftService] Rejected disabled recipe "{craftKey}": {invalidRecipes[craftKey]}`)
		return false
	end
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
