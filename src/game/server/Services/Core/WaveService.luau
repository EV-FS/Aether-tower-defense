--/Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--/Modules
local Promise = require(ReplicatedStorage.Packages.Promise)
local Signal = require(ReplicatedStorage.Packages.Signal)
local EnemyService
local TimeService

--/Config
local WaveData = require(ReplicatedStorage.Settings.Data.WaveData)
local MapData = require(ReplicatedStorage.Settings.Data.MapData)
local GameSettings = require(ReplicatedStorage.Settings.Game.GameSettings)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)
local Net = require(ReplicatedStorage.Shared.Net)

--/Variables
local spawnEnded = false
local skipPromise

-------------------------------------------------
--// WaveService
-------------------------------------------------
local WaveService = {}
WaveService.CurrentWave = 0
WaveService.ActiveSpawns = {}
WaveService.AutoStartPromise = nil
WaveService.SelectedMap = nil
WaveService.SelectedDifficulty = "Normal"

WaveService.WaveCompleted = Signal.new()
WaveService.WaveStarted = Signal.new()
WaveService.CanSkip = Signal.new()
WaveService.AllWavesCompleted = Signal.new()

function WaveService.onEnemyDefeated()
	if TableUtils.Length(EnemyService.GetAll()) <= 0 and spawnEnded then
		if skipPromise then
			skipPromise:cancel()
		end

		WaveService.WaveCompleted:Fire(WaveService.CurrentWave)
		Net.GameEvent.WaveCompleted.FireAll(WaveService.CurrentWave)
	end
end

function WaveService:GetWaves(mapName: string?, difficultyName: string?): number
	local map = mapName or (WaveService and WaveService.SelectedMap)
	local mapData = MapData[map]
	if not mapData then
		warn(`선택 된 {map}에 데이터가 존재하지 않습니다.`)
		return 0
	end

	local targetDifficulty = difficultyName or (WaveService and WaveService.SelectedDifficulty) or "Normal"
	return (mapData.DifficultyWaves and mapData.DifficultyWaves[targetDifficulty]) or 0
end

function WaveService:PlayRound(chapter: string, difficulty: string)
	self.SelectedMap = chapter
	self.SelectedDifficulty = difficulty or "Normal"

	self:StartNextWave()
end

function WaveService:StartNextWave()
	local maxWaves = self:GetWaves()
	if self.CurrentWave + 1 > maxWaves then
		self.AllWavesCompleted:Fire()
		return
	end

	if skipPromise then
		skipPromise:cancel()
		skipPromise = nil
	end

	if self.AutoStartPromise then
		self.AutoStartPromise:cancel()
		self.AutoStartPromise = nil
	end

	self.CurrentWave += 1
	self.WaveStarted:Fire(self.CurrentWave)
	Net.GameEvent.WaveStarted.FireAll(self.CurrentWave)

	spawnEnded = false

	if self.CurrentWave < maxWaves then
		TimeService = TimeService or ServiceRegistry:GetService("TimeService")

		skipPromise = TimeService.DeltaDelay(GameSettings.SkipTime):andThen(function()
			self.CanSkip:Fire()
		end)
		self.AutoStartPromise = TimeService.DeltaDelay(GameSettings.WaveDuration):andThen(function()
			self:StartNextWave()
		end)
	end
	self:PlayWave(self.CurrentWave)
end

function WaveService:PlayWave()
	local chapterData = WaveData[self.SelectedMap]
	if not chapterData then
		return
	end

	local waveData = chapterData[self.CurrentWave]
	if not waveData then
		return
	end

	local spawnPromise
	spawnPromise = Promise.each(waveData, function(enemy)
		return EnemyService.Spawn(enemy.Name, enemy.Count, enemy.Delay, enemy.IsBoss)
	end)

	spawnPromise:andThen(function()
		local index = table.find(WaveService.ActiveSpawns, spawnPromise)
		if index then
			table.remove(WaveService.ActiveSpawns, index)
		end

		if #WaveService.ActiveSpawns == 0 then
			spawnEnded = true
		end
		WaveService.onEnemyDefeated()
	end)

	table.insert(WaveService.ActiveSpawns, spawnPromise)
end

function WaveService:Stop()
	for _, promise in ipairs(self.ActiveSpawns) do
		promise:cancel()
	end
	table.clear(self.ActiveSpawns)

	if skipPromise then
		skipPromise:cancel()
		skipPromise = nil
	end
	if self.AutoStartPromise then
		self.AutoStartPromise:cancel()
		self.AutoStartPromise = nil
	end

	self.CurrentWave = 0
	spawnEnded = false
end

function WaveService.Init(services)
	EnemyService = services:GetService("EnemyService")
end

function WaveService.Start()
	EnemyService.EnemyDefeated:Connect(WaveService.onEnemyDefeated)
end

return WaveService
