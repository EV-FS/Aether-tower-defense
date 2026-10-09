local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)
local DataService

local TradeRecords = MemoryStoreService:GetHashMap("PendingTrades_v1")
local PlayerPendings = MemoryStoreService:GetHashMap("PlayerPending_v1")

local RECORD_TTL = (45 * 24 * 60 * 60) - 1
local MAX_TRADING_HISTORY = 50
local MAX_RECORD_BYTES = 30 * 1024

local TradePending = {}

function TradePending.Init(services)
	DataService = services:GetService("DataService")
end

function TradePending.GetRecord(sessionId: string)
	return TradeRecords:GetAsync(sessionId)
end

function TradePending.SaveRecord(session): (boolean, string?)
	local createdAt = os.time()

	local sessionId = session.SessionId
	if not sessionId then
		return false
	end

	local plr1UserId = session.Player1.UserId
	local plr2UserId = session.Player2.UserId
	if not plr1UserId or not plr2UserId then
		return false
	end

	local plr1Offers = TableUtils.DeepCopy(session.Offers[session.Player1])
	local plr2Offers = TableUtils.DeepCopy(session.Offers[session.Player2])

	local record = {
		SchemaVersion = 1,
		TradeId = sessionId,
		State = "Prepared",
		CreatedAt = createdAt,
		ExpiresAt = createdAt + RECORD_TTL,

		UserIds = {
			plr1UserId,
			plr2UserId,
		},

		Offers = {
			[tostring(session.Player1.UserId)] = plr1Offers,
			[tostring(session.Player2.UserId)] = plr2Offers,
		},
	}

	local success, errorMsg = pcall(function()
		local bytes = #HttpService:JSONEncode(record)
		if bytes > MAX_RECORD_BYTES then
			warn(`거래 기록이 너무 큼: {bytes} bytes`)
		end

		TradeRecords:SetAsync(session.SessionId, record, RECORD_TTL)
	end)

	return success, errorMsg
end

function TradePending.CommitRecord(sessionId: string)
	if typeof(sessionId) ~= "string" then
		return false
	end

	local success, newPending = pcall(function()
		return TradeRecords:UpdateAsync(sessionId, function(resource)
			if not resource then
				return
			end

			if resource.State == "Prepared" then
				resource.State = "Committing"
			end
			resource.ExpiresAt = os.time() + RECORD_TTL

			return resource
		end, RECORD_TTL)
	end)

	return success and typeof(newPending) == "table" and newPending.State == "Committing", newPending
end

function TradePending.CancelRecord(sessionId: string)
	if typeof(sessionId) ~= "string" then
		return false
	end

	local success, newPending = pcall(function()
		return TradeRecords:UpdateAsync(sessionId, function(resource)
			if not resource then
				return
			end

			if resource.State == "Prepared" then
				resource.State = "Cancelled"
			end
			resource.ExpiresAt = os.time() + RECORD_TTL

			return resource
		end, RECORD_TTL)
	end)

	return success, newPending
end

function TradePending.CompleteRecord(sessionId: string)
	if typeof(sessionId) ~= "string" then
		return false
	end

	local success, newPending = pcall(function()
		return TradeRecords:UpdateAsync(sessionId, function(resource)
			if not resource then
				return
			end

			resource.State = "Completed"
			resource.ExpiresAt = os.time() + RECORD_TTL

			return resource
		end, RECORD_TTL)
	end)

	return success, newPending
end

function TradePending.GetPlayerPending(userId: number)
	local sessionId = PlayerPendings:GetAsync(tostring(userId))
	return if sessionId == "" then nil else sessionId
end

function TradePending.GetPlayerTradeOffers(record, playerUserId: number)
	local otherUserId
	for _, userId in record.UserIds do
		if userId ~= playerUserId then
			otherUserId = userId
			break
		end
	end

	return record.Offers[tostring(playerUserId)], record.Offers[tostring(otherUserId)]
end

function TradePending.SetPlayerPending(userId: number, sessionId: string)
	if typeof(userId) ~= "number" then
		return false
	end

	if typeof(sessionId) ~= "string" then
		return false
	end

	local success, errorMsg = pcall(function()
		PlayerPendings:SetAsync(tostring(userId), sessionId, RECORD_TTL)
	end)

	return success, errorMsg
end

function TradePending.AppendHistory(player: Player, sessionId: string)
	if typeof(sessionId) ~= "string" then
		return
	end

	local playerData = DataService:GetData(player)
	if not playerData then
		return
	end

	local tradeHistory = TableUtils.DeepCopy(playerData.TradeHistory) or {}
	table.insert(tradeHistory, sessionId)

	if tradeHistory[MAX_TRADING_HISTORY + 1] then
		table.remove(tradeHistory, 1)
	end

	DataService:UpdateData(player, "TradeHistory", tradeHistory)
end

function TradePending.ClearPlayerPending(userId: number, sessionId: string)
	if typeof(userId) ~= "number" or typeof(sessionId) ~= "string" or sessionId == "" then
		return false
	end

	local success, result = pcall(function()
		return PlayerPendings:UpdateAsync(tostring(userId), function(current)
			if current and current ~= "" and current ~= sessionId then
				return nil
			end

			-- 빈 값은 조회에서 nil로 처리하고 1초 뒤 만료시킨다.
			return ""
		end, 1)
	end)
	if not success then
		return false, result
	end

	return result == ""
end

return TradePending
