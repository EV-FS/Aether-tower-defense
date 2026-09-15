local ContentProvider = game:GetService("ContentProvider")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CutsceneData = require(ReplicatedStorage.Settings.Data.CutsceneData)
local PlaybackClock = require(script.Parent.PlaybackClock)
local SampleTrack = require(script.Parent.ECS.SampleTrack)

local CUTSCENE_ROOT = { "Assets", "Cutscenes" }
local RENDER_STEP_NAME = "CutsceneCamera"
local FOCUS_ACTION_NAME = "CutsceneFocusControls"
local CUTSCENE_LOAD_TIMEOUT = 15

local CutscenePlayer = {}

local activeToken = 0
local activeScene: { Instance }? = nil
local activeTracks: { AnimationTrack }? = nil
local savedCameraState = nil
local activeTimingConnection: RBXScriptConnection? = nil
local focusRestoreCallbacks: { () -> () }? = nil
local focusConnections: { RBXScriptConnection }? = nil
local activeTimeline = nil
local preloadedCutscenes = {}
local preloadingCutscenes = {}

export type PlaybackOptions = {
	FrameCallbacks: { [number]: () -> () }?,
	PauseFrames: { [number]: boolean }?,
}

local function findPath(root: Instance, path: { string }): Instance?
	local current = root
	for _, name in ipairs(path) do
		local child = current:WaitForChild(name, 10)
		if not child then
			return nil
		end
		current = child
	end
	return current
end

local function findInScene(sceneRoots: { Instance }, name: string): Instance?
	for _, root in ipairs(sceneRoots) do
		if root.Name == name then
			return root
		end

		local descendant = root:FindFirstChild(name, true)
		if descendant then
			return descendant
		end
	end
	return nil
end

local function getAnimator(model: Model): Animator
	local animator = model:FindFirstChildWhichIsA("Animator", true)
	if animator then
		return animator
	end

	local animationHost = model:FindFirstChildWhichIsA("Humanoid", true)
		or model:FindFirstChildWhichIsA("AnimationController", true)

	if not animationHost then
		local animationController = Instance.new("AnimationController")
		animationController.Name = "CutsceneAnimationController"
		animationController.Parent = model
		animationHost = animationController
	end

	animator = Instance.new("Animator")
	animator.Parent = animationHost
	return animator
end

local function cloneScene(sceneSource: Instance): { Instance }
	local sceneRoots = {}

	for _, source in ipairs(sceneSource:GetChildren()) do
		local wasArchivable = source.Archivable
		source.Archivable = true
		local instance = source:Clone()
		source.Archivable = wasArchivable

		instance.Parent = workspace
		table.insert(sceneRoots, instance)
	end

	return sceneRoots
end

local function getWorkspaceScene(config): { Instance }
	local sceneRoots = {}
	local added = {}

	local function addRoot(name: string)
		local instance = workspace:FindFirstChild(name)
		if instance and not added[instance] then
			added[instance] = true
			table.insert(sceneRoots, instance)
		end
	end

	addRoot(config.Camera.Model)
	for targetName in config.Animations do
		addRoot(targetName)
	end

	return sceneRoots
end

local function createAnimationInstances(animations: { [string]: number }): { Animation }
	local instances = {}
	for targetName, animationId in animations do
		local animation = Instance.new("Animation")
		animation.Name = `{targetName}CutscenePreload`
		animation.AnimationId = `rbxassetid://{animationId}`
		table.insert(instances, animation)
	end
	return instances
end

local function preloadCutscene(cutsceneName: string, config): boolean
	if preloadedCutscenes[cutsceneName] then
		return true
	end
	if preloadingCutscenes[cutsceneName] then
		repeat
			RunService.Heartbeat:Wait()
		until not preloadingCutscenes[cutsceneName]
		return preloadedCutscenes[cutsceneName] == true
	end

	preloadingCutscenes[cutsceneName] = true
	local animationInstances = createAnimationInstances(config.Animations)
	local preloadInstances = {}
	for _, animation in animationInstances do
		table.insert(preloadInstances, animation)
	end

	if config.UseWorkspaceScene then
		for _, root in getWorkspaceScene(config) do
			table.insert(preloadInstances, root)
		end
	else
		local cutsceneRoot = findPath(ReplicatedStorage, CUTSCENE_ROOT)
		local sceneSource = cutsceneRoot and findPath(cutsceneRoot, config.ScenePath)
		if sceneSource then
			table.insert(preloadInstances, sceneSource)
		end
	end

	local ok, err = pcall(function()
		ContentProvider:PreloadAsync(preloadInstances)
	end)
	for _, animation in animationInstances do
		animation:Destroy()
	end

	preloadingCutscenes[cutsceneName] = nil
	preloadedCutscenes[cutsceneName] = ok
	if not ok then
		warn(`[CutscenePlayer] Failed to preload "{cutsceneName}": {err}`)
	end
	return ok
end

local function hideCharacter(character: Model, restoreCallbacks: { () -> () })
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") or descendant:IsA("Decal") then
			local previous = descendant.LocalTransparencyModifier
			descendant.LocalTransparencyModifier = 1
			table.insert(restoreCallbacks, function()
				if descendant.Parent then
					descendant.LocalTransparencyModifier = previous
				end
			end)
		elseif descendant:IsA("BillboardGui") then
			local previous = descendant.Enabled
			descendant.Enabled = false
			table.insert(restoreCallbacks, function()
				if descendant.Parent then
					descendant.Enabled = previous
				end
			end)
		elseif descendant:IsA("ParticleEmitter") or descendant:IsA("Trail") or descendant:IsA("Beam") then
			local previous = descendant.Enabled
			descendant.Enabled = false
			table.insert(restoreCallbacks, function()
				if descendant.Parent then
					descendant.Enabled = previous
				end
			end)
		end
	end
end

local function beginFocusMode()
	local restoreCallbacks = {}
	local connections = {}
	focusRestoreCallbacks = restoreCallbacks
	focusConnections = connections
	ContextActionService:BindActionAtPriority(
		FOCUS_ACTION_NAME,
		function()
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.ContextActionPriority.High.Value + 100,
		unpack(Enum.PlayerActions:GetEnumItems())
	)

	local function watchPlayer(player: Player)
		if player.Character then
			hideCharacter(player.Character, restoreCallbacks)
		end
		table.insert(connections, player.CharacterAdded:Connect(function(character)
			hideCharacter(character, restoreCallbacks)
		end))
	end

	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	table.insert(connections, Players.PlayerAdded:Connect(watchPlayer))
end

local function endFocusMode()
	ContextActionService:UnbindAction(FOCUS_ACTION_NAME)
	if focusConnections then
		for _, connection in focusConnections do
			connection:Disconnect()
		end
		focusConnections = nil
	end

	if focusRestoreCallbacks then
		for index = #focusRestoreCallbacks, 1, -1 do
			pcall(focusRestoreCallbacks[index])
		end
		focusRestoreCallbacks = nil
	end
end

local function restoreCamera()
	RunService:UnbindFromRenderStep(RENDER_STEP_NAME)

	local camera = workspace.CurrentCamera
	local state = savedCameraState
	if camera and state then
		camera.CameraType = state.CameraType
		camera.CameraSubject = state.CameraSubject
		camera.CFrame = state.CFrame
		camera.Focus = state.Focus
		camera.FieldOfView = state.FieldOfView
	end

	savedCameraState = nil
end

local function cleanActiveCutscene()
	activeTimeline = nil
	restoreCamera()
	if activeTimingConnection then
		activeTimingConnection:Disconnect()
		activeTimingConnection = nil
	end
	endFocusMode()

	if activeTracks then
		for _, track in ipairs(activeTracks) do
			track:Stop(0)
			track:Destroy()
		end
		activeTracks = nil
	end

	if activeScene then
		for _, instance in ipairs(activeScene) do
			instance:Destroy()
		end
		activeScene = nil
	end
end

local function loadAnimations(
	sceneRoots: { Instance },
	animations: { [string]: number }
): { AnimationTrack }
	local tracks = {}
	local animationInstances = {}
	local animationTargets = {}

	for targetName, animationId in animations do
		local target = findInScene(sceneRoots, targetName)
		if not target or not target:IsA("Model") then
			warn(`[CutscenePlayer] Animation target "{targetName}" was not found.`)
			continue
		end

		local animation = Instance.new("Animation")
		animation.Name = `{targetName}CutsceneAnimation`
		animation.AnimationId = `rbxassetid://{animationId}`
		table.insert(animationInstances, animation)
		animationTargets[animation] = target
	end

	pcall(function()
		ContentProvider:PreloadAsync(animationInstances)
	end)

	for _, animation in ipairs(animationInstances) do
		local target = animationTargets[animation]
		local targetName = target.Name
		if target and target:IsA("Model") then
			local success, track = pcall(function()
				local animator = getAnimator(target)
				for _, existingTrack in animator:GetPlayingAnimationTracks() do
					existingTrack:Stop(0)
				end
				return animator:LoadAnimation(animation)
			end)

			if success then
				track.Priority = Enum.AnimationPriority.Action4
				track.Looped = false
				table.insert(tracks, track)
			else
				warn(`[CutscenePlayer] Failed to load animation for "{targetName}": {track}`)
			end
		end
		animation:Destroy()
	end

	return tracks
end

local function prepareTracks(tracks: { AnimationTrack }): boolean
	for _, track in tracks do
		track:Play(0, 1, 0)
	end

	local deadline = os.clock() + CUTSCENE_LOAD_TIMEOUT
	while os.clock() < deadline do
		local ready = true
		for _, track in tracks do
			if track.Length <= 0 then
				ready = false
				break
			end
		end
		if ready then
			PlaybackClock.Apply(tracks, 0)
			-- Give every rig, especially Bookrig, one pose-evaluation frame at time 0
			-- before the shared timeline is allowed to advance.
			RunService.PreAnimation:Wait()
			PlaybackClock.Apply(tracks, 0)
			return true
		end
		RunService.Heartbeat:Wait()
	end

	return false
end

function CutscenePlayer.Preload(cutsceneName: string): boolean
	local config = CutsceneData[cutsceneName]
	if not config then
		warn(`[CutscenePlayer] Cutscene data "{cutsceneName}" does not exist.`)
		return false
	end
	return preloadCutscene(cutsceneName, config)
end

function CutscenePlayer.Stop()
	activeToken += 1
	cleanActiveCutscene()
end

function CutscenePlayer.Resume(): boolean
	local timeline = activeTimeline
	if not timeline or not timeline.Paused then
		return false
	end

	timeline.Paused = false
	timeline.LastClock = os.clock()
	return true
end

function CutscenePlayer.Play(cutsceneName: string, options: PlaybackOptions?): boolean
	local config = CutsceneData[cutsceneName]
	if not config then
		warn(`[CutscenePlayer] Cutscene data "{cutsceneName}" does not exist.`)
		return false
	end
	-- This is normally already complete from the lobby startup preload. Waiting
	-- here closes the race when a player summons immediately after joining.
	CutscenePlayer.Preload(cutsceneName)

	CutscenePlayer.Stop()
	local token = activeToken

	local sceneRoots
	if config.UseWorkspaceScene then
		sceneRoots = getWorkspaceScene(config)
		activeScene = nil
	else
		local cutsceneRoot = findPath(ReplicatedStorage, CUTSCENE_ROOT)
		local sceneSource = cutsceneRoot and findPath(cutsceneRoot, config.ScenePath)
		if not sceneSource then
			warn(`[CutscenePlayer] Scene source for "{cutsceneName}" was not found.`)
			return false
		end

		sceneRoots = cloneScene(sceneSource)
		activeScene = sceneRoots
		print(`[CutscenePlayer] Loaded {#sceneRoots} objects for "{cutsceneName}" into Workspace.`)
	end

	local sceneReady, sceneError = pcall(function()
		ContentProvider:PreloadAsync(sceneRoots)
	end)
	if not sceneReady then
		warn(`[CutscenePlayer] Scene assets for "{cutsceneName}" failed to preload: {sceneError}`)
		cleanActiveCutscene()
		return false
	end

	local cameraModel = findInScene(sceneRoots, config.Camera.Model)
	local cameraPart = cameraModel and cameraModel:FindFirstChild(config.Camera.Part, true)
	if not cameraPart or not cameraPart:IsA("BasePart") then
		warn(`[CutscenePlayer] Camera part "{config.Camera.Model}.{config.Camera.Part}" was not found.`)
		cleanActiveCutscene()
		return false
	end

	local camera = workspace.CurrentCamera
	if not camera then
		warn("[CutscenePlayer] CurrentCamera is unavailable.")
		cleanActiveCutscene()
		return false
	end

	local tracks = loadAnimations(sceneRoots, config.Animations)
	activeTracks = tracks
	local expectedTrackCount = 0
	for _ in config.Animations do
		expectedTrackCount += 1
	end
	if #tracks ~= expectedTrackCount then
		warn(
			`[CutscenePlayer] Cutscene "{cutsceneName}" loaded {#tracks}/{expectedTrackCount} animation tracks.`
		)
		cleanActiveCutscene()
		return false
	end
	if not prepareTracks(tracks) then
		warn(`[CutscenePlayer] Cutscene "{cutsceneName}" animation tracks did not finish loading in time.`)
		cleanActiveCutscene()
		return false
	end

	savedCameraState = {
		CameraType = camera.CameraType,
		CameraSubject = camera.CameraSubject,
		CFrame = camera.CFrame,
		Focus = camera.Focus,
		FieldOfView = camera.FieldOfView,
	}

	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = cameraPart.CFrame
	if config.FocusMode then
		beginFocusMode()
	end

	local startedAt = os.clock()
	local currentElapsed = 0
	local fovTrack = config.Camera.FOV
	local fovKeys = if fovTrack then SampleTrack.Keys(fovTrack.Samples) else nil
	local callbackFPS = config.FPS or (fovTrack and fovTrack.FPS) or 60
	local firedCallbacks = {}
	local pauseKeys = {}
	for frame, shouldPause in (options and options.PauseFrames or {}) do
		if shouldPause then
			table.insert(pauseKeys, frame)
		end
	end
	table.sort(pauseKeys)
	local nextPauseIndex = 1
	local timeline = {
		Token = token,
		Elapsed = 0,
		LastClock = startedAt,
		Paused = false,
	}
	activeTimeline = timeline
	activeTimingConnection = RunService.PreAnimation:Connect(function()
		local now = os.clock()
		if not timeline.Paused then
			timeline.Elapsed += math.max(0, now - timeline.LastClock)
		end
		timeline.LastClock = now

		local pauseFrame = pauseKeys[nextPauseIndex]
		if pauseFrame and timeline.Elapsed * callbackFPS >= pauseFrame then
			timeline.Elapsed = pauseFrame / callbackFPS
			timeline.Paused = true
			nextPauseIndex += 1
		end

		currentElapsed = math.min(timeline.Elapsed, config.MaxDuration or math.huge)
		PlaybackClock.Apply(tracks, currentElapsed)
	end)

	RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Camera.Value + 1, function()
		local currentCamera = workspace.CurrentCamera
		if not cameraPart.Parent or not currentCamera then
			return
		end

		currentCamera.CameraType = Enum.CameraType.Scriptable
		currentCamera.CFrame = cameraPart.CFrame
		if fovTrack and fovKeys then
			local fovFPS = fovTrack.FPS or callbackFPS
			currentCamera.FieldOfView = math.clamp(
				SampleTrack.Read(fovTrack.Samples, fovKeys, currentElapsed * fovFPS, fovTrack.Cuts),
				1,
				120
			)
		end
	end)

	RunService.Heartbeat:Wait()

	local maxDuration = config.MaxDuration or 60
	while activeToken == token and currentElapsed < maxDuration do
		-- The timeline is clamped to exact frame fractions at pause points. Add a
		-- tiny epsilon so floating-point division cannot turn frame 142 into 141.
		local currentFrame = math.floor(currentElapsed * callbackFPS + 1e-4)
		for frame, callback in (options and options.FrameCallbacks or {}) do
			if not firedCallbacks[frame] and currentFrame >= frame then
				firedCallbacks[frame] = true
				local ok, err = pcall(callback)
				if not ok then
					warn(`[CutscenePlayer] Frame {frame} callback failed: {err}`)
					if timeline.Paused then
						CutscenePlayer.Resume()
					end
				end
			end
		end

		RunService.Heartbeat:Wait()
	end

	if activeToken == token then
		activeToken += 1
		cleanActiveCutscene()
	end

	return true
end

return CutscenePlayer
