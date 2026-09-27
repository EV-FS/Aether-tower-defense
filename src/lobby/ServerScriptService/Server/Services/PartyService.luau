--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Signal = require(ReplicatedStorage.Packages.Signal)
local Protocol = require(ReplicatedStorage.Shared.Modules.Core.MatchProtocol)
local Config = require(ReplicatedStorage.Settings.Game.PartySettings)
local MapProgression = require(ReplicatedStorage.Shared.Modules.Core.MapProgression)

type Settings = Protocol.Settings
type Result<T> = Protocol.Result<T>
type Snapshot = Protocol.PartySnapshot
type ErrorCode = Protocol.ErrorCode
type RateLimit = { Tokens: number, UpdatedAt: number }
export type ServerPartyEvent = { Kind: string, PartyId: string, Party: Snapshot?, Reason: string? }
type Party = {
	Id: string,
	Leader: Player,
	Members: { Player },
	Settings: Settings,
	State: Protocol.PartyState,
	Revision: number,
	MatchId: string?,
	ErrorCode: ErrorCode?,
}

local parties: { [string]: Party } = {}
local membership: { [Player]: Party } = {}
local sequences: { [Player]: number } = {}
local rateLimits: { [Player]: RateLimit } = {}
local connections: { RBXScriptConnection } = {}
local MatchService: any
local DataService: any
local changedRemote: RemoteEvent?
local requestRemote: RemoteFunction?
local started = false

local PartyService = { Dependencies = { "MatchService", "DataService" }, Changed = Signal.new() }

local function mapUnlocked(player: Player, mapName: string): boolean
	if MapProgression.IsUnlocked(mapName, nil) then return true end
	local playerData = DataService:GetData(player)
	return playerData ~= nil and MapProgression.IsUnlocked(mapName, playerData.MapClears)
end

local function validPlayer(player: any): boolean
	return typeof(player) == "Instance" and player:IsA("Player") and player.Parent == Players
end

-- Every public read owns its tables. Callers cannot mutate the live party.
local function snapshot(party: Party): Snapshot
	local members = {}
	for _, player in party.Members do
		table.insert(members, { UserId = player.UserId, Name = player.Name, DisplayName = player.DisplayName })
	end
	return {
		Id = party.Id,
		LeaderUserId = party.Leader.UserId,
		Members = members,
		Settings = { Map = party.Settings.Map, Difficulty = party.Settings.Difficulty },
		State = party.State,
		Revision = party.Revision,
		MaxMembers = Config.MaxMembers,
		MatchId = party.MatchId,
		ErrorCode = party.ErrorCode,
	}
end

local function send(player: Player, kind: any, party: Party, reason: string?, includeParty: boolean)
	if not validPlayer(player) then
		return
	end
	sequences[player] = (sequences[player] or 0) + 1
	local event: Protocol.PartyEvent = {
		Kind = kind,
		PartyId = party.Id,
		Party = if includeParty then snapshot(party) else nil,
		Reason = reason,
		Sequence = sequences[player],
	}
	if changedRemote then
		changedRemote:FireClient(player, event)
	end
end

local function publish(party: Party, kind: any?, reason: string?)
	party.Revision += 1
	for _, player in party.Members do
		send(player, kind or "Updated", party, reason, true)
	end
	PartyService.Changed:Fire(
		{ Kind = kind or "Updated", PartyId = party.Id, Party = snapshot(party), Reason = reason } :: ServerPartyEvent
	)
end

local function getOwnedParty(player: Player): (Party?, ErrorCode?)
	if not validPlayer(player) then
		return nil, "INVALID_PLAYER"
	end
	local party = membership[player]
	if not party then
		return nil, "NOT_IN_PARTY"
	end
	if party.Leader ~= player then
		return nil, "NOT_LEADER"
	end
	return party, nil
end

local function destroyParty(party: Party, reason: string)
	parties[party.Id] = nil
	for _, player in party.Members do
		membership[player] = nil
		player:SetAttribute("PartyId", nil)
		send(player, "Disbanded", party, reason, false)
	end
	if party.MatchId then
		MatchService:CloseMatch(party.MatchId)
	end
	PartyService.Changed:Fire({ Kind = "Disbanded", PartyId = party.Id, Reason = reason } :: ServerPartyEvent)
end

local function removeMember(party: Party, player: Player, reason: string)
	local index = table.find(party.Members, player)
	if not index then
		return
	end
	table.remove(party.Members, index)
	membership[player] = nil
	player:SetAttribute("PartyId", nil)
	send(player, "Removed", party, reason, false)
	MatchService:RemovePlayer(player)
	if #party.Members == 0 then
		destroyParty(party, "EMPTY")
		return
	end
	-- Deterministic succession: the longest-standing remaining member becomes leader.
	if party.Leader == player then
		party.Leader = party.Members[1]
	end
	publish(party, "Updated", reason)
end

local function locked(party: Party): boolean
	return party.State == "Starting"
		or party.State == "Teleporting"
		or (party.MatchId ~= nil and MatchService:IsMatchBusy(party.MatchId))
end

local function validatePatch(current: Settings, patch: any): (Settings?, ErrorCode?)
	if type(patch) ~= "table" or next(patch) == nil then
		return nil, "INVALID_ARGUMENT"
	end
	for key in patch do
		if key ~= "Map" and key ~= "Difficulty" then
			return nil, "INVALID_ARGUMENT"
		end
	end
	return Protocol.ValidateSettings({
		Map = if patch.Map == nil then current.Map else patch.Map,
		Difficulty = if patch.Difficulty == nil then current.Difficulty else patch.Difficulty,
	})
end

function PartyService:CreateParty(player: Player, settings: Protocol.SettingsPatch?): Result<Snapshot>
	if not validPlayer(player) then
		return Protocol.Failure("INVALID_PLAYER")
	end
	if membership[player] then
		return Protocol.Failure("ALREADY_IN_PARTY")
	end
	if player:GetAttribute("AFKTeleportPending") or MatchService:IsPlayerBusy(player) then
		return Protocol.Failure("ALREADY_IN_MATCH")
	end
	local selected, code = validatePatch(
		{ Map = Config.DefaultMap, Difficulty = Config.DefaultDifficulty },
		if settings == nil then { Map = Config.DefaultMap, Difficulty = Config.DefaultDifficulty } else settings
	)
	if not selected then
		return Protocol.Failure(code :: ErrorCode)
	end
	if not mapUnlocked(player, selected.Map) then
		return Protocol.Failure("MAP_LOCKED")
	end
	if membership[player] or not validPlayer(player) then
		return Protocol.Failure("ALREADY_IN_PARTY")
	end
	local party: Party = {
		Id = HttpService:GenerateGUID(false),
		Leader = player,
		Members = { player },
		Settings = selected,
		State = "Open",
		Revision = 0,
	}
	parties[party.Id] = party
	membership[player] = party
	player:SetAttribute("PartyId", party.Id)
	publish(party, "Created")
	return Protocol.Success(snapshot(party))
end

function PartyService:JoinParty(player: Player, partyId: string): Result<Snapshot>
	if not validPlayer(player) then
		return Protocol.Failure("INVALID_PLAYER")
	end
	if type(partyId) ~= "string" or #partyId > 100 then
		return Protocol.Failure("INVALID_ARGUMENT")
	end
	if membership[player] then
		return Protocol.Failure("ALREADY_IN_PARTY")
	end
	if player:GetAttribute("AFKTeleportPending") or MatchService:IsPlayerBusy(player) then
		return Protocol.Failure("ALREADY_IN_MATCH")
	end
	local party = parties[partyId]
	if not party then
		return Protocol.Failure("PARTY_NOT_FOUND")
	end
	if party.State ~= "Open" then
		return Protocol.Failure("PARTY_BUSY")
	end
	if #party.Members >= Config.MaxMembers then
		return Protocol.Failure("PARTY_FULL")
	end
	-- No yielding work between capacity/membership checks and this insertion.
	table.insert(party.Members, player)
	membership[player] = party
	player:SetAttribute("PartyId", party.Id)
	publish(party, "Updated", "JOINED")
	return Protocol.Success(snapshot(party))
end

function PartyService:LeaveParty(player: Player): Result<Snapshot>
	local party = membership[player]
	if not party then
		return Protocol.Failure("NOT_IN_PARTY")
	end
	if locked(party) then
		return Protocol.Failure("PARTY_BUSY")
	end
	removeMember(party, player, "LEFT")
	return Protocol.Success(nil)
end

function PartyService:TransferLeadership(player: Player, userId: number): Result<Snapshot>
	local party, code = getOwnedParty(player)
	if not party then
		return Protocol.Failure(code :: ErrorCode)
	end
	if locked(party) then
		return Protocol.Failure("PARTY_BUSY")
	end
	if type(userId) ~= "number" or userId % 1 ~= 0 then
		return Protocol.Failure("INVALID_ARGUMENT")
	end
	for _, member in party.Members do
		if member.UserId == userId then
			party.Leader = member
			publish(party, "Updated", "LEADER_CHANGED")
			return Protocol.Success(snapshot(party))
		end
	end
	return Protocol.Failure("MEMBER_NOT_FOUND")
end

function PartyService:KickMember(player: Player, userId: number): Result<Snapshot>
	local party, code = getOwnedParty(player)
	if not party then
		return Protocol.Failure(code :: ErrorCode)
	end
	if locked(party) then
		return Protocol.Failure("PARTY_BUSY")
	end
	if type(userId) ~= "number" or userId % 1 ~= 0 then
		return Protocol.Failure("INVALID_ARGUMENT")
	end
	if userId == player.UserId then
		return Protocol.Failure("CANNOT_KICK_SELF")
	end
	for _, member in party.Members do
		if member.UserId == userId then
			removeMember(party, member, "KICKED")
			return Protocol.Success(snapshot(party))
		end
	end
	return Protocol.Failure("MEMBER_NOT_FOUND")
end

function PartyService:DisbandParty(player: Player): Result<Snapshot>
	local party, code = getOwnedParty(player)
	if not party then
		return Protocol.Failure(code :: ErrorCode)
	end
	if locked(party) then
		return Protocol.Failure("PARTY_BUSY")
	end
	destroyParty(party, "LEADER_DISBANDED")
	return Protocol.Success(nil)
end

function PartyService:UpdateSettings(player: Player, patch: Protocol.SettingsPatch): Result<Snapshot>
	local party, code = getOwnedParty(player)
	if not party then
		return Protocol.Failure(code :: ErrorCode)
	end
	if party.State ~= "Open" then
		return Protocol.Failure("PARTY_BUSY")
	end
	local settings, errorCode = validatePatch(party.Settings, patch)
	if not settings then
		return Protocol.Failure(errorCode :: ErrorCode)
	end
	if not mapUnlocked(player, settings.Map) then
		return Protocol.Failure("MAP_LOCKED")
	end
	if membership[player] ~= party or party.Leader ~= player or party.State ~= "Open" then
		return Protocol.Failure("PARTY_BUSY")
	end
	party.Settings = settings
	party.ErrorCode = nil
	publish(party, "Updated", "SETTINGS_CHANGED")
	return Protocol.Success(snapshot(party))
end

function PartyService:StartParty(player: Player): Result<Snapshot>
	local party, code = getOwnedParty(player)
	if not party then
		return Protocol.Failure(code :: ErrorCode)
	end
	if locked(party) then
		return Protocol.Failure("PARTY_BUSY")
	end
	if party.State == "Retryable" and party.MatchId then
		local retry = MatchService:RetryMatch(party.MatchId)
		if not retry.Success then
			return Protocol.Failure(retry.Code)
		end
		party.State = "Teleporting"
		party.ErrorCode = nil
		publish(party, "Teleporting", "RETRYING")
		return Protocol.Success(snapshot(party))
	end
	local settings, errorCode = Protocol.ValidateStartSettings(party.Settings)
	if not settings then
		return Protocol.Failure(errorCode :: ErrorCode)
	end
	if not mapUnlocked(player, settings.Map) then
		return Protocol.Failure("MAP_LOCKED")
	end
	if membership[player] ~= party or party.Leader ~= player or locked(party) then
		return Protocol.Failure("PARTY_BUSY")
	end
	if #party.Members < Config.MinMembers then
		return Protocol.Failure("PARTY_TOO_SMALL")
	end
	for _, member in party.Members do
		if not validPlayer(member) or member:GetAttribute("AFKTeleportPending") then
			return Protocol.Failure("INVALID_PLAYER")
		end
	end
	-- Lock first. MatchService stores the immutable request before scheduling any yielding work.
	party.State = "Starting"
	party.ErrorCode = nil
	local result = MatchService:StartMatch(
		{ Members = table.clone(party.Members), Settings = settings },
		function(status)
			if parties[party.Id] ~= party or (party.MatchId and party.MatchId ~= status.MatchId) then
				return
			end
			party.ErrorCode = status.ErrorCode
			if status.State == "Closed" then
				if status.ErrorCode == "RESERVATION_FAILED" then
					party.State = "Open"
					party.MatchId = nil
					publish(party, "Updated", status.ErrorCode)
				else
					destroyParty(party, status.ErrorCode or "MATCH_CLOSED")
				end
				return
			end
			party.MatchId = status.MatchId
			party.State = if status.State == "Preparing" then "Starting" else status.State
			publish(party, if party.State == "Open" then "Updated" else "Teleporting", status.ErrorCode)
		end
	)
	if not result.Success then
		party.State = "Open"
		return Protocol.Failure(result.Code)
	end
	party.MatchId = result.Data.MatchId
	publish(party, "Teleporting", "STARTING")
	return Protocol.Success(snapshot(party))
end

function PartyService:GetParty(player: Player, partyId: string?): Result<Snapshot>
	if not validPlayer(player) then
		return Protocol.Failure("INVALID_PLAYER")
	end
	if partyId ~= nil and (type(partyId) ~= "string" or #partyId > 100) then
		return Protocol.Failure("INVALID_ARGUMENT")
	end
	local party = if partyId then parties[partyId] else membership[player]
	if partyId and not party then
		return Protocol.Failure("PARTY_NOT_FOUND")
	end
	return Protocol.Success(if party then snapshot(party) else nil)
end

function PartyService:ListParties(_player: Player?): Result<{ Snapshot }>
	local result = {}
	for _, party in parties do
		if party.State == "Open" then
			table.insert(result, snapshot(party))
		end
	end
	table.sort(result, function(a, b)
		return a.Id < b.Id
	end)
	return Protocol.Success(result)
end

local function allowRequest(player: Player): boolean
	local now = os.clock()
	local limit: RateLimit = rateLimits[player] or { Tokens = Config.RequestBurst, UpdatedAt = now }
	limit.Tokens = math.min(Config.RequestBurst, limit.Tokens + (now - limit.UpdatedAt) * Config.RequestsPerSecond)
	limit.UpdatedAt = now
	rateLimits[player] = limit
	if limit.Tokens < 1 then
		return false
	end
	limit.Tokens -= 1
	return true
end

function PartyService.Init(services)
	MatchService = services:GetService("MatchService")
	DataService = services:GetService("DataService")
end

function PartyService.Start()
	if started then
		return
	end
	started = true
	local folder = ReplicatedStorage:FindFirstChild("RuntimeRemotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "RuntimeRemotes"
		folder.Parent = ReplicatedStorage
	end
	local request = Instance.new("RemoteFunction")
	request.Name = "PartyRequest"
	local changed = Instance.new("RemoteEvent")
	changed.Name = "PartyChanged"
	requestRemote = request
	changedRemote = changed
	local actions: { [string]: any } = {
		CreateParty = PartyService.CreateParty,
		JoinParty = PartyService.JoinParty,
		LeaveParty = PartyService.LeaveParty,
		TransferLeadership = PartyService.TransferLeadership,
		KickMember = PartyService.KickMember,
		DisbandParty = PartyService.DisbandParty,
		UpdateSettings = PartyService.UpdateSettings,
		StartParty = PartyService.StartParty,
		GetParty = PartyService.GetParty,
		ListParties = PartyService.ListParties,
	}
	request.OnServerInvoke = function(player: Player, action: any, payload: any)
		if not allowRequest(player) then
			return Protocol.Failure("RATE_LIMITED")
		end
		if type(action) ~= "string" or not actions[action] then
			return Protocol.Failure("INVALID_ARGUMENT")
		end
		local ok, result = pcall(actions[action], PartyService, player, payload)
		if not ok then
			warn(`[PartyService] {action} failed: {result}`)
			return Protocol.Failure("INTERNAL_ERROR")
		end
		result.Sequence = sequences[player] or 0
		return result
	end
	changed.Parent = folder
	request.Parent = folder
	table.insert(
		connections,
		Players.PlayerRemoving:Connect(function(player)
			local party = membership[player]
			if party then
				removeMember(party, player, "DISCONNECTED")
			end
			sequences[player] = nil
			rateLimits[player] = nil
		end)
	)
end

function PartyService.Destroy()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	for _, party in table.clone(parties) do
		destroyParty(party, "SERVICE_STOPPED")
	end
	if requestRemote then
		requestRemote:Destroy()
	end
	if changedRemote then
		changedRemote:Destroy()
	end
	requestRemote = nil
	changedRemote = nil
	table.clear(sequences)
	table.clear(rateLimits)
	PartyService.Changed:DisconnectAll()
	started = false
end

return PartyService
