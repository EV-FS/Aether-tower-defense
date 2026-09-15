local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
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
	local effect = ServerStorage:FindFirstChild("Jump", true)
	if not character or not rootPart or not rootPart:IsA("BasePart") or not humanoid then
		warn(`[DoubleJumpVFX] Character was not ready for {player.Name}`)
		return
	end
	if not effect then
		warn("[DoubleJumpVFX] Missing ServerStorage descendant named Jump")
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
		warn(`[DoubleJumpVFX] Jump must be a BasePart or Model, got {clone.ClassName}`)
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

	-- Give the effect instance one replication frame before sending its reference.
	-- ForgeVFX must run on each client because camera effects and its local caches
	-- are intentionally unavailable in the server context.
	RunService.Heartbeat:Wait()
	remote:FireAllClients(clone)
	Debris:AddItem(clone, 5)
end

remote.OnServerEvent:Connect(playEffect)
Players.PlayerRemoving:Connect(function(player)
	lastPlayed[player] = nil
end)
