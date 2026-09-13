local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CameraRuntime = require(ReplicatedStorage.Shared.Modules.Cutscene.ECS.CameraRuntime)
local ClientRigTracks = require(ReplicatedStorage.Shared.Modules.Cutscene.ClientRigTracks)
local Cleanup = require(ReplicatedStorage.Shared.Modules.Cutscene.Cleanup)
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local active = nil
local activeCleanup = nil

local function attach(state)
	if state.Name ~= "ActiveCutscene" or active == state then return end
	active = state
	local reference = state:WaitForChild("CameraPart", 10)
	local ready = state:WaitForChild("CameraReady", 10)
	if not reference or not ready then active = nil; return end
	ready:FireServer("Stage", "Waiting for CamPart replication")
	local cameraDeadline = os.clock() + 30
	while state.Parent and not reference.Value do
		assert(os.clock() < cameraDeadline, "CamPart replication timed out")
		RunService.Heartbeat:Wait()
	end
	if not state.Parent then active = nil; return end
	local config = require(ReplicatedStorage.Settings.Data.CutsceneData)[state:GetAttribute("CutsceneName")]
	ready:FireServer("Stage", "Waiting for loaded animation tracks")
	local rigTracks = ClientRigTracks.new(state)
	activeCleanup = function() rigTracks:Destroy() end
	local tracks = rigTracks:Prepare(ready)
	if not state.Parent then rigTracks:Destroy(); active = nil; activeCleanup = nil; return end
	local camera = workspace.CurrentCamera
	while not camera do
		assert(state.Parent and os.clock() < cameraDeadline, "CurrentCamera unavailable")
		RunService.Heartbeat:Wait()
		camera = workspace.CurrentCamera
	end
	local savedType, savedSubject = camera.CameraType, camera.CameraSubject
	local savedCFrame, savedFocus = camera.CFrame, camera.Focus
	local savedFOV = camera.FieldOfView
	ready:FireServer("Stage", "Audio/VFX/impact/screen effect initialization")
	local runtime = CameraRuntime.new(state, reference, config, tracks)
	if not state.Parent then runtime:Destroy(); rigTracks:Destroy(); active = nil; activeCleanup = nil; return end
	local playbackConnection = nil
	local covers = {}
	local cleaned = false
	local function cleanup()
		if cleaned then return end
		cleaned = true
		if playbackConnection then playbackConnection:Disconnect() end
		RunService:UnbindFromRenderStep("ServerCutsceneCamera")
		Cleanup.Try("Client runtime", function() runtime:Destroy() end)
		Cleanup.Try("Client rig tracks", function() rigTracks:Destroy() end)
		Cleanup.Try("Camera restore", function()
			if workspace.CurrentCamera then
				workspace.CurrentCamera.CameraType = savedType
				workspace.CurrentCamera.CameraSubject = savedSubject
				workspace.CurrentCamera.CFrame = savedCFrame
				workspace.CurrentCamera.Focus = savedFocus
				workspace.CurrentCamera.FieldOfView = savedFOV
			end
		end)
		for gui, enabled in covers do if gui.Parent then gui.Enabled = enabled end end
		if active == state then active = nil; activeCleanup = nil end
	end
	activeCleanup = cleanup
	local callbackError = nil
	local function guard(callback)
		if cleaned or callbackError then return end
		local ok, err = xpcall(callback, debug.traceback)
		if not ok then callbackError = err end
	end
	playbackConnection = RunService.PreAnimation:Connect(function()
		guard(function() runtime:PreAnimation() end)
	end)
	RunService:BindToRenderStep("ServerCutsceneCamera", Enum.RenderPriority.Camera.Value + 1, function()
		guard(function()
			runtime:Step()
			for _, gui in playerGui:GetChildren() do
				if gui:IsA("ScreenGui") and (gui.Name == "LoadingScreen" or gui.Name == "LoadingBootstrap") then
					if covers[gui] == nil then covers[gui] = gui.Enabled end
					gui.Enabled = false
				end
			end
		end)
	end)
	RunService.RenderStepped:Wait()
	assert(not callbackError, tostring(callbackError))
	ready:FireServer()
	while state.Parent and not callbackError do RunService.Heartbeat:Wait() end
	assert(not callbackError, tostring(callbackError))
	cleanup()
end

local function start(child)
	local ok, err = xpcall(attach, debug.traceback, child)
	if not ok then
		if active == child and activeCleanup then Cleanup.Try("Bootstrap failure", activeCleanup) end
		warn("[CutsceneBootstrap] " .. tostring(err))
		local ready = child:FindFirstChild("CameraReady")
		if ready then ready:FireServer("Failed", tostring(err)) end
		if active == child then active = nil end
	end
end
ReplicatedStorage.ChildAdded:Connect(function(child) task.spawn(start, child) end)
local current = ReplicatedStorage:FindFirstChild("ActiveCutscene")
if current then task.spawn(start, current) end
