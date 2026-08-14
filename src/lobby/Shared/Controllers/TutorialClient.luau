local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)

local source = Vide.source

export type TutorialStep = {
	Target: string,
	Title: string,
	Description: string,
}

local STEPS: { TutorialStep } = {
	{
		Target = "InventoryButton",
		Title = "YOUR COLLECTION",
		Description = "Open your inventory to view, equip, and manage the units you own.",
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
local stepIndex = source(1)

local TutorialClient = {}

function TutorialClient:IsVisible(): () -> boolean
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
	stepIndex(1)
	isOpen(true)
end

function TutorialClient:Next()
	if stepIndex() >= #STEPS then
		isOpen(false)
		return
	end

	stepIndex(stepIndex() + 1)
end

function TutorialClient:Close()
	isOpen(false)
end

function TutorialClient.Init() end

function TutorialClient.Start() end

return TutorialClient
