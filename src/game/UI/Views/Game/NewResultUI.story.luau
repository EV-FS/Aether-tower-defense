local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local useButtonEffect = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useButtonEffect)
local useButtonHoverEffect = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useButtonHoverEffect)
local Slot = require(ReplicatedStorage.UI.Components.Slot)

local create = Vide.create
local source = Vide.source
local spring = Vide.spring
local show = Vide.show
local read = Vide.read
local mount = Vide.mount

local resultEffectTask = nil

local isVisible = source(false)
local isClose = source(false)
local resultVisible = source(false)
local matchResult = source("Defeat")
local coins = source(10)
local gems = source(10)

local VICTORY_THEME = Color3.fromRGB(124, 236, 49)
local DEFEAT_THEME = Color3.fromRGB(236, 49, 49)

return function(target: Instance)
	local container = Instance.new("Frame")
	container.Name = "SummonUIStoryContainer"
	container.BackgroundColor3 = Color3.fromRGB(0, 0, 255)
	container.Size = UDim2.fromScale(1, 1)
	container.BackgroundTransparency = 1
	container.Parent = target

	local destroyVide = mount(function()
		local wasVisible = false
		local frameSize, setFrameSize = spring(function()
			if isClose() then
				return UDim2.fromScale(0.4, 0.4)
			end

			return if isVisible() then UDim2.fromScale(1, 1) else UDim2.fromScale(0.9, 0.9)
		end, 0.5, 0.9)

		Vide.effect(function()
			local visible = isVisible()
			local didClose = wasVisible and not visible
			wasVisible = visible

			if visible then
				setFrameSize({
					position = UDim2.fromScale(0.9, 0.9),
					velocity = UDim2.fromScale(0, 0),
				})
				isClose(false)
			elseif didClose then
				isClose(true)
			end

			if resultEffectTask then
				task.cancel(resultEffectTask)
				resultEffectTask = nil
				resultVisible(false)
			end

			if visible then
				resultEffectTask = task.delay(0.75, function()
					resultVisible(true)
					resultEffectTask = nil
				end)
			else
				resultVisible(false)
			end
		end)

		return create("Frame")({
			Name = "Container",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Rotation = spring(function()
				return if isVisible() then 0 else -3
			end, 0.4, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = frameSize,

			Vide.action(function(mainFrame)
				Vide.effect(function()
					if not isClose() then
						mainFrame.Position = UDim2.fromScale(0.5, 0.5)
						return
					end

					local closeTween = TweenService:Create(
						mainFrame,
						TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.In),
						{ Position = UDim2.fromScale(0.5, 1.25) }
					)
					Vide.cleanup(function()
						closeTween:Cancel()
						closeTween:Destroy()
					end)
					closeTween:Play()
				end)
			end),

			create("Frame")({
				Name = "Frame",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = function()
					return if matchResult() == "Victory" then VICTORY_THEME else DEFEAT_THEME
				end,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.5, 0.5),
				ZIndex = 50,

				create("UICorner")({
					Name = "UICorner",
					BottomLeftRadius = UDim.new(0.03, 0),
					BottomRightRadius = UDim.new(0.03, 0),
					TopLeftRadius = UDim.new(0.03, 0),
					TopRightRadius = UDim.new(0.03, 0),
				}),

				create("UIGradient")({
					Name = "UIGradient",
					Rotation = 15,
					Offset = spring(function()
						return if resultVisible() then Vector2.new(1.3, 0) else Vector2.new(-1.3, 0)
					end, 0.65, 1),
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 0.994),
						NumberSequenceKeypoint.new(0, 1),
						NumberSequenceKeypoint.new(0.2, 1),
						NumberSequenceKeypoint.new(0.205, 0),
						NumberSequenceKeypoint.new(0.5, 0),
						NumberSequenceKeypoint.new(0.6, 0),
						NumberSequenceKeypoint.new(0.605, 1),
						NumberSequenceKeypoint.new(0.7, 1),
						NumberSequenceKeypoint.new(0.705, 0),
						NumberSequenceKeypoint.new(0.85, 0),
						NumberSequenceKeypoint.new(0.855, 1),
						NumberSequenceKeypoint.new(1, 1),
					}),
				}),
			}),

			create("ImageLabel")({
				Name = "Main",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = "rbxassetid://132288552415911",
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.5, 0.5),

				create("ImageButton")({
					Name = "CancelButton",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = "rbxassetid://92651860309635",
					Rotation = spring(function()
						return if resultVisible() then 0 else -15
					end, 0.5, 0.5),
					ImageTransparency = spring(function()
						return if resultVisible() then 0 else 1
					end, 0.5, 1),
					Position = spring(function()
						return if resultVisible()
							then UDim2.fromScale(0.988679, 0.0157452)
							else UDim2.fromScale(0.97, 0.0157452)
					end, 0.5, 0.75),
					Size = UDim2.fromScale(0.117, 0.209),
					ZIndex = 51,

					useButtonEffect(),
				}),

				create("ImageButton")({
					Name = "ReplayButton",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = "rbxassetid://139274506988816",
					Rotation = spring(function()
						return if resultVisible() then 0 else -5
					end, 0.3, 0.5),
					Position = spring(function()
						return if resultVisible()
							then UDim2.fromScale(0.170833, 0.892807)
							else UDim2.fromScale(0.170833, 0.95)
					end, 0.3, 0.6),
					Size = UDim2.fromScale(0.251227, 0.112709),
					Visible = resultVisible,

					MouseButton1Click = function()
						isVisible(false)
					end,

					create("UICorner")({
						Name = "UICorner",
						BottomLeftRadius = UDim.new(0.2, 0),
						BottomRightRadius = UDim.new(0.2, 0),
						TopLeftRadius = UDim.new(0.2, 0),
						TopRightRadius = UDim.new(0.2, 0),
					}),

					create("TextLabel")({
						Name = "Title",
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
						Position = UDim2.fromScale(0.149276, 0.214464),
						Size = UDim2.fromScale(0.68577, 0.527425),
						Text = "REPLAY",
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,

						create("UIStroke")({
							Name = "UIStroke",
						}),
					}),

					create("UIGradient")({
						Name = "UIGradient",
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(13, 255, 0)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(234, 255, 0)),
						}),
					}),

					useButtonHoverEffect(),
					useButtonEffect(),
				}),

				create("ImageButton")({
					Name = "ExitButton",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = Color3.new(1, 1, 1),
					Image = "rbxassetid://139274506988816",
					Rotation = spring(function()
						return if resultVisible() then 0 else -5
					end, 0.3, 0.5),
					Position = spring(function()
						return if resultVisible()
							then UDim2.fromScale(0.473839, 0.892807)
							else UDim2.fromScale(0.473839, 0.95)
					end, 0.5, 0.6),
					Size = UDim2.fromScale(0.251227, 0.112709),
					Visible = resultVisible,

					MouseButton1Click = function()
						isVisible(false)
					end,

					create("UICorner")({
						Name = "UICorner",
						BottomLeftRadius = UDim.new(0.2, 0),
						BottomRightRadius = UDim.new(0.2, 0),
						TopLeftRadius = UDim.new(0.2, 0),
						TopRightRadius = UDim.new(0.2, 0),
					}),

					create("UIGradient")({
						Name = "UIGradient",
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 67, 60)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 62, 178)),
						}),
					}),

					create("TextLabel")({
						Name = "Title",
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
						Position = UDim2.fromScale(0.149276, 0.214464),
						Size = UDim2.fromScale(0.68577, 0.527425),
						Text = "EXIT",
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,

						create("UIStroke")({
							Name = "UIStroke",
						}),
					}),

					useButtonHoverEffect(),
					useButtonEffect(),
				}),

				create("ImageLabel")({
					Name = "Reward",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = "rbxassetid://107734182158267",
					ImageTransparency = spring(function()
						return if resultVisible() then 0 else 1
					end, 0.5, 1),
					Position = spring(function()
						return if resultVisible()
							then UDim2.fromScale(0.321125, 0.625)
							else UDim2.fromScale(0.25, 0.625)
					end, 0.5, 1),
					Size = spring(function()
						return if isVisible() then UDim2.fromScale(0.595636, 0.354167) else UDim2.fromScale(0.5, 0.15)
					end, 0.5, 0.6),

					create("ScrollingFrame")({
						Name = "ScrollingFrame",
						Active = true,
						BackgroundTransparency = 1,
						CanvasSize = UDim2.fromScale(2, 0),
						Position = UDim2.fromScale(0.0190313, 0.284314),
						ScrollBarImageColor3 = Color3.new(),
						ScrollBarThickness = 0,
						Size = UDim2.fromScale(0.954591, 0.637255),

						create("UIListLayout")({
							Name = "UIListLayout",
							FillDirection = Enum.FillDirection.Horizontal,
							SortOrder = Enum.SortOrder.LayoutOrder,
							VerticalAlignment = Enum.VerticalAlignment.Center,
						}),

						show(function()
							return resultVisible() and read(coins()) ~= 0
						end, function()
							return Slot({
								Name = "Coins",
								LayoutOrder = 1,
								Size = UDim2.fromScale(0.216, 0.967),
								Visible = true,

								AssetType = "Currency",
								AssetProps = {
									CurrencyName = "Coins",
									CurrencyQuantity = coins,
								},
								Rarity = "Coins",
							}),
								0.25
						end),
						show(function()
							return resultVisible() and read(gems()) ~= 0
						end, function()
							return Slot({
								Name = "Gems",
								LayoutOrder = 2,
								Size = UDim2.fromScale(0.216, 0.967),
								Visible = true,

								AssetType = "Currency",
								AssetProps = {
									CurrencyName = "Gems",
									CurrencyQuantity = gems,
								},
								Rarity = "Gems",
							}),
								0.25
						end),
					}),

					create("TextLabel")({
						Name = "Title",
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
						Position = spring(function()
							return if resultVisible()
								then UDim2.fromScale(0.0362293, 0.067405)
								else UDim2.fromScale(0.0362293, 0.2)
						end, 0.5, 1),
						Size = UDim2.fromScale(0.644648, 0.128673),
						Text = "REWARD",
						TextTransparency = spring(function()
							return if resultVisible() then 0 else 1
						end, 0.5, 1),
						TextColor3 = Color3.fromRGB(130, 130, 130),
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						Visible = function()
							return if resultVisible() then true else false
						end,

						create("UIStroke")({
							Name = "UIStroke",
							Transparency = spring(function()
								return if resultVisible() then 0 else 1
							end, 0.5, 1),
						}),
					}),
				}),

				create("ImageLabel")({
					Name = "Background",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = "rbxassetid://107734182158267",
					ImageTransparency = spring(function()
						return if isVisible() then 0 else 1
					end, 0.5, 1),
					Position = UDim2.fromScale(0.323369, 0.243056),
					Size = spring(function()
						return if isVisible() then UDim2.fromScale(0.595636, 0.354167) else UDim2.fromScale(0.5, 0.15)
					end, 0.5, 0.6),

					create("TextLabel")({
						Name = "MapName",
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
						Position = spring(function()
							return if resultVisible()
								then UDim2.fromScale(0.0362293, 0.067405)
								else UDim2.fromScale(0.0362293, 0.2)
						end, 0.5, 0.5),
						Size = UDim2.fromScale(0.644648, 0.128673),
						Text = "Goblin Hut",
						TextTransparency = spring(function()
							return if resultVisible() then 0 else 1
						end, 0.5, 1),
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,

						create("UIStroke")({
							Name = "UIStroke",
							Transparency = spring(function()
								return if resultVisible() then 0 else 1
							end, 0.5, 1),
						}),

						create("UIGradient")({
							Name = "UIGradient",
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(112, 255, 73)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(198, 255, 92)),
							}),
						}),
					}),

					create("TextLabel")({
						Name = "Difficulty",
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
						Position = spring(function()
							return if resultVisible()
								then UDim2.fromScale(0.0362293, 0.194856)
								else UDim2.fromScale(0.0362293, 0.3)
						end, 0.5, 0.5),
						Size = UDim2.fromScale(0.644648, 0.0992617),
						Text = "EASY",
						TextTransparency = spring(function()
							return if resultVisible() then 0 else 1
						end, 0.5, 1),
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,

						create("UIStroke")({
							Name = "UIStroke",
							Transparency = spring(function()
								return if resultVisible() then 0 else 1
							end, 0.5, 1),
						}),

						create("UIGradient")({
							Name = "UIGradient",
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(160, 255, 116)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 237, 34)),
							}),
							Rotation = 90,
						}),
					}),
				}),

				create("UICorner")({
					Name = "UICorner",
					BottomLeftRadius = UDim.new(0.035, 0),
					BottomRightRadius = UDim.new(0.035, 0),
					TopLeftRadius = UDim.new(0.035, 0),
					TopRightRadius = UDim.new(0.035, 0),
				}),

				create("UIShadow")({
					Name = "UIShadow",
					BlurRadius = UDim.new(0.05, 0),
					Color = spring(function()
						if resultVisible() then
							return if matchResult() == "Victory" then VICTORY_THEME else DEFEAT_THEME
						else
							return Color3.new(1, 1, 1)
						end
					end, 0.75, 1),
					Transparency = 0.5,
				}),

				create("UIStroke")({
					Name = "OutlineHider",
					BorderStrokePosition = Enum.BorderStrokePosition.Inner,
					Color = Color3.new(1, 1, 1),
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.015,

					create("UIGradient")({
						Name = "UIGradient",
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(15, 15, 14)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(24, 24, 23)),
						}),
						Rotation = 90,
					}),
				}),

				create("UIStroke")({
					Name = "UIStroke",
					Color = spring(function()
						if resultVisible() then
							return if matchResult() == "Victory" then VICTORY_THEME else DEFEAT_THEME
						else
							return Color3.new(1, 1, 1)
						end
					end, 0.75, 1),
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.008,
				}),

				create("ImageLabel")({
					Name = "Exp",
					AnchorPoint = Vector2.new(1, 0.5),
					BackgroundTransparency = 1,
					Image = "rbxassetid://90940467445281",
					ImageTransparency = spring(function()
						return if resultVisible() then 0 else 1
					end, 0.5, 1),
					Position = spring(function()
						return if resultVisible()
							then UDim2.fromScale(0.98, 0.507661)
							else UDim2.fromScale(1.05, 0.507661)
					end, 0.5, 0.8),
					Size = spring(function()
						return if resultVisible()
							then UDim2.fromScale(0.338564, 0.883377)
							else UDim2.fromScale(0.15, 0.883377)
					end, 0.65, 0.8),

					create("ScrollingFrame")({
						Name = "ScrollingFrame",
						Active = true,
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.0115979, 0.027024),
						ScrollBarImageColor3 = Color3.new(),
						ScrollBarThickness = 0,
						Size = UDim2.fromScale(0.988401, 0.951701),
						Visible = false,

						create("UIListLayout")({
							Name = "UIListLayout",
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							SortOrder = Enum.SortOrder.LayoutOrder,
						}),

						create("ImageLabel")({
							Name = "ImageLabel",
							BackgroundTransparency = 1,
							Image = "rbxassetid://74186256738288",
							Position = UDim2.fromScale(0.0100924, 2.99883e-08),
							Size = UDim2.fromScale(0.979816, 0.112028),

							create("TextLabel")({
								Name = "Level",
								BackgroundTransparency = 1,
								FontFace = Font.new(
									"rbxasset://fonts/families/SourceSansPro.json",
									Enum.FontWeight.Bold,
									Enum.FontStyle.Normal
								),
								Position = UDim2.fromScale(0.422888, 0.0620903),
								Size = UDim2.fromScale(0.5066, 0.288464),
								Text = "LV 10/50",
								TextColor3 = Color3.new(1, 1, 1),
								TextScaled = true,
								TextXAlignment = Enum.TextXAlignment.Left,
								ZIndex = 10,

								create("UIStroke")({
									Name = "UIStroke",
									Thickness = 2,
								}),
							}),

							create("Folder")({
								Name = "ExpBar",

								create("ImageLabel")({
									Name = "barBG",
									AnchorPoint = Vector2.new(0.5, 0.5),
									BackgroundTransparency = 1,
									Image = "rbxassetid://123614945790793",
									Position = UDim2.fromScale(0.691773, 0.803545),
									Size = UDim2.fromScale(0.546449, 0.234954),
								}),

								create("ImageLabel")({
									Name = "barFill",
									AnchorPoint = Vector2.new(0.5, 0.5),
									BackgroundTransparency = 1,
									Image = "rbxassetid://87566142417575",
									Position = UDim2.fromScale(0.691707, 0.798611),
									Size = UDim2.fromScale(0.541475, 0.156028),
									ZIndex = 2,

									create("UIGradient")({
										Name = "UIGradient",
										Color = ColorSequence.new({
											ColorSequenceKeypoint.new(0, Color3.fromRGB(227, 255, 42)),
											ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 159, 42)),
										}),
										Rotation = 90,
									}),
								}),
							}),

							create("TextLabel")({
								Name = "Percentage",
								BackgroundTransparency = 1,
								FontFace = Font.new(
									"rbxasset://fonts/families/SourceSansPro.json",
									Enum.FontWeight.Bold,
									Enum.FontStyle.Normal
								),
								Position = UDim2.fromScale(0.443424, 0.47585),
								Size = UDim2.fromScale(0.5066, 0.208022),
								Text = "100%",
								TextColor3 = Color3.new(1, 1, 1),
								TextScaled = true,
								TextXAlignment = Enum.TextXAlignment.Left,
								ZIndex = 10,

								create("UIStroke")({
									Name = "UIStroke",
									Thickness = 2,
								}),

								create("UIGradient")({
									Name = "UIGradient",
									Color = ColorSequence.new({
										ColorSequenceKeypoint.new(0, Color3.fromRGB(227, 255, 42)),
										ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 159, 42)),
									}),
									Rotation = 90,
								}),
							}),
						}),
					}),
				}),
			}),

			create("ImageLabel")({
				Name = "Cloud",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = "rbxassetid://108731144529861",
				ImageTransparency = spring(function()
					return if isVisible() then 0 else 1
				end, 0.5, 1),
				Position = spring(function()
					return if isVisible() then UDim2.fromScale(0.7, 0.244549) else UDim2.fromScale(0.59, 0.244549)
				end, 0.5, 1),
				Size = UDim2.fromScale(0.223438, 0.137702),
				ZIndex = -1,
			}),

			create("ImageLabel")({
				Name = "Cloud",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = "rbxassetid://121800551940380",
				ImageTransparency = spring(function()
					return if isVisible() then 0 else 1
				end, 0.5, 1),
				Position = spring(function()
					return if isVisible() then UDim2.fromScale(0.324131, 0.706354) else UDim2.fromScale(0.4, 0.706354)
				end, 0.5, 1),
				Size = UDim2.fromScale(0.223438, 0.137702),
				ZIndex = -1,
			}),

			create("UIAspectRatioConstraint")({
				Name = "UIAspectRatioConstraint",
				AspectRatio = 1.78108,
				AspectType = Enum.AspectType.ScaleWithParentSize,
			}),
		})
	end, container)

	local z = 0
	local a = true
	local b = task.spawn(function()
		while a do
			isVisible(not isVisible())
			if z >= 2 then
				matchResult("Defeat")
			else
				matchResult("Victory")
			end

			z += 1
			z %= 4

			task.wait(if isVisible() then 3 else 1)
		end
	end)

	return function()
		a = false
		task.cancel(b)
		if resultEffectTask then
			task.cancel(resultEffectTask)
			resultEffectTask = nil
		end

		destroyVide()
		container:Destroy()
	end
end
