local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local stateEvent = ReplicatedStorage:WaitForChild("AFKState")
local returnEvent = ReplicatedStorage:WaitForChild("ReturnToLobby")

local function formatPlaytime(seconds: number): string
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local remainingSeconds = seconds % 60
	return string.format("Playtime: %02d:%02d:%02d", hours, minutes, remainingSeconds)
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AFKWorldUI"
screenGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = player:WaitForChild("PlayerGui")

local background = Instance.new("Frame")
background.Name = "Frame"
background.BackgroundColor3 = Color3.fromRGB(2, 5, 12)
background.BorderSizePixel = 0
background.Size = UDim2.fromScale(1, 1)
background.Parent = screenGui

local function addLabel(name: string, text: string, position: UDim2, size: UDim2, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Position = position
	label.Size = size
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Parent = background
	return label
end

local title = addLabel("AFKText", "AFK World", UDim2.fromScale(0.3, 0.04), UDim2.fromScale(0.4, 0.1), Color3.fromRGB(255, 205, 35))
local titleStroke = Instance.new("UIStroke")
titleStroke.Thickness = 5
titleStroke.Parent = title
addLabel("CommentText", "Earn rewards while playing AFK!", UDim2.fromScale(0.25, 0.14), UDim2.fromScale(0.5, 0.05), Color3.fromRGB(130, 140, 160))

local playtime = addLabel("Playtime", "Playtime: 00:00:00", UDim2.fromScale(0.35, 0.57), UDim2.fromScale(0.3, 0.06), Color3.fromRGB(247, 247, 247))
local function addReward(name: string, text: string, position: UDim2, color: Color3)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	frame.Position = position
	frame.Size = UDim2.fromScale(0.2, 0.075)
	frame.Parent = background

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 5)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 2
	stroke.Parent = frame

	local label = Instance.new("TextLabel")
	label.Name = "Value"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextColor3 = Color3.fromRGB(247, 247, 247)
	label.TextScaled = true
	label.Parent = frame
	return label
end

local coins = addReward("AcquisitionCoinFrame", "Coins: 0", UDim2.fromScale(0.27, 0.45), Color3.fromRGB(255, 205, 35))
local gems = addReward("AcquisitionGemFrame", "Gems: 0", UDim2.fromScale(0.53, 0.45), Color3.fromRGB(100, 190, 255))

local returnButton = Instance.new("TextButton")
returnButton.Name = "ReturnToLobbyButton"
returnButton.AnchorPoint = Vector2.new(0.5, 0.5)
returnButton.BackgroundColor3 = Color3.fromRGB(65, 70, 85)
returnButton.Position = UDim2.fromScale(0.5, 0.93)
returnButton.Size = UDim2.fromScale(0.22, 0.07)
returnButton.Font = Enum.Font.FredokaOne
returnButton.Text = "Return to Lobby"
returnButton.TextColor3 = Color3.new(1, 1, 1)
returnButton.TextScaled = true
returnButton.Parent = background
local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0, 10)
buttonCorner.Parent = returnButton
returnButton.Activated:Connect(function()
	returnEvent:FireServer()
end)

stateEvent.OnClientEvent:Connect(function(state)
	playtime.Text = formatPlaytime(state.Playtime or 0)
	coins.Text = `Coins: {state.Coins or 0}`
	gems.Text = `Gems: {state.Gems or 0}`
end)
