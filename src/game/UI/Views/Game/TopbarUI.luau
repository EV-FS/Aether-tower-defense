local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local TopbarFactory = require(ReplicatedStorage.Shared.Modules.UI.TopbarFactory)
local Net = require(ReplicatedStorage.Shared.Net.client)
local ClientSignals = require(StarterPlayer.StarterPlayerScripts.Client.ClientSignals)
local EmoteUI = require(script.Parent.EmoteUI)
local SettingsUI = require(script.Parent.Parent.Settings.SettingsUI)
local SpeedUI = require(script.Parent.SpeedUI)

local TopbarUI = {}
local topbar = TopbarFactory.new()
local speedOptionIcons = {}
local exitRequested = false

local function updateSpeedLabels(speed: number)
	for optionSpeed, icon in speedOptionIcons do
		local prefix = if optionSpeed == speed then ">  " else ""
		icon:setLabel(`{prefix}{optionSpeed}x`)
	end
end

local function speedOption(speed: number)
	local icon = topbar:CreateLabel(`${speed}x`, `Set speed to {speed}x`)
	topbar:BindOneClick(icon, function()
		task.spawn(function()
			local success, changed = pcall(SpeedUI.ChangeSpeed, speed)
			if success and changed then
				updateSpeedLabels(speed)
			elseif not success then
				warn(`[TopbarUI] Failed to change speed: {changed}`)
			end
		end)
	end)
	speedOptionIcons[speed] = icon
	return icon
end

function TopbarUI.Start()
	local emoteIcon = topbar:CreateImage("Emote", "Emotes", 1)
	topbar:BindToggle(emoteIcon, EmoteUI.Open, EmoteUI.Close)
	EmoteUI.BindTopbarIcon(emoteIcon)

	local exitIcon = topbar:CreateImage("Exit", "Return to Lobby", 1, false)
	topbar:BindOneClick(exitIcon, function()
		if exitRequested then return end
		exitRequested = true
		Net.GameEvent.TeleportToLobby.Fire()
		task.delay(3, function()
			exitRequested = false
		end)
	end)

	local speedIcon = topbar:CreateImage("Speed", "Game Speed", 2, false)
	-- Preserve the speed artwork instead of TopbarPlus replacing it with an X.
	speedIcon:setImage(string.gsub(TopbarFactory.Assets.Speed, "rbxassetid://", ""), "Selected")
	speedIcon:setDropdown({ speedOption(1), speedOption(1.5), speedOption(2) })

	local settingsIcon = topbar:CreateImage("Settings", "Settings", 3, false)
	topbar:BindToggle(settingsIcon, SettingsUI.Open, SettingsUI.Close)
	SettingsUI.BindTopbarIcon(settingsIcon)

	topbar:CreateGroup({ exitIcon, speedIcon, settingsIcon }, 2)
	updateSpeedLabels(SpeedUI.GetSpeed())
	topbar:TrackConnection(ClientSignals.GameSpeedChanged:Connect(updateSpeedLabels))
end

function TopbarUI.Destroy()
	EmoteUI.BindTopbarIcon(nil)
	SettingsUI.BindTopbarIcon(nil)
	topbar:Destroy()
	table.clear(speedOptionIcons)
	exitRequested = false
end

return TopbarUI
