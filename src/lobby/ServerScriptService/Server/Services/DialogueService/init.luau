-- src/lobby/ServerScriptService/Server/Services/DialogueService/init.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- lobby 프로젝트 구조에 맞게 경로 수정
local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local NpcDialogueData = require(ReplicatedStorage:WaitForChild("Settings"):WaitForChild("Data"):WaitForChild("NpcDialogueData"))

local DialogueService = {}

local playerDialogueStates = {}

function DialogueService.Start()
    -- ServiceRegistry compatibility
end

function DialogueService.StartDialogue(player, npcId)
    playerDialogueStates[player.UserId] = {
        NpcId = npcId,
        CurrentDialogueId = "Start"
    }
    Net.DialogueService.StartDialogue.Fire(player, npcId)
end

function DialogueService.HandleChoice(player, data)
    local state = playerDialogueStates[player.UserId]
    if not state or state.NpcId ~= data.NpcId then return end
    
    local npcData = NpcDialogueData[data.NpcId]
    local currentDialogue = npcData.DialogueTree[state.CurrentDialogueId]
    local choice = currentDialogue.Choices[data.ChoiceIndex]
    
    if choice then
        if choice.Next == "End" then
            playerDialogueStates[player.UserId] = nil
            Net.DialogueService.CloseDialogue.Fire(player)
            return
        end
        
        state.CurrentDialogueId = choice.Next
        Net.DialogueService.UpdateDialogueUI.Fire(player, {
            NpcId = data.NpcId,
            DialogueId = state.CurrentDialogueId
        })
    end
end

-- 올바른 Blink 서버 이벤트 리스너 연결 방식
Net.DialogueService.ChooseDialogue.On(function(player, data)
    DialogueService.HandleChoice(player, data)
end)

return DialogueService
