local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Topbarplus = require(ReplicatedStorage.Packages.Topbarplus)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local TopbarIcons = require(ReplicatedStorage.Shared.Modules.UI.TopbarIcons)

local TopbarUI = {}
local UIController

local function createIcon(image: string)
	return Topbarplus.new()
		:setImage(image)
		:align("Right")
end

function TopbarUI.RenderUI()
	return nil
end

function TopbarUI.Init()
	UIController = ServiceRegistry:GetService("UIController")
end

function TopbarUI.Start()
	local emoteIcon = createIcon(TopbarIcons.Emote)
	emoteIcon:bindEvent("selected", function()
		if UIController then
			UIController:Toggle("EmoteWheel")
		end
		emoteIcon:deselect()
	end)

	local settingsIcon = createIcon(TopbarIcons.Settings)
	settingsIcon:bindEvent("selected", function()
		if UIController then
			UIController:Open("Settings")
		end
	end)
	settingsIcon:bindEvent("deselected", function()
		if UIController then
			UIController:Close("Settings")
			UIController:Close("Setting")
		end
	end)

	Topbarplus.new()
		:align("Right")
		:setFixedMenu({ emoteIcon, settingsIcon })
end

return TopbarUI
