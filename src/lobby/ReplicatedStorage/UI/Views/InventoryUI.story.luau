local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local useButtonEffect = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useButtonEffect)
local NumberUtils = require(ReplicatedStorage.Shared.Modules.Utils.NumberUtils)

local create = Vide.create
local source = Vide.source
local spring = Vide.spring
local mount = Vide.mount

local isVisible = source(false)
local storageCount = source(0)
local selectedDamage = source(0)
local selectedCooldown = source(0)
local selectedRange = source(0)
local selectedMaxTower = source(0)

local function getDecimalPlaces(value: number): number
	local decimalPart = string.format("%.10f", math.abs(value)):match("%.(%d*[1-9])0*$")
	return if decimalPart then #decimalPart else 0
end

local function formatAnimatedStat(animatedValue: number, statValue: number): string
	local decimalPlaces = getDecimalPlaces(statValue)
	local scale = 10 ^ decimalPlaces
	local roundedValue = math.round(animatedValue * scale) / scale

	return NumberUtils.FormatComma(roundedValue)
end

return function(target: Instance)
	local container = Instance.new("Frame")
	container.Name = "SummonUIStoryContainer"
	container.BackgroundColor3 = Color3.fromRGB(0, 0, 255)
	container.Size = UDim2.fromScale(1, 1)
	container.BackgroundTransparency = 1
	container.Parent = target

	local destroyVide = mount(function()
		local animatedCount = spring(storageCount, 0.5, 1)
		local animatedDamage = spring(selectedDamage, 0.5, 1)
		local animatedCooldown = spring(selectedCooldown, 0.5, 1)
		local animatedRange = spring(selectedRange, 0.5, 1)
		local animatedMaxTower = spring(selectedMaxTower, 0.5, 1)

		return create("Frame")({
			Name = "Container",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			Visible = isVisible,

			create("ImageLabel")({
				Name = "Main",
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				Image = "rbxassetid://86505261925755",
				Rotation = spring(function()
					return if isVisible() then 0 else -4
				end, 0.5, 1),
				Position = UDim2.fromScale(0.5, 0.20195),
				Size = spring(function()
					return if isVisible() then UDim2.fromScale(0.721698, 0.668872) else UDim2.fromScale(0.675, 0.668872)
				end, 0.5, 0.5),

				create("ImageLabel")({
					Name = "Header",
					BackgroundTransparency = 1,
					Image = "rbxassetid://79038669500555",
					Position = spring(function()
						return if isVisible()
							then UDim2.fromScale(-0.0573612, -0.111321)
							else UDim2.fromScale(-0.1, -0.111321)
					end, 0.5, 1),
					Size = UDim2.fromScale(0.692821, 0.28349),
					ZIndex = 10,

					create("ImageLabel")({
						Name = "Star",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Image = "rbxassetid://111343804919469",
						Rotation = spring(function()
							return if isVisible() then 0 else -90
						end, 0.5, 0.7),
						Position = UDim2.fromScale(0.133, 0.478),
						Size = spring(function()
							return if isVisible()
								then UDim2.fromScale(0.184974, 0.837933)
								else UDim2.fromScale(0.346017, 1.56746)
						end, 0.5, 0.8),

						create("UIAspectRatioConstraint")({
							Name = "UIAspectRatioConstraint",
						}),
					}),

					create("ImageLabel")({
						Name = "Cloud",
						BackgroundTransparency = 1,
						Image = "rbxassetid://122017999272407",
						ImageTransparency = spring(function()
							return if isVisible() then 0 else 1
						end, 0.5, 1),

						Position = spring(function()
							return if isVisible()
								then UDim2.fromScale(0.529887, 0.0551715)
								else UDim2.fromScale(0.375, 0.0551715)
						end, 0.7, 0.8),
						Size = UDim2.fromScale(0.537766, 1.06417),

						create("UIAspectRatioConstraint")({
							Name = "UIAspectRatioConstraint",
							AspectRatio = 2.16,
						}),
					}),

					create("TextLabel")({
						Name = "Title",
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
						Position = UDim2.fromScale(0.265238, 0.435573),
						Size = UDim2.fromScale(0.283423, 0.290134),
						Text = "INVENTORY",
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						TextTransparency = spring(function()
							return if isVisible() then 0 else 1
						end, 0.5, 1),
					}),

					create("UIAspectRatioConstraint")({
						Name = "UIAspectRatioConstraint",
						AspectRatio = 4.53,
					}),
				}),

				create("Frame")({
					Name = "LeftFrame",
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0.018712, 0.158304),
					Size = UDim2.fromScale(0.596526, 0.803586),

					create("ImageLabel")({
						Name = "Bottom",
						BackgroundTransparency = 1,
						Image = "rbxassetid://101405228511471",
						Position = UDim2.fromScale(-0.00261403, 0.882837),
						Size = UDim2.fromScale(1, 0.117596),

						create("ImageButton")({
							Name = "SellButton",
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							Image = "rbxassetid://76383008324602",
							Position = spring(function()
								return if isVisible() then UDim2.fromScale(0.24, 0.5) else UDim2.fromScale(0.24, 1.2)
							end, 0.35, 0.5),
							Size = UDim2.fromScale(0.251482, 0.782844),

							useButtonEffect(),

							create("TextLabel")({
								Name = "Title",
								BackgroundTransparency = 1,
								FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
								Position = UDim2.fromScale(0.265238, 0.237766),
								Size = UDim2.fromScale(0.467855, 0.487941),
								Text = "SELL",
								TextColor3 = Color3.new(1, 1, 1),
								TextScaled = true,
							}),
						}),

						create("ImageButton")({
							Name = "LockButton",
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							Image = "rbxassetid://70564113534462",
							Position = spring(function()
								return if isVisible() then UDim2.fromScale(0.5, 0.5) else UDim2.fromScale(0.5, 1.4)
							end, 0.5, 0.5),
							Size = UDim2.fromScale(0.251482, 0.782844),

							useButtonEffect(),

							create("TextLabel")({
								Name = "Title",
								BackgroundTransparency = 1,
								FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
								Position = UDim2.fromScale(0.265238, 0.237766),
								Size = UDim2.fromScale(0.467855, 0.487941),
								Text = "LOCK",
								TextColor3 = Color3.new(1, 1, 1),
								TextScaled = true,
							}),
						}),

						create("ImageButton")({
							Name = "SortButton",
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							Image = "rbxassetid://128977854458302",
							Position = spring(function()
								return if isVisible() then UDim2.fromScale(0.76, 0.5) else UDim2.fromScale(0.76, 1.6)
							end, 0.65, 0.5),
							Size = UDim2.fromScale(0.251482, 0.782844),

							useButtonEffect(),

							create("TextLabel")({
								Name = "Title",
								BackgroundTransparency = 1,
								FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
								Position = UDim2.fromScale(0.234055, 0.237766),
								Size = UDim2.fromScale(0.734762, 0.487942),
								Text = "SORT : RARITY",
								TextColor3 = Color3.new(1, 1, 1),
								TextScaled = true,
							}),
						}),
					}),

					create("ScrollingFrame")({
						Name = "ScrollingFrame",
						Active = true,
						BackgroundTransparency = 1,
						Position = spring(function()
							return if isVisible()
								then UDim2.fromScale(0.0339824, 0.124035)
								else UDim2.fromScale(0, 0.124035)
						end, 0.5, 1),
						ScrollBarImageColor3 = Color3.new(),
						ScrollBarThickness = 0,
						Size = UDim2.fromScale(0.966018, 0.758802),

						create("UIGridLayout")({
							Name = "UIGridLayout",
							CellPadding = spring(function()
								return if isVisible() then UDim2.fromScale(0.01, 0.01) else UDim2.fromScale(-0.01, 0.01)
							end, 0.5, 1),
							CellSize = UDim2.fromScale(0.186, 0.125),
							SortOrder = Enum.SortOrder.LayoutOrder,
						}),

						create("ImageButton")({
							Name = "ImageButton",
							BackgroundTransparency = 1,
							Image = "rbxassetid://87496848270095",
							ImageTransparency = spring(function()
								return if isVisible() then 0 else 1
							end, 0.5, 1),

							LayoutOrder = 6,
							Position = UDim2.fromScale(0.830332, 0.0325001),
							Size = UDim2.fromScale(0.186, 0.125),

							create("UICorner")({
								CornerRadius = UDim.new(0.08),
							}),

							create("Frame")({
								Name = "SelectedEffect",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								Size = UDim2.fromScale(0.95, 0.95),
								Position = UDim2.fromScale(0.5, 0.5),

								create("UICorner")({
									CornerRadius = UDim.new(0.08),
								}),

								create("UIStroke")({
									Color = Color3.new(1, 1, 1),
									Thickness = 2.5,
								}),
							}),
							create("UIShadow")({
								BlurRadius = UDim.new(0.075),
								Color = Color3.new(1, 1, 1),
								Transparency = 0.2,
								ZIndex = -1,
							}),

							create("TextLabel")({
								Name = "Name",
								BackgroundTransparency = 1,
								FontFace = Font.new(
									"rbxasset://fonts/families/SourceSansPro.json",
									Enum.FontWeight.Bold,
									Enum.FontStyle.Normal
								),
								Position = UDim2.fromScale(0.107999, 0.618754),
								Size = UDim2.fromScale(0.84887, 0.172688),
								Text = "메카 어니언",
								TextColor3 = Color3.new(1, 1, 1),
								TextScaled = true,
								TextXAlignment = Enum.TextXAlignment.Left,
								ZIndex = 10,

								create("UIStroke")({
									Name = "UIStroke",
									Thickness = 2,
								}),
							}),

							create("ViewportFrame")({
								Name = "ViewportFrame",
								BackgroundTransparency = 1,
								Position = UDim2.fromScale(0.11, 0.102),
								Size = UDim2.fromScale(0.784, 0.781),
								ZIndex = 5,
							}),

							create("CanvasGroup")({
								Name = "CanvasGroup",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								Position = UDim2.fromScale(0.489217, 0.489218),
								Size = UDim2.fromScale(0.935304, 0.935304),

								create("LocalScript")({
									Name = "LocalScript",
								}),
							}),

							create("UIAspectRatioConstraint")({
								Name = "UIAspectRatioConstraint",
							}),

							create("ImageLabel")({
								Name = "Level",
								BackgroundTransparency = 1,
								Image = "rbxassetid://104083646922843",
								Position = UDim2.fromScale(-0.0129994, -0.05),
								Size = UDim2.fromScale(0.653434, 0.238322),
								ZIndex = 10,

								create("UIAspectRatioConstraint")({
									Name = "UIAspectRatioConstraint",
									AspectRatio = 3.2,
								}),

								create("TextLabel")({
									Name = "TextLabel",
									AnchorPoint = Vector2.new(0.5, 0.5),
									BackgroundTransparency = 1,
									FontFace = Font.new(
										"rbxasset://fonts/families/SourceSansPro.json",
										Enum.FontWeight.Bold,
										Enum.FontStyle.Normal
									),
									Position = UDim2.fromScale(0.3, 0.489),
									Size = UDim2.fromScale(0.477775, 0.75514),
									Text = "레벨 1",
									TextColor3 = Color3.new(1, 1, 1),
									TextScaled = true,

									create("UIStroke")({
										Name = "UIStroke",
										Thickness = 2,
									}),

									create("UIGradient")({
										Name = "UIGradient",
										Color = ColorSequence.new({
											ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
											ColorSequenceKeypoint.new(1, Color3.fromRGB(104, 106, 211)),
										}),
										Rotation = 90,
									}),
								}),
							}),

							create("ImageLabel")({
								Name = "Trait",
								BackgroundTransparency = 1,
								Image = "rbxassetid://100463457721493",
								Position = UDim2.fromScale(0.64, 0.03),
								Size = UDim2.fromScale(0.359565, 0.31687),

								create("UIAspectRatioConstraint")({
									Name = "UIAspectRatioConstraint",
								}),
							}),

							create("TextLabel")({
								Name = "Price",
								BackgroundTransparency = 1,
								FontFace = Font.new(
									"rbxasset://fonts/families/SourceSansPro.json",
									Enum.FontWeight.Bold,
									Enum.FontStyle.Normal
								),
								Position = UDim2.fromScale(0.108, 0.782623),
								Size = UDim2.fromScale(0.641, 0.2),
								Text = "₩100",
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
										ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 152, 62)),
										ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 160, 26)),
									}),
									Rotation = 90,
								}),
							}),

							create("UIGradient")({
								Name = "UIGradient",
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(154, 0, 5)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 0, 4)),
								}),
								Rotation = 45,
							}),
						}),
						create("ImageButton")({
							Name = "ImageButton",
							BackgroundTransparency = 1,
							Image = "rbxassetid://87496848270095",
							ImageTransparency = spring(function()
								return if isVisible() then 0 else 1
							end, 0.5, 1),

							LayoutOrder = 6,
							Position = UDim2.fromScale(0.830332, 0.0325001),
							Size = UDim2.fromScale(0.186, 0.125),

							create("TextLabel")({
								Name = "Name",
								BackgroundTransparency = 1,
								FontFace = Font.new(
									"rbxasset://fonts/families/SourceSansPro.json",
									Enum.FontWeight.Bold,
									Enum.FontStyle.Normal
								),
								Position = UDim2.fromScale(0.107999, 0.618754),
								Size = UDim2.fromScale(0.84887, 0.172688),
								Text = "메카 어니언",
								TextColor3 = Color3.new(1, 1, 1),
								TextScaled = true,
								TextXAlignment = Enum.TextXAlignment.Left,
								ZIndex = 10,

								create("UIStroke")({
									Name = "UIStroke",
									Thickness = 2,
								}),
							}),

							create("ViewportFrame")({
								Name = "ViewportFrame",
								BackgroundTransparency = 1,
								Position = UDim2.fromScale(0.11, 0.102),
								Size = UDim2.fromScale(0.784, 0.781),
								ZIndex = 5,
							}),

							create("CanvasGroup")({
								Name = "CanvasGroup",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								Position = UDim2.fromScale(0.489217, 0.489218),
								Size = UDim2.fromScale(0.935304, 0.935304),

								create("LocalScript")({
									Name = "LocalScript",
								}),
							}),

							create("UIAspectRatioConstraint")({
								Name = "UIAspectRatioConstraint",
							}),

							create("ImageLabel")({
								Name = "Level",
								BackgroundTransparency = 1,
								Image = "rbxassetid://104083646922843",
								Position = UDim2.fromScale(-0.0129994, -0.05),
								Size = UDim2.fromScale(0.653434, 0.238322),
								ZIndex = 10,

								create("UIAspectRatioConstraint")({
									Name = "UIAspectRatioConstraint",
									AspectRatio = 3.2,
								}),

								create("TextLabel")({
									Name = "TextLabel",
									AnchorPoint = Vector2.new(0.5, 0.5),
									BackgroundTransparency = 1,
									FontFace = Font.new(
										"rbxasset://fonts/families/SourceSansPro.json",
										Enum.FontWeight.Bold,
										Enum.FontStyle.Normal
									),
									Position = UDim2.fromScale(0.3, 0.489),
									Size = UDim2.fromScale(0.477775, 0.75514),
									Text = "레벨 1",
									TextColor3 = Color3.new(1, 1, 1),
									TextScaled = true,

									create("UIStroke")({
										Name = "UIStroke",
										Thickness = 2,
									}),

									create("UIGradient")({
										Name = "UIGradient",
										Color = ColorSequence.new({
											ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
											ColorSequenceKeypoint.new(1, Color3.fromRGB(104, 106, 211)),
										}),
										Rotation = 90,
									}),
								}),
							}),

							create("ImageLabel")({
								Name = "Trait",
								BackgroundTransparency = 1,
								Image = "rbxassetid://100463457721493",
								Position = UDim2.fromScale(0.64, 0.03),
								Size = UDim2.fromScale(0.359565, 0.31687),

								create("UIAspectRatioConstraint")({
									Name = "UIAspectRatioConstraint",
								}),
							}),

							create("TextLabel")({
								Name = "Price",
								BackgroundTransparency = 1,
								FontFace = Font.new(
									"rbxasset://fonts/families/SourceSansPro.json",
									Enum.FontWeight.Bold,
									Enum.FontStyle.Normal
								),
								Position = UDim2.fromScale(0.108, 0.782623),
								Size = UDim2.fromScale(0.641, 0.2),
								Text = "₩100",
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
										ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 152, 62)),
										ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 160, 26)),
									}),
									Rotation = 90,
								}),
							}),

							create("UIGradient")({
								Name = "UIGradient",
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(154, 0, 5)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 0, 4)),
								}),
								Rotation = 45,
							}),
						}),
						create("ImageButton")({
							Name = "ImageButton",
							BackgroundTransparency = 1,
							Image = "rbxassetid://87496848270095",
							ImageTransparency = spring(function()
								return if isVisible() then 0 else 1
							end, 0.5, 1),

							LayoutOrder = 6,
							Position = UDim2.fromScale(0.830332, 0.0325001),
							Size = UDim2.fromScale(0.186, 0.125),

							create("TextLabel")({
								Name = "Name",
								BackgroundTransparency = 1,
								FontFace = Font.new(
									"rbxasset://fonts/families/SourceSansPro.json",
									Enum.FontWeight.Bold,
									Enum.FontStyle.Normal
								),
								Position = UDim2.fromScale(0.107999, 0.618754),
								Size = UDim2.fromScale(0.84887, 0.172688),
								Text = "메카 어니언",
								TextColor3 = Color3.new(1, 1, 1),
								TextScaled = true,
								TextXAlignment = Enum.TextXAlignment.Left,
								ZIndex = 10,

								create("UIStroke")({
									Name = "UIStroke",
									Thickness = 2,
								}),
							}),

							create("ViewportFrame")({
								Name = "ViewportFrame",
								BackgroundTransparency = 1,
								Position = UDim2.fromScale(0.11, 0.102),
								Size = UDim2.fromScale(0.784, 0.781),
								ZIndex = 5,
							}),

							create("CanvasGroup")({
								Name = "CanvasGroup",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								Position = UDim2.fromScale(0.489217, 0.489218),
								Size = UDim2.fromScale(0.935304, 0.935304),

								create("LocalScript")({
									Name = "LocalScript",
								}),
							}),

							create("UIAspectRatioConstraint")({
								Name = "UIAspectRatioConstraint",
							}),

							create("ImageLabel")({
								Name = "Level",
								BackgroundTransparency = 1,
								Image = "rbxassetid://104083646922843",
								Position = UDim2.fromScale(-0.0129994, -0.05),
								Size = UDim2.fromScale(0.653434, 0.238322),
								ZIndex = 10,

								create("UIAspectRatioConstraint")({
									Name = "UIAspectRatioConstraint",
									AspectRatio = 3.2,
								}),

								create("TextLabel")({
									Name = "TextLabel",
									AnchorPoint = Vector2.new(0.5, 0.5),
									BackgroundTransparency = 1,
									FontFace = Font.new(
										"rbxasset://fonts/families/SourceSansPro.json",
										Enum.FontWeight.Bold,
										Enum.FontStyle.Normal
									),
									Position = UDim2.fromScale(0.3, 0.489),
									Size = UDim2.fromScale(0.477775, 0.75514),
									Text = "레벨 1",
									TextColor3 = Color3.new(1, 1, 1),
									TextScaled = true,

									create("UIStroke")({
										Name = "UIStroke",
										Thickness = 2,
									}),

									create("UIGradient")({
										Name = "UIGradient",
										Color = ColorSequence.new({
											ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
											ColorSequenceKeypoint.new(1, Color3.fromRGB(104, 106, 211)),
										}),
										Rotation = 90,
									}),
								}),
							}),

							create("ImageLabel")({
								Name = "Trait",
								BackgroundTransparency = 1,
								Image = "rbxassetid://100463457721493",
								Position = UDim2.fromScale(0.64, 0.03),
								Size = UDim2.fromScale(0.359565, 0.31687),

								create("UIAspectRatioConstraint")({
									Name = "UIAspectRatioConstraint",
								}),
							}),

							create("TextLabel")({
								Name = "Price",
								BackgroundTransparency = 1,
								FontFace = Font.new(
									"rbxasset://fonts/families/SourceSansPro.json",
									Enum.FontWeight.Bold,
									Enum.FontStyle.Normal
								),
								Position = UDim2.fromScale(0.108, 0.782623),
								Size = UDim2.fromScale(0.641, 0.2),
								Text = "₩100",
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
										ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 152, 62)),
										ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 160, 26)),
									}),
									Rotation = 90,
								}),
							}),

							create("UIGradient")({
								Name = "UIGradient",
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(154, 0, 5)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 0, 4)),
								}),
								Rotation = 45,
							}),
						}),
						create("ImageButton")({
							Name = "ImageButton",
							BackgroundTransparency = 1,
							Image = "rbxassetid://87496848270095",
							ImageTransparency = spring(function()
								return if isVisible() then 0 else 1
							end, 0.5, 1),

							LayoutOrder = 6,
							Position = UDim2.fromScale(0.830332, 0.0325001),
							Size = UDim2.fromScale(0.186, 0.125),

							create("TextLabel")({
								Name = "Name",
								BackgroundTransparency = 1,
								FontFace = Font.new(
									"rbxasset://fonts/families/SourceSansPro.json",
									Enum.FontWeight.Bold,
									Enum.FontStyle.Normal
								),
								Position = UDim2.fromScale(0.107999, 0.618754),
								Size = UDim2.fromScale(0.84887, 0.172688),
								Text = "메카 어니언",
								TextColor3 = Color3.new(1, 1, 1),
								TextScaled = true,
								TextXAlignment = Enum.TextXAlignment.Left,
								ZIndex = 10,

								create("UIStroke")({
									Name = "UIStroke",
									Thickness = 2,
								}),
							}),

							create("ViewportFrame")({
								Name = "ViewportFrame",
								BackgroundTransparency = 1,
								Position = UDim2.fromScale(0.11, 0.102),
								Size = UDim2.fromScale(0.784, 0.781),
								ZIndex = 5,
							}),

							create("CanvasGroup")({
								Name = "CanvasGroup",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								Position = UDim2.fromScale(0.489217, 0.489218),
								Size = UDim2.fromScale(0.935304, 0.935304),

								create("LocalScript")({
									Name = "LocalScript",
								}),
							}),

							create("UIAspectRatioConstraint")({
								Name = "UIAspectRatioConstraint",
							}),

							create("ImageLabel")({
								Name = "Level",
								BackgroundTransparency = 1,
								Image = "rbxassetid://104083646922843",
								Position = UDim2.fromScale(-0.0129994, -0.05),
								Size = UDim2.fromScale(0.653434, 0.238322),
								ZIndex = 10,

								create("UIAspectRatioConstraint")({
									Name = "UIAspectRatioConstraint",
									AspectRatio = 3.2,
								}),

								create("TextLabel")({
									Name = "TextLabel",
									AnchorPoint = Vector2.new(0.5, 0.5),
									BackgroundTransparency = 1,
									FontFace = Font.new(
										"rbxasset://fonts/families/SourceSansPro.json",
										Enum.FontWeight.Bold,
										Enum.FontStyle.Normal
									),
									Position = UDim2.fromScale(0.3, 0.489),
									Size = UDim2.fromScale(0.477775, 0.75514),
									Text = "레벨 1",
									TextColor3 = Color3.new(1, 1, 1),
									TextScaled = true,

									create("UIStroke")({
										Name = "UIStroke",
										Thickness = 2,
									}),

									create("UIGradient")({
										Name = "UIGradient",
										Color = ColorSequence.new({
											ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
											ColorSequenceKeypoint.new(1, Color3.fromRGB(104, 106, 211)),
										}),
										Rotation = 90,
									}),
								}),
							}),

							create("ImageLabel")({
								Name = "Trait",
								BackgroundTransparency = 1,
								Image = "rbxassetid://100463457721493",
								Position = UDim2.fromScale(0.64, 0.03),
								Size = UDim2.fromScale(0.359565, 0.31687),

								create("UIAspectRatioConstraint")({
									Name = "UIAspectRatioConstraint",
								}),
							}),

							create("TextLabel")({
								Name = "Price",
								BackgroundTransparency = 1,
								FontFace = Font.new(
									"rbxasset://fonts/families/SourceSansPro.json",
									Enum.FontWeight.Bold,
									Enum.FontStyle.Normal
								),
								Position = UDim2.fromScale(0.108, 0.782623),
								Size = UDim2.fromScale(0.641, 0.2),
								Text = "₩100",
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
										ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 152, 62)),
										ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 160, 26)),
									}),
									Rotation = 90,
								}),
							}),

							create("UIGradient")({
								Name = "UIGradient",
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(154, 0, 5)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 0, 4)),
								}),
								Rotation = 45,
							}),
						}),
						create("ImageButton")({
							Name = "ImageButton",
							BackgroundTransparency = 1,
							Image = "rbxassetid://87496848270095",
							ImageTransparency = spring(function()
								return if isVisible() then 0 else 1
							end, 0.5, 1),

							LayoutOrder = 6,
							Position = UDim2.fromScale(0.830332, 0.0325001),
							Size = UDim2.fromScale(0.186, 0.125),

							create("TextLabel")({
								Name = "Name",
								BackgroundTransparency = 1,
								FontFace = Font.new(
									"rbxasset://fonts/families/SourceSansPro.json",
									Enum.FontWeight.Bold,
									Enum.FontStyle.Normal
								),
								Position = UDim2.fromScale(0.107999, 0.618754),
								Size = UDim2.fromScale(0.84887, 0.172688),
								Text = "메카 어니언",
								TextColor3 = Color3.new(1, 1, 1),
								TextScaled = true,
								TextXAlignment = Enum.TextXAlignment.Left,
								ZIndex = 10,

								create("UIStroke")({
									Name = "UIStroke",
									Thickness = 2,
								}),
							}),

							create("ViewportFrame")({
								Name = "ViewportFrame",
								BackgroundTransparency = 1,
								Position = UDim2.fromScale(0.11, 0.102),
								Size = UDim2.fromScale(0.784, 0.781),
								ZIndex = 5,
							}),

							create("CanvasGroup")({
								Name = "CanvasGroup",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								Position = UDim2.fromScale(0.489217, 0.489218),
								Size = UDim2.fromScale(0.935304, 0.935304),

								create("LocalScript")({
									Name = "LocalScript",
								}),
							}),

							create("UIAspectRatioConstraint")({
								Name = "UIAspectRatioConstraint",
							}),

							create("ImageLabel")({
								Name = "Level",
								BackgroundTransparency = 1,
								Image = "rbxassetid://104083646922843",
								Position = UDim2.fromScale(-0.0129994, -0.05),
								Size = UDim2.fromScale(0.653434, 0.238322),
								ZIndex = 10,

								create("UIAspectRatioConstraint")({
									Name = "UIAspectRatioConstraint",
									AspectRatio = 3.2,
								}),

								create("TextLabel")({
									Name = "TextLabel",
									AnchorPoint = Vector2.new(0.5, 0.5),
									BackgroundTransparency = 1,
									FontFace = Font.new(
										"rbxasset://fonts/families/SourceSansPro.json",
										Enum.FontWeight.Bold,
										Enum.FontStyle.Normal
									),
									Position = UDim2.fromScale(0.3, 0.489),
									Size = UDim2.fromScale(0.477775, 0.75514),
									Text = "레벨 1",
									TextColor3 = Color3.new(1, 1, 1),
									TextScaled = true,

									create("UIStroke")({
										Name = "UIStroke",
										Thickness = 2,
									}),

									create("UIGradient")({
										Name = "UIGradient",
										Color = ColorSequence.new({
											ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
											ColorSequenceKeypoint.new(1, Color3.fromRGB(104, 106, 211)),
										}),
										Rotation = 90,
									}),
								}),
							}),

							create("ImageLabel")({
								Name = "Trait",
								BackgroundTransparency = 1,
								Image = "rbxassetid://100463457721493",
								Position = UDim2.fromScale(0.64, 0.03),
								Size = UDim2.fromScale(0.359565, 0.31687),

								create("UIAspectRatioConstraint")({
									Name = "UIAspectRatioConstraint",
								}),
							}),

							create("TextLabel")({
								Name = "Price",
								BackgroundTransparency = 1,
								FontFace = Font.new(
									"rbxasset://fonts/families/SourceSansPro.json",
									Enum.FontWeight.Bold,
									Enum.FontStyle.Normal
								),
								Position = UDim2.fromScale(0.108, 0.782623),
								Size = UDim2.fromScale(0.641, 0.2),
								Text = "₩100",
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
										ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 152, 62)),
										ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 160, 26)),
									}),
									Rotation = 90,
								}),
							}),

							create("UIGradient")({
								Name = "UIGradient",
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(154, 0, 5)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 0, 4)),
								}),
								Rotation = 45,
							}),
						}),
						create("ImageButton")({
							Name = "ImageButton",
							BackgroundTransparency = 1,
							Image = "rbxassetid://87496848270095",
							ImageTransparency = spring(function()
								return if isVisible() then 0 else 1
							end, 0.5, 1),

							LayoutOrder = 6,
							Position = UDim2.fromScale(0.830332, 0.0325001),
							Size = UDim2.fromScale(0.186, 0.125),

							create("TextLabel")({
								Name = "Name",
								BackgroundTransparency = 1,
								FontFace = Font.new(
									"rbxasset://fonts/families/SourceSansPro.json",
									Enum.FontWeight.Bold,
									Enum.FontStyle.Normal
								),
								Position = UDim2.fromScale(0.107999, 0.618754),
								Size = UDim2.fromScale(0.84887, 0.172688),
								Text = "메카 어니언",
								TextColor3 = Color3.new(1, 1, 1),
								TextScaled = true,
								TextXAlignment = Enum.TextXAlignment.Left,
								ZIndex = 10,

								create("UIStroke")({
									Name = "UIStroke",
									Thickness = 2,
								}),
							}),

							create("ViewportFrame")({
								Name = "ViewportFrame",
								BackgroundTransparency = 1,
								Position = UDim2.fromScale(0.11, 0.102),
								Size = UDim2.fromScale(0.784, 0.781),
								ZIndex = 5,
							}),

							create("CanvasGroup")({
								Name = "CanvasGroup",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								Position = UDim2.fromScale(0.489217, 0.489218),
								Size = UDim2.fromScale(0.935304, 0.935304),

								create("LocalScript")({
									Name = "LocalScript",
								}),
							}),

							create("UIAspectRatioConstraint")({
								Name = "UIAspectRatioConstraint",
							}),

							create("ImageLabel")({
								Name = "Level",
								BackgroundTransparency = 1,
								Image = "rbxassetid://104083646922843",
								Position = UDim2.fromScale(-0.0129994, -0.05),
								Size = UDim2.fromScale(0.653434, 0.238322),
								ZIndex = 10,

								create("UIAspectRatioConstraint")({
									Name = "UIAspectRatioConstraint",
									AspectRatio = 3.2,
								}),

								create("TextLabel")({
									Name = "TextLabel",
									AnchorPoint = Vector2.new(0.5, 0.5),
									BackgroundTransparency = 1,
									FontFace = Font.new(
										"rbxasset://fonts/families/SourceSansPro.json",
										Enum.FontWeight.Bold,
										Enum.FontStyle.Normal
									),
									Position = UDim2.fromScale(0.3, 0.489),
									Size = UDim2.fromScale(0.477775, 0.75514),
									Text = "레벨 1",
									TextColor3 = Color3.new(1, 1, 1),
									TextScaled = true,

									create("UIStroke")({
										Name = "UIStroke",
										Thickness = 2,
									}),

									create("UIGradient")({
										Name = "UIGradient",
										Color = ColorSequence.new({
											ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
											ColorSequenceKeypoint.new(1, Color3.fromRGB(104, 106, 211)),
										}),
										Rotation = 90,
									}),
								}),
							}),

							create("ImageLabel")({
								Name = "Trait",
								BackgroundTransparency = 1,
								Image = "rbxassetid://100463457721493",
								Position = UDim2.fromScale(0.64, 0.03),
								Size = UDim2.fromScale(0.359565, 0.31687),

								create("UIAspectRatioConstraint")({
									Name = "UIAspectRatioConstraint",
								}),
							}),

							create("TextLabel")({
								Name = "Price",
								BackgroundTransparency = 1,
								FontFace = Font.new(
									"rbxasset://fonts/families/SourceSansPro.json",
									Enum.FontWeight.Bold,
									Enum.FontStyle.Normal
								),
								Position = UDim2.fromScale(0.108, 0.782623),
								Size = UDim2.fromScale(0.641, 0.2),
								Text = "₩100",
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
										ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 152, 62)),
										ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 160, 26)),
									}),
									Rotation = 90,
								}),
							}),

							create("UIGradient")({
								Name = "UIGradient",
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(154, 0, 5)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 0, 4)),
								}),
								Rotation = 45,
							}),
						}),
					}),

					create("ImageButton")({
						Name = "SearchButton",
						BackgroundTransparency = 1,
						Image = "rbxassetid://97005389138079",
						LayoutOrder = 6,
						Position = UDim2.fromScale(0.033053, 0.0172543),
						Size = UDim2.fromScale(0.0794115, 0.0921883),

						create("UIAspectRatioConstraint")({
							Name = "UIAspectRatioConstraint",
						}),
					}),

					create("ImageLabel")({
						Name = "SearchBox",
						BackgroundTransparency = 1,
						Image = "rbxassetid://102610083488834",
						Position = UDim2.fromScale(0.123512, 0.0172543),
						Size = spring(function()
							return if isVisible()
								then UDim2.fromScale(0.702835, 0.0921883)
								else UDim2.fromScale(0, 0.0921883)
						end, 0.5, 0.9),

						create("TextBox")({
							Name = "TextBox",
							BackgroundTransparency = 1,
							FontFace = Font.new(
								"rbxasset://fonts/families/FredokaOne.json",
								Enum.FontWeight.Bold,
								Enum.FontStyle.Normal
							),
							Position = UDim2.fromScale(0.0363427, 0),
							Size = UDim2.fromScale(0.963657, 1),
							PlaceholderText = "TOWER NAME",
							TextColor3 = Color3.new(1, 1, 1),
							TextSize = 22,
							TextXAlignment = Enum.TextXAlignment.Left,

							create("UITextSizeConstraint")({
								Name = "UITextSizeConstraint",
								MaxTextSize = 30,
							}),

							create("UIGradient")({
								Name = "UIGradient",
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(27, 18, 98)),
								}),
								Rotation = 90,
							}),
						}),
					}),

					create("ImageLabel")({
						Name = "InventoryLimit",
						BackgroundTransparency = 1,
						Image = "rbxassetid://92189379920788",
						Position = UDim2.fromScale(0.844985, 0.0172543),
						Size = UDim2.fromScale(0.133909, 0.0921883),

						create("TextLabel")({
							Name = "Title",
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
							Position = UDim2.fromScale(0.5, 0.5),
							Size = UDim2.fromScale(0.843832, 0.543318),
							Text = function()
								return `{math.round(animatedCount())}/100`
							end,
							TextColor3 = Color3.new(1, 1, 1),
							TextScaled = true,

							create("UIGradient")({
								Name = "UIGradient",
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(29, 37, 85)),
								}),
								Rotation = 90,
							}),

							create("UIStroke")({
								Name = "UIStroke",
							}),
						}),
					}),

					create("ImageLabel")({
						Name = "Shadow",
						BackgroundTransparency = 1,
						Image = "rbxassetid://78891351891737",
						Position = UDim2.fromScale(0.0130701, 0.671846),
						Size = UDim2.fromScale(0.965823, 0.211848),
					}),
				}),

				create("ImageLabel")({
					Name = "Avatar",
					BackgroundTransparency = 1,
					Image = "rbxassetid://121523581447419",
					Position = spring(function()
						return if isVisible()
							then UDim2.fromScale(0.596001, 0.170108)
							else UDim2.fromScale(0.625, 0.170108)
					end, 0.4, 0.5),
					Size = spring(function()
						return if isVisible()
							then UDim2.fromScale(0.382446, 0.697631)
							else UDim2.fromScale(0.425, 0.697631)
					end, 0.4, 0.5),
					ZIndex = 10,

					create("UIGradient")({
						Name = "UIGradient",
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 100, 100)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 3, 4)),
						}),
						Rotation = 90,
					}),

					create("ImageLabel")({
						Name = "Damage",
						BackgroundTransparency = 1,
						Image = "rbxassetid://91726020798265",
						Position = UDim2.fromScale(0.0743812, 0.865685),
						Size = UDim2.fromScale(0.287129, 0.130411),

						create("TextLabel")({
							Name = "Tag",
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
							Position = UDim2.fromScale(0.75, 0.5),
							Size = UDim2.fromScale(0.843832, 0.543318),
							Text = function()
								return formatAnimatedStat(animatedDamage(), selectedDamage())
							end,
							TextColor3 = Color3.new(1, 1, 1),
							TextScaled = true,
							TextXAlignment = Enum.TextXAlignment.Left,

							create("UIStroke")({
								Name = "UIStroke",
							}),
						}),
					}),

					create("ImageLabel")({
						Name = "Rng",
						BackgroundTransparency = 1,
						Image = "rbxassetid://77164215386840",
						Position = UDim2.fromScale(0.355713, 0.865685),
						Size = UDim2.fromScale(0.287129, 0.130411),

						create("TextLabel")({
							Name = "Tag",
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
							Position = UDim2.fromScale(0.75, 0.5),
							Size = UDim2.fromScale(0.843832, 0.543318),
							Text = function()
								return formatAnimatedStat(animatedRange(), selectedRange())
							end,
							TextColor3 = Color3.new(1, 1, 1),
							TextScaled = true,
							TextXAlignment = Enum.TextXAlignment.Left,

							create("UIStroke")({
								Name = "UIStroke",
							}),
						}),
					}),

					create("ImageLabel")({
						Name = "Cooldown",
						BackgroundTransparency = 1,
						Image = "rbxassetid://117790979554827",
						Position = UDim2.fromScale(0.641121, 0.865685),
						Size = UDim2.fromScale(0.287129, 0.130411),

						create("TextLabel")({
							Name = "Tag",
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
							Position = UDim2.fromScale(0.75, 0.5),
							Size = UDim2.fromScale(0.843832, 0.543318),
							Text = function()
								return formatAnimatedStat(animatedCooldown(), selectedCooldown())
							end,
							TextColor3 = Color3.new(1, 1, 1),
							TextScaled = true,
							TextXAlignment = Enum.TextXAlignment.Left,

							create("UIStroke")({
								Name = "UIStroke",
							}),
						}),
					}),

					create("ImageLabel")({
						Name = "LevelBG",
						BackgroundTransparency = 1,
						Image = "rbxassetid://111497714681866",
						Position = UDim2.fromScale(0.0927249, 0.819462),
						Size = UDim2.fromScale(0.813106, 0.0421658),

						create("UIGradient")({
							Name = "UIGradient",
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(44, 36, 28)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(44, 36, 28)),
							}),
						}),
					}),

					create("ImageLabel")({
						Name = "LevelFill",
						BackgroundTransparency = 1,
						Image = "rbxassetid://111497714681866",
						Position = UDim2.fromScale(0.0927249, 0.819462),
						Size = UDim2.fromScale(0.813106, 0.0421658),

						create("TextLabel")({
							Name = "Tag",
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
							Position = UDim2.fromScale(0.48102, 0.39498),
							Size = UDim2.fromScale(0.843832, 1),
							Text = "LV.10(1/100xp)",
							TextColor3 = Color3.new(1, 1, 1),
							TextScaled = true,

							create("UIStroke")({
								Name = "UIStroke",
							}),
						}),

						create("UIGradient")({
							Name = "UIGradient",
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(147, 120, 12)),
								ColorSequenceKeypoint.new(0.494898, Color3.fromRGB(251, 255, 0)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(254, 255, 203)),
							}),
						}),
					}),

					create("ImageLabel")({
						Name = "MaximumPlacement",
						BackgroundTransparency = 1,
						Image = "rbxassetid://99625316186918",
						Position = UDim2.fromScale(0.0866135, 0.719145),
						Size = UDim2.fromScale(0.207609, 0.0877106),

						create("TextLabel")({
							Name = "Tag",
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
							Position = UDim2.fromScale(0.8, 0.52),
							Size = UDim2.fromScale(0.843832, 0.672881),
							Text = function()
								return formatAnimatedStat(animatedMaxTower(), selectedMaxTower())
							end,
							TextColor3 = Color3.new(1, 1, 1),
							TextScaled = true,
							TextXAlignment = Enum.TextXAlignment.Left,

							create("UIStroke")({
								Name = "UIStroke",
							}),
						}),
					}),

					create("ImageButton")({
						Name = "SkinButton",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Image = "rbxassetid://114347652939958",
						Position = UDim2.fromScale(0.85117, 0.732566),
						Size = UDim2.fromScale(0.186781, 0.168732),

						create("UIAspectRatioConstraint")({
							Name = "UIAspectRatioConstraint",
						}),

						create("TextLabel")({
							Name = "Tag",
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
							Position = UDim2.fromScale(0.498106, 0.825253),
							Size = UDim2.fromScale(0.721342, 0.344584),
							Text = "skin",
							TextColor3 = Color3.new(1, 1, 1),
							TextScaled = true,

							create("UIStroke")({
								Name = "UIStroke",
							}),
						}),
					}),

					create("TextLabel")({
						Name = "Name",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
						Position = UDim2.fromScale(0.49695, 0.147478),
						Size = UDim2.fromScale(0.83363, 0.0605149),
						Text = "Michael Jackson Onion",
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,

						create("UIStroke")({
							Name = "UIStroke",
						}),
					}),

					create("TextLabel")({
						Name = "Grade",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
						Position = UDim2.fromScale(0.49695, 0.200005),
						Size = UDim2.fromScale(0.83363, 0.0479085),
						Text = "EXCLUSIVE",
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,

						create("UIStroke")({
							Name = "UIStroke",
						}),

						create("UIGradient")({
							Name = "UIGradient",
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 23, 2)),
								ColorSequenceKeypoint.new(0.501701, Color3.fromRGB(18, 9, 9)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 23, 2)),
							}),
						}),
					}),

					create("ViewportFrame")({
						Name = "ViewportFrame",
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.107252, 0.111511),
						Size = UDim2.fromScale(0.789563, 0.888489),
						ZIndex = -1,
					}),

					create("ImageLabel")({
						Name = "Trait",
						BackgroundTransparency = 1,
						Image = "rbxassetid://127028785606527",
						Position = UDim2.fromScale(0.0825364, 0.019763),
						Size = UDim2.fromScale(0.113389, 0.097458),

						create("UIAspectRatioConstraint")({
							Name = "UIAspectRatioConstraint",
						}),

						create("UIGradient")({
							Name = "UIGradient",
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 246, 144)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 246, 144)),
							}),
						}),

						create("ImageLabel")({
							Name = "Trait",
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							Image = "rbxassetid://100463457721493",
							Position = UDim2.fromScale(0.5, 0.5),
							Size = UDim2.fromScale(0.887562, 0.847315),

							create("UIAspectRatioConstraint")({
								Name = "UIAspectRatioConstraint",
							}),
						}),
					}),
				}),

				create("ImageButton")({
					Name = "EquipButton",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = "rbxassetid://83967774994235",
					Position = spring(function()
						return if isVisible()
							then UDim2.fromScale(0.787698, 0.920119)
							else UDim2.fromScale(0.787698, 1.05)
					end, 0.75, 0.65),
					Size = UDim2.fromScale(0.337246, 0.0842378),
					ZIndex = 11,

					useButtonEffect(0.985),

					create("TextLabel")({
						Name = "Title",
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
						Position = UDim2.fromScale(0.265238, 0.237766),
						Size = UDim2.fromScale(0.467855, 0.487941),
						Text = "EQUIP",
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
					}),

					create("UIGradient")({
						Name = "UIGradient",
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(32, 255, 88)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(230, 255, 1)),
						}),
						Rotation = 90,
					}),
				}),

				create("ImageButton")({
					Name = "CancelButton",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = "rbxassetid://92651860309635",
					Rotation = spring(function()
						return if isVisible() then 0 else -1800
					end, 1, 0.8),
					Position = spring(function()
						return if isVisible()
							then UDim2.fromScale(0.980096, 0.0289194)
							else UDim2.fromScale(0.2, 0.0289194)
					end, 1, 0.85),
					Size = UDim2.fromScale(0.102144, 0.15458),

					useButtonEffect(nil, 1.1),

					create("UIAspectRatioConstraint")({
						Name = "UIAspectRatioConstraint",
					}),
				}),

				create("UIAspectRatioConstraint")({
					Name = "UIAspectRatioConstraint",
					AspectRatio = 1.88,
				}),
			}),

			create("UIAspectRatioConstraint")({
				Name = "UIAspectRatioConstraint",
				AspectRatio = 1.547,
				AspectType = Enum.AspectType.ScaleWithParentSize,
			}),
		})
	end, container)

	local a = true
	local b = task.spawn(function()
		while a do
			isVisible(not isVisible())
			storageCount(if isVisible() then 67 else 0)
			selectedDamage(if isVisible() then 6767 else 0)
			selectedCooldown(if isVisible() then 6.767 else 0)
			selectedRange(if isVisible() then 676 else 0)
			selectedMaxTower(if isVisible() then 67 else 0)

			task.wait(if isVisible() then 1.5 else 0.5)
		end
	end)

	return function()
		a = false
		task.cancel(b)

		destroyVide()
		container:Destroy()
	end
end
