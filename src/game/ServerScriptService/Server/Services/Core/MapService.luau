local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GetPath = require(ReplicatedStorage.Shared.Modules.Core.GetPath)
local SceneLifecycle = require(script.Parent.SceneLifecycle)
local MapLoadTrace = require(script.Parent.MapLoadTrace)
local AudioService
local WaveService

local MapService = {}
local MAP_MOUNT_CHUNK_SIZE = 32
MapService.IsLoading = false
MapService.IsLoaded = false
MapService.LoadedMap = nil
MapService.LoadedRoots = {}
local waveConnection = nil

function MapService:PrepareMap(mapName: string)
	local started = os.clock()
	local source = assert(ReplicatedStorage.Assets.Maps:WaitForChild(mapName, 30), "Missing map: " .. mapName)
	local trace = MapLoadTrace.new(mapName, workspace:WaitForChild("Map"))
	local clone = trace:Run("Clone", function() return SceneLifecycle.Clone(source) end)
	-- This limit includes every descendant, even children below a BasePart.
	-- Gameplay is owned by server services. Scripts embedded in map assets stay
	-- disabled so an imported/free-model script cannot stall the entire server.
	local prepared = SceneLifecycle.Prepare(clone, MAP_MOUNT_CHUNK_SIZE, true, trace)
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
	local trace = MapLoadTrace.new(mapName, mapFolder)
	local staging = prepared
	local ok, err = xpcall(function()
		if waveConnection then waveConnection:Disconnect(); waveConnection = nil end
		-- Delete only instances this service loaded, never unrelated Workspace objects.
		trace:Run("Cleanup", function() SceneLifecycle.Destroy(self.LoadedRoots) end)
		self.LoadedRoots = {}
		self.LoadedMap = nil
		staging = staging or self:PrepareMap(mapName)
		assert(staging.MapName == mapName, "Prepared map does not match selected map")
		mapFolder:SetAttribute("MapPrepareSeconds", staging.PrepareSeconds)
		self.LoadedRoots = SceneLifecycle.MountPrepared(staging, mapFolder, trace)
		staging = nil

		local environmentFolder = mapFolder:FindFirstChild("Environment")
		local terrainRegion = environmentFolder and environmentFolder:FindFirstChildOfClass("TerrainRegion")
		if terrainRegion then
			trace:Run("Terrain", function()
				-- A TerrainRegion cannot be sliced by the runtime API. Log BEFORE
				-- PasteRegion so a stall inside this engine call is identifiable.
				print(string.format("[MapLoad] %s TerrainRegion SizeInCells=%s", mapName, tostring(terrainRegion.SizeInCells)))
				workspace.Terrain:PasteRegion(terrainRegion, workspace.Terrain.MaxExtents.Min, true)
			end)
		end

		trace:Run("Paths", function() GetPath.Init() end)
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
		mapFolder:SetAttribute("LoadError", string.sub(tostring(err), 1, 1000))
		warn("[MapService] Load failed before cleanup: " .. tostring(err))
		task.wait()
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
