local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create
local mount = Vide.mount

local DialogueUI = {}
local unmount: (() -> ())? = nil

function DialogueUI.CreateGui()
	return create("ScreenGui")({
		Name = "DialogueGui",
		ResetOnSpawn = false,
		DisplayOrder = 50,
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,

		-- 1. 대화 시 은은한 배경 어둡게 & 포커스 (Backdrop Overlay)
		create("Frame")({
			Name = "Backdrop",
			BackgroundTransparency = 1,
			BackgroundColor3 = Color3.fromRGB(3, 5, 10),
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0, 0),
			Size = UDim2.fromScale(1, 1),
			ZIndex = 1,

			create("UIGradient")({
				Name = "Vignette",
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.85),
					NumberSequenceKeypoint.new(0.5, 0.5),
					NumberSequenceKeypoint.new(1, 0.1),
				}),
			}),
		}),

		-- 2. 우측 선택지 목록 컨테이너 (Choice Container)
		create("Frame")({
			Name = "DialogueChoiceFrame",
			BackgroundTransparency = 1,
			ClipsDescendants = false,
			Position = UDim2.fromScale(0.79, 0),
			Size = UDim2.fromScale(0.20, 1),
			Visible = false,
			ZIndex = 10,

			create("UIListLayout")({
				Name = "UIListLayout",
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0.02, 0),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			create("Frame")({
				Name = "Template",
				BackgroundColor3 = Color3.fromRGB(45, 55, 64),
				Position = UDim2.fromScale(0.0238648, 0.477831),
				Size = UDim2.fromScale(0.952271, 0.046),
				Visible = false,
				ClipsDescendants = false,

				create("UIScale")({
					Name = "ChoiceScale",
					Scale = 1,
				}),

				create("UICorner")({
					Name = "UICorner",
					BottomLeftRadius = UDim.new(1, 0),
					BottomRightRadius = UDim.new(1, 0),
					TopLeftRadius = UDim.new(1, 0),
					TopRightRadius = UDim.new(1, 0),
				}),

				create("UIGradient")({
					Name = "UIGradient",
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 0),
						NumberSequenceKeypoint.new(0.419554, 0.025),
						NumberSequenceKeypoint.new(0.800743, 0.4625, 0.375),
						NumberSequenceKeypoint.new(1, 1),
					}),
				}),

				create("TextButton")({
					Name = "Button",
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json"),
					Size = UDim2.fromScale(1, 1),
					Text = "",
					TextColor3 = Color3.new(),
					TextSize = 14,
					ZIndex = 5,
					AutoButtonColor = false,
				}),

				create("UIStroke")({
					Name = "UIStroke",
					Color = Color3.fromRGB(120, 121, 105),
					Thickness = 2,
					ZIndex = 2,

					create("UIGradient")({
						Name = "UIGradient",
						Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 0),
							NumberSequenceKeypoint.new(0.407178, 0.2125),
							NumberSequenceKeypoint.new(0.799505, 1),
							NumberSequenceKeypoint.new(1, 1),
						}),
					}),
				}),

				create("Frame")({
					Name = "Frame",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0.423163, 0.496154),
					Size = UDim2.fromScale(0.81908, 0.811888),

					create("UICorner")({
						Name = "UICorner",
						BottomLeftRadius = UDim.new(1, 0),
						BottomRightRadius = UDim.new(1, 0),
						TopLeftRadius = UDim.new(1, 0),
						TopRightRadius = UDim.new(1, 0),
					}),

					create("UIGradient")({
						Name = "UIGradient",
						Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 0),
							NumberSequenceKeypoint.new(1, 1),
						}),
					}),
				}),

				create("TextLabel")({
					Name = "TextLabel",
					BackgroundTransparency = 1,
					FontFace = Font.new(
						"rbxasset://fonts/families/AccanthisADFStd.json",
						Enum.FontWeight.Bold,
						Enum.FontStyle.Normal
					),
					Position = UDim2.fromScale(0.04, 0.12),
					Size = UDim2.fromScale(0.92, 0.76),
					Text = "...",
					TextColor3 = Color3.new(1, 1, 1),
					RichText = true,
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 3,

					create("UIStroke")({
						Name = "UIStroke",
						Color = Color3.fromRGB(9, 9, 9),
						Thickness = 1.5,
					}),
				}),
			}),
		}),

		-- 3. 하단 메인 대화창 (Dialogue Frame)
		create("Frame")({
			Name = "DialogueFram",
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = Color3.fromRGB(10, 12, 18),
			BackgroundTransparency = 0.08,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.747184),
			Size = UDim2.fromScale(1, 0.252816),
			Visible = false,
			ClipsDescendants = false,
			ZIndex = 5,

			create("UIScale")({
				Name = "FramScale",
				Scale = 1,
			}),

			create("UIGradient")({
				Name = "UIGradient",
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.200495, 0.5),
					NumberSequenceKeypoint.new(0.5, 0.35625),
					NumberSequenceKeypoint.new(0.80198, 0.50625),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),

			create("TextLabel")({
				Name = "NameText",
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/AccanthisADFStd.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(0.455918, 0.049505),
				Size = UDim2.fromScale(0.0875604, 0.178218),
				Text = "Loading",
				TextColor3 = Color3.fromRGB(255, 195, 2),
				TextScaled = true,
				ZIndex = 6,

				create("UIStroke")({
					Name = "UIStroke",
					Color = Color3.fromRGB(89, 67, 1),
				}),
			}),

			create("Frame")({
				Name = "MidFrame",
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0, 0.227382),
				Size = UDim2.fromScale(1, 0.119153),
				ZIndex = 6,

				create("UIListLayout")({
					Name = "UIListLayout",
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Padding = UDim.new(0.01, 0),
					SortOrder = Enum.SortOrder.LayoutOrder,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Wraps = true,
				}),

				create("ImageLabel")({
					Name = "LeftSide",
					BackgroundTransparency = 1,
					Image = "rbxassetid://113911681062286",
					ImageColor3 = Color3.fromRGB(255, 195, 2),
					LayoutOrder = 1,
					Position = UDim2.fromScale(0.429921, 0.1644),
					Size = UDim2.fromScale(0.0573663, 0.671202),
					ZIndex = 6,

					create("UIAspectRatioConstraint")({
						Name = "UIAspectRatioConstraint",
						AspectRatio = 5.88043,
					}),
				}),

				create("TextLabel")({
					Name = "NpcInfoText",
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					FontFace = Font.new(
						"rbxasset://fonts/families/AccanthisADFStd.json",
						Enum.FontWeight.Bold,
						Enum.FontStyle.Normal
					),
					LayoutOrder = 2,
					Position = UDim2.fromScale(0.473732, 0.126073),
					Size = UDim2.fromScale(0, 0.747855),
					Text = "Loading",
					TextColor3 = Color3.fromRGB(255, 195, 2),
					TextScaled = true,
					ZIndex = 6,

					create("UIStroke")({
						Name = "UIStroke",
						Color = Color3.fromRGB(89, 67, 1),
					}),
				}),

				create("ImageLabel")({
					Name = "RightSide",
					BackgroundTransparency = 1,
					Image = "rbxassetid://106133935062886",
					ImageColor3 = Color3.fromRGB(255, 195, 2),
					LayoutOrder = 3,
					Position = UDim2.fromScale(0.547737, 0.1644),
					Size = UDim2.fromScale(0.0573663, 0.671202),
					ZIndex = 6,

					create("UIAspectRatioConstraint")({
						Name = "UIAspectRatioConstraint",
						AspectRatio = 5.88043,
					}),
				}),
			}),

			create("TextLabel")({
				Name = "Context",
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/AccanthisADFStd.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(0, 0.39604),
				Size = UDim2.fromScale(1, 0.6),
				Text = "...",
				TextColor3 = Color3.fromRGB(245, 245, 245),
				RichText = true,
				TextScaled = true,
				TextYAlignment = Enum.TextYAlignment.Top,
				ZIndex = 6,

				create("UIStroke")({
					Name = "UIStroke",
					Color = Color3.fromRGB(48, 48, 48),
				}),

				create("UITextSizeConstraint")({
					Name = "UITextSizeConstraint",
					MaxTextSize = 25,
				}),
			}),

			create("TextButton")({
				Name = "FastButton",
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json"),
				Position = UDim2.fromScale(0, 0.40099),
				Size = UDim2.fromScale(1, 0.6),
				Text = "",
				TextColor3 = Color3.new(),
				TextSize = 14,
				ZIndex = 7,
				AutoButtonColor = false,
			}),
		}),
	})
end

function DialogueUI.Init()
	local player = Players.LocalPlayer
	if not player then
		return
	end

	local playerGui = player:WaitForChild("PlayerGui")
	if not playerGui:FindFirstChild("DialogueGui") then
		unmount = mount(DialogueUI.CreateGui, playerGui)
	end
end

function DialogueUI.Destroy()
	if unmount then
		unmount()
		unmount = nil
	end
end

return DialogueUI
