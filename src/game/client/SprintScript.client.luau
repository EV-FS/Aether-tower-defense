local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local SetMobileStyle = require(ReplicatedStorage.Shared.Modules.UI.SetMobileStyle)

local camera = workspace.CurrentCamera

local player = Players.LocalPlayer
local normalSpeed = 16
local sprintSpeed = 48

local currentHumanoid = nil
local isSprinting = false

local function onCharacterAdded(character)
	currentHumanoid = character:WaitForChild("Humanoid", 5)
	if currentHumanoid then
		currentHumanoid.WalkSpeed = normalSpeed
	end
	isSprinting = false
end

local function handleSprint(_, inputState)
	if not currentHumanoid then
		return
	end

	if inputState == Enum.UserInputState.Begin then
		isSprinting = not isSprinting
		currentHumanoid.WalkSpeed = isSprinting and sprintSpeed or normalSpeed
	end
end

if player.Character then
	onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)

ContextActionService:BindAction("Sprint", handleSprint, true, Enum.KeyCode.LeftShift)
ContextActionService:SetImage("Sprint", "rbxassetid://95175163838191")

if UserInputService.TouchEnabled then
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
end
