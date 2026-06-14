--/Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

--/Modules
local ClientSignals = require(StarterPlayer.StarterPlayerScripts.Client.ClientSignals)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local NumberUtils = require(ReplicatedStorage.Shared.Modules.Utils.NumberUtils)
local Net = require(ReplicatedStorage.Shared.Net.client)
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)

local OnEvent = Fusion.OnEvent
local peek = Fusion.peek

local scope = Fusion.scoped(Fusion)

local clearVisible = scope:Value(false)
local isWin = scope:Value(false)
local coins = scope:Value(0)
local exp = scope:Value(0)
local gems = scope:Value(0)
local restartVoted = scope:Value(0)

local playerNumber = scope:Value(0)

local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local ClearFrame = PlayerGui:WaitForChild("Interface"):WaitForChild("GameClear")

-------------------------------------------------
--// Local Functions
-------------------------------------------------
local function clearTowerRewards()
	for _, child in pairs(ClearFrame.TowerExpGain:GetChildren()) do
		if child:IsA("Frame") and child.Name ~= "Template" then
			child:Destroy()
		end
	end
end

local function HydrateUI()
	scope:Hydrate(ClearFrame)({
		Visible = scope:Computed(function(use)
			return use(clearVisible)
		end),
	})

	scope:Hydrate(ClearFrame.Reward.RewardList.Coins)({
		Visible = scope:Computed(function(use)
			return if use(coins) > 0 then true else false
		end),
	})
	scope:Hydrate(ClearFrame.Reward.RewardList.Coins.Amount)({
		Text = scope:Computed(function(use)
			local coinsVal = use(coins)
			local gemsVal = use(gems)
			local formatted = `{NumberUtils.FormatComma(coinsVal)}C`
			if gemsVal > 0 then
				formatted ..= ` + {NumberUtils.FormatComma(gemsVal)} Gems`
			end
			return formatted
		end),
	})

	scope:Hydrate(ClearFrame.Reward.RewardList.Exp)({
		Visible = scope:Computed(function(use)
			return if use(exp) > 0 then true else false
		end),
	})
	scope:Hydrate(ClearFrame.Reward.RewardList.Exp.Amount)({
		Text = scope:Computed(function(use)
			return `{NumberUtils.FormatComma(use(exp))} Exp`
		end),
	})

	scope:Hydrate(ClearFrame.Title)({
		Text = scope:Computed(function(use)
			return if use(isWin) then "Victory" else "Defeat"
		end),
	})

	scope:Hydrate(ClearFrame.Replay)({
		[OnEvent("MouseButton1Click")] = function()
			Net.GameEvent.VoteRestart.Fire()
		end,
	})
	scope:Hydrate(ClearFrame.Replay.TextLabel)({
		Text = scope:Computed(function(use)
			return `Replay ({use(restartVoted)}/{math.floor(use(playerNumber) / 2) + 1})`
		end),
	})

	scope:Hydrate(ClearFrame.Lobby)({
		[OnEvent("MouseButton1Click")] = function()
			Net.GameEvent.TeleportToLobby.Fire()
		end,
	})
end

-------------------------------------------------
--// ResultUI
-------------------------------------------------
local ResultUI = {}

function ResultUI.Init()
	HydrateUI()
	playerNumber:set(#Players:GetPlayers())
end

function ResultUI.Start()
	ClientSignals.GameOver:Connect(
		function(isWinVal: boolean, coinsVal: number, expVal: number, gemsVal: number, towers: any)
			clearTowerRewards()
			clearVisible:set(true)
			isWin:set(isWinVal)
			coins:set(coinsVal)
			exp:set(expVal)
			gems:set(gemsVal or 0)

			for _, towerInfo in towers do
				local template = ClearFrame.TowerExpGain.Template:Clone()
				template.Name = towerInfo.name
				template.Visible = true

				template.TowerName.Text = towerInfo.name

				local towerConfig = TowerData.ByName[towerInfo.name]
				if towerConfig and towerConfig.TowerImage then
					template.TowerImage.Image = towerConfig.TowerImage
				end

				if towerInfo.levelAfter > towerInfo.levelBefore then
					template.Level.Text =
						`Lv.{towerInfo.levelBefore} → {towerInfo.levelAfter} ({towerInfo.percentBefore}% → {towerInfo.percentAfter}%)`
				else
					template.Level.Text =
						`Lv.{towerInfo.levelAfter} ({towerInfo.percentBefore}% → {towerInfo.percentAfter}%)`
				end

				template.ExpProgress.Progress.Size = UDim2.fromScale(towerInfo.percentAfter / 100, 1)

				template.Parent = ClearFrame.TowerExpGain
			end
		end
	)

	ClientSignals.Restarted:Connect(function()
		clearTowerRewards()
		clearVisible:set(false)
		restartVoted:set(0)
	end)
	ClientSignals.RestartVoted:Connect(function(currentVote: number)
		restartVoted:set(currentVote or peek(restartVoted) + 1)
	end)

	Players.PlayerAdded:Connect(function()
		playerNumber:set(peek(playerNumber) + 1)
	end)

	Players.PlayerRemoving:Connect(function()
		playerNumber:set(peek(playerNumber) - 1)
	end)
end

return ResultUI
