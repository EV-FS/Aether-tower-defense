local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")

local ClientSignals = require(StarterPlayer.StarterPlayerScripts.Client.ClientSignals)
local Vide = require(ReplicatedStorage.Packages.Vide)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local useButtonEffect = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useButtonEffect)
local TimeService

local FOLD_PERIOD = 0.25

local action = Vide.action
local create = Vide.create
local source = Vide.source
local spring = Vide.spring
local effect = Vide.effect

local CurrentSpeed = source(1)
local IsFold = source(false)

-------------------------------------------------
--// Local Functions
-------------------------------------------------
local function SpeedButton(props)
	local mainPos = props.Position
	local mainSize = props.Size
	local targetSpeed = props.Speed
	local OnActivated = props.OnActivated

	return create("TextButton")({
		Name = `{targetSpeed}x`,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = spring(function()
			return if CurrentSpeed() == targetSpeed then Color3.fromRGB(0, 200, 80) else Color3.fromRGB(80, 80, 80)
		end, 0.2, 0.8),
		FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json"),
		Position = mainPos,
		Size = mainSize,
		action(function(element)
			effect(function()
				local target = if IsFold() then UDim2.new(mainPos.X, UDim.new(1.5, 0)) else mainPos
				local tweenTime = if IsFold() then FOLD_PERIOD * targetSpeed * 0.5 else FOLD_PERIOD * targetSpeed * 1
				TweenService:Create(
					element,
					TweenInfo.new(tweenTime, Enum.EasingStyle.Back, Enum.EasingDirection.InOut),
					{ Position = target }
				):Play()
			end)
		end),

		TextTransparency = 1,

		MouseButton1Click = OnActivated,
		useButtonEffect(),

		create("TextLabel")({
			Name = "TextLabel",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			FontFace = Font.new(
				"rbxasset://fonts/families/Nunito.json",
				Enum.FontWeight.ExtraBold,
				Enum.FontStyle.Normal
			),
			Position = UDim2.fromScale(0.5, 0.5),
			RichText = true,
			Size = UDim2.fromScale(0.7, 0.7),
			Text = `{targetSpeed}x`,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,

			create("UIStroke")({
				Name = "UIStroke",
				Thickness = 2,
			}),
		}),

		create("UICorner")({
			Name = "UICorner",
			CornerRadius = UDim.new(0.1, 0),
		}),

		create("UIStroke")({
			Name = "UIStroke",
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
			Color = spring(function()
				return if CurrentSpeed() == targetSpeed then Color3.fromRGB(0, 65, 26) else Color3.new()
			end, 0.2, 0.8),
			Thickness = 2,
		}),

		create("UIStroke")({
			Name = "UIStroke",
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Thickness = 2,
		}),
	})
end

-------------------------------------------------
--// SpeedUI
-------------------------------------------------
local SpeedUI = {}

function SpeedUI.ChangeSpeed(newSpeed: number)
	CurrentSpeed(newSpeed)

	TimeService = TimeService or ServiceRegistry:GetService("TimeService")
	TimeService:SetGameSpeed(CurrentSpeed())
end

function SpeedUI.RenderUI()
	return create("Frame")({
		Name = "SpeedFrame",
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Color3.fromRGB(16, 16, 16),
		Position = UDim2.fromScale(0.975, 0.015),
		Size = spring(function()
			return if IsFold() then UDim2.new(0.06, 20, 0.06, 5) else UDim2.new(0.225, 20, 0.06, 5)
		end, FOLD_PERIOD * 2, 0.8),

		ClipsDescendants = true,

		create("UIStroke")({
			Name = "Inline",
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
			Color = Color3.fromRGB(65, 65, 65),
			Thickness = 3.5,
		}),

		create("UIStroke")({
			Name = "Outline",
			Thickness = 3.5,
		}),

		create("UICorner")({
			Name = "UICorner",
			CornerRadius = UDim.new(0.15, 0),
		}),

		create("UIShadow")({
			BlurRadius = UDim.new(0.2, 0),
			Transparency = 0,
		}),

		create("ImageLabel")({
			Name = "Icon",
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			Image = "rbxassetid://115365401486601",
			ImageColor3 = Color3.fromRGB(125, 255, 0),
			Position = spring(function()
				return if IsFold() then UDim2.fromScale(0.05, 0.5) else UDim2.fromScale(0.03, 0.5)
			end, FOLD_PERIOD * 2, 0.8),

			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromScale(0.8, 0.8),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
		}),

		SpeedButton({
			Position = UDim2.fromScale(0.28, 0.5),
			Size = UDim2.fromScale(0.2, 0.7),
			Speed = 1,
			OnActivated = function()
				SpeedUI.ChangeSpeed(1)
			end,
		}),
		SpeedButton({
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.2, 0.7),
			Speed = 1.5,
			OnActivated = function()
				SpeedUI.ChangeSpeed(1.5)
			end,
		}),
		SpeedButton({
			Position = UDim2.fromScale(0.717, 0.5),
			Size = UDim2.fromScale(0.2, 0.7),
			Speed = 2,
			OnActivated = function()
				SpeedUI.ChangeSpeed(2)
			end,
		}),

		create("TextButton")({
			Name = "Dropdown",
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundColor3 = Color3.fromRGB(50, 50, 50),
			FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json"),
			Position = spring(function()
				return if IsFold() then UDim2.fromScale(0.945, 0.5) else UDim2.fromScale(0.975, 0.5)
			end, FOLD_PERIOD * 2, 0.8),

			Size = UDim2.fromScale(0.8, 0.7),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			Text = "",
			TextColor3 = Color3.new(),
			TextSize = 14,

			MouseButton1Click = function()
				IsFold(not IsFold())
			end,

			useButtonEffect(1, 1),

			create("TextLabel")({
				Name = "TextLabel",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/Nunito.json",
					Enum.FontWeight.ExtraBold,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(0.5, 0.5),
				Rotation = spring(function()
					return if IsFold() then 90 else 0
				end, FOLD_PERIOD, 0.8),

				RichText = true,
				Size = UDim2.fromScale(0.7, 0.7),
				Text = `<font family="rbxasset://LuaPackages/Packages/_Index/BuilderIcons/BuilderIcons/BuilderIcons.json">chevron-small-down</font>`,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,

				create("UIStroke")({
					Name = "UIStroke",
					Thickness = 2,
				}),
			}),

			create("UICorner")({
				Name = "UICorner",
				CornerRadius = UDim.new(0.1, 0),
			}),

			create("UIStroke")({
				Name = "UIStroke",
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				BorderStrokePosition = Enum.BorderStrokePosition.Inner,
				Color = Color3.fromRGB(65, 65, 65),
				Thickness = 2,
			}),

			create("UIStroke")({
				Name = "UIStroke",
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = 2,
			}),
		}),
	})
end

function SpeedUI.Init() end

function SpeedUI.Start()
	ClientSignals.GameSpeedChanged:Connect(function(newSpeed, _, _)
		CurrentSpeed(newSpeed)
	end)
end

return SpeedUI
