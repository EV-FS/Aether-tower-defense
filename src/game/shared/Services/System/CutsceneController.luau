local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CutscenePlayer = require(ReplicatedStorage.Shared.Modules.Cutscene.CutscenePlayer)
local MapData = require(ReplicatedStorage.Settings.Data.MapData)

local CutsceneController = {}

local CUTSCENE_FINISHED_EVENT_NAME = "CutsceneFinished"
local playedCutscenes = {}
local isStarted = false

local function hideLoadingCover()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	for _, name in ipairs({ "LoadingBootstrap", "LoadingScreen" }) do
		local loadingGui = playerGui:FindFirstChild(name)
		if loadingGui and loadingGui:IsA("ScreenGui") then
			loadingGui.Enabled = false
		end
	end
end

local function playMapIntro(mapName: string?)
	local mapInfo = mapName and MapData[mapName]
	local cutsceneName = mapInfo and mapInfo.IntroCutscene
	if not cutsceneName or playedCutscenes[cutsceneName] then
		return
	end

	playedCutscenes[cutsceneName] = true
	task.spawn(function()
		hideLoadingCover()
		local didPlay = CutscenePlayer.Play(cutsceneName)
		if not didPlay then
			warn(`[CutsceneController] Failed to play "{cutsceneName}" for map "{mapName}".`)
		end

		local finishedEvent = ReplicatedStorage:FindFirstChild(CUTSCENE_FINISHED_EVENT_NAME)
		if finishedEvent and finishedEvent:IsA("RemoteEvent") then
			finishedEvent:FireServer(mapName, cutsceneName)
		end
	end)
end

function CutsceneController.Start()
	if isStarted then
		return
	end
	isStarted = true

	local mapFolder = workspace:WaitForChild("Map")

	playMapIntro(mapFolder:GetAttribute("SelectedMap"))
	mapFolder:GetAttributeChangedSignal("SelectedMap"):Connect(function()
		playMapIntro(mapFolder:GetAttribute("SelectedMap"))
	end)
end

function CutsceneController.Play(cutsceneName: string): boolean
	return CutscenePlayer.Play(cutsceneName)
end

function CutsceneController.Stop()
	CutscenePlayer.Stop()
end

return CutsceneController
