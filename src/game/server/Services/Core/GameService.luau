--/Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

--/Modules

local Promise = require(ReplicatedStorage.Packages.Promise)
local GameSettings = require(ReplicatedStorage.Settings.Game.GameSettings)
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
GameService.IsMapLoading = false
GameService.IsMapLoaded = false

GameService.SelectedMap = nil
GameService.SelectedDifficulty = nil
GameService.StartPlayerCount = 1

function GameService:WaitForTeleportData()
	local function check()
		return Promise.new(function(resolve, reject)
			if self.SelectedMap ~= nil then
				resolve()
			else
				reject()
			end
		end)
	end
	return Promise.retryWithDelay(check, 300, 0.1)
end

function GameService:AllReady()
	local players = Players:GetPlayers()
	if #players == 0 then
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
	if self.IsMapLoaded then
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
		CharacterGuard.Release(mapFolder)
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
	if self.IsGameRunning then
		return
	end
	self.IsGameRunning = true

	self.StartPlayerCount = math.max(1, #Players:GetPlayers())
	Net.GameEvent.GameInfoSynced.FireAll({
		Difficulty = self.SelectedDifficulty or "Normal",
		StartPlayerCount = self.StartPlayerCount,
	})

	self:PrepareMap()
	if not self.IsMapLoaded then
		self.IsGameRunning = false
		return
	end

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

	for _, player in ipairs(Players:GetPlayers()) do
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

	local totalPlayers = #Players:GetPlayers()
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
	if self.IsGameRunning then
		return
	end

	if not self:AllReady() then
		return
	end

	table.clear(self.ReadyList)
	self:FireReadyState()
	self:StartGame()
end

function GameService:RestartGame()
	if self.IsGameRunning then
		return
	end

	local totalPlayers = #Players:GetPlayers()
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
	local function PlayerAdded(player: Player)
		local joinData = player:GetJoinData()
		local teleportData = joinData and joinData.TeleportData

		if teleportData and teleportData.Map and GameService.SelectedMap == nil then
			GameService.SelectedMap = teleportData.Map
		end

		if teleportData and teleportData.Difficulty and GameService.SelectedDifficulty == nil then
			GameService.SelectedDifficulty = teleportData.Difficulty
		end

		GameService:FireReadyState()
	end

	--/Player
	for _, player in ipairs(Players:GetPlayers()) do
		PlayerAdded(player)
	end
	Players.PlayerAdded:Connect(PlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
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

	--/Map
	task.defer(function()
		GameService:PrepareMap()
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
		if not GameService.IsGameRunning then
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
		if GameService.IsGameRunning then
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
		if GameService.IsGameRunning then
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
