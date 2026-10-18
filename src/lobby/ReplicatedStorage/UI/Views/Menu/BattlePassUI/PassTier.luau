local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local useIsInScrollWindow = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useIsInScrollWindow)

local create = Vide.create
local spring = Vide.spring
local read = Vide.read

type Reactive<T> = T | (() -> T)

type Props = {
	IsVisible: Reactive<boolean>,
	IsClaimed: Reactive<boolean>,
	OwnPremium: Reactive<boolean>,
	PassLevel: Reactive<number>,
}

return function(props: Props)
	local isInView, bind = useIsInScrollWindow()

	return create("Frame")({
		Name = "Example",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(0.415245, 0.969682),

		bind,

		create("Frame")({
			Name = "Level",
			BackgroundColor3 = Color3.fromRGB(34, 34, 34),
			BackgroundTransparency = spring(function()
				return if isInView() then 0 else 1
			end, 0.3, 1),
			Position = UDim2.fromScale(0.0342934, 0.0395819),
			Size = UDim2.fromScale(0.925918, 0.106871),

			create("TextLabel")({
				Name = "Level",
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
				Position = spring(function()
					return if isInView() then UDim2.fromScale(0.181055, 0.128582) else UDim2.fromScale(0.181055, 0.5)
				end, 0.5, 0.5),
				Size = UDim2.fromScale(0.627587, 0.709994),
				Text = `Lv.{props.PassLevel}`,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextTransparency = spring(function()
					return if isInView() then 0 else 1
				end, 0.5, 1),
				ZIndex = 2,

				create("UIStroke")({
					Name = "UIStroke",
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.1,
					Transparency = spring(function()
						return if isInView() then 0 else 1
					end, 0.5, 1),
				}),
			}),
		}),

		create("ImageLabel")({
			Name = "Premium",
			BackgroundColor3 = Color3.fromRGB(33, 33, 33),
			BackgroundTransparency = 0.3,
			ClipsDescendants = true,
			Image = "rbxassetid://85518831768316",

			Position = spring(function()
				return if isInView() then UDim2.fromScale(0.0457245, 0.604067) else UDim2.fromScale(0.0457245, 0.7)
			end, 0.5, 0.5),
			Size = UDim2.fromScale(0.896319, 0.38),

			create("TextLabel")({
				Name = "Name",
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
				Position = UDim2.fromScale(0.0491513, 0.0781928),
				Size = UDim2.fromScale(0.938095, 0.215409),
				Text = "100 Coins",
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 2,

				create("UIStroke")({
					Name = "UIStroke",
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.1,
				}),

				create("UIGradient")({
					Name = "UIGradient",
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 234, 0)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 106, 0)),
					}),
					Rotation = 90,
				}),
			}),

			create("ImageLabel")({
				Name = "Main",
				BackgroundTransparency = 1,
				Image = "rbxassetid://117112996963807",
				Position = UDim2.fromScale(0.236975, 0.086607),
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromScale(0.608083, 0.824659),

				create("UIAspectRatioConstraint")({
					Name = "UIAspectRatioConstraint",
				}),
			}),

			create("ImageLabel")({
				Name = "ImageLabel",
				BackgroundTransparency = 1,
				Image = "rbxassetid://117112996963807",
				ImageTransparency = 0.8,
				Position = UDim2.fromScale(0.70885, 0.569995),
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromScale(0.608083, 0.824659),

				create("UIAspectRatioConstraint")({
					Name = "UIAspectRatioConstraint",
				}),
			}),

			create("ImageLabel")({
				Name = "ImageLabel",
				BackgroundTransparency = 1,
				Image = "rbxassetid://117112996963807",
				ImageTransparency = 0.8,
				Position = UDim2.fromScale(-0.183886, -0.263078),
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromScale(0.608083, 0.824659),

				create("UIAspectRatioConstraint")({
					Name = "UIAspectRatioConstraint",
				}),
			}),

			create("ImageLabel")({
				Name = "ImageLabel",
				BackgroundTransparency = 1,
				Image = "rbxassetid://117112996963807",
				ImageTransparency = 0.8,
				Position = UDim2.fromScale(-0.234899, 0.662559),
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromScale(0.471875, 0.732095),

				create("UIAspectRatioConstraint")({
					Name = "UIAspectRatioConstraint",
				}),
			}),

			create("TextLabel")({
				Name = "Text",
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
				Position = UDim2.fromScale(0.0201776, 0.736423),
				Size = UDim2.fromScale(0.947939, 0.1537),
				Text = "Click to Claim!",
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				ZIndex = 2,

				create("UIStroke")({
					Name = "UIStroke",
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.1,
				}),
			}),

			create("UIGradient")({
				Name = "UIGradient",
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 234, 0)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 106, 0)),
				}),
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.3),
					NumberSequenceKeypoint.new(1, 0.3),
				}),
			}),

			create("Frame")({
				Name = "Lock",
				BackgroundColor3 = Color3.fromRGB(15, 15, 15),
				BackgroundTransparency = spring(function()
					return if read(props.IsVisible) then 0.3 else 0.8
				end, 0.5, 0.5),
				Size = UDim2.fromScale(1, 1),
				ZIndex = 88,
				Visible = function()
					return not read(props.OwnPremium)
				end,

				create("ImageLabel")({
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = "rbxassetid://15117261700",
					ImageTransparency = spring(function()
						return if read(props.IsVisible) and isInView() then 0 else 1
					end, 0.5, 1),
					Position = UDim2.fromScale(0.4897375, 0.419636),
					Size = spring(function()
						return if read(props.IsVisible) and isInView()
							then UDim2.fromScale(0.354561, 0.571866)
							else UDim2.fromScale(0.526, 0.849)
					end, 0.5, 1),
				}),

				create("TextLabel")({
					Name = "Text",
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
					Position = UDim2.fromScale(0.0201776, 0.705569),
					Size = UDim2.fromScale(0.947939, 0.1537),
					Text = "Premium",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					ZIndex = 2,

					create("UIStroke")({
						Name = "UIStroke",
						StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
						Thickness = 0.1,
					}),
				}),
			}),
		}),

		create("Frame")({
			Name = "Free",
			BackgroundColor3 = Color3.fromRGB(33, 33, 33),
			BackgroundTransparency = 0.3,
			ClipsDescendants = true,
			Position = spring(function()
				return if isInView() then UDim2.fromScale(0.0457245, 0.181977) else UDim2.fromScale(0.0457245, 0.25)
			end, 0.6, 0.5),
			Size = UDim2.fromScale(0.896319, 0.38),

			create("UICorner")({
				Name = "UICorner",
				BottomLeftRadius = UDim.new(0.04, 0),
				BottomRightRadius = UDim.new(0.04, 0),
				TopLeftRadius = UDim.new(0.04, 0),
				TopRightRadius = UDim.new(0.04, 0),
			}),

			create("UIStroke")({
				Name = "UIStroke",
				Color = Color3.fromRGB(144, 144, 144),
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.02,
			}),

			create("TextLabel")({
				Name = "Text",
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
				Position = UDim2.fromScale(0.0201776, 0.736423),
				Size = UDim2.fromScale(0.947939, 0.1537),
				Text = "Click to Claim!",
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				ZIndex = 2,

				create("UIStroke")({
					Name = "UIStroke",
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.1,
				}),
			}),

			create("TextLabel")({
				Name = "Name",
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
				Position = UDim2.fromScale(0.0300213, 0.067908),
				Size = UDim2.fromScale(0.938095, 0.215409),
				Text = "100 Coins",
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 2,

				create("UIStroke")({
					Name = "UIStroke",
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.1,
				}),

				create("UIGradient")({
					Name = "UIGradient",
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 234, 0)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 106, 0)),
					}),
					Rotation = 90,
				}),
			}),

			create("ImageLabel")({
				Name = "Main",
				BackgroundTransparency = 1,
				Image = "rbxassetid://117112996963807",
				Position = UDim2.fromScale(0.236975, 0.086607),
				ScaleType = Enum.ScaleType.Slice,
				Size = UDim2.fromScale(0.608083, 0.824659),

				create("UIAspectRatioConstraint")({
					Name = "UIAspectRatioConstraint",
				}),
			}),

			create("ImageLabel")({
				Name = "ImageLabel",
				BackgroundTransparency = 1,
				Image = "rbxassetid://117112996963807",
				ImageTransparency = 0.8,
				Position = UDim2.fromScale(0.70885, 0.569995),
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromScale(0.608083, 0.824659),

				create("UIAspectRatioConstraint")({
					Name = "UIAspectRatioConstraint",
				}),
			}),

			create("ImageLabel")({
				Name = "ImageLabel",
				BackgroundTransparency = 1,
				Image = "rbxassetid://117112996963807",
				ImageTransparency = 0.8,
				Position = UDim2.fromScale(-0.183886, -0.263078),
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromScale(0.608083, 0.824659),

				create("UIAspectRatioConstraint")({
					Name = "UIAspectRatioConstraint",
				}),
			}),

			create("ImageLabel")({
				Name = "ImageLabel",
				BackgroundTransparency = 1,
				Image = "rbxassetid://117112996963807",
				ImageTransparency = 0.8,
				Position = UDim2.fromScale(-0.234899, 0.662559),
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromScale(0.471875, 0.732095),

				create("UIAspectRatioConstraint")({
					Name = "UIAspectRatioConstraint",
				}),
			}),

			create("Frame")({
				Name = "Claimed",
				BackgroundColor3 = Color3.fromRGB(15, 15, 15),
				BackgroundTransparency = 0.3,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 88,
				Visible = function()
					return not read(props.IsClaimed)
				end,

				create("TextLabel")({
					Name = "Text",
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
					Position = spring(function()
						if not isInView() then
							return UDim2.fromScale(0.0201776, 0.6)
						elseif not read(props.IsVisible) then
							return UDim2.fromScale(0.0201776, 0.5)
						else
							return UDim2.fromScale(0.0201776, 0.366169)
						end
					end, 0.5, 0.7),
					Size = spring(function()
						if not isInView() then
							return UDim2.fromScale(0.947939, 0.15)
						elseif not read(props.IsVisible) then
							return UDim2.fromScale(0.947939, 0.2)
						else
							return UDim2.fromScale(0.947939, 0.255251)
						end
					end, 0.5, 0.7),
					Text = "Claimed!",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					ZIndex = 2,

					create("UIStroke")({
						Name = "UIStroke",
						StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
						Thickness = 0.1,
					}),

					create("UIGradient")({
						Name = "UIGradient",
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 0)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(21, 255, 0)),
						}),
						Rotation = 90,
					}),
				}),

				create("UICorner")({
					Name = "UICorner",
					BottomLeftRadius = UDim.new(0.04, 0),
					BottomRightRadius = UDim.new(0.04, 0),
					TopLeftRadius = UDim.new(0.04, 0),
					TopRightRadius = UDim.new(0.04, 0),
				}),
			}),
		}),
	})
end
