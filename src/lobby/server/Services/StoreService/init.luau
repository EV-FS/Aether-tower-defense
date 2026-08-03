local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PurchaseData = require(ReplicatedStorage.Settings.Data.PurchaseData)
local DataService

local StoreService = {}

function StoreService.SyncGamePasses(player: Player)
	if not DataService:GetProfile(player) then
		warn(`{player.Name}의 데이터 로드 실패.`)
		return
	end

	for _, passData in PurchaseData.ByName.GamePasses do
		local success, isOwn = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passData.Id)
		end)
		if success then
			if isOwn then
				StoreService.OnPurchaseGamePass(player, passData.Id, true)
			end
		else
			warn(`플레이어 {player.Name}의 게임패스({passData.Id}) 확인 실패: {tostring(isOwn)}`)
		end
	end
end

function StoreService.OnPurchaseGamePass(player: Player, gamePassId: number, wasPurchased: boolean)
	if not wasPurchased then
		return
	end

	if DataService:IsOwnGamePass(player, tostring(gamePassId)) then
		return
	end

	DataService:AddGamePass(player, gamePassId, "Owned")
end

function StoreService.OnPurchaseDevProduct(receiptInfo): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local result = DataService:ProcessProduct(player, receiptInfo)

	return result or Enum.ProductPurchaseDecision.NotProcessedYet
end

function StoreService.Init(services)
	DataService = services:GetService("DataService")
end

function StoreService.Start()
	for _, player in Players:GetPlayers() do
		task.spawn(StoreService.SyncGamePasses, player)
	end

	Players.PlayerAdded:Connect(function(player: Player)
		task.spawn(StoreService.SyncGamePasses, player)
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(StoreService.OnPurchaseGamePass)
	MarketplaceService.ProcessReceipt = StoreService.OnPurchaseDevProduct
end

return StoreService
