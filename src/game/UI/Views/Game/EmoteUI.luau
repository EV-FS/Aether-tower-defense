local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local EmoteData = require(ReplicatedStorage.Settings.Data.EmoteData)
local EmoteRadialMenu = require(ReplicatedStorage.Shared.Modules.UI.Emote.EmoteRadialMenu)
local EmoteOverlay = require(ReplicatedStorage.Shared.Modules.UI.Emote.EmoteOverlay)
local LocalEmotePlayer = require(ReplicatedStorage.Shared.Modules.UI.Emote.LocalEmotePlayer)

local create = Vide.create
local effect = Vide.effect
local source = Vide.source

local VIEW_ID = "EmoteWheel"
local UIController
local SprintClient
local emotePlayer
local emoteIcon = source(nil :: any)

local emoteSlots = {
	Emote1 = source(EmoteData.ByIndex[1]),
	Emote2 = source(EmoteData.ByIndex[2]),
	Emote3 = source(EmoteData.ByIndex[3]),
	Emote4 = source(nil),
}

local EmoteUI = {}

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

function EmoteUI.BindTopbarIcon(icon: any)
	emoteIcon(icon)
end

function EmoteUI.OnSelected(emoteName: string)
	local emoteConfig = EmoteData.ByName[emoteName]
	if emotePlayer and emoteConfig and emotePlayer:CheckCooldown() then
		local didStart = emotePlayer:Start(emoteName, emoteConfig)
		if SprintClient then
			if didStart then
				SprintClient.Disable()
			else
				SprintClient.Enable()
			end
		end
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
			OnClose = EmoteUI.Close,
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
	UIController = ServiceRegistry:GetService("UIController")
	SprintClient = ServiceRegistry:GetService("SprintClient")
	emotePlayer = LocalEmotePlayer.new()
	emotePlayer.OnAutoStopped = function()
		if SprintClient then SprintClient.Enable() end
	end
end

function EmoteUI.Destroy()
	if emotePlayer then
		emotePlayer:Stop()
		emotePlayer = nil
	end
	if SprintClient then SprintClient.Enable() end
	emoteIcon(nil)
end

return EmoteUI
