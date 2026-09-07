local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

local action = Vide.action
local cleanup = Vide.cleanup
local create = Vide.create
local effect = Vide.effect
local source = Vide.source
local untrack = Vide.untrack

local ENTER_DURATION = 0.24
local EXIT_DURATION = 0.98
local CLOUD_ENTER_DURATION = 0.38
local TITLE_ENTER_DELAY = 0.5
local TITLE_ENTER_DURATION = 0.44
local STAR_SPIN_DELAY = 0.82
local STAR_SPIN_DURATION = 0.84
local STAR_SPIN_DEGREES = 1080
local CLOUD_SPIN_SPEED = 145
local SPOTLIGHT_FOCUS_DURATION = 0.92
local STAR_START_POSITION = Vector2.new(-0.28, -0.72)
local STAR_CONTROL_POSITION = Vector2.new(0.72, -1.32)
local STAR_END_POSITION = Vector2.new(0.779, 0.632)

export type Props = {
	IsVisible: () -> boolean,
	UseScreenGui: boolean?,
}

local function tween(instance: Instance, info: TweenInfo, properties: { [string]: any })
	local animation = TweenService:Create(instance, info, properties)
	animation:Play()
	return animation
end

local function animateTitleEntrance(instance: ImageLabel, visible: () -> boolean)
	local motionScale = instance:FindFirstChild("MotionScale")
	local elapsed = 0
	local wasVisible = false
	local isPlaying = false
	local connection: RBXScriptConnection

	local function reset()
		instance.Position = UDim2.fromScale(0.5, -0.18)
		instance.ImageTransparency = 0
		if motionScale and motionScale:IsA("UIScale") then
			motionScale.Scale = 0.92
		end
	end

	reset()
	connection = RunService.RenderStepped:Connect(function(deltaTime)
		if not instance.Parent then
			connection:Disconnect()
			return
		end

		local isVisible = visible()
		if isVisible and not wasVisible then
			elapsed = -TITLE_ENTER_DELAY
			reset()
			isPlaying = true
		elseif not isVisible then
			reset()
			isPlaying = false
		end
		wasVisible = isVisible

		if not isVisible or not isPlaying then
			return
		end

		elapsed += deltaTime
		if elapsed < 0 then
			return
		end

		local progress = math.clamp(elapsed / TITLE_ENTER_DURATION, 0, 1)
		local eased = TweenService:GetValue(progress, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		instance.Position = UDim2.fromScale(0.5, -0.18 + 0.545 * eased)
		if motionScale and motionScale:IsA("UIScale") then
			motionScale.Scale = 0.92 + 0.08 * eased
		end

		if progress >= 1 then
			instance.Position = UDim2.fromScale(0.5, 0.365)
			if motionScale and motionScale:IsA("UIScale") then
				motionScale.Scale = 1
			end
			isPlaying = false
		end
	end)
end

local function animateCloudEntrance(
	instance: ImageLabel,
	visible: () -> boolean,
	delayTime: number,
	startPosition: Vector2,
	targetPosition: Vector2,
	idlePhase: number
)
	local elapsed = 0
	local idleElapsed = 0
	local wasVisible = false
	local connection: RBXScriptConnection

	local function reset()
		instance.Position = UDim2.fromScale(startPosition.X, startPosition.Y)
		instance.ImageTransparency = 0.08
		idleElapsed = 0
	end

	reset()
	connection = RunService.RenderStepped:Connect(function(deltaTime)
		if not instance.Parent then
			connection:Disconnect()
			return
		end

		local isVisible = visible()
		if isVisible and not wasVisible then
			elapsed = -delayTime
			reset()
		elseif not isVisible then
			reset()
		end
		wasVisible = isVisible

		if not isVisible then
			return
		end

		elapsed += deltaTime
		if elapsed < 0 then
			return
		end

		local progress = math.clamp(elapsed / CLOUD_ENTER_DURATION, 0, 1)
		if progress < 1 then
			local eased = TweenService:GetValue(progress, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			local position = startPosition:Lerp(targetPosition, eased)
			instance.Position = UDim2.fromScale(position.X, position.Y)
			return
		end

		idleElapsed += deltaTime
		local idleOffset = math.sin(idleElapsed * 1.5 + idlePhase) * 0.006
		instance.Position = UDim2.fromScale(targetPosition.X, targetPosition.Y + idleOffset)
		instance.ImageTransparency = 0.08
	end)
end

local function animateSpotlightFocus(
	instance: ImageLabel,
	visible: () -> boolean,
	delayTime: number,
	startPosition: UDim2,
	targetPosition: UDim2,
	startSize: UDim2,
	targetSize: UDim2,
	phase: number
)
	local elapsed = 0
	local idleElapsed = 0
	local wasVisible = false

	local function reset()
		instance.Position = startPosition
		instance.Size = startSize
		instance.ImageTransparency = 0.72
		idleElapsed = 0
	end

	reset()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function(deltaTime)
		if not instance.Parent then
			connection:Disconnect()
			return
		end

		local isVisible = visible()
		if isVisible and not wasVisible then
			elapsed = -delayTime
			reset()
		elseif not isVisible then
			reset()
		end
		wasVisible = isVisible

		if not isVisible then
			return
		end

		elapsed += deltaTime
		if elapsed < 0 then
			return
		end

		local progress = math.clamp(elapsed / SPOTLIGHT_FOCUS_DURATION, 0, 1)
		if progress < 1 then
			local eased = TweenService:GetValue(progress, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
			local fade = TweenService:GetValue(progress, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			instance.Position = startPosition:Lerp(targetPosition, eased)
			instance.Size = startSize:Lerp(targetSize, eased)
			instance.ImageTransparency = 0.72 - 0.64 * fade
			return
		end

		idleElapsed += deltaTime
		local breathe = math.sin(idleElapsed * 1.15 + phase)
		instance.Position = targetPosition + UDim2.fromScale(0, breathe * 0.0025)
		instance.Size = targetSize + UDim2.fromScale(targetSize.X.Scale * breathe * 0.012, 0)
		instance.ImageTransparency = 0.1 - breathe * 0.025
	end)
	cleanup(connection)
end

local function animateImageReveal(
	instance: ImageLabel,
	visible: () -> boolean,
	delayTime: number,
	duration: number,
	startPosition: UDim2,
	targetPosition: UDim2,
	startSize: UDim2,
	targetSize: UDim2,
	targetTransparency: number,
	idleAmount: number,
	phase: number
)
	local elapsed = 0
	local idleElapsed = 0
	local wasVisible = false

	local function reset()
		instance.Position = startPosition
		instance.Size = startSize
		instance.ImageTransparency = 1
		idleElapsed = 0
	end

	reset()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function(deltaTime)
		if not instance.Parent then
			connection:Disconnect()
			return
		end

		local isVisible = visible()
		if isVisible and not wasVisible then
			elapsed = -delayTime
			reset()
		elseif not isVisible then
			reset()
		end
		wasVisible = isVisible

		if not isVisible then
			return
		end

		elapsed += deltaTime
		if elapsed < 0 then
			return
		end

		local progress = math.clamp(elapsed / duration, 0, 1)
		if progress < 1 then
			local eased = TweenService:GetValue(progress, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			local fade = TweenService:GetValue(progress, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			instance.Position = startPosition:Lerp(targetPosition, eased)
			instance.Size = startSize:Lerp(targetSize, eased)
			instance.ImageTransparency = 1 - (1 - targetTransparency) * fade
			return
		end

		idleElapsed += deltaTime
		local idleOffset = math.sin(idleElapsed * 1.3 + phase) * idleAmount
		instance.Position = targetPosition + UDim2.fromScale(0, idleOffset)
		instance.Size = targetSize
		instance.ImageTransparency = targetTransparency
	end)
	cleanup(connection)
end

local function animateTextReveal(
	instance: TextLabel,
	visible: () -> boolean,
	delayTime: number,
	duration: number,
	startPosition: UDim2,
	targetPosition: UDim2,
	targetTransparency: number,
	idleAmount: number
)
	local elapsed = 0
	local idleElapsed = 0
	local wasVisible = false

	local function reset()
		instance.Position = startPosition
		instance.TextTransparency = 1
		idleElapsed = 0
	end

	reset()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function(deltaTime)
		if not instance.Parent then
			connection:Disconnect()
			return
		end

		local isVisible = visible()
		if isVisible and not wasVisible then
			elapsed = -delayTime
			reset()
		elseif not isVisible then
			reset()
		end
		wasVisible = isVisible

		if not isVisible then
			return
		end

		elapsed += deltaTime
		if elapsed < 0 then
			return
		end

		local progress = math.clamp(elapsed / duration, 0, 1)
		if progress < 1 then
			local eased = TweenService:GetValue(progress, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
			instance.Position = startPosition:Lerp(targetPosition, eased)
			instance.TextTransparency = 1 - (1 - targetTransparency) * eased
			return
		end

		idleElapsed += deltaTime
		instance.Position = targetPosition + UDim2.fromScale(0, math.sin(idleElapsed * 1.4) * idleAmount)
		instance.TextTransparency = targetTransparency
	end)
	cleanup(connection)
end

local function animateSpinnerEntrance(instance: CanvasGroup, visible: () -> boolean)
	local motionScale = instance:FindFirstChild("MotionScale")
	if not motionScale or not motionScale:IsA("UIScale") then
		return
	end

	local elapsed = 0
	local idleElapsed = 0
	local wasVisible = false
	local delayTime = 1.04
	local duration = 0.48

	local function reset()
		instance.Position = UDim2.fromScale(0.5, 0.835)
		instance.GroupTransparency = 1
		motionScale.Scale = 0.72
		idleElapsed = 0
	end

	reset()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function(deltaTime)
		if not instance.Parent then
			connection:Disconnect()
			return
		end

		local isVisible = visible()
		if isVisible and not wasVisible then
			elapsed = -delayTime
			reset()
		elseif not isVisible then
			reset()
		end
		wasVisible = isVisible

		if not isVisible then
			return
		end

		elapsed += deltaTime
		if elapsed < 0 then
			return
		end

		local progress = math.clamp(elapsed / duration, 0, 1)
		if progress < 1 then
			local eased = TweenService:GetValue(progress, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			instance.Position = UDim2.fromScale(0.5, 0.835 - 0.035 * eased)
			instance.GroupTransparency = 1 - math.clamp(progress / 0.62, 0, 1)
			motionScale.Scale = 0.72 + 0.28 * eased
			return
		end

		idleElapsed += deltaTime
		local breathe = math.sin(idleElapsed * 1.65)
		instance.Position = UDim2.fromScale(0.5, 0.8 + breathe * 0.004)
		instance.GroupTransparency = 0
		motionScale.Scale = 1 + breathe * 0.018
	end)
	cleanup(connection)
end

local function impactTitle(star: GuiObject, visible: () -> boolean)
	local title = star.Parent
	if not title or not title:IsA("ImageLabel") then
		return
	end
	local titleScale = title:FindFirstChild("MotionScale")
	if not titleScale or not titleScale:IsA("UIScale") then
		return
	end

	task.spawn(function()
		if not visible() or not title.Parent then
			return
		end

		local compress = tween(title, TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromScale(0.5, 0.371),
		})
		tween(titleScale, TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 0.985 })
		compress.Completed:Wait()
		if not visible() or not title.Parent then
			return
		end

		local rebound = tween(title, TweenInfo.new(0.13, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
			Position = UDim2.fromScale(0.5, 0.362),
		})
		tween(titleScale, TweenInfo.new(0.13, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Scale = 1.012 })
		rebound.Completed:Wait()
		if not visible() or not title.Parent then
			return
		end

		tween(title, TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
			Position = UDim2.fromScale(0.5, 0.365),
		})
		tween(titleScale, TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Scale = 1 })
	end)
end

local function settleStar(instance: GuiObject, visible: () -> boolean)
	local motionScale = instance:FindFirstChild("MotionScale")
	if not motionScale or not motionScale:IsA("UIScale") then
		return
	end
	local glow = instance:FindFirstChild("Glow")

	local function setPosition(progress: number)
		local inverse = 1 - progress
		local point = STAR_START_POSITION * (inverse * inverse)
			+ STAR_CONTROL_POSITION * (2 * inverse * progress)
			+ STAR_END_POSITION * (progress * progress)
		instance.Position = UDim2.fromScale(point.X, point.Y)
	end

	local function reset()
		instance.Rotation = 0
		instance.ImageTransparency = 1
		motionScale.Scale = 0.62
		setPosition(0)
		if glow and glow:IsA("ImageLabel") then
			glow.ImageTransparency = 1
		end
	end

	local elapsed = 0
	local idleElapsed = 0
	local wasVisible = false
	local isPlaying = false
	local isSettled = false
	reset()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function(deltaTime)
		if not instance.Parent then
			connection:Disconnect()
			return
		end

		local isVisible = visible()
		if isVisible and not wasVisible then
			elapsed = -STAR_SPIN_DELAY
			idleElapsed = 0
			isSettled = false
			reset()
			isPlaying = true
		elseif not isVisible then
			isSettled = false
			reset()
			isPlaying = false
		end
		wasVisible = isVisible

		if not isPlaying then
			if isVisible and isSettled then
				idleElapsed += deltaTime
				local shimmer = math.sin(idleElapsed * 2.1)
				motionScale.Scale = 1 + shimmer * 0.012
				if glow and glow:IsA("ImageLabel") then
					glow.ImageTransparency = 0.86 - shimmer * 0.055
				end
			end
			return
		end

		elapsed += deltaTime
		if elapsed < 0 then
			return
		end

		local progress = math.clamp(elapsed / STAR_SPIN_DURATION, 0, 1)
		local travelProgress = TweenService:GetValue(progress, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
		local rotationProgress = TweenService:GetValue(progress, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		instance.Rotation = STAR_SPIN_DEGREES * rotationProgress
		instance.ImageTransparency = 1 - math.clamp(progress / 0.16, 0, 1)
		setPosition(travelProgress)

		if progress < 0.58 then
			local grow = TweenService:GetValue(progress / 0.58, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
			motionScale.Scale = 0.62 + 0.58 * grow
		else
			local settle = TweenService:GetValue(
				(progress - 0.58) / 0.42,
				Enum.EasingStyle.Sine,
				Enum.EasingDirection.Out
			)
			motionScale.Scale = 1.2 - 0.2 * settle
		end

		if glow and glow:IsA("ImageLabel") then
			local glowFadeIn = math.clamp(progress / 0.18, 0, 1)
			local glowFadeOut = math.clamp((progress - 0.62) / 0.38, 0, 1)
			glow.ImageTransparency = 1 - 0.5 * glowFadeIn + 0.38 * glowFadeOut
		end

		if progress >= 1 then
			instance.Rotation = 0
			instance.ImageTransparency = 0
			instance.Position = UDim2.fromScale(STAR_END_POSITION.X, STAR_END_POSITION.Y)
			motionScale.Scale = 1
			if glow and glow:IsA("ImageLabel") then
				glow.ImageTransparency = 0.88
			end
			impactTitle(instance, visible)
			isSettled = true
			isPlaying = false
		end
	end)
end

local function rotateCloudCircle(instance: GuiObject, visible: () -> boolean)
	local speed = 0
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function(deltaTime)
		if not instance.Parent then
			connection:Disconnect()
			return
		end

		if not visible() then
			speed = 0
			return
		end

		-- Ease into the loop so the spinner does not jerk on the first rendered frame.
		speed += (CLOUD_SPIN_SPEED - speed) * math.min(deltaTime * 8, 1)
		instance.Rotation = (instance.Rotation + speed * deltaTime) % 360
	end)
end

local function animateLoadingText(instance: TextLabel, visible: () -> boolean)
	task.spawn(function()
		local dotCount = 0
		while instance.Parent do
			if visible() then
				instance.Text = "Loading" .. string.rep(".", dotCount)
				dotCount = (dotCount + 1) % 4
				task.wait(0.32)
			else
				instance.Text = "Loading..."
				dotCount = 0
				task.wait(0.1)
			end
		end
	end)
end

local function pulse(instance: Instance, delayTime: number, amount: number, duration: number)
	local scale = instance:FindFirstChild("Pulse")
	if not scale or not scale:IsA("UIScale") then
		return
	end

	task.delay(delayTime, function()
		if scale.Parent then
			tween(scale, TweenInfo.new(duration * 0.72, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
				Scale = amount,
			})
		end
	end)
end

local function shimmerProgress(instance: GuiObject, visible: () -> boolean)
	task.spawn(function()
		while instance.Parent do
			if not visible() then
				task.wait(0.1)
				continue
			end

			instance.Position = UDim2.fromScale(-0.24, 0.5)
			local animation = tween(instance, TweenInfo.new(1.15, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
				Position = UDim2.fromScale(1.24, 0.5),
			})
			animation.Completed:Wait()
			task.wait(0.18)
		end
	end)
end

local function sweep(instance: GuiObject)
	task.spawn(function()
		while instance.Parent do
			instance.Position = UDim2.fromScale(-0.18, 0.5)
			local animation = tween(instance, TweenInfo.new(1.55, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut), {
				Position = UDim2.fromScale(1.18, 0.5),
			})
			animation.Completed:Wait()
			if instance.Parent then
				task.wait(1.2)
			end
		end
	end)
end

local function dustFall(layer: GuiObject)
	local motes = {}
	for index = 1, 44 do
		local mote = Instance.new("Frame")
		mote.Name = `DustMote{index}`
		mote.AnchorPoint = Vector2.new(0.5, 0.5)
		mote.BackgroundColor3 = if index % 3 == 0 then Color3.fromRGB(196, 218, 255) else Color3.fromRGB(255, 255, 255)
		mote.BackgroundTransparency = math.random(52, 76) / 100
		mote.BorderSizePixel = 0
		mote.Position = UDim2.fromScale(math.random(-10, 110) / 100, math.random(-10, 110) / 100)
		local size = math.random(4, 9)
		mote.Size = UDim2.fromOffset(size, size)
		mote.ZIndex = 90
		mote.Parent = layer

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = mote

		table.insert(motes, {
			Instance = mote,
			X = mote.Position.X.Scale,
			Y = mote.Position.Y.Scale,
			Speed = math.random(5, 12) / 100,
			Drift = math.random(-10, 10) / 100,
			Phase = math.random() * math.pi * 2,
		})
	end

	local elapsed = 0
	local connection
	connection = RunService.RenderStepped:Connect(function(deltaTime)
		if not layer.Parent then
			connection:Disconnect()
			return
		end

		elapsed += deltaTime
		for _, moteData in motes do
			local mote = moteData.Instance
			if not mote.Parent then
				continue
			end

			moteData.Y += moteData.Speed * deltaTime
			moteData.X += math.sin(elapsed * 0.8 + moteData.Phase) * moteData.Drift * deltaTime
			if moteData.Y > 1.08 then
				moteData.Y = -0.08
				moteData.X = math.random(-10, 110) / 100
			end
			mote.Position = UDim2.fromScale(moteData.X, moteData.Y)
		end
	end)
end

return function(props: Props)
	local visible = props.IsVisible
	local useScreenGui = props.UseScreenGui ~= false
	local entryProgress = source(if visible() then 1 else 0)
	local exitProgress = source(if visible() then 0 else 1)

	effect(function()
		local shouldShow = visible()
		local startEntry = untrack(entryProgress)
		local startExit = untrack(exitProgress)
		local elapsed = 0
		local duration = if shouldShow then ENTER_DURATION else EXIT_DURATION

		local connection: RBXScriptConnection
		connection = RunService.RenderStepped:Connect(function(deltaTime)
			elapsed += deltaTime
			local progress = math.min(elapsed / duration, 1)
			local eased = TweenService:GetValue(
				progress,
				if shouldShow then Enum.EasingStyle.Quart else Enum.EasingStyle.Quad,
				if shouldShow then Enum.EasingDirection.Out else Enum.EasingDirection.InOut
			)

			local entryEasing = if shouldShow then progress else eased
			entryProgress(startEntry + ((if shouldShow then 1 else 0) - startEntry) * entryEasing)
			exitProgress(startExit + ((if shouldShow then 0 else 1) - startExit) * eased)

			if progress == 1 then
				connection:Disconnect()
			end
		end)
		cleanup(connection)
	end)

	return create(if useScreenGui then "ScreenGui" else "Frame")({
		Name = "LoadingScreen",
		DisplayOrder = if useScreenGui then 100 else nil,
		IgnoreGuiInset = if useScreenGui then true else nil,
		ResetOnSpawn = if useScreenGui then false else nil,
		ZIndexBehavior = if useScreenGui then Enum.ZIndexBehavior.Sibling else nil,
		Enabled = if useScreenGui then true else nil,
		Visible = if useScreenGui then nil else true,
		Size = if useScreenGui then nil else UDim2.fromScale(1, 1),

		create("CanvasGroup")({
			Name = "Container",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Interactable = visible,
			GroupTransparency = function()
				if visible() then
					return 0
				end

				local fade = math.clamp((exitProgress() - 0.2) / 0.44, 0, 1)
				return TweenService:GetValue(fade, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			end,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			ZIndex = 100,

			create("TextButton")({
				Name = "InputBlocker",
				Active = visible,
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Text = "",
				Visible = visible,
				ZIndex = 98,
			}),

			create("ImageLabel")({
				Name = "Main",
				BackgroundColor3 = Color3.fromRGB(20, 13, 39),
				BackgroundTransparency = 0,
				BorderSizePixel = 0,
				Image = "rbxassetid://121340856010495",
				ImageTransparency = 0,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 100,

				create("Frame")({
					Name = "DustLayer",
					BackgroundTransparency = 1,
					ClipsDescendants = true,
					Size = UDim2.fromScale(1, 1),
					ZIndex = 101,
					action(dustFall),
				}),

				create("ImageLabel")({
					Name = "Title",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = "rbxassetid://86974214352692",
					ImageTransparency = 0,
					Position = UDim2.fromScale(0.5, -0.18),
					Size = UDim2.fromScale(0.332543, 0.136633),
					ZIndex = 110,

					create("UIAspectRatioConstraint")({ AspectRatio = 5 }),
					create("UIScale")({ Name = "MotionScale", Scale = 0.92 }),
					action(function(instance)
						animateTitleEntrance(instance, visible)
					end),
					create("ImageLabel")({
						Name = "TowerDefense",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Image = "rbxassetid://94841238370615",
						Position = UDim2.fromScale(0.5, 1.1),
						Size = UDim2.fromScale(0.607542, 0.181463),
						create("UIAspectRatioConstraint")({ AspectRatio = 12 }),
					}),
					create("ImageLabel")({
						Name = "Star",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Image = "rbxassetid://100121381827138",
						Position = UDim2.fromScale(STAR_START_POSITION.X, STAR_START_POSITION.Y),
						Size = UDim2.fromScale(0.139757, 0.797365),
						ZIndex = 112,
						create("UIScale")({ Name = "MotionScale", Scale = 0.72 }),
						create("ImageLabel")({
							Name = "Glow",
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							Image = "rbxassetid://100121381827138",
							ImageColor3 = Color3.fromRGB(196, 126, 255),
							ImageTransparency = 1,
							Position = UDim2.fromScale(0.5, 0.5),
							Size = UDim2.fromScale(1.55, 1.55),
							ZIndex = 111,
						}),
						action(function(instance)
							settleStar(instance, visible)
						end),
					}),
				}),

				create("Folder")({
					Name = "Gradient",
					create("ImageLabel")({
						Name = "HighlightGradient",
						BackgroundTransparency = 1,
						Image = "rbxassetid://99800468606079",
						Position = UDim2.fromScale(0.136127, 0.00198865),
						Size = UDim2.fromScale(0.713886, 0.5),
						ZIndex = 101,
						create("UIGradient")({
							Color = ColorSequence.new(Color3.fromRGB(178, 118, 198)),
							Offset = Vector2.zero,
							action(function(instance)
								tween(instance, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
									Offset = Vector2.new(0.16, 0),
								})
							end),
						}),
					}),
					create("ImageLabel")({
						Name = "LightHighlightLeft",
						BackgroundTransparency = 1,
						Image = "rbxassetid://139334064628653",
						Position = UDim2.fromScale(-0.025, 0.00699998),
						Size = UDim2.fromScale(0.395, 1.015),
						ZIndex = 99,
						create("UIGradient")({ Color = ColorSequence.new(Color3.fromRGB(255, 46, 255)) }),
						action(function(instance)
							animateSpotlightFocus(
								instance,
								visible,
								0.08,
								UDim2.fromScale(-0.12, -0.055),
								UDim2.fromScale(0.00876923, 0.00699998),
								UDim2.fromScale(0.52, 1.12),
								UDim2.fromScale(0.374045, 0.985907),
								0
							)
						end),
					}),
					create("ImageLabel")({
						Name = "LightHighlightRight",
						BackgroundTransparency = 1,
						Image = "rbxassetid://80555777505154",
						Position = UDim2.fromScale(0.65, 0.00686102),
						Size = UDim2.fromScale(0.395, 1.015),
						ZIndex = 99,
						create("UIGradient")({ Color = ColorSequence.new(Color3.fromRGB(255, 46, 255)) }),
						action(function(instance)
							animateSpotlightFocus(
								instance,
								visible,
								0.12,
								UDim2.fromScale(0.6, -0.055),
								UDim2.fromScale(0.617, 0.00686102),
								UDim2.fromScale(0.52, 1.12),
								UDim2.fromScale(0.374045, 0.985907),
								math.pi
							)
						end),
					}),
					create("ImageLabel")({
						Name = "LightHighlightMiddle",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Image = "rbxassetid://106539961470258",
						Position = UDim2.fromScale(0.499704, 0.492323),
						Size = UDim2.fromScale(0.562368, 0.985907),
						ZIndex = 102,
						create("UIGradient")({ Color = ColorSequence.new(Color3.fromRGB(255, 46, 255)) }),
						create("UIScale")({ Name = "Pulse", Scale = 1 }),
						action(function(instance)
							pulse(instance, 0.25, 1.035, 2.6)
						end),
						action(function(instance)
							animateSpotlightFocus(
								instance,
								visible,
								0.18,
								UDim2.fromScale(0.499704, 0.46),
								UDim2.fromScale(0.499704, 0.492323),
								UDim2.fromScale(0.84, 1.15),
								UDim2.fromScale(0.562368, 0.985907),
								math.pi * 0.5
							)
						end),
					}),
				}),

				create("Folder")({
					Name = "DecoCloud",
					create("ImageLabel")({
						Name = "LeftCloud",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Image = "rbxassetid://76402386556915",
						ImageTransparency = 0.08,
						Position = UDim2.fromScale(0.218, -0.18),
						Size = UDim2.fromScale(0.188911, 0.138111),
						create("UIAspectRatioConstraint")({ AspectRatio = 2.81 }),
						create("UIGradient")({
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 46, 255)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(42, 46, 255)),
							}),
							Rotation = 180,
						}),
						action(function(instance)
							animateCloudEntrance(
								instance,
								visible,
								0.07,
								Vector2.new(0.218, -0.18),
								Vector2.new(0.2417, 0.403934),
								0
							)
						end),
					}),
					create("ImageLabel")({
						Name = "RightCloud",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Image = "rbxassetid://73402979366304",
						ImageTransparency = 0.08,
						Position = UDim2.fromScale(0.768, -0.18),
						Size = UDim2.fromScale(0.188911, 0.138111),
						create("UIAspectRatioConstraint")({ AspectRatio = 2.81 }),
						create("UIGradient")({
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 46, 255)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(42, 46, 255)),
							}),
						}),
						action(function(instance)
							animateCloudEntrance(
								instance,
								visible,
								0.1,
								Vector2.new(0.768, -0.18),
								Vector2.new(0.743509, 0.403934),
								math.pi
							)
						end),
					}),
				}),

				create("CanvasGroup")({
					Name = "CloudCircl",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0.5, 0.8),
					Size = UDim2.fromScale(0.0659627, 0.135511),
					ZIndex = 105,
					create("UIScale")({ Name = "MotionScale", Scale = 0.72 }),
					action(function(instance)
						animateSpinnerEntrance(instance, visible)
					end),
					action(function(instance)
						rotateCloudCircle(instance, visible)
					end),
					create("ImageLabel")({
						Name = "CloudLeftTop",
						BackgroundTransparency = 1,
						Image = "rbxassetid://89538349664387",
						Position = UDim2.fromScale(-0.017, -0.013),
						Size = UDim2.fromScale(0.505, 0.522),
						create("UIAspectRatioConstraint")({}),
					}),
					create("ImageLabel")({
						Name = "CloudRightTop",
						BackgroundTransparency = 1,
						Image = "rbxassetid://102724658060172",
						Position = UDim2.fromScale(0.506, -0.013),
						Size = UDim2.fromScale(0.505, 0.522),
						create("UIAspectRatioConstraint")({}),
					}),
					create("ImageLabel")({
						Name = "CloudLeftBottom",
						BackgroundTransparency = 1,
						Image = "rbxassetid://80095269078857",
						Position = UDim2.fromScale(-0.017, 0.509),
						Size = UDim2.fromScale(0.505, 0.522),
						create("UIAspectRatioConstraint")({}),
					}),
					create("ImageLabel")({
						Name = "CloudRightBottom",
						BackgroundTransparency = 1,
						Image = "rbxassetid://119418187970725",
						Position = UDim2.fromScale(0.505, 0.509),
						Size = UDim2.fromScale(0.505, 0.522),
						create("UIAspectRatioConstraint")({}),
					}),
					create("UIAspectRatioConstraint")({}),
				}),

				create("TextLabel")({
					Name = "LoadingText",
					BackgroundTransparency = 1,
					Font = Enum.Font.GothamBold,
					Position = UDim2.fromScale(0.465846, 0.659924),
					Size = UDim2.fromScale(0.0683077, 0.034134),
					Text = "Loading...",
					TextColor3 = Color3.fromRGB(244, 244, 244),
					TextTransparency = 0,
					TextScaled = true,
					action(function(instance)
						animateTextReveal(
							instance,
							visible,
							1.02,
							0.42,
							UDim2.fromScale(0.465846, 0.684),
							UDim2.fromScale(0.465846, 0.659924),
							0,
							0.0018
						)
					end),
					action(function(instance)
						animateLoadingText(instance, visible)
					end),
					create("UIStroke")({
						Color = Color3.fromRGB(12, 8, 24),
						Thickness = 1.4,
						Transparency = 0.35,
					}),
					create("UITextSizeConstraint")({
						MaxTextSize = 28,
						MinTextSize = 13,
					}),
				}),

				create("Frame")({
					Name = "LoadingTrack",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = Color3.fromRGB(106, 70, 139),
					BackgroundTransparency = 0.58,
					BorderSizePixel = 0,
					ClipsDescendants = true,
					Position = UDim2.fromScale(0.5, 0.712),
					Size = UDim2.fromScale(0.13, 0.0035),
					ZIndex = 106,

					create("UICorner")({ CornerRadius = UDim.new(1, 0) }),
					create("Frame")({
						Name = "Shimmer",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = Color3.fromRGB(230, 203, 255),
						BackgroundTransparency = 0.08,
						BorderSizePixel = 0,
						Position = UDim2.fromScale(-0.24, 0.5),
						Size = UDim2.fromScale(0.28, 1),
						ZIndex = 107,
						action(function(instance)
							shimmerProgress(instance, visible)
						end),
						create("UICorner")({ CornerRadius = UDim.new(1, 0) }),
						create("UIGradient")({
							Transparency = NumberSequence.new({
								NumberSequenceKeypoint.new(0, 1),
								NumberSequenceKeypoint.new(0.5, 0),
								NumberSequenceKeypoint.new(1, 1),
							}),
						}),
					}),
				}),

				create("TextLabel")({
					Name = "TipText",
					BackgroundTransparency = 1,
					Font = Enum.Font.GothamBold,
					Position = UDim2.fromScale(0, 0.905183),
					Size = UDim2.fromScale(0.999385, 0.034134),
					Text = "Tip: 유닛을 강화하고 배치 조합을 바꿔 더 강한 적에 대비하세요.",
					TextColor3 = Color3.fromRGB(137, 126, 150),
					TextTransparency = 0.12,
					TextScaled = true,
					action(function(instance)
						animateTextReveal(
							instance,
							visible,
							1.2,
							0.52,
							UDim2.fromScale(0, 0.934),
							UDim2.fromScale(0, 0.905183),
							0.12,
							0.0012
						)
					end),
					create("UITextSizeConstraint")({
						MaxTextSize = 22,
						MinTextSize = 11,
					}),
				}),

				create("ImageLabel")({
					Name = "RightDeco",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = "rbxassetid://76748326209585",
					Position = UDim2.fromScale(0.572923, 0.498104),
					Size = UDim2.fromScale(0.119385, 0.00632111),
					action(function(instance)
						animateImageReveal(
							instance,
							visible,
							1.14,
							0.46,
							UDim2.fromScale(0.515, 0.498104),
							UDim2.fromScale(0.572923, 0.498104),
							UDim2.fromScale(0.012, 0.00632111),
							UDim2.fromScale(0.119385, 0.00632111),
							0,
							0.001,
							math.pi
						)
					end),
					create("UIGradient")({
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(115, 21, 115)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(89, 92, 255)),
						}),
						Rotation = 90,
					}),
				}),
				create("ImageLabel")({
					Name = "LeftDeco",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = "rbxassetid://81331354109408",
					Position = UDim2.fromScale(0.426462, 0.498104),
					Size = UDim2.fromScale(0.119385, 0.00632111),
					action(function(instance)
						animateImageReveal(
							instance,
							visible,
							1.14,
							0.46,
							UDim2.fromScale(0.485, 0.498104),
							UDim2.fromScale(0.426462, 0.498104),
							UDim2.fromScale(0.012, 0.00632111),
							UDim2.fromScale(0.119385, 0.00632111),
							0,
							0.001,
							0
						)
					end),
					create("UIGradient")({
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(115, 21, 115)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(89, 92, 255)),
						}),
						Rotation = 90,
					}),
				}),
				create("ImageLabel")({
					Name = "Sword",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = "rbxassetid://94099229991691",
					Position = UDim2.fromScale(0.499692, 0.522124),
					Size = UDim2.fromScale(0.0227692, 0.079646),
					action(function(instance)
						animateImageReveal(
							instance,
							visible,
							1.3,
							0.48,
							UDim2.fromScale(0.499692, 0.505),
							UDim2.fromScale(0.499692, 0.522124),
							UDim2.fromScale(0.011, 0.04),
							UDim2.fromScale(0.0227692, 0.079646),
							0,
							0.002,
							math.pi * 0.5
						)
					end),
					create("UIGradient")({
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(115, 21, 115)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(89, 92, 255)),
						}),
						Rotation = 90,
					}),
				}),
			}),
			create("Frame")({
				Name = "EnergySweep",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 0.84,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(-0.18, 0.5),
				Size = UDim2.fromScale(0.035, 1.35),
				ZIndex = 120,
				action(sweep),
				create("UIGradient")({
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 1),
						NumberSequenceKeypoint.new(0.5, 0.15),
						NumberSequenceKeypoint.new(1, 1),
					}),
				}),
			}),
		}),

		create("Frame")({
			Name = "EntryCurtainTop",
			BackgroundColor3 = Color3.fromRGB(20, 13, 39),
			BorderSizePixel = 0,
			Position = function()
				if not visible() then
					return UDim2.fromScale(0, -0.52)
				end

				local reveal = TweenService:GetValue(
					entryProgress(),
					Enum.EasingStyle.Quart,
					Enum.EasingDirection.Out
				)
				return UDim2.fromScale(0, -0.52 * reveal)
			end,
			Size = UDim2.fromScale(1, 0.52),
			ZIndex = 180,

			create("UIGradient")({
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(31, 18, 55)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(17, 11, 33)),
				}),
				Rotation = 90,
			}),
			create("Frame")({
				Name = "EdgeGlow",
				AnchorPoint = Vector2.new(0, 1),
				BackgroundColor3 = Color3.fromRGB(155, 82, 218),
				BackgroundTransparency = 0.3,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(1, 0, 0, 2),
				ZIndex = 181,
			}),
		}),

		create("Frame")({
			Name = "EntryCurtainBottom",
			BackgroundColor3 = Color3.fromRGB(20, 13, 39),
			BorderSizePixel = 0,
			Position = function()
				if not visible() then
					return UDim2.fromScale(0, 1.02)
				end

				local reveal = TweenService:GetValue(
					entryProgress(),
					Enum.EasingStyle.Quart,
					Enum.EasingDirection.Out
				)
				return UDim2.fromScale(0, 0.5 + 0.52 * reveal)
			end,
			Size = UDim2.fromScale(1, 0.52),
			ZIndex = 180,

			create("UIGradient")({
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(17, 11, 33)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(38, 20, 61)),
				}),
				Rotation = 90,
			}),
			create("Frame")({
				Name = "EdgeGlow",
				BackgroundColor3 = Color3.fromRGB(155, 82, 218),
				BackgroundTransparency = 0.3,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 2),
				ZIndex = 181,
			}),
		}),

		create("Frame")({
			Name = "ExitVeil",
			BackgroundColor3 = Color3.fromRGB(19, 12, 38),
			BackgroundTransparency = function()
				if visible() then
					return 1
				end

				local progress = exitProgress()
				if progress < 0.24 then
					local cover = TweenService:GetValue(progress / 0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
					return 1 - cover * 0.88
				elseif progress < 0.58 then
					return 0.12
				end

				local reveal = TweenService:GetValue(
					(progress - 0.58) / 0.42,
					Enum.EasingStyle.Quart,
					Enum.EasingDirection.InOut
				)
				return 0.12 + reveal * 0.88
			end,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 190,

			create("UIGradient")({
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(36, 20, 64)),
					ColorSequenceKeypoint.new(0.5, Color3.fromRGB(18, 12, 36)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(47, 23, 74)),
				}),
			}),
		}),

		create("Frame")({
			Name = "ExitLight",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(235, 220, 255),
			BackgroundTransparency = function()
				if visible() then
					return 1
				end

				local progress = exitProgress()
				local strength = math.sin(math.pi * math.clamp(progress / 0.72, 0, 1))
				return 1 - strength * 0.68
			end,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = function()
				if visible() then
					return UDim2.fromScale(0, 0.004)
				end

				local progress = exitProgress()
				local expand = TweenService:GetValue(
					math.clamp(progress / 0.42, 0, 1),
					Enum.EasingStyle.Quart,
					Enum.EasingDirection.Out
				)
				local collapse = 1 - TweenService:GetValue(
					math.clamp((progress - 0.7) / 0.3, 0, 1),
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.In
				)
				return UDim2.fromScale(0.82 * expand * collapse, 0.004)
			end,
			ZIndex = 191,

			create("UIGradient")({
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.16, 0.35),
					NumberSequenceKeypoint.new(0.5, 0),
					NumberSequenceKeypoint.new(0.84, 0.35),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		})
	})
end
