local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local LoadoutSlot = require(ReplicatedStorage.UI.Components.LoadoutSlot)

local create = Vide.create

local MAX_LOADOUT_SIZE = 5
local INVENTORY_VIEW_ID = "InventoryFrame"

local InventoryClient
local DataClient
local DialogueClient
local UIController

local LoadoutUI = {}

function LoadoutUI.RenderUI()
	local slots = table.create(MAX_LOADOUT_SIZE)

	for index = 1, MAX_LOADOUT_SIZE do
		slots[index] = LoadoutSlot({
			slotNumber = index,
			loadout = InventoryClient.Loadout,
			Activated = function()
				UIController:Open(INVENTORY_VIEW_ID)
			end,
		})
	end

	return create("Frame")({
		Name = "LoadoutUI",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Visible = function()
			if DialogueClient and DialogueClient.IsOpen() then
				return false
			end
			if UIController and UIController:IsOpen("Dialogue") then
				return false
			end
			return true
		end,

		create("Frame")({
			Name = "Slots",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),

			create("UIAspectRatioConstraint")({
				Name = "UIAspectRatioConstraint",
				AspectRatio = 1.42478,
				AspectType = Enum.AspectType.ScaleWithParentSize,
			}),

			-- 1. 덱 위: 재화 표시 (원본 디자인 100% 유지 + 간격/너비 최적화)
			create("Frame")({
				Name = "Currency",
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(-0.001, 0.755),
				Size = UDim2.fromScale(1, 0.0758533),

				create("UIListLayout")({
					Name = "UIListLayout",
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Padding = UDim.new(0.02, 0),
					SortOrder = Enum.SortOrder.LayoutOrder,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),

				-- Coins
				create("Frame")({
					Name = "Coins",
					BackgroundColor3 = Color3.new(),
					BackgroundTransparency = 0.2,
					BorderColor3 = Color3.new(),
					BorderSizePixel = 0,
					Position = UDim2.fromScale(0.346767, 0.216667),
					Size = UDim2.fromScale(0.165, 0.566667),

					create("ImageLabel")({
						Name = "ImageLabel",
						BackgroundTransparency = 1,
						Image = "rbxassetid://117112996963807",
						Position = UDim2.fromScale(0.0520515, -0.0882353),
						ScaleType = Enum.ScaleType.Fit,
						Size = UDim2.fromScale(0.2911, 1.11765),

						create("UIAspectRatioConstraint")({
							Name = "UIAspectRatioConstraint",
						}),
					}),

					create("UIGradient")({
						Name = "UIGradient",
						Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 1),
							NumberSequenceKeypoint.new(0.502475, 0),
							NumberSequenceKeypoint.new(1, 1),
						}),
					}),

					create("TextLabel")({
						Name = "TextLabel",
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
						Position = UDim2.fromScale(0.36, 0.0588235),
						Size = UDim2.fromScale(0.62, 0.882353),
						Text = function()
							return DataClient and DataClient.FormatNumber(DataClient.Coins()) or "0"
						end,
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,

						create("UIStroke")({
							Name = "UIStroke",
							StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
							Thickness = 0.08,
						}),

						create("UIGradient")({
							Name = "UIGradient",
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 106, 0)),
							}),
							Rotation = 90,
						}),
					}),
				}),

				-- Gems
				create("Frame")({
					Name = "Gems",
					BackgroundColor3 = Color3.new(),
					BackgroundTransparency = 0.2,
					BorderColor3 = Color3.new(),
					BorderSizePixel = 0,
					Position = UDim2.fromScale(0.434455, 0.225),
					Size = UDim2.fromScale(0.165, 0.566667),

					create("ImageLabel")({
						Name = "ImageLabel",
						BackgroundTransparency = 1,
						Image = "rbxassetid://104268323693949",
						Position = UDim2.fromScale(0.06, -0.17558),
						ScaleType = Enum.ScaleType.Fit,
						Size = UDim2.fromScale(0.2911, 1.29323),

						create("UIAspectRatioConstraint")({
							Name = "UIAspectRatioConstraint",
						}),
					}),

					create("UIGradient")({
						Name = "UIGradient",
						Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 1),
							NumberSequenceKeypoint.new(0.502475, 0),
							NumberSequenceKeypoint.new(1, 1),
						}),
					}),

					create("TextLabel")({
						Name = "TextLabel",
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
						Position = UDim2.fromScale(0.36, 0.0882353),
						Size = UDim2.fromScale(0.62, 0.823529),
						Text = function()
							return DataClient and DataClient.FormatNumber(DataClient.Gems()) or "0"
						end,
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,

						create("UIStroke")({
							Name = "UIStroke",
							StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
							Thickness = 0.08,
						}),

						create("UIGradient")({
							Name = "UIGradient",
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 187, 255)),
								ColorSequenceKeypoint.new(0.5, Color3.fromRGB(185, 227, 255)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(153, 0, 255)),
							}),
							Rotation = 90,
						}),
					}),
				}),

				-- Blossom
				create("Frame")({
					Name = "Blossom",
					BackgroundColor3 = Color3.new(),
					BackgroundTransparency = 0.2,
					BorderColor3 = Color3.new(),
					BorderSizePixel = 0,
					Position = UDim2.fromScale(0.434455, 0.225),
					Size = UDim2.fromScale(0.165, 0.566667),

					create("ImageLabel")({
						Name = "ImageLabel",
						BackgroundTransparency = 1,
						Image = "rbxassetid://129066851213188",
						Position = UDim2.fromScale(0.06, -0.0579331),
						ScaleType = Enum.ScaleType.Fit,
						Size = UDim2.fromScale(0.2911, 1.29323),

						create("UIAspectRatioConstraint")({
							Name = "UIAspectRatioConstraint",
						}),
					}),

					create("UIGradient")({
						Name = "UIGradient",
						Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 1),
							NumberSequenceKeypoint.new(0.502475, 0),
							NumberSequenceKeypoint.new(1, 1),
						}),
					}),

					create("TextLabel")({
						Name = "TextLabel",
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
						Position = UDim2.fromScale(0.36, 0.0882353),
						Size = UDim2.fromScale(0.62, 0.823529),
						Text = function()
							return DataClient and DataClient.FormatNumber(DataClient.Blossom()) or "0"
						end,
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,

						create("UIStroke")({
							Name = "UIStroke",
							StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
							Thickness = 0.08,
						}),

						create("UIGradient")({
							Name = "UIGradient",
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 112, 248)),
								ColorSequenceKeypoint.new(0.5, Color3.fromRGB(239, 181, 255)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(243, 79, 255)),
							}),
							Rotation = 90,
						}),
					}),
				}),
			}),

			-- 2. 덱 슬롯 프레임 (Deck Loadout Slots)
			create("Frame")({
				Name = "Frame",
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.183092, 0.825),
				Size = UDim2.fromScale(0.631857, 0.134),

				create("UIListLayout")({
					Name = "UIListLayout",
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Padding = UDim.new(0.008, 0),
					SortOrder = Enum.SortOrder.LayoutOrder,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),

				unpack(slots),
			}),

			-- 3. 덱 아래: 경험치 & 레벨 바 (원본 디자인 100% 유지)
			create("Folder")({
				Name = "Xpbar",

				create("Frame")({
					Name = "XpbarDeco",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0.501244, 0.980),
					Size = UDim2.fromScale(0.735, 0.03),
					ZIndex = 10,

					create("UIListLayout")({
						Name = "UIListLayout",
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						Padding = UDim.new(0.15, 0),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),

					create("ImageLabel")({
						Name = "SeparateLine",
						BackgroundTransparency = 1.02,
						Image = "rbxassetid://96127352288701",
						Position = UDim2.fromScale(0.0102451, 0),
						Size = UDim2.fromScale(0.005, 1),

						create("UIGradient")({
							Name = "UIGradient",
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(65, 65, 65)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(65, 65, 65)),
							}),
						}),
					}),

					create("ImageLabel")({
						Name = "SeparateLine",
						BackgroundTransparency = 1.02,
						Image = "rbxassetid://96127352288701",
						Position = UDim2.fromScale(0.0102451, 0),
						Size = UDim2.fromScale(0.005, 1),

						create("UIGradient")({
							Name = "UIGradient",
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(65, 65, 65)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(65, 65, 65)),
							}),
						}),
					}),

					create("ImageLabel")({
						Name = "SeparateLine",
						BackgroundTransparency = 1.02,
						Image = "rbxassetid://96127352288701",
						Position = UDim2.fromScale(0.0102451, 0),
						Size = UDim2.fromScale(0.005, 1),

						create("UIGradient")({
							Name = "UIGradient",
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(65, 65, 65)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(65, 65, 65)),
							}),
						}),
					}),

					create("ImageLabel")({
						Name = "SeparateLine",
						BackgroundTransparency = 1.02,
						Image = "rbxassetid://96127352288701",
						Position = UDim2.fromScale(0.0102451, 0),
						Size = UDim2.fromScale(0.005, 1),

						create("UIGradient")({
							Name = "UIGradient",
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(65, 65, 65)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(65, 65, 65)),
							}),
						}),
					}),

					create("ImageLabel")({
						Name = "SeparateLine",
						BackgroundTransparency = 1.02,
						Image = "rbxassetid://96127352288701",
						Position = UDim2.fromScale(0.0102451, 0),
						Size = UDim2.fromScale(0.005, 1),

						create("UIGradient")({
							Name = "UIGradient",
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(65, 65, 65)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(65, 65, 65)),
							}),
						}),
					}),

					create("ImageLabel")({
						Name = "SeparateLine",
						BackgroundTransparency = 1.02,
						Image = "rbxassetid://96127352288701",
						Position = UDim2.fromScale(0.0102451, 0),
						Size = UDim2.fromScale(0.005, 1),

						create("UIGradient")({
							Name = "UIGradient",
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(65, 65, 65)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(65, 65, 65)),
							}),
						}),
					}),
				}),

				create("ImageLabel")({
					Name = "XpbarBG",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = "rbxassetid://123614945790793",
					Position = UDim2.fromScale(0.501244, 0.980),
					Size = UDim2.fromScale(0.734689, 0.0301169),
				}),

				create("ImageLabel")({
					Name = "XpbarFill",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = "rbxassetid://87566142417575",
					Position = UDim2.fromScale(0.501244, 0.978),
					Size = function()
						local exp = DataClient and DataClient.Exp() or 0
						local maxExp = DataClient and DataClient.GetMaxExp() or 100
						local ratio = math.clamp(exp / math.max(1, maxExp), 0, 1)
						return UDim2.fromScale(0.728 * ratio, 0.02)
					end,
					ZIndex = 2,

					create("UIGradient")({
						Name = "UIGradient",
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(62, 75, 255)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(49, 228, 255)),
						}),
					}),
				}),

				create("TextLabel")({
					Name = "Name",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new(
						"rbxasset://fonts/families/SourceSansPro.json",
						Enum.FontWeight.Bold,
						Enum.FontStyle.Normal
					),
					Position = UDim2.fromScale(0.501244, 0.963),
					Size = UDim2.fromScale(0.498016, 0.0337153),
					Text = function()
						local level = DataClient and DataClient.Level() or 1
						local exp = DataClient and DataClient.Exp() or 0
						local maxExp = DataClient and DataClient.GetMaxExp() or 100
						return string.format("LV.%d(%d/%dxp)", level, exp, maxExp)
					end,
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					ZIndex = 10,

					create("UIStroke")({
						Name = "UIStroke",
						Thickness = 2,
					}),
				}),
			}),
		}),
	})
end

function LoadoutUI.Init()
	InventoryClient = ServiceRegistry:GetService("InventoryClient")
	DataClient = ServiceRegistry:GetService("DataClient")
	DialogueClient = ServiceRegistry:GetService("DialogueClient")
	UIController = ServiceRegistry:GetService("UIController")
end

function LoadoutUI.Start()
	InventoryClient.FetchLoadout()
end

return LoadoutUI
