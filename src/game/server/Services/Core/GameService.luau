--/Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

--/Modules

local GameSettings = require(ReplicatedStorage.Settings.Game.GameSettings)
local PartySettings = require(ReplicatedStorage.Settings.Game.PartySettings)
local MatchProtocol = require(ReplicatedStorage.Shared.Modules.Core.MatchProtocol)
local MapData = require(ReplicatedStorage.Settings.Data.MapData)
local ServerCutscene = require(script.Parent.ServerCutscene)
local CharacterGuard = require(script.Parent.Parent.Parent.CharacterGuard)
local SafeTeleport = require(ReplicatedStorage.Shared.Modules.Core.SafeTeleport)
local Net = require(ReplicatedStorage.Shared.Net)

local BaseService
local MapService
local WaveService
local EconomyService
local DataService

local TowerService
local EnemyService
local UnitService

-------------------------------------------------
--// GameService
-------------------------------------------------
local GameService = {}
GameService.Dependencies = {
	"BaseService",
	"MapService",
	"WaveService",
	"EconomyService",
	"DataService",
	"TowerService",
	"EnemyService",
	"UnitService",
}
GameService.Connections = {}
GameService.RestartList = {}
GameService.ReadyList = {}
GameService.SkipList = {}

GameService.SkipActive = false
GameService.IsGameRunning = false
GameService.IsGameStarting = false
GameService.IsMapLoading = false
GameService.IsMapLoaded = false

GameService.SelectedMap = nil
GameService.SelectedDifficulty = nil
GameService.StartPlayerCount = 1

-- Match settings are committed together before any yielding work. Later arrivals
-- can join this match, but cannot replace its map, difficulty, or identity.
local matchData: MatchProtocol.TeleportData? = nil
local admittedPlayers: { [Player]: boolean } = {}
local arrivalDeadline = 0
local started = false

function GameService:GetMatchInfo(): MatchProtocol.TeleportData?
	return if matchData then table.clone(matchData) else nil
end

function GameService:GetMatchPlayers(): { Player }
	local players = {}
	for _, player in Players:GetPlayers() do
		if admittedPlayers[player] then
			table.insert(players, player)
		end
	end
	return players
end

local function admitPlayer(player: Player, joinData: any): (boolean, string?)
	local teleportData = if type(joinData) == "table" then joinData.TeleportData else nil
	local incoming: MatchProtocol.TeleportData?
	local errorCode: string?
	if RunService:IsStudio() and teleportData == nil then
		-- Preserve the project's map-preview workflow even while its waves are WIP.
		local settings, settingsError = MatchProtocol.ValidateSettings({
			Map = PartySettings.StudioMap,
			Difficulty = PartySettings.StudioDifficulty,
		})
		if not settings then
			return false, settingsError
		end
		incoming = matchData or MatchProtocol.CreateTeleportData(HttpService:GenerateGUID(false), settings, 1)
	else
		if not RunService:IsStudio() then
			if
				type(joinData) ~= "table"
				or joinData.SourcePlaceId ~= GameSettings.LobbyPlaceId
				or joinData.SourceGameId ~= game.GameId
			then
				return false, "INVALID_SOURCE"
			end
		end
		incoming, errorCode = MatchProtocol.ValidateTeleportData(teleportData)
	end
	if not incoming then
		return false, errorCode or "INVALID_TELEPORT_DATA"
	end

	if matchData then
		if
			incoming.MatchId ~= matchData.MatchId
			or incoming.Map ~= matchData.Map
			or incoming.Difficulty ~= matchData.Difficulty
			or incoming.MemberCount ~= matchData.MemberCount
		then
			return false, "MATCH_MISMATCH"
		end
	else
		matchData = table.freeze(table.clone(incoming))
		GameService.SelectedMap = incoming.Map
		GameService.SelectedDifficulty = incoming.Difficulty
		arrivalDeadline = os.clock() + PartySettings.ArrivalTimeout
		ReplicatedStorage:SetAttribute("MatchId", incoming.MatchId)
		ReplicatedStorage:SetAttribute("ExpectedPlayerCount", incoming.MemberCount)
		task.delay(PartySettings.ArrivalTimeout, function()
			if started then
				GameService:TryStartGameWhenAllReady()
			end
		end)
	end
	admittedPlayers[player] = true
	return true, nil
end

function GameService:AllReady()
	local players = self:GetMatchPlayers()
	if #players == 0 then
		return false
	end
	if matchData and #players < matchData.MemberCount and os.clock() < arrivalDeadline then
		return false
	end

	for _, player in ipairs(players) do
		if not table.find(self.ReadyList, player) then
			return false
		end
	end
	return true
end

function GameService:FireReadyState()
	Net.GameEvent.ReadyVoted.FireAll(#self.ReadyList)
end

function GameService:PrepareMap()
	if self.IsMapLoaded or not matchData then
		return
	end

	if self.IsMapLoading then
		while self.IsMapLoading do
			task.wait()
		end
		return
	end

	self.IsMapLoading = true
	local mapFolder = workspace:WaitForChild("Map")
	mapFolder:SetAttribute("GameplayReady", false)
	mapFolder:SetAttribute("LoadError", nil)

	if RunService:IsStudio() then
		self.SelectedMap = "Kitsune Raid"
		self.SelectedDifficulty = "Normal"
	end

	local success = self:WaitForTeleportData():await()
	if not success then
		warn("Failed to receive teleport data. Falling back to default map.")
		self.SelectedMap = "Chapter 1"
		self.SelectedDifficulty = "Normal"
	end

	ReplicatedStorage:SetAttribute("SelectedMap", self.SelectedMap)
	ReplicatedStorage:SetAttribute("SelectedDifficulty", self.SelectedDifficulty or "Normal")

	local mapInfo = MapData[self.SelectedMap]
	local introCutscene = mapInfo and mapInfo.IntroCutscene
	local preparedMap = nil
	ReplicatedStorage:SetAttribute("CutsceneEndedAt", nil)
	ReplicatedStorage:SetAttribute("CutsceneTransitionSeconds", nil)
	if introCutscene then
		local played, err = pcall(ServerCutscene.Play, introCutscene, function()
			preparedMap = MapService:PrepareMap(self.SelectedMap)
		end)
		if not played then
			MapService:DiscardPrepared(preparedMap)
			self.IsMapLoading = false
			mapFolder:SetAttribute("LoadError", string.sub(tostring(err), 1, 500))
			warn("[GameService] Map intro failed: " .. tostring(err))
			return
		end
	end

	local loaded, loadError = pcall(function()
		MapService:LoadMapAsync(self.SelectedMap, self.SelectedDifficulty, preparedMap)
		local characterStarted = os.clock()
		CharacterGuard.Release(mapFolder, self:GetMatchPlayers())
		mapFolder:SetAttribute("CharacterPrepareSeconds", os.clock() - characterStarted)
	end)
	if not loaded then
		self.IsMapLoading = false
		mapFolder:SetAttribute("LoadError", string.sub(tostring(loadError), 1, 500))
		warn("[GameService] Map preparation failed: " .. tostring(loadError))
		return
	end

	self.IsMapLoaded = true
	mapFolder:SetAttribute("GameplayReady", true)
	local endedAt = ReplicatedStorage:GetAttribute("CutsceneEndedAt")
	if endedAt then
		ReplicatedStorage:SetAttribute("CutsceneTransitionSeconds", workspace:GetServerTimeNow() - endedAt)
	end
	self.IsMapLoading = false
end

function GameService:StartGame()
	if self.IsGameRunning or self.IsGameStarting then
		return
	end
	self.IsGameStarting = true
	self:PrepareMap()
	self.IsGameStarting = false
	-- A player may have arrived while map/cutscene loading yielded.
	if not self.IsMapLoaded or not self:AllReady() then
		return
	end
	self.IsGameRunning = true
	table.clear(self.ReadyList)
	self:FireReadyState()
	self.StartPlayerCount = math.max(1, #self:GetMatchPlayers())
	Net.GameEvent.GameInfoSynced.FireAll({
		Difficulty = self.SelectedDifficulty,
		StartPlayerCount = self.StartPlayerCount,
	})

	BaseService:Reset()

	WaveService:PlayRound(self.SelectedMap, self.SelectedDifficulty)
end

function GameService:GameOver(isWin: boolean)
	if not self.IsGameRunning then
		return
	end
	self.IsGameRunning = false

	WaveService:Stop()
	EnemyService:DestroyAll()
	UnitService:DestroyAll()

	for _, connection in pairs(self.Connections) do
		connection:Disconnect()
	end
	table.clear(self.Connections)

	local coins = 0
	local exp = 0
	local gems = 0
	local mapData = MapData[self.SelectedMap]

	if mapData then
		local mapRewards = mapData.Rewards and mapData.Rewards[self.SelectedDifficulty]

		if mapRewards then
			if isWin then
				coins = mapRewards.WinCoins or 0
				exp = mapRewards.WinExp or 0
				gems = mapRewards.WinGems or 0
			else
				local maxWave = WaveService:GetWaves()
				local currentWave = WaveService.CurrentWave
				local completionRatio = math.clamp(maxWave > 0 and (currentWave / maxWave) or 0, 0, 1)

				coins = math.floor((mapRewards.LoseCoinsPerWave or 0) * completionRatio)
				exp = math.floor((mapRewards.LoseExpPerWave or 0) * completionRatio)
				gems = 0
			end
		else
			warn(
				`[GameService] MapData에서 {self.SelectedMap}의 난이도 {self.SelectedDifficulty} 보상 정보를 찾을 수 없습니다.`
			)
		end
	else
		warn(`[GameService] MapData에서 {self.SelectedMap}의 보상 정보를 찾을 수 없습니다.`)
	end

	-- Rewards continue to come from server-observed game results and MapData.
	-- TeleportData never contains reward amounts or player entitlements.
	for _, player in ipairs(self:GetMatchPlayers()) do
		task.spawn(function()
			local profile = DataService:GetProfile(player)
			if not profile then
				return
			end

			if coins > 0 then
				DataService:AddData(player, "Coins", coins)
			end
			if exp > 0 then
				DataService:AddData(player, "Exp", exp)
			end
			if gems > 0 then
				DataService:AddData(player, "Gems", gems)
			end

			if isWin then
				profile.Data.Wins = (profile.Data.Wins or 0) + 1
			end
		end)
	end

	Net.GameEvent.GameOver.FireAll({
		isWin = isWin,
		coins = coins,
		exp = exp,
		gems = gems,
	})
end

function GameService:RemoveFromRestartList(player: Player)
	local index = table.find(self.RestartList, player)
	if index then
		table.remove(self.RestartList, index)
	end
end

function GameService:RemoveFromReadyList(player: Player)
	local index = table.find(self.ReadyList, player)
	if index then
		table.remove(self.ReadyList, index)
	end
end

function GameService:RemoveFromSkipList(player: Player)
	local index = table.find(self.SkipList, player)
	if index then
		table.remove(self.SkipList, index)
	end
end

function GameService:TrySkip()
	if not self.IsGameRunning or not self.SkipActive then
		return
	end

	local totalPlayers = #self:GetMatchPlayers()
	if totalPlayers == 0 then
		return
	end

	local majority = math.floor(totalPlayers / 2) + 1
	if #self.SkipList < majority then
		return
	end

	self.SkipActive = false
	table.clear(self.SkipList)

	local currentWave = WaveService.CurrentWave
	local skipCash = GameSettings.SkipBonus * currentWave
	EconomyService.AddCashToAll(skipCash)

	WaveService:StartNextWave()
end

function GameService:TryStartGameWhenAllReady()
	if self.IsGameRunning or self.IsGameStarting then
		return
	end

	if not self:AllReady() then
		return
	end

	self:StartGame()
end

function GameService:RestartGame()
	if self.IsGameRunning or self.IsGameStarting then
		return
	end

	local totalPlayers = #self:GetMatchPlayers()
	if totalPlayers == 0 then
		return
	end

	local majority = math.floor(totalPlayers / 2) + 1
	if #self.RestartList < majority then
		return
	end

	table.clear(self.RestartList)
	table.clear(self.ReadyList)
	table.clear(self.SkipList)
	self.SkipActive = false

	TowerService:DestroyAll()
	EnemyService:DestroyAll()
	UnitService:DestroyAll()

	BaseService:Reset()

	EconomyService.SetCashToAll(GameSettings.StartMoney)
	Net.GameEvent.Restarted.FireAll()

	self:TryStartGameWhenAllReady()
end

function GameService.Init(services)
	BaseService = services:GetService("BaseService")
	MapService = services:GetService("MapService")
	WaveService = services:GetService("WaveService")
	EconomyService = services:GetService("EconomyService")
	DataService = services:GetService("DataService")

	TowerService = services:GetService("TowerService")
	EnemyService = services:GetService("EnemyService")
	UnitService = services:GetService("UnitService")
end

function GameService.Start()
	if started then
		return
	end
	started = true

	local function PlayerAdded(player: Player)
		if admittedPlayers[player] or player.Parent ~= Players then
			return
		end
		local readSuccess, joinData = pcall(player.GetJoinData, player)
		local admitted, reason = admitPlayer(player, if readSuccess then joinData else nil)
		if not admitted then
			warn(string.format("[GameService] Rejected match arrival %d: %s", player.UserId, tostring(reason)))
			player:Kick("Invalid match information. Please join the game through the lobby.")
			return
		end

		GameService:FireReadyState()
		task.defer(function()
			GameService:PrepareMap()
			if not GameService.IsMapLoaded or player.Parent ~= Players or not admittedPlayers[player] then
				return
			end
			-- CharacterGuard snapshots players during map setup. An arrival during
			-- that yielding work may have missed the snapshot with auto-loads off.
			if not player.Character and Players.CharacterAutoLoads then
				local loaded, loadError = pcall(player.LoadCharacterAsync, player)
				if not loaded and player.Parent == Players then
					warn("[GameService] Late-arrival character failed: " .. tostring(loadError))
					player:Kick("Your character could not load. Please rejoin through the lobby.")
				end
			end
		end)
	end

	--/Player
	Players.PlayerAdded:Connect(PlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		PlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		admittedPlayers[player] = nil
		GameService:RemoveFromRestartList(player)
		GameService:RemoveFromReadyList(player)
		GameService:RemoveFromSkipList(player)
		task.defer(function()
			GameService:FireReadyState()

			Net.GameEvent.RestartVoted.FireAll(#GameService.RestartList)
			Net.GameEvent.SkipVoted.FireAll(#GameService.SkipList)

			GameService:RestartGame()
			GameService:TrySkip()
			GameService:TryStartGameWhenAllReady()
		end)
	end)

	--/Net
	BaseService.BaseDestroyed:Connect(function()
		GameService:GameOver(false)
	end)

	WaveService.WaveCompleted:Connect(function(waveNumber: number)
		if not GameService.IsGameRunning then
			return
		end

		local waveBonus = math.floor(500 / (1 + math.exp(-0.2 * (waveNumber - 20))))
		local reward = GameSettings.WaveReward * waveNumber + waveBonus
		EconomyService.AddCashToAll(reward)

		WaveService:StartNextWave()
	end)

	WaveService.WaveStarted:Connect(function(_: number)
		GameService.SkipActive = false
		table.clear(GameService.SkipList)
		Net.GameEvent.SkipVoted.FireAll(0)
	end)

	WaveService.CanSkip:Connect(function()
		if not GameService.IsGameRunning then
			return
		end

		GameService.SkipActive = true
		table.clear(GameService.SkipList)
		Net.GameEvent.CanSkip.FireAll()
	end)

	WaveService.AllWavesCompleted:Connect(function()
		if not GameService.IsGameRunning then
			return
		end
		GameService:GameOver(true)
	end)

	Net.GameEvent.VoteSkip.On(function(player: Player)
		if not admittedPlayers[player] or not GameService.IsGameRunning then
			return
		end

		if not GameService.SkipActive then
			return
		end

		if table.find(GameService.SkipList, player) then
			return
		end

		table.insert(GameService.SkipList, player)
		Net.GameEvent.SkipVoted.FireAll(#GameService.SkipList)

		GameService:TrySkip()
	end)

	Net.GameEvent.VoteRestart.On(function(player: Player)
		if not admittedPlayers[player] or GameService.IsGameRunning or GameService.IsGameStarting then
			return
		end

		if table.find(GameService.RestartList, player) then
			return
		end

		table.insert(GameService.RestartList, player)
		Net.GameEvent.RestartVoted.FireAll(#GameService.RestartList)

		GameService:RestartGame()
	end)

	Net.GameEvent.Ready.On(function(player: Player)
		if not admittedPlayers[player] or GameService.IsGameRunning then
			return
		end

		if table.find(GameService.ReadyList, player) then
			return
		end

		table.insert(GameService.ReadyList, player)
		GameService:FireReadyState()
		GameService:TryStartGameWhenAllReady()
	end)

	Net.GameEvent.GetGameInfo.On(function()
		return {
			Difficulty = GameService.SelectedDifficulty or "Normal",
			StartPlayerCount = GameService.StartPlayerCount,
		}
	end)

	Net.GameEvent.TeleportToLobby.On(function(player: Player)
		if not admittedPlayers[player] then
			return
		end
		GameService:RemoveFromRestartList(player)
		GameService:RemoveFromReadyList(player)

		task.spawn(function()
			local success, result = SafeTeleport(GameSettings.LobbyPlaceId, { player })
			if not success then
				warn("Teleport failed:", result)
			end
		end)
	end)
end

return GameService
