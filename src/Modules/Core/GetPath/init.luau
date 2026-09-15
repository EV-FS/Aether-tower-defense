local BezierPath = require(script.Parent.BezierPath)
local RunService = game:GetService("RunService")

local Guide = require(script.Guide)

local GetPath = {}
GetPath.CachedPath = nil
GetPath.PathLength = 0

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

function GetPath:Get()
	local startedAt = os.clock()
	while not self.CachedPath do
		if os.clock() - startedAt > 60 then
			warn("경로 로드 타임아웃.")
			return nil
		end

		task.wait(0.1)
	end

	return self.CachedPath
end

function GetPath.Init()
	local Positions = {}
	local mapFolder = workspace:WaitForChild("Map", 30)
	local waypointsFolder = mapFolder:WaitForChild("Waypoints", 30)
	local start = waypointsFolder:WaitForChild("Start", 30)

	local nextNode = start
	while true do
		table.insert(Positions, nextNode.Position)
		if nextNode.Name == "End" then
			break
		end

		local nextValue = nextNode:WaitForChild("Next")
		if not nextValue.Value then
			nextValue:GetPropertyChangedSignal("Value"):Wait()
		end

		nextNode = nextValue.Value
	end

	GetPath.CachedPath = BezierPath.new(Positions, 3.5)
	GetPath.PathLength = GetPath.CachedPath:GetPathLength()

	if RunService:IsClient() then
		Guide.Init(GetPath)
	end

	return GetPath.CachedPath
end

return GetPath
