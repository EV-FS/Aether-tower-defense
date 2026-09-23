local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)
local TraitData = require(ReplicatedStorage.Settings.Data.TraitData)
local UnitCatalog = require(ReplicatedStorage.Settings.Data.UnitCatalog)
local UnitViewportProfiles = require(ReplicatedStorage.Settings.Visuals.UnitViewportProfiles)
local TowerViewport = require(ReplicatedStorage.UI.Components.TowerViewport)
local RarityRegistry = require(ReplicatedStorage.Shared.Modules.Core.Rarity.RarityRegistry)
local CardFrame = require(ReplicatedStorage.UI.Components.Card.CardFrame)
local NumberUtils = require(ReplicatedStorage.Shared.Modules.Utils.NumberUtils)
local useDiagonalShine = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useDiagonalShine)

local create = Vide.create
local derive = Vide.derive

local EMPTY_BACKGROUND_GRADIENT = ColorSequence.new(Color3.fromRGB(72, 76, 86))

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
	local traitInfo = derive(function()
		local profile = towerProfile()
		return if profile and profile.Trait then TraitData.ByName[profile.Trait] else nil
	end)
	local traitGradient = derive(function()
		local info = traitInfo()
		return RarityRegistry.Get(if info then info.Rarity else "Common").Presentation.Gradient
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
	local viewportProfile = derive(function()
		return UnitViewportProfiles.GetCard(towerName())
	end)

	local shineGradient = derive(function()
		return RarityRegistry.Get(rarity()).Presentation.Gradient
	end)
	local shineTransparency = derive(function()
		return 0.38
	end)

	return CardFrame({
		Name = `Slot{props.slotNumber}`,
		Active = true,
		AnchorPoint = Vector2.new(0.5, 0.5),
		ClipsDescendants = false,
		Image = "rbxassetid://87496848270095",
		ImageColor3 = Color3.new(1, 1, 1),
		ImageTransparency = function()
			return if hasTower() then 0 else 0.2
		end,
		LayoutOrder = props.slotNumber,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.227, 0.935),
		ZIndex = 1,
		Activated = props.Activated,
		Rarity = rarity,
		RarityEnabled = hasTower,
		FallbackGradient = EMPTY_BACKGROUND_GRADIENT,
		CornerRadius = UDim.new(0, 8),
		HoverRotation = -1.5,
		PressedScale = 0.93,
		HoverScale = 1.07,
		Content = {

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
			Image = function()
				local info = traitInfo()
				return if info then info.Image else ""
			end,
			Position = UDim2.fromScale(0.64, 0.03),
			Size = UDim2.fromScale(0.359565, 0.31687),
			Visible = function()
				return traitInfo() ~= nil
			end,
			ZIndex = 12,

			create("UIAspectRatioConstraint")({
				Name = "UIAspectRatioConstraint",
			}),

			create("UIGradient")({
				Name = "RarityGradient",
				Color = traitGradient,
				Rotation = 30,
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
				Color = shineGradient,
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
			Active = hasTower,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			TowerName = towerName,
			AnimationName = "Idle",
			AnimationLevel = towerLevel,
			AnimationFadeTime = 0,
			AnimationLooped = true,
			AnimationSpeed = 1,
			UseViewportModel = true,
			UseCharacterBounds = function()
				return viewportProfile().BoundsMode == "Character"
			end,
			UsePortraitBounds = function()
				return viewportProfile().BoundsMode == "Portrait"
			end,
			CenterOnRoot = function()
				return not viewportProfile().CenterOnBounds
			end,
			RenderEffects = false,
			FitPadding = function()
				return viewportProfile().FitPadding
			end,
			FieldOfView = 35,
			FocusYOffset = function()
				return viewportProfile().FocusYOffset
			end,
			CameraDirection = Vector3.new(0, 0, -1),
			ModelRotation = 15,
			Ambient = Color3.fromRGB(205, 205, 205),
			Position = UDim2.fromScale(0.5, 0.51),
			Size = UDim2.fromScale(0.9, 0.9),
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
		},
	})
end
