local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Vide = require(ReplicatedStorage.Packages.Vide)

local action = Vide.action
local cleanup = Vide.cleanup
local read = Vide.read

type Reactive<T> = T | (() -> T)

export type ShineMotion = {
	startPosition: UDim2?,
	endPosition: UDim2?,
	duration: number?,
	restInterval: number?,
}

local START_POSITION = UDim2.fromScale(-0.25, 0.5)
local END_POSITION = UDim2.fromScale(1.25, 0.5)
local TRAVEL_DURATION = 0.62
local REST_INTERVAL = 3.4

return function(
	getActive: Reactive<boolean>,
	getSpeed: Reactive<number>?,
	initialDelay: number?,
	motion: ShineMotion?
)
	return action(function(instance: Instance)
		assert(instance:IsA("GuiObject"), "useDiagonalShine must be used on a GuiObject")

		local shine = instance :: GuiObject
		local startPosition = if motion and motion.startPosition then motion.startPosition else START_POSITION
		local endPosition = if motion and motion.endPosition then motion.endPosition else END_POSITION
		local travelDuration = if motion and motion.duration then motion.duration else TRAVEL_DURATION
		local restInterval = if motion and motion.restInterval then motion.restInterval else REST_INTERVAL
		local isAlive = true
		local activeTween: Tween? = nil
		shine.Position = startPosition
		shine.Visible = false

		local shineThread = task.spawn(function()
			task.wait(initialDelay or 0)

			while isAlive and shine.Parent do
				if not read(getActive) then
					task.wait(0.2)
					continue
				end

				local speed = if getSpeed then math.max(read(getSpeed), 0.35) else 1
				shine.Position = startPosition
				shine.Visible = true

				local tween = TweenService:Create(
					shine,
					TweenInfo.new(travelDuration / speed, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
					{ Position = endPosition }
				)
				activeTween = tween
				tween:Play()
				tween.Completed:Wait()
				activeTween = nil
				shine.Visible = false

				task.wait(restInterval / math.sqrt(speed))
			end
		end)

		cleanup(function()
			isAlive = false
			if activeTween then
				activeTween:Cancel()
				activeTween = nil
			end
			pcall(task.cancel, shineThread)
			shine.Visible = false
		end)
	end)
end
