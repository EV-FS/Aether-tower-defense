local SetMobileStyle = {}

function SetMobileStyle.Default(imageButton: ImageButton)
	local imageLabel = imageButton:FindFirstChild("ActionIcon")
	local textLabel = imageButton:FindFirstChild("ActionTitle")

	local visualLabel = Instance.new("ImageLabel")
	visualLabel.BackgroundTransparency = 1
	visualLabel.Image = "rbxassetid://130691448656069"
	visualLabel.ImageRectOffset = Vector2.new(1, 146)
	visualLabel.ImageRectSize = Vector2.new(144, 144)
	visualLabel.Parent = imageButton
	visualLabel.ZIndex = -1

	visualLabel.Size = UDim2.fromScale(1, 1)

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

function SetMobileStyle.Toggle(imageButton: ImageButton)
	local imageLabel = imageButton:FindFirstChild("ActionIcon")
	local textLabel = imageButton:FindFirstChild("ActionTitle")

	local visualLabel = Instance.new("ImageLabel")
	visualLabel.BackgroundTransparency = 1
	visualLabel.Image = "rbxassetid://130691448656069"
	visualLabel.ImageRectOffset = Vector2.new(1, 146)
	visualLabel.ImageRectSize = Vector2.new(144, 144)
	visualLabel.Parent = imageButton
	visualLabel.ZIndex = -1
	visualLabel.Size = UDim2.fromScale(1, 1)

	imageButton.ImageTransparency = 1

	if imageLabel then
		imageLabel.ImageColor3 = Color3.new(1, 1, 1)
		imageLabel.ImageTransparency = 0.5
	end
	if textLabel then
		textLabel.TextColor3 = Color3.new(1, 1, 1)
		textLabel.TextTransparency = 0.5
	end

	local isToggled = false
	local touchObject = nil

	local function updateVisual(toggled: boolean)
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

	imageButton.InputBegan:Connect(function(inputObject)
		if
			touchObject
			or inputObject.UserInputType ~= Enum.UserInputType.Touch
			or inputObject.UserInputState ~= Enum.UserInputState.Begin
		then
			return
		end

		touchObject = inputObject
		isToggled = not isToggled

		updateVisual(isToggled)
	end)

	imageButton.InputEnded:Connect(function(inputObject)
		if inputObject ~= touchObject then
			return
		end
		touchObject = nil
	end)
end

return SetMobileStyle
