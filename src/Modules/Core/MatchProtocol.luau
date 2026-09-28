--!strict
-- One wire contract for lobby UI, party management, and game-place admission.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MapData = require(ReplicatedStorage.Settings.Data.MapData)
local WaveData = require(ReplicatedStorage.Settings.Data.WaveData)
local Config = require(ReplicatedStorage.Settings.Game.PartySettings)

export type Settings = { Map: string, Difficulty: string }
export type SettingsPatch = { Map: string?, Difficulty: string? }
export type ErrorCode =
	"OK"
	| "INVALID_ARGUMENT"
	| "INVALID_SETTINGS"
	| "INVALID_MAP"
	| "INVALID_DIFFICULTY"
	| "MAP_UNAVAILABLE"
	| "MAP_LOCKED"
	| "INVALID_TELEPORT_DATA"
	| "INVALID_PLAYER"
	| "ALREADY_IN_PARTY"
	| "NOT_IN_PARTY"
	| "PARTY_NOT_FOUND"
	| "PARTY_FULL"
	| "PARTY_TOO_SMALL"
	| "NOT_LEADER"
	| "MEMBER_NOT_FOUND"
	| "CANNOT_KICK_SELF"
	| "PARTY_BUSY"
	| "RATE_LIMITED"
	| "INTERNAL_ERROR"
	| "NETWORK_ERROR"
	| "REQUEST_TIMEOUT"
	| "NOT_READY"
	| "DESTINATION_NOT_CONFIGURED"
	| "STUDIO_TELEPORT_UNAVAILABLE"
	| "ALREADY_IN_MATCH"
	| "MATCH_NOT_FOUND"
	| "MATCH_BUSY"
	| "MATCH_EXPIRED"
	| "NO_MEMBERS"
	| "INVITE_NOT_FOUND"
	| "INVITE_EXPIRED"
	| "INVITE_TARGET_UNAVAILABLE"
	| "INVITE_COOLDOWN"
	| "RESERVATION_FAILED"
	| "TELEPORT_FAILED"
	| "TELEPORT_PARTIAL"
	| "TELEPORT_TIMEOUT"

export type Result<T> = { Success: boolean, Code: ErrorCode, Data: T?, Sequence: number? }
export type PartyState = "Open" | "Starting" | "Teleporting" | "Retryable"
export type Member = { UserId: number, Name: string, DisplayName: string }
export type PartySnapshot = {
	Id: string,
	LeaderUserId: number,
	Members: { Member },
	Settings: Settings,
	State: PartyState,
	MaxMembers: number,
	Revision: number,
	MatchId: string?,
	ErrorCode: ErrorCode?,
}
export type PartyEvent = {
	Kind: "Created" | "Updated" | "Removed" | "Disbanded" | "Teleporting",
	PartyId: string,
	Party: PartySnapshot?,
	Reason: string?,
	Sequence: number,
}
export type PartyInvite = {
	Id: string,
	PartyId: string,
	FromUserId: number,
	FromName: string,
	FromDisplayName: string,
	FromLevel: number,
	Map: string,
	Difficulty: string,
	MemberCount: number,
	Loadout: { string },
	ExpiresAt: number,
}
export type TeleportData = {
	Version: number,
	MatchId: string,
	Map: string,
	Difficulty: string,
	MemberCount: number,
	AttemptId: number?, -- Transport correlation only; never changes match identity.
}
export type MatchRequest = { Members: { Player }, Settings: Settings }

local MatchProtocol = {}

function MatchProtocol.Success<T>(data: T?): Result<T>
	return { Success = true, Code = "OK", Data = data }
end

function MatchProtocol.Failure(code: ErrorCode): Result<any>
	return { Success = false, Code = code }
end

function MatchProtocol.ValidateSettings(value: any): (Settings?, ErrorCode?)
	if type(value) ~= "table" then
		return nil, "INVALID_ARGUMENT"
	end
	if type(value.Map) ~= "string" or #value.Map > 100 or not MapData[value.Map] then
		return nil, "INVALID_MAP"
	end
	local definition = MapData[value.Map]
	if type(value.Difficulty) ~= "string" or not table.find(definition.Difficulties, value.Difficulty) then
		return nil, "INVALID_DIFFICULTY"
	end
	local difficulty: MapData.Difficulty = value.Difficulty :: MapData.Difficulty
	local waves = definition.DifficultyWaves[difficulty]
	if type(waves) ~= "number" or waves < 1 or waves % 1 ~= 0 or not definition.Rewards[difficulty] then
		return nil, "MAP_UNAVAILABLE"
	end
	return { Map = value.Map, Difficulty = value.Difficulty }, nil
end

-- A selectable map can be unfinished. Do not send players to a round that cannot finish.
function MatchProtocol.ValidateStartSettings(value: any): (Settings?, ErrorCode?)
	local settings, code = MatchProtocol.ValidateSettings(value)
	if not settings then
		return nil, code :: ErrorCode?
	end
	local waves = WaveData[settings.Map]
	if type(waves) ~= "table" then
		return nil, "MAP_UNAVAILABLE"
	end
	for index = 1, MapData[settings.Map].DifficultyWaves[settings.Difficulty :: MapData.Difficulty] do
		if type(waves[index]) ~= "table" or #waves[index] == 0 then
			return nil, "MAP_UNAVAILABLE"
		end
	end
	return settings, nil
end

function MatchProtocol.CreateTeleportData(matchId: string, settings: Settings, memberCount: number): TeleportData
	return {
		Version = 1,
		MatchId = matchId,
		Map = settings.Map,
		Difficulty = settings.Difficulty,
		MemberCount = memberCount,
	}
end

function MatchProtocol.ValidateTeleportData(value: any): (TeleportData?, ErrorCode?)
	if
		type(value) ~= "table"
		or value.Version ~= 1
		or type(value.MatchId) ~= "string"
		or #value.MatchId ~= 36
		or not string.match(value.MatchId, "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$")
		or type(value.MemberCount) ~= "number"
		or value.MemberCount % 1 ~= 0
		or value.MemberCount < 1
		or value.MemberCount > Config.MaxMembers
	then
		return nil, "INVALID_TELEPORT_DATA"
	end
	if
		value.AttemptId ~= nil
		and (type(value.AttemptId) ~= "number" or value.AttemptId < 1 or value.AttemptId % 1 ~= 0)
	then
		return nil, "INVALID_TELEPORT_DATA"
	end
	local settings, code = MatchProtocol.ValidateStartSettings(value)
	if not settings then
		return nil, code :: ErrorCode?
	end
	local data = MatchProtocol.CreateTeleportData(value.MatchId, settings, value.MemberCount)
	data.AttemptId = value.AttemptId
	return data, nil
end

return table.freeze(MatchProtocol)
