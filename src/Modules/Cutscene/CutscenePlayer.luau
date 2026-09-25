local ContentProvider = game:GetService("ContentProvider")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CutsceneData = require(ReplicatedStorage.Settings.Data.CutsceneData)
local CutsceneValidator = require(script.Parent.CutsceneValidator)
local PlaybackClock = require(script.Parent.PlaybackClock)
local SceneTransform = require(script.Parent.SceneTransform)
local SampleTrack = require(script.Parent.ECS.SampleTrack)
local ScreenEffects = require(script.Parent.ScreenEffects)
local LightingSession = require(script.Parent.LightingSession)
local LocalAudio = require(script.Parent.LocalAudio)
local LocalVFX = require(script.Parent.LocalVFX)
local LocalActorView = require(script.Parent.LocalActorView)
local CutscenePresentation = require(script.Parent.CutscenePresentation)
local Cleanup = require(script.Parent.Cleanup)

local CUTSCENE_ROOT = { "Assets", "Cutscenes" }
local RENDER_STEP_NAME = "CutsceneCamera"
local FOCUS_ACTION_NAME = "CutsceneFocusControls"
local CUTSCENE_LOAD_TIMEOUT = 15

local CutscenePlayer = {}

type SavedWorkspaceModelState = {
	Pivot: CFrame,
	Transforms: { [Instance]: CFrame },
	Anchored: { [BasePart]: boolean },
}

local activeToken = 0
local activeScene: { Instance }? = nil
local activeTracks: { AnimationTrack }? = nil
local savedCameraState = nil
local savedWorkspaceSceneStates: { [Model]: SavedWorkspaceModelState }? = nil
local activeTimingConnection: RBXScriptConnection? = nil
local focusRestoreCallbacks: { () -> () }? = nil
local focusConnections: { RBXScriptConnection }? = nil
local activeTimeline = nil
local activeScreenEffects = nil
local activeLightingSession = nil
local activeAudio = nil
local activeVFX = nil
local activeActorViews = nil
local activePresentation = nil
local preloadedCutscenes = {}
local preloadingCutscenes = {}

export type PlaybackOptions = {
	FrameCallbacks: { [number]: () -> () }?,
	PauseFrames: { [number]: boolean }?,
	OnCovered: (() -> ())?,
	OnReturning: (() -> ())?,
}

local function validateConfig(cutsceneName: string, config): boolean
	local valid, validationError = pcall(CutsceneValidator.Validate, cutsceneName, config)
	if not valid then
		warn(`[CutscenePlayer] Invalid cutscene data "{cutsceneName}": {validationError}`)
	end
	return valid
end

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

local function resolveSceneModels(sceneRoots: { Instance }, animations: { [string]: number }): { [string]: Model }?
	local models = {}
	local counts = {}
	local function inspect(instance: Instance)
		if instance:IsA("Model") and animations[instance.Name] then
			counts[instance.Name] = (counts[instance.Name] or 0) + 1
			models[instance.Name] = instance
		end
	end
	for _, root in sceneRoots do
		inspect(root)
		for _, descendant in root:GetDescendants() do
			inspect(descendant)
		end
	end
	for targetName in animations do
		if counts[targetName] ~= 1 then
			warn(`[CutscenePlayer] Expected exactly one model named "{targetName}"; found {counts[targetName] or 0}.`)
			return nil
		end
	end
	return models
end

local function waitForSceneModels(sceneSource: Instance, animations: { [string]: number }, token: number): boolean
	local deadline = os.clock() + 10
	local missing = {}
	repeat
		table.clear(missing)
		for targetName in animations do
			local target = sceneSource:FindFirstChild(targetName, true)
			if not target or not target:IsA("Model") then
				table.insert(missing, targetName)
			end
		end
		if #missing == 0 then
			return true
		end
		if activeToken ~= token then
			return false
		end
		task.wait(0.1)
	until os.clock() >= deadline
	table.sort(missing)
	warn(`[CutscenePlayer] Scene "{sceneSource:GetFullName()}" is missing animation models: {table.concat(missing, ", ")}`)
	return false
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

local function prepareClonedScene(scene: Instance, animations: { [string]: number })
	local models = assert(resolveSceneModels({ scene }, animations), "Cutscene has missing or duplicate animation models")
	local rigParts = {}
	for _, model in models do
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				rigParts[descendant] = true
			end
		end
	end
	for _, descendant in scene:GetDescendants() do
		if descendant:IsA("BaseScript") then
			descendant.Enabled = false
		elseif descendant:IsA("SpawnLocation") then
			descendant.Enabled = false
		end
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanTouch = false
			if not rigParts[descendant] then
				descendant.Anchored = true
			end
		end
	end
	for targetName, model in models do
		local root = model:FindFirstChild("HumanoidRootPart", true)
		if not root or not root:IsA("BasePart") then
			root = model.PrimaryPart
		end
		if not root then
			local motor = model:FindFirstChildWhichIsA("Motor6D", true)
			root = motor and motor.Part0
		end
		root = root or model:FindFirstChildWhichIsA("BasePart", true)
		assert(root and root:IsA("BasePart"), `Cutscene rig "{targetName}" has no root BasePart`)
		root.Anchored = true
	end
end

local function cloneScene(sceneSource: Instance, transform: CFrame?, animations: { [string]: number }): { Instance }
	local wasArchivable = sceneSource.Archivable
	sceneSource.Archivable = true
	local cloneOk, scene = pcall(function()
		return sceneSource:Clone()
	end)
	sceneSource.Archivable = wasArchivable
	assert(cloneOk and scene, `Could not clone cutscene source "{sceneSource:GetFullName()}": {scene}`)
	local placed, placementError = pcall(function()
		SceneTransform.Apply(scene, transform)
		prepareClonedScene(scene, animations)
	end)
	if not placed then
		scene:Destroy()
		error(placementError, 0)
	end
	scene.Parent = workspace
	return { scene }
end

local function getWorkspaceScene(config, saveState: boolean?): { Instance }
	local sceneRoots = {}
	local added = {}

	local function addRoot(name: string)
		local instance = workspace:FindFirstChild(name)
		if instance and not added[instance] then
			added[instance] = true
			table.insert(sceneRoots, instance)
			if saveState and instance:IsA("Model") then
				local transforms = {}
				local anchored = {}
				for _, descendant in instance:GetDescendants() do
					if descendant:IsA("Motor6D") or descendant:IsA("Bone") then
						transforms[descendant] = descendant.Transform
					elseif descendant:IsA("BasePart") then
						anchored[descendant] = descendant.Anchored
					end
				end
				(savedWorkspaceSceneStates :: { [Model]: SavedWorkspaceModelState })[instance] = {
					Pivot = instance:GetPivot(),
					Transforms = transforms,
					Anchored = anchored,
				}
			end
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
	local preloadSound = nil
	if config.Audio then
		preloadSound = Instance.new("Sound")
		preloadSound.SoundId = `rbxassetid://{config.Audio.SoundId}`
		table.insert(preloadInstances, preloadSound)
	end

	if config.UseWorkspaceScene then
		for _, root in getWorkspaceScene(config) do
			table.insert(preloadInstances, root)
		end
	else
		local cutsceneRoot = findPath(ReplicatedStorage, CUTSCENE_ROOT)
		local sceneSource = cutsceneRoot and findPath(cutsceneRoot, config.ScenePath)
		if not sceneSource then
			for _, animation in animationInstances do
				animation:Destroy()
			end
			if preloadSound then preloadSound:Destroy() end
			preloadingCutscenes[cutsceneName] = nil
			warn(`[CutscenePlayer] Scene source for "{cutsceneName}" was not found at ReplicatedStorage.Assets.Cutscenes.{table.concat(config.ScenePath, ".")}.`)
			return false
		end
		if config.PreloadScene ~= false then
			table.insert(preloadInstances, sceneSource)
		end
	end

	local ok, err = pcall(function()
		ContentProvider:PreloadAsync(preloadInstances)
	end)
	for _, animation in animationInstances do
		animation:Destroy()
	end
	if preloadSound then preloadSound:Destroy() end

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
	if activeActorViews then
		local views = activeActorViews
		activeActorViews = nil
		for _, view in views do
			Cleanup.Try("Local actor", function() view:Destroy() end)
		end
	end
	if activeVFX then
		local vfx = activeVFX
		activeVFX = nil
		Cleanup.Try("Local VFX", function() vfx:Destroy() end)
	end
	if activeAudio then
		local audio = activeAudio
		activeAudio = nil
		Cleanup.Try("Local audio", function() audio:Destroy() end)
	end
	-- Restore the screen independently even if another cleanup resource fails.
	if activeScreenEffects then
		local screen = activeScreenEffects
		activeScreenEffects = nil
		Cleanup.Try("Local screen effects", function() screen:Destroy() end)
	end
	if activeLightingSession then
		local lighting = activeLightingSession
		activeLightingSession = nil
		Cleanup.Try("Local lighting", function() lighting:Destroy() end)
	end
	Cleanup.Try("Local camera", restoreCamera)
	if activeTimingConnection then
		activeTimingConnection:Disconnect()
		activeTimingConnection = nil
	end
	Cleanup.Try("Local focus", endFocusMode)

	if activeTracks then
		for _, track in ipairs(activeTracks) do
			Cleanup.Try("Local track stop", function() track:Stop(0) end)
			Cleanup.Try("Local track destroy", function() track:Destroy() end)
		end
		activeTracks = nil
	end

	if savedWorkspaceSceneStates then
		for model, state in savedWorkspaceSceneStates do
			if model.Parent then
				model:PivotTo(state.Pivot)
			end
			for part, wasAnchored in state.Anchored do
				if part.Parent then
					part.Anchored = wasAnchored
				end
			end
			for joint, transform in state.Transforms do
				if joint.Parent and (joint:IsA("Motor6D") or joint:IsA("Bone")) then
					joint.Transform = transform
				end
			end
		end
		savedWorkspaceSceneStates = nil
	end

	if activeScene then
		for _, instance in ipairs(activeScene) do
			instance:Destroy()
		end
		activeScene = nil
	end
end

local function loadAnimations(
	sceneModels: { [string]: Model },
	animations: { [string]: number }
): ({ AnimationTrack }, { [string]: AnimationTrack })
	local tracks = {}
	local tracksByName = {}
	local animationInstances = {}
	local animationTargets = {}

	for targetName, animationId in animations do
		local target = sceneModels[targetName]

		local animation = Instance.new("Animation")
		animation.Name = `{targetName}CutsceneAnimation`
		animation.AnimationId = `rbxassetid://{animationId}`
		table.insert(animationInstances, animation)
		animationTargets[animation] = target
	end

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
				tracksByName[targetName] = track
			else
				warn(`[CutscenePlayer] Failed to load animation for "{targetName}": {track}`)
			end
		end
		animation:Destroy()
	end

	return tracks, tracksByName
end

local function prepareTracks(tracks: { AnimationTrack }, token: number): boolean
	for _, track in tracks do
		track:Play(0, 1, 0)
	end

	local deadline = os.clock() + CUTSCENE_LOAD_TIMEOUT
	while os.clock() < deadline do
		if activeToken ~= token then return false end
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
			if activeToken ~= token then return false end
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
	if not validateConfig(cutsceneName, config) then
		return false
	end
	return preloadCutscene(cutsceneName, config)
end

function CutscenePlayer.Stop()
	activeToken += 1
	local presentation = activePresentation
	activePresentation = nil
	cleanActiveCutscene()
	if presentation then presentation:Destroy() end
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

local preloadPresentationAssets

local function play(cutsceneName: string, options: PlaybackOptions?, token: number, presentation): boolean
	local config = CutsceneData[cutsceneName]
	if not config then
		warn(`[CutscenePlayer] Cutscene data "{cutsceneName}" does not exist.`)
		return false
	end
	-- Preload returning false can mean a recoverable asset preload failure, but
	-- malformed timeline data must never continue into partial playback.
	if not validateConfig(cutsceneName, config) then
		return false
	end
	-- This is normally already complete from the lobby startup preload. Waiting
	-- here closes the race when a player summons immediately after joining.
	-- Small lobby scenes may preload in the background. Never hold playback on a
	-- full-scene ContentProvider request; animation readiness is checked below.
	local wasPreloaded = if config.PreloadScene == false
		then preloadedCutscenes[cutsceneName] == true
		else CutscenePlayer.Preload(cutsceneName)
	if activeToken ~= token then return false end

	local sceneRoots
	if config.UseWorkspaceScene then
		savedWorkspaceSceneStates = {}
		sceneRoots = getWorkspaceScene(config, true)
		activeScene = nil
	else
		local cutsceneRoot = findPath(ReplicatedStorage, CUTSCENE_ROOT)
		local sceneSource = cutsceneRoot and findPath(cutsceneRoot, config.ScenePath)
		if activeToken ~= token then return false end
		if not sceneSource then
			warn(`[CutscenePlayer] Scene source for "{cutsceneName}" was not found at ReplicatedStorage.Assets.Cutscenes.{table.concat(config.ScenePath, ".")}.`)
			return false
		end
		if not waitForSceneModels(sceneSource, config.Animations, token) then
			return false
		end

		sceneRoots = cloneScene(sceneSource, config.SceneTransform, config.Animations)
		activeScene = sceneRoots
		print(`[CutscenePlayer] Loaded {#sceneRoots} objects for "{cutsceneName}" into Workspace.`)
	end

	if not wasPreloaded and config.PreloadScene ~= false then
		local sceneReady, sceneError = pcall(function()
			ContentProvider:PreloadAsync(sceneRoots)
		end)
		if activeToken ~= token then return false end
		if not sceneReady then
			warn(`[CutscenePlayer] Scene assets for "{cutsceneName}" failed to preload: {sceneError}`)
			cleanActiveCutscene()
			return false
		end
	end

	local sceneModels = resolveSceneModels(sceneRoots, config.Animations)
	if not sceneModels then
		cleanActiveCutscene()
		return false
	end
	local cameraModel = sceneModels[config.Camera.Model]
	local cameraPart = cameraModel and cameraModel:FindFirstChild(config.Camera.Part, true)
	if not cameraPart and cameraModel and cameraModel:IsA("Model") then
		cameraPart = cameraModel.PrimaryPart
		if not cameraPart then
			for _, descendant in cameraModel:GetDescendants() do
				if descendant:IsA("BasePart") then
					if cameraPart then
						cameraPart = nil
						break
					end
					cameraPart = descendant
				end
			end
		end
	end
	if not cameraPart or not cameraPart:IsA("BasePart") then
		warn(`[CutscenePlayer] Camera part "{config.Camera.Model}.{config.Camera.Part}" was not found; set that part or the Cam model's PrimaryPart.`)
		cleanActiveCutscene()
		return false
	end
	if cameraPart.Name ~= config.Camera.Part then
		warn(`[CutscenePlayer] "{config.Camera.Model}.{config.Camera.Part}" is missing; using "{cameraPart:GetFullName()}" as the camera part.`)
	end

	local camera = workspace.CurrentCamera
	if not camera then
		warn("[CutscenePlayer] CurrentCamera is unavailable.")
		cleanActiveCutscene()
		return false
	end

	local tracks, tracksByName = loadAnimations(sceneModels, config.Animations)
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
	local tracksReady = prepareTracks(tracks, token)
	if activeToken ~= token then return false end
	if not tracksReady then
		local missing = {}
		for targetName, track in tracksByName do
			if track.Length <= 0 then
				table.insert(missing, `{targetName} ({config.Animations[targetName]})`)
			end
		end
		warn(`[CutscenePlayer] Cutscene "{cutsceneName}" animation tracks did not finish loading in time: {table.concat(missing, ", ")}. Check asset permissions and rig compatibility.`)
		cleanActiveCutscene()
		return false
	end
	if config.Actors then
		activeActorViews = {}
		for name, role in config.Actors do
			if role == "Self" then
				local view = LocalActorView.new(name, sceneModels[name], config.Animations[name], tracks, function()
					return activeToken == token
				end)
				table.insert(activeActorViews, view)
				if not view:Prepare(12) then
					warn(`[CutscenePlayer] "{cutsceneName}" kept its authored {name} appearance because the player avatar was unavailable.`)
				end
				if activeToken ~= token then return false end
			else
				warn(`[CutscenePlayer] Local actor role "{role}" for {name} is unsupported.`)
			end
		end
	end

	if config.Lighting then
		local lightingOk, lighting = pcall(LightingSession.new, config.Lighting)
		if lightingOk then
			activeLightingSession = lighting
		else
			warn(`[CutscenePlayer] Lighting for "{cutsceneName}" could not be applied: {lighting}`)
		end
	end
	local screenConfig = config.ScreenEffects
	local screenView = if screenConfig then ScreenEffects.new(screenConfig) else nil
	activeScreenEffects = screenView
	local audioView = if config.Audio then LocalAudio.new(config.Audio) else nil
	activeAudio = audioView
	local vfxConfig = config.VFX
	local vfxView = nil
	if vfxConfig then
		local vfxOk, result = pcall(LocalVFX.new, sceneRoots, vfxConfig.Events)
		if vfxOk then
			vfxView = result
			activeVFX = result
		else
			warn(`[CutscenePlayer] VFX for "{cutsceneName}" could not be prepared: {result}`)
		end
	end
	if presentation and not preloadPresentationAssets(sceneRoots, token, config.Presentation.PreloadTimeout) then
		return false
	end
	local cameraTrack = tracksByName[config.Camera.Model]
	-- Local cutscenes may pause for interactive reveals after the camera animation
	-- reaches its final pose. An authored duration must cover the whole timeline.
	local maxDuration = config.MaxDuration or PlaybackClock.Duration(cameraTrack.Length)
	local screenFPS = if screenConfig
		then screenConfig.FPS or config.FPS or screenConfig.EndFrame / maxDuration
		else nil
	local vfxFPS = if vfxConfig
		then vfxConfig.FPS or config.FPS or vfxConfig.EndFrame / maxDuration
		else nil
	local authoredDuration = if screenConfig and screenConfig.FPS
		then screenConfig.EndFrame / screenConfig.FPS
		else config.MaxDuration
	if authoredDuration and math.abs(cameraTrack.Length - authoredDuration) > 0.25 then
		warn(`[CutscenePlayer] "{cutsceneName}" camera animation is {string.format("%.3f", cameraTrack.Length)}s, but the authored effect timeline is {string.format("%.3f", authoredDuration)}s. Check the Cam animation export for missing or extra frames.`)
	end
	if screenView then
		print(`[CutscenePlayer] "{cutsceneName}" mounted Lighting.{screenView.Effect.Name}: {screenConfig.EndFrame} frames at {string.format("%.3f", screenFPS)} FPS.`)
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
	camera.Focus = cameraPart.CFrame
	if screenView then screenView:ApplyFrame(0, true) end
	if config.Camera.FOV then
		local fov = config.Camera.FOV
		camera.FieldOfView = math.clamp(fov.Samples[0] or camera.FieldOfView, 1, 120)
	end
	if config.FocusMode then
		beginFocusMode()
	end
	if presentation and not presentation:ReadyToReveal(function() return activeToken == token end) then
		return false
	end

	local startedAt = os.clock()
	local currentElapsed = 0
	local fovTrack = config.Camera.FOV
	local fovKeys = if fovTrack then SampleTrack.Keys(fovTrack.Samples) else nil
	local fovFPS = if fovTrack and fovKeys
		then fovTrack.FPS or config.FPS or fovKeys[#fovKeys] / cameraTrack.Length
		else nil
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
	local playbackError = nil
	local function protect(callback)
		return function()
			if activeToken ~= token or playbackError then return end
			local ok, err = xpcall(callback, debug.traceback)
			if not ok then
				playbackError = err
				if screenView then screenView:Destroy() end
			end
		end
	end
	activeTimingConnection = RunService.PreAnimation:Connect(protect(function()
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

		currentElapsed = math.min(timeline.Elapsed, maxDuration)
		if activeActorViews then
			for _, view in activeActorViews do view:PreAnimation() end
		end
		PlaybackClock.Apply(tracks, currentElapsed)
	end))

	RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Camera.Value + 1, protect(function()
		local currentCamera = workspace.CurrentCamera
		if not cameraPart.Parent or not currentCamera then
			error("Cutscene camera was removed during playback")
		end
		if screenView then
			screenView:ApplyFrame(currentElapsed * screenFPS, true)
		end
		if vfxView then
			vfxView:Step(currentElapsed * vfxFPS)
		end
		if audioView then
			audioView:Step(currentElapsed, timeline.Paused)
		end

		currentCamera.CameraType = Enum.CameraType.Scriptable
		currentCamera.CFrame = cameraPart.CFrame
		currentCamera.Focus = cameraPart.CFrame
		if fovTrack and fovKeys then
			currentCamera.FieldOfView = math.clamp(
				SampleTrack.Read(fovTrack.Samples, fovKeys, currentElapsed * fovFPS, fovTrack.Cuts),
				1,
				120
			)
		end
	end))
	if presentation then presentation:Reveal() end

	RunService.Heartbeat:Wait()

	while activeToken == token and not playbackError and currentElapsed < maxDuration do
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

	if playbackError then error(playbackError, 0) end
	local completed = activeToken == token
	if completed then
		if presentation then
			local isCurrent = function() return activeToken == token end
			-- Freeze the final authored frame so the FOV zoom is not overwritten by
			-- the camera track while the blackout closes.
			RunService:UnbindFromRenderStep(RENDER_STEP_NAME)
			if activeTimingConnection then
				activeTimingConnection:Disconnect()
				activeTimingConnection = nil
			end
			if not presentation:CoverExit(isCurrent, audioView and audioView.Sound, camera) then return false end
		end
		cleanActiveCutscene()
		if presentation then
			if options and options.OnReturning then
				Cleanup.Try("Restore cutscene UI", options.OnReturning)
			end
			local returned = presentation:ReturnToLobby(function() return activeToken == token end)
			if not returned and activeToken ~= token then return false end
			if activePresentation == presentation then activePresentation = nil end
		end
		if activeToken == token then activeToken += 1 end
	end

	return completed
end

preloadPresentationAssets = function(sceneRoots: { Instance }, token: number, timeout: number): boolean
	local targets = {}
	local seen = {}
	local function add(root: Instance)
		local function inspect(instance: Instance)
			if seen[instance] then return end
			if instance:IsA("MeshPart") or instance:IsA("SpecialMesh") or instance:IsA("Decal")
				or instance:IsA("Texture") or instance:IsA("SurfaceAppearance")
				or instance:IsA("ParticleEmitter") or instance:IsA("Beam") or instance:IsA("Trail")
				or instance:IsA("ImageLabel") or instance:IsA("ImageButton")
				or instance:IsA("Sky") or instance:IsA("Sound") or instance:IsA("VideoFrame") then
				seen[instance] = true
				table.insert(targets, instance)
			end
		end
		inspect(root)
		for _, descendant in root:GetDescendants() do inspect(descendant) end
	end
	for _, root in sceneRoots do add(root) end
	for _, view in activeActorViews or {} do
		if view.Model then add(view.Model) end
	end
	if activeLightingSession then
		for _, child in activeLightingSession.Owned do add(child) end
	end
	if activeAudio then add(activeAudio.Sound) end
	if #targets == 0 then return true end

	local finished, success, failure = false, false, nil
	local failedAssets = {}
	local thread = task.spawn(function()
		success, failure = pcall(function()
			ContentProvider:PreloadAsync(targets, function(assetId, status)
				if status ~= Enum.AssetFetchStatus.Success and #failedAssets < 8 then
					table.insert(failedAssets, tostring(assetId))
				end
			end)
		end)
		finished = true
	end)
	local deadline = os.clock() + timeout
	while not finished and activeToken == token and os.clock() < deadline do
		RunService.Heartbeat:Wait()
	end
	if not finished then
		pcall(task.cancel, thread)
		if activeToken == token then warn(`[CutscenePlayer] Scene asset preload exceeded {timeout}s.`) end
		return false
	end
	if not success then
		warn(`[CutscenePlayer] Scene asset preload failed: {tostring(failure)}`)
		return false
	end
	if #failedAssets > 0 then
		warn(`[CutscenePlayer] Some scene assets could not be fetched: {table.concat(failedAssets, ", ")}`)
	end
	return activeToken == token
end

function CutscenePlayer.Play(cutsceneName: string, options: PlaybackOptions?): boolean
	CutscenePlayer.Stop()
	local token = activeToken
	local presentation = nil
	local ok, result = xpcall(function()
		local config = CutsceneData[cutsceneName]
		if config and config.Presentation then
			presentation = CutscenePresentation.new(config.Presentation)
			activePresentation = presentation
			if not presentation:CoverEntrance(function() return activeToken == token end) then return false end
			if options and options.OnCovered then options.OnCovered() end
		end
		return play(cutsceneName, options, token, presentation)
	end, debug.traceback)
	if not ok or not result then
		if activeToken == token then
			if presentation then
				Cleanup.Try("Cover failed cutscene", function()
					presentation:CoverExit(function() return activeToken == token end, nil, nil)
				end)
			end
			cleanActiveCutscene()
			if presentation then
				if options and options.OnReturning then
					Cleanup.Try("Restore cutscene UI", options.OnReturning)
				end
				Cleanup.Try("Return to lobby", function()
					presentation:ReturnToLobby(function() return activeToken == token end)
				end)
				presentation:Destroy()
				if activePresentation == presentation then activePresentation = nil end
			end
			activeToken += 1
		end
	end
	if not ok then
		warn(`[CutscenePlayer] "{cutsceneName}" playback failed: {result}`)
		return false
	end
	return result
end

return CutscenePlayer
