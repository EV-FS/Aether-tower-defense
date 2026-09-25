local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Vide = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Vide"))
local LoadingScreen = require(script.Parent.LoadingScreen)

local EXIT_DURATION = 1.05
local MIN_VISIBLE_DURATION = 2.1
-- Normal boot now prepares every UI asset behind the cover. This is only a
-- deadlock escape hatch, not the expected loading duration.
local MAX_VISIBLE_DURATION = 30

local visible = Vide.source(false)
local loadingUnmount: (() -> ())? = nil
local transitionToken = 0
local shownAt = 0

local LoadingController = {}

local function releaseBootstrapCover()
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local bootstrap = playerGui and playerGui:FindFirstChild("LoadingBootstrap")
	if not bootstrap then return end
	task.spawn(function()
		-- Wait until the replacement LoadingScreen has had a rendered frame.
		RunService.RenderStepped:Wait()
		RunService.Heartbeat:Wait()
		if bootstrap.Parent then bootstrap:Destroy() end
	end)
end

local function scheduleFailsafe(token: number)
	task.delay(MAX_VISIBLE_DURATION, function()
		if transitionToken ~= token or not loadingUnmount then
			return
		end
		warn(`[LoadingController] Loading exceeded {MAX_VISIBLE_DURATION}s; releasing the cover`)
		LoadingController.Hide(true)
	end)
end

local function mountLoadingScreen()
	if loadingUnmount then
		return
	end

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	visible(false)
	loadingUnmount = Vide.mount(function()
		return LoadingScreen({ IsVisible = visible })
	end, playerGui)
end

function LoadingController.Show(holdUntilHidden: boolean?)
	transitionToken += 1
	mountLoadingScreen()

	if not visible() then
		shownAt = os.clock()
	end
	visible(true)
	releaseBootstrapCover()
	if not holdUntilHidden then
		scheduleFailsafe(transitionToken)
	end
end

function LoadingController.Hide(skipMinimum: boolean?, skipExit: boolean?)
	if not loadingUnmount then
		return
	end

	transitionToken += 1
	local token = transitionToken
	local currentUnmount = loadingUnmount
	local remainingIntro = if skipMinimum then 0 else math.max(MIN_VISIBLE_DURATION - (os.clock() - shownAt), 0)
	if skipExit then
		visible(false)
		currentUnmount()
		if loadingUnmount == currentUnmount then loadingUnmount = nil end
		return
	end

	task.delay(remainingIntro, function()
		if transitionToken ~= token or loadingUnmount ~= currentUnmount then
			return
		end

		visible(false)
		task.wait(EXIT_DURATION)
		if transitionToken == token and loadingUnmount == currentUnmount then
			currentUnmount()
			loadingUnmount = nil
		end
	end)
end

function LoadingController.HideAndWait(skipMinimum: boolean?): boolean
	if not loadingUnmount then return true end
	LoadingController.Hide(skipMinimum)
	local token = transitionToken
	local deadline = os.clock() + EXIT_DURATION + MIN_VISIBLE_DURATION + 2
	while loadingUnmount and transitionToken == token and os.clock() < deadline do
		RunService.RenderStepped:Wait()
	end
	if transitionToken ~= token then return false end
	if loadingUnmount then
		LoadingController.Hide(true, true)
		return false
	end
	return true
end

function LoadingController.Destroy()
	transitionToken += 1
	visible(false)

	if loadingUnmount then
		loadingUnmount()
		loadingUnmount = nil
	end
end

return LoadingController
