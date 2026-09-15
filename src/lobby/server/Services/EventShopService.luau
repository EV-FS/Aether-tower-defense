local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventShopData = require(ReplicatedStorage.Settings.Data.EventShopData)

local DataService

local REMOTES_FOLDER_NAME = "RuntimeRemotes"
local REMOTE_NAME = "EventShopPurchase"
local REQUEST_COOLDOWN = 0.25
local lastRequestAt: { [Player]: number } = {}

local EventShopService = {}

local function response(success: boolean, message: string, extra: { [string]: any }?)
	local result = extra or {}
	result.Success = success
	result.Message = message
	return result
end

function EventShopService:Purchase(player: Player, productId: any)
	local now = os.clock()
	local previous = lastRequestAt[player]
	if previous and now - previous < REQUEST_COOLDOWN then
		return response(false, "Please wait a moment.")
	end
	lastRequestAt[player] = now

	if typeof(productId) ~= "string" or #productId > 64 then
		return response(false, "Invalid event shop product.")
	end

	local product = EventShopData.ById[productId]
	if not product then
		return response(false, "This product is unavailable.")
	end

	local playerData = DataService:GetData(player)
	if not playerData then
		return response(false, "Your data is still loading.")
	end

	local inventory = playerData.Inventory or {}
	local category = inventory[product.RewardCategory] or {}
	if product.Unique and (category[product.RewardName] or 0) > 0 then
		return response(false, "You already own this reward.", { AlreadyOwned = true })
	end

	local balance = playerData.Blossom or 0
	if balance < product.Price then
		return response(false, `Collect {product.Price - balance} more Blossoms.`, {
			Balance = balance,
			Required = product.Price,
		})
	end

	local newBalance = DataService:AddData(player, "Blossom", -product.Price)
	if newBalance == nil then
		return response(false, "The purchase could not be completed.")
	end

	DataService:AddData(
		player,
		"Inventory",
		product.RewardAmount,
		product.RewardCategory,
		product.RewardName
	)

	return response(true, `Purchased {product.Title}!`, {
		Balance = newBalance,
		ProductId = product.Id,
		RewardName = product.RewardName,
		RewardAmount = product.RewardAmount,
	})
end

function EventShopService.Init(services)
	DataService = services:GetService("DataService")
end

EventShopService.Dependencies = { "DataService" }

function EventShopService.Start()
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
	assert(remote:IsA("RemoteFunction"), "EventShopPurchase runtime remote must be a RemoteFunction")

	remote.OnServerInvoke = function(player: Player, productId: any)
		return EventShopService:Purchase(player, productId)
	end

	Players.PlayerRemoving:Connect(function(player)
		lastRequestAt[player] = nil
	end)
end

return EventShopService
