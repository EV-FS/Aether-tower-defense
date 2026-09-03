local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local useButtonEffect = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useButtonEffect)
local useColorSequenceCycle = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useColorSequenceCycle)
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

local VIEW_ID = "Summon"
local EXIT_DURATION = 0.38
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

local function createRarityGradient(rarity: string, animated: boolean?)
	local colors = RARITY_GRADIENTS[rarity] or RARITY_GRADIENTS.Common
	if animated then
		return create("UIGradient")({
			Name = "RarityGradient",
			Rotation = 45,
			useColorSequenceCycle(colors, 1.35, isOpen),
		})
	end

	return create("UIGradient")({
		Name = "RarityGradient",
		Color = colors,
		Rotation = 45,
	})
end

local function createUnitCard(rarity: string, layoutOrder: number)
	local entryDirection = layoutOrder - 2
	local entryPeriod = 0.34 + layoutOrder * 0.035

	return create("Frame")({
		Name = rarity .. "Card",
		BackgroundTransparency = 1,
		LayoutOrder = layoutOrder,
		Size = UDim2.fromScale(0.290764, 1),

		create("ImageLabel")({
			Name = "Shadow",
			BackgroundTransparency = 1,
			Image = CARD_SHADOW_IMAGE,
			ImageTransparency = spring(function()
				return if isOpen() then 0 else 1
			end, 0.3, 0.9),
			Position = spring(function()
				return if isOpen() then UDim2.fromScale(0.00631904, 0.106321) else UDim2.fromScale(0.00631904, 0.16)
			end, entryPeriod, 0.78),
			Size = UDim2.fromScale(1, 1),
			ZIndex = 1,

			create("UIAspectRatioConstraint")({}),
		}),

		TowerViewport({
			TowerName = function()
				return getUnitInfo(rarity).Name
			end,
			AnimationName = "Idle",
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			FitPadding = 1.04,
			ImageTransparency = spring(function()
				return if isOpen() then 0 else 1
			end, entryPeriod, 0.9),
			Position = spring(function()
				if isOpen() then
					return UDim2.fromScale(0.5, 0.84)
				end
				return UDim2.fromScale(0.5 + entryDirection * 0.12, 0.96)
			end, entryPeriod, 0.72),
			Size = UDim2.fromScale(0.92, 0.88),
			ModelRotation = spring(function()
				return if isOpen() then 0 else entryDirection * 55
			end, entryPeriod + 0.12, 0.68),
			ZIndex = 2,
		}),

		create("ImageLabel")({
			Name = "NamePlate",
			BackgroundTransparency = 1,
			Image = NAME_PLATE_IMAGE,
			ImageTransparency = spring(function()
				return if isOpen() then 0 else 1
			end, 0.3 + layoutOrder * 0.04, 0.9),
			Position = spring(function()
				return if isOpen()
					then UDim2.fromScale(0.176933, 0.647593)
					else UDim2.fromScale(0.176933, 0.76)
			end, entryPeriod, 0.74),
			Size = UDim2.fromScale(0.652453, 0.178427),
			ZIndex = 4,

			create("TextLabel")({
				Name = "UnitName",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = DISPLAY_FONT,
				Position = UDim2.fromScale(0.5, 0.31),
				Size = UDim2.fromScale(0.9, 0.37),
				Text = function()
					return getUnitInfo(rarity).Name
				end,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = 5,

				create("UIStroke")({
					Color = Color3.fromRGB(33, 30, 45),
					Thickness = 1.5,
				}),

				create("UITextSizeConstraint")({
					MaxTextSize = 25,
					MinTextSize = 8,
				}),
			}),

			create("TextLabel")({
				Name = "Grade",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = DISPLAY_FONT,
				Position = UDim2.fromScale(0.5, 0.7),
				Size = UDim2.fromScale(0.9, 0.3),
				Text = string.upper(rarity),
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				ZIndex = 5,

				create("UIStroke")({
					Color = Color3.fromRGB(30, 24, 42),
					Thickness = 1.5,
				}),

				createRarityGradient(rarity, true),
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
	position: UDim2,
	colors: ColorSequence,
	entryDelay: number
)
	return create("ImageButton")({
		Name = name,
		Active = function()
			return isOpen() and not summonInProgress()
		end,
		AnchorPoint = Vector2.new(0.5, 0.5),
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Image = PURCHASE_BUTTON_IMAGE,
		ImageColor3 = function()
			return if summonInProgress() then Color3.fromRGB(170, 170, 170) else Color3.new(1, 1, 1)
		end,
		Position = spring(function()
			return if isOpen() then position else position + UDim2.fromScale(0, 0.075)
		end, entryDelay, 0.76),
		Size = UDim2.fromScale(0.238867, 0.113861),
		ZIndex = 8,

		Activated = function()
			SummonUI.Summon(amount)
		end,

		useButtonEffect(0.92, 1.035),

		create("UIGradient")({
			Color = colors,
			Rotation = 90,
		}),

		create("TextLabel")({
			Name = "Action",
			BackgroundTransparency = 1,
			FontFace = DISPLAY_FONT,
			Position = UDim2.fromScale(0.0483483, 0.168285),
			Size = UDim2.fromScale(0.48, 0.699418),
			Text = title,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 9,

			create("UIStroke")({
				Color = Color3.fromRGB(48, 43, 28),
				Thickness = 1.5,
			}),
		}),

		create("TextLabel")({
			Name = "Cost",
			BackgroundTransparency = 1,
			FontFace = DISPLAY_FONT,
			Position = UDim2.fromScale(0.59, 0.278),
			Size = UDim2.fromScale(0.17, 0.498891),
			Text = tostring(cost),
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 9,

			create("UIStroke")({
				Color = Color3.fromRGB(48, 43, 28),
				Thickness = 1.5,
			}),
		}),

		create("ImageLabel")({
			Name = "Currency",
			BackgroundTransparency = 1,
			Image = CURRENCY_IMAGE,
			Position = UDim2.fromScale(0.775, 0.16),
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromScale(0.18, 0.68),
			ZIndex = 9,

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
	layoutOrder: number
)
	local animatedRatio = spring(function()
		return math.clamp(getRatio(), 0, 1)
	end, 0.34, 0.82)

	return create("Frame")({
		Name = name,
		BackgroundColor3 = Color3.fromRGB(26, 24, 43),
		BackgroundTransparency = 0.08,
		LayoutOrder = layoutOrder,
		Size = UDim2.fromScale(1, 0.285),
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
	if summonInProgress() then
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
			SummonResultUI.ShowResults(pulledUnits)
		end
	end)
end

function SummonUI.RenderUI()
	local isMountedSource = source(false)
	local isAnimatedOpen = source(false)
	local mounted = false
	local visibilityToken = 0

	effect(function()
		local shouldOpen = isOpen()
		visibilityToken += 1
		local token = visibilityToken

		if shouldOpen then
			if not mounted then
				mounted = true
				isAnimatedOpen(false)
				isMountedSource(true)
				task.defer(function()
					if token == visibilityToken and mounted then
						isAnimatedOpen(true)
					end
				end)
			else
				isAnimatedOpen(true)
			end
			return
		end

		isAnimatedOpen(false)
		isProbabilityOpen(false)
		if not mounted then
			return
		end

		task.delay(EXIT_DURATION, function()
			if token ~= visibilityToken or isAnimatedOpen() then
				return
			end
			mounted = false
			isMountedSource(false)
		end)
	end)

	cleanup(function()
		visibilityToken += 1
	end)

	local windowScale = spring(function()
		return if isAnimatedOpen() then 1 else 0.76
	end, 0.34, 0.74)
	local windowTransparency = spring(function()
		return if isAnimatedOpen() then 0 else 1
	end, 0.24, 0.92)
	local ratesTransparency = spring(function()
		return if isAnimatedOpen() and isProbabilityOpen() then 0 else 1
	end, 0.2, 0.9)
	local ratesScale = spring(function()
		return if isAnimatedOpen() and isProbabilityOpen() then 1 else 0.82
	end, 0.28, 0.74)
	local statusTransparency = spring(function()
		return if isAnimatedOpen() then 0 else 1
	end, 0.3, 0.88)
	local statusScale = spring(function()
		return if isAnimatedOpen() then 1 else 0.78
	end, 0.38, 0.7)

	return create("CanvasGroup")({
		Name = "Container",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		GroupTransparency = windowTransparency,
		Interactable = isAnimatedOpen,
		Position = spring(function()
			return if isAnimatedOpen() then UDim2.fromScale(0.5, 0.5) else UDim2.fromScale(0.5, 0.575)
		end, 0.36, 0.76),
		Rotation = spring(function()
			return if isAnimatedOpen() then 0 else -4
		end, 0.4, 0.7),
		Size = UDim2.fromScale(1, 1),
		Visible = isMountedSource,

		create("UIAspectRatioConstraint")({
			AspectRatio = 1.547,
			AspectType = Enum.AspectType.ScaleWithParentSize,
		}),

		create("ImageLabel")({
			Name = "Main",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = MAIN_IMAGE,
			Position = UDim2.fromScale(0.498839, 0.536386),
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
				Position = spring(function()
					return if isAnimatedOpen()
						then UDim2.fromScale(-0.0573612, -0.111321)
						else UDim2.fromScale(-0.12, -0.22)
				end, 0.34, 0.7),
				Size = UDim2.fromScale(0.692821, 0.28349),
				ZIndex = 10,

				create("ImageLabel")({
					Name = "Helmet",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = HELMET_IMAGE,
					Position = UDim2.fromScale(0.125303, 0.46739),
					Rotation = spring(function()
						return if isAnimatedOpen() then 0 else -28
					end, 0.3, 0.66),
					Size = UDim2.fromScale(0.125872, 0.58156),

					create("UIAspectRatioConstraint")({}),
				}),

				create("ImageLabel")({
					Name = "Cloud",
					BackgroundTransparency = 1,
					Image = CLOUD_IMAGE,
					Position = spring(function()
						return if isAnimatedOpen()
							then UDim2.fromScale(0.529887, 0.0551715)
							else UDim2.fromScale(0.68, 0.01)
					end, 0.42, 0.72),
					Size = UDim2.fromScale(0.537766, 1.06417),

					create("UIAspectRatioConstraint")({
						AspectRatio = 2.16,
					}),
				}),

				create("TextLabel")({
					Name = "Title",
					BackgroundTransparency = 1,
					FontFace = DISPLAY_FONT,
					Position = UDim2.fromScale(0.265238, 0.435573),
					Size = UDim2.fromScale(0.283423, 0.290134),
					Text = "SUMMON",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Left,

					create("UIStroke")({
						Color = Color3.fromRGB(39, 33, 58),
						Thickness = 1.5,
					}),
				}),

				create("ImageLabel")({
					Name = "Sword",
					BackgroundTransparency = 1,
					Image = SWORD_IMAGE,
					Position = spring(function()
						return if isAnimatedOpen()
							then UDim2.fromScale(0.01, -0.312)
							else UDim2.fromScale(-0.08, -0.48)
					end, 0.38, 0.68),
					Rotation = spring(function()
						return if isAnimatedOpen() then 0 else -18
					end, 0.34, 0.65),
					Size = UDim2.fromScale(0.251814, 1.53914),

					create("UIAspectRatioConstraint")({
						AspectRatio = 0.77,
					}),
				}),
			}),

			create("ImageButton")({
				Name = "CancelButton",
				AnchorPoint = Vector2.new(0.5, 0.5),
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				Image = CLOSE_IMAGE,
				Position = spring(function()
					return if isAnimatedOpen()
						then UDim2.fromScale(0.980096, 0.0289194)
						else UDim2.fromScale(1.07, -0.06)
				end, 0.31, 0.68),
				Rotation = spring(function()
					return if isAnimatedOpen() then 0 else 45
				end, 0.28, 0.64),
				Size = UDim2.fromScale(0.102144, 0.15458),
				ZIndex = 12,

				Activated = function()
					UIController:Close(VIEW_ID)
				end,

				useButtonEffect(0.88, 1.08),

				create("UIAspectRatioConstraint")({}),
			}),

			create("ImageLabel")({
				Name = "Banner",
				BackgroundTransparency = 1,
				Image = BANNER_IMAGE,
				ImageTransparency = spring(function()
					return if isAnimatedOpen() then 0 else 0.4
				end, 0.28, 0.86),
				Position = spring(function()
					return if isAnimatedOpen()
						then UDim2.fromScale(0.0334857, 0.172169)
						else UDim2.fromScale(0.0334857, 0.235)
				end, 0.38, 0.75),
				Size = UDim2.fromScale(0.932419, 0.666445),
				ZIndex = 2,

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
				"OnePickButton",
				1,
				"SUMMON",
				ONE_PULL_COST,
				UDim2.fromScale(0.152616, 0.905),
				ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(55, 255, 0)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 238, 1)),
				}),
				0.34
			),

			createPurchaseButton(
				"TenPickButton",
				10,
				"X10",
				TEN_PULL_COST,
				UDim2.fromScale(0.406167, 0.905),
				ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(108, 108, 108)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(48, 48, 48)),
				}),
				0.4
			),

			create("CanvasGroup")({
				Name = "SummonStatus",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(20, 18, 36),
				BackgroundTransparency = 0.12,
				GroupTransparency = statusTransparency,
				Position = spring(function()
					return if isAnimatedOpen()
						then UDim2.fromScale(0.711, 0.905)
						else UDim2.fromScale(0.711, 1.03)
				end, 0.42, 0.7),
				Size = UDim2.fromScale(0.285, 0.126),
				ZIndex = 9,

				create("UIScale")({
					Scale = statusScale,
				}),

				create("UICorner")({
					CornerRadius = UDim.new(0.08, 0),
				}),

				create("UIStroke")({
					Color = Color3.fromRGB(116, 107, 170),
					Thickness = 1.2,
					Transparency = function()
						return 0.3 + (0.7 * statusTransparency())
					end,
				}),

				create("UIPadding")({
					PaddingBottom = UDim.new(0.07, 0),
					PaddingLeft = UDim.new(0.035, 0),
					PaddingRight = UDim.new(0.035, 0),
					PaddingTop = UDim.new(0.07, 0),
				}),

				create("UIListLayout")({
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Padding = UDim.new(0.04, 0),
					SortOrder = Enum.SortOrder.LayoutOrder,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),

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
					1
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
					2
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
					3
				),
			}),

			create("ImageButton")({
				Name = "DropRateButton",
				AnchorPoint = Vector2.new(0.5, 0.5),
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				Image = PROBABILITY_BUTTON_IMAGE,
				Position = spring(function()
					return if isAnimatedOpen()
						then UDim2.fromScale(0.925, 0.905)
						else UDim2.fromScale(0.925, 1.05)
				end, 0.34, 0.68),
				Rotation = spring(function()
					return if isProbabilityOpen() then 45 else 0
				end, 0.28, 0.72),
				Size = UDim2.fromScale(0.075, 0.112),
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
					return isAnimatedOpen() and (isProbabilityOpen() or ratesTransparency() < 0.995)
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
	local zone = TouchZone.new(summonTouch)
	zone:Start()

	zone.Touched:Connect(function(player: Player)
		if player ~= Players.LocalPlayer then
			return
		end

		SummonUI.Open()
	end)

	zone.TouchEnded:Connect(function(player: Player)
		if player ~= Players.LocalPlayer then
			return
		end

		UIController:Close(VIEW_ID)
	end)
end

return SummonUI
