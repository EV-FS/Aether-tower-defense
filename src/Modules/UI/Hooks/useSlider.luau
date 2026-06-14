local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Vide = require(ReplicatedStorage.Packages.Vide)

local cleanup = Vide.cleanup
local source = Vide.source

local function updateSliderPosition(inputPosition: Vector3, slider: Frame, handler: GuiButton, valueSource: any)
	local mouseX = inputPosition.X
	local frameLeft = slider.AbsolutePosition.X
	local frameWidth = slider.AbsoluteSize.X

	local percentage = math.clamp((mouseX - frameLeft) / frameWidth, 0, 1)

	handler.Position = UDim2.new(percentage, 0, handler.Position.Y.Scale, handler.Position.Y.Offset)

	if valueSource then
		valueSource(math.floor(percentage * 100))
	end
end

return function(props: { Slider: Frame, Handler: GuiButton, Process: any?, OnRelease: ((value: number) -> ())? })
	local slider = props.Slider
	local handler = props.Handler
	local valueSource = props.Process
	local onRelease = props.OnRelease

	local isDragging = source(false)

	local function stopDragging()
		if isDragging() then
			isDragging(false)

			if onRelease and valueSource then
				onRelease(valueSource())
			end
		end
	end

	local sliderBegan = slider.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			isDragging(true)
			updateSliderPosition(input.Position, slider, handler, valueSource)
		end
	end)

	local handlerBegan = handler.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			isDragging(true)
		end
	end)

	local handlerUp = handler.MouseButton1Up:Connect(function()
		stopDragging()
	end)

	local inputEnded = UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			stopDragging()
		end
	end)

	local inputChanged = UserInputService.InputChanged:Connect(function(input)
		if not isDragging() then
			return
		end

		if
			input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end

		updateSliderPosition(input.Position, slider, handler, valueSource)
	end)

	local disconnectAll = function()
		sliderBegan:Disconnect()
		handlerBegan:Disconnect()
		handlerUp:Disconnect()
		inputEnded:Disconnect()
		inputChanged:Disconnect()
	end

	local hasCleanupScope = pcall(function()
		cleanup(disconnectAll)
	end)

	if not hasCleanupScope then
		return disconnectAll
	end

	return nil
end
