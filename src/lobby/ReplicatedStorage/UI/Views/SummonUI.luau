local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local useButtonEffect = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useButtonEffect)
local TouchZone = require(ReplicatedStorage.Shared.Modules.Utils.TouchZone)
local Net = require(ReplicatedStorage.Shared.Net)
local SummonConfig = require(ReplicatedStorage.Settings.Data.SummonConfig)
local TowerViewport = require(ReplicatedStorage.UI.Components.TowerViewport)
local SummonResultUI = require(script.Parent.SummonResultUI)

local cleanup = Vide.cleanup
local create = Vide.create
local effect = Vide.effect
local source = Vide.source
local spring = Vide.spring

local UIController
local DataClient
local summonZone

local VIEW_ID = "Summon"
local EXIT_DURATION = 0.32
local ONE_PULL_COST = SummonConfig.Prices[1]
local TEN_PULL_COST = SummonConfig.Prices[10]
local BANNER_TIMER_DURATION = SummonConfig.BannerTimerDuration
local MYTHIC_PITY_LIMIT = SummonConfig.Pity.Mythic.Limit
local ABSOLUTE_PITY_LIMIT = SummonConfig.Pity.Absolute.Limit
local MYTHIC_PITY_ATTRIBUTE = SummonConfig.Pity.Mythic.Attribute
local ABSOLUTE_PITY_ATTRIBUTE = SummonConfig.Pity.Absolute.Attribute

local DISPLAY_FONT = Font.new(
	"rbxasset://fonts/families/FredokaOne.json",
	Enum.FontWeight.Bold,
	Enum.FontStyle.Normal
)
local PLAIN_DISPLAY_FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")
local BODY_FONT = Font.new(
	"rbxasset://fonts/families/SourceSansPro.json",
	Enum.FontWeight.Bold,
	Enum.FontStyle.Normal
)

local MAIN_IMAGE = "rbxassetid://101796292394413"
local HEADER_IMAGE = "rbxassetid://106553153352559"
local HELMET_IMAGE = "rbxassetid://109351985581707"
local CLOUD_IMAGE = "rbxassetid://71168710355974"
local SWORD_IMAGE = "rbxassetid://131831557828351"
local CLOSE_IMAGE = "rbxassetid://92651860309635"
local BANNER_IMAGE = "rbxassetid://98737132035258"
local CARD_SHADOW_IMAGE = "rbxassetid://99201276937983"
local NAME_PLATE_IMAGE = "rbxassetid://116700116064149"
local PURCHASE_BUTTON_IMAGE = "rbxassetid://139274506988816"
local CURRENCY_IMAGE = "rbxassetid://104268323693949"
local PROBABILITY_BUTTON_IMAGE = "rbxassetid://120545788069786"

local RARITY_GRADIENTS = SummonConfig.RarityGradients
local FEATURED_RARITIES = SummonConfig.FeaturedRarities
local RATE_RARITIES = SummonConfig.RateDisplayOrder
local PURCHASE_AVAILABLE_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(55, 255, 0)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 238, 1)),
})
local PURCHASE_UNAVAILABLE_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(108, 108, 108)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(48, 48, 48)),
})

type UnitBannerInfo = {
	Name: string,
	RateText: string,
}

type UnitsPool = {
	[string]: UnitBannerInfo,
}

local DEFAULT_UNITS_POOL: UnitsPool = {
	Common = { Name = "", RateText = "" },
	Rare = { Name = "", RateText = "" },
	Epic = { Name = "", RateText = "" },
	Legendary = { Name = "", RateText = "" },
	Mythic = { Name = "", RateText = "" },
	Absolute = { Name = "", RateText = "" },
}

local currentUnitsPool = source(DEFAULT_UNITS_POOL)
local isProbabilityOpen = source(false)
local summonInProgress = source(false)
local nextBannerTimerResetAt = source(0)
local bannerSecondsRemaining = source(BANNER_TIMER_DURATION)
local mythicPity = source(0)
local absolutePity = source(0)
local SummonUI = {}

local function isOpen(): boolean
	return UIController ~= nil and UIController:IsOpen(VIEW_ID)
end

function SummonUI.Open(): boolean
	return UIController ~= nil and UIController:OpenExclusive(VIEW_ID)
end

local function copyDefaultUnitsPool(): UnitsPool
	local pool = {}
	for rarity, info in DEFAULT_UNITS_POOL do
		pool[rarity] = {
			Name = info.Name,
			RateText = info.RateText,
		}
	end
	return pool
end

local function getUnitInfo(rarity: string): UnitBannerInfo
	return currentUnitsPool()[rarity] or DEFAULT_UNITS_POOL[rarity] or { Name = "", RateText = "" }
end

local function formatTimer(seconds: number): string
	local roundedSeconds = math.max(0, math.ceil(seconds))
	return string.format("%02d:%02d", math.floor(roundedSeconds / 60), roundedSeconds % 60)
end

local function canPurchase(cost: number): boolean
	return DataClient ~= nil and not summonInProgress() and DataClient.Coins() >= cost
end

local function createRarityGradient(rarity: string)
	local colors = RARITY_GRADIENTS[rarity] or RARITY_GRADIENTS.Common
	return create("UIGradient")({
		Name = "UIGradient",
		Color = colors,
	})
end

local function createUnitCard(rarity: string, layoutOrder: number)
	return create("Frame")({
		Name = "Frame",
		BackgroundTransparency = 1,
		LayoutOrder = layoutOrder,
		Size = UDim2.fromScale(0.290764, 1),

		create("ImageLabel")({
			Name = "Shadow",
			BackgroundTransparency = 1,
			Image = CARD_SHADOW_IMAGE,
			Position = UDim2.fromScale(0.00631904, 0.106321),
			Size = UDim2.fromScale(1, 1),
			ZIndex = -1,

			create("UIAspectRatioConstraint")({}),
		}),

		TowerViewport({
			TowerName = function()
				return getUnitInfo(rarity).Name
			end,
			Name = "ViewportFrame",
			AnimationName = "Idle",
			AnchorPoint = Vector2.new(0, 0),
			BackgroundTransparency = 1,
			Ambient = Color3.fromRGB(190, 190, 190),
			LightColor = Color3.new(1, 1, 1),
			LightDirection = Vector3.new(-1, -0.8, -0.65),
			FieldOfView = 32,
			FitPadding = 1.08,
			Position = UDim2.fromScale(0, 0),
			Size = UDim2.fromScale(1, 1),
			UseCharacterBounds = true,
			UseViewportModel = true,
			ModelRotation = 0,
			ZIndex = 1,
		}),

		create("ImageLabel")({
			Name = "Name",
			BackgroundTransparency = 1,
			Image = NAME_PLATE_IMAGE,
			Position = UDim2.fromScale(0.176933, 0.647593),
			Size = UDim2.fromScale(0.652453, 0.178427),
			ZIndex = 2,

			create("TextLabel")({
				Name = "Name",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = DISPLAY_FONT,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 0.4),
				Text = function()
					return getUnitInfo(rarity).Name
				end,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextTruncate = Enum.TextTruncate.AtEnd,

				create("UIStroke")({}),
				create("UITextSizeConstraint")({ MinTextSize = 8, MaxTextSize = 22 }),
			}),

			create("TextLabel")({
				Name = "Grade",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = DISPLAY_FONT,
				Position = UDim2.fromScale(0.5, 0.757312),
				Size = UDim2.fromScale(1, 0.3),
				Text = string.upper(rarity),
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,

				create("UIStroke")({}),
				create("UITextSizeConstraint")({ MinTextSize = 7, MaxTextSize = 14 }),

				createRarityGradient(rarity),
			}),

			create("UIListLayout")({
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
		}),
	})
end

local function createRateRow(rarity: string, layoutOrder: number)
	return create("Frame")({
		Name = rarity,
		BackgroundTransparency = 1,
		LayoutOrder = layoutOrder,
		Size = UDim2.fromScale(1, 0.145),
		ZIndex = 22,

		create("TextLabel")({
			Name = "Grade",
			BackgroundTransparency = 1,
			FontFace = BODY_FONT,
			LayoutOrder = 1,
			Size = UDim2.fromScale(0.55, 0.72),
			Text = rarity,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 22,

			create("UIStroke")({
				Color = Color3.fromRGB(25, 20, 38),
				Thickness = 1.2,
			}),

			createRarityGradient(rarity),
		}),

		create("TextLabel")({
			Name = "Probability",
			BackgroundTransparency = 1,
			FontFace = BODY_FONT,
			LayoutOrder = 2,
			Size = UDim2.fromScale(0.3, 0.72),
			Text = function()
				return getUnitInfo(rarity).RateText
			end,
			TextColor3 = Color3.fromRGB(255, 238, 185),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 22,

			create("UIStroke")({
				Color = Color3.fromRGB(40, 30, 20),
				Thickness = 1,
			}),
		}),

		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0.06, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	})
end

local function createPurchaseButton(
	name: string,
	amount: number,
	title: string,
	cost: number,
	position: UDim2
)
	return create("ImageButton")({
		Name = name,
		Active = function()
			return isOpen() and canPurchase(cost)
		end,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = PURCHASE_BUTTON_IMAGE,
		Position = position,
		Size = UDim2.fromScale(0.238867, 0.113861),

		Activated = function()
			SummonUI.Summon(amount)
		end,

		useButtonEffect(0.97, 1.025),

		create("UICorner")({}),

		create("UIStroke")({
			Color = function()
				return if canPurchase(cost) then Color3.new(1, 1, 1) else Color3.fromRGB(121, 121, 121)
			end,
		}),

		create("UIGradient")({
			Color = function()
				return if canPurchase(cost) then PURCHASE_AVAILABLE_GRADIENT else PURCHASE_UNAVAILABLE_GRADIENT
			end,
		}),

		create("TextLabel")({
			Name = "Title",
			BackgroundTransparency = 1,
			FontFace = PLAIN_DISPLAY_FONT,
			Position = if amount == 1
				then UDim2.fromScale(0.0483483, 0.168285)
				else UDim2.fromScale(0.0483484, 0.253242),
			Size = if amount == 1
				then UDim2.fromScale(0.402995, 0.699418)
				else UDim2.fromScale(0.547652, 0.473445),
			Text = title,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,

			create("UIStroke")({}),
		}),

		create("TextLabel")({
			Name = "Title",
			BackgroundTransparency = 1,
			FontFace = PLAIN_DISPLAY_FONT,
			Position = UDim2.fromScale(0.596, 0.278),
			Size = UDim2.fromScale(0.164253, 0.498891),
			Text = tostring(cost),
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,

			create("UIStroke")({}),
		}),

		create("ImageLabel")({
			Name = "ImageLabel",
			BackgroundTransparency = 1,
			Image = CURRENCY_IMAGE,
			Position = UDim2.fromScale(0.7598, 0.0835799),
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromScale(0.226426, 0.784124),

			create("UIAspectRatioConstraint")({}),
		}),
	})
end

local function createStatusBar(
	name: string,
	fillName: string,
	title: string,
	getRatio: () -> number,
	getValueText: () -> string,
	colors: ColorSequence,
	position: UDim2,
	size: UDim2
)
	local animatedRatio = spring(function()
		return math.clamp(getRatio(), 0, 1)
	end, 0.34, 0.82)

	return create("Frame")({
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(26, 24, 43),
		BackgroundTransparency = 0.08,
		Position = position,
		Size = size,
		ZIndex = 10,

		create("UICorner")({
			CornerRadius = UDim.new(0.22, 0),
		}),

		create("UIStroke")({
			Color = Color3.fromRGB(153, 146, 196),
			Thickness = 1,
			Transparency = 0.42,
		}),

		create("Frame")({
			Name = "Track",
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = Color3.fromRGB(48, 44, 67),
			ClipsDescendants = true,
			Position = UDim2.fromScale(0.025, 0.5),
			Size = UDim2.fromScale(0.95, 0.72),
			ZIndex = 10,

			create("UICorner")({
				CornerRadius = UDim.new(0.28, 0),
			}),

			create("Frame")({
				Name = fillName,
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0,
				Size = function()
					return UDim2.fromScale(animatedRatio(), 1)
				end,
				ZIndex = 11,

				create("UICorner")({
					CornerRadius = UDim.new(0.28, 0),
				}),

				create("UIGradient")({
					Color = colors,
					Rotation = 12,
				}),
			}),
		}),

		create("TextLabel")({
			Name = "Label",
			BackgroundTransparency = 1,
			FontFace = DISPLAY_FONT,
			Position = UDim2.fromScale(0.065, 0.08),
			Size = UDim2.fromScale(0.61, 0.84),
			Text = title,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 12,

			create("UIStroke")({
				Color = Color3.fromRGB(31, 25, 46),
				Thickness = 1.2,
			}),

			create("UITextSizeConstraint")({
				MaxTextSize = 14,
				MinTextSize = 6,
			}),
		}),

		create("TextLabel")({
			Name = "Value",
			BackgroundTransparency = 1,
			FontFace = DISPLAY_FONT,
			Position = UDim2.fromScale(0.66, 0.08),
			Size = UDim2.fromScale(0.275, 0.84),
			Text = getValueText,
			TextColor3 = Color3.fromRGB(255, 246, 205),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 12,

			create("UIStroke")({
				Color = Color3.fromRGB(38, 30, 48),
				Thickness = 1.1,
			}),

			create("UITextSizeConstraint")({
				MaxTextSize = 14,
				MinTextSize = 6,
			}),
		}),
	})
end

function SummonUI.UpdateBanner(bannerData)
	if bannerData and type(bannerData.NextRerollTime) == "number" then
		nextBannerTimerResetAt(bannerData.NextRerollTime)
	end

	if not bannerData or type(bannerData.Units) ~= "table" then
		warn("[SummonUI] Banner data is missing its unit list.")
		return
	end

	local unitsByRarity = copyDefaultUnitsPool()
	local units = bannerData.Units

	if units[1] then
		for _, unit in ipairs(units) do
			if unit.Rarity and unitsByRarity[unit.Rarity] then
				unitsByRarity[unit.Rarity] = {
					Name = unit.Name or "",
					RateText = unit.RateText or "",
				}
			end
		end
	else
		for rarity, info in units do
			if unitsByRarity[rarity] and type(info) == "table" then
				unitsByRarity[rarity] = {
					Name = info.Name or "",
					RateText = info.RateText or "",
				}
			end
		end
	end

	local previousPool = currentUnitsPool()
	local lineupChanged = false
	for rarity, unitInfo in unitsByRarity do
		local previousInfo = previousPool[rarity]
		if
			not previousInfo
			or previousInfo.Name ~= unitInfo.Name
			or previousInfo.RateText ~= unitInfo.RateText
		then
			lineupChanged = true
			break
		end
	end

	if lineupChanged then
		currentUnitsPool(unitsByRarity)
	end
end

function SummonUI.Summon(number: number)
	local cost = SummonConfig.Prices[number]
	if not cost or not canPurchase(cost) then
		return
	end
	summonInProgress(true)

	task.spawn(function()
		local ok, success, result = pcall(function()
			return Net.SummonService.DoSummon.Invoke(number):await()
		end)
		summonInProgress(false)

		if not ok then
			warn("[SummonUI] Summon request failed: " .. tostring(success))
			return
		end

		if not success or not result or not result.Success then
			return
		end

		local pulledUnits = result.PulledUnits
		if type(pulledUnits) == "table" and #pulledUnits > 0 then
			isProbabilityOpen(false)
			SummonResultUI.ShowResults(pulledUnits, function()
				if summonZone and summonZone:IsTouching(Players.LocalPlayer) then
					SummonUI.Open()
				end
			end)
		end
	end)
end

function SummonUI.RenderUI()
	local isMounted = source(false)
	local isAnimatedOpen = source(false)
	local transitionToken = 0

	effect(function()
		local shouldOpen = isOpen()
		transitionToken += 1
		local token = transitionToken

		if shouldOpen then
			isMounted(true)
			isAnimatedOpen(false)
			task.defer(function()
				if token == transitionToken and isOpen() then
					isAnimatedOpen(true)
				end
			end)
			return
		end

		isAnimatedOpen(false)
		isProbabilityOpen(false)
		task.delay(EXIT_DURATION, function()
			if token == transitionToken and not isOpen() then
				isMounted(false)
			end
		end)
	end)

	cleanup(function()
		transitionToken += 1
	end)

	local windowScale = spring(function()
		return if isAnimatedOpen() then 1 else 0.9
	end, 0.3, 0.86)
	local windowPosition = spring(function()
		return if isAnimatedOpen() then UDim2.fromScale(0.5, 0.5) else UDim2.fromScale(0.5, 0.535)
	end, 0.3, 0.86)
	local windowRotation = spring(function()
		return if isAnimatedOpen() then 0 else -2
	end, 0.32, 0.88)
	local ratesTransparency = spring(function()
		return if isOpen() and isProbabilityOpen() then 0 else 1
	end, 0.2, 0.9)
	local ratesScale = spring(function()
		return if isOpen() and isProbabilityOpen() then 1 else 0.82
	end, 0.28, 0.74)

	return create("CanvasGroup")({
		Name = "Container",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		Interactable = function()
			return isOpen() and isAnimatedOpen()
		end,
		Visible = isMounted,

		create("ImageLabel")({
			Name = "Main",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = MAIN_IMAGE,
			Position = windowPosition,
			Rotation = windowRotation,
			Size = UDim2.fromScale(0.721698, 0.668872),

			create("UIScale")({
				Scale = windowScale,
			}),

			create("UIAspectRatioConstraint")({
				AspectRatio = 1.88,
			}),

			create("ImageLabel")({
				Name = "Header",
				BackgroundTransparency = 1,
				Image = HEADER_IMAGE,
				Position = UDim2.fromScale(-0.0573612, -0.111321),
				Size = UDim2.fromScale(0.692821, 0.28349),
				ZIndex = 10,

				create("UIAspectRatioConstraint")({
					AspectRatio = 4.53,
				}),

				create("ImageLabel")({
					Name = "Helmet",
					AnchorPoint = Vector2.new(0, 0),
					BackgroundTransparency = 1,
					Image = HELMET_IMAGE,
					Position = UDim2.fromScale(0.0623672, 0.17661),
					Size = UDim2.fromScale(0.125872, 0.58156),

					create("UIAspectRatioConstraint")({}),
				}),

				create("ImageLabel")({
					Name = "Cloud",
					BackgroundTransparency = 1,
					Image = CLOUD_IMAGE,
					Position = UDim2.fromScale(0.529887, 0.0551715),
					Size = UDim2.fromScale(0.537766, 1.06417),

					create("UIAspectRatioConstraint")({
						AspectRatio = 2.16,
					}),
				}),

				create("TextLabel")({
					Name = "Title",
					BackgroundTransparency = 1,
					FontFace = PLAIN_DISPLAY_FONT,
					Position = UDim2.fromScale(0.265238, 0.435573),
					Size = UDim2.fromScale(0.283423, 0.290134),
					Text = "SUMMON",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),

				create("ImageLabel")({
					Name = "Sword",
					BackgroundTransparency = 1,
					Image = SWORD_IMAGE,
					Position = UDim2.fromScale(0.01, -0.312),
					Size = UDim2.fromScale(0.251814, 1.53914),

					create("UIAspectRatioConstraint")({
						AspectRatio = 0.77,
					}),
				}),
			}),

			create("ImageButton")({
				Name = "CancelButton",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = CLOSE_IMAGE,
				Position = UDim2.fromScale(0.980096, 0.0289194),
				Size = UDim2.fromScale(0.102144, 0.15458),

				Activated = function()
					isProbabilityOpen(false)
					UIController:Close(VIEW_ID)
				end,

				useButtonEffect(0.88, 1.08),

				create("UIAspectRatioConstraint")({}),
			}),

			create("ImageLabel")({
				Name = "Banner",
				BackgroundTransparency = 1,
				Image = BANNER_IMAGE,
				Position = UDim2.fromScale(0.0334857, 0.172169),
				Size = UDim2.fromScale(0.932419, 0.666445),

				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),

				createUnitCard(FEATURED_RARITIES[1], 1),
				createUnitCard(FEATURED_RARITIES[2], 2),
				createUnitCard(FEATURED_RARITIES[3], 3),
			}),

			createPurchaseButton(
				"PurchaseButton",
				1,
				"SUMMON",
				ONE_PULL_COST,
				UDim2.fromScale(0.152616, 0.905)
			),

			createPurchaseButton(
				"PurchaseButton",
				10,
				"X10",
				TEN_PULL_COST,
				UDim2.fromScale(0.406167, 0.905)
			),

			createStatusBar(
				"BannerTimer",
				"BannerTimerFill",
				"TIMER",
				function()
					return bannerSecondsRemaining() / BANNER_TIMER_DURATION
				end,
				function()
					return formatTimer(bannerSecondsRemaining())
				end,
				ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(67, 211, 255)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(110, 103, 255)),
				}),
				UDim2.fromScale(0.8, 0.105),
				UDim2.fromScale(0.26, 0.036)
			),

			createStatusBar(
				"MythicFloorBar",
				"Fill",
				"MYTHIC PITY",
				function()
					return mythicPity() / MYTHIC_PITY_LIMIT
				end,
				function()
					return `{mythicPity()}/{MYTHIC_PITY_LIMIT}`
				end,
				RARITY_GRADIENTS.Mythic,
				UDim2.fromScale(0.7, 0.875),
				UDim2.fromScale(0.26, 0.036)
			),

			createStatusBar(
				"AbsoluteFloorBar",
				"Fill",
				"ABSOLUTE PITY",
				function()
					return absolutePity() / ABSOLUTE_PITY_LIMIT
				end,
				function()
					return `{absolutePity()}/{ABSOLUTE_PITY_LIMIT}`
				end,
				RARITY_GRADIENTS.Absolute,
				UDim2.fromScale(0.7, 0.935),
				UDim2.fromScale(0.26, 0.036)
			),

			create("ImageButton")({
				Name = "DropRateButton",
				AnchorPoint = Vector2.new(0.5, 0.5),
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				Image = PROBABILITY_BUTTON_IMAGE,
				Position = UDim2.fromScale(0.91, 0.905),
				Rotation = spring(function()
					return if isProbabilityOpen() then -6 else 0
				end, 0.28, 0.72),
				Size = UDim2.fromScale(0.08, 0.113861),
				ZIndex = 15,

				Activated = function()
					isProbabilityOpen(not isProbabilityOpen())
				end,

				useButtonEffect(0.88, 1.1),

				create("UIAspectRatioConstraint")({}),

				create("TextLabel")({
					Name = "Label",
					AnchorPoint = Vector2.new(0.5, 1),
					BackgroundTransparency = 1,
					FontFace = DISPLAY_FONT,
					Position = UDim2.fromScale(0.5, 1.09),
					Size = UDim2.fromScale(1.45, 0.27),
					Text = "DROP RATE",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					ZIndex = 16,

					create("UIStroke")({
						Color = Color3.fromRGB(35, 28, 54),
						Thickness = 1.2,
					}),
				}),
			}),

			create("CanvasGroup")({
				Name = "DropRateFrame",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(24, 23, 45),
				BackgroundTransparency = 0.06,
				GroupTransparency = ratesTransparency,
				Interactable = isProbabilityOpen,
				Visible = function()
					return isOpen() and (isProbabilityOpen() or ratesTransparency() < 0.995)
				end,
				Position = spring(function()
					return if isProbabilityOpen()
						then UDim2.fromScale(0.78, 0.475)
						else UDim2.fromScale(0.82, 0.475)
				end, 0.3, 0.74),
				Size = UDim2.fromScale(0.3, 0.54),
				ZIndex = 20,

				create("UIScale")({
					Scale = ratesScale,
				}),

				create("UICorner")({
					CornerRadius = UDim.new(0.055, 0),
				}),

				create("UIStroke")({
					Color = Color3.fromRGB(126, 119, 255),
					Thickness = 2,
					Transparency = ratesTransparency,
				}),

				create("TextLabel")({
					Name = "Title",
					BackgroundTransparency = 1,
					FontFace = DISPLAY_FONT,
					Position = UDim2.fromScale(0.09, 0.035),
					Size = UDim2.fromScale(0.82, 0.11),
					Text = "DROP RATES",
					TextColor3 = Color3.fromRGB(255, 244, 196),
					TextScaled = true,
					ZIndex = 22,

					create("UIStroke")({
						Color = Color3.fromRGB(35, 27, 55),
						Thickness = 1.4,
					}),
				}),

				create("Frame")({
					Name = "Rows",
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0.08, 0.17),
					Size = UDim2.fromScale(0.84, 0.77),
					ZIndex = 21,

					create("UIListLayout")({
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						Padding = UDim.new(0.012, 0),
						SortOrder = Enum.SortOrder.LayoutOrder,
						VerticalAlignment = Enum.VerticalAlignment.Center,
					}),

					createRateRow(RATE_RARITIES[1], 1),
					createRateRow(RATE_RARITIES[2], 2),
					createRateRow(RATE_RARITIES[3], 3),
					createRateRow(RATE_RARITIES[4], 4),
					createRateRow(RATE_RARITIES[5], 5),
					createRateRow(RATE_RARITIES[6], 6),
				}),
			}),
		}),
	})
end

function SummonUI.Init()
	UIController = ServiceRegistry:GetService("UIController")
	DataClient = ServiceRegistry:GetService("DataClient")
end

function SummonUI.Start()
	local player = Players.LocalPlayer
	local function updatePitySources()
		mythicPity(
			math.clamp(
				math.floor(tonumber(player:GetAttribute(MYTHIC_PITY_ATTRIBUTE)) or 0),
				0,
				MYTHIC_PITY_LIMIT - 1
			)
		)
		absolutePity(
			math.clamp(
				math.floor(tonumber(player:GetAttribute(ABSOLUTE_PITY_ATTRIBUTE)) or 0),
				0,
				ABSOLUTE_PITY_LIMIT - 1
			)
		)
	end

	updatePitySources()
	player:GetAttributeChangedSignal(MYTHIC_PITY_ATTRIBUTE):Connect(updatePitySources)
	player:GetAttributeChangedSignal(ABSOLUTE_PITY_ATTRIBUTE):Connect(updatePitySources)

	Net.SummonService.BannerUpdated.On(SummonUI.UpdateBanner)

	task.spawn(function()
		while true do
			local serverTime = workspace:GetServerTimeNow()
			local resetAt = nextBannerTimerResetAt()

			if resetAt <= 0 then
				resetAt = serverTime + (BANNER_TIMER_DURATION - (serverTime % BANNER_TIMER_DURATION))
				nextBannerTimerResetAt(resetAt)
			elseif resetAt <= serverTime then
				local elapsedIntervals = math.floor((serverTime - resetAt) / BANNER_TIMER_DURATION) + 1
				resetAt += elapsedIntervals * BANNER_TIMER_DURATION
				nextBannerTimerResetAt(resetAt)
			end

			bannerSecondsRemaining(math.max(0, resetAt - serverTime))
			task.wait(0.2)
		end
	end)

	task.spawn(function()
		local ok, success, bannerData = pcall(function()
			return Net.SummonService.GetBanner.Invoke():await()
		end)

		if ok and success and bannerData then
			SummonUI.UpdateBanner(bannerData)
		elseif not ok then
			warn("[SummonUI] GetBanner failed: " .. tostring(success))
		end
	end)

	local summonTouch = workspace:WaitForChild("TouchZone"):WaitForChild("SummonTouch")
	summonZone = TouchZone.new(summonTouch)
	summonZone:Start()

	summonZone.Touched:Connect(function(player: Player)
		if player ~= Players.LocalPlayer then
			return
		end

		SummonUI.Open()
	end)

	summonZone.TouchEnded:Connect(function(player: Player)
		if player ~= Players.LocalPlayer then
			return
		end

		isProbabilityOpen(false)
		UIController:Close(VIEW_ID)
	end)
end

return SummonUI
