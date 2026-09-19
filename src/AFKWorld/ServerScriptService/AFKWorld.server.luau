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
type AFKSession = {
	Playtime: number,
	CoinCycles: number,
	GemCycles: number,
	LastClock: number,
}

local profiles: { [Player]: any } = {}
local sessions: { [Player]: AFKSession } = {}
local pendingTeleports: { [Player]: TeleportState } = {}

local function lockCharacter(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
		humanoid.AutoRotate = false
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 10)
	if rootPart and rootPart:IsA("BasePart") then
		rootPart.AssemblyLinearVelocity = Vector3.zero
		rootPart.AssemblyAngularVelocity = Vector3.zero
		rootPart.Anchored = true
	end
end

local function enableAFKCharacterLock(player: Player)
	if player.Character then
		task.spawn(lockCharacter, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		task.spawn(lockCharacter, character)
	end)
end

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

local function nonnegativeInteger(value: any, maximum: number?): number
	return math.clamp(math.floor(tonumber(value) or 0), 0, maximum or 1e15)
end

local function getPending(data): { Coins: number, Gems: number }
	if type(data.AFKRewards) ~= "table" then
		data.AFKRewards = { Coins = 0, Gems = 0 }
	end
	data.AFKRewards.Coins = nonnegativeInteger(data.AFKRewards.Coins)
	data.AFKRewards.Gems = nonnegativeInteger(data.AFKRewards.Gems)
	return data.AFKRewards
end

local function updateLeaderstats(player: Player, data)
	local leaderstats = player:FindFirstChild("leaderstats") or Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player
	for _, currencyName in { "Coins", "Gems" } do
		local value = leaderstats:FindFirstChild(currencyName) or Instance.new("IntValue")
		value.Name = currencyName
		value.Value = nonnegativeInteger(data[currencyName])
		value.Parent = leaderstats
	end
end

local function secondsUntilNext(playtime: number, interval: number): number
	return math.max(1, math.ceil(interval - (playtime % interval)))
end

local function sendState(player: Player, status: string?, errorMessage: string?)
	local profile = profiles[player]
	local session = sessions[player]
	local data = if profile then profile.Data else {}
	local pending = getPending(data)
	local playtime = if session then session.Playtime else 0
	stateEvent:FireClient(player, {
		Playtime = math.floor(playtime),
		Coins = nonnegativeInteger(data.Coins),
		Gems = nonnegativeInteger(data.Gems),
		PendingCoins = pending.Coins,
		PendingGems = pending.Gems,
		NextCoinIn = secondsUntilNext(playtime, Config.CoinRewardInterval),
		NextGemIn = secondsUntilNext(playtime, Config.GemRewardInterval),
		CoinProgress = (playtime % Config.CoinRewardInterval) / Config.CoinRewardInterval,
		CoinsPerReward = Config.CoinsPerReward,
		GemsPerReward = Config.GemsPerReward,
		CoinRewardInterval = Config.CoinRewardInterval,
		GemRewardInterval = Config.GemRewardInterval,
		TeleportStatus = status,
		Error = errorMessage,
	})
end

local function accrueRewards(player: Player): boolean
	local profile = profiles[player]
	local session = sessions[player]
	if not profile or not session then
		return false
	end
	local now = os.clock()
	session.Playtime += math.max(now - session.LastClock, 0)
	session.LastClock = now

	local coinCycles = math.floor(session.Playtime / Config.CoinRewardInterval)
	local gemCycles = math.floor(session.Playtime / Config.GemRewardInterval)
	local addedCoinCycles = math.max(coinCycles - session.CoinCycles, 0)
	local addedGemCycles = math.max(gemCycles - session.GemCycles, 0)
	session.CoinCycles = coinCycles
	session.GemCycles = gemCycles
	if addedCoinCycles == 0 and addedGemCycles == 0 then
		return false
	end

	local pending = getPending(profile.Data)
	pending.Coins += addedCoinCycles * Config.CoinsPerReward
	pending.Gems += addedGemCycles * Config.GemsPerReward
	profile:Save()
	return true
end

local function claimRewards(player: Player): (number, number)
	local profile = profiles[player]
	if not profile then
		return 0, 0
	end
	local data = profile.Data
	local pending = getPending(data)
	local coins, gems = pending.Coins, pending.Gems
	if coins <= 0 and gems <= 0 then
		return 0, 0
	end
	pending.Coins, pending.Gems = 0, 0
	data.Coins = nonnegativeInteger(data.Coins) + coins
	data.Gems = nonnegativeInteger(data.Gems) + gems
	updateLeaderstats(player, data)
	profile:Save()
	return coins, gems
end

local function trustedTeleportData(player: Player): { [string]: any }?
	local joinData = player:GetJoinData()
	if joinData.SourcePlaceId ~= Config.LobbyPlaceId and joinData.SourcePlaceId ~= Config.AFKPlaceId then
		return nil
	end
	return if type(joinData.TeleportData) == "table" then joinData.TeleportData else nil
end

local function applyHandoff(data, teleportData: { [string]: any }?)
	if not teleportData or teleportData.HandoffVersion ~= 1 then
		return
	end
	data.Coins = math.max(nonnegativeInteger(data.Coins), nonnegativeInteger(teleportData.CoinsSnapshot))
	data.Gems = math.max(nonnegativeInteger(data.Gems), nonnegativeInteger(teleportData.GemsSnapshot))
	local pending = getPending(data)
	pending.Coins = math.max(pending.Coins, nonnegativeInteger(teleportData.PendingCoinsSnapshot))
	pending.Gems = math.max(pending.Gems, nonnegativeInteger(teleportData.PendingGemsSnapshot))
end

local function endProfile(player: Player)
	local profile = profiles[player]
	local teleportState = pendingTeleports[player]
	if profile then
		if not teleportState then
			accrueRewards(player)
			claimRewards(player)
		elseif teleportState.Kind == "Return" then
			claimRewards(player)
		else
			profile:Save()
		end
	end
	profiles[player], sessions[player], pendingTeleports[player] = nil, nil, nil
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
	local session = sessions[player]
	if session then
		session.LastClock = os.clock()
	end
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
	accrueRewards(player)
	if kind == "Return" then
		claimRewards(player)
	end

	local profile, session = profiles[player], sessions[player]
	if not profile or not session then
		return false
	end
	local data = profile.Data
	local pending = getPending(data)
	profile:Save()
	local teleportData = {
		ReturnPlaceId = Config.LobbyPlaceId,
		HandoffVersion = 1,
		AFKPlaytime = session.Playtime,
		CoinsSnapshot = nonnegativeInteger(data.Coins),
		GemsSnapshot = nonnegativeInteger(data.Gems),
		PendingCoinsSnapshot = pending.Coins,
		PendingGemsSnapshot = pending.Gems,
	}
	local state: TeleportState = {
		Attempts = 1,
		Kind = kind,
		PlaceId = placeId,
		RetryQueued = false,
		TeleportData = teleportData,
	}
	pendingTeleports[player] = state
	sendState(player, if kind == "Return" then "Returning" else "Refreshing")
	local options = Instance.new("TeleportOptions")
	options:SetTeleportData(teleportData)
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
	enableAFKCharacterLock(player)
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
	local teleportData = trustedTeleportData(player)
	applyHandoff(profile.Data, teleportData)
	profiles[player] = profile

	local carriedPlaytime = if teleportData then tonumber(teleportData.AFKPlaytime) else nil
	local playtime = if carriedPlaytime then math.clamp(carriedPlaytime, 0, 7 * 24 * 60 * 60) else 0
	sessions[player] = {
		Playtime = playtime,
		CoinCycles = math.floor(playtime / Config.CoinRewardInterval),
		GemCycles = math.floor(playtime / Config.GemRewardInterval),
		LastClock = os.clock(),
	}
	updateLeaderstats(player, profile.Data)
	profile.OnSessionEnd:Connect(function()
		if profiles[player] ~= profile then
			return
		end
		profiles[player], sessions[player] = nil, nil
		if player:IsDescendantOf(Players) then
			player:Kick("Profile session ended. Please rejoin.")
		end
	end)
	sendState(player)
	scheduleRefresh(player)

	while player:IsDescendantOf(Players) and profiles[player] == profile do
		task.wait(Config.StateUpdateInterval)
		if not pendingTeleports[player] then
			accrueRewards(player)
			sendState(player)
		end
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
	if state then
		warn(`[AFKWorld] Teleport initialization failed for {player.Name}: {result.Name} ({errorMessage})`)
		finishTeleportFailure(player, state, errorMessage)
	end
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
