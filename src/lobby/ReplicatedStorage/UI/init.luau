--/Services
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--/Modules
local Vide = require(ReplicatedStorage.Packages.Vide)
local App = require(script.App)
local LoadingController = require(ReplicatedFirst:WaitForChild("LoadingController"))
local UIOffsetScaler = require(script.Utils.UIOffsetScaler)
local LobbyButtonEffects = require(script.Utils.LobbyButtonEffects)

local mount = Vide.mount

local UI = {}
local isInitialized = false
local unmount: (() -> ())? = nil
local detachButtonEffects: (() -> ())? = nil
local mountedViews = nil
local viewUnmounts = {} :: { () -> () }
local mountGeneration = 0
function UI.ShowLoading()
	LoadingController.Show()
end

function UI.HideLoading()
	LoadingController.Hide()
end

function UI.HideLoadingAndWait(): boolean
	return LoadingController.HideAndWait()
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
		return App({})
	end, playerGui)
	local interface = playerGui:WaitForChild("Interface")
	mountGeneration += 1
	local generation = mountGeneration

	-- Build every menu behind the loading cover. Each view is still isolated so
	-- one broken menu cannot prevent the rest of the interface from loading.
	for index, view in ipairs(views) do
		if generation ~= mountGeneration then
			return
		end
		if view.RenderUI then
			local startedAt = os.clock()
			local success, result = pcall(function()
				return mount(function()
					return view.RenderUI()
				end, interface)
			end)
			local elapsed = os.clock() - startedAt
			local viewName = viewModules[index]:GetFullName()
			if success then
				table.insert(viewUnmounts, result)
				if elapsed > 0.1 then
					warn(`[UI] {viewName} took {string.format("%.3f", elapsed)}s to render`)
				end
			else
				warn(`[UI] {viewName} failed to render: {result}`)
			end
		end
	end
	detachButtonEffects = LobbyButtonEffects.Attach(interface)

	for _, view in views do
		if view.Start then
			task.spawn(view.Start, views)
		end
	end
end

function UI.Destroy()
	LoadingController.Destroy()

	if not isInitialized then
		return
	end

	mountGeneration += 1
	if detachButtonEffects then
		detachButtonEffects()
		detachButtonEffects = nil
	end
	for index = #viewUnmounts, 1, -1 do
		viewUnmounts[index]()
		viewUnmounts[index] = nil
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
