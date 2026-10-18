-- // VARIABLES // --
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")

local Vide = require(ReplicatedStorage.Packages.Vide)
local ViewportModel = require(ReplicatedStorage.Shared.Modules.Utils.ViewportModel)
local DialogueData = require(ReplicatedStorage.Settings.Data.CommanderDialogueData)
local CommanderPortraitBounds = require(script.Parent.CommanderPortraitBounds)

-- // FUNCTIONS // --
--[[ Blends the mounted portrait between idle and urgent transmissions. ]]
local function playAnimations(model: Model, presentation)
	local controller = model:FindFirstChildOfClass("Humanoid") or model:FindFirstChildOfClass("AnimationController")
	if not controller then
		controller = Instance.new("AnimationController")
		controller.Parent = model
	end
	local animator = controller:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = controller
	local active = true
	local started = false
	local animations: { Animation } = {}
	local tracks: { [string]: AnimationTrack } = {}
	local currentTrack: AnimationTrack? = nil
	local danger = false
	local function updateTrack()
		if not active then
			return
		end
		local nextTrack = (if danger then tracks.Danger else nil) or tracks.Idle
		if currentTrack == nextTrack then
			return
		end
		if currentTrack then
			currentTrack:Stop(0.2)
		end
		currentTrack = nextTrack
		if currentTrack then
			currentTrack:Play(0.2)
		end
	end
	local function loadTrack(name: string, assetId: string)
		local animation = Instance.new("Animation")
		animation.Name = `Commander{name}`
		animation.AnimationId = assetId
		animation.Parent = model
		table.insert(animations, animation)
		task.spawn(function()
			local success, result = pcall(function()
				ContentProvider:PreloadAsync({ animation })
				if not active then
					return nil
				end
				return animator:LoadAnimation(animation)
			end)
			if not success then
				if active then
					warn(`Commander {name} animation could not load: {result}`)
				end
				return
			end
			if not result then
				return
			end
			if not active then
				result:Destroy()
				return
			end
			result.Priority = if name == "Danger" then Enum.AnimationPriority.Action else Enum.AnimationPriority.Idle
			result.Looped = true
			tracks[name] = result
			updateTrack()
		end)
	end
	local function startWhenMounted()
		if started or not active or not model:IsDescendantOf(game) then
			return
		end
		started = true
		loadTrack("Idle", DialogueData.IdleAnimationId)
		if presentation.IsDanger then
			loadTrack("Danger", DialogueData.DangerAnimationId)
		end
	end
	Vide.cleanup(model.AncestryChanged:Connect(startWhenMounted))
	Vide.cleanup(function()
		active = false
		for _, track in tracks do
			track:Stop(0)
			track:Destroy()
		end
		for _, animation in animations do
			animation:Destroy()
		end
	end)
	Vide.effect(function()
		danger = if presentation.IsDanger then presentation.IsDanger() else false
		updateTrack()
	end)
	startWhenMounted()
end

--[[ Creates an isolated portrait fitted to the available display area. ]]
local function createPortrait(rig: Model, presentation): ViewportFrame
	local camera = Vide.create("Camera")({
		Name = "Camera",
		CameraType = Enum.CameraType.Scriptable,
		FieldOfViewMode = Enum.FieldOfViewMode.Vertical,
		FieldOfView = DialogueData.Camera.FieldOfView,
	})
	local world = Vide.create("WorldModel")({ Name = "WorldModel" })
	local viewport = Vide.create("ViewportFrame")({
		Name = "ViewportFrame",
		AnchorPoint = Vector2.new(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		ImageTransparency = presentation.Fade,
		BorderSizePixel = 0,
		Position = presentation.Position,
		Size = presentation.Size or UDim2.fromScale(0.099479, 0.204366),
		ZIndex = 1,
		Ambient = Color3.fromRGB(180, 180, 180),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-1, -1, -1),
		CurrentCamera = camera,
		camera,
		world,
		Vide.create("UIAspectRatioConstraint")({ AspectRatio = 1 }),
		Vide.create("UIGradient")({
			Rotation = -90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.0907859, 0.33125),
				NumberSequenceKeypoint.new(0.191057, 0),
				NumberSequenceKeypoint.new(0.52439, 0),
				NumberSequenceKeypoint.new(1, 0),
			}),
		}),
	})
	Vide.cleanup(function()
		viewport:Destroy()
	end)
	local model = rig:Clone()
	assert(model, "Commander model must be Archivable")
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BaseScript") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.LocalTransparencyModifier = 0
		end
	end
	local root = model:FindFirstChild("HumanoidRootPart", true)
		or model.PrimaryPart
		or model:FindFirstChildWhichIsA("BasePart", true)
	if root and root:IsA("BasePart") then
		model.PrimaryPart = root
		root.PivotOffset = CFrame.identity
	end
	model:PivotTo(CFrame.identity)
	model.Parent = world
	local fit = ViewportModel.new(viewport, camera)
	fit:SetModel(model, true, true, CommanderPortraitBounds.GetPoints(model, DialogueData.Camera.TorsoFraction))
	local cameraDirection = DialogueData.Camera.Direction
	local direction = if cameraDirection.Magnitude > 0 then cameraDirection.Unit else Vector3.new(0, 0, -1)
	local orientation = CFrame.lookAt(Vector3.zero, -direction)
	local head = model:FindFirstChild("Head", true)
	local focus = if head and head:IsA("BasePart") then head.Position else model:GetBoundingBox().Position
	local function updateCamera()
		if viewport.AbsoluteSize.X <= 0 or viewport.AbsoluteSize.Y <= 0 then
			return
		end
		fit:Calibrate()
		local fitted = fit:GetMinimumFitCFrame(orientation)
		local padding = fit:GetFitDistance() * (DialogueData.Camera.Padding - 1)
		camera.CFrame = fitted + direction * padding
		camera.Focus = CFrame.new(focus)
	end
	Vide.cleanup(viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateCamera))
	updateCamera()
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = descendant == root
		end
	end
	playAnimations(model, presentation)
	return viewport
end

-- // INITIALIZATION // --
return createPortrait
