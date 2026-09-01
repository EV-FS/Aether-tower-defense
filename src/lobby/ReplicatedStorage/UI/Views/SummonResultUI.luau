local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Vide = require(ReplicatedStorage.Packages.Vide)
local RarityData = require(ReplicatedStorage.Settings.Data.RarityData)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local TowerViewport = require(ReplicatedStorage.UI.Components.TowerViewport)

local create = Vide.create
local cleanup = Vide.cleanup
local effect = Vide.effect
local source = Vide.source
local spring = Vide.spring

export type PulledUnit = {
	UnitName: string,
	Rarity: string,
}

local VIEW_ID = "SummonResult"

local RARITY_GRADIENTS = {
	Common = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(199, 199, 199)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(160, 160, 160)),
	}),
	Rare = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(42, 106, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 34, 255)),
	}),
	Epic = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(235, 85, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 32, 170)),
	}),
	Legendary = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 194, 52)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 126, 61)),
	}),
	Mythic = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 14, 18)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(189, 0, 3)),
	}),
	Absolute = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(185, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(239, 189, 255)),
	}),
}

local UIController

local resultsQueue = source({} :: { PulledUnit })
local currentIndex = source(0)
local revealPhase = source(false)
local isTransitioning = source(false)
local isClosing = source(false)
local slideSign = source(1)

local EXIT_DELAY = 0.34
local ENTER_DELAY = 0.42
local CLOSE_DELAY = 0.4
local BACKDROP_BLUR_SIZE = 8
local BLUR_FADE_IN_TIME = 0.32
local BLUR_FADE_OUT_TIME = 0.38

local closeToken = 0

local SummonResultUI = {}

local function getCurrentUnit(): PulledUnit?
	local queue = resultsQueue()
	local index = currentIndex()
	if index < 1 or index > #queue then
		return nil
	end

	return queue[index]
end

local function isRevealed(): boolean
	return UIController:IsOpen(VIEW_ID) and revealPhase()
end

local function canInteract(): boolean
	return isRevealed() and not isTransitioning()
end

local function isHintVisible(): boolean
	return isRevealed() and not isTransitioning() and not isClosing()
end

local function playInitialReveal()
	isTransitioning(false)
	revealPhase(false)
	task.defer(function()
		if UIController:IsOpen(VIEW_ID) then
			revealPhase(true)
		end
	end)
end

local function playTransition(onSwitch: () -> ())
	isTransitioning(true)
	revealPhase(false)

	task.delay(EXIT_DELAY, function()
		if not UIController:IsOpen(VIEW_ID) then
			isTransitioning(false)
			return
		end

		slideSign(-slideSign())
		onSwitch()

		task.defer(function()
			if not UIController:IsOpen(VIEW_ID) then
				isTransitioning(false)
				return
			end

			revealPhase(true)

			task.delay(ENTER_DELAY, function()
				isTransitioning(false)
			end)
		end)
	end)
end

local function playClose(onFinished: () -> ())
	if isTransitioning() or isClosing() then
		return
	end

	closeToken += 1
	local token = closeToken

	isTransitioning(true)
	isClosing(true)
	revealPhase(false)

	task.delay(CLOSE_DELAY, function()
		if token ~= closeToken or not UIController:IsOpen(VIEW_ID) then
			isClosing(false)
			isTransitioning(false)
			return
		end

		onFinished()
	end)
end

function SummonResultUI.ShowResults(units: { PulledUnit })
	if #units == 0 then
		return
	end

	closeToken += 1
	resultsQueue(units)
	currentIndex(1)
	slideSign(1)
	isTransitioning(false)
	isClosing(false)
	revealPhase(false)
	UIController:Open(VIEW_ID)
	playInitialReveal()
end

function SummonResultUI.Advance()
	if isTransitioning() then
		return
	end

	local queue = resultsQueue()
	local index = currentIndex()

	if index < #queue then
		playTransition(function()
			currentIndex(index + 1)
		end)
		return
	end

	playClose(function()
		SummonResultUI.Close()
	end)
end

function SummonResultUI.Close()
	closeToken += 1
	UIController:Close(VIEW_ID)
	resultsQueue({})
	currentIndex(0)
	revealPhase(false)
	isTransitioning(false)
	isClosing(false)
end

function SummonResultUI.RenderUI()
	local backdropBlur = Instance.new("BlurEffect")
	backdropBlur.Name = "SummonResultBackdropBlur"
	backdropBlur.Size = 0
	backdropBlur.Enabled = false
	backdropBlur.Parent = Lighting
	cleanup(function()
		backdropBlur:Destroy()
	end)

	effect(function()
		-- Begin fading out as soon as the close animation starts, rather than
		-- dropping the blur on the frame where the view is removed.
		local shouldBlur = UIController:IsOpen(VIEW_ID) and not isClosing()
		local tween = TweenService:Create(
			backdropBlur,
			TweenInfo.new(
				if shouldBlur then BLUR_FADE_IN_TIME else BLUR_FADE_OUT_TIME,
				Enum.EasingStyle.Quad,
				if shouldBlur then Enum.EasingDirection.Out else Enum.EasingDirection.InOut
			),
			{ Size = if shouldBlur then BACKDROP_BLUR_SIZE else 0 }
		)

		if shouldBlur then
			backdropBlur.Enabled = true
		end

		local completed = tween.Completed:Connect(function(playbackState)
			if playbackState == Enum.PlaybackState.Completed and not shouldBlur then
				backdropBlur.Enabled = false
			end
		end)
		tween:Play()
		cleanup(function()
			completed:Disconnect()
			tween:Cancel()
		end)
	end)

	return create("Frame")({
		Name = "SummonResultUI",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = UIController:IsVisible(VIEW_ID),
		ZIndex = 50,

		create("TextButton")({
			Name = "Backdrop",
			AutoButtonColor = false,
			Active = function()
				return canInteract()
			end,
			BackgroundColor3 = Color3.fromRGB(5, 5, 10),
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Text = "",
			ZIndex = 50,

			Activated = SummonResultUI.Advance,
		}),

		create("Frame")({
			Name = "ResultPanel",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.5),
			Rotation = spring(function()
				if isRevealed() then
					return 0
				end

				if isClosing() then
					return -6
				end

				return slideSign() * 8
			end, if isClosing() then 0.32 else 0.38, 0.68),
			Size = UDim2.fromScale(1, 1),
			ZIndex = 51,

			create("UIScale")({
				Scale = spring(function()
					if isRevealed() then
						return 1
					end

					if isClosing() then
						return 0.88
					end

					return 0.94
				end, if isClosing() then 0.3 else 0.38, 0.68),
			}),

			create("Frame")({
				Name = "ViewportHolder",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.5, 0.38),
				Size = UDim2.fromScale(0.42, 0.48),
				ZIndex = 53,

				TowerViewport({
					TowerName = function()
						local unit = getCurrentUnit()
						return unit and unit.UnitName or ""
					end,
					AnimationName = "Idle",
					AnchorPoint = Vector2.new(0.5, 1),
					BackgroundTransparency = 1,
					ImageTransparency = spring(function()
						return if isRevealed() then 0 else 1
					end, 0.45, 0.85),
					Position = UDim2.fromScale(0.5, 1),
					Size = UDim2.fromScale(1, 1),
					ZIndex = 53,
					ModelRotation = spring(function()
						if isRevealed() then
							return 0
						end

						if isClosing() then
							return 35
						end

						return slideSign() * 95
					end, if isClosing() then 0.38 else 0.45, 0.58),
					-- A fixed camera fit prevents the model from jumping when the entry
					-- spring changes the rendered UI size.
					UseViewportModel = false,
				}),
			}),

			create("TextLabel")({
				Name = "TowerName",
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/SourceSansPro.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = spring(function()
					if isRevealed() then
						return UDim2.fromScale(0.5, 0.66)
					end

					return UDim2.fromScale(0.5 - slideSign() * 0.08, 0.74)
				end, 0.38, 0.68),
				Size = UDim2.fromScale(0.7, 0.07),
				Text = function()
					local unit = getCurrentUnit()
					return unit and unit.UnitName or ""
				end,
				TextColor3 = Color3.fromRGB(245, 242, 230),
				TextScaled = true,
				TextTransparency = spring(function()
					return if isRevealed() then 0 else 1
				end, 0.45, 0.85),
				ZIndex = 54,

				create("UIStroke")({
					Thickness = 1.5,
					Transparency = spring(function()
						return if isRevealed() then 0.4 else 1
					end, 0.45, 0.85),
				}),
			}),

			create("TextLabel")({
				Name = "Rarity",
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/SourceSansPro.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = spring(function()
					if isRevealed() then
						return UDim2.fromScale(0.5, 0.735)
					end

					return UDim2.fromScale(0.5 + slideSign() * 0.08, 0.8)
				end, 0.4, 0.68),
				Size = UDim2.fromScale(0.5, 0.055),
				Text = function()
					local unit = getCurrentUnit()
					return unit and RarityData.DisplayNames[unit.Rarity] or ""
				end,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextTransparency = spring(function()
					return if isRevealed() then 0 else 1
				end, 0.5, 0.85),
				ZIndex = 54,

				create("UIStroke")({
					Thickness = 2,
					Transparency = spring(function()
						return if isRevealed() then 0.15 else 1
					end, 0.5, 0.85),
				}),

				create("UIGradient")({
					Color = function()
						local unit = getCurrentUnit()
						local rarity = unit and unit.Rarity or "Common"
						return RARITY_GRADIENTS[rarity] or RARITY_GRADIENTS.Common
					end,
					Rotation = 90,
				}),
			}),

			create("TextLabel")({
				Name = "Progress",
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/SourceSansPro.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(0.5, 0.805),
				Size = UDim2.fromScale(0.3, 0.04),
				Text = function()
					local total = #resultsQueue()
					if total <= 1 then
						return ""
					end

					return `{currentIndex()} / {total}`
				end,
				TextColor3 = Color3.fromRGB(180, 175, 150),
				TextScaled = true,
				TextTransparency = spring(function()
					return if isRevealed() then 0.15 else 1
				end, 0.45, 0.85),
				ZIndex = 54,
			}),

			create("TextLabel")({
				Name = "ContinueHint",
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/SourceSansPro.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = spring(function()
					if isHintVisible() then
						return UDim2.fromScale(0.5, 0.94)
					end

					return UDim2.fromScale(0.5, 1.06)
				end, 0.42, 1),
				Size = UDim2.fromScale(0.45, 0.04),
				Text = function()
					local total = #resultsQueue()
					local index = currentIndex()
					if total <= 1 then
						return "Tap to close"
					end

					return if index < total then "Tap to continue" else "Tap to finish"
				end,
				TextColor3 = Color3.fromRGB(150, 145, 120),
				TextScaled = true,
				TextTransparency = spring(function()
					return if isHintVisible() then 0.25 else 1
				end, 0.4, 1),
				ZIndex = 54,
			}),
		}),
	})
end

function SummonResultUI.Init()
	UIController = ServiceRegistry:GetService("UIController")
end

function SummonResultUI.Start() end

return SummonResultUI
