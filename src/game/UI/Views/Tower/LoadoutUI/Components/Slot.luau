local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)
local UnitCatalog = require(ReplicatedStorage.Settings.Data.UnitCatalog)
local RarityGradient = require(ReplicatedStorage.Settings.Visuals.RarityGradient)
local TowerViewport = require(ReplicatedStorage.UI.Components.TowerViewport)
local useButtonEffect = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useButtonEffect)
local useColorSequenceCycle = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useColorSequenceCycle)
local useDiagonalShine = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useDiagonalShine)
local NumberUtils = require(ReplicatedStorage.Shared.Modules.Utils.NumberUtils)

local create = Vide.create
local derive = Vide.derive
local source = Vide.source
local spring = Vide.spring

local EMPTY_GRADIENT = ColorSequence.new(Color3.fromRGB(72, 76, 86))

local EFFECT_LEVELS = { Common = 1, Rare = 2, Epic = 3, Legendary = 4, Mythic = 5, Secret = 5, Absolute = 6 }
local SHINE_COLORS = {
	Common = Color3.fromRGB(178, 178, 178), Rare = Color3.fromRGB(38, 132, 255),
	Epic = Color3.fromRGB(214, 52, 255), Legendary = Color3.fromRGB(255, 168, 24),
	Mythic = Color3.fromRGB(255, 31, 92), Secret = Color3.fromRGB(255, 31, 92), Absolute = Color3.fromRGB(121, 225, 255),
}
local SHINE_GRADIENTS = {
	Common = ColorSequence.new(Color3.fromRGB(155, 155, 155), Color3.fromRGB(215, 215, 215)),
	Rare = ColorSequence.new(Color3.fromRGB(18, 78, 255), Color3.fromRGB(28, 220, 255)),
	Epic = ColorSequence.new(Color3.fromRGB(126, 45, 255), Color3.fromRGB(255, 35, 185)),
	Legendary = ColorSequence.new(Color3.fromRGB(255, 105, 18), Color3.fromRGB(255, 238, 61)),
	Mythic = ColorSequence.new(Color3.fromRGB(255, 20, 27), Color3.fromRGB(255, 36, 185)),
	Secret = ColorSequence.new(Color3.fromRGB(255, 20, 27), Color3.fromRGB(255, 36, 185)),
	Absolute = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(73, 220, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 244, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(199, 82, 255)),
	}),
}

local LOBBY_SHINE_MOTION = {
	startPosition = UDim2.fromScale(-0.58, -0.46),
	endPosition = UDim2.fromScale(1.58, 1.46),
	duration = 6.2,
	restInterval = 2.4,
}

local function createGlowLine(name: string, color: () -> ColorSequence, positionX: number, width: number, transparency: () -> number)
	return create("Frame")({
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = transparency,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(positionX, 0.5),
		Size = UDim2.fromScale(width, 1),
		ZIndex = 4,

		create("UIGradient")({
			Color = color,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.16, 0.96),
				NumberSequenceKeypoint.new(0.5, 0.22),
				NumberSequenceKeypoint.new(0.84, 0.96),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})
end

local function createLobbyShine(color: () -> ColorSequence, transparency: () -> number, active: () -> boolean, delay: number)
	return create("Frame")({
		Name = "WideDiagonalLights",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Rotation = 18,
		Size = UDim2.fromScale(1.05, 1.62),
		ZIndex = 4,

		createGlowLine("LeadingGlow", color, 0.2, 0.76, transparency),
		createGlowLine("TrailingGlow", color, 0.8, 0.68, function()
			return math.min(transparency() + 0.06, 0.92)
		end),
		useDiagonalShine(active, 1, delay, LOBBY_SHINE_MOTION),
	})
end

export type Props = {
	slotNumber: number,
	loadout: () -> {},
	ownedTowers: () -> {},
	playerCash: () -> number,
	Activated: () -> (),
}

return function(props: Props)
	local tower = derive(function()
		local currentLoadout = props.loadout()
		return currentLoadout[tostring(props.slotNumber)] or currentLoadout[props.slotNumber]
	end)
	local towerName = derive(function()
		local equipped = tower()
		return if equipped then equipped.Name or equipped.towerName or "" else ""
	end)
	local hasTower = derive(function()
		return tower() ~= nil
	end)
	local rarity = derive(function()
		local t = tower()
		if not t then
			return "Common"
		end

		local towerName = t.Name or t.towerName
		return UnitCatalog.GetRarity(towerName)
	end)
	local imageTint = derive(function()
		return if hasTower() then Color3.new(1, 1, 1) else Color3.new(0.75, 0.75, 0.75)
	end)
	local backgroundGradient = derive(function()
		if not hasTower() then
			return EMPTY_GRADIENT
		end

		return RarityGradient.Gradients[rarity()] or RarityGradient.Gradients.Common
	end)
	local shimmerSpeed = derive(function()
		return RarityGradient.ShimmerSpeed[rarity()] or 0.75
	end)
	local gradientTransitionTime = derive(function()
		return 3.4 / shimmerSpeed()
	end)
	local towerLevel = derive(function()
		local t = tower()
		if not t then
			return 0
		end

		local towerName = t.Name or t.towerName
		local towerKey = t.Key or t.towerKey

		local ownedTowersData = props.ownedTowers()
		if towerName and towerKey and ownedTowersData[towerName] then
			local keyText = tostring(towerKey)
			local keyId = keyText:match("^t_(%d+)$") or keyText:match("^(%d+)$")
			local towerData = ownedTowersData[towerName][towerKey]
				or ownedTowersData[towerName][keyText]
				or (keyId and ownedTowersData[towerName][`t_{keyId}`])
			if towerData and towerData.Lv then
				return towerData.Lv
			end
		end

		return 0
	end)
	local towerCostValue = derive(function()
		local t = tower()
		if not t then
			return 0
		end

		local towerName = t.Name or t.towerName
		local towerInfo = TowerData.ByName[towerName]
		local cost = 0
		if towerInfo and towerInfo.Stats and towerInfo.Stats[0] then
			cost = towerInfo.Stats[0].Cost or 0
		end
		return cost
	end)
	local towerCost = derive(function()
		return `${NumberUtils.FormatComma(towerCostValue())}`
	end)
	local canAfford = derive(function()
		return not hasTower() or props.playerCash() >= towerCostValue()
	end)
	local missingCashRatio = derive(function()
		local cost = towerCostValue()
		if not hasTower() or cost <= 0 then
			return 0
		end

		return math.clamp(1 - math.max(props.playerCash(), 0) / cost, 0, 1)
	end)
	local animatedMissingRatio = spring(missingCashRatio, 0.16, 0.82)
	local edgeTransparency = spring(function()
		local ratio = missingCashRatio()
		return if ratio > 0.001 and ratio < 0.999 then 0.48 else 1
	end, 0.16, 0.82)
	local effectLevel = derive(function() return if hasTower() then EFFECT_LEVELS[rarity()] or 1 else 0 end)
	local shineColor = derive(function() return SHINE_COLORS[rarity()] or SHINE_COLORS.Common end)
	local shineGradient = derive(function() return SHINE_GRADIENTS[rarity()] or SHINE_GRADIENTS.Common end)
	local shineTransparency = derive(function() return 0.38 end)
	local cyclesGradient = derive(function() return hasTower() and effectLevel() >= EFFECT_LEVELS.Epic end)
	local rarityStrokeTransparency = derive(function() return if hasTower() then math.max(0.82 - effectLevel() * 0.135, 0.02) else 1 end)
	local rarityStrokeThickness = derive(function() return 0.75 + effectLevel() * 0.27 end)
	local rarityGlowTransparency = derive(function() return if hasTower() and effectLevel() > 1 then math.max(1.04 - effectLevel() * 0.115, 0.32) else 1 end)
	local rarityGlowRadius = derive(function() return UDim.new(0.018 + effectLevel() * 0.008, 0) end)
	local isHovered = source(false)
	local hoverTransparency = spring(function() return if isHovered() then 0.72 else 1 end, 0.16, 0.82)
	local hoverStrokeTransparency = spring(function() return if isHovered() then 0.05 else 1 end, 0.14, 0.8)
	local hoverRotation = spring(function() return if isHovered() then -1.5 else 0 end, 0.18, 0.78)

	return create("ImageButton")({
		Name = `Slot{props.slotNumber}`,
		Active = true,
		BackgroundTransparency = 1,
		ClipsDescendants = false,
		Image = "rbxassetid://87496848270095",
		ImageTransparency = function() return if hasTower() then 0 else 0.2 end,
		ImageColor3 = imageTint,
		LayoutOrder = props.slotNumber,
		Rotation = hoverRotation,
		Size = UDim2.fromScale(0.92, 0.92),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		ZIndex = 1,

		Activated = props.Activated,
		MouseEnter = function() isHovered(true) end,
		MouseLeave = function() isHovered(false) end,

		useButtonEffect(0.93, 1.07),

		create("UIGradient")({
			Name = "RarityGradient", Rotation = 45,
			useColorSequenceCycle(backgroundGradient, gradientTransitionTime, cyclesGradient),
		}),
		create("UIShadow")({
			Name = "RarityGlow", BlurRadius = rarityGlowRadius,
			Color = shineColor, Transparency = rarityGlowTransparency, ZIndex = -1,
		}),
		create("UIStroke")({
			Name = "RarityStroke", ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = Color3.new(1, 1, 1),
			Thickness = rarityStrokeThickness, Transparency = rarityStrokeTransparency,
			create("UIGradient")({ Name = "RarityStrokeGradient", Rotation = 45, useColorSequenceCycle(shineGradient, gradientTransitionTime, cyclesGradient) }),
		}),
		create("UICorner")({ Name = "HoverCorner", CornerRadius = UDim.new(0, 8) }),
		create("ImageLabel")({
			Name = "HoverHighlight", Active = false, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1,
			Image = "rbxassetid://87496848270095", ImageTransparency = hoverTransparency,
			Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.95, 0.95), ZIndex = 2,
			create("UICorner")({ CornerRadius = UDim.new(0, 8) }),
			create("UIGradient")({ Color = shineGradient, Rotation = 45 }),
		}),
		create("UIStroke")({ Name = "HoverStroke", Color = Color3.new(1, 1, 1), Thickness = 2, Transparency = hoverStrokeTransparency }),

		create("UIAspectRatioConstraint")({}),

		create("TextLabel")({
			Name = "Num",
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.ExtraBold),
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromScale(0.68, 0.07),
			Size = UDim2.fromScale(0.25, 0.14),
			Text = `[{props.slotNumber}]`,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 5,
			create("UIStroke")({}),
		}),

		create("ImageLabel")({
			Name = "LevelBadge",
			BackgroundTransparency = 1,
			Image = "rbxassetid://104083646922843",
			Position = UDim2.fromScale(-0.013, -0.05),
			Size = UDim2.fromScale(0.653434, 0.238322),
			Visible = hasTower,
			ZIndex = 10,

			create("UIAspectRatioConstraint")({ AspectRatio = 3.2 }),
			create("TextLabel")({
				Name = "Level",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold),
				Position = UDim2.fromScale(0.3, 0.489),
				Size = UDim2.fromScale(0.477775, 0.75514),
				Text = function() return `Level {towerLevel()}` end,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				create("UIStroke")({ Thickness = 2 }),
			}),
		}),

		create("TextLabel")({
			Name = "Price",
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold),
			Position = UDim2.fromScale(0.108, 0.782623),
			Size = UDim2.fromScale(0.641, 0.2),

			Visible = hasTower,
			Text = towerCost,

			TextColor3 = function()
				return if canAfford() then Color3.new(1, 1, 1) else Color3.fromRGB(255, 62, 62)
			end,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 5,
			create("UIStroke")({ Thickness = 2 }),
		}),

		TowerViewport({
			Name = "UnitViewport",
			BackgroundTransparency = 1,
			TowerName = towerName,
			AnimationName = "Idle",
			AnimationLevel = towerLevel,
			UseViewportModel = true,
			UseCharacterBounds = true,
			FitPadding = 1.1,
			Position = UDim2.fromScale(0.11, 0.102),
			Size = UDim2.fromScale(0.784, 0.781),
			ZIndex = 5,
			Visible = hasTower,
		}),

		create("CanvasGroup")({
			Name = "DiagonalShineMask",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			GroupTransparency = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.94, 0.94),
			Visible = hasTower,
			ZIndex = 4,

			create("UICorner")({
				Name = "ShineCorner",
				CornerRadius = UDim.new(0, 8),
			}),
			createLobbyShine(shineGradient, shineTransparency, hasTower, (props.slotNumber - 1) * 0.24),
		}),

		create("Frame")({
			Name = "AffordabilityMask",
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Position = UDim2.fromScale(0.055, 0.055),
			Size = UDim2.fromScale(0.89, 0.89),
			Visible = hasTower,
			ZIndex = 3,

			create("UICorner")({
				CornerRadius = UDim.new(0.12, 0),
			}),

			create("Frame")({
				Name = "MissingCashFill",
				AnchorPoint = Vector2.new(0, 1),
				BackgroundColor3 = Color3.fromRGB(3, 5, 8),
				BackgroundTransparency = 0.3,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0, 1),
				Size = function()
					return UDim2.fromScale(1, math.clamp(animatedMissingRatio(), 0, 1))
				end,
				ZIndex = 3,

				create("UIGradient")({
					Rotation = 90,
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 0.12),
						NumberSequenceKeypoint.new(0.25, 0.02),
						NumberSequenceKeypoint.new(1, 0),
					}),
				}),

				create("Frame")({
					Name = "ProgressEdge",
					BackgroundColor3 = Color3.fromRGB(235, 241, 255),
					BackgroundTransparency = edgeTransparency,
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, 1),
					ZIndex = 4,

					create("UIGradient")({
						Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 1),
							NumberSequenceKeypoint.new(0.18, 0.25),
							NumberSequenceKeypoint.new(0.5, 0),
							NumberSequenceKeypoint.new(0.82, 0.25),
							NumberSequenceKeypoint.new(1, 1),
						}),
					}),
				}),
			}),
		}),

		create("TextLabel")({
			Name = "Rarity",
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold),
			Position = UDim2.fromScale(0.108, 0.535),
			Size = UDim2.fromScale(0.7, 0.105),
			Text = function() return string.upper(rarity()) end,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Visible = hasTower,
			ZIndex = 10,
			create("UIGradient")({ Color = backgroundGradient }),
			create("UIStroke")({ Thickness = 1.5 }),
		}),

		create("TextLabel")({
			Name = "Name",
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold),
			Position = UDim2.fromScale(0.108, 0.618754),
			Size = UDim2.fromScale(0.848871, 0.172688),
			Text = function()
				return towerName()
			end,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Visible = hasTower,
			ZIndex = 10,
			create("UIStroke")({ Thickness = 2 }),
		}),
	})
end
