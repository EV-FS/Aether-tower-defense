local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TopbarFactory = require(ReplicatedStorage.Shared.Modules.UI.TopbarFactory)
local EmoteUI = require(script.Parent.EmoteUI)
local SettingsUI = require(script.Parent.SettingsUI)

local TopbarUI = {}
local topbar = TopbarFactory.new()

function TopbarUI.Start()
	local emoteIcon = topbar:CreateImage("Emote", "Emotes", 1)
	topbar:BindToggle(emoteIcon, EmoteUI.Open, EmoteUI.Close)
	EmoteUI.BindTopbarIcon(emoteIcon)

	local settingsIcon = topbar:CreateImage("Settings", "Settings", 2)
	topbar:BindToggle(settingsIcon, SettingsUI.Open, SettingsUI.Close)
	SettingsUI.BindTopbarIcon(settingsIcon)
end

function TopbarUI.Destroy()
	EmoteUI.BindTopbarIcon(nil)
	SettingsUI.BindTopbarIcon(nil)
	topbar:Destroy()
end

return TopbarUI
