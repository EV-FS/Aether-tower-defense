local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Fusion = require(ReplicatedStorage.Packages.Fusion)

local peek = Fusion.peek
local OnEvent = Fusion.OnEvent

local function updateSliderPosition(inputPosition: Vector3, slider: Frame, handler: GuiButton, process: any?)
	local mouseX = inputPosition.X
	local frameLeft = slider.AbsolutePosition.X
	local frameWidth = slider.AbsoluteSize.X

	local percentage = math.clamp((mouseX - frameLeft) / frameWidth, 0, 1)

	handler.Position = UDim2.new(percentage, 0, handler.Position.Y.Scale, handler.Position.Y.Offset)

	if process then
		process:set(math.floor(percentage * 100))
	end
end

return function(scope, props: { Slider: Frame, Handler: GuiButton, Process: any?, OnRelease: ((value: number) -> ())? })
	local slider = props.Slider
	local handler = props.Handler
	local process = props.Process
	local onRelease = props.OnRelease

	local isDragging = scope:Value(false)

	local function stopDragging()
		if peek(isDragging) then
			isDragging:set(false)

			if onRelease and process then
				onRelease(peek(process))
			end
		end
	end

	table.insert(
		scope,
		slider.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				isDragging:set(true)
				updateSliderPosition(input.Position, slider, handler, process)
			end
		end)
	)

	scope:Hydrate(handler)({
		[OnEvent("InputBegan")] = function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				isDragging:set(true)
			end
		end,
		[OnEvent("MouseButton1Up")] = function()
			stopDragging()
		end,
	})

	table.insert(
		scope,
		UserInputService.InputEnded:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				stopDragging()
			end
		end)
	)

	table.insert(
		scope,
		UserInputService.InputChanged:Connect(function(input)
			if not peek(isDragging) then
				return
			end

			if
				input.UserInputType ~= Enum.UserInputType.MouseMovement
				and input.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end

			updateSliderPosition(input.Position, slider, handler, process)
		end)
	)
end
