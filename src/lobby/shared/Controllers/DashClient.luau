local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InputController = require(ReplicatedStorage.Shared.Controllers.InputController)
local EmitParticles = require(ReplicatedStorage.Shared.Modules.Utils.EmitParticles)

local DashInput
local PLAYER = Players.LocalPlayer
local DASH_COOLDOWN = 0.8

local DashTracks = {}
local LastDashTime = 0
local DASH_VFX = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("VFX"):WaitForChild("Dash")
local DASH_VFX_LIFETIME = 2

type DashDirection = "Forward" | "Backward" | "Left" | "Right"

local function GetDashDirection(dashVector: Vector2, rootPart: BasePart): DashDirection
	local lookVector = rootPart.CFrame.LookVector
	local rightVector = rootPart.CFrame.RightVector
	local forwardDot = dashVector.X * lookVector.X + dashVector.Y * lookVector.Z
	local rightDot = dashVector.X * rightVector.X + dashVector.Y * rightVector.Z

	if math.abs(forwardDot) >= math.abs(rightDot) then
		return if forwardDot >= 0 then "Forward" else "Backward"
	end

	return if rightDot >= 0 then "Right" else "Left"
end

local DashClient = {}
DashClient.DashInfo = {
	Forward = { Speed = 130, Duration = 0.2, AnimationId = "rbxassetid://112359286044213" },
	Backward = { Speed = 130, Duration = 0.2, AnimationId = "rbxassetid://99143998068665" },
	Left = { Speed = 130, Duration = 0.2, AnimationId = "rbxassetid://139209194154392 " },
	Right = { Speed = 130, Duration = 0.2, AnimationId = "rbxassetid://131581512006061" },
}

local function LoadDashTracks(character: Model)
	table.clear(DashTracks)

	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local animator = humanoid:WaitForChild("Animator") :: Animator

	for direction, dashInfo in DashClient.DashInfo do
		local animation = Instance.new("Animation")
		animation.Name = `Dash{direction}`
		animation.AnimationId = dashInfo.AnimationId
		animation.Parent = animator

		local track = animator:LoadAnimation(animation)
		track.Priority = Enum.AnimationPriority.Action
		DashTracks[direction] = track
	end
end

local function PlayDashVFX(rootPart: BasePart, dashVector: Vector2)
	local effect = DASH_VFX:Clone()
	if not effect:IsA("PVInstance") then
		warn("[DashClient] Assets.VFX.Dash must be a Model or BasePart")
		effect:Destroy()
		return
	end

	local direction = Vector3.new(dashVector.X, 0, dashVector.Y)
	effect:PivotTo(CFrame.lookAt(rootPart.Position, rootPart.Position + direction))
	effect.Parent = workspace

	EmitParticles(effect)
	Debris:AddItem(effect, DASH_VFX_LIFETIME)
end

function DashClient:Dash()
	if PLAYER:GetAttribute("SummonControlsLocked") then
		return
	end

	local character = PLAYER.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not rootPart or humanoid.Health <= 0 then
		return
	end

	local moveDirection = humanoid.MoveDirection
	local dashVector = Vector2.new(moveDirection.X, moveDirection.Z)

	if dashVector.Magnitude <= 0.001 then
		local lookVector = rootPart.CFrame.LookVector
		dashVector = Vector2.new(lookVector.X, lookVector.Z)
	end
	dashVector = dashVector.Unit

	local dashDirection = GetDashDirection(dashVector, rootPart)
	local dashInfo = self.DashInfo[dashDirection]
	local now = os.clock()
	if now - LastDashTime < DASH_COOLDOWN then
		return
	end
	LastDashTime = now

	DashTracks[dashDirection]:Play(0.1)
	PlayDashVFX(rootPart, dashVector)

	local dashAttachment = rootPart:FindFirstChild("DashAttachment") or Instance.new("Attachment")
	dashAttachment.Name = "DashAttachment"
	dashAttachment.Parent = rootPart

	local linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.Name = "DashVelocity"
	linearVelocity.Attachment0 = dashAttachment
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector

	local force = rootPart.AssemblyMass * 2500
	linearVelocity.ForceLimitsEnabled = true
	linearVelocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	linearVelocity.MaxAxesForce = Vector3.new(force, force, force)

	linearVelocity.VectorVelocity = Vector3.new(dashVector.X, 0, dashVector.Y) * dashInfo.Speed
	linearVelocity.Parent = dashAttachment

	Debris:AddItem(linearVelocity, dashInfo.Duration)
end

function DashClient.Init() end

function DashClient.Start()
	LoadDashTracks(PLAYER.Character or PLAYER.CharacterAdded:Wait())
	PLAYER.CharacterAdded:Connect(LoadDashTracks)

	local iScope = InputController.Scope
	local iAction = InputController.Action
	local iInfo = InputController.Info

	DashInput = iScope("DashInput", {
		iAction("Dash", iInfo({ Enum.KeyCode.Q })),
	}):Enable()

	DashInput.Actions.Dash.Began:Connect(function()
		DashClient:Dash()
	end)
end

return DashClient
