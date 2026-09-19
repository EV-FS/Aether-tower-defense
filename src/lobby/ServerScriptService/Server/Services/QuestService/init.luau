local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local QuestData = require(ReplicatedStorage.Settings.Data.QuestData)

local DataService
local NotificationService

local QuestService = {}

function QuestService.GetPlayerQuests(player: Player)
	if not DataService then
		return {}
	end
	local playerData = DataService:GetData(player)
	if not playerData then
		return {}
	end
	return playerData.Quests or {}
end

function QuestService.AcceptQuest(player: Player, questId: string): boolean
	local config = QuestData[questId]
	if not config or not DataService then
		return false
	end

	local playerData = DataService:GetData(player)
	if not playerData then
		return false
	end

	if not playerData.Quests then
		playerData.Quests = {}
	end

	local currentQuest = playerData.Quests[questId]
	if currentQuest and (currentQuest.Active or currentQuest.Claimed) then
		return false
	end

	local initialProgress = 0
	if config.TargetCurrency and playerData[config.TargetCurrency] then
		initialProgress = math.min(playerData[config.TargetCurrency], config.TargetAmount)
	end

	local questState = {
		Active = true,
		Progress = initialProgress,
		Target = config.TargetAmount,
		Completed = initialProgress >= config.TargetAmount,
		Claimed = false,
	}

	DataService:UpdateData(player, "Quests", questState, questId)
	return true
end

function QuestService.ClaimQuest(player: Player, questId: string): boolean
	local config = QuestData[questId]
	if not config or not DataService then
		return false
	end

	local playerData = DataService:GetData(player)
	if not playerData or not playerData.Quests or not playerData.Quests[questId] then
		return false
	end

	local quest = playerData.Quests[questId]
	if not quest.Completed or quest.Claimed then
		return false
	end

	quest.Claimed = true
	quest.Active = false
	DataService:UpdateData(player, "Quests", quest, questId)

	-- 보상 지급
	if config.Rewards.Coins and config.Rewards.Coins > 0 then
		DataService:AddData(player, "Coins", config.Rewards.Coins)
	end
	if config.Rewards.Gems and config.Rewards.Gems > 0 then
		DataService:AddData(player, "Gems", config.Rewards.Gems)
	end
	if config.Rewards.Exp and config.Rewards.Exp > 0 then
		DataService:AddData(player, "Exp", config.Rewards.Exp)
	end

	return true
end

function QuestService.UpdateProgress(player: Player, currencyName: string, amount: number)
	if not DataService then
		return
	end
	local playerData = DataService:GetData(player)
	if not playerData or not playerData.Quests then
		return
	end

	for questId, quest in pairs(playerData.Quests) do
		local config = QuestData[questId]
		if config and config.TargetCurrency == currencyName and quest.Active and not quest.Claimed then
			local newProgress = math.min(amount, config.TargetAmount)
			local completed = newProgress >= config.TargetAmount
			if quest.Progress ~= newProgress or quest.Completed ~= completed then
				quest.Progress = newProgress
				quest.Completed = completed
				DataService:UpdateData(player, "Quests", quest, questId)
			end
		end
	end
end

function QuestService.Init(services)
	DataService = services:GetService("DataService")
	NotificationService = services:GetService("NotificationService")
end

function QuestService.Start()
	if DataService then
		DataService:GetChangedSignal("Blossom"):Connect(function(player, value)
			QuestService.UpdateProgress(player, "Blossom", value)
		end)

		local function acceptStarterQuests(player: Player)
			for questId, config in QuestData do
				if config.AutoAccept then
					QuestService.AcceptQuest(player, questId)
				end
			end
		end

		for _, player in Players:GetPlayers() do
			task.spawn(acceptStarterQuests, player)
		end
		Players.PlayerAdded:Connect(function(player)
			task.spawn(acceptStarterQuests, player)
		end)
	end
end

return QuestService
