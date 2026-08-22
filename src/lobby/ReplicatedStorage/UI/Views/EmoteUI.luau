local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Topbarplus = require(ReplicatedStorage.Packages.Topbarplus)
local Vide = require(ReplicatedStorage.Packages.Vide)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local EmoteData = require(ReplicatedStorage.Settings.Data.EmoteData)
local EmoteRadialMenu = require(ReplicatedStorage.UI.Components.EmoteRadialMenu)
local EmoteOverlay = require(ReplicatedStorage.UI.Components.EmoteOverlay)
local EmoteClient
local InputController
local UIController

local create = Vide.create
local source = Vide.source

local VIEW_ID = "EmoteWheel"
local EmoteInput

local emoteSlots = {
	Emote1 = source(EmoteData.ByIndex[1]),
	Emote2 = source(EmoteData.ByIndex[2]),
	Emote3 = source(nil),
	Emote4 = source(nil),
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

		EmoteOverlay({
			Name = "EmoteOverlay",
			IsOpen = UIController:IsVisible(VIEW_ID),
			OnClose = function()
				UIController:Close(VIEW_ID)
			end,
			Content = EmoteRadialMenu({
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
		iAction("Toggle", iInfo({ Enum.KeyCode.E })),
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
