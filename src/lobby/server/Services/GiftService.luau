--/Services
local MarketplaceService = game:GetService("MarketplaceService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local HttpService = game:GetService("HttpService")
local UserService = game:GetService("UserService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Shared.Net)
local PurchaseData = require(ReplicatedStorage.Settings.Data.PurchaseData)
local DataService

--/Constants
local INTENT_TTL = 7200
local CANCEL_WINDOW = 30
local ALLOW_SELF_GIFT = true
local VERIFY_RECIPIENT = true
local VERIFY_FAIL_OPEN = false
local RATE_WINDOW = 10
local RATE_MAX = 3
local INVALID_CACHE_TTL = 60
local INVALID_CACHE_MAX = 500

local STORE_TTL = INTENT_TTL + 60
local RECEIPT_TTL = 30 * 24 * 3600

--/Variables
local IntentMap = MemoryStoreService:GetHashMap("GiftIntent_v1")
local ReceiptMap = MemoryStoreService:GetHashMap("GiftReceipt_v1")

local rateLimits: { [number]: { count: number, reset: number } } = {}
local invalidUserCache: { [number]: number } = {}
local invalidCacheCount = 0

-------------------------------------------------
--// Local Functions
-------------------------------------------------
local function isValidId(n: any): boolean
	return type(n) == "number" and n % 1 == 0 and n > 0
end

local function isGiftable(productId: number): boolean
	local product = PurchaseData.ById[productId]
	return product ~= nil and product.Category == "DevProducts" and product.Giftable ~= false
end

local function checkRate(userId: number): boolean
	local now = os.clock()
	local userRate = rateLimits[userId]

	if not userRate or now > userRate.reset then
		rateLimits[userId] = { count = 1, reset = now + RATE_WINDOW }
		return true
	end

	if userRate.count >= RATE_MAX then
		return false
	end

	userRate.count += 1
	return true
end

local function isCachedInvalid(id: number): boolean
	local ts = invalidUserCache[id]
	return ts ~= nil and (os.time() - ts) < INVALID_CACHE_TTL
end

local function markInvalid(id: number)
	if not invalidUserCache[id] then
		invalidCacheCount += 1
	end
	invalidUserCache[id] = os.time()

	if invalidCacheCount > INVALID_CACHE_MAX then
		table.clear(invalidUserCache)
		invalidCacheCount = 0
	end
end

local function intentIsLive(existing: any): boolean
	return type(existing) == "table"
		and existing.consumed ~= true
		and type(existing.expiresAt) == "number"
		and os.time() <= existing.expiresAt
end

local function acquireIntent(buyerId: number, intent: any): (boolean, string?)
	local ok, result = pcall(function()
		return IntentMap:UpdateAsync(tostring(buyerId), function(existing)
			if intentIsLive(existing) then
				return existing
			end
			return intent
		end, STORE_TTL)
	end)

	if not ok then
		return false, "memorystore_error"
	end

	if result and result.nonce == intent.nonce then
		return true
	end

	return false, "already_pending"
end

local function readIntent(buyerId: number): (boolean, any)
	local ok, intent = pcall(function()
		return IntentMap:GetAsync(tostring(buyerId))
	end)

	if not ok or not intentIsLive(intent) then
		return ok, nil
	end

	return true, intent
end

local function consumeIntent(buyerId: number, nonce: string)
	pcall(function()
		IntentMap:UpdateAsync(tostring(buyerId), function(existing)
			if existing and existing.nonce == nonce then
				existing.consumed = true
			end
			return existing
		end, STORE_TTL)
	end)
end

local function readReceipt(purchaseId: string): (boolean, any)
	local ok, rec = pcall(function()
		return ReceiptMap:GetAsync(purchaseId)
	end)

	if not ok then
		return false, nil
	end

	return true, rec
end

local function markReceipt(purchaseId: string, recipientId: number, nonce: string): boolean
	local ok = pcall(function()
		ReceiptMap:UpdateAsync(purchaseId, function(existing)
			if existing then
				return existing
			end
			return {
				recipientId = recipientId,
				nonce = nonce,
				ts = os.time(),
			}
		end, RECEIPT_TTL)
	end)
	return ok
end

local function notify(player: Player?, event: string, payload: any)
	if not player or not player.Parent then
		return
	end
	pcall(function()
		Net.GiftService[event]:Fire(player, payload)
	end)
end

-------------------------------------------------
--// GiftService
-------------------------------------------------
local GiftService = {}

function GiftService.Init(services)
	DataService = services:GetService("DataService")
end

function GiftService.Start()
	Net.GiftService.RequestGift.On(function(player: Player, productId: any, recipientId: any)
		return GiftService:PromptGift(player, productId, recipientId)
	end)

	Players.PlayerRemoving:Connect(function(player)
		rateLimits[player.UserId] = nil
	end)

	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, isPurchased)
		if isPurchased or not isGiftable(productId) then
			return
		end

		pcall(function()
			IntentMap:UpdateAsync(tostring(userId), function(existing)
				if
					existing
					and not existing.consumed
					and existing.productId == productId
					and (os.time() - (existing.ts or 0)) <= CANCEL_WINDOW
				then
					existing.consumed = true
				end
				return existing
			end, STORE_TTL)
		end)
	end)
end

function GiftService:PromptGift(buyer: Player, productId: number, recipientId: number): (boolean, string?)
	if not isValidId(productId) or not isValidId(recipientId) then
		return false, "invalid_arguments"
	end
	if typeof(buyer) ~= "Instance" or not buyer:IsA("Player") then
		return false, "bad_buyer"
	end
	if not isGiftable(productId) then
		return false, "not_giftable"
	end
	if not ALLOW_SELF_GIFT and recipientId == buyer.UserId then
		return false, "self_gift_disabled"
	end

	if not checkRate(buyer.UserId) then
		return false, "rate_limited"
	end

	if VERIFY_RECIPIENT then
		if isCachedInvalid(recipientId) then
			return false, "recipient_not_found"
		end

		local ok, infos = pcall(function()
			return UserService:GetUserInfosByUserIdsAsync({ recipientId })
		end)

		if ok then
			if type(infos) ~= "table" or #infos == 0 then
				markInvalid(recipientId)
				return false, "recipient_not_found"
			end
		elseif not VERIFY_FAIL_OPEN then
			return false, "verify_unavailable"
		end
	end

	local now = os.time()
	local intent = {
		nonce = HttpService:GenerateGUID(false),
		recipientId = recipientId,
		productId = productId,
		ts = now,
		expiresAt = now + INTENT_TTL,
	}

	local acquired, why = acquireIntent(buyer.UserId, intent)
	if not acquired then
		return false, why
	end

	local promptOk = pcall(function()
		MarketplaceService:PromptProductPurchase(buyer, productId)
	end)

	if not promptOk then
		consumeIntent(buyer.UserId, intent.nonce)
		return false, "prompt_failed"
	end

	return true
end

function GiftService:HandleReceipt(receiptInfo: any): Enum.ProductPurchaseDecision?
	if type(receiptInfo) ~= "table" or not isValidId(receiptInfo.PlayerId) or not isValidId(receiptInfo.ProductId) then
		return nil
	end

	local playerId = receiptInfo.PlayerId
	local purchaseId = tostring(receiptInfo.PurchaseId)

	local recOk, rec = readReceipt(purchaseId)
	if not recOk then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if rec then
		if type(rec.nonce) == "string" then
			consumeIntent(playerId, rec.nonce)
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local ok, intent = readIntent(playerId)
	if not ok then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if not intent or intent.productId ~= receiptInfo.ProductId then
		return nil
	end

	local sendOk, delivered = pcall(function()
		return DataService:SendGift(intent.recipientId, {
			purchaseId = purchaseId,
			productId = receiptInfo.ProductId,
			fromUserId = playerId,
			ts = os.time(),
		})
	end)

	if not sendOk or delivered ~= true then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if not markReceipt(purchaseId, intent.recipientId, intent.nonce) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	consumeIntent(playerId, intent.nonce)
	notify(Players:GetPlayerByUserId(playerId), "GiftPurchaseComplete", {
		recipientId = intent.recipientId,
		productId = receiptInfo.ProductId,
	})

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

return GiftService
