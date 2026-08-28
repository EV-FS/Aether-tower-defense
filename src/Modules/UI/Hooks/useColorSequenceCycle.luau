local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Vide = require(ReplicatedStorage.Packages.Vide)

local action = Vide.action
local cleanup = Vide.cleanup

type Reactive<T> = T | (() -> T)

local function read<T>(value: Reactive<T>): T
	return if type(value) == "function" then (value :: () -> T)() else value
end

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

--[[
	create("UIGradient")({
		useColorSequenceCycle(ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 75, 75)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(115, 34, 34)),
		}), 0.8),
	})

	transitionTime is the time in seconds for each keypoint color to reach the next color.
]]

local function useColorSequenceCycle(colorSequence: Reactive<ColorSequence>, transitionTime: Reactive<number>?)
	return action(function(instance: Instance)
		assert(instance:IsA("UIGradient"))

		local gradient = instance :: UIGradient
		local activeSequence = read(colorSequence)
		local elapsed = 0

		gradient.Color = activeSequence

		local connection = RunService.RenderStepped:Connect(function(deltaTime)
			local nextSequence = read(colorSequence)

			if nextSequence ~= activeSequence then
				activeSequence = nextSequence
				elapsed = 0
			end

			local duration = math.max(if transitionTime then read(transitionTime) else 1, 0.01)

			elapsed += deltaTime
			gradient.Color = getCycledSequence(activeSequence, elapsed, duration)
		end)

		cleanup(connection)
	end)
end

return useColorSequenceCycle
