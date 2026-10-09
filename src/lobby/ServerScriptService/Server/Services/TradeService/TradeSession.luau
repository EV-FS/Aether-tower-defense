--/Services
local HttpService = game:GetService("HttpService")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--/Modules
local TradePending = require(script.Parent.TradePending)
local Signal = require(ReplicatedStorage.Packages.Signal)
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)
local DataService

--/Types
export type OfferType = "Tower" | "Inventory"
export type InventoryType = "Item" | "Crate" | "Skin" | "Emote" | "Emoji"

export type MaterialOffers = { [string]: number }
export type InventoryOffers = { [string]: MaterialOffers }

export type TradeOffer = {
	Towers: TowerOffers,
	Inventory: InventoryOffers,
}

export type OfferData = {
	offerType: OfferType,
	offerName: string,
	offerArg: string,
	offerArg2: number?,
}

export type TowerSnapshot = { [string]: any }
export type TowerOffers = { [string]: { [string]: TowerSnapshot } }

export type TradeState = "Building" | "Countdown" | "Committing" | "Completed" | "Cancelled"

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
		offerArg: string,
		offerArg2: number?
	) -> boolean,

	RemoveOffer: (
		self: Session,
		offerGiver: Player,
		offerType: OfferType,
		offerName: string,
		offerArg: string,
		offerArg2: number?
	) -> boolean,
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
local MAX_TOWER_OFFERS = 100
local MATERIAL_CATEGORIES = {
	Item = "Items",
	Crate = "Crates",
	Skin = "Skins",
	Emote = "Emotes",
	Emoji = "Emojis",
}

--/Variables
local ActiveSessions: { [string]: Session } = {}
local PlayerToSession: { [Player]: Session } = {}
local FailedRestores: { [Player]: boolean } = {}

-------------------------------------------------
--// Local Functions
-------------------------------------------------
local function GetTblPath(parentTable: TowerOffers, key: string)
	parentTable[key] = parentTable[key] or {}

	return parentTable[key]
end

local function GetTowerOffersCount(offersTable: TowerOffers): number
	if not offersTable then
		return 0
	end
	local count = 0
	for _, towerKeys in offersTable do
		for _ in towerKeys do
			count += 1
		end
	end

	return count
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
local function IsValidAmount(amount: any): boolean
	return typeof(amount) == "number" and amount > 0 and math.isfinite(amount) and amount % 1 == 0
end

local function VerifyInventory(player: Player, category: string, materialName: string, amount: number): boolean
	if not IsValidAmount(amount) then
		return false
	end

	return DataService:CanAfford(player, "Inventory", amount, category, materialName)
end

local function CreateSnapshot(player: Player): (boolean, { [string]: any }?)
	local playerData = DataService:GetData(player)
	if not playerData then
		return false
	end

	local snapshotData = {
		OwnedTowers = TableUtils.DeepCopy(playerData.OwnedTowers),
		Inventory = TableUtils.DeepCopy(playerData.Inventory),
		Loadout = TableUtils.DeepCopy(playerData.Loadout),
		EmoteLoadout = TableUtils.DeepCopy(playerData.EmoteLoadout),
		EmojiLoadout = TableUtils.DeepCopy(playerData.EmojiLoadout),

		TradeReservations = if playerData.TradeReservations
			then TableUtils.DeepCopy(playerData.TradeReservations)
			else nil,

		_NextId = playerData._NextId,
		_LastAppliedTradeId = playerData._LastAppliedTradeId,
	}

	return true, snapshotData
end

local function OverwriteSnapshot(player: Player, snapshot: { [string]: any }): boolean
	local playerData = DataService:GetData(player)
	if not playerData then
		return false
	end

	for key, data in snapshot do
		local restored = if typeof(data) == "table" then TableUtils.DeepCopy(data) else data

		playerData[key] = restored
	end

	return true
end

local function ReserveOfferAssets(player: Player, sessionId: string, offer: TradeOffer): boolean
	local playerData = DataService:GetData(player)
	if not playerData then
		return false
	end

	local reservation = playerData.TradeReservations
	if reservation then
		return reservation.SessionId == sessionId
	end

	for towerName, towerKeys in offer.Towers do
		local ownedTowers = playerData.OwnedTowers[towerName]
		for towerKey in towerKeys do
			local tower = ownedTowers and ownedTowers[towerKey]
			if not tower or tower.Trading == true then
				return false
			end
		end
	end
	for category, materials in offer.Inventory do
		for materialName, amount in materials do
			if not VerifyInventory(player, category, materialName, amount) then
				return false
			end
		end
	end

	local reservations = TableUtils.DeepCopy(offer.Inventory)
	reservations.SessionId = sessionId
	reservations.Towers = {}
	for towerName, towerKeys in offer.Towers do
		local keys = {}
		for towerKey in towerKeys do
			keys[towerKey] = true
		end
		reservations.Towers[towerName] = keys
	end
	DataService:UpdateData(player, "TradeReservations", reservations)

	for towerName, towerKeys in offer.Towers do
		for towerKey in towerKeys do
			if not DataService:AdjustTower(player, towerName, towerKey, "Trading", true) then
				return false
			end
		end
	end

	return true
end

local function ReleaseOfferAssets(player: Player, sessionId: string, offer: TradeOffer?): boolean
	local playerData = DataService:GetData(player)
	if not playerData then
		return false
	end

	local reservation = playerData.TradeReservations
	if not reservation then
		return true
	end
	if reservation.SessionId ~= sessionId then
		return false
	end

	-- 기존 예약에는 타워 목록이 없을 수 있음.
	local towers = if offer then offer.Towers else reservation.Towers or playerData.OwnedTowers
	for towerName, towerKeys in towers do
		local ownedTowers = playerData.OwnedTowers[towerName]
		for towerKey in towerKeys do
			local tower = ownedTowers and ownedTowers[towerKey]
			if not tower or tower.Trading ~= true then
				continue
			end
			if not DataService:AdjustTower(player, towerName, towerKey, "Trading", false) then
				return false
			end
		end
	end

	DataService:UpdateData(player, "TradeReservations", nil)

	return true
end

local function ClearInventoryLoadout(player: Player, category: string, materialName: string)
	local loadoutKey = if category == "Emotes"
		then "EmoteLoadout"
		elseif category == "Emojis" then "EmojiLoadout"
		else nil

	if not loadoutKey then
		return
	end

	local playerData = DataService:GetData(player)
	local loadout = playerData and playerData[loadoutKey]
	if not loadout then
		return
	end

	local updated = table.clone(loadout)
	local changed = false

	for slot, equippedName in updated do
		if equippedName == materialName then
			updated[slot] = nil
			changed = true
		end
	end

	if changed then
		DataService:UpdateData(player, loadoutKey, updated)
	end
end

local function ApplyDeductions(player: Player, offer: TradeOffer)
	for towerName, towerKeys in offer.Towers do
		for towerKey in towerKeys do
			assert(DataService:RemoveTower(player, towerName, towerKey), ``)
		end
	end

	for category, materials in offer.Inventory do
		for materialName, amount in materials do
			local remaining = DataService:AddData(player, "Inventory", -amount, category, materialName)

			assert(remaining ~= nil, `Failed to deduct {category}/{materialName}.`)

			if remaining == 0 then
				ClearInventoryLoadout(player, category, materialName)
			end
		end
	end
end

local function GrantResult(player: Player, offer: TradeOffer)
	for towerName, towerKeys in offer.Towers do
		for _, towerData in towerKeys do
			assert(DataService:AddTower(player, towerName, towerData), ``)
		end
	end

	for category, materials in offer.Inventory do
		for materialName, amount in materials do
			local result = DataService:AddData(player, "Inventory", amount, category, materialName)

			assert(result ~= nil, `Failed to grant {category}/{materialName}.`)
		end
	end
end

-------------------------------------------------
--// TradeSession
-------------------------------------------------
local TradeSession = {}
TradeSession.__index = TradeSession
TradeSession.ReadyChanged = Signal.new()
TradeSession.StartCountdown = Signal.new()
TradeSession.StartCommitting = Signal.new()
TradeSession.TradeEnded = Signal.new()
TradeSession.ReleaseOfferAssets = ReleaseOfferAssets

function TradeSession.GetSessionFromId(sessionId: string): Session?
	return ActiveSessions[sessionId]
end

function TradeSession.GetSessionFromPlayer(player: Player): Session?
	return PlayerToSession[player]
end

function TradeSession.ApplyPlayerTrade(
	player: Player,
	sessionId: string,
	playerOffer: TradeOffer,
	otherOffer: TradeOffer
): boolean
	if FailedRestores[player] then
		return false
	end

	local profile = DataService:GetProfile(player)
	if not profile or not profile:IsActive() then
		return false
	end

	local playerData = profile.Data
	if playerData._LastAppliedTradeId ~= sessionId then
		if not ReserveOfferAssets(player, sessionId, playerOffer) then
			return false
		end
	end

	local snapshotSuccess, snapshot = CreateSnapshot(player)
	if not snapshotSuccess or not snapshot then
		return false
	end

	if playerData._LastAppliedTradeId ~= sessionId then
		local success, errorMsg = pcall(function()
			ApplyDeductions(player, playerOffer)
			GrantResult(player, otherOffer)

			assert(
				ReleaseOfferAssets(player, sessionId, playerOffer),
				"Reservations을 Release하는 것을 실패함."
			)

			playerData._LastAppliedTradeId = sessionId
		end)

		if not success then
			local restoreSuccess, restored = pcall(function()
				return OverwriteSnapshot(player, snapshot)
			end)

			if not restoreSuccess or restored ~= true then
				FailedRestores[player] = true
				warn(`거래 복원 실패: {sessionId}, {tostring(restored)}`)
			end

			warn(`거래 적용 실패: {sessionId}, {tostring(errorMsg)}`)
			return false
		end
	end

	local saveSuccess, saved = pcall(function()
		return DataService:SaveDataAsync(player)
	end)

	if not saveSuccess or saved ~= true then
		warn(`거래 저장 미확인: {sessionId}`)
		return false
	end

	return true
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
			Inventory = {},
		},
		[self.Player2] = {
			Towers = {},
			Inventory = {},
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
	offerArg: string,
	offerArg2: number?
): boolean
	if self.CurrentState ~= "Building" then
		return false
	end

	local targetPlayer = FindParticipant(offerGiver, self.Player1, self.Player2)
	if not targetPlayer then
		return false
	end

	local offer = self.Offers[targetPlayer]

	if offerType == "Tower" then
		local towerOffers = offer.Towers[offerName]
		if towerOffers and towerOffers[offerArg] then
			return false
		end

		if GetTowerOffersCount(offer.Towers) >= MAX_TOWER_OFFERS then
			return false
		end

		local targetTower = VerifyTower(targetPlayer, offerName, offerArg)
		if not targetTower then
			return false
		end

		GetTblPath(offer.Towers, offerName)[offerArg] = TableUtils.DeepCopy(targetTower)
	elseif offerType == "Inventory" then
		local category = MATERIAL_CATEGORIES[offerArg]
		if not category then
			return false
		end

		local amount = if offerArg2 == nil then 1 else offerArg2
		if not IsValidAmount(amount) then
			return false
		end

		local materials = offer.Inventory[category]
		local currentAmount = if materials then materials[offerName] or 0 else 0
		local totalAmount = currentAmount + amount

		if not VerifyInventory(targetPlayer, category, offerName, totalAmount) then
			return false
		end

		if not materials then
			materials = {}
			offer.Inventory[category] = materials
		end

		materials[offerName] = totalAmount
	else
		return false
	end

	self:OnOfferChanged()
	return true
end

function TradeSession:RemoveOffer(
	offerGiver: Player,
	offerType: OfferType,
	offerName: string,
	offerArg: string,
	offerArg2: number?
): boolean
	if self.CurrentState ~= "Building" then
		return false
	end

	local targetPlayer = FindParticipant(offerGiver, self.Player1, self.Player2)
	if not targetPlayer then
		return false
	end

	local offer = self.Offers[targetPlayer]

	if offerType == "Tower" then
		local towers = offer.Towers[offerName]
		if not towers or not towers[offerArg] then
			return false
		end

		towers[offerArg] = nil
		if next(towers) == nil then
			offer.Towers[offerName] = nil
		end
	elseif offerType == "Inventory" then
		local category = MATERIAL_CATEGORIES[offerArg]
		if not category then
			return false
		end

		local amount = if offerArg2 == nil then 1 else offerArg2
		if not IsValidAmount(amount) then
			return false
		end

		local materials = offer.Inventory[category]
		local currentAmount = materials and materials[offerName]
		if not currentAmount then
			return false
		end

		local remaining = currentAmount - amount
		materials[offerName] = if remaining > 0 then remaining else nil

		if next(materials) == nil then
			offer.Inventory[category] = nil
		end
	else
		return false
	end

	self:OnOfferChanged()
	return true
end

function TradeSession:SetReady(player: Player, action: boolean, clientVersion: number): boolean
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
		local profile = DataService:GetProfile(player)
		if not profile or not profile:IsActive() then
			return false, `Couldn't load {player.DisplayName}'s data. The trade has been cancelled.`
		end
		local playerData = profile.Data

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

		for category, materials in offers.Inventory do
			for materialName, amount in materials do
				if not VerifyInventory(player, category, materialName, amount) then
					return false,
						`{player.DisplayName} no longer has enough {materialName} ({category}). The trade has been cancelled.`
				end
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
	self.StartCommitting:Fire(self.SessionId)

	local valid, reason = self:ValidateTrade()
	if not valid then
		self:Break(reason)
		return
	end

	local sessionId = self.SessionId
	if not sessionId then
		self:Break(`The trade session isn't vaild.`)
		return
	end

	local plr1Id = self.Player1.UserId
	local plr2Id = self.Player2.UserId

	if not plr1Id or not plr2Id then
		self:Break(``)
		return
	end

	if not ReserveOfferAssets(self.Player1, sessionId, self.Offers[self.Player1]) then
		self:Break(``, true)
		return
	end

	if not ReserveOfferAssets(self.Player2, sessionId, self.Offers[self.Player2]) then
		self:Break(``, true)
		return
	end

	DataService:Lock(self.Player1)
	DataService:Lock(self.Player2)

	local pendingSuccess = TradePending.SaveRecord(self)
	if not pendingSuccess then
		self:Break(``, true)
		return
	end

	local plr1PendingSuccess = TradePending.SetPlayerPending(plr1Id, sessionId)
	if not plr1PendingSuccess then
		TradePending.CancelRecord(sessionId)
		self:Break(``, true)
		return
	end
	local plr2PendingSuccess = TradePending.SetPlayerPending(plr2Id, sessionId)
	if not plr2PendingSuccess then
		TradePending.ClearPlayerPending(plr1Id, sessionId)
		TradePending.CancelRecord(sessionId)
		self:Break(``, true)
		return
	end

	local commitPendingSuccess = TradePending.CommitRecord(sessionId)
	if not commitPendingSuccess then
		self:Break(``)
		return
	end

	local plr1TradeSuccess =
		TradeSession.ApplyPlayerTrade(self.Player1, sessionId, self.Offers[self.Player1], self.Offers[self.Player2])
	if plr1TradeSuccess then
		if TradePending.ClearPlayerPending(plr1Id, sessionId) then
			DataService:Unlock(self.Player1)
		end
	else
		self:Break(``)
		return
	end

	local plr2TradeSuccess =
		TradeSession.ApplyPlayerTrade(self.Player2, sessionId, self.Offers[self.Player2], self.Offers[self.Player1])
	if plr2TradeSuccess then
		if TradePending.ClearPlayerPending(plr2Id, sessionId) then
			DataService:Unlock(self.Player2)
		end
	else
		self:Break(``)
		return
	end

	TradePending.CompleteRecord(sessionId)

	TradePending.AppendHistory(self.Player1, sessionId)
	TradePending.AppendHistory(self.Player2, sessionId)

	self:Complete()
end

function TradeSession:Complete()
	self.CurrentState = "Completed"

	self.TradeEnded:Fire(self.SessionId, "Completed")
	self:EndSession()
end

function TradeSession:Break(reason: string?, releaseReservations: boolean?)
	if releaseReservations then
		for _, player in { self.Player1, self.Player2 } do
			local success, released = pcall(ReleaseOfferAssets, player, self.SessionId, self.Offers[player])
			if not success or not released then
				DataService:Lock(player)
				warn(`거래 예약 해제 실패: {self.SessionId}, {player.UserId}`)
			else
				DataService:Unlock(player)
			end
		end
	end

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
	Players.PlayerRemoving:Connect(function(player: Player)
		FailedRestores[player] = nil
	end)
end

return TradeSession
