local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CutsceneData = require(ReplicatedStorage.Settings.Data.CutsceneData)

local CUTSCENE_ROOT = { "Assets", "Cutscenes" }
local RENDER_STEP_NAME = "CutsceneCamera"

local CutscenePlayer = {}

local activeToken = 0
local activeScene: { Instance }? = nil
local activeTracks: { AnimationTrack }? = nil
local savedCameraState = nil

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
	restoreCamera()

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
				return getAnimator(target):LoadAnimation(animation)
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

function CutscenePlayer.Stop()
	activeToken += 1
	cleanActiveCutscene()
end

function CutscenePlayer.Play(cutsceneName: string): boolean
	local config = CutsceneData[cutsceneName]
	if not config then
		warn(`[CutscenePlayer] Cutscene data "{cutsceneName}" does not exist.`)
		return false
	end

	CutscenePlayer.Stop()
	local token = activeToken

	local cutsceneRoot = findPath(ReplicatedStorage, CUTSCENE_ROOT)
	local sceneSource = cutsceneRoot and findPath(cutsceneRoot, config.ScenePath)
	if not sceneSource then
		warn(`[CutscenePlayer] Scene source for "{cutsceneName}" was not found.`)
		return false
	end

	local sceneRoots = cloneScene(sceneSource)
	activeScene = sceneRoots
	print(`[CutscenePlayer] Loaded {#sceneRoots} objects for "{cutsceneName}" into Workspace.`)

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

	savedCameraState = {
		CameraType = camera.CameraType,
		CameraSubject = camera.CameraSubject,
		CFrame = camera.CFrame,
		Focus = camera.Focus,
		FieldOfView = camera.FieldOfView,
	}

	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = cameraPart.CFrame
	RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Camera.Value + 1, function()
		if cameraPart.Parent and workspace.CurrentCamera then
			workspace.CurrentCamera.CFrame = cameraPart.CFrame
		end
	end)

	local tracks = loadAnimations(sceneRoots, config.Animations)
	activeTracks = tracks

	for _, track in ipairs(tracks) do
		track:Play(0, 1, 1)
	end
	RunService.Heartbeat:Wait()

	local startedAt = os.clock()
	local maxDuration = config.MaxDuration or 60
	while activeToken == token and os.clock() - startedAt < maxDuration do
		local hasPlayingTrack = false
		for _, track in ipairs(tracks) do
			if track.IsPlaying then
				hasPlayingTrack = true
				break
			end
		end
		if not hasPlayingTrack then
			break
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
