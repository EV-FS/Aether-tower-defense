--/Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--/Modules
local Vide = require(ReplicatedStorage.Packages.Vide)
local App = require(script.App)
local UIOffsetScaler = require(script.Utils.UIOffsetScaler)
local ViewRegistry = require(script.Views)

local mount = Vide.mount

local UI = {}
local isInitialized = false
local unmount: (() -> ())? = nil
local mountedViews = nil

function UI.Init()
	if isInitialized then
		return
	end

	isInitialized = true
	UIOffsetScaler.Init()

	local views = ViewRegistry.GetAll()
	mountedViews = views
	for _, view in ipairs(views) do
		if view.Init then
			view.Init()
		end
	end

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	unmount = mount(function()
		local uiElements = {}
		for _, view in ipairs(views) do
			table.insert(uiElements, view.RenderUI())
		end
		return App(uiElements)
	end, playerGui)

	for _, view in ipairs(views) do
		if view.Start then
			task.spawn(view.Start)
		end
	end
end

function UI.Destroy()
	if not isInitialized then
		return
	end

	if unmount then
		unmount()
		unmount = nil
	end

	if mountedViews then
		for _, view in ipairs(mountedViews) do
			if view.Destroy then
				view.Destroy()
			end
		end
		mountedViews = nil
	end

	UIOffsetScaler.Destroy()
	isInitialized = false
end

return UI
