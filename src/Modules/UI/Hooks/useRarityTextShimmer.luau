local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local RarityGradient = require(ReplicatedStorage.Settings.Visuals.RarityGradient)

local action = Vide.action
local cleanup = Vide.cleanup
local read = Vide.read

type Reactive<T> = T | (() -> T)

local GOLD_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 248, 195)),
	ColorSequenceKeypoint.new(0.45, Color3.fromRGB(255, 220, 85)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 178, 45)),
})

local function getCycledSequence(colorSequence: ColorSequence, elapsed: number, transitionTime: number): ColorSequence
	local keypoints = colorSequence.Keypoints
	local keypointCount = #keypoints
	if keypointCount < 2 then
		return colorSequence
	end

	local cycleProgress = (elapsed / transitionTime) % keypointCount
	local colorOffset = math.floor(cycleProgress)
	local alpha = cycleProgress - colorOffset
	local cycledKeypoints = table.create(keypointCount)

	for index, keypoint in keypoints do
		local currentIndex = ((index + colorOffset - 1) % keypointCount) + 1
		local nextIndex = (currentIndex % keypointCount) + 1
		local currentColor = keypoints[currentIndex].Value
		local nextColor = keypoints[nextIndex].Value

		cycledKeypoints[index] = ColorSequenceKeypoint.new(keypoint.Time, currentColor:Lerp(nextColor, alpha))
	end

	return ColorSequence.new(cycledKeypoints)
end

local function useGradientShimmer(
	getSequence: Reactive<ColorSequence>,
	getActive: Reactive<boolean>,
	getSpeed: Reactive<number>?
)
	return action(function(instance: Instance)
		assert(instance:IsA("UIGradient"), "useGradientShimmer must be used on a UIGradient")

		local gradient = instance :: UIGradient
		local elapsed = 0

		local connection = RunService.RenderStepped:Connect(function(deltaTime)
			elapsed += deltaTime

			local sequence = read(getSequence)
			local speed = if getSpeed then math.max(read(getSpeed), 0.2) else 0.75

			if read(getActive) then
				gradient.Rotation = (elapsed * 18 * speed) % 360
				gradient.Color = getCycledSequence(sequence, elapsed, 1.8 / speed)
			else
				gradient.Rotation = 90
				gradient.Color = sequence
			end
		end)

		cleanup(connection)
	end)
end

local function useRarityTextShimmer(
	getRarity: Reactive<string>,
	getActive: Reactive<boolean>,
	getSpeedScale: Reactive<number>?
)
	return action(function(instance: Instance)
		assert(instance:IsA("UIGradient"), "useRarityTextShimmer must be used on a UIGradient")

		local gradient = instance :: UIGradient
		local elapsed = 0

		local connection = RunService.RenderStepped:Connect(function(deltaTime)
			elapsed += deltaTime

			local rarity = read(getRarity)
			local sequence = RarityGradient.Gradients[rarity] or RarityGradient.Gradients.Common
			local speed = (RarityGradient.ShimmerSpeed[rarity] or 1) * (if getSpeedScale then read(getSpeedScale) else 1)

			if read(getActive) then
				gradient.Rotation = (elapsed * 24 * speed) % 360
				gradient.Color = getCycledSequence(sequence, elapsed, 1.55 / speed)
			else
				gradient.Rotation = 90
				gradient.Color = sequence
			end
		end)

		cleanup(connection)
	end)
end

local function useShineSweep(getActive: Reactive<boolean>, getSpeed: Reactive<number>?)
	return action(function(instance: Instance)
		assert(instance:IsA("GuiObject"), "useShineSweep must be used on a GuiObject")

		local target = instance :: GuiObject
		local elapsed = 0

		local connection = RunService.RenderStepped:Connect(function(deltaTime)
			if not read(getActive) then
				return
			end

			local speed = if getSpeed then math.max(read(getSpeed), 0.15) else 1
			elapsed += deltaTime * speed
			local progress = (elapsed % 2.1) / 2.1
			target.Position = UDim2.fromScale(0.06 + progress * 0.88, 0.5)
		end)

		cleanup(connection)
	end)
end

local function useRarityBorderPulse(getRarity: Reactive<string>, getActive: Reactive<boolean>, getIntensity: Reactive<number>?)
	return action(function(instance: Instance)
		assert(instance:IsA("UIStroke"), "useRarityBorderPulse must be used on a UIStroke")

		local stroke = instance :: UIStroke
		local elapsed = 0

		local connection = RunService.RenderStepped:Connect(function(deltaTime)
			elapsed += deltaTime

			if not read(getActive) then
				stroke.Transparency = 1
				return
			end

			local rarity = read(getRarity)
			local glow = RarityGradient.Glow[rarity] or RarityGradient.Glow.Common
			local speed = RarityGradient.ShimmerSpeed[rarity] or 1
			local intensity = if getIntensity then read(getIntensity) else 1
			local pulse = (math.sin(elapsed * 3.4 * speed) + 1) * 0.5

			stroke.Color = glow
			stroke.Transparency = 1 - (0.12 + pulse * 0.28) * intensity
		end)

		cleanup(connection)
	end)
end

return {
	Text = useRarityTextShimmer,
	Sweep = useShineSweep,
	BorderPulse = useRarityBorderPulse,
	Gold = function(getActive: Reactive<boolean>, getSpeed: Reactive<number>?)
		return useGradientShimmer(function()
			return GOLD_GRADIENT
		end, getActive, getSpeed)
	end,
	GoldGradient = GOLD_GRADIENT,
}
