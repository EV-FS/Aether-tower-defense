local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Data = require(ReplicatedStorage.Settings.Data.CutsceneData)
local CutsceneValidator = require(ReplicatedStorage.Shared.Modules.Cutscene.CutsceneValidator)
local PlaybackClock = require(ReplicatedStorage.Shared.Modules.Cutscene.PlaybackClock)
local ScenePaths = require(ReplicatedStorage.Shared.Modules.Cutscene.ScenePaths)
local SceneTransform = require(ReplicatedStorage.Shared.Modules.Cutscene.SceneTransform)
local SceneLifecycle = require(script.Parent.SceneLifecycle)
local CutsceneProfiles = require(script.Parent.CutsceneProfiles)
local Cleanup = require(ReplicatedStorage.Shared.Modules.Cutscene.Cleanup)
local ServerCutscene = {}

function ServerCutscene.Play(name: string, prepareNext)
	local config = assert(Data[name], "Unknown cutscene: " .. name)
	assert(CutsceneValidator.Validate(name, config))
	local fastMount = config.Lifecycle and config.Lifecycle.FastMount
	local fastCleanup = config.Lifecycle and config.Lifecycle.FastCleanup
	local roots, tracks, animations = {}, {}, {}
	local playbackTracks = {}
	local playbackConnection = nil
	local streamingContainer = nil
	local staging = nil
	local stopProfiles = nil
	local state = Instance.new("Folder")
	state.Name = "ActiveCutscene"
	state:SetAttribute("CutsceneName", name)
	local currentPhase = "Scene setup"
	local phaseStarted = os.clock()
	local function phase(value)
		print(string.format("[ServerCutscene] %s: %s -> %s (%.2fs)", name, currentPhase, value, os.clock() - phaseStarted))
		phaseStarted = os.clock()
		currentPhase = value
		state:SetAttribute("Phase", value)
		ReplicatedStorage:SetAttribute("CutscenePhase", value)
	end
	ReplicatedStorage:SetAttribute("CutsceneError", nil)
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
		phase("Scene setup")
		if config.Actors then stopProfiles = CutsceneProfiles.Begin(state, config.Actors) end
		local source = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Cutscenes")
		for _, segment in config.ScenePath do
			source = assert(source:WaitForChild(segment, 10), "Missing cutscene folder: " .. segment)
		end
		-- Clone together to preserve references between sibling rigs and objects.
		local clone = SceneLifecycle.Clone(source)
		staging = clone
		SceneTransform.Apply(clone, config.SceneTransform)
		local function visit(targets, callback)
			if not fastMount then
				SceneLifecycle.Visit(targets, callback)
				return
			end
			-- Fast lifecycle explicitly trades a short spike for removing seconds of
			-- frame-budget waits before the intro can begin.
			for _, target in targets do
				callback(target)
				for _, descendant in target:GetDescendants() do callback(descendant) end
			end
		end
		-- Never guess which duplicate PlayerRig is the newly authored actor.
		local modelCounts = {}
		visit({ clone }, function(instance)
			if instance:IsA("Model") then modelCounts[instance.Name] = (modelCounts[instance.Name] or 0) + 1 end
		end)
		for targetName in config.Animations do
			local matches = modelCounts[targetName] or 0
			assert(matches == 1, "Expected exactly one cutscene model named " .. targetName .. "; found " .. matches)
		end
		local rigParts = {}
		local atomicRoots = {}
		for targetName in config.Animations do
			local rig = clone:FindFirstChild(targetName, true)
			if rig then
				atomicRoots[rig] = true
				visit({ rig }, function(instance)
					if instance:IsA("BasePart") then rigParts[instance] = true end
				end)
			end
		end
		-- Cutscene assets are scenery, not gameplay actors or spawn points.
		visit({ clone }, function(instance)
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
				root = root or rig:FindFirstChildWhichIsA("BasePart", true)
				assert(root and root:IsA("BasePart"), "Missing rig root: " .. targetName)
				root.Anchored = true
			end
		end
		phase("Scene mount")
		if workspace.StreamingEnabled or fastMount then
			streamingContainer = Instance.new("Model")
			streamingContainer.Name = "CutsceneScene_" .. name
			streamingContainer.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
			if not fastMount then streamingContainer.Parent = workspace end
		end
		roots = clone:GetChildren()
		for _, root in roots do
			if root:IsA("Model") then root.ModelStreamingMode = Enum.ModelStreamingMode.Persistent end
		end
		if fastMount then
			-- Preserve complete rig/model trees; no leaf detachment or per-part waits.
			-- Requested tradeoff: one replication/physics spike instead of a long mount.
			for _, root in roots do root.Parent = streamingContainer end
			clone:Destroy() -- now-empty wrapper, not source assets
			streamingContainer.Parent = workspace
		else
			SceneLifecycle.Mount(clone, streamingContainer or workspace, atomicRoots)
		end
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
		local trackLabels, optionalTracks = {}, {}
		phase("Server animations")
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
			animatorReference:SetAttribute("Optional", config.Actors and config.Actors[targetName] ~= nil)
			local modelReference = Instance.new("ObjectValue")
			modelReference.Name = "Model"
			modelReference.Value = model
			modelReference.Parent = animatorReference
			animatorReference.Parent = rigTracks
			local animation = Instance.new("Animation")
			animation.AnimationId = "rbxassetid://" .. id
			table.insert(animations, animation)
			local track = animator:LoadAnimation(animation)
			trackLabels[track] = targetName .. " (" .. tostring(id) .. ")"
			optionalTracks[track] = config.Actors and config.Actors[targetName] ~= nil or false
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
			local pending = {}
			for _, track in tracks do
				if track.Length <= 0 and not optionalTracks[track] then table.insert(pending, trackLabels[track]) end
			end
			if #pending == 0 then break end
			assert(os.clock() < deadline, "Animation load timed out; check asset permissions: " .. table.concat(pending, ", "))
			RunService.Heartbeat:Wait()
		until false
		for _, track in tracks do
			if track.Length <= 0 then
				warn("[ServerCutscene] Optional animation unavailable; using static authored actor: " .. trackLabels[track])
				continue
			end
			if track.Name == "CutsceneCameraTrack" then
				state:SetAttribute("CameraDuration", track.Length)
			end
			-- Replicate every paused track before clients acknowledge readiness.
			track:Play(0, 1, 0)
			track.TimePosition = 0
			table.insert(playbackTracks, track)
		end
		-- The camera defines the shot, not a longer character animation's idle tail.
		local duration = PlaybackClock.Duration(state:GetAttribute("CameraDuration"), config.MaxDuration)
		state:SetAttribute("Duration", duration)
		local requiredTrackCount = 0
		for _, reference in rigTracks:GetChildren() do
			if not reference:GetAttribute("Optional") then requiredTrackCount += 1 end
		end
		state:SetAttribute("TrackCount", requiredTrackCount)
		state.Parent = ReplicatedStorage
		-- Clients can preload the intro concurrently with off-world map preparation.
		-- Do not start the animation clock until preparation has finished (no Clone
		-- spike mid-animation). The next map is still NOT mounted into Workspace.
		phase("Off-world map preparation")
		if prepareNext then prepareNext() end
		phase("Client preparation")
		deadline = os.clock() + 60
		local nextReport = os.clock() + 5
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
			if os.clock() >= nextReport then
				warn("[ServerCutscene] Waiting for clients: " .. table.concat(pending, "; "))
				nextReport = os.clock() + 5
			end
			assert(os.clock() < deadline, "Cutscene preparation timed out: " .. table.concat(pending, "; "))
			RunService.Heartbeat:Wait()
		until false
		-- Give the shared start timestamp time to reach the prepared clients.
		state:SetAttribute("StartedAt", workspace:GetServerTimeNow() + 0.5)
		phase("Playing")
		local playbackError = nil
		playbackConnection = RunService.PreAnimation:Connect(function()
			if playbackError then return end
			local ok, failure = pcall(PlaybackClock.Apply, playbackTracks, PlaybackClock.Elapsed(state, workspace:GetServerTimeNow()))
			if not ok then playbackError = failure end
		end)
		while PlaybackClock.Elapsed(state, workspace:GetServerTimeNow()) < duration do
			assert(not playbackError, tostring(playbackError))
			for player, failure in failures do
				if player.Parent == Players then error(player.Name .. ": " .. failure) end
			end
			RunService.Heartbeat:Wait()
		end
		ReplicatedStorage:SetAttribute("CutsceneEndedAt", workspace:GetServerTimeNow())
	end, debug.traceback)
	local failedPhase = currentPhase
	local cleanupStarted = os.clock()
	phase("Cleanup")
	Cleanup.Try("Ready listener", function() connection:Disconnect() end)
	if stopProfiles then Cleanup.Try("Profiles", stopProfiles) end
	if playbackConnection then Cleanup.Try("Playback listener", function() playbackConnection:Disconnect() end) end
	Cleanup.Try("Replicated session", function() state:Destroy() end)
	for _, track in tracks do
		Cleanup.Try("Stop rig animation", function() track:Stop(0) end)
		Cleanup.Try("Destroy rig animation", function() track:Destroy() end)
	end
	for _, animation in animations do Cleanup.Try("Animation asset", function() animation:Destroy() end) end
	if fastCleanup then
		-- Delete the owned container as a unit, including Models/Folders, not leaves
		-- spread over many frames. Never search/delete similarly named source assets.
		if streamingContainer then Cleanup.Try("Fast scene container", function() streamingContainer:Destroy() end) end
		for _, root in roots do Cleanup.Try("Fast owned root", function() root:Destroy() end) end
		if staging then Cleanup.Try("Fast staging scene", function() staging:Destroy() end); staging = nil end
	elseif not Cleanup.Try("Scene roots", function() SceneLifecycle.Destroy(roots, true) end) then
		for _, root in roots do
			if not Cleanup.Try("Retry scene root " .. root.Name, function() SceneLifecycle.Destroy({ root }, true) end) then
				-- Emergency path only: owned clone, never source assets or arbitrary Workspace models.
				Cleanup.Try("Remove failed owned root", function() root:Destroy() end)
			end
		end
	end
	if staging then Cleanup.Try("Staging scene", function() SceneLifecycle.Destroy({ staging }) end) end
	if streamingContainer then Cleanup.Try("Streaming container", function() streamingContainer:Destroy() end) end
	ReplicatedStorage:SetAttribute("CutsceneCleanupSeconds", os.clock() - cleanupStarted)
	ReplicatedStorage:SetAttribute("CutscenePhase", if success then "Finished" else "Failed: " .. failedPhase)
	if not success then
		local detail = "[" .. failedPhase .. "] " .. tostring(err)
		ReplicatedStorage:SetAttribute("CutsceneError", string.sub(detail, 1, 1000))
		error(detail, 0)
	end
end

return ServerCutscene
