local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GetPath = require(ReplicatedStorage.Shared.Modules.Core.GetPath)
local AudioService
local WaveService

local MapService = {}
MapService.IsLoading = false
MapService.IsLoaded = false
MapService.LoadedMap = nil

function MapService:LoadMapAsync(mapName: string, difficulty: string?)
	while not WaveService do
		task.wait()
	end

	if self.IsLoaded and self.LoadedMap == mapName then
		return
	end

	if self.IsLoading then
		while self.IsLoading do
			task.wait()
		end
		return
	end

	self.IsLoading = true

	local mapClone = ReplicatedStorage.Assets.Maps:WaitForChild(mapName):Clone()
	local mapFolder = workspace:WaitForChild("Map")
	mapFolder:SetAttribute("SelectedMap", mapName)
	mapFolder:SetAttribute("SelectedDifficulty", difficulty or "Normal")
	for _, inst in mapClone:GetChildren() do
		inst.Parent = mapFolder
	end

	local bgmFolder = workspace:WaitForChild("Map"):WaitForChild("BGM")
	--AudioService.SetBGMState(nil, nil, bgmFolder:WaitForChild("0").SoundId)

	GetPath.Init()

	WaveService.WaveStarted:Connect(function()
		local currentWave = WaveService.CurrentWave
		local currentBGM = bgmFolder:FindFirstChild(tostring(currentWave))

		if currentBGM then
			AudioService.SetBGMState(nil, nil, currentBGM.SoundId)
		end
	end)

	self.LoadedMap = mapName
	self.IsLoaded = true
	self.IsLoading = false
end

function MapService.Init(services)
	AudioService = services:GetService("AudioService")
	WaveService = services:GetService("WaveService")
end

function MapService.Start() end

return MapService
