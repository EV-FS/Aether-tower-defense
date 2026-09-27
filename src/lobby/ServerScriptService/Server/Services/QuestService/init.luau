local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QuestData = require(ReplicatedStorage.Settings.Data.QuestData)

local DataService

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
	local config = QuestData.Get(questId)
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
	if currentQuest and (currentQuest.Active or currentQuest.Completed or currentQuest.Claimed) then
		return false
	end

	local initialProgress = 0
	local objective = config.Entity.Objective
	if objective.Kind == "Currency" and playerData[objective.Target] then
		initialProgress = math.min(playerData[objective.Target], objective.Amount)
	elseif objective.Kind == "MapClear" then
		initialProgress = math.min(tonumber(playerData.MapClears and playerData.MapClears[objective.Target]) or 0, objective.Amount)
	end

	local questState = {
		Active = true,
		Progress = initialProgress,
		Target = config.TargetAmount,
		Completed = initialProgress >= config.TargetAmount,
		Claimed = false,
	}

	DataService:UpdateData(player, "Quests", questState, questId)
	if questState.Completed and config.Entity.Lifecycle.AutoClaim then
		QuestService.ClaimQuest(player, questId)
	end
	return true
end

function QuestService.ClaimQuest(player: Player, questId: string): boolean
	local config = QuestData.Get(questId)
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

	for rewardName, amount in config.Rewards do
		if type(amount) == "number" and amount > 0 then
			DataService:AddData(player, rewardName, amount)
		end
	end

	return true
end

function QuestService.SetObjectiveProgress(player: Player, objectiveKind: string, target: string, amount: number)
	if not DataService then
		return
	end
	local playerData = DataService:GetData(player)
	if not playerData or not playerData.Quests then
		return
	end

	for _, config in QuestData.QueryObjective(objectiveKind, target) do
		local questId = config.Id
		local quest = playerData.Quests[questId]
		if quest and quest.Active and not quest.Claimed then
			local newProgress = math.min(amount, config.Entity.Objective.Amount)
			if objectiveKind == "MapClear" then
				newProgress = math.max(tonumber(quest.Progress) or 0, newProgress)
			end
			local completed = newProgress >= config.TargetAmount
			if quest.Progress ~= newProgress or quest.Completed ~= completed then
				quest.Progress = newProgress
				quest.Completed = completed
				DataService:UpdateData(player, "Quests", quest, questId)
				if completed and config.Entity.Lifecycle.AutoClaim then
					QuestService.ClaimQuest(player, questId)
				end
			end
		end
	end
end

function QuestService.UpdateProgress(player: Player, currencyName: string, amount: number)
	QuestService.SetObjectiveProgress(player, "Currency", currencyName, amount)
end

function QuestService.Init(services)
	DataService = services:GetService("DataService")
end

function QuestService.Start()
	if DataService then
		local subscribedCurrencies = {}
		for _, config in QuestData.QueryObjective("Currency") do
			local currencyName = config.Entity.Objective.Target
			if not subscribedCurrencies[currencyName] then
				subscribedCurrencies[currencyName] = true
				local capturedCurrency = currencyName
				DataService:GetChangedSignal(capturedCurrency):Connect(function(player, value)
					QuestService.SetObjectiveProgress(player, "Currency", capturedCurrency, value)
				end)
			end
		end
		DataService:GetChangedSignal("MapClears"):Connect(function(player)
			local playerData = DataService:GetData(player)
			if not playerData then return end
			for _, config in QuestData.QueryObjective("MapClear") do
				local mapName = config.Entity.Objective.Target
				local clears = tonumber(playerData.MapClears and playerData.MapClears[mapName]) or 0
				QuestService.SetObjectiveProgress(player, "MapClear", mapName, clears)
			end
		end)

		local function acceptStarterQuests(player: Player)
			local playerData = DataService:GetData(player)
			if not playerData then return end
			-- Keep previously completed map quests valid when introducing MapClears to old profiles.
			for _, config in QuestData.QueryObjective("MapClear") do
				local quest = playerData.Quests and playerData.Quests[config.Id]
				local mapName = config.Entity.Objective.Target
				local clears = tonumber(playerData.MapClears and playerData.MapClears[mapName]) or 0
				if quest and (quest.Completed or quest.Claimed) and clears < config.TargetAmount then
					DataService:UpdateData(player, "MapClears", config.TargetAmount, mapName)
				end
			end
			for _, config in QuestData.QueryLifecycle("AutoAccept") do
				QuestService.AcceptQuest(player, config.Id)
			end
			for _, config in QuestData.QueryObjective("MapClear") do
				local mapName = config.Entity.Objective.Target
				local clears = tonumber(playerData.MapClears and playerData.MapClears[mapName]) or 0
				QuestService.SetObjectiveProgress(player, "MapClear", mapName, clears)
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
