local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local SceneTransform = require(ReplicatedStorage.Shared.Modules.Cutscene.SceneTransform)

local LocalSceneView = {}
LocalSceneView.__index = LocalSceneView

local nextId = 0

local function findCameraPart(scene: Instance, name: string): BasePart
	local direct = scene:FindFirstChild(name)
	if direct then
		assert(direct:IsA("BasePart"), `"{name}" must be a BasePart, not {direct.ClassName}`)
		return direct
	end

	local found: BasePart? = nil
	for _, descendant in scene:GetDescendants() do
		if descendant.Name == name then
			assert(descendant:IsA("BasePart"), `"{name}" must be a BasePart, not {descendant.ClassName}`)
			assert(found == nil, `Scene contains more than one "{name}" camera part`)
			found = descendant
		end
	end
	assert(found, `Scene is missing the "{name}" camera part`)
	return found :: BasePart
end

local function prepareScene(scene: Instance)
	for _, descendant in scene:GetDescendants() do
		if descendant:IsA("BaseScript") then
			descendant.Enabled = false
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end
end

-- The caller owns the returned view. The cloned folder stays local to this client.
-- SceneTransform moves every top-level part/model with the same world-space CFrame.
function LocalSceneView.Mount(source: Instance, transform: CFrame, cameraPartName: string): (any?, string?)
	if not source:IsA("Folder") then
		return nil, `Scene source must be a Folder, got {source.ClassName}`
	end

	local originalArchivable = {}
	local cloned, scene = pcall(function()
		originalArchivable[source] = source.Archivable
		source.Archivable = true
		for _, descendant in source:GetDescendants() do
			originalArchivable[descendant] = descendant.Archivable
			descendant.Archivable = true
		end
		return source:Clone()
	end)
	for instance, value in originalArchivable do
		if instance.Parent or instance == source then
			instance.Archivable = value
		end
	end
	if not cloned or not scene then
		return nil, `Could not clone scene "{source:GetFullName()}"`
	end

	local cameraPart: BasePart?
	local placed, placementError = pcall(function()
		SceneTransform.Apply(scene, transform)
		prepareScene(scene)
		local cam = findCameraPart(scene, cameraPartName)
		cameraPart = cam
		cam.Transparency = 1
	end)
	if not placed then
		scene:Destroy()
		return nil, tostring(placementError)
	end
	local activeCam = assert(cameraPart, "Camera part was not prepared") :: BasePart

	nextId += 1
	local self = setmetatable({
		Scene = scene,
		CameraPart = activeCam,
		CameraStates = {},
		RenderStepName = `LocalSceneViewCamera_{nextId}`,
		Destroyed = false,
	}, LocalSceneView)
	scene.Name = `{source.Name}_LocalView`
	scene.Parent = Workspace

	local function updateCamera()
		if self.Destroyed or not scene.Parent or not activeCam.Parent then
			return
		end
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		if not self.CameraStates[camera] then
			self.CameraStates[camera] = {
				CameraType = camera.CameraType,
				CameraSubject = camera.CameraSubject,
				CFrame = camera.CFrame,
				Focus = camera.Focus,
			}
		end
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = activeCam.CFrame
		camera.Focus = camera.CFrame * CFrame.new(0, 0, -10)
	end

	updateCamera()
	RunService:BindToRenderStep(self.RenderStepName, Enum.RenderPriority.Camera.Value + 1, updateCamera)
	return self, nil
end

function LocalSceneView:Destroy()
	if self.Destroyed then
		return
	end
	self.Destroyed = true
	RunService:UnbindFromRenderStep(self.RenderStepName)
	self.Scene:Destroy()
	for camera, state in self.CameraStates do
		if camera.Parent then
			local subject = state.CameraSubject
			if not subject or not subject.Parent then
				local character = Players.LocalPlayer.Character
				subject = character and character:FindFirstChildOfClass("Humanoid")
			end
			if subject then
				camera.CameraSubject = subject
			end
			camera.CameraType = state.CameraType
			camera.CFrame = state.CFrame
			camera.Focus = state.Focus
		end
	end
	table.clear(self.CameraStates)
end

return LocalSceneView
