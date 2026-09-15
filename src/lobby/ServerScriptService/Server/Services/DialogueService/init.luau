local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local NpcDialogueData = require(ReplicatedStorage:WaitForChild("Settings"):WaitForChild("Data"):WaitForChild("NpcDialogueData"))
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)

local DialogueService = {}
local QuestService
local DataService

local playerDialogueStates = {}

function DialogueService.Init(services)
	QuestService = services:GetService("QuestService")
	DataService = services:GetService("DataService")
end

function DialogueService.Start()
	-- ServiceRegistry compatibility
end

function DialogueService.StartDialogue(player, npcId)
	playerDialogueStates[player.UserId] = {
		NpcId = npcId,
		CurrentDialogueId = "Start",
	}
	Net.DialogueService.StartDialogue.Fire(player, npcId)
end

function DialogueService.HandleChoice(player, data)
	local state = playerDialogueStates[player.UserId]
	if not state or state.NpcId ~= data.NpcId then
		return
	end

	local npcData = NpcDialogueData[data.NpcId]
	if not npcData then
		return
	end

	local currentDialogue = npcData.DialogueTree[state.CurrentDialogueId]
	if not currentDialogue or not currentDialogue.Choices then
		return
	end

	local choice = currentDialogue.Choices[data.ChoiceIndex]
	if not choice then
		return
	end

	if choice.Next == "End" then
		playerDialogueStates[player.UserId] = nil
		Net.DialogueService.CloseDialogue.Fire(player)
		return
	end

	local nextId = choice.Next

	-- WanderingMerchant 퀘스트 분기 동적 처리
	if data.NpcId == "WanderingMerchant" then
		if nextId == "Quest_Check" and QuestService and DataService then
			local playerData = DataService:GetData(player)
			local quests = playerData and playerData.Quests or {}
			local quest = quests["BlossomCollector"]

			if not quest or (not quest.Active and not quest.Claimed) then
				nextId = "Quest_Check"
			elseif quest.Active and not quest.Completed then
				nextId = "Quest_Progress"
			elseif quest.Active and quest.Completed and not quest.Claimed then
				nextId = "Quest_Ready"
			elseif quest.Claimed then
				nextId = "Quest_AlreadyDone"
			end
		elseif nextId == "Quest_Accepted" and QuestService then
			QuestService.AcceptQuest(player, "BlossomCollector")
		elseif nextId == "Quest_Completed" and QuestService then
			QuestService.ClaimQuest(player, "BlossomCollector")
		end
	end

	state.CurrentDialogueId = nextId
	Net.DialogueService.UpdateDialogueUI.Fire(player, {
		NpcId = data.NpcId,
		DialogueId = state.CurrentDialogueId,
	})
end

Net.DialogueService.ChooseDialogue.On(function(player, data)
	DialogueService.HandleChoice(player, data)
end)

return DialogueService
