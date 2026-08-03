local Players = game:GetService("Players")
local function setup(character: Model)
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
end

setup(Players.LocalPlayer.Character)

Players.PlayerAdded:Connect(function(player: Player)
	player.CharacterAdded:Connect(function(character: Model)
		setup(character)
	end)
end)
