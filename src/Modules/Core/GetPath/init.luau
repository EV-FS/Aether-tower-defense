local BezierPath = require(script.Parent.BezierPath)
local RunService = game:GetService("RunService")

local Guide = require(script.Guide)

local GetPath = {}
GetPath.CachedPath = nil
GetPath.PathLength = 0
GetPath.Paths = {}
GetPath.PathCount = 0

local function waitForChild(parent: Instance, name: string): Instance
	return assert(parent:WaitForChild(name, 30), `Missing path instance: {parent:GetFullName()}.{name}`)
end

local function waitForAttribute(instance: Instance, name: string)
	local startedAt = os.clock()
	while instance:GetAttribute(name) == nil do
		assert(os.clock() - startedAt < 30, `Timed out loading path attribute: {name}`)
		task.wait(0.1)
	end
	return instance:GetAttribute(name)
end

local function buildPath(folder: Instance)
	local positions = {}
	local visited = {}
	local node = waitForChild(folder, "Start")
	while true do
		assert(node:IsA("BasePart") and node:IsDescendantOf(folder), `Invalid waypoint in {folder:GetFullName()}`)
		assert(not visited[node], `Cyclic Next link in {folder:GetFullName()}`)
		visited[node] = true
		table.insert(positions, node.Position)
		if node.Name == "End" then
			break
		end

		local nextValue = waitForChild(node, "Next")
		assert(nextValue:IsA("ObjectValue"), `Next must be an ObjectValue: {node:GetFullName()}`)
		local startedAt = os.clock()
		while not nextValue.Value do
			assert(os.clock() - startedAt < 30, `Missing Next target: {node:GetFullName()}`)
			task.wait(0.1)
		end
		node = nextValue.Value
	end

	assert(#positions >= 2, `Path needs Start and End: {folder:GetFullName()}`)
	local path = BezierPath.new(positions, 3.5)
	assert(path:GetPathLength() > 0, `Path has no length: {folder:GetFullName()}`)
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
			warn("경로 로드 타임아웃.")
			return nil
		end

		task.wait(0.1)
	end

	return assert(self.Paths[pathId or 1], `Unknown PathId: {pathId or 1}`)
end

function GetPath:GetCount(): number
	assert(self:Get(), "Paths have not loaded")
	return self.PathCount
end

function GetPath.Init()
	local mapFolder = waitForChild(workspace, "Map")
	local waypointsFolder = waitForChild(mapFolder, "Waypoints")
	local isLegacy
	local pathCount
	if RunService:IsServer() then
		isLegacy = waypointsFolder:FindFirstChild("Start") ~= nil
		pathCount = 0
		local seenIds = {}
		for _, child in waypointsFolder:GetChildren() do
			if child:IsA("Folder") then
				assert(not isLegacy, "Do not mix legacy waypoints with numbered path folders")
				local id = tonumber(child.Name)
				assert(
					id and id >= 1 and id <= 255 and id % 1 == 0 and tostring(id) == child.Name,
					"Path folders must be named 1, 2, 3, ... (up to 255)"
				)
				assert(not seenIds[id], `Duplicate path folder: {id}`)
				seenIds[id] = true
				pathCount += 1
			end
		end
		if isLegacy then
			pathCount = 1
		else
			for id = 1, pathCount do
				assert(seenIds[id], `Missing path folder: {id}; use consecutive IDs starting at 1`)
			end
		end
		assert(pathCount > 0, "No paths found in Waypoints")
	else
		-- The manifest prevents partially replicated folders from becoming a partial path list.
		pathCount = waitForAttribute(waypointsFolder, "PathCount")
		isLegacy = waitForAttribute(waypointsFolder, "UsesLegacyPath")
	end

	local paths = {}
	for id = 1, pathCount do
		local folder = isLegacy and waypointsFolder or waitForChild(waypointsFolder, tostring(id))
		paths[id] = buildPath(folder)
	end

	GetPath.Paths = paths
	GetPath.PathCount = pathCount
	GetPath.CachedPath = paths[1]
	GetPath.PathLength = GetPath.CachedPath:GetPathLength()
	if RunService:IsServer() then
		waypointsFolder:SetAttribute("UsesLegacyPath", isLegacy)
		waypointsFolder:SetAttribute("PathCount", pathCount)
	end

	if RunService:IsClient() then
		Guide.Init(GetPath)
	end

	return GetPath.CachedPath
end

return GetPath
