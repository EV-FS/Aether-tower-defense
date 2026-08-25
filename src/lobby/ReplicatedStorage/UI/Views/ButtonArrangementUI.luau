local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local useButtonEffect = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useButtonEffect)

local create = Vide.create
local source = Vide.source
local spring = Vide.spring

local ButtonArrangementUI = {}
local UIController
local DialogueClient

local function createMenuButton(name: string, label: string, image: string, layoutOrder: number, activated: (() -> ())?)
	local isHovered = source(false)
	local tooltipAlpha = spring(function()
		return if isHovered() then 0 else 1
	end, 0.25, 0.85)
	local tooltipScale = spring(function()
		return if isHovered() then 1 else 0.86
	end, 0.22, 0.8)
	local tooltipOffset = spring(function()
		return if isHovered() then 0 else -10
	end, 0.24, 0.88)
	local iconColor = spring(function()
		return if isHovered() then Color3.fromRGB(255, 224, 142) else Color3.new(1, 1, 1)
	end, 0.22, 0.82)
	local iconRotation = spring(function()
		return if isHovered() then -1.5 else 0
	end, 0.24, 0.78)
	local highlightTransparency = spring(function()
		return if isHovered() then 0.78 else 1
	end, 0.18, 0.9)

	return create("ImageButton")({
		Name = name,
		BackgroundTransparency = 1,
		Image = image,
		ImageColor3 = iconColor,
		LayoutOrder = layoutOrder,
		Rotation = iconRotation,
		Size = UDim2.fromScale(0.542, 0.109),

		Activated = activated,
		MouseEnter = function()
			isHovered(true)
		end,
		MouseLeave = function()
			isHovered(false)
		end,

		useButtonEffect(0.92, 1.08),

		create("ImageLabel")({
			Name = "HoverHighlight",
			Active = false,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = image,
			ImageColor3 = Color3.fromRGB(255, 252, 225),
			ImageTransparency = highlightTransparency,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.94, 0.94),
			ZIndex = 3,
		}),

		create("Frame")({
			Name = "HoverLabel",
			Active = false,
			AnchorPoint = Vector2.new(0, 0.5),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = Color3.fromRGB(23, 27, 39),
			BackgroundTransparency = function()
				return 0.12 + tooltipAlpha() * 0.88
			end,
			Position = function()
				return UDim2.new(1.22, tooltipOffset(), 0.5, 0)
			end,
			Size = UDim2.fromOffset(0, 34),
			ZIndex = 3,

			create("UICorner")({
				Name = "UICorner",
				CornerRadius = UDim.new(0, 8),
			}),

			create("UIGradient")({
				Name = "UIGradient",
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(38, 43, 59)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(19, 22, 32)),
				}),
				Rotation = 90,
			}),

			create("UIPadding")({
				Name = "UIPadding",
				PaddingLeft = UDim.new(0, 11),
				PaddingRight = UDim.new(0, 13),
			}),

			create("UIListLayout")({
				Name = "UIListLayout",
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 7),
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),

			create("UIScale")({
				Name = "TooltipScale",
				Scale = tooltipScale,
			}),

			create("Frame")({
				Name = "Accent",
				BackgroundColor3 = Color3.fromRGB(255, 211, 100),
				BackgroundTransparency = function()
					return 0.08 + tooltipAlpha() * 0.92
				end,
				Size = UDim2.fromOffset(4, 4),
				ZIndex = 4,

				create("UICorner")({
					Name = "UICorner",
					CornerRadius = UDim.new(1, 0),
				}),
			}),

			create("TextLabel")({
				Name = "Label",
				Active = false,
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
				Size = UDim2.fromOffset(0, 34),
				Text = label,
				TextColor3 = Color3.fromRGB(255, 240, 193),
				TextSize = 13,
				TextTransparency = tooltipAlpha,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 4,
			}),
		}),

		create("UIAspectRatioConstraint")({
			Name = "UIAspectRatioConstraint",
		}),
	})
end

function ButtonArrangementUI.RenderUI()
	return create("Frame")({
		Name = "ButtonArrangement",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.0561939, 0.499861),
		Size = UDim2.fromScale(0.145, 1),
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

		create("UIListLayout")({
			Name = "UIListLayout",
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0.01, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),

		createMenuButton("InventoryButton", "INVENTORY", "rbxassetid://98616994645968", 1, function()
			UIController:Open("InventoryFrame")
		end),
		createMenuButton("ShopButton", "SHOP", "rbxassetid://116881322718656", 2),
		createMenuButton("TradeBUtton", "TRADE", "rbxassetid://131037655538280", 3),
		createMenuButton("SettingButton", "SETTINGS", "rbxassetid://87579593338768", 4),
		createMenuButton("QuestButton", "QUESTS", "rbxassetid://102609699370792", 5),
		createMenuButton("IndexButton", "INDEX", "rbxassetid://80352298798116", 6),

		create("UIAspectRatioConstraint")({
			Name = "UIAspectRatioConstraint",
			AspectRatio = 0.21,
		}),
	})
end

function ButtonArrangementUI.Init()
	UIController = ServiceRegistry:GetService("UIController")
	DialogueClient = ServiceRegistry:GetService("DialogueClient")
end

return ButtonArrangementUI
