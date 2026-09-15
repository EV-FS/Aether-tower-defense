local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

-------------------------------------------------
--// Local Functions
-------------------------------------------------
local function HasTradeRequest(requester: Player, receiver: Player)
	return RequestLog[`{requester.UserId}-{receiver.UserId}`] ~= nil
end

-------------------------------------------------
--// TradeService
-------------------------------------------------
local TradeService = {}

function TradeService.SendRequest(requester: Player, receiver: Player): (boolean, string?)
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
	TradeService.StartTrade(requester, acceptor)

	return true
end

function TradeService.StartTrade(player1: Player, player2: Player): Session?
	if player1 == player2 then
		return
	end
	if not DataService:GetData(player1) or not DataService:GetData(player2) then
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

	local success = targetSession:AddOffer(player, offerData.offerType, offerData.offerName, offerData.offerArg)
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

	local success = targetSession:RemoveOffer(player, offerData.offerType, offerData.offerName, offerData.offerArg)
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

	targetSession:Break(reason or "The trade has been cancelled.")
	return true
end

function TradeService.Init(services: any)
	DataService = services:GetService("DataService")
	SettingsService = services:GetService("SettingsService")

	TradeSession.Init(services)
end

function TradeService.Start()
	Players.PlayerRemoving:Connect(function(player: Player)
		local playerSession = TradeSession.GetSessionFromPlayer(player)
		if playerSession then
			TradeService.CancelTrade(
				playerSession.SessionId,
				`The trade was cancelled because {player.DisplayName} left the game.`
			)
		end
	end)

	--/Event
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

	--/Functions: Request
	Net.TradeService.SendRequest.On(function(player: Player, receiver: Player): { Success: boolean, Reason: string? }
		local success, reason = TradeService.SendRequest(player, receiver)
		return { Success = success, Reason = reason }
	end)
	Net.TradeService.AcceptRequest.On(function(player: Player, requester: Player): { Success: boolean, Reason: string? }
		local success, reason = TradeService.AcceptRequest(requester, player)
		return { Success = success, Reason = reason }
	end)

	--/Functions: OnTrading
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
