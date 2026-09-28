local TweenService = game:GetService("TweenService")

local HOVER_TWEEN = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PRESS_TWEEN = TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local LobbyButtonEffects = {}

local function isVisualButton(button: GuiButton): boolean
	if button:GetAttribute("DisableLobbyButtonEffects") or button.Name:find("Backdrop")
		or (not button.Active and not button.Selectable) then
		return false
	end
	if button:FindFirstChildOfClass("UIGradient") or button:FindFirstChildOfClass("UICorner")
		or button:FindFirstChildOfClass("UIStroke") then
		return true
	end
	if button:IsA("ImageButton") then
		return (button.Image ~= "" and button.ImageTransparency < 1) or button.BackgroundTransparency < 1
	end
	return (button.Text ~= "" and button.TextTransparency < 1) or button.BackgroundTransparency < 1
end

local function attach(button: GuiButton): () -> ()
	local connections: { RBXScriptConnection } = {}
	local tweens: { [Instance]: Tween } = {}
	local ownsScale = button:FindFirstChildOfClass("UIScale") == nil
	local scale: UIScale? = nil
	if ownsScale then
		scale = Instance.new("UIScale")
		scale.Name = "LobbyButtonScale"
		scale.Parent = button
	end

	local corner = button:FindFirstChildOfClass("UICorner")
	local gradient = button:FindFirstChildOfClass("UIGradient")
	local hasOutline = corner ~= nil or gradient ~= nil or button:FindFirstChildOfClass("UIStroke") ~= nil
	local overlay: Frame? = nil
	local outline: UIStroke? = nil
	local imageHighlight: ImageLabel? = nil
	if hasOutline then
		overlay = Instance.new("Frame")
		overlay.Name = "LobbyHoverShade"
		overlay.Active = false
		overlay.BorderSizePixel = 0
		overlay.BackgroundColor3 = Color3.new()
		overlay.BackgroundTransparency = 1
		overlay.Size = UDim2.fromScale(1, 1)
		overlay.Parent = button
		if corner then corner:Clone().Parent = overlay end

		outline = Instance.new("UIStroke")
		outline.Name = "LobbyHoverOutline"
		outline.Color = button.BackgroundColor3
		outline.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
		outline.Thickness = 0.04
		outline.Transparency = 1
		outline.Parent = button
		if gradient then
			local copiedGradient = gradient:Clone()
			copiedGradient.Parent = outline
			table.insert(connections, gradient:GetPropertyChangedSignal("Color"):Connect(function()
				copiedGradient.Color = gradient.Color
			end))
		end
	elseif button:IsA("ImageButton") and button.Image ~= "" then
		imageHighlight = Instance.new("ImageLabel")
		imageHighlight.Name = "LobbyHoverImage"
		imageHighlight.Active = false
		imageHighlight.BackgroundTransparency = 1
		imageHighlight.Image = button.Image
		imageHighlight.ImageTransparency = 1
		imageHighlight.ScaleType = button.ScaleType
		imageHighlight.SliceCenter = button.SliceCenter
		imageHighlight.SliceScale = button.SliceScale
		imageHighlight.ImageRectOffset = button.ImageRectOffset
		imageHighlight.ImageRectSize = button.ImageRectSize
		imageHighlight.Size = UDim2.fromScale(1, 1)
		imageHighlight.Parent = button
		table.insert(connections, button:GetPropertyChangedSignal("Image"):Connect(function()
			imageHighlight.Image = button.Image
		end))
	end

	local hovered = false
	local pressed = false
	local function tween(instance: Instance?, target: { [string]: number }, info: TweenInfo)
		if not instance then return end
		local previous = tweens[instance]
		if previous then previous:Cancel() end
		local nextTween = TweenService:Create(instance, info, target)
		tweens[instance] = nextTween
		nextTween:Play()
	end
	local function update()
		local active = button.Interactable and button.Visible
		local over = active and hovered
		local down = active and pressed
		tween(overlay, { BackgroundTransparency = if over then 0.5 else 1 }, HOVER_TWEEN)
		tween(outline, { Transparency = if over then 0 else 1 }, HOVER_TWEEN)
		tween(imageHighlight, { ImageTransparency = if over then 0.75 else 1 }, HOVER_TWEEN)
		if scale then
			tween(scale, { Scale = if down then 0.94 elseif over then 1.04 else 1 }, if down then PRESS_TWEEN else HOVER_TWEEN)
		end
	end

	table.insert(connections, button.MouseEnter:Connect(function()
		hovered = true
		update()
	end))
	table.insert(connections, button.MouseLeave:Connect(function()
		hovered = false
		pressed = false
		update()
	end))
	table.insert(connections, button.MouseButton1Down:Connect(function()
		pressed = true
		update()
	end))
	table.insert(connections, button.MouseButton1Up:Connect(function()
		pressed = false
		update()
	end))
	table.insert(connections, button.SelectionGained:Connect(function()
		hovered = true
		update()
	end))
	table.insert(connections, button.SelectionLost:Connect(function()
		hovered = false
		pressed = false
		update()
	end))
	table.insert(connections, button:GetPropertyChangedSignal("Interactable"):Connect(update))

	return function()
		for _, connection in connections do connection:Disconnect() end
		for _, activeTween in tweens do activeTween:Cancel() end
		if overlay then overlay:Destroy() end
		if outline then outline:Destroy() end
		if imageHighlight then imageHighlight:Destroy() end
		if scale then scale:Destroy() end
	end
end

function LobbyButtonEffects.Attach(interface: ScreenGui): () -> ()
	local attached: { [GuiButton]: () -> () } = {}
	local pending: { [GuiButton]: boolean } = {}
	local running = true
	local function consider(instance: Instance)
		if not running or not instance:IsA("GuiButton") or attached[instance] or pending[instance] then return end
		pending[instance] = true
		task.defer(function()
			pending[instance] = nil
			if running and instance:IsDescendantOf(interface) and isVisualButton(instance) and not attached[instance] then
				attached[instance] = attach(instance)
			end
		end)
	end
	local added = interface.DescendantAdded:Connect(consider)
	local removing = interface.DescendantRemoving:Connect(function(instance)
		if instance:IsA("GuiButton") and attached[instance] then
			attached[instance]()
			attached[instance] = nil
		end
	end)
	for _, descendant in interface:GetDescendants() do consider(descendant) end
	return function()
		running = false
		added:Disconnect()
		removing:Disconnect()
		for button, detach in attached do
			detach()
			attached[button] = nil
		end
		table.clear(pending)
	end
end

return LobbyButtonEffects
