--!strict

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local MatchProtocol = require(ReplicatedStorage.Shared.Modules.Core.MatchProtocol)
local PartySettings = require(ReplicatedStorage.Settings.Game.PartySettings)
local DataService

export type MatchRequest = {
	Members: { Player },
	Settings: MatchProtocol.Settings,
}
export type MatchState = "Preparing" | "Teleporting" | "Retryable" | "Closed"
export type MatchStatus = {
	State: MatchState,
	MatchId: string,
	ErrorCode: MatchProtocol.ErrorCode?,
}
export type MatchReceipt = { MatchId: string }
type Observer = (MatchStatus) -> ()
type MatchRecord = {
	Id: string,
	State: MatchState,
	Members: { [number]: Player },
	MemberCount: number,
	Settings: MatchProtocol.Settings,
	AccessCode: string?,
	Attempt: number,
	Pending: { [number]: boolean },
	HasDeparted: boolean,
	ExpiresAt: number?,
	Revision: number,
	OnChanged: Observer,
}

local MatchService = {}
local matches: { [string]: MatchRecord } = {}
local playerMatches: { [number]: string } = {}
local connections: { RBXScriptConnection } = {}

local function isCurrent(record: MatchRecord): boolean
	return matches[record.Id] == record
end

local function notify(record: MatchRecord, state: MatchState, errorCode: MatchProtocol.ErrorCode?)
	record.State = state
	record.Revision += 1
	local revision = record.Revision
	local status: MatchStatus = { State = state, MatchId = record.Id, ErrorCode = errorCode }
	-- Callers finish their own mutation before observing a transition. Stale queued
	-- transitions and subscriber exceptions cannot mutate or strand the match.
	task.defer(function()
		if record.Revision ~= revision then
			return
		end
		local ok, err = pcall(record.OnChanged :: any, status)
		if not ok then
			warn("[MatchService] Status observer failed:", err)
		end
	end)
end

local function close(record: MatchRecord, errorCode: MatchProtocol.ErrorCode?)
	if not isCurrent(record) then
		return
	end
	matches[record.Id] = nil
	for userId in record.Members do
		if playerMatches[userId] == record.Id then
			playerMatches[userId] = nil
		end
	end
	record.Members = {}
	record.Pending = {}
	notify(record, "Closed", errorCode)
end

local function remainingMembers(record: MatchRecord): { Player }
	local remaining = {}
	for userId, player in record.Members do
		if player.Parent == Players and playerMatches[userId] == record.Id then
			table.insert(remaining, player)
		end
	end
	return remaining
end

local beginAttempt: (MatchRecord) -> ()

local function finishAttempt(record: MatchRecord, attempt: number, errorCode: MatchProtocol.ErrorCode)
	if not isCurrent(record) or record.Attempt ~= attempt or record.State ~= "Teleporting" then
		return
	end
	if #remainingMembers(record) == 0 then
		close(record, nil)
		return
	end
	record.Pending = {}
	-- A departure only establishes that someone left this lobby, not that they
	-- reached the destination. No arrival/reward claims depend on this flag.
	notify(record, "Retryable", if record.HasDeparted then "TELEPORT_PARTIAL" else errorCode)
	if attempt < PartySettings.TeleportMaxAttempts then
		task.delay(PartySettings.TeleportRetryDelay, function()
			if isCurrent(record) and record.Attempt == attempt and (record.State :: MatchState) == "Retryable" then
				beginAttempt(record)
			end
		end)
	end
end

beginAttempt = function(record: MatchRecord)
	if not isCurrent(record) then
		return
	end
	if record.ExpiresAt and os.clock() >= record.ExpiresAt then
		close(record, "MATCH_EXPIRED")
		return
	end
	local members = remainingMembers(record)
	if #members == 0 then
		close(record, nil)
		return
	end
	for _, player in members do
		if DataService:IsLocked(player) then
			close(record, "NOT_READY")
			return
		end
	end
	record.Attempt += 1
	local attempt = record.Attempt
	record.Pending = {}
	for _, player in members do
		record.Pending[player.UserId] = true
	end
	notify(record, "Teleporting", nil)

	-- This watchdog also covers a TeleportAsync call that never returns.
	task.delay(PartySettings.TeleportAttemptTimeout, function()
		finishAttempt(record, attempt, "TELEPORT_TIMEOUT")
	end)
	task.defer(function()
		if not isCurrent(record) or record.Attempt ~= attempt or record.State ~= "Teleporting" then
			return
		end
		-- Recheck attendance after deferring; never submit a player who has left.
		local present = remainingMembers(record)
		if #present == 0 then
			close(record, nil)
			return
		end
		for _, player in present do
			if DataService:IsLocked(player) then
				close(record, "NOT_READY")
				return
			end
		end
		local options = Instance.new("TeleportOptions")
		options.ReservedServerAccessCode = record.AccessCode :: string
		local data = MatchProtocol.CreateTeleportData(record.Id, record.Settings, record.MemberCount)
		data.AttemptId = attempt
		options:SetTeleportData(data)
		local ok, err = pcall(function()
			TeleportService:TeleportAsync(PartySettings.GamePlaceId, present, options)
		end)
		options:Destroy()
		if not ok and isCurrent(record) and record.Attempt == attempt and record.State == "Teleporting" then
			warn("[MatchService] Teleport request failed:", err)
			finishAttempt(record, attempt, "TELEPORT_FAILED")
		end
	end)
end

-- Non-yielding acceptance API shared by parties and future matchmaking. The
-- caller supplies already chosen members/settings; this service revalidates and
-- snapshots them before any asynchronous reservation or teleport can begin.
function MatchService:StartMatch(request: MatchRequest, onChanged: Observer): MatchProtocol.Result<MatchReceipt>
	if type(request) ~= "table" or type(request.Members) ~= "table" or type(onChanged) ~= "function" then
		return MatchProtocol.Failure("INVALID_ARGUMENT")
	end
	local settings, settingsError = MatchProtocol.ValidateStartSettings(request.Settings)
	if not settings then
		return MatchProtocol.Failure(settingsError :: MatchProtocol.ErrorCode)
	end
	local memberCount = #request.Members
	if memberCount < PartySettings.MinMembers then
		return MatchProtocol.Failure("PARTY_TOO_SMALL")
	end
	if memberCount > PartySettings.MaxMembers then
		return MatchProtocol.Failure("PARTY_FULL")
	end
	local members: { [number]: Player } = {}
	local actualCount = 0
	for index, player in request.Members do
		if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > memberCount then
			return MatchProtocol.Failure("INVALID_ARGUMENT")
		end
		if typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent ~= Players then
			return MatchProtocol.Failure("INVALID_PLAYER")
		end
		if DataService:IsLocked(player) then
			return MatchProtocol.Failure("NOT_READY")
		end
		if members[player.UserId] then
			return MatchProtocol.Failure("INVALID_ARGUMENT")
		end
		if playerMatches[player.UserId] or player:GetAttribute("AFKTeleportPending") then
			return MatchProtocol.Failure("ALREADY_IN_MATCH")
		end
		members[player.UserId] = player
		actualCount += 1
	end
	if actualCount ~= memberCount then
		return MatchProtocol.Failure("INVALID_ARGUMENT")
	end
	if PartySettings.GamePlaceId <= 0 or PartySettings.GamePlaceId % 1 ~= 0 then
		return MatchProtocol.Failure("DESTINATION_NOT_CONFIGURED")
	end
	if RunService:IsStudio() then
		return MatchProtocol.Failure("STUDIO_TELEPORT_UNAVAILABLE")
	end

	local record: MatchRecord = {
		Id = HttpService:GenerateGUID(false),
		State = "Preparing",
		Members = members,
		MemberCount = memberCount,
		Settings = { Map = settings.Map, Difficulty = settings.Difficulty },
		AccessCode = nil,
		Attempt = 0,
		Pending = {},
		HasDeparted = false,
		ExpiresAt = nil,
		Revision = 0,
		OnChanged = onChanged,
	}
	matches[record.Id] = record
	for userId in members do
		playerMatches[userId] = record.Id
	end
	notify(record, "Preparing", nil)
	task.delay(PartySettings.ReservationTimeout, function()
		if isCurrent(record) and record.State == "Preparing" then
			close(record, "RESERVATION_FAILED")
		end
	end)
	task.defer(function()
		if not isCurrent(record) then
			return
		end
		local ok, accessCode = pcall(function()
			return TeleportService:ReserveServerAsync(PartySettings.GamePlaceId)
		end)
		-- A reservation can finish after timeout/disband; never teleport then.
		if not isCurrent(record) or record.State ~= "Preparing" then
			return
		end
		if not ok or type(accessCode) ~= "string" or accessCode == "" then
			warn("[MatchService] Server reservation failed")
			close(record, "RESERVATION_FAILED")
			return
		end
		record.AccessCode = accessCode
		record.ExpiresAt = os.clock() + PartySettings.MatchRetryLifetime
		task.delay(PartySettings.MatchRetryLifetime, function()
			close(record, "MATCH_EXPIRED")
		end)
		beginAttempt(record)
	end)
	return MatchProtocol.Success({ MatchId = record.Id })
end

function MatchService:RetryMatch(matchId: string): MatchProtocol.Result<MatchReceipt>
	if type(matchId) ~= "string" then
		return MatchProtocol.Failure("INVALID_ARGUMENT")
	end
	local record = matches[matchId]
	if not record then
		return MatchProtocol.Failure("MATCH_NOT_FOUND")
	end
	if record.ExpiresAt and os.clock() >= record.ExpiresAt then
		close(record, "MATCH_EXPIRED")
		return MatchProtocol.Failure("MATCH_EXPIRED")
	end
	if record.State ~= "Retryable" then
		return MatchProtocol.Failure("MATCH_BUSY")
	end
	if #remainingMembers(record) == 0 then
		close(record, nil)
		return MatchProtocol.Failure("NO_MEMBERS")
	end
	beginAttempt(record)
	return MatchProtocol.Success({ MatchId = record.Id })
end

function MatchService:IsPlayerBusy(player: Player): boolean
	return playerMatches[player.UserId] ~= nil
end

-- Synchronous guard for party mutations while asynchronous status delivery is
-- queued. Retryable membership changes remain allowed.
function MatchService:IsMatchBusy(matchId: string): boolean
	local record = matches[matchId]
	return record ~= nil and (record.State == "Preparing" or record.State == "Teleporting")
end

function MatchService:RemovePlayer(player: Player)
	local matchId = playerMatches[player.UserId]
	local record = if matchId then matches[matchId] else nil
	if not record then
		return
	end
	-- This is also called on PlayerRemoving, where Parent can still be Players.
	-- Explicit party removal during Retryable is not evidence of arrival either.
	if record.Attempt > 0 then
		record.HasDeparted = true
	end
	record.Members[player.UserId] = nil
	record.Pending[player.UserId] = nil
	playerMatches[player.UserId] = nil
	if next(record.Members) == nil then
		close(record, nil)
	elseif record.State == "Teleporting" and next(record.Pending) == nil then
		finishAttempt(record, record.Attempt, "TELEPORT_PARTIAL")
	end
end

function MatchService:CloseMatch(matchId: string)
	local record = matches[matchId]
	if record then
		close(record, nil)
	end
end

function MatchService.Init(services)
	DataService = services:GetService("DataService")
end

MatchService.Dependencies = { "DataService" }

function MatchService.Start()
	if #connections > 0 then
		return
	end
	table.insert(
		connections,
		Players.PlayerRemoving:Connect(function(player)
			MatchService:RemovePlayer(player)
		end)
	)
	table.insert(
		connections,
		TeleportService.TeleportInitFailed:Connect(function(player, _result, _message, placeId, options)
			local matchId = playerMatches[player.UserId]
			local record = if matchId then matches[matchId] else nil
			if not record or record.State ~= "Teleporting" or placeId ~= PartySettings.GamePlaceId or not options then
				return
			end
			local ok, data = pcall(function()
				return options:GetTeleportData()
			end)
			if not ok or type(data) ~= "table" or data.MatchId ~= record.Id or data.AttemptId ~= record.Attempt then
				return
			end
			if options.ReservedServerAccessCode ~= record.AccessCode or not record.Pending[player.UserId] then
				return
			end
			record.Pending[player.UserId] = nil
			-- Wait for every member to fail/leave or the watchdog before another
			-- batch. Multiple failure events cannot schedule parallel retries.
			if next(record.Pending) == nil then
				finishAttempt(record, record.Attempt, "TELEPORT_FAILED")
			end
		end)
	)
end

function MatchService.Destroy()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	for _, record in matches do
		close(record, nil)
	end
end

return MatchService
