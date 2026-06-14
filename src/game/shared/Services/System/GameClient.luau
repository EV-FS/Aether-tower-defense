--/Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

--/Modules
local ClientSignals = require(StarterPlayer.StarterPlayerScripts.Client.ClientSignals)
local Net = require(ReplicatedStorage.Shared.Net)
local Promise = require(ReplicatedStorage.Packages.Promise)
local GetPath = require(ReplicatedStorage.Shared.Modules.Core.GetPath)

-------------------------------------------------
--// Tower Reward Calculator
-------------------------------------------------
local TowerRewardCalculator = {}
TowerRewardCalculator.Snapshot = {}

function TowerRewardCalculator.GetCumulativeExp(level: number, exp: number): number
	return exp + 50 * level * (level + 1)
end

function TowerRewardCalculator.FetchTowersAsync()
	return Promise.all({
		Net.DataService.GetDataValue.Invoke("Loadout"),
		Net.DataService.GetDataValue.Invoke("OwnedTowers"),
	}):andThen(function(results)
		local towers = {}
		local loadout = results[1]
		local ownedTowers = results[2]

		if not loadout or not ownedTowers then
			return towers
		end

		for _, slot in pairs(loadout) do
			if slot and slot.Name and slot.Key then
				local towerData = ownedTowers[slot.Name] and ownedTowers[slot.Name][slot.Key]
				if towerData then
					towers[slot.Key] = {
						Name = slot.Name,
						Lv = towerData.Lv,
						Exp = towerData.Exp,
					}
				end
			end
		end

		return towers
	end)
end

function TowerRewardCalculator.TakeSnapshot()
	TowerRewardCalculator.FetchTowersAsync():andThen(function(towers)
		TowerRewardCalculator.Snapshot = towers
	end)
end

function TowerRewardCalculator.CalculateGainedTowersAsync()
	return TowerRewardCalculator.FetchTowersAsync():andThen(function(currentTowers)
		local gainedTowers = {}
		for key, currentStats in currentTowers do
			local snap = TowerRewardCalculator.Snapshot[key]
			if snap then
				local startCumulative = TowerRewardCalculator.GetCumulativeExp(snap.Lv, snap.Exp)
				local endCumulative = TowerRewardCalculator.GetCumulativeExp(currentStats.Lv, currentStats.Exp)

				local percentBefore = math.floor((snap.Exp / (100 * (snap.Lv + 1))) * 100)
				local percentAfter = math.floor((currentStats.Exp / (100 * (currentStats.Lv + 1))) * 100)

				table.insert(gainedTowers, {
					name = currentStats.Name,
					gainedExp = endCumulative - startCumulative,
					levelBefore = snap.Lv,
					levelAfter = currentStats.Lv,
					percentBefore = percentBefore,
					percentAfter = percentAfter,
				})
			end
		end

		TowerRewardCalculator.Snapshot = currentTowers

		return gainedTowers
	end)
end

-------------------------------------------------
--// GameClient
-------------------------------------------------
local GameClient = {}
GameClient.SelectedDifficulty = "Normal"
GameClient.StartPlayerCount = 1
GameClient.IsGameStarted = false

function GameClient.UpdateGameInfo(data: { Difficulty: string, StartPlayerCount: number })
	GameClient.SelectedDifficulty = data.Difficulty
	GameClient.StartPlayerCount = data.StartPlayerCount
end

function GameClient.Start()
	TowerRewardCalculator.TakeSnapshot()

	Net.GameEvent.GetGameInfo.Invoke():andThen(GameClient.UpdateGameInfo):catch(function(err)
		warn("[GameClient] Failed to fetch initial GameInfo:", err)
	end)

	Net.GameEvent.GameInfoSynced.On(GameClient.UpdateGameInfo)

	-- Start path guidance arrows during preparation stage
	task.spawn(function()
		GetPath:StartGuide()
	end)

	Net.GameEvent.WaveStarted.On(function(waveNumber: number)
		ClientSignals.WaveStarted:Fire(waveNumber)
		GetPath:StopGuide()
	end)

	Net.GameEvent.WaveCompleted.On(function()
		ClientSignals.WaveCompleted:Fire()
	end)

	Net.GameEvent.GameOver.On(function(data: { coins: number, exp: number, gems: number, isWin: boolean })
		TowerRewardCalculator.CalculateGainedTowersAsync():andThen(function(gainedTowers)
			ClientSignals.GameOver:Fire(data.isWin, data.coins, data.exp, data.gems, gainedTowers)
		end)
	end)
	Net.GameEvent.Restarted.On(function()
		ClientSignals.Restarted:Fire()
		GetPath:StartGuide()
	end)

	Net.GameEvent.ReadyVoted.On(function(votedNumber: number)
		ClientSignals.ReadyVoted:Fire(votedNumber)
	end)
	Net.GameEvent.RestartVoted.On(function(votedNumber: number)
		ClientSignals.RestartVoted:Fire(votedNumber)
	end)
	Net.GameEvent.SkipVoted.On(function(votedNumber: number)
		ClientSignals.SkipVoted:Fire(votedNumber)
	end)

	Net.GameEvent.CanSkip.On(function()
		ClientSignals.CanSkip:Fire()
	end)
end

return GameClient
