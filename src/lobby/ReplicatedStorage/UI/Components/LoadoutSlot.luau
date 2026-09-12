local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)
local UnitCatalog = require(ReplicatedStorage.Settings.Data.UnitCatalog)
local TowerViewport = require(ReplicatedStorage.UI.Components.TowerViewport)
local RarityGradient = require(ReplicatedStorage.Settings.Visuals.RarityGradient)
local NumberUtils = require(ReplicatedStorage.Shared.Modules.Utils.NumberUtils)
local useButtonEffect = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useButtonEffect)
local useColorSequenceCycle = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useColorSequenceCycle)
local useDiagonalShine = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useDiagonalShine)

local create = Vide.create
local derive = Vide.derive
local source = Vide.source
local spring = Vide.spring

local EMPTY_BACKGROUND_GRADIENT = ColorSequence.new(Color3.fromRGB(72, 76, 86))

local EFFECT_LEVELS = {
	Common = 1,
	Rare = 2,
	Epic = 3,
	Legendary = 4,
	Mythic = 5,
	Exclusive = 5,
	Absolute = 6,
}

local SHINE_COLORS = {
	Common = Color3.fromRGB(178, 178, 178),
	Rare = Color3.fromRGB(38, 132, 255),
	Epic = Color3.fromRGB(214, 52, 255),
	Legendary = Color3.fromRGB(255, 168, 24),
	Mythic = Color3.fromRGB(255, 31, 92),
	Exclusive = Color3.fromRGB(255, 31, 92),
	Absolute = Color3.fromRGB(121, 225, 255),
}

local SHINE_GRADIENTS = {
	Common = ColorSequence.new(Color3.fromRGB(155, 155, 155), Color3.fromRGB(215, 215, 215)),
	Rare = ColorSequence.new(Color3.fromRGB(18, 78, 255), Color3.fromRGB(28, 220, 255)),
	Epic = ColorSequence.new(Color3.fromRGB(126, 45, 255), Color3.fromRGB(255, 35, 185)),
	Legendary = ColorSequence.new(Color3.fromRGB(255, 105, 18), Color3.fromRGB(255, 238, 61)),
	Mythic = ColorSequence.new(Color3.fromRGB(255, 20, 27), Color3.fromRGB(255, 36, 185)),
	Exclusive = ColorSequence.new(Color3.fromRGB(255, 20, 27), Color3.fromRGB(255, 36, 185)),
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

export type Props = {
	slotNumber: number,
	loadout: () -> { [string | number]: { Name: string?, Key: string?, towerName: string?, towerKey: string? }? },
	units: () -> { [string]: { [string | number]: any } },
	Activated: (() -> ())?,
}

local function createGlowLine(
	name: string,
	color: () -> ColorSequence,
	positionX: number,
	width: number,
	transparency: () -> number
)
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

local function createShinePair(
	name: string,
	color: () -> ColorSequence,
	transparency: () -> number,
	active: () -> boolean,
	delay: number
)
	return create("Frame")({
		Name = name,
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

return function(props: Props)
	local tower = derive(function()
		local currentLoadout = props.loadout()
		return currentLoadout[tostring(props.slotNumber)] or currentLoadout[props.slotNumber]
	end)

	local towerName = derive(function()
		local equipped = tower()
		if not equipped then
			return ""
		end

		return equipped.Name or equipped.towerName or ""
	end)

	local towerKey = derive(function()
		local equipped = tower()
		return if equipped then equipped.Key or equipped.towerKey else nil
	end)

	local towerProfile = derive(function()
		local name = towerName()
		local key = towerKey()
		local ownedOfType = props.units()[name]
		if not ownedOfType or key == nil then
			return nil
		end

		local keyText = tostring(key)
		local keyId = keyText:match("^t_(%d+)$") or keyText:match("^(%d+)$")
		return ownedOfType[key] or ownedOfType[keyText] or (keyId and ownedOfType[`t_{keyId}`]) or nil
	end)

	local towerLevel = derive(function()
		local profile = towerProfile()
		return if profile and typeof(profile.Lv) == "number" then profile.Lv else 0
	end)

	local hasTower = derive(function()
		return towerName() ~= ""
	end)

	local towerCost = derive(function()
		local towerInfo = TowerData.ByName[towerName()]
		local cost = towerInfo and towerInfo.Stats and towerInfo.Stats[0] and towerInfo.Stats[0].Cost or 0
		return `₩{NumberUtils.FormatComma(cost)}`
	end)

	local rarity = derive(function()
		return UnitCatalog.GetRarity(towerName())
	end)

	local backgroundGradient = derive(function()
		if not hasTower() then
			return EMPTY_BACKGROUND_GRADIENT
		end
		return RarityGradient.Gradients[rarity()] or RarityGradient.Gradients.Common
	end)

	local effectLevel = derive(function()
		return if hasTower() then EFFECT_LEVELS[rarity()] or EFFECT_LEVELS.Common else 0
	end)
	local shineColor = derive(function()
		return SHINE_COLORS[rarity()] or SHINE_COLORS.Common
	end)
	local shineGradient = derive(function()
		return SHINE_GRADIENTS[rarity()] or SHINE_GRADIENTS.Common
	end)
	local shineTransparency = derive(function()
		return 0.38
	end)
	local gradientCycleTime = derive(function()
		return math.max(5.4 - effectLevel() * 0.48, 2.5)
	end)
	local cyclesGradient = derive(function()
		return hasTower() and effectLevel() >= EFFECT_LEVELS.Epic
	end)
	local rarityStrokeTransparency = derive(function()
		return if hasTower() then math.max(0.82 - effectLevel() * 0.135, 0.02) else 1
	end)
	local rarityStrokeThickness = derive(function()
		return 0.75 + effectLevel() * 0.27
	end)
	local rarityGlowTransparency = derive(function()
		if not hasTower() or effectLevel() <= EFFECT_LEVELS.Common then
			return 1
		end
		return math.max(1.04 - effectLevel() * 0.115, 0.32)
	end)
	local rarityGlowRadius = derive(function()
		return UDim.new(0.018 + effectLevel() * 0.008, 0)
	end)

	local isHovered = source(false)
	local hoverTransparency = spring(function()
		return if isHovered() then 0.72 else 1
	end, 0.16, 0.82)
	local hoverStrokeTransparency = spring(function()
		return if isHovered() then 0.05 else 1
	end, 0.14, 0.8)
	local hoverRotation = spring(function()
		return if isHovered() then -1.5 else 0
	end, 0.18, 0.78)

	return create("ImageButton")({
		Name = `Slot{props.slotNumber}`,
		Active = true,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ClipsDescendants = false,
		Image = "rbxassetid://87496848270095",
		ImageColor3 = Color3.new(1, 1, 1),
		ImageTransparency = function()
			return if hasTower() then 0 else 0.2
		end,
		LayoutOrder = props.slotNumber,
		Position = UDim2.fromScale(0.5, 0.5),
		Rotation = hoverRotation,
		Size = UDim2.fromScale(0.227, 0.935),
		ZIndex = 1,

		Activated = props.Activated,
		MouseEnter = function()
			isHovered(true)
		end,
		MouseLeave = function()
			isHovered(false)
		end,

		useButtonEffect(0.93, 1.07),

		create("UIGradient")({
			Name = "RarityGradient",
			Rotation = 45,

			useColorSequenceCycle(backgroundGradient, gradientCycleTime, cyclesGradient),
		}),

		create("UIShadow")({
			Name = "RarityGlow",
			BlurRadius = rarityGlowRadius,
			Color = shineColor,
			Transparency = rarityGlowTransparency,
			ZIndex = -1,
		}),

		create("UIStroke")({
			Name = "RarityStroke",
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Color3.new(1, 1, 1),
			Thickness = rarityStrokeThickness,
			Transparency = rarityStrokeTransparency,

			create("UIGradient")({
				Name = "RarityStrokeGradient",
				Rotation = 45,

				useColorSequenceCycle(shineGradient, gradientCycleTime, cyclesGradient),
			}),
		}),

		create("UICorner")({
			Name = "HoverCorner",
			CornerRadius = UDim.new(0, 8),
		}),

		create("ImageLabel")({
			Name = "HoverHighlight",
			Active = false,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = "rbxassetid://87496848270095",
			ImageColor3 = Color3.new(1, 1, 1),
			ImageTransparency = hoverTransparency,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.95, 0.95),
			ZIndex = 2,

			create("UICorner")({
				Name = "UICorner",
				CornerRadius = UDim.new(0, 8),
			}),

			create("UIGradient")({
				Name = "HoverGradient",
				Color = shineGradient,
				Rotation = 45,
			}),
		}),

		create("UIStroke")({
			Name = "HoverStroke",
			Color = Color3.new(1, 1, 1),
			Thickness = 2,
			Transparency = hoverStrokeTransparency,
		}),

		create("UIAspectRatioConstraint")({
			Name = "UIAspectRatioConstraint",
		}),

		create("ImageLabel")({
			Name = "Level",
			BackgroundTransparency = 1,
			Image = "rbxassetid://104083646922843",
			Position = UDim2.fromScale(-0.013, -0.05),
			Size = UDim2.fromScale(0.653434, 0.238322),
			Visible = hasTower,
			ZIndex = 10,

			create("UIAspectRatioConstraint")({
				Name = "UIAspectRatioConstraint",
				AspectRatio = 3.2,
			}),

			create("TextLabel")({
				Name = "TextLabel",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/SourceSansPro.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(0.3, 0.489),
				Size = UDim2.fromScale(0.477775, 0.75514),
				Text = function()
					return `Level {towerLevel()}`
				end,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,

				create("UIStroke")({
					Name = "UIStroke",
					Thickness = 2,
				}),

				create("UIGradient")({
					Name = "UIGradient",
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(104, 106, 211)),
					}),
					Rotation = 90,
				}),
			}),
		}),

		create("ImageLabel")({
			Name = "Trait",
			BackgroundTransparency = 1,
			Image = "rbxassetid://100463457721493",
			Position = UDim2.fromScale(0.64, 0.03),
			Size = UDim2.fromScale(0.359565, 0.31687),
			Visible = false,

			create("UIAspectRatioConstraint")({
				Name = "UIAspectRatioConstraint",
			}),
		}),

		create("TextLabel")({
			Name = "Price",
			BackgroundTransparency = 1,
			FontFace = Font.new(
				"rbxasset://fonts/families/SourceSansPro.json",
				Enum.FontWeight.Bold,
				Enum.FontStyle.Normal
			),
			Position = UDim2.fromScale(0.108, 0.782623),
			Size = UDim2.fromScale(0.641, 0.2),
			Text = towerCost,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 10,
			Visible = hasTower,

			create("UIStroke")({
				Name = "UIStroke",
				Thickness = 2,
			}),

			create("UIGradient")({
				Name = "UIGradient",
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 152, 62)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 160, 26)),
				}),
				Rotation = 90,
			}),
		}),

		create("TextLabel")({
			Name = "Rarity",
			BackgroundTransparency = 1,
			FontFace = Font.new(
				"rbxasset://fonts/families/SourceSansPro.json",
				Enum.FontWeight.Bold,
				Enum.FontStyle.Normal
			),
			Position = UDim2.fromScale(0.108, 0.535),
			Size = UDim2.fromScale(0.7, 0.105),
			Text = function()
				return string.upper(rarity())
			end,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Visible = hasTower,
			ZIndex = 10,

			create("UIGradient")({
				Color = backgroundGradient,
			}),

			create("UIStroke")({
				Thickness = 1.5,
			}),
		}),

		create("TextLabel")({
			Name = "Name",
			BackgroundTransparency = 1,
			FontFace = Font.new(
				"rbxasset://fonts/families/SourceSansPro.json",
				Enum.FontWeight.Bold,
				Enum.FontStyle.Normal
			),
			Position = UDim2.fromScale(0.108, 0.618754),
			Size = UDim2.fromScale(0.848871, 0.172688),
			Text = towerName,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 10,
			Visible = hasTower,

			create("UIStroke")({
				Name = "UIStroke",
				Thickness = 2,
			}),
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

			createShinePair(
				"WideDiagonalLights",
				shineGradient,
				shineTransparency,
				hasTower,
				(props.slotNumber - 1) * 0.24
			),
		}),
	})
end

