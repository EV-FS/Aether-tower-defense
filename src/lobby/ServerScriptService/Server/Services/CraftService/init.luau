--/Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--/Modules
local CraftRecipes = require(ReplicatedStorage.Settings.Data.CraftRecipes)
local ItemData = require(ReplicatedStorage.Settings.Data.ItemData)
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)
local Net = require(ReplicatedStorage.Shared.Net.server)
local DataService
local invalidRecipes: { [string]: string } = {}
local activeCrafts: { [Player]: boolean } = {}
local VALID_CURRENCIES = { Coins = true, Gems = true }

-------------------------------------------------
--// Local Functions
-------------------------------------------------
local function GetCraftable(player: Player, craftInfo: CraftRecipes.Recipe): boolean
	local playerData = DataService:GetData(player)
	if not playerData or DataService:IsLocked(player) then
		return false
	end

	local requiredItems = {}
	for _, ingredient in craftInfo.Ingredients do
		requiredItems[ingredient.Name] = (requiredItems[ingredient.Name] or 0) + ingredient.Amount
	end
	for name, amount in requiredItems do
		if not DataService:CanAfford(player, "Inventory", amount, "Items", name) then
			return false
		end
	end
	for currency, amount in craftInfo.Currencies or {} do
		if not DataService:CanAfford(player, currency, amount) then
			return false
		end
	end

	return true
end

local function ApplyDeductions(player: Player, craftInfo: CraftRecipes.Recipe)
	for _, ingredient in craftInfo.Ingredients do
		assert(
			DataService:AddData(player, "Inventory", -ingredient.Amount, "Items", ingredient.Name) ~= nil,
			`Failed to deduct {ingredient.Name}.`
		)
	end
	for currency, amount in craftInfo.Currencies or {} do
		assert(DataService:AddData(player, currency, -amount) ~= nil, `Failed to deduct {currency}.`)
	end
end

local function GrantResult(player: Player, craftInfo: CraftRecipes.Recipe)
	if craftInfo.ResultType == "Tower" then
		for _ = 1, craftInfo.ResultAmount do
			DataService:AddTower(player, craftInfo.ResultName)
		end
	else
		DataService:AddData(player, "Inventory", craftInfo.ResultAmount, "Items", craftInfo.ResultName)
	end
end

-------------------------------------------------
--// CraftService
-------------------------------------------------
local CraftService = {}

local function GetRecipeError(craftKey: string, craftInfo: CraftRecipes.Recipe): string?
	if craftInfo.ResultType == "Tower" then
		if not TowerData.ByName[craftInfo.ResultName] then
			return `Craft result "{craftInfo.ResultName}" in "{craftKey}" is missing from TowerData`
		end
	elseif craftInfo.ResultType == nil or craftInfo.ResultType == "Item" then
		if not ItemData.ByName[craftInfo.ResultName] then
			return `Craft result "{craftInfo.ResultName}" in "{craftKey}" is missing from ItemData`
		end
	else
		return `Invalid result type in "{craftKey}"`
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
	for currency, amount in craftInfo.Currencies or {} do
		if not VALID_CURRENCIES[currency] then
			return `Invalid currency "{currency}" in "{craftKey}"`
		end
		if typeof(amount) ~= "number" or amount <= 0 or amount % 1 ~= 0 then
			return `Invalid currency amount in "{craftKey}"`
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
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		activeCrafts[player] = nil
	end)
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
	if activeCrafts[player] then
		return false
	end
	local craftInfo = CraftRecipes[craftKey]
	if invalidRecipes[craftKey] then
		warn(`[CraftService] Rejected disabled recipe "{craftKey}": {invalidRecipes[craftKey]}`)
		return false
	end
	if not craftInfo then
		warn(`{craftKey}에 해당하는 Recipe가 존재하지 않음.`)
		return false
	end

	activeCrafts[player] = true
	local ok, crafted = pcall(function()
		if not GetCraftable(player, craftInfo) then
			return false
		end
		ApplyDeductions(player, craftInfo)
		GrantResult(player, craftInfo)
		return true
	end)
	activeCrafts[player] = nil
	if not ok then
		warn(`[CraftService] Failed to craft "{craftKey}" for {player.Name}: {crafted}`)
		return false
	end
	return crafted
end

return CraftService
