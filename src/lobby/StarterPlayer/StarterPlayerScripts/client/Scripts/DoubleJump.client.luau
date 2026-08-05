local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local DEFAULT_JUMP_POWER = 50
local DOBULE_JUMP_MULTIFLIER = 1.2

local player = Players.LocalPlayer
local humanoid = nil
local canDoubleJump = false
local hasDoubleJumped = false

local function setupCharacter(character: Model)
	humanoid = character:WaitForChild("Humanoid") :: Humanoid
	canDoubleJump = false
	hasDoubleJumped = false

	humanoid.StateChanged:Connect(function(_, newState)
		if newState == Enum.HumanoidStateType.Freefall then
			task.wait(0.1)
			canDoubleJump = true
		elseif newState == Enum.HumanoidStateType.Landed then
			canDoubleJump = false
			hasDoubleJumped = false
			humanoid.JumpPower = DEFAULT_JUMP_POWER
		end
	end)
end

setupCharacter(player.Character or player.CharacterAdded:Wait())
player.CharacterAdded:Connect(setupCharacter)

UserInputService.JumpRequest:Connect(function()
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	if humanoid:GetState() ~= Enum.HumanoidStateType.Freefall or not canDoubleJump or hasDoubleJumped then
		return
	end

	hasDoubleJumped = true
	humanoid.JumpPower = DEFAULT_JUMP_POWER * DOBULE_JUMP_MULTIFLIER
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
end)
