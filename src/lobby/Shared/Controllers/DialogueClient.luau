-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Shared.Net.client)
local NpcDialogueData = require(ReplicatedStorage.Settings.Data.NpcDialogueData)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local AudioController = require(script.Parent.AudioController)
local SoundLibrary = require(ReplicatedStorage.Settings.Data.NPCS.Sounds.SoundLibrary)

local DialogueClient = {}

local playerGui
local dialogueGui
local choiceContainer
local choiceTemplate
local dialogueFrame
local nameText
local npcInfoText
local contextText
local fastButton

local originalPosition
local originalChoicePosition

local CurrentNpcId
local CurrentDialogueId
local _suppressClose = false
local _pendingClose = false
local _suppressNextServerTweenFor = nil
local _ignoreTutorialServerUpdate = false

local _skipRequested = false

local function findDescendant(instance, name)
    if not instance then
        return nil
    end
    return instance:FindFirstChild(name, true)
end

local function getChoiceContainer(root)
    if not root then
        return nil
    end

    local container = root:FindFirstChild("DialogueChoiceFrame") or root:FindFirstChild("Frame")
    if container and container:IsA("Frame") then
        return container
    end

    for _, child in ipairs(root:GetChildren()) do
        if child:IsA("Frame") and (child.Name == "DialogueChoiceFrame" or child.Name == "Frame") then
            return child
        end
    end

    return nil
end

local function clearChoices()
    if not choiceContainer or not choiceTemplate then
        return
    end

    for _, child in ipairs(choiceContainer:GetChildren()) do
        if child ~= choiceTemplate and child.Name:match("^ChoiceClone") then
            child:Destroy()
        end
    end
end

local function setTextObject(textObject, value)
    if textObject and textObject:IsA("TextLabel") then
        textObject.Text = value or ""
    end
end

local function createChoiceClone(choice, index)
    if not choiceTemplate or not choiceContainer then
        return
    end

    local clone = choiceTemplate:Clone()
    clone.Name = "ChoiceClone" .. tostring(index)
    clone.Visible = true
    clone.Parent = choiceContainer

    local textLabel
    for _, desc in ipairs(clone:GetDescendants()) do
        if desc:IsA("TextLabel") then
            textLabel = desc
            break
        end
    end
    if textLabel then
        textLabel.Text = choice.Text or ""
    else
        warn("[DialogueClient] createChoiceClone: no TextLabel found in template")
    end

    local button
    for _, desc in ipairs(clone:GetDescendants()) do
        if desc:IsA("TextButton") then
            button = desc
            break
        end
    end
    if button then
        button.MouseButton1Click:Connect(function()
            DialogueClient.ChooseDialogue(index)
        end)
    else
        warn("[DialogueClient] createChoiceClone: no TextButton found in template")
    end

    print(string.format("[DialogueClient] createChoiceClone: created choice %d text='%s'", index, tostring(choice.Text)))
end

local currentDialogueCoroutine

local function animateText(textObject, fullText, typingSoundName, onChoicesTriggered, onComplete)
    if currentDialogueCoroutine then
        coroutine.close(currentDialogueCoroutine)
    end

    _skipRequested = false

    currentDialogueCoroutine = coroutine.create(function()
        textObject.Text = fullText
        textObject.MaxVisibleGraphemes = 0

        local sound = typingSoundName and pcall(function() return SoundLibrary(typingSoundName) end) and SoundLibrary(typingSoundName) or nil
        local soundId
        if sound and typeof(sound) == "Instance" and sound:IsA("Sound") then
            soundId = sound.SoundId
        elseif sound and typeof(sound) == "string" then
            soundId = sound
        end

        local utf8Len = utf8.len(fullText) or #fullText
        local triggerIndex = math.max(1, math.floor(utf8Len * 0.3))
        local choicesTriggered = false

        local i = 1
        while i <= utf8Len do
            textObject.MaxVisibleGraphemes = i

            if not _skipRequested and soundId then
                AudioController.PlayOn2D(soundId, 0.3)
            end

            if not choicesTriggered and i >= triggerIndex then
                choicesTriggered = true
                if onChoicesTriggered then pcall(onChoicesTriggered) end
            end

            local startByte = utf8.offset(fullText, i)
            local nextByte = utf8.offset(fullText, i + 1)
            local char
            if startByte then
                if nextByte then
                    char = string.sub(fullText, startByte, nextByte - 1)
                else
                    char = string.sub(fullText, startByte, #fullText)
                end
            else
                char = ""
            end

            local typingSpeed
            if _skipRequested then
                typingSpeed = 0.01
            else
                if char == "." or char == "," or char == "!" or char == "?" then
                    typingSpeed = 0.3
                else
                    typingSpeed = 0.05
                end
            end

            task.wait(typingSpeed)
            i += 1
        end

        if type(onComplete) == "function" then
            pcall(onComplete)
        end
    end)

    coroutine.resume(currentDialogueCoroutine)
end

local function openDialogue(npcId, dialogueId, skipSlide)
    if not dialogueGui or not dialogueFrame then
        return
    end

    local npcData = NpcDialogueData[npcId]
    if not npcData then
        warn(string.format("[DialogueClient] 대화 데이터를 찾을 수 없음: %s", tostring(npcId)))
        return
    end

    local dialogue = npcData.DialogueTree[dialogueId]
    if not dialogue then
        warn(string.format("[DialogueClient] 대화 노드를 찾을 수 없음: %s.%s", tostring(npcId), tostring(dialogueId)))
        return
    end

    CurrentNpcId = npcId
    CurrentDialogueId = dialogueId
    setTextObject(nameText, npcData.Name or npcId)
    setTextObject(npcInfoText, npcId)

    clearChoices()

    if choiceContainer then
        choiceContainer.Visible = false
        originalChoicePosition = choiceContainer.Position
    end

    if not dialogue.Choices or #dialogue.Choices == 0 then
        DialogueClient.Close()
        return
    end

    if dialogueGui then
        dialogueGui.Enabled = true
    end
    if not skipSlide then
        local offScreenPosition = originalPosition + UDim2.new(0, 0, 0.5, 0)
        dialogueFrame.Position = offScreenPosition
        dialogueFrame:TweenPosition(originalPosition, Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.3, true)
    end

    _suppressClose = true
    _pendingClose = false
    animateText(contextText, dialogue.Text or "", npcData.TypingSoundName,
        function()
            for index, choice in ipairs(dialogue.Choices) do
                createChoiceClone(choice, index)
            end
            if choiceContainer then
                choiceContainer.Visible = true
                choiceContainer.Position = originalChoicePosition + UDim2.new(0, 0, 0.1, 0)
                choiceContainer:TweenPosition(originalChoicePosition, Enum.EasingDirection.Out, Enum.EasingStyle.Back, 0.4, true)
            end
        end,
        function()
            _suppressClose = false
            if _pendingClose then
                _pendingClose = false
                DialogueClient.Close()
            end
        end
    )
end

function DialogueClient.ChooseDialogue(choiceIndex)
    if not CurrentNpcId then
        return
    end
    local npcData = NpcDialogueData[CurrentNpcId]
    local nextId
    if npcData and CurrentDialogueId then
        local current = npcData.DialogueTree[CurrentDialogueId]
        if current and current.Choices and current.Choices[choiceIndex] then
            nextId = current.Choices[choiceIndex].Next
        end
    end

    Net.DialogueService.ChooseDialogue.Fire({
        NpcId = CurrentNpcId,
        ChoiceIndex = choiceIndex,
    })

    if CurrentNpcId == "Aether" and nextId == "StartTutorial" then
        _ignoreTutorialServerUpdate = true
        ServiceRegistry:GetService("TutorialClient"):StartTutorial()
        DialogueClient.Close()
        return
    end

    if nextId then
        _suppressNextServerTweenFor = nextId
        openDialogue(CurrentNpcId, nextId, true)
    end
end

function DialogueClient.SkipTyping()
    if _suppressClose then
        _skipRequested = true
    end
end

function DialogueClient.Close()
    if not dialogueGui or not dialogueFrame then
        return
    end

    local offScreenPosition = originalPosition + UDim2.new(0, 0, 0.5, 0)
    dialogueFrame:TweenPosition(offScreenPosition, Enum.EasingDirection.In, Enum.EasingStyle.Quad, 0.3, true, function()
        dialogueGui.Enabled = false
    end)

    clearChoices()
    CurrentNpcId = nil

    _suppressClose = false
    _pendingClose = false
    _skipRequested = false
end

function DialogueClient.Init()
    local player = Players.LocalPlayer
    if not player then
        return
    end

    playerGui = player:WaitForChild("PlayerGui")
    dialogueGui = playerGui:WaitForChild("DialogueGui")

    dialogueFrame = findDescendant(dialogueGui, "DialogueFram")
    originalPosition = dialogueFrame and dialogueFrame.Position or UDim2.new(0.5, 0, 0.5, 0)

    nameText = findDescendant(dialogueFrame, "NameText")
    npcInfoText = findDescendant(dialogueFrame, "NpcInfoText")
    contextText = findDescendant(dialogueFrame, "Context")

    choiceContainer = getChoiceContainer(dialogueGui)
    choiceTemplate = choiceContainer and choiceContainer:FindFirstChild("Template")

    fastButton = findDescendant(dialogueFrame, "FastButton")
    if fastButton and fastButton:IsA("GuiButton") then
        fastButton.MouseButton1Click:Connect(function()
            DialogueClient.SkipTyping()
        end)
    end

    if dialogueGui then
        dialogueGui.Enabled = false
    end
end

function DialogueClient.Start()
    if not RunService:IsClient() then
        return
    end

    Net.DialogueService.StartDialogue.On(function(npcId)
        openDialogue(npcId, "Start")
    end)

    Net.DialogueService.UpdateDialogueUI.On(function(data)
        if typeof(data) ~= "table" then
            return
        end
        if not data.NpcId or not data.DialogueId then
            return
        end
        if _ignoreTutorialServerUpdate and data.NpcId == "Aether" and data.DialogueId == "StartTutorial" then
            _ignoreTutorialServerUpdate = false
            return
        end
        if _suppressNextServerTweenFor and data.DialogueId == _suppressNextServerTweenFor then
            _suppressNextServerTweenFor = nil
            openDialogue(data.NpcId, data.DialogueId, true)
            return
        end
        openDialogue(data.NpcId, data.DialogueId)
    end)

    Net.DialogueService.CloseDialogue.On(function()
        if _suppressClose then
            _pendingClose = true
            return
        end
        DialogueClient.Close()
    end)
end

return DialogueClient
