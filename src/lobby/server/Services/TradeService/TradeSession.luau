--/Services
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

--/Modules
local Signal = require(ReplicatedStorage.Packages.Signal)
local DataService: any = require(ServerScriptService.Server.Services.DataService)
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)

--/Types
export type OfferType = "Tower" | "Item"
export type TowerSnapshot = { [string]: any }
export type TowerOffers = { [string]: { [string]: TowerSnapshot } }
export type ItemOffers = { [string]: number }

export type TradeOffer = {
	Towers: TowerOffers,
	Items: ItemOffers,
}

export type TradeState = "Building" | "Countdown" | "Committing" | "Completed" | "Cancelled"

export type OfferData = {
	offerType: OfferType,
	offerName: string,
	offerArg: (string | number)?,
}

export type Session = {
	SessionId: string,
	Player1: Player,
	Player2: Player,
	Version: number,
	Offers: { [Player]: TradeOffer },
	Ready: { [Player]: boolean },
	_CountdownConn: thread?,
	CurrentState: TradeState,

	AddOffer: (
		self: Session,
		offerGiver: Player,
		offerType: OfferType,
		offerName: string,
		offerArg: (string | number)?
	) -> (),
	RemoveOffer: (
		self: Session,
		offerGiver: Player,
		offerType: OfferType,
		offerName: string,
		offerArg: (string | number)?
	) -> (),
	SetReady: (self: Session, player: Player, action: boolean, clientVersion: number) -> boolean,
	ResetReady: (self: Session) -> (),
	BeginCountdown: (self: Session) -> (),
	CancelCountdown: (self: Session) -> (),
	ValidateTrade: (self: Session) -> (boolean, string?),
	CommitTrade: (self: Session) -> (),
	Destroy: (self: Session) -> (),
}

--/Constants
local COUNTDOWN_TIME = 5

--/Variables
local ActiveSessions: { [string]: Session } = {}
local PlayerToSession: { [Player]: Session } = {}

-------------------------------------------------
--// Local Functions
-------------------------------------------------
local function GetTblPath(parentTable: TowerOffers, key: string): { [string]: TowerSnapshot }
	parentTable[key] = parentTable[key] or {}

	return parentTable[key]
end

local function FindParticipant(targetPlayer: Player, plr1: Player, plr2: Player): Player?
	if targetPlayer == plr1 then
		return plr1
	elseif targetPlayer == plr2 then
		return plr2
	else
		return nil
	end
end

local function VerifyTower(player: Player, towerName: string, towerKey: string): TowerSnapshot?
	local playerData = DataService:GetData(player)
	if not playerData then
		return nil
	end

	local towerCategory = playerData.OwnedTowers[towerName]
	if not towerCategory then
		return nil
	end

	local targetTower = towerCategory[towerKey]
	if not targetTower then
		return nil
	end

	return targetTower
end

local function VerifyItem(player: Player, itemName: string, amount: number): boolean
	local playerData = DataService:GetData(player)
	if not playerData then
		return false
	end

	local targetItem = playerData.Inventory.Items[itemName]
	if not targetItem or targetItem < (amount or 1) then
		return false
	end

	return true
end

local function ApplyDeductions(player: Player, offer: TradeOffer)
	for towerName, towerKeys in offer.Towers do
		for towerKey in towerKeys do
			DataService:RemoveTower(player, towerName, towerKey)
		end
	end

	for itemName, amount in offer.Items do
		DataService:AddData(player, "Inventory", -amount, "Items", itemName)
	end
end

local function GrantResult(player: Player, offer: TradeOffer)
	for towerName, towerKeys in offer.Towers do
		for _, towerData in towerKeys do
			DataService:AddTower(player, towerName, towerData)
		end
	end

	for itemName, amount in offer.Items do
		DataService:AddData(player, "Inventory", amount, "Items", itemName)
	end
end

-------------------------------------------------
--// TradeSession
-------------------------------------------------
local TradeSession = {}
TradeSession.__index = TradeSession
TradeSession.ReadyChanged = Signal.new()
TradeSession.StartCountdown = Signal.new()
TradeSession.TradeEnded = Signal.new()

function TradeSession.GetSessionFromId(sessionId: string): Session?
	return ActiveSessions[sessionId]
end

function TradeSession.GetSessionFromPlayer(player: Player): Session?
	return PlayerToSession[player]
end

function TradeSession.new(plr1: Player, plr2: Player): Session
	local self = setmetatable({}, TradeSession)
	self.SessionId = HttpService:GenerateGUID(false)
	self.Player1 = plr1
	self.Player2 = plr2
	self.Version = 0

	self.Offers = {
		[self.Player1] = {
			Towers = {},
			Items = {},
		},
		[self.Player2] = {
			Towers = {},
			Items = {},
		},
	}
	self.Ready = {
		[self.Player1] = false,
		[self.Player2] = false,
	}

	self._CountdownConn = nil
	self.CurrentState = "Building"

	ActiveSessions[self.SessionId] = self
	PlayerToSession[self.Player1] = self
	PlayerToSession[self.Player2] = self

	return self
end

function TradeSession:OnOfferChanged()
	self.Version += 1
	self:ResetReady()
end

function TradeSession:AddOffer(
	offerGiver: Player,
	offerType: OfferType,
	offerName: string,
	offerArg: (string | number)?
)
	if self.CurrentState ~= "Building" then
		return false
	end

	local targetPlayer = FindParticipant(offerGiver, self.Player1, self.Player2)
	if not targetPlayer then
		return false
	end

	if offerType == "Tower" then
		if typeof(offerArg) ~= "string" then
			return false
		end

		local targetTower = VerifyTower(targetPlayer, offerName, offerArg)
		if not targetTower then
			return false
		end

		GetTblPath(self.Offers[targetPlayer].Towers, offerName)[offerArg] = TableUtils.DeepCopy(targetTower)
	elseif offerType == "Item" then
		if typeof(offerArg) == "string" then
			return false
		end

		local currentAmount = self.Offers[targetPlayer].Items[offerName] or 0
		if currentAmount < 0 then
			return false
		end

		local canAffort = VerifyItem(targetPlayer, offerName, currentAmount + (offerArg or 1))
		if not canAffort then
			return false
		end

		self.Offers[targetPlayer].Items[offerName] += (offerArg or 1)
	else
		warn(`알 수 없는 OfferType: {offerType}.`)
		return false
	end

	self:OnOfferChanged()

	return true
end

function TradeSession:RemoveOffer(
	offerGiver: Player,
	offerType: OfferType,
	offerName: string,
	offerArg: (string | number)?
)
	if self.CurrentState ~= "Building" then
		return false
	end

	local targetPlayer = FindParticipant(offerGiver, self.Player1, self.Player2)
	if not targetPlayer then
		return false
	end

	if offerType == "Tower" then
		if typeof(offerArg) ~= "string" then
			return false
		end

		local offeredCategory = self.Offers[targetPlayer].Towers[offerName]
		if not offeredCategory then
			return false
		end

		local offeredTower = self.Offers[targetPlayer].Towers[offerName][offerArg]
		if not offeredTower then
			return false
		end

		GetTblPath(self.Offers[targetPlayer].Towers, offerName)[offerArg] = nil
	elseif offerType == "Item" then
		if typeof(offerArg) == "string" then
			return false
		end

		local subtractValue = self.Offers[targetPlayer].Items[offerName] - (offerArg or 1)
		self.Offers[targetPlayer].Items[offerName] = math.max(subtractValue, 0)
	else
		warn(`알 수 없는 OfferType: {offerType}.`)
		return false
	end

	self:OnOfferChanged()

	return true
end

function TradeSession:SetReady(player: Player, action: boolean, clientVersion: number)
	if self.CurrentState ~= "Building" and self.CurrentState ~= "Countdown" then
		return false
	end

	if typeof(clientVersion) ~= "number" or self.Version ~= clientVersion then
		return false
	end

	local targetPlayer = FindParticipant(player, self.Player1, self.Player2)
	if not targetPlayer then
		return false
	end
	if self.Ready[targetPlayer] == action then
		return false
	end

	self.Ready[targetPlayer] = action
	self.ReadyChanged:Fire(self.SessionId, targetPlayer, action)

	if action == true then
		local otherPlayer = if targetPlayer == self.Player1 then self.Player2 else self.Player1
		if self.Ready[otherPlayer] == true then
			self:BeginCountdown()
		end
	elseif action == false then
		if self.CurrentState == "Countdown" then
			self:CancelCountdown()
		end
	end

	return true
end

function TradeSession:ResetReady()
	for _, player in { self.Player1, self.Player2 } do
		if not self.Ready[player] then
			continue
		end

		self.Ready[player] = false
		self.ReadyChanged:Fire(self.SessionId, player, false)
	end
end

function TradeSession:BeginCountdown()
	if self.CurrentState ~= "Building" then
		return
	end

	self.CurrentState = "Countdown"

	self._CountdownConn = task.delay(COUNTDOWN_TIME, function()
		self._CountdownConn = nil
		self:CommitTrade()
	end)
end

function TradeSession:CancelCountdown()
	if self.CurrentState == "Committing" then
		return
	end

	self:ResetReady()
	self.CurrentState = "Building"

	if self._CountdownConn then
		task.cancel(self._CountdownConn)
		self._CountdownConn = nil
	end
end

function TradeSession:ValidateTrade(): (boolean, string?)
	if not self.Player1:IsDescendantOf(Players) or not self.Player2:IsDescendantOf(Players) then
		return false, "A player left the game before the trade could be completed."
	end

	for player, offers in self.Offers do
		local playerData = DataService:GetData(player)
		if not playerData then
			return false, `Couldn't load {player.DisplayName}'s data. The trade has been cancelled.`
		end

		for towerName, towerKeys in offers.Towers do
			if not playerData.OwnedTowers[towerName] then
				return false, `{player.DisplayName} no longer has the {towerName} tower. The trade has been cancelled.`
			end

			for towerKey in towerKeys do
				if not playerData.OwnedTowers[towerName][towerKey] then
					return false,
						`{player.DisplayName} no longer has the {towerName} tower. The trade has been cancelled.`
				end
			end
		end

		for itemName, amount in offers.Items do
			if (playerData.Inventory.Items[itemName] or 0) < amount then
				return false, `{player.DisplayName} no longer has enough {itemName}. The trade has been cancelled.`
			end
		end
	end

	return true
end

function TradeSession:CommitTrade()
	if self.CurrentState ~= "Countdown" then
		return
	end

	self.CurrentState = "Committing"

	local valid, reason = self:ValidateTrade()
	if not valid then
		self:Break(reason)
		return
	end

	ApplyDeductions(self.Player1, self.Offers[self.Player1])
	ApplyDeductions(self.Player2, self.Offers[self.Player2])

	GrantResult(self.Player1, self.Offers[self.Player2])
	GrantResult(self.Player2, self.Offers[self.Player1])

	DataService:SaveData(self.Player1)
	DataService:SaveData(self.Player2)

	self:Complete()
end

function TradeSession:Complete()
	self.CurrentState = "Completed"

	self.TradeEnded:Fire(self.SessionId, "Completed")
	self:EndSession()
end

function TradeSession:Break(reason: string?)
	self.CurrentState = "Cancelled"

	self.TradeEnded:Fire(self.SessionId, "Cancelled", reason)
	self:EndSession()
end

function TradeSession:EndSession()
	if self._CountdownConn then
		task.cancel(self._CountdownConn)
		self._CountdownConn = nil
	end

	task.defer(function()
		ActiveSessions[self.SessionId] = nil
		PlayerToSession[self.Player1] = nil
		PlayerToSession[self.Player2] = nil
	end)
end

function TradeSession.Init(services)
	DataService = services:GetService("DataService")
end

return TradeSession
