local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local EmoteData = require(ReplicatedStorage.Settings.Data.EmoteData)
local EmoteRadialMenu = require(ReplicatedStorage.Shared.Modules.UI.Emote.EmoteRadialMenu)
local EmoteOverlay = require(ReplicatedStorage.Shared.Modules.UI.Emote.EmoteOverlay)
local EmoteClient
local InputController
local UIController

local create = Vide.create
local effect = Vide.effect
local source = Vide.source

local VIEW_ID = "EmoteWheel"
local EmoteInput
local emoteIcon = source(nil :: any)

local emoteSlots = {}
local emoteIndices = {}
for index in EmoteData.ByIndex do
	table.insert(emoteIndices, index)
end
table.sort(emoteIndices)
for _, index in emoteIndices do
	table.insert(emoteSlots, source(EmoteData.ByIndex[index]))
end

local EmoteUI = {}

function EmoteUI.OnSelected(emoteName: string)
	if EmoteClient then
		EmoteClient.PlayEmote(emoteName)
	end

	EmoteUI.Close()
end

function EmoteUI.RenderUI()
	effect(function()
		local icon = emoteIcon()
		if not icon or not UIController then return end

		local isOpen = UIController:IsOpen(VIEW_ID)
		if isOpen and not icon.isSelected then
			icon:select()
		elseif not isOpen and icon.isSelected then
			icon:deselect()
		end
	end)

	return create("Frame")({
		Name = "EmoteUI",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),

		EmoteOverlay({
			Name = "EmoteOverlay",
			IsOpen = UIController:IsVisible(VIEW_ID),
			OnClose = function()
				EmoteUI.Close()
			end,
			Content = EmoteRadialMenu({
				Emotes = emoteSlots,
				OnSelected = EmoteUI.OnSelected,
			}),
		}),
	})
end

function EmoteUI.BindTopbarIcon(icon: any)
	emoteIcon(icon)
end

function EmoteUI.Open()
	if UIController and not UIController:IsOpen(VIEW_ID) then
		UIController:Open(VIEW_ID)
	end
end

function EmoteUI.Close()
	if UIController and UIController:IsOpen(VIEW_ID) then
		UIController:Close(VIEW_ID)
	end
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

end

return EmoteUI
