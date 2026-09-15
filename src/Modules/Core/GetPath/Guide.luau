--/Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

--/Modules
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local TimeService

-------------------------------------------------
--// Guide Configuration & State
-------------------------------------------------
local Guide = {}
local GetPathModule = nil
local activeArrows = {}
local originalTransparencies = {}
local renderConnection = nil
local isShowing = false

local SPEED = 15
local SPACING = 25
local CLUSTER_OFFSET = 1.25
local HEIGHT_OFFSET = 0.05
local FADE_DURATION = 0.5

local assetsFolder = ReplicatedStorage:WaitForChild("Assets", 5)
local visualsFolder = assetsFolder and assetsFolder:WaitForChild("Visuals", 5)
local arrowTemplate = visualsFolder and visualsFolder:WaitForChild("Arrow", 5)

if not arrowTemplate then
	warn("[경로 안내] 화살표 템플릿을 찾을 수 없습니다: ReplicatedStorage.Assets.Visuals.Arrow")
end

-------------------------------------------------
--// Local Functions
-------------------------------------------------
local function positionArrow(arrow: Instance, cframe: CFrame)
	if arrow:IsA("Model") then
		arrow:PivotTo(cframe)
	elseif arrow:IsA("BasePart") then
		arrow.CFrame = cframe
	end
end

local function setupArrowForFade(arrow: Instance)
	local function recordAndHide(instance: Instance)
		if instance:IsA("BasePart") then
			originalTransparencies[instance] = instance.Transparency
			instance.Transparency = 1
		end
		for _, child in ipairs(instance:GetChildren()) do
			recordAndHide(child)
		end
	end
	recordAndHide(arrow)
end

local function fadeArrow(arrow: Instance, isFadeOut: boolean, duration: number)
	local function applyFade(instance: Instance)
		if instance:IsA("BasePart") then
			local targetTransparency = isFadeOut and 1 or (originalTransparencies[instance] or 0)
			TweenService:Create(instance, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Transparency = targetTransparency,
			}):Play()
		end
		for _, child in ipairs(instance:GetChildren()) do
			applyFade(child)
		end
	end
	applyFade(arrow)
end

local function cleanArrowTransparencies(arrow: Instance)
	local function clean(instance: Instance)
		if instance:IsA("BasePart") then
			originalTransparencies[instance] = nil
		end
		for _, child in ipairs(instance:GetChildren()) do
			clean(child)
		end
	end
	clean(arrow)
end

-------------------------------------------------
--// Public API
-------------------------------------------------
function Guide.Init(getPathModule)
	GetPathModule = getPathModule
end

function Guide.Start()
	if isShowing then
		return
	end
	isShowing = true

	if not GetPathModule:Get() then
		warn("[경로 안내] 경로가 아직 로드되지 않았습니다.")
		isShowing = false
		return
	end

	for _, arrow in ipairs(activeArrows) do
		cleanArrowTransparencies(arrow)
		arrow:Destroy()
	end
	table.clear(activeArrows)

	local pathGroups = {}
	for _, pathId in ipairs(GetPathModule:GetSpawnPathIds()) do
		local path = GetPathModule:Get(pathId)
		local pathLength = path:GetPathLength()
		local arrows = {}
		table.insert(pathGroups, { Path = path, Length = pathLength, Arrows = arrows })
		local numGroups = math.max(3, math.floor(pathLength / SPACING))
		for _ = 1, numGroups do
			for _ = 0, 2 do
				local arrow = arrowTemplate:Clone()
				setupArrowForFade(arrow)
				arrow.Parent = workspace.Visuals
				table.insert(activeArrows, arrow)
				table.insert(arrows, arrow)
				fadeArrow(arrow, false, FADE_DURATION)
			end
		end
	end

	TimeService = TimeService or ServiceRegistry:GetService("TimeService")

	local distanceTravelled = 0
	renderConnection = RunService.PreRender:Connect(function(dt)
		distanceTravelled += dt * SPEED * TimeService:GetGameSpeed()

		for _, group in ipairs(pathGroups) do
			local path = group.Path
			local pathLength = group.Length
			for k, arrow in ipairs(group.Arrows) do
				local i = math.ceil(k / 3)
				local j = (k - 1) % 3

				local mainDistance = (i - 1) * SPACING + distanceTravelled
				local arrowDistance = (mainDistance - j * CLUSTER_OFFSET) % pathLength
				if arrowDistance < 0 then
					arrowDistance += pathLength
				end

				local alpha = arrowDistance / pathLength
				local targetCFrame = path:CalculateUniformCFrame(alpha)
				local finalCFrame = (targetCFrame + Vector3.new(0, HEIGHT_OFFSET, 0)) * CFrame.Angles(0, math.rad(-90), 0)

				positionArrow(arrow, finalCFrame)
			end
		end
	end)
end

function Guide.Stop()
	if not isShowing then
		return
	end
	isShowing = false

	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end

	local arrowsToDestroy = activeArrows
	activeArrows = {}

	for _, arrow in ipairs(arrowsToDestroy) do
		task.spawn(function()
			fadeArrow(arrow, true, FADE_DURATION)
			task.wait(FADE_DURATION)
			cleanArrowTransparencies(arrow)
			arrow:Destroy()
		end)
	end
end

return Guide
