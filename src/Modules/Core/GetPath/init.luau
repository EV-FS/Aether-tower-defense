local BezierPath = require(script.Parent.BezierPath)
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Guide = require(script.Guide)
local PathCatalog = require(script.PathCatalog)
local FrameBudget = require(script.Parent.Parent.Utils.FrameBudget)

local GetPath = {}
GetPath.CachedPath = nil
GetPath.PathLength = 0
GetPath.Paths = {}
GetPath.PathCount = 0
local catalog: PathCatalog.Catalog? = nil

local function waitForChild(parent: Instance, name: string): Instance
	return assert(parent:WaitForChild(name, 30), `경로 구성 요소를 찾을 수 없습니다: {parent:GetFullName()}.{name}`)
end

local function waitForAttribute(instance: Instance, name: string)
	local startedAt = os.clock()
	while instance:GetAttribute(name) == nil do
		assert(os.clock() - startedAt < 30, `경로 속성 로딩 대기 시간이 초과되었습니다: {name}`)
		task.wait(0.1)
	end
	return instance:GetAttribute(name)
end

local function buildPath(folder: Instance, isLegacy: boolean)
	local step = FrameBudget.new(task.wait, 128, 0.0015)
	local positions = {}
	local visited = {}
	local node = waitForChild(folder, "Start")
	while true do
		assert(node:IsA("BasePart") and node:IsDescendantOf(folder), `경로 노드는 해당 폴더 안의 BasePart여야 합니다: {folder:GetFullName()}`)
		-- Named paths can be children of the legacy Waypoints container, but their nodes belong to another route.
		assert(not isLegacy or node.Parent == folder, "기존 경로의 Next는 Waypoints에 직접 들어 있는 노드끼리 연결해야 합니다.")
		assert(not visited[node], `Next 연결이 순환하고 있습니다: {folder:GetFullName()}`)
		visited[node] = true
		table.insert(positions, node.Position)
		if node.Name == "End" then
			break
		end

		local nextValue = waitForChild(node, "Next")
		assert(nextValue:IsA("ObjectValue"), `Next는 ObjectValue여야 합니다: {node:GetFullName()}`)
		local startedAt = os.clock()
		while not nextValue.Value do
			assert(os.clock() - startedAt < 30, `Next가 가리키는 다음 노드를 찾을 수 없습니다: {node:GetFullName()}`)
			task.wait(0.1)
		end
		node = nextValue.Value
		step()
	end

	assert(#positions >= 2, `경로에는 Start와 End 노드가 필요합니다: {folder:GetFullName()}`)
	local path = BezierPath.new(positions, 3.5, step)
	assert(path:GetPathLength() > 0, `경로 길이가 0보다 커야 합니다: {folder:GetFullName()}`)
	return path
end

function GetPath:StartGuide()
	if not RunService:IsClient() then
		return
	end
	Guide.Start()
end

function GetPath:StopGuide()
	if not RunService:IsClient() then
		return
	end
	Guide.Stop()
end

function GetPath:Get(pathId: number?)
	local startedAt = os.clock()
	while not self.CachedPath do
		if os.clock() - startedAt > 60 then
			warn("경로 로딩 대기 시간이 초과되었습니다.")
			return nil
		end

		task.wait(0.1)
	end

	return assert(self.Paths[pathId or 1], `존재하지 않는 경로 ID입니다: {pathId or 1}`)
end

function GetPath:GetCount(): number
	assert(self:Get(), "경로가 아직 로드되지 않았습니다.")
	return self.PathCount
end

function GetPath:GetSpawnPathIds(isBoss: boolean?, path: (string | number)?): { number }
	assert(self:Get(), "경로가 아직 로드되지 않았습니다.")
	return PathCatalog.selectSpawnPaths(assert(catalog, "경로 목록이 아직 로드되지 않았습니다."), isBoss, path)
end

function GetPath.Init()
	local mapFolder = waitForChild(workspace, "Map")
	local waypointsFolder = waitForChild(mapFolder, "Waypoints")
	local manifest
	if RunService:IsServer() then
		local folderNames = {}
		for _, child in waypointsFolder:GetChildren() do
			if child:IsA("Folder") then
				table.insert(folderNames, child.Name)
			end
		end
		local start = waypointsFolder:FindFirstChild("Start")
		manifest = {
			Folders = folderNames,
			Legacy = start ~= nil and start:IsA("BasePart"),
		}
	else
		-- One map-level manifest; never guess IDs from partially replicated children.
		manifest = HttpService:JSONDecode(waitForAttribute(waypointsFolder, "PathManifest"))
	end

	local loadedCatalog = PathCatalog.new(manifest.Folders, manifest.Legacy)
	local paths = {}
	for id, name in ipairs(loadedCatalog.Names) do
		local isLegacy = loadedCatalog.IsLegacy and id == 1
		local folder = if isLegacy then waypointsFolder else waitForChild(waypointsFolder, name)
		paths[id] = buildPath(folder, isLegacy)
	end

	catalog = loadedCatalog
	GetPath.Paths = paths
	GetPath.PathCount = #loadedCatalog.Names
	GetPath.CachedPath = paths[1]
	GetPath.PathLength = GetPath.CachedPath:GetPathLength()
	if RunService:IsServer() then
		waypointsFolder:SetAttribute("PathManifest", HttpService:JSONEncode(manifest))
	end

	if RunService:IsClient() then
		Guide.Init(GetPath)
	end

	return GetPath.CachedPath
end

return GetPath
