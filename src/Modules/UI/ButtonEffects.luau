local TweenService = game:GetService("TweenService")

local ButtonEffects = {}

local isPressing = false
local isClicked = false

local DEFAULT_SCALE = 1
local PRESSED_SCALE = 0.88
local TWEEN_INFO = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

type EffectOptions = {
	hoverScale: number?,
	pressScale: number?,
	period: number?,
	damping: number?,
}

function ButtonEffects.ApplyPressEffect(button, pressedScale)
	pressedScale = pressedScale or PRESSED_SCALE

	local scale = button:FindFirstChild("PressScale") or Instance.new("UIScale")
	scale.Name = "PressScale"
	scale.Scale = DEFAULT_SCALE
	scale.Parent = button

	local tween

	local function play(targetScale)
		if tween then
			tween:Cancel()
		end

		tween = TweenService:Create(scale, TWEEN_INFO, {
			Scale = targetScale,
		})

		tween:Play()
	end

	local down = button.MouseButton1Down:Connect(function()
		isPressing = true
		play(pressedScale)
	end)

	local up = button.MouseButton1Up:Connect(function()
		isPressing = false
		if not isClicked then
			play(DEFAULT_SCALE)
		end
	end)

	local leave = button.MouseLeave:Connect(function()
		play(DEFAULT_SCALE)
	end)

	local activated = button.MouseButton1Click:Connect(function()
		isClicked = true
		play(pressedScale)

		task.delay(0.05, function()
			isClicked = false
			if not isPressing then
				play(DEFAULT_SCALE)
			end
		end)
	end)

	return function()
		down:Disconnect()
		up:Disconnect()
		leave:Disconnect()
		activated:Disconnect()

		if tween then
			tween:Cancel()
		end

		scale.Scale = DEFAULT_SCALE
	end
end

return ButtonEffects
