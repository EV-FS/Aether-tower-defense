local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local TeleportService = game:GetService("TeleportService")

local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore)
local DataConstants = require(ReplicatedStorage.Settings.Data.DataConstants)
local Config = require(ReplicatedStorage.Settings.Game.AFKSettings)

local PlayerStore = ProfileStore.New(Config.ProfileStoreName, DataConstants.PROFILE_TEMPLATE)

type TeleportKind = "Return" | "Refresh"
type TeleportState = {
	Attempts: number,
	Kind: TeleportKind,
	PlaceId: number,
	RetryQueued: boolean,
	TeleportData: { [string]: any },
}

local profiles: { [Player]: any } = {}
local playtimes: { [Player]: number } = {}
local pendingTeleports: { [Player]: TeleportState } = {}

local function getOrCreateRemote(name: string): RemoteEvent
	local existing = ReplicatedStorage:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end

	if existing then
		existing:Destroy()
	end

	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = ReplicatedStorage
	return event
end

local stateEvent = getOrCreateRemote("AFKState")
local stateRequestEvent = getOrCreateRemote("RequestAFKState")
local returnEvent = getOrCreateRemote("ReturnToLobby")

local function updateLeaderstats(player: Player, data)
	local leaderstats = player:FindFirstChild("leaderstats") or Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	for _, currencyName in { "Coins", "Gems" } do
		local value = leaderstats:FindFirstChild(currencyName) or Instance.new("IntValue")
		value.Name = currencyName
		value.Value = data[currencyName] or 0
		value.Parent = leaderstats
	end
end

local function sendState(player: Player, status: string?, errorMessage: string?)
	local profile = profiles[player]
	local data = if profile then profile.Data else {}
	stateEvent:FireClient(player, {
		Playtime = playtimes[player] or 0,
		Coins = data.Coins or 0,
		Gems = data.Gems or 0,
		TeleportStatus = status,
		Error = errorMessage,
	})
end

local function endProfile(player: Player)
	local profile = profiles[player]
	profiles[player] = nil
	playtimes[player] = nil
	pendingTeleports[player] = nil

	if profile then
		profile:EndSession()
	end
end

local scheduleRefresh: (Player) -> ()

local function finishTeleportFailure(player: Player, state: TeleportState, message: string)
	if pendingTeleports[player] ~= state or state.RetryQueued then
		return
	end

	if state.Attempts < Config.TeleportRetryCount then
		state.RetryQueued = true
		task.delay(Config.TeleportRetryDelay, function()
			if pendingTeleports[player] ~= state or not player:IsDescendantOf(Players) then
				return
			end

			state.RetryQueued = false
			state.Attempts += 1

			local options = Instance.new("TeleportOptions")
			options:SetTeleportData(state.TeleportData)
			local success, err = pcall(function()
				TeleportService:TeleportAsync(state.PlaceId, { player }, options)
			end)
			if not success then
				warn(`[AFKWorld] Teleport attempt {state.Attempts} failed for {player.Name}: {err}`)
				finishTeleportFailure(player, state, tostring(err))
			end
		end)
		return
	end

	pendingTeleports[player] = nil
	warn(`[AFKWorld] Giving up teleport for {player.Name}: {message}`)
	sendState(player, nil, "Teleport failed. Please try again.")

	if state.Kind == "Refresh" and profiles[player] then
		scheduleRefresh(player)
	end
end

local function beginTeleport(player: Player, kind: TeleportKind, placeId: number): boolean
	if pendingTeleports[player] then
		return false
	end

	if RunService:IsStudio() then
		sendState(player, nil, "Teleport is unavailable in Studio. Test in the published game.")
		return false
	end

	local profile = profiles[player]
	if profile then
		profile:Save()
	end

	local state: TeleportState = {
		Attempts = 1,
		Kind = kind,
		PlaceId = placeId,
		RetryQueued = false,
		TeleportData = {
			ReturnPlaceId = Config.LobbyPlaceId,
			AFKPlaytime = playtimes[player] or 0,
		},
	}
	pendingTeleports[player] = state
	sendState(player, if kind == "Return" then "Returning" else "Refreshing")

	local options = Instance.new("TeleportOptions")
	options:SetTeleportData(state.TeleportData)
	local success, err = pcall(function()
		TeleportService:TeleportAsync(placeId, { player }, options)
	end)
	if not success then
		warn(`[AFKWorld] Teleport attempt 1 failed for {player.Name}: {err}`)
		finishTeleportFailure(player, state, tostring(err))
	end

	return true
end

scheduleRefresh = function(player: Player)
	task.delay(Config.SessionRefreshInterval, function()
		if not player:IsDescendantOf(Players) or not profiles[player] then
			return
		end

		if pendingTeleports[player] then
			scheduleRefresh(player)
			return
		end

		beginTeleport(player, "Refresh", Config.AFKPlaceId)
	end)
end

local function loadPlayer(player: Player)
	player:SetAttribute("IsAFKWorld", true)
	local profile = PlayerStore:StartSessionAsync(`Player_{player.UserId}`, {
		Cancel = function()
			return not player:IsDescendantOf(Players)
		end,
	})
	if not profile then
		if player:IsDescendantOf(Players) then
			player:Kick("Data load failed. Please rejoin.")
		end
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()
	profiles[player] = profile

	local teleportData = player:GetJoinData().TeleportData
	local carriedPlaytime = if type(teleportData) == "table" then tonumber(teleportData.AFKPlaytime) else nil
	playtimes[player] = if carriedPlaytime then math.clamp(math.floor(carriedPlaytime), 0, 7 * 24 * 60 * 60) else 0

	updateLeaderstats(player, profile.Data)
	profile.OnSessionEnd:Connect(function()
		if profiles[player] ~= profile then
			return
		end

		profiles[player] = nil
		if player:IsDescendantOf(Players) then
			player:Kick("Profile session ended. Please rejoin.")
		end
	end)

	sendState(player)
	scheduleRefresh(player)

	while player:IsDescendantOf(Players) and profiles[player] == profile do
		task.wait(Config.RewardInterval)
		if not player:IsDescendantOf(Players) or profiles[player] ~= profile then
			break
		end

		playtimes[player] = (playtimes[player] or 0) + Config.RewardInterval
		profile.Data.Coins = (profile.Data.Coins or 0) + Config.CoinsPerInterval
		profile.Data.Gems = (profile.Data.Gems or 0) + Config.GemsPerInterval
		updateLeaderstats(player, profile.Data)
		profile:Save()
		sendState(player)
	end
end

stateRequestEvent.OnServerEvent:Connect(function(player: Player)
	if profiles[player] then
		sendState(player)
	end
end)

returnEvent.OnServerEvent:Connect(function(player: Player)
	beginTeleport(player, "Return", Config.LobbyPlaceId)
end)

TeleportService.TeleportInitFailed:Connect(function(player, result, errorMessage)
	local state = pendingTeleports[player]
	if not state then
		return
	end

	warn(`[AFKWorld] Teleport initialization failed for {player.Name}: {result.Name} ({errorMessage})`)
	finishTeleportFailure(player, state, errorMessage)
end)

Players.PlayerAdded:Connect(function(player)
	task.spawn(loadPlayer, player)
end)

for _, player in Players:GetPlayers() do
	task.spawn(loadPlayer, player)
end

Players.PlayerRemoving:Connect(endProfile)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		endProfile(player)
	end
end)
