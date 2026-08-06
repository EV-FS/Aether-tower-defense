--/Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Shared.Net.client)
local NpcDialogueData = require(ReplicatedStorage.Settings.Data.NpcDialogueData)
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

local CurrentNpcId

local function findDescendant(instance, name)
	if not instance then
		return nil
	end
	return instance:FindFirstChild(name, true)
end

local function getChoiceContainer(root)
	local container = root:FindFirstChild("DialogueChoiceFrame")
	if not container then
		container = root:FindFirstChild("Frame")
	end

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

	local textLabel = findDescendant(clone, "TextLabel")
	if textLabel and textLabel:IsA("TextLabel") then
		textLabel.Text = choice.Text or ""
	end

	local button = clone:FindFirstChild("Button", true)
	if button and button:IsA("TextButton") then
		button.MouseButton1Click:Connect(function()
			DialogueClient.ChooseDialogue(index)
		end)
	end
end

local currentDialogueCoroutine

local function animateText(textObject, fullText, typingSoundName)
	if currentDialogueCoroutine then
		coroutine.close(currentDialogueCoroutine)
	end

	currentDialogueCoroutine = coroutine.create(function()
		textObject.Text = ""
		
		-- Use utf8.codes to correctly handle multi-byte characters like Korean
		local chars = {}
		for _, char in utf8.codes(fullText) do
			table.insert(chars, utf8.char(char))
		end
		
		local sound = typingSoundName and SoundLibrary(typingSoundName)
		local soundId
		if sound and sound:IsA("Sound") then
			soundId = sound.SoundId
		elseif sound and typeof(sound) == "string" then
			soundId = sound
		end
		
		local currentText = ""
		for _, char in ipairs(chars) do
			currentText = currentText .. char
			textObject.Text = currentText

			if sound then
				print("Playing sound:", soundId)
				AudioController.PlayOn2D(soundId, 0.3)
			end

			-- Pause for punctuation
			if char == "." or char == "," or char == "!" or char == "?" then
				task.wait(0.3)
			else
				task.wait(0.05) -- Slightly slower speed for readability
			end
		end
	end)

	coroutine.resume(currentDialogueCoroutine)
end

local function openDialogue(npcId, dialogueId)
	if not dialogueGui then
		return
	end

	local npcData = NpcDialogueData[npcId]
	if not npcData then
		warn(`[DialogueClient] 대화 데이터를 찾을 수 없음: {npcId}`)
		return
	end

	local dialogue = npcData.DialogueTree[dialogueId]
	if not dialogue then
		warn(`[DialogueClient] 대화 노드를 찾을 수 없음: {npcId}.{dialogueId}`)
		return
	end

	CurrentNpcId = npcId
	setTextObject(nameText, npcData.Name or npcId)
	setTextObject(npcInfoText, npcId)

	-- Animate text instead of setting it immediately
	animateText(contextText, dialogue.Text or "", npcData.TypingSoundName)

	clearChoices()

	for index, choice in ipairs(dialogue.Choices or {}) do
		createChoiceClone(choice, index)
	end

	dialogueGui.Enabled = true
end

function DialogueClient.ChooseDialogue(choiceIndex)
	if not CurrentNpcId then
		return
	end

	Net.DialogueService.ChooseDialogue.Fire({
		NpcId = CurrentNpcId,
		ChoiceIndex = choiceIndex,
	})
end

function DialogueClient.Close()
	if dialogueGui then
		dialogueGui.Enabled = false
	end
	clearChoices()
	CurrentNpcId = nil
end

function DialogueClient.Init()
	local player = Players.LocalPlayer
	if not player then
		return
	end

	playerGui = player:WaitForChild("PlayerGui")
	dialogueGui = playerGui:WaitForChild("DialogueGui")

	dialogueFrame = findDescendant(dialogueGui, "DialogueFram")
	nameText = findDescendant(dialogueFrame, "NameText")
	npcInfoText = findDescendant(dialogueFrame, "NpcInfoText")
	contextText = findDescendant(dialogueFrame, "Context")

	choiceContainer = getChoiceContainer(dialogueGui)
	choiceTemplate = choiceContainer and choiceContainer:FindFirstChild("Template")

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

		openDialogue(data.NpcId, data.DialogueId)
	end)

	Net.DialogueService.CloseDialogue.On(function()
		DialogueClient.Close()
	end)
end

return DialogueClient
