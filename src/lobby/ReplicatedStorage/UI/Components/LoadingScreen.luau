local TweenService = game:GetService("TweenService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

local action = Vide.action
local create = Vide.create
local spring = Vide.spring

export type Props = {
	IsVisible: () -> boolean,
}

local function tween(instance: Instance, info: TweenInfo, properties: { [string]: any })
	local animation = TweenService:Create(instance, info, properties)
	animation:Play()
	return animation
end

return function(props: Props)
	local visible = props.IsVisible

	return create("ScreenGui")({
		Name = "LoadingScreen",
		DisplayOrder = 100,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = visible,

		create("Frame")({
			Name = "Container",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			ZIndex = 100,

			create("ImageLabel")({
				Name = "Main",
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0,
				Image = "rbxassetid://121340856010495",
				ImageTransparency = spring(function()
					return if visible() then 0 else 1
				end, 0.22, 0.82),
				Size = UDim2.fromScale(1, 1),
				ZIndex = 100,

				create("ImageLabel")({
					Name = "Title",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = "rbxassetid://86974214352692",
					ImageTransparency = spring(function()
						return if visible() then 0 else 1
					end, 0.18, 0.8),
					Position = spring(function()
						return if visible() then UDim2.fromScale(0.5, 0.365) else UDim2.fromScale(0.5, 0.34)
					end, 0.2, 0.78),
					Size = UDim2.fromScale(0.462601, 0.136633),
					ZIndex = 110,

					create("UIAspectRatioConstraint")({ AspectRatio = 5 }),
					create("ImageLabel")({
						Name = "TowerDefense",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Image = "rbxassetid://94841238370615",
						Position = UDim2.fromScale(0.5, 1.1),
						Size = UDim2.fromScale(0.607542, 0.181463),
						create("UIAspectRatioConstraint")({ AspectRatio = 12 }),
					}),
					create("ImageLabel")({
						Name = "Star",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Image = "rbxassetid://100121381827138",
						Position = UDim2.fromScale(0.779, 0.632),
						Size = UDim2.fromScale(0.139757, 0.797365),
					}),
				}),

				create("Folder")({
					Name = "Gradient",
					create("ImageLabel")({
						Name = "HighlightGradient",
						BackgroundTransparency = 1,
						Image = "rbxassetid://99800468606079",
						Position = UDim2.fromScale(0.136127, 0.00198865),
						Size = UDim2.fromScale(0.713886, 0.5),
						ZIndex = 101,
						create("UIGradient")({
							Color = ColorSequence.new(Color3.fromRGB(178, 118, 198)),
							Offset = Vector2.zero,
							action(function(instance)
								tween(instance, TweenInfo.new(2.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
									Offset = Vector2.new(0.16, 0),
								})
							end),
						}),
					}),
					create("ImageLabel")({
						Name = "LightHighlightMiddle",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Image = "rbxassetid://106539961470258",
						ImageTransparency = spring(function()
							return if visible() then 0.05 else 1
						end, 0.25, 0.75),
						Position = UDim2.fromScale(0.499704, 0.492323),
						Size = spring(function()
							return if visible() then UDim2.fromScale(0.562368, 0.985907) else UDim2.fromScale(0.42, 0.8)
						end, 0.2, 0.72),
						ZIndex = 102,
						create("UIGradient")({ Color = ColorSequence.new(Color3.fromRGB(255, 46, 255)) }),
					}),
				}),

				create("Folder")({
					Name = "DecoCloud",
					create("ImageLabel")({
						Name = "LeftCloud",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Image = "rbxassetid://76402386556915",
						Position = UDim2.fromScale(0.2417, 0.403934),
						Rotation = 0,
						Size = UDim2.fromScale(0.265863, 0.138111),
						create("UIAspectRatioConstraint")({ AspectRatio = 2.81 }),
						create("UIGradient")({
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 46, 255)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(42, 46, 255)),
							}),
							Rotation = 180,
						}),
						action(function(instance)
							tween(instance, TweenInfo.new(3.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
								Position = UDim2.fromScale(0.2417, 0.421934),
								Rotation = 2,
							})
						end),
					}),
					create("ImageLabel")({
						Name = "RightCloud",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Image = "rbxassetid://73402979366304",
						Position = UDim2.fromScale(0.743509, 0.403934),
						Rotation = 0,
						Size = UDim2.fromScale(0.265863, 0.138111),
						create("UIAspectRatioConstraint")({ AspectRatio = 2.81 }),
						create("UIGradient")({
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 46, 255)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(42, 46, 255)),
							}),
						}),
						action(function(instance)
							tween(instance, TweenInfo.new(4.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
								Position = UDim2.fromScale(0.743509, 0.387934),
								Rotation = -2,
							})
						end),
					}),
				}),

				create("Frame")({
					Name = "CloudCircl",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0.5, 0.8),
					Rotation = 0,
					Size = UDim2.fromScale(0.0820985, 0.135511),
					ZIndex = 105,
					action(function(instance)
						tween(instance, TweenInfo.new(1.7, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {
							Rotation = 360,
						})
					end),
					create("ImageLabel")({
						Name = "CloudLeftTop",
						BackgroundTransparency = 1,
						Image = "rbxassetid://89538349664387",
						Position = UDim2.fromScale(-0.017, -0.013),
						Size = UDim2.fromScale(0.505, 0.522),
						create("UIAspectRatioConstraint")({}),
					}),
					create("ImageLabel")({
						Name = "CloudRightTop",
						BackgroundTransparency = 1,
						Image = "rbxassetid://102724658060172",
						Position = UDim2.fromScale(0.506, -0.013),
						Size = UDim2.fromScale(0.505, 0.522),
						create("UIAspectRatioConstraint")({}),
					}),
					create("ImageLabel")({
						Name = "CloudLeftBottom",
						BackgroundTransparency = 1,
						Image = "rbxassetid://80095269078857",
						Position = UDim2.fromScale(-0.017, 0.509),
						Size = UDim2.fromScale(0.505, 0.522),
						create("UIAspectRatioConstraint")({}),
					}),
					create("ImageLabel")({
						Name = "CloudRightBottom",
						BackgroundTransparency = 1,
						Image = "rbxassetid://119418187970725",
						Position = UDim2.fromScale(0.505, 0.509),
						Size = UDim2.fromScale(0.505, 0.522),
						create("UIAspectRatioConstraint")({}),
					}),
					create("UIAspectRatioConstraint")({}),
				}),

				create("TextLabel")({
					Name = "LoadingText",
					BackgroundTransparency = 1,
					Font = Enum.Font.GothamBold,
					Position = UDim2.fromScale(0.465846, 0.659924),
					Size = UDim2.fromOffset(111, 27),
					Text = "Loading...",
					TextColor3 = Color3.fromRGB(244, 244, 244),
					TextTransparency = spring(function()
						return if visible() then 0 else 1
					end, 0.18, 0.8),
					TextScaled = true,
				}),

				create("TextLabel")({
					Name = "TipText",
					BackgroundTransparency = 1,
					Font = Enum.Font.GothamBold,
					Position = UDim2.fromScale(0, 0.905183),
					Size = UDim2.fromOffset(1624, 27),
					Text = "Tip: Hello",
					TextColor3 = Color3.fromRGB(72, 72, 72),
					TextTransparency = spring(function()
						return if visible() then 0 else 1
					end, 0.18, 0.8),
					TextScaled = true,
				}),
			}),
		})
	})
end