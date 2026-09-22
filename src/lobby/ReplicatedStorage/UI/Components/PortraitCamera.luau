local RunService = game:GetService("RunService")

-- One connection for visible portraits; callbacks use cached body parts only.
local updates = {}
local connection: RBXScriptConnection? = nil
local PortraitCamera = {}

function PortraitCamera.FindPart(model: Model, name: string): BasePart?
	local direct = model:FindFirstChild(name)
	if direct and direct:IsA("BasePart") then
		return direct
	end
	for _, part in model:GetDescendants() do
		if part.Name == name and part:IsA("BasePart")
			and not part:FindFirstAncestorWhichIsA("Accessory")
			and not part:FindFirstAncestorWhichIsA("Tool") then
			return part
		end
	end
	return nil
end

function PortraitCamera.Track(model: Model, frame: ViewportFrame, camera: Camera, options)
	local head = PortraitCamera.FindPart(model, "Head")
	if not head then
		return nil
	end
	local torso = PortraitCamera.FindPart(model, "UpperTorso")
		or PortraitCamera.FindPart(model, "Torso")
		or PortraitCamera.FindPart(model, "HumanoidRootPart")
	local lowerTorso = PortraitCamera.FindPart(model, "LowerTorso")
	local torsoHeight = if torso then torso.Size.Y else head.Size.Y * 2
	if lowerTorso then
		torsoHeight += lowerTorso.Size.Y
	end
	-- Dimensions, not the authored pose, establish a stable bust scale.
	local height = math.max(head.Size.Y + torsoHeight, 0.1) * options.Padding
	local width = math.max(head.Size.X, if torso then torso.Size.X * 1.5 else head.Size.X)
	local depth = math.max(head.Size.Magnitude, if torso then torso.Size.Magnitude else 0) * 0.5
	local direction = options.Direction
	direction = if direction.Magnitude > 0 then direction.Unit else Vector3.new(0, 0, -1)
	local orientation = CFrame.lookAt(Vector3.zero, -direction)
	local tangent = math.tan(math.rad(options.FieldOfView) * 0.5)
	local function update()
		local size = frame.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 or not model.Parent then
			return
		end
		local aspect = size.X / size.Y
		local distance = math.max(height / (2 * tangent), width / (2 * tangent * aspect)) + depth
		-- Keep the face above the rarity/name overlay. Following translation only
		-- preserves the idle's rotation and limb movement without zoom pumping.
		local headDepth = distance
		local focus = head.Position - orientation.UpVector * (headDepth * tangent * 0.5)
			+ orientation.UpVector * options.FocusYOffset
		camera.FieldOfView = options.FieldOfView
		camera.CFrame = CFrame.new(focus + direction * distance) * orientation.Rotation
	end
	update()
	updates[update] = true
	if not connection then
		connection = RunService.Heartbeat:Connect(function()
			for callback in updates do
				callback()
			end
		end)
	end
	return function()
		updates[update] = nil
		if next(updates) == nil and connection then
			connection:Disconnect()
			connection = nil
		end
	end
end

return PortraitCamera
