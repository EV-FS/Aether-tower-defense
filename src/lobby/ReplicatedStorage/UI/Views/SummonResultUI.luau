local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local RarityData = require(ReplicatedStorage.Settings.Data.RarityData)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local TowerViewport = require(ReplicatedStorage.UI.Components.TowerViewport)

local create = Vide.create
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
	Uncommon = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 255, 140)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 180, 70)),
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

local RARITY_GLOW = {
	Common = Color3.fromRGB(180, 180, 180),
	Uncommon = Color3.fromRGB(90, 220, 110),
	Rare = Color3.fromRGB(70, 120, 255),
	Epic = Color3.fromRGB(210, 80, 255),
	Legendary = Color3.fromRGB(255, 190, 70),
	Mythic = Color3.fromRGB(255, 60, 60),
	Absolute = Color3.fromRGB(180, 220, 255),
}

local RARITY_TIER = {
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Epic = 4,
	Legendary = 5,
	Mythic = 6,
	Absolute = 7,
}

local UIController

local resultsQueue = source({} :: { PulledUnit })
local currentIndex = source(0)
local revealPhase = source(false)
local isTransitioning = source(false)
local isClosing = source(false)
local showFlash = source(false)
local slideSign = source(1)

local EXIT_DELAY = 0.34
local ENTER_DELAY = 0.42
local CLOSE_DELAY = 0.4

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

local function getRarityTier(): number
	local unit = getCurrentUnit()
	if not unit then
		return 1
	end

	return RARITY_TIER[unit.Rarity] or 1
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

local function pulseFlash()
	if getRarityTier() < 4 then
		return
	end

	showFlash(true)
	task.delay(0.14, function()
		showFlash(false)
	end)
end

local function playInitialReveal()
	isTransitioning(false)
	revealPhase(false)
	task.defer(function()
		if UIController:IsOpen(VIEW_ID) then
			revealPhase(true)
			pulseFlash()
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
			pulseFlash()

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
	showFlash(false)

	task.delay(CLOSE_DELAY, function()
		if token ~= closeToken or not UIController:IsOpen(VIEW_ID) then
			isClosing(false)
			isTransitioning(false)
			return
		end

		isClosing(false)
		isTransitioning(false)
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
	showFlash(false)
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
	showFlash(false)
end

function SummonResultUI.RenderUI()
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
			BackgroundTransparency = spring(function()
				if isRevealed() then
					return 0.35
				end

				return 1
			end, if isClosing() then 0.28 else 0.35, 0.85),
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
				Name = "RevealFlash",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = function()
					local unit = getCurrentUnit()
					local rarity = unit and unit.Rarity or "Common"
					return RARITY_GLOW[rarity] or RARITY_GLOW.Common
				end,
				BackgroundTransparency = spring(function()
					return if showFlash() then 0.45 else 1
				end, 0.1, 0.85),
				Position = UDim2.fromScale(0.5, 0.4),
				Size = spring(function()
					return if showFlash() then UDim2.fromScale(0.75, 0.8) else UDim2.fromScale(0.2, 0.2)
				end, 0.12, 0.75),
				ZIndex = 52,
			}),

			create("ImageLabel")({
				Name = "Glow",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = "rbxassetid://74355115881963",
				ImageColor3 = function()
					local unit = getCurrentUnit()
					return if unit then RARITY_GLOW[unit.Rarity] or RARITY_GLOW.Common else RARITY_GLOW.Common
				end,
				ImageTransparency = spring(function()
					if not isRevealed() then
						return 1
					end

					return if getRarityTier() >= 4 then 0.15 else 0.55
				end, 0.45, 0.7),
				Position = UDim2.fromScale(0.5, 0.4),
				Size = spring(function()
					return if isRevealed() then UDim2.fromScale(0.55, 0.62) else UDim2.fromScale(0.05, 0.06)
				end, 0.55, 0.62),
				ZIndex = 51,
			}),

			create("ImageLabel")({
				Name = "Burst",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = "rbxassetid://137286113984807",
				ImageTransparency = spring(function()
					if not isRevealed() or getRarityTier() < 5 then
						return 1
					end

					return 0.35
				end, 0.5, 0.75),
				Position = UDim2.fromScale(0.5, 0.4),
				Rotation = spring(function()
					return if isRevealed() then 0 else -120
				end, 0.7, 0.55),
				Size = spring(function()
					return if isRevealed() then UDim2.fromScale(0.7, 0.75) else UDim2.fromScale(0.1, 0.1)
				end, 0.6, 0.6),
				ZIndex = 52,
			}),

			create("Frame")({
				Name = "ViewportHolder",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Position = spring(function()
					if isRevealed() then
						return UDim2.fromScale(0.5, 0.38)
					end

					if isClosing() then
						return UDim2.fromScale(0.5, 0.58)
					end

					return UDim2.fromScale(0.5 + slideSign() * 0.14, 0.54)
				end, if isClosing() then 0.32 else 0.38, 0.66),
				Size = spring(function()
					if isRevealed() then
						return UDim2.fromScale(0.42, 0.48)
					end

					if isClosing() then
						return UDim2.fromScale(0.08, 0.09)
					end

					return UDim2.fromScale(0.12, 0.14)
				end, if isClosing() then 0.3 else 0.38, 0.64),
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
					ModelRotation = spring(function()
						if isRevealed() then
							return 0
						end

						if isClosing() then
							return 35
						end

						return slideSign() * 95
					end, if isClosing() then 0.38 else 0.45, 0.58),
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
