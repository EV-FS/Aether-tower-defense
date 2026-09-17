local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)

local cleanup = Vide.cleanup
local create = Vide.create
local effect = Vide.effect
local read = Vide.read
local source = Vide.source
local untrack = Vide.untrack

local DEFAULT_CAMERA_DIRECTION = Vector3.new(0, 0, -1)
local DEFAULT_FIELD_OF_VIEW = 35
local DEFAULT_FIT_PADDING = 1.1
local MINIMUM_RADIUS = 0.01

type Reactive<T> = T | (() -> T)

type RigState = {
	Model: Model,
	Center: Vector3,
	Radius: number,
}

export type Props = {
	--GuiObject
	Active: Reactive<boolean>?,
	AnchorPoint: Reactive<Vector2>?,
	BackgroundColor3: Reactive<Color3>?,
	BackgroundTransparency: Reactive<number>?,
	ClipsDescendants: Reactive<boolean>?,
	LayoutOrder: Reactive<number>?,
	Name: Reactive<string>?,
	Position: Reactive<UDim2>?,
	Rotation: Reactive<number>?,
	Size: Reactive<UDim2>?,
	Visible: Reactive<boolean>?,
	ZIndex: Reactive<number>?,

	--ViewportFrame
	Ambient: Reactive<Color3>?,
	ImageColor3: Reactive<Color3>?,
	ImageTransparency: Reactive<number>?,
	LightColor: Reactive<Color3>?,
	LightDirection: Reactive<Vector3>?,

	--RigViewport
	Rig: Reactive<Model?>?,
	CenterOffset: Reactive<Vector3>?,
	FieldOfView: Reactive<number>?,
	CameraDirection: Reactive<Vector3>?,
	FitPadding: Reactive<number>?,
	Zoom: Reactive<number>?,
	RigRotation: Reactive<Vector3>?,
	UseWorldModel: boolean?,
	OnRigChanged: ((Model?) -> ())?,

	--RigAnmation
	Animation: Reactive<Animation?>?,
	AutoPlay: boolean?,
	AnimationLooped: Reactive<boolean>?,
	AnimationSpeed: Reactive<number>?,
	AnimationFadeTime: number?,
	OnTrackChanged: ((AnimationTrack?) -> ())?,
}

-------------------------------------------------
--// Local Functions
-------------------------------------------------
local function prepareRig(model: Model): RigState
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BaseScript") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.LocalTransparencyModifier = 0
		end
	end

	local humanoidRootPart = model:FindFirstChild("HumanoidRootPart", true)
	local root = model.PrimaryPart or humanoidRootPart
	if not root or not root:IsA("BasePart") then
		root = model:FindFirstChildWhichIsA("BasePart", true)
	end
	if root and root:IsA("BasePart") then
		root.Anchored = true
	end

	model:PivotTo(CFrame.identity)
	local bounds: CFrame
	local size: Vector3
	if humanoidRootPart and humanoidRootPart:IsA("BasePart") then
		bounds = humanoidRootPart.CFrame
		size = humanoidRootPart.Size
	else
		bounds, size = model:GetBoundingBox()
	end

	return {
		Model = model,
		Center = bounds.Position,
		Radius = math.max(size.Magnitude * 0.5, MINIMUM_RADIUS),
	}
end

local function getAnimator(model: Model): Animator
	local controller = model:FindFirstChildWhichIsA("Humanoid", true)
		or model:FindFirstChildWhichIsA("AnimationController", true)
	if not controller then
		controller = Instance.new("AnimationController")
		controller.Parent = model
	end

	local animator = controller:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = controller
	end

	return animator
end

local function getRigCFrame(props: Props): CFrame
	local rotation = read(props.RigRotation) or Vector3.zero
	return CFrame.Angles(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z))
end

local function updateCamera(camera: Camera, state: RigState, size: Vector2, props: Props)
	local fieldOfView = math.clamp(read(props.FieldOfView) or DEFAULT_FIELD_OF_VIEW, 1, 120)
	local direction = read(props.CameraDirection) or DEFAULT_CAMERA_DIRECTION
	direction = if direction.Magnitude > 0 then direction.Unit else DEFAULT_CAMERA_DIRECTION

	local aspectRatio = if size.X > 0 and size.Y > 0 then size.X / size.Y else 1
	local halfAngle = math.atan(math.tan(math.rad(fieldOfView) * 0.5) * math.min(aspectRatio, 1))
	local padding = math.max(read(props.FitPadding) or DEFAULT_FIT_PADDING, 1)
	local zoom = math.max(read(props.Zoom) or 1, 0.01)
	local distance =
		math.max(state.Radius / math.sin(halfAngle) * padding / zoom, state.Radius + math.abs(camera.NearPlaneZ))
	local focus = getRigCFrame(props):PointToWorldSpace(state.Center + (read(props.CenterOffset) or Vector3.zero))
	local up = if math.abs(direction:Dot(Vector3.yAxis)) > 0.999 then Vector3.zAxis else Vector3.yAxis

	camera.FieldOfView = fieldOfView
	camera.Focus = CFrame.new(focus)
	camera.CFrame = CFrame.lookAt(focus + direction * distance, focus, up)
end

-------------------------------------------------
--// RigViewPort
-------------------------------------------------
return function(props: Props): ViewportFrame
	local camera = create("Camera")({
		Name = "RigCamera",
		CameraType = Enum.CameraType.Scriptable,
		FieldOfViewMode = Enum.FieldOfViewMode.Vertical,
	})
	local worldModel = props.UseWorldModel == true and create("WorldModel")({
		Name = "RigWorld",
	})

	local viewport = create("ViewportFrame")({
		Name = props.Name or "RigViewport",
		Active = props.Active,
		AnchorPoint = props.AnchorPoint,
		BackgroundColor3 = props.BackgroundColor3,
		BackgroundTransparency = props.BackgroundTransparency or 1,
		BorderSizePixel = 0,
		ClipsDescendants = props.ClipsDescendants,
		LayoutOrder = props.LayoutOrder,
		Position = props.Position,
		Rotation = props.Rotation,
		Size = props.Size or UDim2.fromScale(1, 1),
		Visible = props.Visible,
		ZIndex = props.ZIndex,

		Ambient = props.Ambient or Color3.fromRGB(180, 180, 180),
		ImageColor3 = props.ImageColor3,
		ImageTransparency = props.ImageTransparency,
		LightColor = props.LightColor or Color3.new(1, 1, 1),
		LightDirection = props.LightDirection or Vector3.new(-1, -1, -1),
		CurrentCamera = camera,

		camera,
		worldModel,
	})

	local rigState = source(nil :: RigState?)
	local activeTrack = source(nil :: AnimationTrack?)
	local viewportSize = source(viewport.AbsoluteSize)
	cleanup(viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		viewportSize(viewport.AbsoluteSize)
	end))
	cleanup(function()
		rigState(nil)
		viewport:Destroy()
	end)

	effect(function()
		local rig = read(props.Rig)
		if not rig then
			return
		end

		local model = rig:Clone()
		if not model then
			warn(`[RigViewport] Rig "{rig.Name}" must be Archivable to create a preview.`)
			return
		end
		cleanup(function()
			rigState(nil)
			model:Destroy()
		end)
		local state = prepareRig(model)
		model.Parent = viewport
		rigState(state)
	end)

	effect(function()
		local state = rigState()
		if not state then
			return
		end
		state.Model:PivotTo(getRigCFrame(props))
	end)

	effect(function()
		local state = rigState()
		if not state then
			return
		end
		updateCamera(camera, state, viewportSize(), props)
	end)

	effect(function()
		local state = rigState()
		if state and props.OnRigChanged then
			cleanup(function()
				untrack(function()
					props.OnRigChanged(nil)
				end)
			end)
			untrack(function()
				props.OnRigChanged(state.Model)
			end)
		end
	end)

	effect(function()
		local state = rigState()
		local animation = read(props.Animation)
		if not state or not animation then
			return
		end
		if not props.UseWorldModel then
			warn("애니메이션을 재생하기 위해선 WorldModel을 사용해야 함.")
			return
		end

		local track
		local loadThread = task.defer(function()
			while not state.Model:IsDescendantOf(game) do
				state.Model.AncestryChanged:Wait()
			end

			local ok, result = pcall(function()
				return getAnimator(state.Model):LoadAnimation(animation)
			end)
			if not ok then
				warn(`Failed to load animation "{animation.AnimationId}": {result}`)
				return
			end

			track = result
			if props.AutoPlay ~= false then
				track:Play(math.max(props.AnimationFadeTime or 0.1, 0))
			end
			activeTrack(track)
		end)
		cleanup(function()
			if loadThread ~= coroutine.running() and coroutine.status(loadThread) ~= "dead" then
				task.cancel(loadThread)
			end
			activeTrack(nil)
			if track then
				track:Stop(0)
				track:Destroy()
			end
		end)
	end)

	effect(function()
		local track = activeTrack()
		if not track then
			return
		end
		local looped = read(props.AnimationLooped)
		local speed = read(props.AnimationSpeed)
		if looped ~= nil then
			track.Looped = looped
		end
		if speed ~= nil then
			track:AdjustSpeed(speed)
		end
	end)

	effect(function()
		local track = activeTrack()
		if track and props.OnTrackChanged then
			cleanup(function()
				untrack(function()
					props.OnTrackChanged(nil)
				end)
			end)
			untrack(function()
				props.OnTrackChanged(track)
			end)
		end
	end)

	return viewport
end
