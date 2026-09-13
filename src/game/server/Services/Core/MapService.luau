local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GetPath = require(ReplicatedStorage.Shared.Modules.Core.GetPath)
local SceneLifecycle = require(script.Parent.SceneLifecycle)
local AudioService
local WaveService

local MapService = {}
MapService.IsLoading = false
MapService.IsLoaded = false
MapService.LoadedMap = nil
MapService.LoadedRoots = {}
local waveConnection = nil

function MapService:PrepareMap(mapName: string)
	local started = os.clock()
	local source = assert(ReplicatedStorage.Assets.Maps:WaitForChild(mapName, 30), "Missing map: " .. mapName)
	local prepared = SceneLifecycle.Prepare(SceneLifecycle.Clone(source))
	prepared.MapName = mapName
	prepared.PrepareSeconds = os.clock() - started
	return prepared
end

function MapService:DiscardPrepared(prepared)
	SceneLifecycle.Discard(prepared)
end

function MapService:LoadMapAsync(mapName: string, difficulty: string?, prepared)
	while not WaveService or self.IsLoading do task.wait() end
	if self.IsLoaded and self.LoadedMap == mapName then
		self:DiscardPrepared(prepared)
		return
	end
	self.IsLoading = true
	local loadStarted = os.clock()
	self.IsLoaded = false
	local mapFolder = workspace:WaitForChild("Map")
	mapFolder:SetAttribute("MapReady", false)
	mapFolder:SetAttribute("LoadError", nil)
	mapFolder:SetAttribute("MapLoadSeconds", nil)
	local staging = prepared
	local ok, err = xpcall(function()
		if waveConnection then waveConnection:Disconnect(); waveConnection = nil end
		-- Delete only instances this service loaded, never unrelated Workspace objects.
		SceneLifecycle.Destroy(self.LoadedRoots)
		self.LoadedRoots = {}
		self.LoadedMap = nil
		staging = staging or self:PrepareMap(mapName)
		assert(staging.MapName == mapName, "Prepared map does not match selected map")
		mapFolder:SetAttribute("MapPrepareSeconds", staging.PrepareSeconds)
		self.LoadedRoots = SceneLifecycle.MountPrepared(staging, mapFolder)
		staging = nil

		local environmentFolder = mapFolder:FindFirstChild("Environment")
		local terrainRegion = environmentFolder and environmentFolder:FindFirstChildOfClass("TerrainRegion")
		if terrainRegion then
			-- TerrainRegion has no chunk-read API; this engine operation remains atomic.
			local started = os.clock()
			workspace.Terrain:PasteRegion(terrainRegion, workspace.Terrain.MaxExtents.Min, true)
			local elapsed = os.clock() - started
			if elapsed > 0.016 then
				warn(string.format("[MapService] Atomic Terrain PasteRegion %.1fms: %s", elapsed * 1000, mapName))
			end
			task.wait()
		end

		GetPath.Init()
		local bgmFolder = mapFolder:FindFirstChild("BGM")
		waveConnection = WaveService.WaveStarted:Connect(function()
			local currentBGM = bgmFolder and bgmFolder:FindFirstChild(tostring(WaveService.CurrentWave))
			if currentBGM then AudioService.SetBGMState(nil, nil, currentBGM.SoundId) end
		end)
		self.LoadedMap = mapName
		self.IsLoaded = true
		mapFolder:SetAttribute("SelectedMap", mapName)
		mapFolder:SetAttribute("SelectedDifficulty", difficulty or "Normal")
		mapFolder:SetAttribute("MapLoadSeconds", os.clock() - loadStarted)
		mapFolder:SetAttribute("MapReady", true)
	end, debug.traceback)
	if not ok then
		SceneLifecycle.Destroy(self.LoadedRoots)
		self.LoadedRoots = {}
		self:DiscardPrepared(staging)
		self.IsLoaded = false
		self.LoadedMap = nil
		mapFolder:SetAttribute("LoadError", string.sub(tostring(err), 1, 500))
	end
	self.IsLoading = false
	if not ok then error(err, 0) end
end

function MapService.Init(services)
	AudioService = services:GetService("AudioService")
	WaveService = services:GetService("WaveService")
end

function MapService.Start() end

return MapService
