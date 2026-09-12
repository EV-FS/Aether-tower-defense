--/Services
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--/Modules
local Vide = require(ReplicatedStorage.Packages.Vide)
local App = require(script.App)
local UIOffsetScaler = require(script.Utils.UIOffsetScaler)

local loadingControllerModule = ReplicatedFirst:FindFirstChild("LoadingController")
local LoadingController = if loadingControllerModule
	then require(loadingControllerModule)
	else require(script.LoadingFallbackController)

local mount = Vide.mount

local UI = {}
local isInitialized = false
local unmount: (() -> ())? = nil
local mountedViews = nil

function UI.ShowLoading()
	LoadingController.Show()
end

function UI.HideLoading()
	LoadingController.Hide()
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
	for _, view in ipairs(views) do
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

	for _, view in ipairs(views) do
		if view.Start then
			task.spawn(view.Start)
		end
	end
end

function UI.Destroy()
	LoadingController.Destroy()

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
