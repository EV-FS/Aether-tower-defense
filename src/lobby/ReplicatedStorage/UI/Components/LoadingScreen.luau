local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

local action = Vide.action
local create = Vide.create
local spring = Vide.spring
local source = Vide.source

export type Props = {
	IsVisible: () -> boolean,
	UseScreenGui: boolean?,
}

local function tween(instance: Instance, info: TweenInfo, properties: { [string]: any })
	local animation = TweenService:Create(instance, info, properties)
	animation:Play()
	return animation
end

local function floatTitle(instance: Instance, visible: () -> boolean)
	task.delay(0.9, function()
		while instance.Parent and visible() do
			local up = tween(instance, TweenInfo.new(1.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Position = UDim2.fromScale(0.5, 0.355),
			})
			up.Completed:Wait()
			if not instance.Parent or not visible() then
				break
			end

			local down = tween(instance, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Position = UDim2.fromScale(0.5, 0.375),
			})
			down.Completed:Wait()
		end
	end)
end

local function spinStar(instance: GuiObject, visible: () -> boolean)
	local elapsed = 0
	local hasFinishedEntrance = false
	local connection
	connection = RunService.RenderStepped:Connect(function(deltaTime)
		if not instance.Parent then
			connection:Disconnect()
			return
		end

		if not visible() then
			elapsed = 0
			hasFinishedEntrance = false
			return
		end
		if hasFinishedEntrance then
			return
		end

		elapsed += deltaTime
		local progress = math.clamp(elapsed / 1.5, 0, 1)
		local speed = 720 - 630 * progress
		instance.Rotation = (instance.Rotation + speed * deltaTime) % 360
		if progress >= 1 then
			hasFinishedEntrance = true
			tween(instance, TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
				Rotation = 0,
			})
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
			tween(scale, TweenInfo.new(duration * 0.72, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
				Scale = amount,
			})
		end
	end)
end

local function sweep(instance: GuiObject)
	task.spawn(function()
		while instance.Parent do
			instance.Position = UDim2.fromScale(-0.18, 0.5)
			local animation = tween(instance, TweenInfo.new(1.15, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut), {
				Position = UDim2.fromScale(1.18, 0.5),
			})
			animation.Completed:Wait()
			if instance.Parent then
				task.wait(0.35)
			end
		end
	end)
end

local function dustFall(layer: GuiObject)
	local motes = {}
	for index = 1, 44 do
		local mote = Instance.new("Frame")
		mote.Name = `DustMote{index}`
		mote.AnchorPoint = Vector2.new(0.5, 0.5)
		mote.BackgroundColor3 = if index % 3 == 0 then Color3.fromRGB(196, 218, 255) else Color3.fromRGB(255, 255, 255)
		mote.BackgroundTransparency = math.random(52, 76) / 100
		mote.BorderSizePixel = 0
		mote.Position = UDim2.fromScale(math.random(-10, 110) / 100, math.random(-10, 110) / 100)
		local size = math.random(4, 9)
		mote.Size = UDim2.fromOffset(size, size)
		mote.ZIndex = 90
		mote.Parent = layer

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = mote

		table.insert(motes, {
			Instance = mote,
			X = mote.Position.X.Scale,
			Y = mote.Position.Y.Scale,
			Speed = math.random(5, 12) / 100,
			Drift = math.random(-10, 10) / 100,
			Phase = math.random() * math.pi * 2,
		})
	end

	local elapsed = 0
	local connection
	connection = RunService.RenderStepped:Connect(function(deltaTime)
		if not layer.Parent then
			connection:Disconnect()
			return
		end

		elapsed += deltaTime
		for _, moteData in motes do
			local mote = moteData.Instance
			if not mote.Parent then
				continue
			end

			moteData.Y += moteData.Speed * deltaTime
			moteData.X += math.sin(elapsed * 0.8 + moteData.Phase) * moteData.Drift * deltaTime
			if moteData.Y > 1.08 then
				moteData.Y = -0.08
				moteData.X = math.random(-10, 110) / 100
			end
			mote.Position = UDim2.fromScale(moteData.X, moteData.Y)
		end
	end)
end

local function driftCloud(
	instance: GuiObject,
	visible: () -> boolean,
	delayTime: number,
	driftPosition: UDim2,
	driftRotation: number,
	basePosition: UDim2
)
	task.spawn(function()
		task.wait(delayTime)
		while instance.Parent do
			if not visible() then
				task.wait()
				continue
			end

			local animation = tween(instance, TweenInfo.new(2.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Position = driftPosition,
				Rotation = driftRotation,
			})
			animation.Completed:Wait()
			if not instance.Parent then
				break
			end

			if visible() then
				local returnAnimation = tween(instance, TweenInfo.new(2.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
					Position = basePosition,
					Rotation = 0,
				})
				returnAnimation.Completed:Wait()
			end
		end
	end)
end

return function(props: Props)
	local visible = props.IsVisible
	local useScreenGui = props.UseScreenGui ~= false

	return create(if useScreenGui then "ScreenGui" else "Frame")({
		Name = "LoadingScreen",
		DisplayOrder = if useScreenGui then 100 else nil,
		IgnoreGuiInset = if useScreenGui then true else nil,
		ResetOnSpawn = if useScreenGui then false else nil,
		ZIndexBehavior = if useScreenGui then Enum.ZIndexBehavior.Sibling else nil,
		Enabled = if useScreenGui then true else nil,
		Visible = if useScreenGui then nil else true,
		Size = if useScreenGui then nil else UDim2.fromScale(1, 1),

		create("CanvasGroup")({
			Name = "Container",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Interactable = visible,
			GroupTransparency = spring(function()
				return if visible() then 0 else 1
			end, 0.28, 0.86),
			Position = UDim2.fromScale(0.5, 0.5),
			Rotation = spring(function()
				return if visible() then 0 else 6
			end, 0.24, 0.82),
			Size = UDim2.fromScale(1, 1),
			ZIndex = 100,

			create("TextButton")({
				Name = "InputBlocker",
				Active = visible,
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Text = "",
				Visible = visible,
				ZIndex = 98,
			}),

			create("UIScale")({
				Scale = spring(function()
					return if visible() then 1 else 0.88
				end, 0.24, 0.82),
			}),

			create("ImageLabel")({
				Name = "Main",
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0,
				Image = "rbxassetid://121340856010495",
				ImageTransparency = spring(function()
					return if visible() then 0 else 1
				end, 0.3, 0.86),
				Size = UDim2.fromScale(1, 1),
				ZIndex = 100,

				create("Frame")({
					Name = "DustLayer",
					BackgroundTransparency = 1,
					ClipsDescendants = true,
					Size = UDim2.fromScale(1, 1),
					ZIndex = 101,
					action(dustFall),
				}),

				create("ImageLabel")({
					Name = "Title",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = "rbxassetid://86974214352692",
					ImageTransparency = spring(function()
						return if visible() then 0 else 1
					end, 0.24, 0.86),
					Position = spring(function()
							return if visible() then UDim2.fromScale(0.5, 0.365) else UDim2.fromScale(0.5, -1)
					end, 0.3, 1.5),
					Rotation = spring(function()
						return if visible() then 0 else -8
					end, 0.22, 0.84),
						Size = UDim2.fromScale(0.332543, 0.136633),
					ZIndex = 110,

					create("UIAspectRatioConstraint")({ AspectRatio = 5 }),
					create("UIScale")({
						Scale = spring(function()
							return if visible() then 1 else 0.86
						end, 0.22, 0.84),
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
						action(function(instance)
							spinStar(instance, visible)
						end),
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
								tween(instance, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
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
							return if visible() then UDim2.fromScale(0.562368, 0.985907) else UDim2.fromScale(0.64, 0.985907)
						end, 0.18, 0.86),
						ZIndex = 102,
						create("UIGradient")({ Color = ColorSequence.new(Color3.fromRGB(255, 46, 255)) }),
						create("UIScale")({ Name = "Pulse", Scale = 1 }),
						action(function(instance)
							pulse(instance, 0.25, 1.035, 2.6)
						end),
						action(function(instance)
							tween(instance, TweenInfo.new(0.8, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
								ImageTransparency = 0.05,
							})
						end),
					}),
				}),

				create("Folder")({
					Name = "DecoCloud",
					action(function(instance)
						local leftTransparency = source(0.42)
						local rightTransparency = source(0.42)

						local leftCloud = create("ImageLabel")({
							Name = "LeftCloud",
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							Image = "rbxassetid://76402386556915",
							Position = spring(function()
								return if visible() then UDim2.fromScale(0.2417, 0.403934) else UDim2.fromScale(0.218, -1)
							end, 0.3, 0.84),
							Rotation = spring(function()
								return if visible() then 0 else -5
							end, 0.3, 0.84),
							ImageTransparency = spring(leftTransparency, 0.3, 0.84),
							Size = UDim2.fromScale(0.188911, 0.138111),
							create("UIAspectRatioConstraint")({ AspectRatio = 2.81 }),
							create("UIGradient")({
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 46, 255)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(42, 46, 255)),
								}),
								Rotation = 180,
							}),
							action(function(instance)
								driftCloud(
									instance,
									visible,
									1.1,
									UDim2.fromScale(0.2417, 0.413934),
									1.5,
									UDim2.fromScale(0.2417, 0.403934)
								)
								task.spawn(function()
									while instance.Parent do
										if visible() then
											tween(instance, TweenInfo.new(2.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
												ImageTransparency = 0.2,
											}).Completed:Wait()
											tween(instance, TweenInfo.new(2.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
												ImageTransparency = 0,
											}).Completed:Wait()
										else
											leftTransparency(0.42)
											task.wait()
										end
									end
								end)
							end),
						})
						leftCloud.Parent = instance

						local rightCloud = create("ImageLabel")({
							Name = "RightCloud",
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							Image = "rbxassetid://73402979366304",
							Position = spring(function()
								return if visible() then UDim2.fromScale(0.743509, 0.403934) else UDim2.fromScale(0.768, -1)
							end, 0.3, 0.84),
							Rotation = spring(function()
								return if visible() then 0 else 5
							end, 0.3, 0.84),
							ImageTransparency = spring(rightTransparency, 0.3, 0.84),
							Size = UDim2.fromScale(0.188911, 0.138111),
							create("UIAspectRatioConstraint")({ AspectRatio = 2.81 }),
							create("UIGradient")({
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 46, 255)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(42, 46, 255)),
								}),
							}),
							action(function(instance)
								driftCloud(
									instance,
									visible,
									1.25,
									UDim2.fromScale(0.743509, 0.393934),
									-1.5,
									UDim2.fromScale(0.743509, 0.403934)
								)
								task.spawn(function()
									while instance.Parent do
										if visible() then
											tween(instance, TweenInfo.new(2.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
												ImageTransparency = 0.2,
											}).Completed:Wait()
											tween(instance, TweenInfo.new(2.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
												ImageTransparency = 0,
											}).Completed:Wait()
										else
											rightTransparency(0.42)
											task.wait()
										end
									end
								end)
							end),
						})
						rightCloud.Parent = instance
					end),
				}),

				create("Frame")({
					Name = "CloudCircl",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0.5, 0.8),
					Rotation = 0,
						Size = UDim2.fromScale(0.0659627, 0.135511),
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
							local speed = 260 + math.sin(elapsed * math.pi / 1.8) * 20
							instance.Rotation = (instance.Rotation + speed * deltaTime) % 360
						end)
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
					Size = UDim2.fromScale(0.0683077, 0.034134),
					Text = "Loading...",
					TextColor3 = Color3.fromRGB(244, 244, 244),
					TextTransparency = spring(function()
						return if visible() then 0 else 1
					end, 0.26, 0.84),
					TextScaled = true,
				}),

				create("TextLabel")({
					Name = "TipText",
					BackgroundTransparency = 1,
					Font = Enum.Font.GothamBold,
					Position = UDim2.fromScale(0, 0.905183),
					Size = UDim2.fromScale(0.999385, 0.034134),
					Text = "Tip: 안녕 나는 왁파야 그 누구보다 멋진 사람이지롱~",
					TextColor3 = Color3.fromRGB(72, 72, 72),
					TextTransparency = spring(function()
						return if visible() then 0 else 1
					end, 0.26, 0.84),
					TextScaled = true,
				}),

				create("ImageLabel")({
					Name = "RightDeco",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = "rbxassetid://76748326209585",
					Position = UDim2.fromScale(0.572923, 0.498104),
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
					Position = UDim2.fromScale(0.426462, 0.498104),
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
					Position = UDim2.fromScale(0.499692, 0.522124),
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
			create("Frame")({
				Name = "EnergySweep",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 0.72,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(-0.18, 0.5),
				Rotation = 14,
				Size = UDim2.fromScale(0.06, 1.35),
				ZIndex = 120,
				action(sweep),
				create("UIGradient")({
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 1),
						NumberSequenceKeypoint.new(0.5, 0.15),
						NumberSequenceKeypoint.new(1, 1),
					}),
				}),
			}),
		})
	})
end
