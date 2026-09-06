local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Vide"))
local LoadingScreen = require(script.Parent.LoadingScreen)

local EXIT_DURATION = 1.05
local MIN_VISIBLE_DURATION = 2.1

local visible = Vide.source(false)
local loadingUnmount: (() -> ())? = nil
local transitionToken = 0
local isBootHeld = true
local shownAt = 0

local LoadingController = {}

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

function LoadingController.Prepare()
	transitionToken += 1
	mountLoadingScreen()
end

function LoadingController.ReleaseBoot()
	isBootHeld = false
	transitionToken += 1
	mountLoadingScreen()
	shownAt = os.clock()
	visible(true)
end

function LoadingController.Show()
	transitionToken += 1
	mountLoadingScreen()

	if isBootHeld then
		return
	end

	if not visible() then
		shownAt = os.clock()
	end
	visible(true)
end

function LoadingController.Hide()
	if not loadingUnmount then
		return
	end

	transitionToken += 1
	local token = transitionToken
	local currentUnmount = loadingUnmount
	local remainingIntro = math.max(MIN_VISIBLE_DURATION - (os.clock() - shownAt), 0)

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

function LoadingController.Destroy()
	transitionToken += 1
	visible(false)

	if loadingUnmount then
		loadingUnmount()
		loadingUnmount = nil
	end
end

return LoadingController
