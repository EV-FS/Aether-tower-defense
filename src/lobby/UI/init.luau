--/Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--/Modules
local Vide = require(ReplicatedStorage.Packages.Vide)
local App = require(script.App)
local UIOffsetScaler = require(script.Utils.UIOffsetScaler)

local mount = Vide.mount

local UI = {}

function UI.Init()
	UIOffsetScaler.Init()

	local views = {}

	for _, module in script.Views:GetDescendants() do
		if module:IsA("ModuleScript") and module.Name:match("UI$") then
			local view = require(module)
			table.insert(views, view)

			if view.Init then
				view.Init()
			end
		end
	end

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	mount(function()
		local uiElements = {}
		for _, view in views do
			if view.RenderUI then
				table.insert(uiElements, view.RenderUI())
			end
		end
		return App(uiElements)
	end, playerGui)

	for _, view in views do
		if view.Start then
			task.spawn(view.Start)
		end
	end
end

return UI
