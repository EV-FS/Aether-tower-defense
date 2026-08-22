local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Vide = require(ReplicatedStorage.Packages.Vide)

local action = Vide.action
local cleanup = Vide.cleanup
local read = Vide.read

type Reactive<T> = T | (() -> T)

local SHINE_COLORS = {
	Common = Color3.fromRGB(50, 45, 45),
	Uncommon = Color3.fromRGB(50, 45, 45),
	Rare = Color3.fromRGB(29, 34, 176),
	Epic = Color3.fromRGB(68, 59, 170),
	Legendary = Color3.fromRGB(158, 63, 153),
	Mythic = Color3.fromRGB(106, 67, 28),
	Exclusive = Color3.fromRGB(17, 0, 1),
	Absolute = Color3.fromRGB(233, 93, 224),
}

local SHINE_SPEED = 10
local SHINE_INTERVAL = 2
local SHINE_WIDTH = 1.1
local SHINE_HEIGHT = 1.55
local SHINE_TRANSPARENCY = 0.1
local START_X = -1.4
local END_X = 1.4

local function useRarityShine(getRarity: Reactive<string>)
	return action(function(instance: Instance)
		assert(instance:IsA("CanvasGroup"), "useRarityShine must be used on a CanvasGroup")

		local frame = instance :: CanvasGroup
		frame.ClipsDescendants = true

		local oldEffect = frame:FindFirstChild("ShineEffect")
		if oldEffect then
			oldEffect:Destroy()
		end

		local shineFolder = Instance.new("Folder")
		shineFolder.Name = "ShineEffect"
		shineFolder.Parent = frame

		local originalCorner = frame:FindFirstChildOfClass("UICorner")
		local shineNumber = 0
		local isAlive = true

		local function createShine()
			if not isAlive or not frame.Parent then
				return
			end

			shineNumber += 1

			local shine = Instance.new("Frame")
			shine.Name = `Shine_{shineNumber}`
			shine.BackgroundTransparency = 1
			shine.BorderSizePixel = 0
			shine.ClipsDescendants = true
			shine.Position = UDim2.fromScale(0, 0)
			shine.Size = UDim2.fromScale(1, 1)
			shine.ZIndex = 1
			shine.Parent = shineFolder

			if originalCorner then
				originalCorner:Clone().Parent = shine
			end

			local light = Instance.new("Frame")
			light.Name = "SoftGlow"
			local rarity = read(getRarity)
			light.BackgroundColor3 = SHINE_COLORS[rarity] or SHINE_COLORS.Common
			light.BackgroundTransparency = SHINE_TRANSPARENCY
			light.BorderSizePixel = 0
			light.Position = UDim2.fromScale(START_X, -0.275)
			light.Rotation = 18
			light.Size = UDim2.fromScale(SHINE_WIDTH, SHINE_HEIGHT)
			light.ZIndex = 2
			light.Parent = shine

			local gradient = Instance.new("UIGradient")
			gradient.Color = ColorSequence.new(Color3.new(1, 1, 1))
			gradient.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.1, 1),
				NumberSequenceKeypoint.new(0.25, 0.97),
				NumberSequenceKeypoint.new(0.35, 0.88),
				NumberSequenceKeypoint.new(0.42, 0.7),
				NumberSequenceKeypoint.new(0.5, 0.52),
				NumberSequenceKeypoint.new(0.58, 0.7),
				NumberSequenceKeypoint.new(0.65, 0.88),
				NumberSequenceKeypoint.new(0.75, 0.97),
				NumberSequenceKeypoint.new(0.9, 1),
				NumberSequenceKeypoint.new(1, 1),
			})
			gradient.Parent = light

			local tween = TweenService:Create(
				light,
				TweenInfo.new(SHINE_SPEED, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut),
				{ Position = UDim2.fromScale(END_X, -0.275) }
			)

			tween.Completed:Connect(function()
				if shine.Parent then
					shine:Destroy()
				end
			end)
			tween:Play()
		end

		task.spawn(function()
			while isAlive and frame.Parent do
				createShine()
				task.wait(SHINE_INTERVAL)
			end
		end)

		cleanup(function()
			isAlive = false
			shineFolder:Destroy()
		end)
	end)
end

return useRarityShine
