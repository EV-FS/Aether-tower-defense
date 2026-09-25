-- Run in Studio with ReplicatedStorage.Shared.Modules.Cutscene.SceneTransform.
return function(SceneTransform)
	local source = Instance.new("Folder")
	source.Name = "Scene"
	local scenery = Instance.new("Folder")
	scenery.Name = "Scenery"
	scenery.Parent = source
	local map = Instance.new("Model")
	map.Name = "Map"
	map.Parent = scenery
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Anchored = true
	floor.CFrame = CFrame.new(4, 2, -7) * CFrame.Angles(0, 0.3, 0)
	floor.Parent = map
	local cam = Instance.new("Model")
	cam.Name = "Cam"
	cam.Parent = source
	local cameraPart = Instance.new("Part")
	cameraPart.Name = "CamPart"
	cameraPart.CFrame = CFrame.new(-2, 8, 5) * CFrame.Angles(0.2, -0.4, 0)
	cameraPart.Parent = cam
	cam.PrimaryPart = cameraPart
	local rig = Instance.new("Model")
	rig.Name = "PlayerRig"
	rig.Parent = source
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.CFrame = CFrame.new(9, 3, 1) * CFrame.Angles(0, 1, 0)
	root.Parent = rig
	rig.PrimaryPart = root
	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.CFrame = root.CFrame * CFrame.new(0, 2, 0)
	torso.Parent = rig
	local motor = Instance.new("Motor6D")
	motor.Name = "RootJoint"
	motor.Part0 = root
	motor.Part1 = torso
	motor.C0 = CFrame.new(0, 1, 0)
	motor.C1 = CFrame.new(0, -1, 0)
	motor.Parent = root
	local reference = Instance.new("ObjectValue")
	reference.Value = root
	reference.Parent = cam

	local clone = source:Clone()
	source:Destroy()
	local clonedFloor = clone.Scenery.Map.Floor
	local clonedCamera = clone.Cam.CamPart
	local clonedRoot = clone.PlayerRig.HumanoidRootPart
	local clonedTorso = clone.PlayerRig.Torso
	local clonedMotor = clonedRoot.RootJoint
	assert(clone.Cam.ObjectValue.Value == clonedRoot, "Cloning the scene must preserve internal references")
	local originalC0, originalC1 = clonedMotor.C0, clonedMotor.C1
	local original = {
		[clonedFloor] = clonedFloor.CFrame,
		[clonedCamera] = clonedCamera.CFrame,
		[clonedRoot] = clonedRoot.CFrame,
		[clonedTorso] = clonedTorso.CFrame,
	}
	local cameraToRig = clonedCamera.CFrame:ToObjectSpace(clonedRoot.CFrame)
	local transform = CFrame.new(10000, 250, -300) * CFrame.Angles(0, math.rad(35), 0)
	assert(SceneTransform.Apply(clone, transform) == 4)
	for part, before in original do
		local expected = transform * before
		assert((part.Position - expected.Position).Magnitude < 0.025, part.Name .. " moved to the wrong position")
		assert(part.CFrame.RightVector:Dot(expected.RightVector) > 0.99999, part.Name .. " rotated incorrectly")
	end
	local relative = clonedCamera.CFrame:ToObjectSpace(clonedRoot.CFrame)
	assert((relative.Position - cameraToRig.Position).Magnitude < 0.025, "Camera-to-rig spacing changed")
	assert(relative.RightVector:Dot(cameraToRig.RightVector) > 0.99999, "Camera-to-rig rotation changed")
	assert(clone.Cam.ObjectValue.Value == clonedRoot, "Scene references changed during placement")
	assert(clonedMotor.Part0 == clonedRoot and clonedMotor.Part1 == clonedTorso, "Rig joints changed during placement")
	assert(clonedMotor.C0 == originalC0 and clonedMotor.C1 == originalC1, "Rig joint offsets changed during placement")
	clone:Destroy()
	print("PASS: scene placement preserves the map, camera, rig, and their relative frames")
end
