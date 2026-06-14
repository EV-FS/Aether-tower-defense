--/Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")

--/Modules
local ClientSignals = require(StarterPlayer.StarterPlayerScripts.Client.ClientSignals)
local Vide = require(ReplicatedStorage.Packages.Vide)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local useButtonEffect = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useButtonEffect)
local Net = require(ReplicatedStorage.Shared.Net)
local SettingsClient

--/Vide Variables
local create = Vide.create
local source = Vide.source
local effect = Vide.effect
local action = Vide.action

local CurrentMode = source("Ready")
local IsReady = source(false)
local IsVisible = source(true)
local IsOpen = source(false)
local ReadyCount = source(0)
local TotalPlayers = source(#Players:GetPlayers())

-------------------------------------------------
--// Local Functions
-------------------------------------------------
local function setPlayerCount()
	task.defer(function()
		TotalPlayers(#Players:GetPlayers())
	end)
end

-------------------------------------------------
--// ReadyUI
-- -------------------------------------------------
local ReadyUI = {}

function ReadyUI.RenderUI()
	return create("Frame")({
		Name = "SkipFrame",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Position = UDim2.fromScale(0.5, 0.082),
		Size = UDim2.fromScale(0.182, 0.047),
		Visible = IsVisible,
		ZIndex = 10,

		create("Frame")({
			Name = "Canvas",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(16, 16, 16),
			BackgroundTransparency = 0.25,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.95, 0.75),

			action(function(element)
				effect(function()
					local target = if IsOpen() then UDim2.fromScale(0.5, 0.5) else UDim2.fromScale(0.5, 1.5)
					TweenService
						:Create(element, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
							Position = target,
						})
						:Play()
				end)
			end),

			create("UICorner")({
				Name = "UICorner",
				CornerRadius = UDim.new(0.2, 0),
			}),

			create("UIShadow")({
				Name = "UIShadow",
				BlurRadius = UDim.new(0.1, 0),
				Transparency = 0.5,
			}),

			create("TextButton")({
				Name = "SkipButton",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(0, 255, 0),
				FontFace = Font.new(
					"rbxasset://fonts/families/SourceSansPro.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(0.843633, 0.491121),
				RichText = true,
				Size = UDim2.fromScale(0.256, 0.55),
				Text = "",
				TextColor3 = Color3.new(),
				TextScaled = true,

				useButtonEffect(),

				MouseButton1Click = function()
					if IsReady() then
						return
					end

					IsReady(true)
					if CurrentMode() == "Ready" then
						Net.GameEvent.Ready.Fire()
					else
						Net.GameEvent.VoteSkip.Fire()
					end
				end,

				create("UICorner")({
					Name = "UICorner",
					CornerRadius = UDim.new(0.1, 0),
				}),

				create("UIStroke")({
					Name = "UIStroke",
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Color = Color3.fromRGB(0, 94, 0),
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.05,
				}),

				create("Frame")({
					Name = "Frame",
					BackgroundColor3 = Color3.fromRGB(0, 143, 0),
					BackgroundTransparency = 0.5,
					Position = UDim2.fromScale(0, 0.473923),
					Size = UDim2.fromScale(1, 0.526077),

					create("UICorner")({
						Name = "UICorner",
						CornerRadius = UDim.new(0.2, 0),
					}),
				}),

				create("TextLabel")({
					Name = "Title",
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
					Position = UDim2.fromScale(0.145287, 0.215392),
					Size = UDim2.fromScale(0.702747, 0.553866),
					Text = function()
						if CurrentMode() == "Ready" then
							return IsReady() and "Ready!" or "Ready?"
						else
							return IsReady() and "Skipped!" or "Skip?"
						end
					end,
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,

					create("UIStroke")({
						Name = "UIStroke",
						StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
						Thickness = 0.15,
					}),
				}),
			}),

			create("TextLabel")({
				Name = "Amount",
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
				Position = UDim2.fromScale(0.45, 0.5),
				RichText = true,
				Size = UDim2.fromScale(0.23, 0.394),
				Text = function()
					return `{ReadyCount()}/{TotalPlayers()}`
				end,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,

				create("UIStroke")({
					Name = "UIStroke",
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.08,
				}),
			}),

			create("TextLabel")({
				Name = "Text",
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
				Position = UDim2.fromScale(0.048, 0.5),
				RichText = true,
				Size = UDim2.fromScale(0.4, 0.4),
				Text = function()
					if CurrentMode() == "Ready" then
						return "Vote Start"
					else
						return "Skip Wave?"
					end
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
						ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 246, 0)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 157, 0)),
					}),
					Rotation = 90,
				}),
			}),
		}),

		create("UIAspectRatioConstraint")({
			Name = "UIAspectRatioConstraint",
			AspectRatio = 4.38584,
			AspectType = Enum.AspectType.ScaleWithParentSize,
		}),
	})
end

function ReadyUI.Init()
	SettingsClient = ServiceRegistry:GetService("SettingsClient")
end

function ReadyUI.Start()
	ClientSignals.ReadyVoted:Connect(function(readyCount)
		if CurrentMode() == "Ready" then
			ReadyCount(readyCount)
		end
	end)

	ClientSignals.SkipVoted:Connect(function(voteCount)
		if CurrentMode() == "Skip" then
			ReadyCount(voteCount)
		end
	end)

	ClientSignals.Restarted:Connect(function()
		CurrentMode("Ready")
		IsReady(false)
		ReadyCount(0)
		setPlayerCount()

		IsOpen(true)
		IsVisible(true)
	end)

	ClientSignals.WaveStarted:Connect(function()
		IsOpen(false)
		local mode = CurrentMode()
		task.delay(0.35, function()
			if CurrentMode() == mode then
				IsVisible(false)
			end
		end)
	end)

	ClientSignals.CanSkip:Connect(function()
		CurrentMode("Skip")
		IsReady(false)
		ReadyCount(0)
		IsOpen(true)
		IsVisible(true)

		if SettingsClient:GetSettings().AutoSkip == true then
			task.delay(0.35, function()
				if CurrentMode() == "Skip" then
					IsReady(true)
					Net.GameEvent.VoteSkip.Fire()
				end
			end)
		end
	end)

	Players.PlayerAdded:Connect(setPlayerCount)
	Players.PlayerRemoving:Connect(setPlayerCount)

	task.defer(function()
		IsOpen(true)
		IsVisible(true)
	end)
end

return ReadyUI
