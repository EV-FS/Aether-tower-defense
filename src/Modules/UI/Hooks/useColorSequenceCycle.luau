local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Vide = require(ReplicatedStorage.Packages.Vide)

local action = Vide.action
local cleanup = Vide.cleanup

type Reactive<T> = T | (() -> T)

type CycleState = {
	colorSequence: Reactive<ColorSequence>,
	transitionTime: Reactive<number>?,
	enabled: Reactive<boolean>?,
	activeSequence: ColorSequence,
	cycleStartedAt: number,
}

local UPDATE_INTERVAL = 1 / 30
local cycleStates: { [UIGradient]: CycleState } = {}
local renderConnection: RBXScriptConnection? = nil
local accumulatedTime = 0
local schedulerTime = 0

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

local function overlapsScrollingViewport(target: GuiObject, scrollingFrame: ScrollingFrame): boolean
	local targetMin = target.AbsolutePosition
	local targetMax = targetMin + target.AbsoluteSize
	local viewportMin = scrollingFrame.AbsolutePosition
	local viewportMax = viewportMin + scrollingFrame.AbsoluteWindowSize

	return targetMax.X > viewportMin.X
		and targetMin.X < viewportMax.X
		and targetMax.Y > viewportMin.Y
		and targetMin.Y < viewportMax.Y
end

local function isVisibleOnScreen(gradient: UIGradient): boolean
	if not gradient.Enabled then
		return false
	end

	local target = gradient.Parent
	if not target or not target:IsA("GuiObject") then
		return false
	end

	if target.AbsoluteSize.X <= 0 or target.AbsoluteSize.Y <= 0 then
		return false
	end

	local ancestor: Instance? = target
	while ancestor do
		if ancestor:IsA("GuiObject") then
			if not ancestor.Visible then
				return false
			end

			if ancestor:IsA("ScrollingFrame") and not overlapsScrollingViewport(target, ancestor) then
				return false
			end
		elseif ancestor:IsA("LayerCollector") and not ancestor.Enabled then
			return false
		end

		ancestor = ancestor.Parent
	end

	return true
end

local function stopSchedulerIfIdle()
	if next(cycleStates) ~= nil or not renderConnection then
		return
	end

	renderConnection:Disconnect()
	renderConnection = nil
	accumulatedTime = 0
end

local function startScheduler()
	if renderConnection then
		return
	end

	renderConnection = RunService.RenderStepped:Connect(function(deltaTime)
		schedulerTime += deltaTime
		accumulatedTime += deltaTime

		if accumulatedTime < UPDATE_INTERVAL then
			return
		end

		accumulatedTime %= UPDATE_INTERVAL

		for gradient, state in cycleStates do
			if not gradient.Parent then
				cycleStates[gradient] = nil
				continue
			end

			if not isVisibleOnScreen(gradient) then
				continue
			end

			local nextSequence = read(state.colorSequence)
			if nextSequence ~= state.activeSequence then
				state.activeSequence = nextSequence
				state.cycleStartedAt = schedulerTime
			end

			if state.enabled and not read(state.enabled) then
				gradient.Color = state.activeSequence
				continue
			end

			local duration = math.max(if state.transitionTime then read(state.transitionTime) else 1, 0.01)
			local elapsed = schedulerTime - state.cycleStartedAt
			gradient.Color = getCycledSequence(state.activeSequence, elapsed, duration)
		end

		stopSchedulerIfIdle()
	end)
end

--[[
	create("UIGradient")({
		useColorSequenceCycle(ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 75, 75)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(115, 34, 34)),
		}), 0.8),
	})

	transitionTime is the time in seconds for each keypoint color to reach the next color.
	enabled can pause updates while the UI is hidden.
]]

local function useColorSequenceCycle(
	colorSequence: Reactive<ColorSequence>,
	transitionTime: Reactive<number>?,
	enabled: Reactive<boolean>?
)
	return action(function(instance: Instance)
		assert(instance:IsA("UIGradient"))

		local gradient = instance :: UIGradient
		local activeSequence = read(colorSequence)
		local state: CycleState = {
			colorSequence = colorSequence,
			transitionTime = transitionTime,
			enabled = enabled,
			activeSequence = activeSequence,
			cycleStartedAt = schedulerTime,
		}

		gradient.Color = activeSequence
		cycleStates[gradient] = state
		startScheduler()

		cleanup(function()
			if cycleStates[gradient] == state then
				cycleStates[gradient] = nil
			end

			stopSchedulerIfIdle()
		end)
	end)
end

return useColorSequenceCycle
