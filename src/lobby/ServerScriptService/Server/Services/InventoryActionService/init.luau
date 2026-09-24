local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)
local AutoSellConfig = require(ReplicatedStorage.Settings.Data.AutoSellConfig)
local UnitSellRewards = require(ReplicatedStorage.Settings.Data.UnitSellRewards)

local DataService

local REMOTES_FOLDER_NAME = "RuntimeRemotes"
local REMOTE_NAME = "InventoryAction"
local REQUEST_COOLDOWN = 0.15
local MAX_TOWER_NAME_LENGTH = 80
local MAX_TOWER_KEY_ID = 4_294_967_295

local lastRequestAt: { [Player]: number } = {}
local random = Random.new()
local InventoryActionService = {}

local function response(success: boolean, message: string, extra: { [string]: any }?)
	local result = extra or {}
	result.Success = success
	result.Message = message
	return result
end

local function normalizeTowerKey(value: any): string?
	if typeof(value) ~= "string" and typeof(value) ~= "number" then
		return nil
	end

	local keyText = tostring(value)
	local keyIdText = string.match(keyText, "^t_(%d+)$") or string.match(keyText, "^(%d+)$")
	local keyId = if keyIdText then tonumber(keyIdText) else nil
	if not keyId or keyId % 1 ~= 0 or keyId < 0 or keyId > MAX_TOWER_KEY_ID then
		return nil
	end
	return `t_{keyId}`
end

function InventoryActionService:Perform(player: Player, data: any)
	local now = os.clock()
	local previous = lastRequestAt[player]
	if previous and now - previous < REQUEST_COOLDOWN then
		return response(false, "Please wait a moment.")
	end
	lastRequestAt[player] = now

	if typeof(data) ~= "table" then
		return response(false, "Invalid unit request.")
	end

	local action = data.Action
	local towerName = data.TowerName
	local towerKey = normalizeTowerKey(data.TowerKey)
	if
		(action ~= "ToggleUnitLock" and action ~= "SellUnit")
		or typeof(towerName) ~= "string"
		or towerName == ""
		or #towerName > MAX_TOWER_NAME_LENGTH
		or not towerKey
	then
		return response(false, "Invalid unit request.")
	end

	local playerData = DataService:GetData(player)
	if not playerData then
		return response(false, "Your data is still loading.")
	end

	local towersOfType = playerData.OwnedTowers[towerName]
	local tower = towersOfType and towersOfType[towerKey]
	if typeof(tower) ~= "table" then
		return response(false, "You do not own this unit.")
	end

	if action == "ToggleUnitLock" then
		local isLocked = tower.Locked ~= true
		DataService:UpdateData(player, "OwnedTowers", isLocked, towerName, towerKey, "Locked")
		return response(true, if isLocked then "Unit locked." else "Unit unlocked.", {
			Locked = isLocked,
		})
	end

	if tower.Locked == true then
		return response(false, "Unlock this unit before selling it.", { Locked = true })
	end

	local towerInfo = TowerData.ByName[towerName]
	local rarity = towerInfo and towerInfo.Rarity
	local autoSellEntry = rarity and AutoSellConfig.ByRarity[rarity]
	local sellPrice = towerInfo and (towerInfo.SellPrice or (autoSellEntry and autoSellEntry.Price))
	if typeof(sellPrice) ~= "number" or sellPrice <= 0 or sellPrice % 1 ~= 0 then
		return response(false, "This unit cannot be sold.")
	end

	DataService:RemoveTower(player, towerName, towerKey)
	local newCoins = DataService:AddData(player, "Coins", sellPrice)
	local shardStones = if UnitSellRewards.Roll(rarity or "", random) then 1 else 0
	if shardStones > 0 then
		DataService:AddData(player, "Inventory", shardStones, "Items", UnitSellRewards.ItemName)
	end
	return response(true, `Sold for {sellPrice} Coins.`, {
		Coins = newCoins,
		SellPrice = sellPrice,
		ShardStones = shardStones,
		Locked = false,
	})
end

function InventoryActionService.Init(services)
	DataService = services:GetService("DataService")
end

InventoryActionService.Dependencies = { "DataService" }

function InventoryActionService.Start()
	local remotesFolder = ReplicatedStorage:FindFirstChild(REMOTES_FOLDER_NAME)
	if not remotesFolder then
		remotesFolder = Instance.new("Folder")
		remotesFolder.Name = REMOTES_FOLDER_NAME
		remotesFolder.Parent = ReplicatedStorage
	end

	local remote = remotesFolder:FindFirstChild(REMOTE_NAME)
	if not remote then
		remote = Instance.new("RemoteFunction")
		remote.Name = REMOTE_NAME
		remote.Parent = remotesFolder
	end
	assert(remote:IsA("RemoteFunction"), "InventoryAction runtime remote must be a RemoteFunction")

	remote.OnServerInvoke = function(player: Player, data: any)
		return InventoryActionService:Perform(player, data)
	end

	Players.PlayerRemoving:Connect(function(player)
		lastRequestAt[player] = nil
	end)
end

return InventoryActionService
