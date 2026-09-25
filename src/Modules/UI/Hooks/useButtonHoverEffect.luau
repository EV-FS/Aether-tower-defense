local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

local action = Vide.action
local create = Vide.create
local source = Vide.source
local spring = Vide.spring

return function()
	local isHovered = source(false)

	return action(function(button: GuiButton)
		local enter = button.MouseEnter:Connect(function()
			isHovered(true)
		end)

		local leave = button.MouseLeave:Connect(function()
			isHovered(false)
		end)

		local hoverFrame = create("Frame")({
			Name = "HoverFrame",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(),
			BackgroundTransparency = spring(function()
				return if isHovered() then 0.5 else 1
			end, 0.3, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),

			Parent = button,
		})

		local hoverOutline = create("UIStroke")({
			Name = "HoverOutline",
			Color = button.BackgroundColor3,
			StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
			Thickness = 0.04,
			Transparency = spring(function()
				return if isHovered() then 0 else 1
			end, 0.3, 1),

			Parent = button,
		})

		local buttonGradient = button:FindFirstChildOfClass("UIGradient")
		local gradientConnect
		if buttonGradient then
			local cloneGradient = buttonGradient:Clone()
			cloneGradient.Parent = hoverOutline

			gradientConnect = buttonGradient:GetPropertyChangedSignal("Color"):Connect(function()
				cloneGradient.Color = buttonGradient.Color
			end)
		end

		local buttonUICorner = button:FindFirstChildOfClass("UICorner")
		if buttonUICorner then
			buttonUICorner:Clone().Parent = hoverFrame
		end

		Vide.cleanup(function()
			enter:Disconnect()
			leave:Disconnect()

			hoverFrame:Destroy()
			hoverOutline:Destroy()

			if gradientConnect then
				gradientConnect:Disconnect()
			end
		end)
	end)
end
