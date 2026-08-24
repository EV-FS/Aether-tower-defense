--/Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--/Modules
local Vide = require(ReplicatedStorage.Packages.Vide)
local App = require(script.App)
local LoadingScreen = require(script.Components.LoadingScreen)
local UIOffsetScaler = require(script.Utils.UIOffsetScaler)

local mount = Vide.mount

local UI = {}
local isInitialized = false
local unmount: (() -> ())? = nil
local mountedViews = nil
local loadingVisible = Vide.source(true)
local loadingUnmount: (() -> ())? = nil
local loadingToken = 0

function UI.ShowLoading()
	loadingToken += 1
	loadingVisible(true)

	if loadingUnmount then
		return
	end

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	loadingVisible(false)
	loadingUnmount = mount(function()
		return LoadingScreen({ IsVisible = loadingVisible })
	end, playerGui)
	task.defer(function()
		if loadingUnmount then
			loadingVisible(true)
		end
	end)
end

function UI.HideLoading()
	if not loadingUnmount then
		return
	end

	loadingVisible(false)
	loadingToken += 1
	local token = loadingToken
	local currentUnmount = loadingUnmount
	task.delay(1.1, function()
		if loadingToken == token and loadingUnmount == currentUnmount then
			currentUnmount()
			loadingUnmount = nil
		end
	end)
end

local function GetViews()
	local views = {}

	for _, module in script.Views:GetDescendants() do
		if module:IsA("ModuleScript") and module.Name:match("UI$") then
			table.insert(views, module)
		end
	end

	table.sort(views, function(a, b)
		return a:GetFullName() < b:GetFullName()
	end)

	return views
end

function UI.Init()
	if isInitialized then
		return
	end

	isInitialized = true
	UIOffsetScaler.Init()

	local viewModules = GetViews()
	local views = table.create(#viewModules)
	for index, module in ipairs(viewModules) do
		views[index] = require(module)
	end

	mountedViews = views
	for _, view in views do
		if view.Init then
			view.Init()
		end
	end

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	unmount = mount(function()
		local uiElements = {}
		for _, view in ipairs(views) do
			if view.RenderUI then
				table.insert(uiElements, view.RenderUI())
			end
		end
		return App(uiElements)
	end, playerGui)

	for _, view in views do
		if view.Start then
			task.spawn(view.Start, views)
		end
	end
end

function UI.Destroy()
	if loadingUnmount then
		loadingUnmount()
		loadingUnmount = nil
	end
	loadingVisible(true)

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
