local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local stateEvent = ReplicatedStorage:WaitForChild("AFKState") :: RemoteEvent
local stateRequestEvent = ReplicatedStorage:WaitForChild("RequestAFKState") :: RemoteEvent
local returnEvent = ReplicatedStorage:WaitForChild("ReturnToLobby") :: RemoteEvent

local function make(className: string, properties, parent: Instance?): Instance
	local instance = Instance.new(className)
	for property, value in properties do
		(instance :: any)[property] = value
	end
	instance.Parent = parent
	return instance
end

local function addStroke(parent: Instance, color: Color3?, thickness: number?): UIStroke
	return make("UIStroke", {
		Color = color or Color3.new(),
		Thickness = thickness or 1,
	}, parent) :: UIStroke
end

local function addText(parent: Instance, name: string, text: string, position: UDim2, size: UDim2): TextLabel
	local label = make("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
		Position = position,
		Size = size,
		Text = text,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
	}, parent) :: TextLabel
	addStroke(label)
	return label
end

local function addGradient(parent: Instance, first: Color3, second: Color3, rotation: number?): UIGradient
	return make("UIGradient", {
		Color = ColorSequence.new(first, second),
		Rotation = rotation or 0,
	}, parent) :: UIGradient
end

local function bindButton(button: GuiButton)
	local scale = make("UIScale", { Scale = 1 }, button) :: UIScale
	button.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1.05 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.06), { Scale = 0.94 }):Play()
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.08), { Scale = 1.05 }):Play()
	end)
end

local screenGui = make("ScreenGui", {
	Name = "AFK",
	ResetOnSpawn = false,
	ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, player:WaitForChild("PlayerGui")) :: ScreenGui

local root = make("Frame", {
	Name = "Frame",
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
}, screenGui) :: Frame

local title = addText(root, "Title", "AFK SERVER", UDim2.fromScale(0.5, 0.05), UDim2.fromScale(0.9068, 0.0684))
title.AnchorPoint = Vector2.new(0.5, 0)

local playtimeLabel = addText(
	root,
	"Playtime",
	"SESSION  00:00:00",
	UDim2.fromScale(0.095, 0.115),
	UDim2.fromScale(0.285, 0.034)
)
playtimeLabel.TextColor3 = Color3.fromRGB(206, 220, 255)

local nextRewardLabel = addText(
	root,
	"NextReward",
	"NEXT 10 COINS IN 1m 00s  |  GEM IN 3m 00s",
	UDim2.fromScale(0.045, 0.155),
	UDim2.fromScale(0.355, 0.026)
)

local progressMask = make("Frame", {
	Name = "RewardBarMask",
	BackgroundTransparency = 1,
	ClipsDescendants = true,
	Position = UDim2.fromScale(0.0318, 0.1835),
	Size = UDim2.fromScale(0.3795, 0.023),
}, root) :: Frame
make("ImageLabel", {
	Name = "barBG",
	BackgroundTransparency = 1,
	Image = "rbxassetid://123614945790793",
	Size = UDim2.fromScale(1, 1),
}, progressMask)
local progressFill = make("ImageLabel", {
	Name = "barFill",
	BackgroundTransparency = 1,
	Image = "rbxassetid://87566142417575",
	Position = UDim2.fromScale(0.005, 0.16),
	Size = UDim2.fromScale(0, 0.67),
	ZIndex = 2,
}, progressMask) :: ImageLabel
addGradient(progressFill, Color3.fromRGB(56, 219, 255), Color3.fromRGB(41, 255, 127), 90)
local barDeco = make("Frame", {
	Name = "barDeco",
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	ZIndex = 3,
}, progressMask) :: Frame
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0.21, 0),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, barDeco)
for index = 1, 4 do
	make("ImageLabel", {
		Name = `SeparateLine{index}`,
		BackgroundTransparency = 1,
		Image = "rbxassetid://96127352288701",
		LayoutOrder = index,
		Size = UDim2.fromScale(0.005, 1),
		ZIndex = 3,
	}, barDeco)
end

local function createRewardCard(
	parent: Instance,
	layoutOrder: number,
	rewardName: string,
	iconId: string,
	quantityText: string
): (ImageButton, TextLabel)
	local card = make("ImageButton", {
		Name = rewardName,
		Active = false,
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Image = "rbxassetid://87496848270095",
		LayoutOrder = layoutOrder,
		Size = UDim2.fromScale(0.26, 0.92),
	}, parent) :: ImageButton
	make("UIAspectRatioConstraint", {}, card)
	addGradient(card, Color3.fromRGB(226, 88, 46), Color3.fromRGB(255, 255, 30), 45)

	make("ImageLabel", {
		Name = "Icon",
		BackgroundTransparency = 1,
		Image = iconId,
		Position = UDim2.fromScale(0.1, 0.08),
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromScale(0.8, 0.78),
	}, card)

	local nameLabel = addText(card, "Name", rewardName, UDim2.fromScale(0.076, 0.73), UDim2.fromScale(0.85, 0.173))
	nameLabel.FontFace = Font.new(
		"rbxasset://fonts/families/SourceSansPro.json",
		Enum.FontWeight.Bold,
		Enum.FontStyle.Normal
	)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.ZIndex = 10

	local quantity = make("ImageLabel", {
		Name = "Quantity",
		BackgroundTransparency = 1,
		Image = "rbxassetid://104083646922843",
		Position = UDim2.fromScale(-0.013, -0.05),
		Size = UDim2.fromScale(0.653, 0.238),
		ZIndex = 10,
	}, card) :: ImageLabel
	make("UIAspectRatioConstraint", { AspectRatio = 3.2 }, quantity)
	local amount = make("TextLabel", {
		Name = "TextLabel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		FontFace = Font.new(
			"rbxasset://fonts/families/SourceSansPro.json",
			Enum.FontWeight.Bold,
			Enum.FontStyle.Normal
		),
		Position = UDim2.fromScale(0.365, 0.4),
		Size = UDim2.fromScale(0.608, 0.889),
		Text = quantityText,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		ZIndex = 11,
	}, quantity) :: TextLabel
	addStroke(amount, nil, 2)
	addGradient(amount, Color3.new(1, 1, 1), Color3.fromRGB(188, 188, 255), 90)
	return card, amount
end

local function createRewardPanel(
	name: string,
	image: string,
	position: UDim2,
	size: UDim2,
	header: string
): (ImageLabel, ScrollingFrame)
	local panel = make("ImageLabel", {
		Name = name,
		BackgroundTransparency = 1,
		Image = image,
		ImageTransparency = 0.3,
		Position = position,
		Size = size,
	}, root) :: ImageLabel
	addText(panel, "Title", header, UDim2.fromScale(0.042, 0.02), UDim2.fromScale(0.907, 0.11))
	make("ImageLabel", {
		Name = "Icon",
		BackgroundTransparency = 1,
		Image = "rbxassetid://97005999994013",
		Position = UDim2.fromScale(0.32, 0.02),
		Size = UDim2.fromScale(0.04, 0.1),
	}, panel)

	local canvas = make("CanvasGroup", {
		Name = "RewardCanvasGroup",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Position = UDim2.fromScale(0.03, 0.154),
		Size = UDim2.fromScale(0.94, 0.78),
	}, panel) :: CanvasGroup
	local scrolling = make("ScrollingFrame", {
		Name = "ScrollingFrame",
		Active = true,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		CanvasSize = UDim2.fromScale(0, 0),
		ClipsDescendants = true,
		ScrollBarImageColor3 = Color3.new(),
		ScrollBarThickness = 0,
		Size = UDim2.fromScale(1, 1),
	}, canvas) :: ScrollingFrame
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0.02, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}, scrolling)
	return panel, scrolling
end

local currentPanel, currentList = createRewardPanel(
	"CurrentReward",
	"rbxassetid://89227290350318",
	UDim2.fromScale(0.0325, 0.2153),
	UDim2.fromScale(0.4092, 0.3819),
	"YOUR REWARD"
)
make("UIAspectRatioConstraint", { AspectRatio = 1.75 }, currentPanel)
local _, currentCoinAmount = createRewardCard(currentList, 1, "COINS", "rbxassetid://117112996963807", "0x")
local _, currentGemAmount = createRewardCard(currentList, 2, "GEMS", "rbxassetid://104268323693949", "0x")

local possiblePanel, possibleList = createRewardPanel(
	"PossibleReward",
	"rbxassetid://127493589553709",
	UDim2.fromScale(0.0325, 0.6111),
	UDim2.fromScale(0.3789, 0.1736),
	"POSSIBLE REWARD"
)
make("UIAspectRatioConstraint", { AspectRatio = 3.85 }, possiblePanel)
createRewardCard(possibleList, 1, "COINS", "rbxassetid://117112996963807", "10 / MIN")
createRewardCard(possibleList, 2, "GEMS", "rbxassetid://104268323693949", "1 / 3 MIN")

local function createActionButton(name: string, text: string, position: UDim2, colors: { Color3 }): (ImageButton, TextLabel)
	local button = make("ImageButton", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Image = "rbxassetid://83967774994235",
		Position = position,
		Size = UDim2.fromScale(0.1835, 0.0676),
	}, root) :: ImageButton
	make("UICorner", { CornerRadius = UDim.new(0, 5) }, button)
	addStroke(button, colors[1])
	addGradient(button, colors[2], colors[3])
	local label = addText(button, "Title", text, UDim2.fromScale(0.12, 0.245), UDim2.fromScale(0.76, 0.488))
	bindButton(button)
	return button, label
end

local returnButton, returnText = createActionButton(
	"DenyButton",
	"RETURN TO LOBBY",
	UDim2.fromScale(0.2216, 0.8304),
	{ Color3.fromRGB(255, 85, 85), Color3.fromRGB(255, 0, 0), Color3.fromRGB(255, 6, 209) }
)

local statusLabel = addText(root, "Status", "REWARDS ARE SAVED AUTOMATICALLY", UDim2.fromScale(0.055, 0.88), UDim2.fromScale(0.35, 0.027))
statusLabel.TextColor3 = Color3.fromRGB(180, 188, 210)

local pendingCoins, pendingGems = 0, 0
local returnRequested = false

local function formatTime(seconds: number): string
	seconds = math.max(math.floor(seconds), 0)
	return string.format("%02d:%02d:%02d", math.floor(seconds / 3600), math.floor(seconds / 60) % 60, seconds % 60)
end

local function shortTime(seconds: number): string
	seconds = math.max(math.ceil(seconds), 0)
	if seconds >= 60 then
		return string.format("%dm %02ds", math.floor(seconds / 60), seconds % 60)
	end
	return string.format("%ds", seconds)
end

returnButton.Activated:Connect(function()
	if returnRequested then
		return
	end
	returnRequested = true
	returnText.Text = "RETURNING..."
	returnEvent:FireServer()
end)

stateEvent.OnClientEvent:Connect(function(state)
	pendingCoins = math.max(math.floor(tonumber(state.PendingCoins) or 0), 0)
	pendingGems = math.max(math.floor(tonumber(state.PendingGems) or 0), 0)
	currentCoinAmount.Text = `{pendingCoins}x`
	currentGemAmount.Text = `{pendingGems}x`
	playtimeLabel.Text = `SESSION  {formatTime(state.Playtime or 0)}`
	nextRewardLabel.Text = `NEXT 10 COINS IN {shortTime(state.NextCoinIn or 60)}  |  GEM IN {shortTime(state.NextGemIn or 180)}`
	progressFill.Size = UDim2.fromScale(math.clamp(tonumber(state.CoinProgress) or 0, 0, 1), 0.67)

	if state.TeleportStatus == "Returning" then
		returnRequested = true
		returnButton.Active = false
		returnText.Text = "RETURNING..."
		statusLabel.Text = "CLAIMING REWARDS AND RETURNING TO LOBBY"
	elseif state.TeleportStatus == "Refreshing" then
		returnRequested = true
		returnButton.Active = false
		returnText.Text = "REFRESHING..."
		statusLabel.Text = "SAVING AND REFRESHING AFK SESSION"
	elseif state.Error then
		returnRequested = false
		returnButton.Active = true
		returnText.Text = "TRY AGAIN"
		statusLabel.Text = tostring(state.Error)
	else
		statusLabel.Text = `BALANCE  {state.Coins or 0} COINS  |  {state.Gems or 0} GEMS`
	end
end)

stateRequestEvent:FireServer()
