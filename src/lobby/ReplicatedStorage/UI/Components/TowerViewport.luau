local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local ViewportModel = require(ReplicatedStorage.Shared.Modules.Utils.ViewportModel)
local PortraitCamera = require(script.Parent.PortraitCamera)
local useTowerAsset = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useTowerAsset)

local cleanup = Vide.cleanup
local create = Vide.create
local effect = Vide.effect
local read = Vide.read
local source = Vide.source
local action = Vide.action

local DEFAULT_CAMERA_DIRECTION = Vector3.new(0, 0, -1)
local DEFAULT_FIELD_OF_VIEW = 35
local DEFAULT_FIT_PADDING = 1.1
local MINIMUM_BOUNDS_RADIUS = 0.01
local MAX_PREPARED_TEMPLATES = 8

type Reactive<T> = T | (() -> T)
type AnimationId = number | string

type ModelState = {
	Instance: Model,
	TowerName: string,
	SourceAsset: Model?,
	RootPart: BasePart?,
	HasPortraitHead: boolean,
	FocusOffset: Vector3,
	BoundsRadius: number,
}

type PreparedTemplate = {
	Model: Model,
	FitPointClouds: { [string]: { Vector3 } },
	HasPortraitHead: boolean,
	FocusOffset: Vector3,
	BoundsRadius: number,
	LastUsed: number,
}

local preparedTemplates: { [Model]: PreparedTemplate } = {}
local preparedTemplateCount = 0
local preparedTemplateClock = 0

export type Props = {
	TowerName: Reactive<string?>,
	Name: string?,
	AnchorPoint: Reactive<Vector2>?,
	Position: Reactive<UDim2>?,
	Size: Reactive<UDim2>?,
	Visible: Reactive<boolean>?,
	Active: Reactive<boolean>?,
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
	UseViewportModel: Reactive<boolean>?,
	UseCharacterBounds: Reactive<boolean>?,
	UsePortraitBounds: Reactive<boolean>?,
	PortraitUpdateInterval: Reactive<number>?,
	CenterOnRoot: Reactive<boolean>?,
	RenderEffects: Reactive<boolean>?,
	FocusYOffset: Reactive<number>?,
	ModelRotation: Reactive<number>?,
	AnimationName: Reactive<string?>?,
	AnimationLevel: Reactive<number?>?,
	AnimationId: Reactive<AnimationId?>?,
	AnimationLooped: Reactive<boolean>?,
	AnimationSpeed: Reactive<number>?,
	AnimationFadeTime: Reactive<number>?,
	OnModelChanged: ((Model?) -> ())?,
}

local function findRootPart(model: Model): BasePart?
	local humanoidRootPart = model:FindFirstChild("HumanoidRootPart", true)
	if humanoidRootPart and humanoidRootPart:IsA("BasePart") then
		return humanoidRootPart
	end
	if model.PrimaryPart then
		return model.PrimaryPart
	end

	return model:FindFirstChildWhichIsA("BasePart", true)
end

local function prepareModel(model: Model, towerName: string, renderEffects: boolean): ModelState
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BaseScript") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.LocalTransparencyModifier = 0
		elseif not renderEffects and (
			descendant:IsA("ParticleEmitter")
			or descendant:IsA("Trail")
			or descendant:IsA("Beam")
		) then
			-- These effects were invisible in cards already. Strip them from the
			-- prepared template so every visible clone is smaller as well.
			descendant:Destroy()
		end
	end

	local rootPart = findRootPart(model)
	if rootPart then
		rootPart.Anchored = true
		-- Normalize the clone's pivot as well as selecting the correct anchor.
		-- Authored PrimaryPart/PivotOffset values may point at a weapon or be rotated.
		model.PrimaryPart = rootPart
		rootPart.PivotOffset = CFrame.identity
	end

	-- Every viewport owns its own WorldModel, so the model can use a stable local origin.
	model:PivotTo(CFrame.identity)

	local boundsCFrame, boundsSize = model:GetBoundingBox()
	return {
		Instance = model,
		TowerName = towerName,
		SourceAsset = nil,
		RootPart = rootPart,
		HasPortraitHead = PortraitCamera.FindPart(model, "Head") ~= nil,
		FocusOffset = boundsCFrame.Position + Vector3.new(0, boundsSize.Y * 0.05, 0),
		BoundsRadius = math.max(boundsSize.Magnitude * 0.5, MINIMUM_BOUNDS_RADIUS),
	}
end

local function clonePreparedModel(asset: Model, towerName: string): (Model, ModelState)
	local prepared = preparedTemplates[asset]
	if not prepared then
		local template = asset:Clone()
		local templateState = prepareModel(template, towerName, false)
		prepared = {
			Model = template,
			FitPointClouds = {},
			HasPortraitHead = templateState.HasPortraitHead,
			FocusOffset = templateState.FocusOffset,
			BoundsRadius = templateState.BoundsRadius,
			LastUsed = 0,
		}
		preparedTemplates[asset] = prepared
		preparedTemplateCount += 1
	end
	preparedTemplateClock += 1
	prepared.LastUsed = preparedTemplateClock

	if preparedTemplateCount > MAX_PREPARED_TEMPLATES then
		local oldestAsset: Model? = nil
		local oldestUse = math.huge
		for cachedAsset, entry in preparedTemplates do
			if entry.LastUsed < oldestUse then
				oldestAsset = cachedAsset
				oldestUse = entry.LastUsed
			end
		end
		if oldestAsset then
			preparedTemplates[oldestAsset].Model:Destroy()
			preparedTemplates[oldestAsset] = nil
			preparedTemplateCount -= 1
		end
	end

	local model = prepared.Model:Clone()
	return model, {
		Instance = model,
		TowerName = towerName,
		SourceAsset = asset,
		RootPart = model.PrimaryPart,
		HasPortraitHead = prepared.HasPortraitHead,
		FocusOffset = prepared.FocusOffset,
		BoundsRadius = prepared.BoundsRadius,
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
	local towerTemplate = useTowerAsset(props.TowerName, function(asset)
		local prepared = preparedTemplates[asset]
		if prepared then
			preparedTemplates[asset] = nil
			preparedTemplateCount -= 1
			prepared.Model:Destroy()
		end
	end)
	local camera = create("Camera")({ Name = "TowerCamera" })
	local worldModel = create("WorldModel")({ Name = "TowerWorld" })
	local modelState = source(nil :: ModelState?)
	local activeTrack = source(nil :: AnimationTrack?)
	local viewportFrame = source(nil :: ViewportFrame?)
	local viewportFitter = source(nil)
	local viewportFitterRevision = source(0)
	local fittedCamera: CFrame?
	local fittedCameraFitter = nil
	local fittedCameraRevision = -1
	local fittedFieldOfView: number?
	local fittedDirection: Vector3?
	local fittedFocusPosition: Vector3?

	-- Model ownership: clone once per tower and keep each viewport fully isolated.
	effect(function()
		local towerName = read(props.TowerName)
		modelState(nil)

		if not towerName or towerName == "" then
			return
		end

		local towerAsset = towerTemplate()
		if not towerAsset then
			return
		end

		local renderEffects = read(props.RenderEffects) ~= false
		local model: Model
		local state: ModelState
		if renderEffects then
			model = towerAsset:Clone()
			state = prepareModel(model, towerName, true)
		else
			model, state = clonePreparedModel(towerAsset, towerName)
		end
		model.Parent = worldModel
		if props.OnModelChanged then
			props.OnModelChanged(model)
		end
		cleanup(function()
			if props.OnModelChanged then
				props.OnModelChanged(nil)
			end
			if modelState() == state then
				modelState(nil)
			end
			model:Destroy()
		end)
		modelState(state)
	end)

	-- ViewportModel caches the model bounds and derives a camera distance from the
	-- actual ViewportFrame dimensions. It is opt-in for views that need a tight fit.
	effect(function()
		local state = modelState()
		local frame = viewportFrame()
		viewportFitter(nil)
		if not read(props.UseViewportModel) or not state or not frame then
			return
		end
		local useCharacterBounds = read(props.UseCharacterBounds) == true
		local usePortraitBounds = read(props.UsePortraitBounds) == true
		if usePortraitBounds and state.HasPortraitHead then
			return
		end
		-- Fit the final orientation immediately; do not show sphere bounds first
		-- and then reframe the animated pose half a second later.
		local rotation = read(props.ModelRotation) or 0
		state.Instance:PivotTo(getModelCFrame(rotation))
		local fitter = ViewportModel.new(frame, camera)
		-- Identical card clones have identical authored geometry. Reuse the
		-- measured point cloud instead of traversing every part on every scroll.
		local prepared = if state.SourceAsset and type(props.ModelRotation) == "number"
			then preparedTemplates[state.SourceAsset]
			else nil
		local fitKey = if prepared then `{rotation}:{useCharacterBounds}:{usePortraitBounds}` else nil
		local cachedPoints = if prepared and fitKey then prepared.FitPointClouds[fitKey] else nil
		local points = fitter:SetModel(state.Instance, useCharacterBounds or usePortraitBounds, usePortraitBounds, cachedPoints)
		if prepared and fitKey and not cachedPoints then
			prepared.FitPointClouds[fitKey] = points
		end
		viewportFitter(fitter)

		local sizeConnection = frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			if frame.AbsoluteSize.X <= 0 or frame.AbsoluteSize.Y <= 0 or viewportFitter() ~= fitter then
				return
			end
			-- The camera effect performs calibration after this revision changes.
			-- Doing it here as well doubled the work throughout window-size springs.
			viewportFitterRevision(viewportFitterRevision() + 1)
		end)

		cleanup(function()
			sizeConnection:Disconnect()
			if viewportFitter() == fitter then
				viewportFitter(nil)
			end
		end)
	end)

	-- Spring updates only transform the existing clone and its camera.
	effect(function()
		if read(props.Active) == false then
			return
		end

		local state = modelState()
		if not state then
			return
		end

		local modelCFrame = getModelCFrame(read(props.ModelRotation) or 0)
		state.Instance:PivotTo(modelCFrame)
		if read(props.UsePortraitBounds) == true and state.HasPortraitHead then
			return -- Animated portrait camera owns framing for this rig.
		end
		local fitter = viewportFitter()
		local fitPadding = math.max(read(props.FitPadding) or DEFAULT_FIT_PADDING, 0.5)
		if fitter then
			local fitterRevision = viewportFitterRevision()
			camera.FieldOfView = math.clamp(read(props.FieldOfView) or DEFAULT_FIELD_OF_VIEW, 1, 120)
			local direction = read(props.CameraDirection) or DEFAULT_CAMERA_DIRECTION
			direction = if direction.Magnitude > 0 then direction.Unit else DEFAULT_CAMERA_DIRECTION
			local focusPosition = if read(props.CenterOnRoot) == true and state.RootPart
				then state.RootPart.Position
				else nil
			if fittedCameraFitter ~= fitter or fittedCameraRevision ~= fitterRevision
				or fittedFieldOfView ~= camera.FieldOfView or fittedDirection ~= direction
				or fittedFocusPosition ~= focusPosition then
				fitter:Calibrate()
				-- Use the model's part-level bounds instead of its bounding sphere. This
				-- avoids excessive empty space on tall or wide units.
				local orientation = CFrame.lookAt(Vector3.zero, -direction)
				fittedCamera = fitter:GetMinimumFitCFrame(orientation, focusPosition)
				fittedCameraFitter = fitter
				fittedCameraRevision = fitterRevision
				fittedFieldOfView = camera.FieldOfView
				fittedDirection = direction
				fittedFocusPosition = focusPosition
			end

			local paddingDistance = fitter:GetFitDistance() * (fitPadding - 1)
			camera.CFrame = (fittedCamera :: CFrame)
				* CFrame.new(0, read(props.FocusYOffset) or 0, paddingDistance)
			return
		end

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

	-- Track after animation evaluation. No GetBoundingBox/point-cloud traversal
	-- runs per frame; hidden cards unregister from the shared update loop.
	effect(function()
		local state = modelState()
		local frame = viewportFrame()
		if not state or not frame or read(props.Active) == false
			or read(props.Visible) == false or read(props.UsePortraitBounds) ~= true then
			return
		end
		local stop = PortraitCamera.Track(state.Instance, frame, camera, {
			Padding = math.max(read(props.FitPadding) or DEFAULT_FIT_PADDING, 0.5),
			FieldOfView = math.clamp(read(props.FieldOfView) or DEFAULT_FIELD_OF_VIEW, 1, 120),
			Direction = read(props.CameraDirection) or DEFAULT_CAMERA_DIRECTION,
			FocusYOffset = read(props.FocusYOffset) or 0,
			UpdateInterval = read(props.PortraitUpdateInterval) or 0,
		})
		if stop then
			cleanup(stop)
		end
	end)

	-- Reload only when the model or selected animation changes.
	effect(function()
		if read(props.Active) == false then
			return
		end

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
		action(function(instance)
			viewportFrame(instance)
		end),

		camera,
		worldModel,
	})
end
