-- // VARIABLES // --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local ViewportModel = require(ReplicatedStorage.Shared.Modules.Utils.ViewportModel)
local DialogueData = require(ReplicatedStorage.Settings.Data.CommanderDialogueData)

-- // FUNCTIONS // --
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
		BackgroundTransparency = presentation.Fade,
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
	if root and root:IsA("BasePart") then
		model.PrimaryPart = root
		root.PivotOffset = CFrame.identity
	end
	model:PivotTo(CFrame.identity)
	model.Parent = world
	local fit = ViewportModel.new(viewport, camera)
	fit:SetModel(model, true, true)
	local direction = DialogueData.Camera.Direction.Unit
	local orientation = CFrame.lookAt(Vector3.zero, -direction)
	local function updateCamera()
		if viewport.AbsoluteSize.X <= 0 or viewport.AbsoluteSize.Y <= 0 then
			return
		end
		fit:Calibrate()
		local fitted = fit:GetMinimumFitCFrame(orientation)
		local padding = fit:GetFitDistance() * (DialogueData.Camera.Padding - 1)
		camera.CFrame = fitted + direction * padding
		camera.Focus = CFrame.new(model:GetBoundingBox().Position)
	end
	Vide.cleanup(viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateCamera))
	updateCamera()
	return viewport
end

-- // INITIALIZATION // --
return createPortrait
