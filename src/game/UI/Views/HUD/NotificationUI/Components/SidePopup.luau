local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create
local source = Vide.source
local spring = Vide.spring

type props = {
	Name: string,
	Icon: string | number,
	LayoutOrder: number,
	Title: string,
	Description: string,
	Duration: number,
}

return function(props)
	local frameName = props.Name
	local iconImage = props.Icon
	local titleText = props.Title
	local descText = props.Description
	local duration = props.Duration

	local targetPosition = source(UDim2.fromScale(1.5, 0.5))
	local posSpring = spring(targetPosition, 0.2, 1)

	local leftTime = source(duration)

	task.defer(function()
		targetPosition(UDim2.fromScale(0.5, 0.5))
	end)

	RunService.PreRender:Connect(function(dt)
		leftTime(leftTime() - dt)
		if leftTime() <= 0.2 then
			targetPosition(UDim2.fromScale(1.5, 0.5))
		end
	end)

	return create("Frame")({
		Name = frameName,
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Size = UDim2.fromScale(0.5, 0.1),

		create("Frame")({
			Name = "Canvas",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(18, 18, 18),
			Position = posSpring,
			Size = UDim2.fromScale(0.95, 0.85),

			create("UIStroke")({
				Name = "UIStroke",
				Thickness = 3.5,
			}),

			create("UIStroke")({
				Name = "UIStroke",
				BorderStrokePosition = Enum.BorderStrokePosition.Inner,
				Color = Color3.fromRGB(65, 65, 65),
				Thickness = 3.5,
			}),

			create("UICorner")({
				Name = "UICorner",
				CornerRadius = UDim.new(0.125, 0),
			}),

			create("ImageLabel")({
				Name = "Icon",
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				Image = if typeof(iconImage) == "string" then iconImage else `rbxassetid://{iconImage}`,
				Position = UDim2.fromScale(0.03, 0.47),
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromScale(0.18, 0.7),
			}),

			create("TextLabel")({
				Name = "Title",
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/Nunito.json",
					Enum.FontWeight.ExtraBold,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(0.225, 0.35),
				RichText = true,
				Size = UDim2.fromScale(0.725, 0.425),
				Text = titleText,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,

				create("UIStroke")({
					Name = "UIStroke",
					Thickness = 2,
				}),
			}),

			create("TextLabel")({
				Name = "Description",
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/Nunito.json",
					Enum.FontWeight.ExtraBold,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(0.225, 0.66),
				RichText = true,
				Size = UDim2.fromScale(0.75, 0.25),
				Text = descText,
				TextColor3 = Color3.fromRGB(200, 200, 200),
				TextScaled = true,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextXAlignment = Enum.TextXAlignment.Left,

				create("UIStroke")({
					Name = "UIStroke",
					Thickness = 2,
				}),
			}),

			create("Frame")({
				Name = "LeftTime",
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 0.2,
				Position = UDim2.fromScale(0.5, 0.9),
				Size = function()
					return UDim2.fromScale(math.max(0, leftTime() / duration * 0.96), 0.03)
				end,

				create("UICorner")({
					Name = "UICorner",
					CornerRadius = UDim.new(1, 0),
				}),
			}),
		}),
	})
end
