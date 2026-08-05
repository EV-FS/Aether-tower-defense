local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Topbarplus = require(ReplicatedStorage.Packages.Topbarplus)
local Vide = require(ReplicatedStorage.Packages.Vide)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local EmojiData = require(ReplicatedStorage.Settings.Data.EmojiData)
local EmojiWheel = require(ReplicatedStorage.UI.Components.EmojiWheel)
local ModalOverlay = require(ReplicatedStorage.UI.Components.ModalOverlay)
local EmojiClient
local InputController
local UIController

local create = Vide.create
local source = Vide.source

local VIEW_ID = "EmojiWheel"

local EmojiInput

-------------------------------------------------
--// Local Functions
-------------------------------------------------
local function getEmojiSlotData(index: number)
	local config = EmojiData.ByIndex[index]
	if not config then
		return nil
	end

	return {
		Id = config.Id,
		DisplayName = config.DisplayName,
		Image = config.Image,
	}
end

local emojiSlots = {
	Emoji1 = source(getEmojiSlotData(1)),
	Emoji2 = source(),
	Emoji3 = source(),
	Emoji4 = source(),
}

-------------------------------------------------
--// EmojiUI
-------------------------------------------------
local EmojiUI = {}

function EmojiUI.OnSelected(emojiId: string)
	if EmojiClient then
		EmojiClient.ShowEmoji(emojiId)
	end

	UIController:Close(VIEW_ID)
end

function EmojiUI.RenderUI()
	return create("Frame")({
		Name = "EmojiUI",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),

		ModalOverlay({
			Name = "EmojiOverlay",
			Title = "Emoji Wheel",
			IsOpen = UIController:IsVisible(VIEW_ID),
			OnClose = function()
				UIController:Close(VIEW_ID)
			end,
			Content = EmojiWheel({
				Emoji1 = emojiSlots.Emoji1,
				Emoji2 = emojiSlots.Emoji2,
				Emoji3 = emojiSlots.Emoji3,
				Emoji4 = emojiSlots.Emoji4,
				OnSelected = EmojiUI.OnSelected,
			}),
		}),
	})
end

function EmojiUI.Init()
	EmojiClient = ServiceRegistry:GetService("EmojiClient")
	InputController = ServiceRegistry:GetService("InputController")
	UIController = ServiceRegistry:GetService("UIController")
end

function EmojiUI.Start()
	local iScope = InputController.Scope
	local iAction = InputController.Action
	local iInfo = InputController.Info

	EmojiInput = iScope("EmojiInput", {
		iAction("Toggle", iInfo({ Enum.KeyCode.B })),
	}):Enable()

	EmojiInput.Actions.Toggle.Began:Connect(function()
		UIController:Toggle(VIEW_ID)
	end)

	if UserInputService.TouchEnabled then
		local icon = Topbarplus.new()
		icon:setLabel("Emoji")
		icon:oneClick(true)
		icon:align("Left")

		icon:bindEvent("deselected", function()
			UIController:Toggle(VIEW_ID)
		end)
	end
end

return EmojiUI
