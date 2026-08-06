local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local ModalOverlay = require(ReplicatedStorage.UI.Components.ModalOverlay)

local create = Vide.create

local DialogueUI = {}

local DialogueClient
local UIController
local VIEW_ID = "Dialogue"

function DialogueUI.RenderUI()
	local buttonStyle = {
		BackgroundColor3 = Color3.fromRGB(40, 42, 49),
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		TextColor3 = Color3.fromRGB(241, 241, 241),
		FontFace = Font.fromEnum(Enum.Font.Gotham),
		TextScaled = true,
		AutoButtonColor = false,
	}

	return create("Frame")({
		Name = "DialogueUI",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),

		ModalOverlay({
			Name = "DialogueOverlay",
			Title = DialogueClient.Title,
			IsOpen = UIController:IsVisible(VIEW_ID),
			OnClose = function()
				DialogueClient.Close()
			end,
			Content = create("Frame")({
				Name = "DialogueContent",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 0.12,
				BackgroundColor3 = Color3.fromRGB(7, 12, 22),
				BorderColor3 = Color3.fromRGB(255, 255, 255),
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.8, 0.55),
				ZIndex = 31,

				create("UICorner")({
					Name = "Corner",
					CornerRadius = UDim.new(0, 16),
				}),

				create("UIStroke")({
					Name = "Stroke",
					Color = Color3.fromRGB(100, 112, 135),
					Thickness = 1,
				}),

				create("TextLabel")({
					Name = "DialogueText",
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0.5, 0.08),
					Size = UDim2.fromScale(0.92, 0.35),
					FontFace = Font.fromEnum(Enum.Font.Gotham),
					Text = DialogueClient.DialogueText,
					TextColor3 = Color3.fromRGB(236, 236, 236),
					TextScaled = true,
					TextWrapped = true,
					TextYAlignment = Enum.TextYAlignment.Top,
				}),

				create("Frame")({
					Name = "Choices",
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.9, 0.42),

					create("UIListLayout")({
						Name = "ChoiceLayout",
						FillDirection = Enum.FillDirection.Vertical,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Top,
						Padding = UDim.new(0, 12),
					}),

					create("TextButton")({
						Name = "Choice1",
						Size = UDim2.fromScale(0.92, 0.16),
						Text = DialogueClient.ChoiceText1,
						Visible = DialogueClient.ChoiceVisible1,
						MouseButton1Click = function()
							DialogueClient.ChooseDialogue(1)
						end,
						BackgroundTransparency = 0,
						BackgroundColor3 = Color3.fromRGB(42, 50, 62),
						BorderSizePixel = 0,
						TextColor3 = Color3.fromRGB(236, 236, 236),
						FontFace = Font.fromEnum(Enum.Font.Gotham),
						TextScaled = true,
						AutoButtonColor = false,
						create("UICorner")({CornerRadius = UDim.new(0, 12)}),
					}),

					create("TextButton")({
						Name = "Choice2",
						Size = UDim2.fromScale(0.92, 0.16),
						Text = DialogueClient.ChoiceText2,
						Visible = DialogueClient.ChoiceVisible2,
						MouseButton1Click = function()
							DialogueClient.ChooseDialogue(2)
						end,
						BackgroundTransparency = 0,
						BackgroundColor3 = Color3.fromRGB(42, 50, 62),
						BorderSizePixel = 0,
						TextColor3 = Color3.fromRGB(236, 236, 236),
						FontFace = Font.fromEnum(Enum.Font.Gotham),
						TextScaled = true,
						AutoButtonColor = false,
						create("UICorner")({CornerRadius = UDim.new(0, 12)}),
					}),

					create("TextButton")({
						Name = "Choice3",
						Size = UDim2.fromScale(0.92, 0.16),
						Text = DialogueClient.ChoiceText3,
						Visible = DialogueClient.ChoiceVisible3,
						MouseButton1Click = function()
							DialogueClient.ChooseDialogue(3)
						end,
						BackgroundTransparency = 0,
						BackgroundColor3 = Color3.fromRGB(42, 50, 62),
						BorderSizePixel = 0,
						TextColor3 = Color3.fromRGB(236, 236, 236),
						FontFace = Font.fromEnum(Enum.Font.Gotham),
						TextScaled = true,
						AutoButtonColor = false,
						create("UICorner")({CornerRadius = UDim.new(0, 12)}),
					}),

					create("TextButton")({
						Name = "Choice4",
						Size = UDim2.fromScale(0.92, 0.16),
						Text = DialogueClient.ChoiceText4,
						Visible = DialogueClient.ChoiceVisible4,
						MouseButton1Click = function()
							DialogueClient.ChooseDialogue(4)
						end,
						BackgroundTransparency = 0,
						BackgroundColor3 = Color3.fromRGB(42, 50, 62),
						BorderSizePixel = 0,
						TextColor3 = Color3.fromRGB(236, 236, 236),
						FontFace = Font.fromEnum(Enum.Font.Gotham),
						TextScaled = true,
						AutoButtonColor = false,
						create("UICorner")({CornerRadius = UDim.new(0, 12)}),
					}),

					create("TextButton")({
						Name = "Close",
						Size = UDim2.fromScale(0.92, 0.16),
						Text = "닫기",
						Visible = DialogueClient.CloseVisible,
						MouseButton1Click = function()
							DialogueClient.Close()
						end,
						BackgroundTransparency = 0,
						BackgroundColor3 = Color3.fromRGB(163, 65, 142),
						BorderSizePixel = 0,
						TextColor3 = Color3.fromRGB(255, 255, 255),
						FontFace = Font.fromEnum(Enum.Font.GothamBold),
						TextScaled = true,
						AutoButtonColor = false,
						create("UICorner")({CornerRadius = UDim.new(0, 12)}),
					}),
				}),
			}),
		}),
	})
end

function DialogueUI.Init()
	DialogueClient = ServiceRegistry:GetService("DialogueClient")
	UIController = ServiceRegistry:GetService("UIController")
end

return DialogueUI
