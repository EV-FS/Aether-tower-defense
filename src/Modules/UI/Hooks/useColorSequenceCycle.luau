local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local ColorSequenceScroll = require(script.Parent.Parent.ColorSequenceScroll)

local action = Vide.action
local cleanup = Vide.cleanup
local read = Vide.read

type Reactive<T> = T | (() -> T)

type SharedPalette = {
	prepared: ColorSequenceScroll.Palette,
	users: number,
	lastPhase: number?,
	lastSample: ColorSequence?,
}

type CycleState = {
	colorSequence: Reactive<ColorSequence>,
	transitionTime: Reactive<number>?,
	enabled: Reactive<boolean>?,
	activeSequence: ColorSequence,
	palette: SharedPalette,
	phase: number,
	destroyConnection: RBXScriptConnection?,
}

local UPDATE_INTERVAL = 1 / 20

local accumulatedTime = 0
local palettes: { [ColorSequence]: SharedPalette } = {}
local cycleStates: { [UIGradient]: CycleState } = {}
local renderConnection: RBXScriptConnection? = nil

local function acquirePalette(sequence: ColorSequence): SharedPalette
	local palette = palettes[sequence]
	if not palette then
		palette = { prepared = ColorSequenceScroll.Prepare(sequence), users = 0 }
		palettes[sequence] = palette
	end
	palette.users += 1
	return palette
end

local function releasePalette(state: CycleState)
	state.palette.users -= 1
	if state.palette.users == 0 then
		palettes[state.activeSequence] = nil
	end
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
	if target and target:IsA("UIStroke") then
		if not target.Enabled then
			return false
		end
		target = target.Parent
	end
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

local function removeState(gradient: UIGradient, state: CycleState)
	if cycleStates[gradient] ~= state then
		return
	end
	cycleStates[gradient] = nil
	releasePalette(state)
	if state.destroyConnection then
		state.destroyConnection:Disconnect()
		state.destroyConnection = nil
	end
	stopSchedulerIfIdle()
end

local function startScheduler()
	if renderConnection then
		return
	end

	renderConnection = RunService.RenderStepped:Connect(function(deltaTime)
		accumulatedTime += deltaTime
		if accumulatedTime < UPDATE_INTERVAL then
			return
		end

		local remainder = accumulatedTime % UPDATE_INTERVAL
		local elapsed = accumulatedTime - remainder
		accumulatedTime = remainder

		for gradient, state in cycleStates do
			if not isVisibleOnScreen(gradient) then
				continue
			end

			local nextSequence = read(state.colorSequence)
			if nextSequence ~= state.activeSequence then
				releasePalette(state)
				state.activeSequence = nextSequence
				state.palette = acquirePalette(nextSequence)
				state.phase = 0
			end

			if (state.enabled ~= nil and not read(state.enabled)) or state.palette.prepared.IsSolid then
				state.phase = 0
				if gradient.Color ~= state.activeSequence then
					gradient.Color = state.activeSequence
				end
				continue
			end

			local duration = math.max(if state.transitionTime then read(state.transitionTime) else 1, 0.01)
			local palette = state.palette
			state.phase = (state.phase + elapsed / (duration * palette.prepared.Steps)) % 1
			if palette.lastPhase ~= state.phase then
				palette.lastPhase = state.phase
				palette.lastSample = ColorSequenceScroll.Sample(palette.prepared, state.phase)
			end
			gradient.Color = palette.lastSample :: ColorSequence
		end
	end)
end

return function(colorSequence: Reactive<ColorSequence>, transitionTime: Reactive<number>?, enabled: Reactive<boolean>?)
	return action(function(instance: Instance)
		assert(instance:IsA("UIGradient"), "useColorSequenceCycle must be used on a UIGradient")

		local gradient = instance :: UIGradient
		local previousState = cycleStates[gradient]
		if previousState then
			removeState(gradient, previousState)
		end
		local activeSequence = read(colorSequence)
		local state: CycleState = {
			colorSequence = colorSequence,
			transitionTime = transitionTime,
			enabled = enabled,
			activeSequence = activeSequence,
			palette = acquirePalette(activeSequence),
			phase = 0,
		}

		gradient.Color = activeSequence
		cycleStates[gradient] = state
		state.destroyConnection = gradient.Destroying:Connect(function()
			removeState(gradient, state)
		end)
		startScheduler()

		cleanup(function()
			removeState(gradient, state)
		end)
	end)
end
