local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

-- This cover is created before ReplicatedStorage finishes replicating, so the
-- engine's default loading screen can be removed without exposing the world.
local bootstrapGui = Instance.new("ScreenGui")
bootstrapGui.Name = "LoadingBootstrap"
bootstrapGui.DisplayOrder = 10001
bootstrapGui.IgnoreGuiInset = true
bootstrapGui.ResetOnSpawn = false
bootstrapGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
bootstrapGui.Parent = playerGui

local cover = Instance.new("Frame")
cover.Name = "Cover"
cover.BackgroundColor3 = Color3.fromRGB(20, 13, 39)
cover.BorderSizePixel = 0
cover.Size = UDim2.fromScale(1, 1)
cover.Parent = bootstrapGui

local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 20, 55)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(18, 13, 36)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(38, 21, 63)),
})
gradient.Parent = cover

ReplicatedFirst:RemoveDefaultLoadingScreen()

-- ReplicatedFirst arrives before ReplicatedStorage.Packages. Keep this native
-- cover until the UI's LoadingController has mounted its replacement screen.
task.delay(60, function()
	if bootstrapGui.Parent then
		warn("[LoadingBootstrap] UI did not mount within 60s; releasing boot cover")
		bootstrapGui:Destroy()
	end
end)
