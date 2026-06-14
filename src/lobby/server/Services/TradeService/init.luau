--/Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

--/Modules
local Net = require(ReplicatedStorage.Shared.Net)
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)

local DataService -- Init 시점 지연 로드

--/Variables
local TradeLogStore = DataStoreService:GetDataStore("TradeLogs_v1")
local PendingTradeStore = DataStoreService:GetDataStore("PendingTrades_v1") -- 크래시 재정산용 에스크로 원장

local ActiveSessions: { [string]: TradeSession } = {}
local PlayerToSession: { [Player]: string } = {}

local SESSION_TIMEOUT = 300 -- 마지막 상호작용 후 5분 경과 시 자동 파기
local MAX_ID_LENGTH = 64 -- 경계단 문자열 길이 상한
local LOG_FLUSH_INTERVAL = 60 -- 거래 로그 배치 저장 주기(초)
local MAX_LOG_QUEUE = 500 -- 큐 상한. 초과 시 가장 오래된 로그부터 폐기
local LOG_BATCH_MAX = 50 -- 한 키에 담는 최대 레코드 수

local LogQueue: { any } = {}

--/Configuration (취약점 해소: 내부 데이터 거래 방지용 화이트리스트)
local TradeConfig = {
	-- 거래가 허용된 안전한 재화 목록만 등록하세요.
	-- 주의: "Level", "Exp" 등 내부 데이터 키는 절대 등록하면 안 됩니다.
	AllowedCurrencies = {
		["Coins"] = true,
		["Gems"] = true,
	},
	-- 아이템이 거래 가능한 속성인지 판단하는 함수
	IsItemTradeable = function(itemId: string): boolean
		-- TODO: 실제 게임의 아이템 데이터 모듈과 연동하여 Tradeable 여부를 반환하세요.
		-- 예: return ItemData[itemId].Tradeable == true
		return true
	end,
}

--/Types
type TradeOffer = {
	Currency: { [string]: number },
	Items: { [string]: number },
	Towers: { [string]: string }, -- towerKey -> towerName
}

type TradeSession = {
	Id: string,
	Version: number,
	Created: number,
	LastActivity: number,
	State: "Building" | "Committing" | "Committed" | "Cancelled",
	Members: { Player },
	Offers: { [Player]: TradeOffer },
	Confirmed: { [Player]: boolean },
}

-------------------------------------------------
--// Local Functions
-------------------------------------------------
local function NewOffer(): TradeOffer
	return { Currency = {}, Items = {}, Towers = {} }
end

local function IsValidId(value: any): boolean
	return type(value) == "string" and #value > 0 and #value <= MAX_ID_LENGTH
end

local function IsValidAmount(value: any): boolean
	return type(value) == "number" and value > 0 and value % 1 == 0 and value < 1e15
end

local function SafeFire(remote, player: Player, payload: any?)
	if player and player.Parent == Players then
		remote.Fire(player, payload)
	end
end

local function BroadcastState(session: TradeSession)
	local payload = {
		SessionId = session.Id,
		Version = session.Version,
		State = session.State,
		Offers = {},
		Confirmed = {},
	}
	for _, member in session.Members do
		local key = tostring(member.UserId)
		payload.Offers[key] = session.Offers[member]
		payload.Confirmed[key] = session.Confirmed[member]
	end
	for _, member in session.Members do
		SafeFire(Net.TradeService.OfferUpdated, member, payload)
	end
end

local function OnOfferChanged(session: TradeSession)
	session.Version += 1
	session.LastActivity = os.time()
	for _, player in session.Members do
		session.Confirmed[player] = false
	end
	BroadcastState(session)
end

local function ValidateOffer(player: Player, offer: TradeOffer): (boolean, string?)
	local playerData = DataService:GetData(player)
	if not playerData then
		return false, "데이터 미로드"
	end

	for currencyId, amount in offer.Currency do
		if (playerData[currencyId] or 0) < amount then
			return false, `재화 부족: {currencyId}`
		end
	end

	for itemId, amount in offer.Items do
		if (playerData.Inventory.Items[itemId] or 0) < amount then
			return false, `아이템 부족: {itemId}`
		end
	end

	local equippedKeys = {}
	for _, loadoutData in playerData.Loadout do
		equippedKeys[loadoutData.Key] = true
	end

	for towerKey, towerName in offer.Towers do
		local towerType = playerData.OwnedTowers[towerName]
		if not towerType or not towerType[towerKey] then
			return false, `타워 누락: {towerName}`
		end
		if equippedKeys[towerKey] then
			return false, `장착 중인 타워는 거래할 수 없습니다: {towerName}`
		end
	end

	return true
end

local function CanReceiveOffer(receiver: Player, incoming: TradeOffer): (boolean, string?)
	local receiverData = DataService:GetData(receiver)
	if not receiverData then
		return false, "수신자 데이터 미로드"
	end
	return true
end

local function GetEditableSession(player: Player): (TradeSession?, string?)
	local sessionId = PlayerToSession[player]
	if not sessionId then
		return nil, "진행 중인 거래가 없습니다."
	end
	local session = ActiveSessions[sessionId]
	if not session or session.State ~= "Building" then
		return nil, "지금은 거래 내용을 수정할 수 없습니다."
	end
	return session
end

local function ApplyTradeSide(player: Player, gives, receives)
	for currencyId, amount in gives.Currency do
		DataService:AddData(player, currencyId, -amount)
	end
	for itemId, amount in gives.Items do
		DataService:AddData(player, "Inventory", -amount, "Items", itemId)
	end
	for towerKey, info in gives.Towers do
		DataService:RemoveTower(player, info.Name, towerKey)
	end

	for currencyId, amount in receives.Currency do
		DataService:AddData(player, currencyId, amount)
	end
	for itemId, amount in receives.Items do
		DataService:AddData(player, "Inventory", amount, "Items", itemId)
	end
	for _, info in receives.Towers do
		DataService:AddTower(player, info.Name, info.Data)
	end
end

-------------------------------------------------
--// TradeService
-------------------------------------------------
local TradeService = {}

-- [취약점 해소: TOCTOU 방어]
-- 상점(Shop)이나 인벤토리 조작 스크립트에서 유저가 아이템을 쓰기 전 이 함수를 호출하여
-- 거래 중일 때는 소비를 막아야 이중 지불을 완벽히 차단할 수 있습니다.
function TradeService.IsPlayerTrading(player: Player): boolean
	local sessionId = PlayerToSession[player]
	if not sessionId then
		return false
	end

	local session = ActiveSessions[sessionId]
	return session and (session.State == "Building" or session.State == "Committing")
end

function TradeService.CreateSession(plr1: Player, plr2: Player): (TradeSession?, string?)
	if plr1 == plr2 then
		return nil, "자기 자신과는 거래할 수 없습니다."
	end
	if PlayerToSession[plr1] or PlayerToSession[plr2] then
		return nil, "이미 다른 거래가 진행 중입니다."
	end
	if not DataService:GetData(plr1) or not DataService:GetData(plr2) then
		return nil, "참가자의 데이터가 아직 로드되지 않았습니다."
	end

	local sessionId = HttpService:GenerateGUID(false)
	local now = os.time()

	local session: TradeSession = {
		Id = sessionId,
		Version = 1,
		Created = now,
		LastActivity = now,
		State = "Building",
		Members = { plr1, plr2 },
		Offers = { [plr1] = NewOffer(), [plr2] = NewOffer() },
		Confirmed = { [plr1] = false, [plr2] = false },
	}

	ActiveSessions[sessionId] = session
	PlayerToSession[plr1] = sessionId
	PlayerToSession[plr2] = sessionId
	return session
end

function TradeService.LogSession(session: TradeSession, id: string?): boolean
	local key = id or session.Id
	local serializable = {
		Id = session.Id,
		Version = session.Version,
		State = session.State,
		Created = session.Created,
		SavedAt = os.time(),
		Members = {},
		Offers = {},
	}
	for _, player in session.Members do
		local userId = tostring(player.UserId)
		table.insert(serializable.Members, userId)
		serializable.Offers[userId] = TableUtils.DeepCopy(session.Offers[player])
	end

	local ok, err = pcall(function()
		TradeLogStore:SetAsync(key, serializable)
	end)
	if not ok then
		warn(`거래 세션 {key} 저장 실패: {err}`)
		return false
	end
	return true
end

function TradeService.AddItem(player: Player, id: string, amount: number): (boolean, string?)
	if not IsValidId(id) then
		return false, "잘못된 아이템 식별자입니다."
	end
	if not IsValidAmount(amount) then
		return false, "잘못된 수량입니다."
	end

	-- [취약점 해소: 화이트리스트 검증]
	if not TradeConfig.IsItemTradeable(id) then
		return false, "거래가 불가능한 아이템입니다."
	end

	local session, reason = GetEditableSession(player)
	if not session then
		return false, reason
	end

	local playerData = DataService:GetData(player)
	if not playerData then
		return false, "데이터 미로드"
	end

	local offer = session.Offers[player]
	local owned = playerData.Inventory.Items[id] or 0
	local alreadyOffered = offer.Items[id] or 0
	if owned < alreadyOffered + amount then
		return false, "보유 수량보다 많이 올릴 수 없습니다."
	end

	offer.Items[id] = alreadyOffered + amount
	OnOfferChanged(session)
	return true
end

function TradeService.RemoveItem(player: Player, id: string, amount: number?): (boolean, string?)
	if not IsValidId(id) then
		return false, "잘못된 아이템 식별자입니다."
	end
	local session, reason = GetEditableSession(player)
	if not session then
		return false, reason
	end

	local offer = session.Offers[player]
	local current = offer.Items[id]
	if not current then
		return false, "올려둔 아이템이 아닙니다."
	end

	if amount == nil or amount >= current then
		offer.Items[id] = nil
	elseif IsValidAmount(amount) then
		offer.Items[id] = current - amount
	else
		return false, "잘못된 수량입니다."
	end

	OnOfferChanged(session)
	return true
end

function TradeService.AddCurrency(player: Player, currencyId: string, amount: number): (boolean, string?)
	if not IsValidId(currencyId) then
		return false, "잘못된 재화 식별자입니다."
	end
	if not IsValidAmount(amount) then
		return false, "잘못된 수량입니다."
	end

	-- [취약점 해소: 내부 변수 거래 어뷰징 원천 차단]
	if not TradeConfig.AllowedCurrencies[currencyId] then
		return false, "거래할 수 없는 재화입니다."
	end

	local session, reason = GetEditableSession(player)
	if not session then
		return false, reason
	end

	local playerData = DataService:GetData(player)
	local offer = session.Offers[player]
	local alreadyOffered = offer.Currency[currencyId] or 0
	if (playerData[currencyId] or 0) < alreadyOffered + amount then
		return false, "보유한 재화보다 많이 올릴 수 없습니다."
	end

	offer.Currency[currencyId] = alreadyOffered + amount
	OnOfferChanged(session)
	return true
end

function TradeService.RemoveCurrency(player: Player, currencyId: string): (boolean, string?)
	if not IsValidId(currencyId) then
		return false, "잘못된 재화 식별자입니다."
	end
	local session, reason = GetEditableSession(player)
	if not session then
		return false, reason
	end
	session.Offers[player].Currency[currencyId] = nil
	OnOfferChanged(session)
	return true
end

function TradeService.AddTower(player: Player, towerName: string, towerKey: string): (boolean, string?)
	if not IsValidId(towerName) or not IsValidId(towerKey) then
		return false, "잘못된 식별자입니다."
	end
	local session, reason = GetEditableSession(player)
	if not session then
		return false, reason
	end

	local playerData = DataService:GetData(player)
	local towerType = playerData.OwnedTowers[towerName]
	if not towerType or not towerType[towerKey] then
		return false, "보유하지 않은 타워입니다."
	end
	for _, loadoutData in playerData.Loadout do
		if loadoutData.Key == towerKey then
			return false, "장착 중인 타워는 거래할 수 없습니다."
		end
	end

	session.Offers[player].Towers[towerKey] = towerName
	OnOfferChanged(session)
	return true
end

function TradeService.RemoveTower(player: Player, towerKey: string): (boolean, string?)
	if not IsValidId(towerKey) then
		return false, "잘못된 타워 식별자입니다."
	end
	local session, reason = GetEditableSession(player)
	if not session then
		return false, reason
	end
	session.Offers[player].Towers[towerKey] = nil
	OnOfferChanged(session)
	return true
end

function TradeService.Confirm(player: Player, clientVersion: number): (boolean, string?)
	local sessionId = PlayerToSession[player]
	local session = sessionId and ActiveSessions[sessionId]
	if not session or session.State ~= "Building" then
		return false, "지금은 확정할 수 없습니다."
	end
	if type(clientVersion) ~= "number" or session.Version ~= clientVersion then
		return false, "거래 내용이 변경되었습니다. 다시 확인해 주세요."
	end

	session.Confirmed[player] = true
	session.LastActivity = os.time()
	BroadcastState(session)

	for _, member in session.Members do
		if not session.Confirmed[member] then
			return true
		end
	end
	return TradeService._Commit(session)
end

function TradeService._Commit(session: TradeSession): (boolean, string?)
	if session.State ~= "Building" then
		return false, "이미 처리 중인 거래입니다."
	end
	session.State = "Committing"

	local plr1, plr2 = session.Members[1], session.Members[2]

	-- 1) 최종 검증
	local ok1, why1 = ValidateOffer(plr1, session.Offers[plr1])
	local ok2, why2 = ValidateOffer(plr2, session.Offers[plr2])
	if not ok1 or not ok2 then
		TradeService.Cancel(session.Id)
		return false, why1 or why2
	end

	-- 2) 수신자 여유 검증
	local rOk1, rWhy1 = CanReceiveOffer(plr2, session.Offers[plr1])
	local rOk2, rWhy2 = CanReceiveOffer(plr1, session.Offers[plr2])
	if not rOk1 or not rOk2 then
		TradeService.Cancel(session.Id)
		return false, rWhy1 or rWhy2
	end

	local function snapshotTowers(player: Player)
		local data = DataService:GetData(player)
		local snap = {}
		for towerKey, towerName in session.Offers[player].Towers do
			snap[towerKey] = { Name = towerName, Data = TableUtils.DeepCopy(data.OwnedTowers[towerName][towerKey]) }
		end
		return snap
	end
	local snap1, snap2 = snapshotTowers(plr1), snapshotTowers(plr2)

	local function buildSide(giverSnap, recvSnap, giverOffer, recvOffer): any
		return {
			TradeId = session.Id,
			At = os.time(),
			Gives = { Currency = giverOffer.Currency, Items = giverOffer.Items, Towers = giverSnap },
			Receives = { Currency = recvOffer.Currency, Items = recvOffer.Items, Towers = recvSnap },
		}
	end
	local sideA = buildSide(snap1, snap2, session.Offers[plr1], session.Offers[plr2])
	local sideB = buildSide(snap2, snap1, session.Offers[plr2], session.Offers[plr1])

	-- 4) 에스크로 선기록
	local escrowOk = pcall(function()
		PendingTradeStore:SetAsync(`Pending_{plr1.UserId}`, sideA)
		PendingTradeStore:SetAsync(`Pending_{plr2.UserId}`, sideB)
	end)
	if not escrowOk then
		pcall(function()
			PendingTradeStore:RemoveAsync(`Pending_{plr1.UserId}`)
			PendingTradeStore:RemoveAsync(`Pending_{plr2.UserId}`)
		end)
		TradeService.Cancel(session.Id)
		return false, "거래 기록 저장에 실패하여 취소되었습니다."
	end

	if session.State ~= "Committing" or not plr1.Parent or not plr2.Parent then
		pcall(function()
			PendingTradeStore:RemoveAsync(`Pending_{plr1.UserId}`)
			PendingTradeStore:RemoveAsync(`Pending_{plr2.UserId}`)
		end)
		TradeService.Cancel(session.Id)
		return false, "거래 처리 중 참가자가 이탈하여 취소되었습니다."
	end

	-- 4-1.5) [취약점 해소: TOCTOU 이중 지불 방어]
	-- 에스크로 저장을 위해 Yield된 사이(약 0.5초) 유저가 다른 곳에 재화를 소모했는지 재검증합니다.
	local reOk1 = ValidateOffer(plr1, session.Offers[plr1])
	local reOk2 = ValidateOffer(plr2, session.Offers[plr2])
	if not reOk1 or not reOk2 then
		pcall(function()
			PendingTradeStore:RemoveAsync(`Pending_{plr1.UserId}`)
			PendingTradeStore:RemoveAsync(`Pending_{plr2.UserId}`)
		end)
		TradeService.Cancel(session.Id)
		return false, "거래 대기 중 재화가 변동되어 취소되었습니다. (중복 사용 차단)"
	end

	-- 4-2) 원자적 커밋 결정
	local commitKey = `Committed_{session.Id}`
	local tokenOk = pcall(function()
		PendingTradeStore:SetAsync(commitKey, { TradeId = session.Id, At = os.time() })
	end)
	if not tokenOk then
		pcall(function()
			PendingTradeStore:RemoveAsync(`Pending_{plr1.UserId}`)
			PendingTradeStore:RemoveAsync(`Pending_{plr2.UserId}`)
		end)
		TradeService.Cancel(session.Id)
		return false, "거래 확정에 실패하여 취소되었습니다."
	end

	-- 4-3) 토큰 기록 yield 동안 누군가 이탈한 경우
	if not plr1.Parent or not plr2.Parent then
		local function settlePresent(player: Player, side)
			if player.Parent then
				ApplyTradeSide(player, side.Gives, side.Receives)
				DataService:UpdateData(player, "LastTradeId", session.Id)
				local saveOk = pcall(function()
					DataService:SaveData(player)
				end)
				if saveOk then
					pcall(function()
						PendingTradeStore:RemoveAsync(`Pending_{player.UserId}`)
					end)
				end
				SafeFire(Net.TradeService.TradeCompleted, player, { SessionId = session.Id })
			end
		end
		settlePresent(plr1, sideA)
		settlePresent(plr2, sideB)

		for _, member in session.Members do
			PlayerToSession[member] = nil
		end
		ActiveSessions[session.Id] = nil
		TradeService._QueueLog(session)
		return true
	end

	-- 5) 스왑 실행
	ApplyTradeSide(plr1, sideA.Gives, sideA.Receives)
	ApplyTradeSide(plr2, sideB.Gives, sideB.Receives)

	-- 6) 트랜잭션 마커 + 강제 저장
	DataService:UpdateData(plr1, "LastTradeId", session.Id)
	DataService:UpdateData(plr2, "LastTradeId", session.Id)
	pcall(function()
		DataService:SaveData(plr1)
		DataService:SaveData(plr2)
	end)

	-- 7) 토큰/펜딩 해제 + 로그 큐
	pcall(function()
		PendingTradeStore:RemoveAsync(commitKey)
		PendingTradeStore:RemoveAsync(`Pending_{plr1.UserId}`)
		PendingTradeStore:RemoveAsync(`Pending_{plr2.UserId}`)
	end)
	TradeService._QueueLog(session)

	session.State = "Committed"

	for _, member in session.Members do
		SafeFire(Net.TradeService.TradeCompleted, member, { SessionId = session.Id })
	end
	for _, member in session.Members do
		PlayerToSession[member] = nil
	end
	ActiveSessions[session.Id] = nil
	return true
end

function TradeService.Cancel(sessionId: string)
	local session = ActiveSessions[sessionId]
	-- [취약점 해소: Cancel 충돌 버그 방어]
	-- 이미 Committing(저장 중) 상태로 돌입한 세션은 이탈 이벤트 등으로 취소할 수 없습니다.
	if not session or session.State == "Committing" or session.State == "Committed" then
		return
	end

	session.State = "Cancelled"
	for _, member in session.Members do
		SafeFire(Net.TradeService.TradeCancelled, member, { SessionId = session.Id })
	end
	for _, member in session.Members do
		PlayerToSession[member] = nil
	end
	ActiveSessions[sessionId] = nil
end

function TradeService._QueueLog(session: TradeSession)
	local record = {
		Id = session.Id,
		Version = session.Version,
		Created = session.Created,
		At = os.time(),
		Members = {},
		Offers = {},
	}
	for _, player in session.Members do
		local userId = tostring(player.UserId)
		table.insert(record.Members, userId)
		record.Offers[userId] = TableUtils.DeepCopy(session.Offers[player])
	end

	if #LogQueue >= MAX_LOG_QUEUE then
		table.remove(LogQueue, 1)
		warn("거래 로그 큐 상한 초과 — 가장 오래된 로그 폐기.")
	end
	table.insert(LogQueue, record)
end

function TradeService._FlushLogs()
	if #LogQueue == 0 then
		return
	end

	local batch = {}
	for _ = 1, math.min(LOG_BATCH_MAX, #LogQueue) do
		table.insert(batch, table.remove(LogQueue, 1))
	end

	local key = `Batch_{os.time()}_{HttpService:GenerateGUID(false)}`
	local ok, err = pcall(function()
		TradeLogStore:SetAsync(key, batch)
	end)
	if not ok then
		warn(`거래 로그 배치 저장 실패: {err}`)
		for i = #batch, 1, -1 do
			if #LogQueue < MAX_LOG_QUEUE then
				table.insert(LogQueue, 1, batch[i])
			end
		end
	end
end

function TradeService.RecoverPendingTrade(player: Player)
	local key = `Pending_{player.UserId}`

	local record
	local readOk = pcall(function()
		record = PendingTradeStore:GetAsync(key)
	end)
	if not readOk or not record then
		return
	end

	local playerData = DataService:GetData(player)
	if not playerData then
		return
	end

	local commitKey = `Committed_{record.TradeId}`
	local committed = false
	local checkOk = pcall(function()
		committed = PendingTradeStore:GetAsync(commitKey) ~= nil
	end)

	if not checkOk then
		warn(`커밋 토큰 확인 실패 — {player.Name}의 재정산을 다음 접속으로 연기.`)
		return
	end

	if committed and playerData.LastTradeId ~= record.TradeId then
		ApplyTradeSide(player, record.Gives, record.Receives)
		DataService:UpdateData(player, "LastTradeId", record.TradeId)

		local saveOk = pcall(function()
			DataService:SaveData(player)
		end)
		if not saveOk then
			warn(`{player.Name} 재정산 저장 실패 — 펜딩 레코드 보존.`)
			return
		end
		warn(`{player.Name}의 중단된 거래 {record.TradeId} 재정산 완료.`)
	end

	pcall(function()
		PendingTradeStore:RemoveAsync(key)
	end)
end

-------------------------------------------------
function TradeService.Init(services)
	DataService = services:GetService("DataService")
end

function TradeService.Start()
	Players.PlayerRemoving:Connect(function(player)
		local sessionId = PlayerToSession[player]
		if sessionId then
			TradeService.Cancel(sessionId)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(30)
			local now = os.time()
			for sessionId, session in ActiveSessions do
				if session.State == "Building" and (now - session.LastActivity) > SESSION_TIMEOUT then
					TradeService.Cancel(sessionId)
				end
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(LOG_FLUSH_INTERVAL)
			local guard = 0
			while #LogQueue > 0 and guard < 20 do
				TradeService._FlushLogs()
				guard += 1
			end
		end
	end)

	game:BindToClose(function()
		local guard = 0
		while #LogQueue > 0 and guard < 20 do
			TradeService._FlushLogs()
			guard += 1
		end
	end)

	Net.TradeService.AddItem.On(function(player: Player, data: any)
		if type(data) ~= "table" then
			return false, "잘못된 요청입니다."
		end
		return TradeService.AddItem(player, data.id, data.amount)
	end)

	Net.TradeService.RemoveItem.On(function(player: Player, data: any)
		if type(data) ~= "table" then
			return false, "잘못된 요청입니다."
		end
		return TradeService.RemoveItem(player, data.id, data.amount)
	end)

	Net.TradeService.AddCurrency.On(function(player: Player, data: any)
		if type(data) ~= "table" then
			return false, "잘못된 요청입니다."
		end
		return TradeService.AddCurrency(player, data.id, data.amount)
	end)

	Net.TradeService.RemoveCurrency.On(function(player: Player, data: any)
		if type(data) ~= "table" then
			return false, "잘못된 요청입니다."
		end
		return TradeService.RemoveCurrency(player, data.id)
	end)

	Net.TradeService.AddTower.On(function(player: Player, data: any)
		if type(data) ~= "table" then
			return false, "잘못된 요청입니다."
		end
		return TradeService.AddTower(player, data.towerName, data.towerKey)
	end)

	Net.TradeService.RemoveTower.On(function(player: Player, data: any)
		if type(data) ~= "table" then
			return false, "잘못된 요청입니다."
		end
		return TradeService.RemoveTower(player, data.towerKey)
	end)

	Net.TradeService.Confirm.On(function(player: Player, data: any)
		if type(data) ~= "table" then
			return false, "잘못된 요청입니다."
		end
		return TradeService.Confirm(player, data.version)
	end)
end

return TradeService
