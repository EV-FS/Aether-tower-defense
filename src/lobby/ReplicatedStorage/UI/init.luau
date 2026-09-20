--/Services
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

--/Modules
local Vide = require(ReplicatedStorage.Packages.Vide)
local App = require(script.App)
local LoadingController = require(ReplicatedFirst:WaitForChild("LoadingController"))
local UIOffsetScaler = require(script.Utils.UIOffsetScaler)

local mount = Vide.mount

local UI = {}
local isInitialized = false
local unmount: (() -> ())? = nil
local mountedViews = nil
local viewUnmounts = {} :: { () -> () }
local mountGeneration = 0
local UI_PRELOAD_TIMEOUT = 8

local function preloadInterface(interface: ScreenGui)
	local targets = {}
	local function collect(root: Instance)
		for _, instance in root:GetDescendants() do
			if
				instance:IsA("ImageLabel")
				or instance:IsA("ImageButton")
				or instance:IsA("TextLabel")
				or instance:IsA("TextButton")
				or instance:IsA("TextBox")
				or instance:IsA("MeshPart")
				or instance:IsA("SpecialMesh")
				or instance:IsA("Decal")
				or instance:IsA("Texture")
				or instance:IsA("SurfaceAppearance")
				or instance:IsA("Animation")
				or instance:IsA("Sound")
				or instance:IsA("AudioPlayer")
				or instance:IsA("VideoFrame")
			then
				table.insert(targets, instance)
			end
		end
	end
	collect(interface)
	collect(SoundService)
	if #targets == 0 then
		return
	end

	local finished = false
	local success = false
	local preloadError = nil
	-- One focused batch: visible UI/viewport assets and the UI audio graph. Do
	-- not include the whole workspace or ReplicatedStorage here.
	local preloadThread = task.spawn(function()
		success, preloadError = pcall(function()
			ContentProvider:PreloadAsync(targets)
		end)
		finished = true
	end)

	local deadline = os.clock() + UI_PRELOAD_TIMEOUT
	while not finished and os.clock() < deadline do
		RunService.Heartbeat:Wait()
	end

	if not finished then
		pcall(task.cancel, preloadThread)
		warn(`[UI] Asset batch exceeded {UI_PRELOAD_TIMEOUT}s; continuing with streaming`)
	elseif not success then
		warn(`[UI] Asset batch failed: {preloadError}`)
	end
end
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

	preloadInterface(interface)

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
