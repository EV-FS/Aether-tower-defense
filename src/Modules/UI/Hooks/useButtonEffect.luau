local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

local source = Vide.source
local spring = Vide.spring
local action = Vide.action
local create = Vide.create

local function useButtonEffect(pressedScale: number?, hoverScale: number?)
	local pScale = pressedScale or 0.95
	local hScale = hoverScale or 1.05

	return action(function(button: GuiButton)
		local isPressed = source(false)
		local isHovered = source(false)
		local isClicked = source(false)

		local down = button.MouseButton1Down:Connect(function()
			isPressed(true)
		end)

		local up = button.MouseButton1Up:Connect(function()
			isPressed(false)
		end)

		local enter = button.MouseEnter:Connect(function()
			isHovered(true)
		end)

		local leave = button.MouseLeave:Connect(function()
			isHovered(false)
			isPressed(false)
		end)

		local click = button.MouseButton1Click:Connect(function()
			isClicked(true)
			task.delay(0.05, function()
				isClicked(false)
			end)
		end)

		local scale = create("UIScale")({
			Parent = button,
			Scale = spring(function()
				if isPressed() or isClicked() then
					return pScale
				elseif isHovered() then
					return hScale
				end
				return 1
			end, 0.15, 0.5),
		})

		Vide.cleanup(function()
			down:Disconnect()
			up:Disconnect()
			enter:Disconnect()
			leave:Disconnect()
			click:Disconnect()
			scale:Destroy()
		end)
	end)
end

return useButtonEffect
