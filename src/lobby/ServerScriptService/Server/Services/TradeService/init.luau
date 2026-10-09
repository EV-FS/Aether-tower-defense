local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TradePending = require(script.TradePending)
local Net = require(ReplicatedStorage.Shared.Net)
local TradeSession = require(script.TradeSession)
local DataService
local SettingsService

--/Types
type OfferData = TradeSession.OfferData
type Session = TradeSession.Session
type RequestLog = { [string]: number }

local REQUEST_COOLDOWN = 15
local REQUEST_TIMEOUT = 30

local RequestLog: RequestLog = {}
local ResolvingPlayers: { [Player]: boolean } = {}

-------------------------------------------------
--// Local Functions
-------------------------------------------------
local function HasTradeRequest(requester: Player, receiver: Player)
	return RequestLog[`{requester.UserId}-{receiver.UserId}`] ~= nil
end

local function CanTrade(player: Player): boolean
	if DataService:IsLocked(player) then
		return false
	end
	local data = DataService:GetData(player)
	return data ~= nil and data.TradeReservations == nil and not DataService:IsLocked(player)
end

local function ClearPendingTrade(player: Player, profile, sessionId: string): boolean
	local data = profile.Data
	local saved = profile.LastSavedData
	local needsSave = data.TradeReservations ~= nil
		or (saved.TradeReservations ~= nil and saved.TradeReservations.SessionId == sessionId)
		or (data._LastAppliedTradeId == sessionId and saved._LastAppliedTradeId ~= sessionId)

	if not TradeSession.ReleaseOfferAssets(player, sessionId) then
		return false
	end
	if needsSave and not DataService:SaveDataAsync(player) then
		return false
	end
	if not profile:IsActive() then
		return false
	end

	return TradePending.ClearPlayerPending(player.UserId, sessionId)
end

local function ResolvePlayerTrade(player: Player): boolean
	local profile = DataService:GetProfile(player)
	if not profile or not profile:IsActive() then
		return false
	end

	local pendingId = TradePending.GetPlayerPending(player.UserId)
	if not profile:IsActive() then
		return false
	end

	local reservation = profile.Data.TradeReservations
	local reservationId = reservation and reservation.SessionId
	if reservation and (typeof(reservationId) ~= "string" or reservationId == "") then
		return false
	end

	if pendingId and reservationId and pendingId ~= reservationId then
		return false
	end

	local savedReservation = profile.LastSavedData.TradeReservations
	local sessionId = pendingId or reservationId or (savedReservation and savedReservation.SessionId)
	if not sessionId then
		return true
	end
	if typeof(sessionId) ~= "string" or sessionId == "" then
		return false
	end
	if profile.LastSavedData._LastAppliedTradeId == sessionId then
		return ClearPendingTrade(player, profile, sessionId)
	end

	local record = TradePending.GetRecord(sessionId)
	if record and (typeof(record.UserIds) ~= "table" or not table.find(record.UserIds, player.UserId)) then
		return false
	end

	if record and record.State == "Prepared" then
		local cancelled
		cancelled, record = TradePending.CancelRecord(sessionId)
		if not cancelled then
			return false
		end
	end

	if not profile:IsActive() then
		return false
	end

	if not record or record.State == "Cancelled" then
		return ClearPendingTrade(player, profile, sessionId)
	end

	if record.State ~= "Committing" then
		return false
	end

	local playerOffer, otherOffer = TradePending.GetPlayerTradeOffers(record, player.UserId)
	if not playerOffer or not otherOffer then
		return false
	end
	if not TradeSession.ApplyPlayerTrade(player, sessionId, playerOffer, otherOffer) then
		return false
	end

	return ClearPendingTrade(player, profile, sessionId)
end

-------------------------------------------------
--// TradeService
-------------------------------------------------
local TradeService = {}

function TradeService.SendRequest(requester: Player, receiver: Player): (boolean, string?)
	if not CanTrade(requester) or not CanTrade(receiver) then
		return false, "One of the players has an incomplete trade."
	end
	if not SettingsService:GetSettings(requester, "Trade") then
		return false, "Trading is turned off. Enable it in Settings to send trade requests."
	end

	if not SettingsService:GetSettings(receiver, "Trade") then
		return false, `{receiver.DisplayName} isn't accepting trade requests right now.`
	end

	if HasTradeRequest(receiver, requester) then
		return TradeService.AcceptRequest(receiver, requester)
	end

	local key = `{requester.UserId}-{receiver.UserId}`
	local lastRequest = RequestLog[key]
	if lastRequest and os.clock() - lastRequest < REQUEST_COOLDOWN then
		return false,
			`You're sending trade requests too quickly. Try again in {REQUEST_COOLDOWN - (os.clock() - lastRequest)} seconds.`
	end
	if requester == receiver then
		return false, "You can't trade with yourself."
	end
	if not DataService:GetData(requester) or not DataService:GetData(receiver) then
		return false, "Player data is still loading. Please try again in a moment."
	end
	if TradeSession.GetSessionFromPlayer(requester) or TradeSession.GetSessionFromPlayer(receiver) then
		return false, "One of the players is already in a trade."
	end

	local requestedAt = os.clock()
	RequestLog[key] = requestedAt

	task.delay(REQUEST_TIMEOUT, function()
		if RequestLog[key] == requestedAt then
			RequestLog[key] = nil
		end
	end)

	Net.TradeService.RequestReceived.Fire(receiver, requester)

	return true
end

function TradeService.AcceptRequest(requester: Player, acceptor: Player): (boolean, string?)
	if not CanTrade(requester) or not CanTrade(acceptor) then
		return false, "One of the players has an incomplete trade."
	end
	if not SettingsService:GetSettings(requester, "Trade") then
		return false, `{requester.DisplayName} has turned off trading.`
	end

	if not SettingsService:GetSettings(acceptor, "Trade") then
		return false, "Trading is turned off. Enable it in Settings to accept trade requests."
	end

	local key = `{requester.UserId}-{acceptor.UserId}`
	local lastRequest = RequestLog[key]
	if not lastRequest then
		return false, "This trade request is no longer available."
	end

	if os.clock() - lastRequest > REQUEST_TIMEOUT then
		return false, "This trade request has expired."
	end
	if TradeSession.GetSessionFromPlayer(requester) or TradeSession.GetSessionFromPlayer(acceptor) then
		return false, "One of the players is already in a trade."
	end

	RequestLog[key] = nil
	if not TradeService.StartTrade(requester, acceptor) then
		return false, "One of the players cannot start a trade right now."
	end
	return true
end

function TradeService.StartTrade(player1: Player, player2: Player): Session?
	if not CanTrade(player1) or not CanTrade(player2) then
		return
	end
	if player1 == player2 then
		return
	end
	local success, pending = pcall(function()
		return TradePending.GetPlayerPending(player1.UserId) or TradePending.GetPlayerPending(player2.UserId)
	end)
	if not success or pending then
		return
	end
	if not CanTrade(player1) or not CanTrade(player2) then
		return
	end
	if TradeSession.GetSessionFromPlayer(player1) or TradeSession.GetSessionFromPlayer(player2) then
		return
	end

	local session: Session = TradeSession.new(player1, player2)

	Net.TradeService.TradeStarted.FireList({ session.Player1, session.Player2 }, {
		Player1 = session.Player1,
		Player2 = session.Player2,
	})

	return session
end

function TradeService.AddOffer(sessionId: string, player: Player, offerData: OfferData)
	local targetSession = TradeSession.GetSessionFromId(sessionId)
	if not targetSession then
		warn(`요청 한 세션: {sessionId}가 존재하지 않음`)
		return
	end

	local success = targetSession:AddOffer(
		player,
		offerData.offerType,
		offerData.offerName,
		offerData.offerArg,
		offerData.offerArg2
	)

	if success then
		Net.TradeService.OfferChanged.FireList({ targetSession.Player1, targetSession.Player2 }, {
			Offerer = player,
			Offer = targetSession.Offers[player],
			Version = targetSession.Version,
		})
	end
end

function TradeService.RemoveOffer(sessionId: string, player: Player, offerData: OfferData)
	local targetSession = TradeSession.GetSessionFromId(sessionId)
	if not targetSession then
		warn(`요청 한 세션: {sessionId}가 존재하지 않음`)
		return
	end

	local success = targetSession:RemoveOffer(
		player,
		offerData.offerType,
		offerData.offerName,
		offerData.offerArg,
		offerData.offerArg2
	)

	if success then
		Net.TradeService.OfferChanged.FireList({ targetSession.Player1, targetSession.Player2 }, {
			Offerer = player,
			Offer = targetSession.Offers[player],
			Version = targetSession.Version,
		})
	end
end

function TradeService.SetReady(sessionId: string, player: Player, action: boolean, clientVersion: number): boolean
	local targetSession = TradeSession.GetSessionFromId(sessionId)
	if not targetSession then
		warn(`요청 한 세션: {sessionId}가 존재하지 않음`)
		return false
	end

	return targetSession:SetReady(player, action, clientVersion)
end

function TradeService.CancelTrade(sessionId: string, reason: string?)
	local targetSession = TradeSession.GetSessionFromId(sessionId)
	if not targetSession then
		warn(`요청 한 세션: {sessionId}가 존재하지 않음`)
		return false
	end
	if targetSession.CurrentState == "Committing" then
		return false
	end

	targetSession:Break(reason or "The trade has been cancelled.")
	return true
end

function TradeService.ResolvePendingTrade(player: Player): boolean
	if ResolvingPlayers[player] or TradeSession.GetSessionFromPlayer(player) then
		return false
	end
	ResolvingPlayers[player] = true
	DataService:Lock(player)

	local success, resolved = pcall(ResolvePlayerTrade, player)
	ResolvingPlayers[player] = nil
	if success and resolved and player.Parent == Players then
		DataService:Unlock(player)
		return true
	end
	if not success then
		warn(`거래 복구 실패: {player.UserId}, {tostring(resolved)}`)
	end
	return false
end

function TradeService.Init(services: any)
	DataService = services:GetService("DataService")
	SettingsService = services:GetService("SettingsService")

	TradeSession.Init(services)
	TradePending.Init(services)

	Players.PlayerAdded:Connect(function(player: Player)
		DataService:Lock(player)
	end)
	for _, player in Players:GetPlayers() do
		DataService:Lock(player)
	end
end

function TradeService.Start()
	local function onPlayerAdded(player: Player)
		for attempt = 1, 3 do
			if player.Parent ~= Players then
				return
			end
			if TradeService.ResolvePendingTrade(player) then
				return
			end
			if attempt < 3 then
				task.wait(attempt)
			end
		end
		warn(`거래 복구 미완료: {player.UserId}`)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		local playerSession = TradeSession.GetSessionFromPlayer(player)
		if playerSession then
			TradeService.CancelTrade(
				playerSession.SessionId,
				`The trade was cancelled because {player.DisplayName} left the game.`
			)
		end
	end)

	--/이벤트
	TradeSession.ReadyChanged:Connect(function(sessionId: string, player: Player, isReady: boolean)
		local session = TradeSession.GetSessionFromId(sessionId)
		if not session then
			return
		end

		Net.TradeService.ReadyChanged.FireList({ session.Player1, session.Player2 }, {
			UserId = player.UserId,
			IsReady = isReady,
		})
	end)

	TradeSession.StartCommitting:Connect(function(sessionId: string)
		local session = TradeSession.GetSessionFromId(sessionId)
		if not session then
			return
		end

		Net.TradeService.StartCommitting.FireList({ session.Player1, session.Player2 })
	end)

	TradeSession.TradeEnded:Connect(function(sessionId: string, endType: "Completed" | "Cancelled", reason: string)
		local targetSession = TradeSession.GetSessionFromId(sessionId)
		if not targetSession then
			return
		end

		Net.TradeService.TradeEnded.FireList({ targetSession.Player1, targetSession.Player2 }, {
			EndType = endType,
			Reason = reason,
		})
	end)

	--/거래 요청
	Net.TradeService.SendRequest.On(function(player: Player, receiver: Player): { Success: boolean, Reason: string? }
		local success, reason = TradeService.SendRequest(player, receiver)
		return { Success = success, Reason = reason }
	end)
	Net.TradeService.AcceptRequest.On(function(player: Player, requester: Player): { Success: boolean, Reason: string? }
		local success, reason = TradeService.AcceptRequest(requester, player)
		return { Success = success, Reason = reason }
	end)

	--/거래 안에서 그거 뭐냐 그 아무튼 Functions
	Net.TradeService.AddOffer.On(function(player: Player, offerData: OfferData)
		local targetSession = TradeSession.GetSessionFromPlayer(player)
		if not targetSession then
			return
		end

		TradeService.AddOffer(targetSession.SessionId, player, offerData)
	end)
	Net.TradeService.RemoveOffer.On(function(player: Player, offerData: OfferData)
		local targetSession = TradeSession.GetSessionFromPlayer(player)
		if not targetSession then
			return
		end

		TradeService.RemoveOffer(targetSession.SessionId, player, offerData)
	end)
	Net.TradeService.SetReady.On(function(player: Player, data: { Action: boolean, Version: number })
		local targetSession = TradeSession.GetSessionFromPlayer(player)
		if not targetSession then
			return false
		end

		return TradeService.SetReady(targetSession.SessionId, player, data.Action, data.Version)
	end)
	Net.TradeService.CancelTrade.On(function(player: Player)
		local targetSession = TradeSession.GetSessionFromPlayer(player)
		if not targetSession then
			return
		end

		TradeService.CancelTrade(targetSession.SessionId)
	end)
end

return TradeService
