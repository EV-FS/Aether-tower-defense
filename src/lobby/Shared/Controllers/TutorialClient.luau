local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Vide = require(ReplicatedStorage.Packages.Vide)

local source = Vide.source
local COMPLETED_EVENT_NAME = "TutorialCompleted"

export type TutorialStep = {
	Target: string,
	Title: string,
	Description: string,
}

local STEPS: { TutorialStep } = {
	{
		Target = "UnitButton",
		Title = "YOUR COLLECTION",
		Description = "Open Units to view, equip, and manage the units you own.",
	},
	{
		Target = "ShopButton",
		Title = "THE SHOP",
		Description = "Visit the shop for useful items, limited offers, and everything you need for the road ahead.",
	},
	{
		Target = "TradeBUtton",
		Title = "TRADE WITH PLAYERS",
		Description = "Trade units and items with other players when you find something worth exchanging.",
	},
	{
		Target = "SettingButton",
		Title = "MAKE IT YOURS",
		Description = "Adjust your settings to make the game feel just right for you.",
	},
	{
		Target = "QuestButton",
		Title = "YOUR NEXT GOAL",
		Description = "Track quests here and claim rewards as you progress through the world.",
	},
	{
		Target = "IndexButton",
		Title = "DISCOVER MORE",
		Description = "The index keeps track of everything you have discovered — and what is still waiting for you.",
	},
}

local isOpen = source(false)
local isMounted = source(false)
local stepIndex = source(1)
local transitionToken = 0

local TutorialClient = {}

function TutorialClient:IsVisible(): () -> boolean
	return function()
		return isMounted()
	end
end

function TutorialClient:IsActive(): () -> boolean
	return function()
		return isOpen()
	end
end

function TutorialClient:GetCurrentStep(): TutorialStep
	return STEPS[stepIndex()]
end

function TutorialClient:GetStepIndex(): number
	return stepIndex()
end

function TutorialClient:GetStepCount(): number
	return #STEPS
end

function TutorialClient:StartTutorial()
	transitionToken += 1
	stepIndex(1)
	isMounted(true)
	isOpen(true)
end

function TutorialClient:Next()
	if stepIndex() >= #STEPS then
		self:Complete()
		return
	end

	stepIndex(stepIndex() + 1)
end

function TutorialClient:Complete()
	local event = ReplicatedStorage:FindFirstChild(COMPLETED_EVENT_NAME)
	if event and event:IsA("RemoteEvent") then
		event:FireServer()
	end
	self:Close()
end

function TutorialClient:Close()
	transitionToken += 1
	local token = transitionToken
	isOpen(false)
	task.delay(0.45, function()
		if transitionToken == token then
			isMounted(false)
		end
	end)
end

function TutorialClient.Init() end

function TutorialClient.Start()
	local command = TextChatService:FindFirstChild("TutorialCommand")
	if not command then
		command = Instance.new("TextChatCommand")
		command.Name = "TutorialCommand"
		command.PrimaryAlias = "!tutorial"
		command.Parent = TextChatService
	end

	if command:IsA("TextChatCommand") then
		command.Triggered:Connect(function(textSource)
			local player = game:GetService("Players").LocalPlayer
			if textSource.UserId == player.UserId then
				TutorialClient:StartTutorial()
			end
		end)
	end

	local Net = require(ReplicatedStorage.Shared.Net.client)
	Net.DataService.GetDataValue.Invoke("TutorialCompleted"):andThen(function(completed)
		if completed ~= true then
			TutorialClient:StartTutorial()
		end
	end):catch(function()
		-- If legacy data has no field yet, treat the player as new.
		TutorialClient:StartTutorial()
	end)
end

return TutorialClient
