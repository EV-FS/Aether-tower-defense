local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)

local cleanup = Vide.cleanup
local create = Vide.create
local effect = Vide.effect
local read = Vide.read
local source = Vide.source

local DEFAULT_CAMERA_DIRECTION = Vector3.new(0, 0, -1)
local DEFAULT_FIELD_OF_VIEW = 35
local DEFAULT_FIT_PADDING = 1.1
local MINIMUM_BOUNDS_RADIUS = 0.01

type Reactive<T> = T | (() -> T)
type AnimationId = number | string

type ModelState = {
	Instance: Model,
	TowerName: string,
	FocusOffset: Vector3,
	BoundsRadius: number,
}

export type Props = {
	TowerName: Reactive<string?>,
	Name: string?,
	AnchorPoint: Reactive<Vector2>?,
	Position: Reactive<UDim2>?,
	Size: Reactive<UDim2>?,
	Visible: Reactive<boolean>?,
	ZIndex: Reactive<number>?,
	BackgroundColor3: Reactive<Color3>?,
	BackgroundTransparency: Reactive<number>?,
	ImageTransparency: Reactive<number>?,
	Ambient: Reactive<Color3>?,
	LightColor: Reactive<Color3>?,
	LightDirection: Reactive<Vector3>?,
	CameraDirection: Reactive<Vector3>?,
	FieldOfView: Reactive<number>?,
	FitPadding: Reactive<number>?,
	FocusYOffset: Reactive<number>?,
	ModelRotation: Reactive<number>?,
	AnimationName: Reactive<string?>?,
	AnimationLevel: Reactive<number?>?,
	AnimationId: Reactive<AnimationId?>?,
	AnimationLooped: Reactive<boolean>?,
	AnimationSpeed: Reactive<number>?,
	AnimationFadeTime: Reactive<number>?,
}

local function getTowerAsset(towerName: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local towers = assets and assets:FindFirstChild("Towers")
	local towerAsset = towers and towers:FindFirstChild(towerName)

	if not towerAsset or not towerAsset:IsA("Model") then
		warn(`[TowerViewport] Tower model "{towerName}" was not found in ReplicatedStorage.Assets.Towers.`)
		return nil
	end

	return towerAsset
end

local function findRootPart(model: Model): BasePart?
	if model.PrimaryPart then
		return model.PrimaryPart
	end

	local humanoidRootPart = model:FindFirstChild("HumanoidRootPart", true)
	if humanoidRootPart and humanoidRootPart:IsA("BasePart") then
		return humanoidRootPart
	end

	return model:FindFirstChildWhichIsA("BasePart", true)
end

local function prepareModel(model: Model, towerName: string): ModelState
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BaseScript") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.CanCollide = false
		end
	end

	local rootPart = findRootPart(model)
	if rootPart then
		rootPart.Anchored = true
	end

	-- Every viewport owns its own WorldModel, so the model can use a stable local origin.
	model:PivotTo(CFrame.identity)

	local boundsCFrame, boundsSize = model:GetBoundingBox()
	return {
		Instance = model,
		TowerName = towerName,
		FocusOffset = boundsCFrame.Position + Vector3.new(0, boundsSize.Y * 0.05, 0),
		BoundsRadius = math.max(boundsSize.Magnitude * 0.5, MINIMUM_BOUNDS_RADIUS),
	}
end

local function getModelCFrame(rotation: number): CFrame
	return CFrame.Angles(0, math.rad(rotation), 0)
end

local function updateCamera(
	camera: Camera,
	modelState: ModelState,
	modelCFrame: CFrame,
	fieldOfView: number,
	cameraDirection: Vector3,
	fitPadding: number,
	focusYOffset: number
)
	local direction = if cameraDirection.Magnitude > 0 then cameraDirection.Unit else DEFAULT_CAMERA_DIRECTION
	local clampedFieldOfView = math.clamp(fieldOfView, 1, 120)
	local distance = modelState.BoundsRadius / math.sin(math.rad(clampedFieldOfView) * 0.5) * math.max(fitPadding, 0.5)
	local focus = modelCFrame:PointToWorldSpace(modelState.FocusOffset + Vector3.new(0, focusYOffset, 0))

	camera.FieldOfView = clampedFieldOfView
	camera.CFrame = CFrame.lookAt(focus + direction * distance, focus)
end

local function getAnimation(towerName: string, animationName: string, level: number?): Animation?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local animations = assets and assets:FindFirstChild("Animations")
	local towerAnimations = animations and animations:FindFirstChild(towerName)
	if not towerAnimations then
		return nil
	end

	if level then
		for currentLevel = level, 0, -1 do
			local animation = towerAnimations:FindFirstChild(`{animationName}_{currentLevel}`)
			if animation and animation:IsA("Animation") then
				return animation
			end
		end
	end

	local animation = towerAnimations:FindFirstChild(animationName)
	return if animation and animation:IsA("Animation") then animation else nil
end

local function createAnimation(
	towerName: string,
	animationId: AnimationId?,
	animationName: string?,
	animationLevel: number?
): Animation?
	if animationId ~= nil then
		local animation = Instance.new("Animation")
		local id = tostring(animationId)
		animation.AnimationId = if string.sub(id, 1, 13) == "rbxassetid://" then id else `rbxassetid://{id}`
		return animation
	end

	if not animationName or animationName == "" then
		return nil
	end

	local animation = getAnimation(towerName, animationName, animationLevel)
	if not animation then
		warn(`[TowerViewport] Animation "{animationName}" was not found for tower "{towerName}".`)
		return nil
	end

	return animation:Clone()
end

local function getAnimator(model: Model): Animator?
	local controller = model:FindFirstChildOfClass("AnimationController") or model:FindFirstChildOfClass("Humanoid")
	if not controller then
		return nil
	end

	local animator = controller:FindFirstChildOfClass("Animator")
	if animator then
		return animator
	end

	animator = Instance.new("Animator")
	animator.Parent = controller
	return animator
end

local function startAnimation(
	model: Model,
	animation: Animation,
	fadeTime: number,
	setActiveTrack: (AnimationTrack?) -> ()
): () -> ()
	local active = true
	local track: AnimationTrack?

	local thread = task.spawn(function()
		while active and not model:IsDescendantOf(game) do
			model.AncestryChanged:Wait()
		end
		if not active then
			return
		end

		local animator = getAnimator(model)
		if not animator then
			warn(`[TowerViewport] Tower "{model.Name}" has no AnimationController or Humanoid.`)
			return
		end

		local success, result = pcall(function()
			return animator:LoadAnimation(animation)
		end)
		if not success then
			warn(`[TowerViewport] Failed to load animation for tower "{model.Name}": {result}`)
			return
		end

		track = result
		track:Play(fadeTime)
		setActiveTrack(track)
	end)

	return function()
		active = false
		if coroutine.status(thread) ~= "dead" then
			task.cancel(thread)
		end

		setActiveTrack(nil)
		if track then
			track:Stop(0)
			track:Destroy()
		end
		animation:Destroy()
	end
end

--[[
	TowerViewport({
		TowerName = "Bacon",
		AnimationName = "Idle",
		ModelRotation = rotationSpring,
		Size = UDim2.fromScale(0.5, 0.5),
	})

	The model is cloned only when TowerName changes. Transform, camera, and playback
	properties can be static values or Vide getters without recreating the model.
]]
return function(props: Props)
	local camera = create("Camera")({ Name = "TowerCamera" })
	local worldModel = create("WorldModel")({ Name = "TowerWorld" })
	local modelState = source(nil :: ModelState?)
	local activeTrack = source(nil :: AnimationTrack?)

	-- Model ownership: clone once per tower and keep each viewport fully isolated.
	effect(function()
		local towerName = read(props.TowerName)
		modelState(nil)

		if not towerName or towerName == "" then
			return
		end

		local towerAsset = getTowerAsset(towerName)
		if not towerAsset then
			return
		end

		local model = towerAsset:Clone()
		local state = prepareModel(model, towerName)
		model.Parent = worldModel
		cleanup(function()
			if modelState() == state then
				modelState(nil)
			end
			model:Destroy()
		end)
		modelState(state)
	end)

	-- Spring updates only transform the existing clone and its camera.
	effect(function()
		local state = modelState()
		if not state then
			return
		end

		local modelCFrame = getModelCFrame(read(props.ModelRotation) or 0)
		state.Instance:PivotTo(modelCFrame)

		-- Cached bounds avoid an expensive GetBoundingBox call on every spring step.
		updateCamera(
			camera,
			state,
			modelCFrame,
			read(props.FieldOfView) or DEFAULT_FIELD_OF_VIEW,
			read(props.CameraDirection) or DEFAULT_CAMERA_DIRECTION,
			read(props.FitPadding) or DEFAULT_FIT_PADDING,
			read(props.FocusYOffset) or 0
		)
	end)

	-- Reload only when the model or selected animation changes.
	effect(function()
		local state = modelState()
		if not state then
			return
		end

		local animation = createAnimation(
			state.TowerName,
			read(props.AnimationId),
			read(props.AnimationName),
			read(props.AnimationLevel)
		)
		if not animation then
			return
		end

		cleanup(startAnimation(state.Instance, animation, read(props.AnimationFadeTime), activeTrack))
	end)

	-- Loop and speed updates are cheap and do not restart the animation.
	effect(function()
		local track = activeTrack()
		if not track then
			return
		end

		track.Looped = read(props.AnimationLooped) ~= false
		track:AdjustSpeed(read(props.AnimationSpeed) or 1)
	end)

	return create("ViewportFrame")({
		Name = props.Name or "TowerViewport",
		AnchorPoint = props.AnchorPoint,
		BackgroundColor3 = props.BackgroundColor3,
		BackgroundTransparency = props.BackgroundTransparency or 1,
		ImageTransparency = props.ImageTransparency or 0,
		BorderSizePixel = 0,
		Position = props.Position,
		Size = props.Size or UDim2.fromScale(1, 1),
		Visible = props.Visible,
		ZIndex = props.ZIndex,
		Ambient = props.Ambient or Color3.fromRGB(180, 180, 180),
		LightColor = props.LightColor or Color3.new(1, 1, 1),
		LightDirection = props.LightDirection or Vector3.new(-1, -1, -1),
		CurrentCamera = camera,

		camera,
		worldModel,
	})
end
