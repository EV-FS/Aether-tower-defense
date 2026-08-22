local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

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

local function floatTitle(instance: Instance, visible: () -> boolean)
	task.delay(0.9, function()
		while instance.Parent and visible() do
			local up = tween(instance, TweenInfo.new(2.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Position = UDim2.fromScale(0.5, 0.355),
			})
			up.Completed:Wait()
			if not instance.Parent or not visible() then
				break
			end

			local down = tween(instance, TweenInfo.new(2.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Position = UDim2.fromScale(0.5, 0.375),
			})
			down.Completed:Wait()
		end
	end)
end

local function pulse(instance: Instance, delayTime: number, amount: number, duration: number)
	local scale = instance:FindFirstChild("Pulse")
	if not scale or not scale:IsA("UIScale") then
		return
	end

	task.delay(delayTime, function()
		if scale.Parent then
			tween(scale, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
				Scale = amount,
			})
		end
	end)
end

return function(props: Props)
	local visible = props.IsVisible

	return create("ScreenGui")({
		Name = "LoadingScreen",
		DisplayOrder = 100,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = true,

		create("CanvasGroup")({
			Name = "Container",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			GroupTransparency = spring(function()
				return if visible() then 0 else 1
			end, 0.24, 0.82),
			Position = UDim2.fromScale(0.5, 0.5),
			Rotation = spring(function()
				return if visible() then 0 else 1.5
			end, 0.2, 0.78),
			Size = UDim2.fromScale(1, 1),
			ZIndex = 100,
			create("UIScale")({
				Scale = spring(function()
					return if visible() then 1 else 0.96
				end, 0.2, 0.78),
			}),

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
						return if visible() then UDim2.fromScale(0.5, 0.365) else UDim2.fromScale(0.5, 0.04)
					end, 0.13, 0.86),
					Rotation = spring(function()
						return if visible() then 0 else -4
					end, 0.16, 0.82),
					Size = UDim2.fromScale(0.462601, 0.136633),
					ZIndex = 110,

					create("UIAspectRatioConstraint")({ AspectRatio = 5 }),
					create("UIScale")({
						Scale = spring(function()
							return if visible() then 1 else 0.86
						end, 0.16, 0.82),
					}),
					action(function(instance)
						floatTitle(instance, visible)
					end),
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
						Name = "LightHighlightLeft",
						BackgroundTransparency = 1,
						Image = "rbxassetid://139334064628653",
						Position = UDim2.fromScale(-0.025, 0.00699998),
						Size = UDim2.fromScale(0.395, 1.015),
						ZIndex = 99,
						create("UIGradient")({ Color = ColorSequence.new(Color3.fromRGB(255, 46, 255)) }),
						action(function(instance)
							tween(instance, TweenInfo.new(1.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
								Position = UDim2.fromScale(0.00876923, 0.00699998),
								Size = UDim2.fromScale(0.374045, 0.985907),
							})
						end),
					}),
					create("ImageLabel")({
						Name = "LightHighlightRight",
						BackgroundTransparency = 1,
						Image = "rbxassetid://80555777505154",
						Position = UDim2.fromScale(0.65, 0.00686102),
						Size = UDim2.fromScale(0.395, 1.015),
						ZIndex = 99,
						create("UIGradient")({ Color = ColorSequence.new(Color3.fromRGB(255, 46, 255)) }),
						action(function(instance)
							tween(instance, TweenInfo.new(1.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
								Position = UDim2.fromScale(0.617, 0.00686102),
								Size = UDim2.fromScale(0.374045, 0.985907),
							})
						end),
					}),
					create("ImageLabel")({
						Name = "LightHighlightMiddle",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Image = "rbxassetid://106539961470258",
						Position = UDim2.fromScale(0.499704, 0.492323),
						Size = spring(function()
							return if visible() then UDim2.fromScale(0.562368, 0.985907) else UDim2.fromScale(0.18, 0.36)
						end, 0.24, 0.8),
						ZIndex = 102,
						create("UIGradient")({ Color = ColorSequence.new(Color3.fromRGB(255, 46, 255)) }),
						create("UIScale")({ Name = "Pulse", Scale = 1 }),
						action(function(instance)
							pulse(instance, 0.25, 1.035, 2.6)
						end),
						action(function(instance)
							tween(instance, TweenInfo.new(1.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
								ImageTransparency = 0.05,
								Size = UDim2.fromScale(0.562368, 0.985907),
							})
						end),
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
							tween(instance, TweenInfo.new(3.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
								Position = UDim2.fromScale(0.2417, 0.420934),
								Rotation = 1.5,
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
							tween(instance, TweenInfo.new(4.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
								Position = UDim2.fromScale(0.743509, 0.386934),
								Rotation = -1.5,
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
						local elapsed = 0
						local connection
						connection = RunService.RenderStepped:Connect(function(deltaTime)
							if not instance.Parent then
								connection:Disconnect()
								return
							end

							elapsed += deltaTime
							local speed = 55 + math.sin(elapsed * math.pi / 2.9) * 35
							instance.Rotation = (instance.Rotation + speed * deltaTime) % 360
						end)
					end),
					create("ImageButton")({
						Name = "CloudLeftTop",
						BackgroundTransparency = 1,
						Image = "rbxassetid://89538349664387",
						Position = UDim2.fromScale(-0.017, -0.013),
						Size = UDim2.fromScale(0.505, 0.522),
						create("UIAspectRatioConstraint")({}),
					}),
					create("ImageButton")({
						Name = "CloudRightTop",
						BackgroundTransparency = 1,
						Image = "rbxassetid://102724658060172",
						Position = UDim2.fromScale(0.506, -0.013),
						Size = UDim2.fromScale(0.505, 0.522),
						create("UIAspectRatioConstraint")({}),
					}),
					create("ImageButton")({
						Name = "CloudLeftBottom",
						BackgroundTransparency = 1,
						Image = "rbxassetid://80095269078857",
						Position = UDim2.fromScale(-0.017, 0.509),
						Size = UDim2.fromScale(0.505, 0.522),
						create("UIAspectRatioConstraint")({}),
					}),
					create("ImageButton")({
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

				create("ImageLabel")({
					Name = "RightDeco",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = "rbxassetid://76748326209585",
					Position = UDim2.fromOffset(931, 394),
					Size = UDim2.fromScale(0.119385, 0.00632111),
					create("UIGradient")({
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(115, 21, 115)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(89, 92, 255)),
						}),
						Rotation = 90,
					}),
				}),
				create("ImageLabel")({
					Name = "LeftDeco",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = "rbxassetid://81331354109408",
					Position = UDim2.fromOffset(693, 394),
					Size = UDim2.fromScale(0.119385, 0.00632111),
					create("UIGradient")({
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(115, 21, 115)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(89, 92, 255)),
						}),
						Rotation = 90,
					}),
				}),
				create("ImageLabel")({
					Name = "Sword",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = "rbxassetid://94099229991691",
					Position = UDim2.fromOffset(812, 413),
					Size = UDim2.fromScale(0.0227692, 0.079646),
					create("UIGradient")({
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(115, 21, 115)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(89, 92, 255)),
						}),
						Rotation = 90,
					}),
				}),
			}),
		})
	})
end