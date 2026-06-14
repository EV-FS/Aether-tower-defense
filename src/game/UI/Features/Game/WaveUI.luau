--/Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

--/Modules
local ClientSignals = require(StarterPlayer.StarterPlayerScripts.Client.ClientSignals)
local Vide = require(ReplicatedStorage.Packages.Vide)
local GameSettings = require(ReplicatedStorage.Settings.Game.GameSettings)
local MapData = require(ReplicatedStorage.Settings.Data.MapData)
local NumberUtils = require(ReplicatedStorage.Shared.Modules.Utils.NumberUtils)
local TimeService = require(ReplicatedStorage.Shared.Services.System.TimeService)

local source = Vide.source

local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local Interface = PlayerGui:WaitForChild("Interface")
local InfoFrame = Interface:WaitForChild("Info")

--/UI Variables
local currentWave = source(0)
local maxWaves = source(0)
local timerSeconds = source(GameSettings.WaveDuration)
local timerVisible = source(true)

local countdownTask = nil

-------------------------------------------------
--// Local Functions
-------------------------------------------------
local function getWaves(mapName: string?, difficultyName: string?): number
	local map = mapName or "Chapter 1"
	local mapData = MapData[map]
	if not mapData then
		return 0
	end
	local difficulty = difficultyName or "Normal"
	return (mapData.DifficultyWaves and mapData.DifficultyWaves[difficulty]) or 0
end

local function stopCountdown()
	if countdownTask then
		task.cancel(countdownTask)
		countdownTask = nil
	end
end

local function startCountdown()
	stopCountdown()

	timerVisible(currentWave() < maxWaves())
	timerSeconds(GameSettings.WaveDuration)

	if currentWave() >= maxWaves() then
		return
	end

	countdownTask = task.spawn(function()
		while true do
			TimeService.DeltaWait(1)

			timerSeconds(timerSeconds() - 1)
			if timerSeconds() <= 0 then
				break
			end
		end
	end)
end

-------------------------------------------------
--// WaveUI
-------------------------------------------------
local WaveUI = {}

function WaveUI.HydrateUI()
	local TimerLabel = InfoFrame:WaitForChild("Timer")
	local WaveLabel = InfoFrame:WaitForChild("Wave")

	Vide.apply(WaveLabel)({
		Text = function()
			return `Wave: {currentWave()}/{maxWaves()}`
		end,
	})

	Vide.apply(TimerLabel)({
		Text = function()
			return NumberUtils.FormatTime(timerSeconds())
		end,
		Visible = timerVisible,
	})
end

function WaveUI.Init()
	Vide.mount(function()
		WaveUI.HydrateUI()
	end)

	task.spawn(function()
		local mapFolder = workspace:WaitForChild("Map")
		local function updateMaxWaves()
			local selectedMap = mapFolder:GetAttribute("SelectedMap") or "Chapter 1"
			local selectedDifficulty = mapFolder:GetAttribute("SelectedDifficulty") or "Normal"
			maxWaves(getWaves(selectedMap, selectedDifficulty))
		end

		updateMaxWaves()
		mapFolder:GetAttributeChangedSignal("SelectedMap"):Connect(updateMaxWaves)
		mapFolder:GetAttributeChangedSignal("SelectedDifficulty"):Connect(updateMaxWaves)
	end)
end

function WaveUI.Start()
	ClientSignals.GameOver:Connect(function()
		stopCountdown()
	end)

	ClientSignals.WaveStarted:Connect(function(waveNum: number)
		currentWave(waveNum)
		startCountdown()
	end)

	ClientSignals.Restarted:Connect(function()
		currentWave(0)
		stopCountdown()
		timerSeconds(GameSettings.WaveDuration)
		timerVisible(true)
	end)
end

return WaveUI
