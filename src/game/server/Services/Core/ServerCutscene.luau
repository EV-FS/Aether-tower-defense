local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Data = require(ReplicatedStorage.Settings.Data.CutsceneData)
local PlaybackClock = require(ReplicatedStorage.Shared.Modules.Cutscene.PlaybackClock)
local ScenePaths = require(ReplicatedStorage.Shared.Modules.Cutscene.ScenePaths)
local SceneLifecycle = require(script.Parent.SceneLifecycle)
local ServerCutscene = {}

function ServerCutscene.Play(name: string)
	local config = assert(Data[name], "Unknown cutscene: " .. name)
	local roots, tracks, animations = {}, {}, {}
	local playbackConnection = nil
	local streamingContainer = nil
	local staging = nil
	local state = Instance.new("Folder")
	state.Name = "ActiveCutscene"
	state:SetAttribute("CutsceneName", name)
	local cameraValue = Instance.new("ObjectValue")
	cameraValue.Name = "CameraPart"
	cameraValue.Parent = state
	local ready = Instance.new("RemoteEvent")
	ready.Name = "CameraReady"
	ready.Parent = state
	local rigTracks = Instance.new("Folder")
	rigTracks.Name = "RigTracks"
	rigTracks.Parent = state
	local sceneRoots = Instance.new("Folder")
	sceneRoots.Name = "SceneRoots"
	sceneRoots.Parent = state
	local acknowledged = {}
	local stages, failures = {}, {}
	local connection = ready.OnServerEvent:Connect(function(player, kind, detail)
		if kind == nil then
			acknowledged[player] = true
		elseif (kind == "Stage" or kind == "Failed") and type(detail) == "string" then
			stages[player] = string.sub(detail, 1, 500)
			if kind == "Failed" then failures[player] = stages[player] end
		end
	end)
	local success, err = xpcall(function()
		local source = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Cutscenes")
		for _, segment in config.ScenePath do
			source = assert(source:WaitForChild(segment, 10), "Missing cutscene folder: " .. segment)
		end
		-- Clone together to preserve references between sibling rigs and objects.
		local clone = SceneLifecycle.Clone(source)
		staging = clone
		local rigParts = {}
		local atomicRoots = {}
		for targetName in config.Animations do
			local rig = clone:FindFirstChild(targetName, true)
			if rig then
				atomicRoots[rig] = true
				SceneLifecycle.Visit({ rig }, function(instance)
					if instance:IsA("BasePart") then rigParts[instance] = true end
				end)
			end
		end
		-- Cutscene assets are scenery, not gameplay actors or spawn points.
		SceneLifecycle.Visit({ clone }, function(instance)
			if instance:IsA("BaseScript") then instance.Enabled = false end
			if instance:IsA("SpawnLocation") then instance.Enabled = false end
			if instance:IsA("BasePart") then
				instance.CanCollide = false
				instance.CanTouch = false
				-- Loose effect parts must not fall below FallenPartsDestroyHeight
				-- while clients prepare. Animated rigs retain their joint setup.
				if not rigParts[instance] then instance.Anchored = true end
			end
		end)
		for targetName in config.Animations do
			local rig = clone:FindFirstChild(targetName, true)
			if rig and rig:IsA("Model") then
				local root = rig:FindFirstChild("HumanoidRootPart") or rig.PrimaryPart
				if not root then
					local motor = rig:FindFirstChildWhichIsA("Motor6D", true)
					root = motor and motor.Part0
				end
				assert(root, "Missing rig root: " .. targetName)
				root.Anchored = true
			end
		end
		if workspace.StreamingEnabled then
			streamingContainer = Instance.new("Model")
			streamingContainer.Name = "CutsceneScene_" .. name
			streamingContainer.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
			streamingContainer.Parent = workspace -- mount into an empty container incrementally
		end
		roots = clone:GetChildren()
		for _, root in roots do
			if root:IsA("Model") then root.ModelStreamingMode = Enum.ModelStreamingMode.Persistent end
		end
		SceneLifecycle.Mount(clone, streamingContainer or workspace, atomicRoots)
		staging = nil
		for _, root in roots do
			local sceneReference = Instance.new("ObjectValue")
			sceneReference.Name = root.Name
			sceneReference.Value = root
			sceneReference.Parent = sceneRoots
		end
		SceneLifecycle.Visit(roots, function(part)
			if part:IsA("BasePart") and not part.Anchored and part:CanSetNetworkOwnership() then
				part:SetNetworkOwner(nil)
			end
		end)
		-- Bind concrete targets on the server, including unique nested shorthand.
		-- ObjectValues let clients distinguish absent assets from pending replication.
		local targets = Instance.new("Folder")
		targets.Name = "VFXTargets"
		local targetCount = 0
		for key, path in ScenePaths.Collect(config.VFX and config.VFX.Events) do
			targetCount += 1
			local target, reason = ScenePaths.Resolve(roots, path)
			local reference = Instance.new("ObjectValue")
			reference.Name = tostring(targetCount)
			reference:SetAttribute("PathKey", key)
			if target then
				reference.Value = target
				reference:SetAttribute("DescendantCount", #target:GetDescendants())
			else
				reference:SetAttribute("Unavailable", reason)
				warn("[ServerCutscene] " .. name .. ": " .. reason .. "; fix the asset/path in CutsceneTracks")
			end
			reference.Parent = targets
		end
		state:SetAttribute("VFXTargetCount", targetCount)
		targets.Parent = state
		local function find(targetName)
			for _, root in roots do
				local result = if root.Name == targetName then root else root:FindFirstChild(targetName, true)
				if result then return result end
			end
			return nil
		end
		local cameraModel = assert(find(config.Camera.Model), "Missing camera model")
		local part = assert(cameraModel:FindFirstChild(config.Camera.Part, true), "Missing CamPart")
		assert(part:IsA("BasePart"), "CamPart must be a BasePart")
		cameraValue.Value = part
		for targetName, id in config.Animations do
			local model = assert(find(targetName), "Missing rig: " .. targetName)
			local host = model:FindFirstChildWhichIsA("Humanoid", true)
				or model:FindFirstChildWhichIsA("AnimationController", true)
			if not host then
				host = Instance.new("AnimationController")
				host.Parent = model
			end
			local animator = host:FindFirstChildOfClass("Animator") or Instance.new("Animator")
			animator.Parent = host
			local animatorReference = Instance.new("ObjectValue")
			animatorReference.Name = targetName
			animatorReference.Value = animator
			animatorReference:SetAttribute("AnimationId", tostring(id))
			animatorReference.Parent = rigTracks
			local animation = Instance.new("Animation")
			animation.AnimationId = "rbxassetid://" .. id
			table.insert(animations, animation)
			local track = animator:LoadAnimation(animation)
			if targetName == config.Camera.Model then
				track.Name = "CutsceneCameraTrack"
			end
			track.Looped = false
			track.Priority = Enum.AnimationPriority.Action4
			table.insert(tracks, track)
		end
		assert(#tracks > 0, "Cutscene has no animations")
		local deadline = os.clock() + 20
		repeat
			local loaded = true
			for _, track in tracks do loaded = loaded and track.Length > 0 end
			if loaded then break end
			assert(os.clock() < deadline, "Animation load timed out; check animation permissions")
			RunService.Heartbeat:Wait()
		until false
		local duration = 0
		for _, track in tracks do
			duration = math.max(duration, track.Length)
			if track.Name == "CutsceneCameraTrack" then
				state:SetAttribute("CameraDuration", track.Length)
			end
			-- Replicate every paused track before clients acknowledge readiness.
			track:Play(0, 1, 0)
			track.TimePosition = 0
		end
		state:SetAttribute("TrackCount", #tracks)
		state.Parent = ReplicatedStorage
		deadline = os.clock() + 60
		repeat
			local audience = Players:GetPlayers()
			local allReady = #audience > 0
			local pending = {}
			for _, player in audience do
				assert(not failures[player], player.Name .. ": " .. tostring(failures[player]))
				if not acknowledged[player] then
					allReady = false
					table.insert(pending, player.Name .. ": " .. (stages[player] or "No bootstrap response"))
				end
			end
			if allReady then break end
			assert(os.clock() < deadline, "Cutscene preparation timed out: " .. table.concat(pending, "; "))
			RunService.Heartbeat:Wait()
		until false
		-- Give the shared start timestamp time to reach the prepared clients.
		state:SetAttribute("StartedAt", workspace:GetServerTimeNow() + 0.5)
		playbackConnection = RunService.PreAnimation:Connect(function()
			PlaybackClock.Apply(tracks, PlaybackClock.Elapsed(state, workspace:GetServerTimeNow()))
		end)
		while PlaybackClock.Elapsed(state, workspace:GetServerTimeNow()) < duration do
			RunService.Heartbeat:Wait()
		end
	end, debug.traceback)
	connection:Disconnect()
	if playbackConnection then playbackConnection:Disconnect() end
	state:Destroy()
	for _, track in tracks do
		track:Stop(0)
		track:Destroy()
	end
	for _, animation in animations do animation:Destroy() end
	SceneLifecycle.Destroy(roots)
	if staging then SceneLifecycle.Destroy({ staging }) end
	if streamingContainer then streamingContainer:Destroy() end
	if not success then error(err, 0) end
end

return ServerCutscene
