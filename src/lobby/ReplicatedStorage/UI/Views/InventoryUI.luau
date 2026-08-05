local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local UIController

local VIEW_ID = "InventoryFrame"

local create = Vide.create

local InventoryUI = {}

function InventoryUI.RenderUI()
	return create("Frame")({
		Name = "InventoryCanvas",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),

		Visible = UIController:IsVisible(VIEW_ID),

		create("Frame")({
			Name = "Gradient",
			BackgroundColor3 = Color3.fromRGB(255, 174, 33),
			BackgroundTransparency = 0.4,
			BorderColor3 = Color3.new(),
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0, 0.823009),
			Size = UDim2.fromScale(1, 0.176991),

			create("UIGradient")({
				Name = "UIGradient",
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(1, 0),
				}),
			}),
		}),

		create("ImageLabel")({
			Name = "Frame",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = "rbxassetid://117967183363418",
			Position = UDim2.fromScale(0.5, 0.5),
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromScale(0.5, 0.5),

			create("TextButton")({
				Name = "Close",
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
				Position = UDim2.fromScale(0.95519, 0.0403587),
				Size = UDim2.fromScale(0.0351011, 0.065671),
				Text = "X",
				TextColor3 = Color3.fromRGB(152, 138, 111),
				TextScaled = true,

				MouseButton1Click = function()
					UIController:Close(VIEW_ID)
				end,
			}),

			create("Frame")({
				Name = "Bar",
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.527046, 0.154709),
				Size = UDim2.fromScale(0.449376, 0.0672646),

				create("ImageLabel")({
					Name = "ImageLabel",
					BackgroundTransparency = 1,
					Image = "rbxassetid://92407025206153",
					Position = UDim2.fromScale(0.0185185, 0.1),
					ScaleType = Enum.ScaleType.Fit,
					Size = UDim2.fromScale(0.0600337, 0.866667),
				}),

				create("TextLabel")({
					Name = "TextLabel",
					BackgroundTransparency = 1,
					FontFace = Font.new(
						"rbxasset://fonts/families/GothamSSm.json",
						Enum.FontWeight.Bold,
						Enum.FontStyle.Normal
					),
					Position = UDim2.fromScale(0.0925926, 0.15),
					Size = UDim2.fromScale(0.67284, 0.666667),
					Text = "Towers",
					TextColor3 = Color3.fromRGB(128, 118, 108),
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),

				create("Frame")({
					Name = "Frame",
					BackgroundColor3 = Color3.fromRGB(128, 118, 108),
					Position = UDim2.fromScale(0.0185185, 0.966667),
					Size = UDim2.fromScale(0.95679, 0.1),

					create("UIGradient")({
						Name = "UIGradient",
						Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 0),
							NumberSequenceKeypoint.new(1, 1),
						}),
					}),

					create("UICorner")({
						Name = "UICorner",
						BottomLeftRadius = UDim.new(1, 0),
						BottomRightRadius = UDim.new(1, 0),
						TopLeftRadius = UDim.new(1, 0),
						TopRightRadius = UDim.new(1, 0),
					}),
				}),
			}),

			create("TextButton")({
				Name = "Equip",
				BackgroundColor3 = Color3.fromRGB(88, 95, 111),
				FontFace = Font.new(
					"rbxasset://fonts/families/GothamSSm.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(0.0624133, 0.872197),
				Size = UDim2.fromScale(0.179967, 0.0784753),
				Text = "Equip",
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,

				create("UICorner")({
					Name = "UICorner",
					BottomLeftRadius = UDim.new(0.2, 0),
					BottomRightRadius = UDim.new(0.2, 0),
					TopLeftRadius = UDim.new(0.2, 0),
					TopRightRadius = UDim.new(0.2, 0),
				}),

				create("UITextSizeConstraint")({
					Name = "UITextSizeConstraint",
					MaxTextSize = 18,
				}),
			}),

			create("TextButton")({
				Name = "Sell",
				BackgroundColor3 = Color3.fromRGB(111, 86, 87),
				FontFace = Font.new(
					"rbxasset://fonts/families/GothamSSm.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(0.251379, 0.872197),
				Size = UDim2.fromScale(0.179967, 0.0784753),
				Text = "Sell",
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,

				create("UICorner")({
					Name = "UICorner",
					BottomLeftRadius = UDim.new(0.2, 0),
					BottomRightRadius = UDim.new(0.2, 0),
					TopLeftRadius = UDim.new(0.2, 0),
					TopRightRadius = UDim.new(0.2, 0),
				}),

				create("UITextSizeConstraint")({
					Name = "UITextSizeConstraint",
					MaxTextSize = 18,
				}),
			}),

			create("ImageLabel")({
				Name = "TowerImage",
				BackgroundTransparency = 1,
				Image = "rbxassetid://111479850317111",
				Position = UDim2.fromScale(0.0457698, 0.0605381),
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromScale(0.396671, 0.811659),
			}),

			create("TextLabel")({
				Name = "Name",
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/GothamSSm.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(0.0593054, 0.0603139),
				Size = UDim2.fromScale(0.241819, 0.051355),
				Text = "King Noob",
				TextColor3 = Color3.fromRGB(128, 118, 108),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			create("TextLabel")({
				Name = "Rarity",
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/GothamSSm.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(0.0593054, 0.110827),
				Size = UDim2.fromScale(0.241819, 0.0355614),
				Text = "Legendary",
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,

				create("UIGradient")({
					Name = "UIGradient",
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 234, 0)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 106, 0)),
					}),
					Rotation = 90,
				}),

				create("UIStroke")({
					Name = "UIStroke",
					Color = Color3.fromRGB(125, 115, 105),
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.1,
				}),
			}),

			create("Frame")({
				Name = "Description",
				BackgroundColor3 = Color3.fromRGB(221, 202, 162),
				BackgroundTransparency = 0.5,
				BorderColor3 = Color3.new(),
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.0721221, 0.641256),
				Size = UDim2.fromScale(0.350902, 0.213004),

				create("UIStroke")({
					Name = "UIStroke",
					Color = Color3.fromRGB(131, 121, 111),
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.02,
				}),

				create("UIListLayout")({
					Name = "UIListLayout",
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),

				create("Frame")({
					Name = "DMG",
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0, 0.349697),
					Size = UDim2.fromScale(1, 0.349697),

					create("TextLabel")({
						Name = "TextLabel",
						BackgroundTransparency = 1,
						FontFace = Font.new(
							"rbxasset://fonts/families/GothamSSm.json",
							Enum.FontWeight.Bold,
							Enum.FontStyle.Normal
						),
						Position = UDim2.fromScale(0.027668, 0.166666),
						Size = UDim2.fromScale(0.715415, 0.486059),
						Text = "DMG",
						TextColor3 = Color3.fromRGB(172, 85, 86),
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),

					create("TextLabel")({
						Name = "Amount",
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
						Position = UDim2.fromScale(0.256917, 0.166666),
						Size = UDim2.fromScale(0.715415, 0.486059),
						Text = "1.24K",
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Right,

						create("UIStroke")({
							Name = "UIStroke",
							Color = Color3.fromRGB(128, 118, 108),
							StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
							Thickness = 0.1,
						}),
					}),
				}),

				create("Frame")({
					Name = "RNG",
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0, 0.349697),
					Size = UDim2.fromScale(1, 0.349697),

					create("TextLabel")({
						Name = "TextLabel",
						BackgroundTransparency = 1,
						FontFace = Font.new(
							"rbxasset://fonts/families/GothamSSm.json",
							Enum.FontWeight.Bold,
							Enum.FontStyle.Normal
						),
						Position = UDim2.fromScale(0.027668, 0.166666),
						Size = UDim2.fromScale(0.715415, 0.486059),
						Text = "RNG",
						TextColor3 = Color3.fromRGB(132, 126, 56),
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),

					create("TextLabel")({
						Name = "Amount",
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
						Position = UDim2.fromScale(0.256917, 0.166666),
						Size = UDim2.fromScale(0.715415, 0.486059),
						Text = "1.24K",
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Right,

						create("UIStroke")({
							Name = "UIStroke",
							Color = Color3.fromRGB(128, 118, 108),
							StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
							Thickness = 0.1,
						}),
					}),
				}),

				create("Frame")({
					Name = "SPA",
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0, 0.349697),
					Size = UDim2.fromScale(1, 0.349697),

					create("TextLabel")({
						Name = "TextLabel",
						BackgroundTransparency = 1,
						FontFace = Font.new(
							"rbxasset://fonts/families/GothamSSm.json",
							Enum.FontWeight.Bold,
							Enum.FontStyle.Normal
						),
						Position = UDim2.fromScale(0.027668, 0.166666),
						Size = UDim2.fromScale(0.715415, 0.486059),
						Text = "SPA",
						TextColor3 = Color3.fromRGB(74, 142, 163),
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),

					create("TextLabel")({
						Name = "Amount",
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
						Position = UDim2.fromScale(0.256917, 0.166666),
						Size = UDim2.fromScale(0.715415, 0.486059),
						Text = "1.24K",
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Right,

						create("UIStroke")({
							Name = "UIStroke",
							Color = Color3.fromRGB(128, 118, 108),
							StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
							Thickness = 0.1,
						}),
					}),
				}),
			}),

			create("UIAspectRatioConstraint")({
				Name = "UIAspectRatioConstraint",
				AspectRatio = 1.61659,
				AspectType = Enum.AspectType.ScaleWithParentSize,
			}),
		}),
	})
end

function InventoryUI.Init()
	UIController = ServiceRegistry:GetService("UIController")
end

function InventoryUI.Start()
	--UIController:Open(VIEW_ID)
end

return InventoryUI
