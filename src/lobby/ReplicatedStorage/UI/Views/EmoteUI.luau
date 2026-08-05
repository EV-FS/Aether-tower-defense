local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Topbarplus = require(ReplicatedStorage.Packages.Topbarplus)
local Vide = require(ReplicatedStorage.Packages.Vide)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local EmoteData = require(ReplicatedStorage.Settings.Data.EmoteData)
local EmoteWheel = require(ReplicatedStorage.UI.Components.EmoteWheel)
local ModalOverlay = require(ReplicatedStorage.UI.Components.ModalOverlay)
local EmoteClient
local InputController
local UIController

local create = Vide.create
local source = Vide.source

local VIEW_ID = "EmoteWheel"
local EmoteInput

local function getEmoteSlotData(index: number)
	local config = EmoteData.ByIndex[index]
	if not config then
		return nil
	end

	return {
		Id = config.Name,
		EmoteName = config.Name,
		DisplayName = config.DisplayName or config.Name,
		AnimationId = config.AnimationId,
	}
end

local emoteSlots = {
	Emote1 = source(getEmoteSlotData(1)),
	Emote2 = source(getEmoteSlotData(2)),
	Emote3 = source(getEmoteSlotData(3)),
	Emote4 = source(getEmoteSlotData(4)),
}

local EmoteUI = {}

function EmoteUI.OnSelected(emoteName: string)
	if EmoteClient then
		EmoteClient.PlayEmote(emoteName)
	end

	UIController:Close(VIEW_ID)
end

function EmoteUI.RenderUI()
	return create("Frame")({
		Name = "EmoteUI",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),

		ModalOverlay({
			Name = "EmoteOverlay",
			Title = "Emote Wheel",
			IsOpen = UIController:IsVisible(VIEW_ID),
			OnClose = function()
				UIController:Close(VIEW_ID)
			end,
			Content = EmoteWheel({
				Emote1 = emoteSlots.Emote1,
				Emote2 = emoteSlots.Emote2,
				Emote3 = emoteSlots.Emote3,
				Emote4 = emoteSlots.Emote4,
				OnSelected = EmoteUI.OnSelected,
			}),
		}),
	})
end

function EmoteUI.Init()
	EmoteClient = ServiceRegistry:GetService("EmoteClient")
	InputController = ServiceRegistry:GetService("InputController")
	UIController = ServiceRegistry:GetService("UIController")
end

function EmoteUI.Start()
	local iScope = InputController.Scope
	local iAction = InputController.Action
	local iInfo = InputController.Info

	EmoteInput = iScope("EmoteInput", {
		iAction("Toggle", iInfo({ Enum.KeyCode.G })),
	}):Enable()

	EmoteInput.Actions.Toggle.Began:Connect(function()
		UIController:Toggle(VIEW_ID)
	end)

	if UserInputService.TouchEnabled then
		local icon = Topbarplus.new()
		icon:setLabel("Emote")
		icon:oneClick(true)
		icon:align("Left")

		icon:bindEvent("deselected", function()
			UIController:Toggle(VIEW_ID)
		end)
	end
end

return EmoteUI
