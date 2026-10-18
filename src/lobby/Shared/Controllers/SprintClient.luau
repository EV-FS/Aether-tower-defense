local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local SetMobileStyle = require(ReplicatedStorage.Shared.Modules.UI.SetMobileStyle)
local FOVController

local camera = workspace.CurrentCamera
local player = Players.LocalPlayer
local normalSpeed = 16
local sprintSpeed = 48

local currentHumanoid: Humanoid? = nil
local isSprinting = false
local isEnabled = true

local SprintClient = {}

local function updateMobileVisual()
	local mobileButton = ContextActionService:GetButton("Sprint")
	if mobileButton then
		SetMobileStyle.SetToggleState(mobileButton, isSprinting and isEnabled)
	end
end

local function updateSpeed()
	if not currentHumanoid or not isEnabled then
		return
	end
	if isSprinting then
		FOVController.SetDefaultFOV(80)
		FOVController.SetFOV(80)
	else
		FOVController.SetDefaultFOV(70)
		FOVController.SetFOV(70)
	end
	currentHumanoid.WalkSpeed = isSprinting and sprintSpeed or normalSpeed
	updateMobileVisual()
end

local function handleSprint(_, inputState)
	if not currentHumanoid or not isEnabled then
		return
	end

	if inputState == Enum.UserInputState.Begin then
		isSprinting = not isSprinting
		updateSpeed()
	end
end

function SprintClient.SetEnabled(enabled: boolean, sprinting: boolean?)
	isEnabled = enabled
	if not enabled then
		isSprinting = false
	elseif sprinting ~= nil then
		isSprinting = sprinting
	end
	updateSpeed()
	updateMobileVisual()
end

function SprintClient.Enable()
	SprintClient.SetEnabled(true)
end

function SprintClient.Disable()
	SprintClient.SetEnabled(false)
end

function SprintClient.IsSprinting(): boolean
	return isSprinting
end

function SprintClient.IsEnabled(): boolean
	return isEnabled
end

function SprintClient.Init(controllers)
	FOVController = controllers:GetService("FOVController")
end

function SprintClient.Start()
	local function onCharacterAdded(character: Model)
		currentHumanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
		if currentHumanoid and isEnabled then
			currentHumanoid.WalkSpeed = normalSpeed
		end
		isSprinting = false
	end

	if player.Character then
		onCharacterAdded(player.Character)
	end
	player.CharacterAdded:Connect(onCharacterAdded)

	ContextActionService:BindAction("Sprint", handleSprint, true, Enum.KeyCode.LeftControl)
	ContextActionService:SetImage("Sprint", "rbxassetid://95175163838191")

	if UserInputService.TouchEnabled then
		task.spawn(function()
			local mobileButton = nil
			for _ = 1, 10 do
				mobileButton = ContextActionService:GetButton("Sprint")
				if mobileButton then
					break
				end
				task.wait()
			end

			if mobileButton then
				local viewportX = camera.ViewportSize.X > 0 and camera.ViewportSize.X or 800
				local viewportY = camera.ViewportSize.Y > 0 and camera.ViewportSize.Y or 600

				local minAxis = math.min(viewportX, viewportY)
				local isSmallScreen = minAxis <= 500
				local buttonSize = isSmallScreen and 50 or 100

				mobileButton.Size = UDim2.fromOffset(buttonSize, buttonSize)
				ContextActionService:SetPosition("Sprint", UDim2.new(0.4, -buttonSize, 0.3, -buttonSize))

				SetMobileStyle.Toggle(mobileButton)
			end
		end)
	end
end

return SprintClient
