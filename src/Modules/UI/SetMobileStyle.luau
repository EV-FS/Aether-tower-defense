local SetMobileStyle = {}

local function updateToggleVisual(imageButton: ImageButton, toggled: boolean)
	local visualLabel = imageButton:FindFirstChild("MobileStyleVisual") :: ImageLabel?
	if not visualLabel then
		return
	end

	imageButton:SetAttribute("IsToggled", toggled)

	local imageLabel = imageButton:FindFirstChild("ActionIcon") :: ImageLabel?
	local textLabel = imageButton:FindFirstChild("ActionTitle") :: TextLabel?

	if toggled then
		visualLabel.ImageRectOffset = Vector2.new(146, 146)
		visualLabel.ImageRectSize = Vector2.new(144, 144)
		if imageLabel then
			imageLabel.ImageColor3 = Color3.new(0, 0, 0)
		end
		if textLabel then
			textLabel.TextColor3 = Color3.new(0, 0, 0)
		end
	else
		visualLabel.ImageRectOffset = Vector2.new(1, 146)
		visualLabel.ImageRectSize = Vector2.new(144, 144)
		if imageLabel then
			imageLabel.ImageColor3 = Color3.new(1, 1, 1)
		end
		if textLabel then
			textLabel.TextColor3 = Color3.new(1, 1, 1)
		end
	end
end

function SetMobileStyle.Default(imageButton: ImageButton)
	local imageLabel = imageButton:FindFirstChild("ActionIcon") :: ImageLabel?
	local textLabel = imageButton:FindFirstChild("ActionTitle") :: TextLabel?

	local visualLabel = imageButton:FindFirstChild("MobileStyleVisual") :: ImageLabel?
	if not visualLabel then
		visualLabel = Instance.new("ImageLabel")
		visualLabel.Name = "MobileStyleVisual"
		visualLabel.BackgroundTransparency = 1
		visualLabel.Image = "rbxassetid://130691448656069"
		visualLabel.ImageRectOffset = Vector2.new(1, 146)
		visualLabel.ImageRectSize = Vector2.new(144, 144)
		visualLabel.Parent = imageButton
		visualLabel.ZIndex = -1
		visualLabel.Size = UDim2.fromScale(1, 1)
	end

	imageButton.ImageTransparency = 1

	if imageLabel then
		imageLabel.ImageColor3 = Color3.new(1, 1, 1)
		imageLabel.ImageTransparency = 0.5
	end
	if textLabel then
		textLabel.TextColor3 = Color3.new(1, 1, 1)
		textLabel.TextTransparency = 0.5
	end

	local touchObject = nil
	imageButton.InputBegan:Connect(function(inputObject)
		if
			touchObject
			or inputObject.UserInputType ~= Enum.UserInputType.Touch
			or inputObject.UserInputState ~= Enum.UserInputState.Begin
		then
			return
		end

		touchObject = inputObject
		visualLabel.ImageRectOffset = Vector2.new(146, 146)
		visualLabel.ImageRectSize = Vector2.new(144, 144)
		if imageLabel then
			imageLabel.ImageColor3 = Color3.new(0, 0, 0)
		end
		if textLabel then
			textLabel.TextColor3 = Color3.new(0, 0, 0)
		end
	end)

	imageButton.InputEnded:Connect(function(inputObject)
		if inputObject ~= touchObject then
			return
		end

		touchObject = nil

		visualLabel.ImageRectOffset = Vector2.new(1, 146)
		visualLabel.ImageRectSize = Vector2.new(144, 144)
		if imageLabel then
			imageLabel.ImageColor3 = Color3.new(1, 1, 1)
		end
		if textLabel then
			textLabel.TextColor3 = Color3.new(1, 1, 1)
		end
	end)
end

function SetMobileStyle.SetToggleState(imageButton: ImageButton, toggled: boolean)
	updateToggleVisual(imageButton, toggled)
end

function SetMobileStyle.Toggle(imageButton: ImageButton)
	local imageLabel = imageButton:FindFirstChild("ActionIcon") :: ImageLabel?
	local textLabel = imageButton:FindFirstChild("ActionTitle") :: TextLabel?

	local visualLabel = imageButton:FindFirstChild("MobileStyleVisual") :: ImageLabel?
	if not visualLabel then
		visualLabel = Instance.new("ImageLabel")
		visualLabel.Name = "MobileStyleVisual"
		visualLabel.BackgroundTransparency = 1
		visualLabel.Image = "rbxassetid://130691448656069"
		visualLabel.ImageRectOffset = Vector2.new(1, 146)
		visualLabel.ImageRectSize = Vector2.new(144, 144)
		visualLabel.Parent = imageButton
		visualLabel.ZIndex = -1
		visualLabel.Size = UDim2.fromScale(1, 1)
	end

	imageButton.ImageTransparency = 1

	if imageLabel then
		imageLabel.ImageColor3 = Color3.new(1, 1, 1)
		imageLabel.ImageTransparency = 0.5
	end
	if textLabel then
		textLabel.TextColor3 = Color3.new(1, 1, 1)
		textLabel.TextTransparency = 0.5
	end

	updateToggleVisual(imageButton, imageButton:GetAttribute("IsToggled") == true)
end

return SetMobileStyle
