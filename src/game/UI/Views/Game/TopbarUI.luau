local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Topbarplus = require(ReplicatedStorage.Packages.Topbarplus)
local Net = require(ReplicatedStorage.Shared.Net)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local ICONS = require(ReplicatedStorage.Shared.Modules.UI.TopbarIcons)

local VIEW_ID = "Settings"

local TopbarUI = {}
local UIController
local TimeService

local function createIcon(image: string)
	return Topbarplus.new()
		:setImage(image)
		:align("Right")
end

local function createSpeedMenu()
	local speedIcon = createIcon(ICONS.Speed)
	local options = {}

	for _, speed in ipairs({ 1, 1.5, 2 }) do
		local option = Topbarplus.new()
			:setLabel(`{speed}x speed`)
			:setCaption(`Set game speed to {speed}x`)
			:bindEvent("selected", function()
				if TimeService then
					TimeService:SetGameSpeed(speed)
				end
				speedIcon:deselect()
			end)
			table.insert(options, option)
	end

	speedIcon:setDropdown(options)
	return speedIcon
end

function TopbarUI.RenderUI()
	return nil
end

function TopbarUI.Init()
	UIController = ServiceRegistry:GetService("UIController")
	TimeService = ServiceRegistry:GetService("TimeService")
end

function TopbarUI.Start()
	local emoteIcon = createIcon(ICONS.Emote)
	emoteIcon:bindEvent("selected", function()
		pcall(function()
			StarterGui:SetCore("EmotesMenuOpen", true)
		end)
		emoteIcon:deselect()
	end)

	local leaveIcon = createIcon(ICONS.Leave)
	leaveIcon:bindEvent("selected", function()
		Net.GameEvent.TeleportToLobby.Fire()
		leaveIcon:deselect()
	end)

	local speedIcon = createSpeedMenu()
	local settingsIcon = createIcon(ICONS.Settings)
	settingsIcon:bindEvent("selected", function()
		if UIController and not (UIController:IsOpen(VIEW_ID) or UIController:IsOpen("Setting")) then
			UIController:Open(VIEW_ID)
		end
	end)
	settingsIcon:bindEvent("deselected", function()
		if UIController and (UIController:IsOpen(VIEW_ID) or UIController:IsOpen("Setting")) then
			UIController:Close(VIEW_ID)
			UIController:Close("Setting")
		end
	end)
end

	Topbarplus.new()
		:align("Right")
		:setFixedMenu({ emoteIcon, leaveIcon, speedIcon, settingsIcon })

return TopbarUI
