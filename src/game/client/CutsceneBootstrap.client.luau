local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")
local CameraRuntime = require(ReplicatedStorage.Shared.Modules.Cutscene.ECS.CameraRuntime)
local Prepare = require(ReplicatedStorage.Shared.Modules.Cutscene.Prepare)
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local active = nil

local function attach(state)
	if state.Name ~= "ActiveCutscene" or active == state then return end
	active = state
	local reference = state:WaitForChild("CameraPart", 10)
	local ready = state:WaitForChild("CameraReady", 10)
	if not reference or not ready then active = nil; return end
	ready:FireServer("Stage", "Waiting for CamPart replication")
	while state.Parent and not reference.Value do RunService.Heartbeat:Wait() end
	if not state.Parent then active = nil; return end
	local config = require(ReplicatedStorage.Settings.Data.CutsceneData)[state:GetAttribute("CutsceneName")]
	local animations = {}
	ready:FireServer("Stage", "Animation asset preload")
	if config then
		for _, id in config.Animations do
			local animation = Instance.new("Animation")
			animation.AnimationId = "rbxassetid://" .. id
			table.insert(animations, animation)
		end
		Prepare.Try("Animation preload", 8, function() ContentProvider:PreloadAsync(animations) end)
		for _, animation in animations do animation:Destroy() end
	end
	if not state.Parent then active = nil; return end
	local rigTracks = state:WaitForChild("RigTracks", 10)
	if not rigTracks then active = nil; return end
	local tracks = {}
	local trackDeadline = os.clock() + 30
	local lastCount = -1
	-- Content download alone does not mean replicated Animator tracks are ready.
	while state.Parent do
		table.clear(tracks)
		for _, referenceValue in rigTracks:GetChildren() do
			local animator = referenceValue.Value
			local expectedId = referenceValue:GetAttribute("AnimationId")
			if animator then
				for _, track in animator:GetPlayingAnimationTracks() do
					local animation = track.Animation
					if animation and animation.AnimationId:match("%d+") == expectedId and track.Length > 0 then
						table.insert(tracks, track)
						break
					end
				end
			end
		end
		if #tracks > 0 and #tracks == state:GetAttribute("TrackCount") then break end
		if lastCount ~= #tracks then
			lastCount = #tracks
			ready:FireServer("Stage", "Replicated animation tracks " .. #tracks .. "/" .. tostring(state:GetAttribute("TrackCount")))
		end
		assert(os.clock() < trackDeadline, "Replicated animation tracks missing: " .. #tracks .. "/" .. tostring(state:GetAttribute("TrackCount")))
		RunService.Heartbeat:Wait()
	end
	if not state.Parent then active = nil; return end
	local camera = workspace.CurrentCamera
	while not camera do
		RunService.Heartbeat:Wait()
		camera = workspace.CurrentCamera
	end
	local savedType, savedSubject = camera.CameraType, camera.CameraSubject
	local savedCFrame, savedFocus = camera.CFrame, camera.Focus
	local savedFOV = camera.FieldOfView
	ready:FireServer("Stage", "Audio/VFX initialization")
	local runtime = CameraRuntime.new(state, reference, config, tracks)
	if not state.Parent then runtime:Destroy(); active = nil; return end
	local playbackConnection = RunService.PreAnimation:Connect(function()
		runtime:PreAnimation()
	end)
	local covers = {}
	RunService:BindToRenderStep("ServerCutsceneCamera", Enum.RenderPriority.Camera.Value + 1, function()
		runtime:Step()
		for _, gui in playerGui:GetChildren() do
			if gui:IsA("ScreenGui") and (gui.Name == "LoadingScreen" or gui.Name == "LoadingBootstrap") then
				if covers[gui] == nil then covers[gui] = gui.Enabled end
				gui.Enabled = false
			end
		end
	end)
	RunService.RenderStepped:Wait()
	ready:FireServer()
	while state.Parent do RunService.Heartbeat:Wait() end
	playbackConnection:Disconnect()
	RunService:UnbindFromRenderStep("ServerCutsceneCamera")
	runtime:Destroy()
	if workspace.CurrentCamera then
		workspace.CurrentCamera.CameraType = savedType
		workspace.CurrentCamera.CameraSubject = savedSubject
		workspace.CurrentCamera.CFrame = savedCFrame
		workspace.CurrentCamera.Focus = savedFocus
		workspace.CurrentCamera.FieldOfView = savedFOV
	end
	for gui, enabled in covers do if gui.Parent then gui.Enabled = enabled end end
	active = nil
end

local function start(child)
	local ok, err = xpcall(attach, debug.traceback, child)
	if not ok then
		warn("[CutsceneBootstrap] " .. tostring(err))
		local ready = child:FindFirstChild("CameraReady")
		if ready then ready:FireServer("Failed", tostring(err)) end
		if active == child then active = nil end
	end
end
ReplicatedStorage.ChildAdded:Connect(function(child) task.spawn(start, child) end)
local current = ReplicatedStorage:FindFirstChild("ActiveCutscene")
if current then task.spawn(start, current) end
