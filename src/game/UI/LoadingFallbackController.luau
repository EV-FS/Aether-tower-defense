local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local LoadingFallbackController = {}

local loadingGui: ScreenGui? = nil

local function mount()
	if loadingGui then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "LoadingScreen"
	gui.DisplayOrder = 10000
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false

	local background = Instance.new("Frame")
	background.Name = "Background"
	background.BackgroundColor3 = Color3.fromRGB(20, 13, 39)
	background.BorderSizePixel = 0
	background.Size = UDim2.fromScale(1, 1)
	background.Parent = gui

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 20, 55)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(18, 13, 36)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(38, 21, 63)),
	})
	gradient.Parent = background

	local label = Instance.new("TextLabel")
	label.Name = "LoadingText"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Position = UDim2.fromScale(0.5, 0.86)
	label.Size = UDim2.fromOffset(300, 50)
	label.Text = "Loading..."
	label.TextColor3 = Color3.fromRGB(240, 232, 255)
	label.TextScaled = true
	label.Parent = background

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	loadingGui = gui
end

function LoadingFallbackController.Show()
	mount()
end

function LoadingFallbackController.Hide()
	local gui = loadingGui
	if not gui then
		return
	end

	loadingGui = nil
	local background = gui:FindFirstChild("Background")
	if background and background:IsA("Frame") then
		TweenService:Create(background, TweenInfo.new(0.35), {
			BackgroundTransparency = 1,
		}):Play()
	end
	task.delay(0.35, function()
		gui:Destroy()
	end)
end

function LoadingFallbackController.Destroy()
	if loadingGui then
		loadingGui:Destroy()
		loadingGui = nil
	end
end

return LoadingFallbackController
