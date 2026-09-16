local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Promise = require(ReplicatedStorage.Packages.Promise)
local Signal = require(ReplicatedStorage.Packages.Signal)
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)
local MatchProtocol = require(ReplicatedStorage.Shared.Modules.Core.MatchProtocol)

export type PartySnapshot = MatchProtocol.PartySnapshot
export type PartyEvent = MatchProtocol.PartyEvent
export type Settings = MatchProtocol.Settings
export type SettingsPatch = { Map: string?, Difficulty: string? }
export type Result<T> = MatchProtocol.Result<T>
export type Connection = { Connected: boolean, Disconnect: (self: Connection) -> () }

-- The installed Promise package does not export a Luau Promise<T> type.
export type Request<T> = {
	andThen: (self: Request<T>, callback: (T) -> any) -> any,
	catch: (self: Request<T>, callback: (any) -> any) -> any,
	finally: (self: Request<T>, callback: () -> ()) -> any,
	await: (self: Request<T>) -> (boolean, T),
	expect: (self: Request<T>) -> T,
}

local REQUEST_TIMEOUT = 20
local cachedParty: PartySnapshot? = nil
local lastSequence = -1
local lastEventSequence = -1
local requestRemote: RemoteFunction? = nil
local changedConnection: RBXScriptConnection? = nil
local ready = nil
local destroyed = false
local generation = 0
local snapshotChanged = Signal.new()

local PartyController = {}

local function publish(party: PartySnapshot?, sequence: number, event: PartyEvent?)
	if
		destroyed
		or sequence < lastSequence
		or (sequence == lastSequence and (not event or sequence <= lastEventSequence))
	then
		return
	end

	lastSequence = sequence
	if event then
		lastEventSequence = sequence
	end
	cachedParty = if party then TableUtils.DeepFreeze(TableUtils.DeepCopy(party)) else nil
	local frozenEvent = if event then TableUtils.DeepFreeze(TableUtils.DeepCopy(event)) else nil
	snapshotChanged:Fire(cachedParty, frozenEvent)
end

local function connect()
	if destroyed then
		return Promise.reject("NOT_READY")
	end
	if ready then
		return ready
	end
	local currentGeneration = generation

	ready = Promise.new(function(resolve, reject)
		local folder = ReplicatedStorage:WaitForChild("RuntimeRemotes", 10)
		local remote = folder and folder:WaitForChild("PartyRequest", 10)
		local event = folder and folder:WaitForChild("PartyChanged", 10)
		if
			destroyed
			or generation ~= currentGeneration
			or not remote
			or not remote:IsA("RemoteFunction")
			or not event
			or not event:IsA("RemoteEvent")
		then
			reject("NOT_READY")
			return
		end

		requestRemote = remote
		changedConnection = event.OnClientEvent:Connect(function(update: PartyEvent)
			publish(update.Party, update.Sequence, update)
		end)
		resolve()
	end):catch(function(err)
		if generation == currentGeneration then
			ready = nil
		end
		return Promise.reject(err)
	end)
	return ready
end

local function request(action: string, payload: any?, updatesOwnParty: boolean?): any
	local currentGeneration = generation
	return connect()
		:andThen(function()
			return Promise.new(function(resolve)
				local ok, result = pcall(function()
					return (requestRemote :: RemoteFunction):InvokeServer(action, payload)
				end)
				if destroyed or generation ~= currentGeneration then
					resolve({ Success = false, Code = "NOT_READY" })
					return
				end
				if not ok or type(result) ~= "table" or type(result.Success) ~= "boolean" then
					resolve({ Success = false, Code = "NETWORK_ERROR" })
					return
				end

				if updatesOwnParty and result.Success and type(result.Sequence) == "number" then
					publish(result.Data, result.Sequence, nil)
				end
				resolve(TableUtils.DeepFreeze(result))
			end)
		end)
		:timeout(REQUEST_TIMEOUT, "REQUEST_TIMEOUT")
		:catch(function(err)
			local code = if err == "NOT_READY" or err == "REQUEST_TIMEOUT" then err else "NETWORK_ERROR"
			return table.freeze({ Success = false, Code = code })
		end)
end

-- Calls resolve with Result<T>, including network failures. Inspect Success and Code.
function PartyController:CreateParty(settings: SettingsPatch?): Request<Result<PartySnapshot>>
	return request("CreateParty", settings, true)
end

function PartyController:JoinParty(partyId: string): Request<Result<PartySnapshot>>
	return request("JoinParty", partyId, true)
end

function PartyController:LeaveParty(): Request<Result<PartySnapshot>>
	return request("LeaveParty", nil, true)
end

function PartyController:TransferLeadership(userId: number): Request<Result<PartySnapshot>>
	return request("TransferLeadership", userId, true)
end

function PartyController:KickMember(userId: number): Request<Result<PartySnapshot>>
	return request("KickMember", userId, true)
end

function PartyController:DisbandParty(): Request<Result<PartySnapshot>>
	return request("DisbandParty", nil, true)
end

function PartyController:UpdateSettings(settings: SettingsPatch): Request<Result<PartySnapshot>>
	return request("UpdateSettings", settings, true)
end

-- Starting a Retryable party rejoins the existing reserved match.
function PartyController:StartParty(): Request<Result<PartySnapshot>>
	return request("StartParty", nil, true)
end

function PartyController:GetParty(partyId: string?): Request<Result<PartySnapshot>>
	return request("GetParty", partyId, partyId == nil)
end

function PartyController:ListParties(): Request<Result<{ PartySnapshot }>>
	return request("ListParties", nil, false)
end

-- Snapshots are deeply frozen; callers cannot change the controller's cache.
function PartyController:GetCachedParty(): PartySnapshot?
	return cachedParty
end

-- Immediately receives the current snapshot, then server-confirmed changes.
-- event is nil for the initial callback or a query response.
function PartyController:ObserveParty(callback: (PartySnapshot?, PartyEvent?) -> ()): Connection
	local connection = snapshotChanged:Connect(callback)
	callback(cachedParty, nil)
	return connection
end

function PartyController.Init()
	destroyed = false
end

function PartyController.Start()
	PartyController:GetParty()
end

function PartyController.Destroy()
	destroyed = true
	generation += 1
	if changedConnection then
		changedConnection:Disconnect()
		changedConnection = nil
	end
	snapshotChanged:DisconnectAll()
	requestRemote = nil
	ready = nil
	cachedParty = nil
	lastSequence = -1
	lastEventSequence = -1
end

return PartyController
