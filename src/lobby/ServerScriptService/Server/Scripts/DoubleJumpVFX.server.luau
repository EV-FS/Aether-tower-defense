local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local remote = ReplicatedStorage:FindFirstChild("DoubleJumpVFX") or Instance.new("RemoteEvent")
remote.Name = "DoubleJumpVFX"
remote.Parent = ReplicatedStorage
local lastPlayed: { [Player]: number } = {}

local function playEffect(player: Player)
	local now = os.clock()
	if now - (lastPlayed[player] or 0) < 0.15 then
		return
	end
	lastPlayed[player] = now

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local effect = ServerStorage:FindFirstChild("Jump")
	if not character or not rootPart or not rootPart:IsA("BasePart") or not humanoid or not effect then
		return
	end

	local clone = effect:Clone()
	local effectPart: BasePart?
	local offset = CFrame.new(0, -humanoid.HipHeight - 1.5, 0) * CFrame.Angles(math.rad(90), 0, 0)
	if clone:IsA("BasePart") then
		effectPart = clone
		clone.CFrame = rootPart.CFrame * offset
	elseif clone:IsA("Model") then
		effectPart = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart", true)
		if not effectPart then
			clone:Destroy()
			return
		end
		clone:PivotTo(rootPart.CFrame * offset)
	else
		clone:Destroy()
		return
	end

	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.Massless = true
			descendant.CanCollide = false
			descendant.CanTouch = false

			local weld = Instance.new("WeldConstraint")
			weld.Part0 = rootPart
			weld.Part1 = descendant
			weld.Parent = descendant
		end
	end
	if clone:IsA("BasePart") then
		clone.Anchored = false
		clone.Massless = true
		clone.CanCollide = false
		clone.CanTouch = false

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = rootPart
		weld.Part1 = clone
		weld.Parent = clone
	end
	clone.Parent = workspace

	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("ParticleEmitter") then
			local emitCount = descendant:GetAttribute("EmitCount") or 1
			descendant:Emit(emitCount)
		end
	end
	Debris:AddItem(clone, 3)
end

remote.OnServerEvent:Connect(playEffect)
Players.PlayerRemoving:Connect(function(player)
	lastPlayed[player] = nil
end)
