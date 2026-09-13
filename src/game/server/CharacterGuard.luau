local Players = game:GetService("Players")
local SceneLifecycle = require(script.Parent.Services.Core.SceneLifecycle)
local Guard = {}
local autoLoads = Players.CharacterAutoLoads
Players.CharacterAutoLoads = false
local released = false
local held = {}
local connections = {}

local function hold(character)
	task.spawn(function()
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if released or not root or not character.Parent then return end
		local shield = Instance.new("ForceField")
		shield.Visible = false
		shield.Parent = character
		held[character] = { Root = root, Anchored = root.Anchored, Shield = shield }
		root.Anchored = true
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end)
end

local function watch(player)
	table.insert(connections, player.CharacterAdded:Connect(hold))
	if player.Character then hold(player.Character) end
end
table.insert(connections, Players.PlayerAdded:Connect(watch))
for _, player in Players:GetPlayers() do watch(player) end

function Guard.Release(map)
	if released then return end
	-- Resolve a real standing surface before allowing character physics.
	local surface = nil
	local fallback = nil
	SceneLifecycle.Visit({ map }, function(instance)
		if instance:IsA("SpawnLocation") and instance.Enabled then
			surface = instance
		elseif instance:IsA("BasePart") and instance.Anchored and instance.CanCollide then
			if not fallback or instance.Size.X * instance.Size.Z > fallback.Size.X * fallback.Size.Z then
				fallback = instance
			end
		end
	end)
	surface = surface or fallback
	if not surface then
		SceneLifecycle.Visit({ workspace }, function(instance)
			if instance:IsA("SpawnLocation") and instance.Enabled then surface = instance end
		end)
	end
	assert(surface, "Map has no spawn or solid standing surface; characters remain protected")
	local destination = surface.CFrame * CFrame.new(0, surface.Size.Y / 2 + 5, 0)
	-- Keep new characters anchored until they have been placed on the loaded map.
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			player:LoadCharacterAsync()
			character = player.Character
		end
		if character then
			local root = character:WaitForChild("HumanoidRootPart", 10)
			if root then
				character:PivotTo(destination)
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
			end
		end
	end
	released = true
	for _, connection in connections do connection:Disconnect() end
	for character, saved in held do
		if character.Parent and saved.Root.Parent then saved.Root.Anchored = saved.Anchored end
		saved.Shield:Destroy()
	end
	table.clear(held)
	Players.CharacterAutoLoads = autoLoads
end

return Guard
