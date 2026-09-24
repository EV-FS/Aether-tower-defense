local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)
local TraitData = require(ReplicatedStorage.Settings.Data.TraitData)
local UnitCatalog = require(ReplicatedStorage.Settings.Data.UnitCatalog)
local UnitViewportProfiles = require(ReplicatedStorage.Settings.Visuals.UnitViewportProfiles)
local NumberUtils = require(ReplicatedStorage.Shared.Modules.Utils.NumberUtils)
local RarityRegistry = require(ReplicatedStorage.Shared.Modules.Core.Rarity.RarityRegistry)
local CardFrame = require(ReplicatedStorage.UI.Components.Card.CardFrame)
local TowerViewport = require(ReplicatedStorage.UI.Components.TowerViewport)

local create = Vide.create
local read = Vide.read
local show = Vide.show
local spring = Vide.spring

return function(props)
	local performanceMode = props.PerformanceMode == true
	local towerInfo = TowerData.ByName[props.TowerName]
	local rarity = UnitCatalog.GetRarity(props.TowerName)
	local viewportProfile = UnitViewportProfiles.GetCard(props.TowerName)
	local usePortraitBounds = viewportProfile.BoundsMode == "Portrait"
	local useCharacterBounds = viewportProfile.BoundsMode == "Character"
	local isInWindow = props.IsInWindow or function() return true end
	local animateWindowVisibility = props.IsInWindow ~= nil and not performanceMode
	local shouldRenderViewport = function()
		return isInWindow() and (props.LiveViewport == nil or read(props.LiveViewport) == true)
	end
	local function windowSpring(openValue, closedValue, period: number, damping: number)
		if not animateWindowVisibility then
			return openValue
		end
		return spring(function()
			return if isInWindow() then openValue else closedValue
		end, period, damping)
	end
	local cost = if towerInfo
			and towerInfo.Stats
			and towerInfo.Stats[0]
			and towerInfo.Stats[0].Cost
		then towerInfo.Stats[0].Cost
		elseif
			towerInfo
			and towerInfo.Stats
			and towerInfo.Stats[1]
			and towerInfo.Stats[1].Cost
		then towerInfo.Stats[1].Cost
		else 0
	local level = if props.TowerData and typeof(props.TowerData.Lv) == "number" then props.TowerData.Lv else 0
	local traitName = if props.TowerData then props.TowerData.Trait else nil
	local traitInfo = if traitName then TraitData.ByName[traitName] else nil
	local gradient = RarityRegistry.Get(rarity).Presentation.Gradient
	local traitGradient = if traitInfo
		then RarityRegistry.Get(traitInfo.Rarity).Presentation.Gradient
		else RarityRegistry.Get("Common").Presentation.Gradient

	return CardFrame({
		Bind = props.Bind,
		Name = props.Name or "ImageButton",
		Image = "rbxassetid://87496848270095",
		ImageTransparency = windowSpring(0, 1, 0.5, 1),
		LayoutOrder = props.LayoutOrder or 0,
		Position = props.Position,
		Size = props.Size or UDim2.fromScale(0.186, 0.125),
		Activated = props.OnActivated,
		Rarity = rarity,
		PerformanceMode = performanceMode,
		ShimmerEnabled = not performanceMode,
		GlowEnabled = not performanceMode,
		HoverEnabled = not performanceMode,
		ButtonEffect = not performanceMode,
		Selected = props.IsSelected,
		ZIndex = function()
			if props.IsSelected() then
				return 10
			elseif props.IsEquipped() then
				return 5
			end

			return 1
		end,
		Content = {
		create("ImageLabel")({
			Name = "TowerImageFallback",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = UnitCatalog.GetImage(props.TowerName),
			Position = UDim2.fromScale(0.5, 0.51),
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromScale(0.9, 0.9),
			Visible = function() return not shouldRenderViewport() end,
			ZIndex = 5,
		}),

		show(shouldRenderViewport, function()
		return TowerViewport({
			Name = "TowerImage",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = windowSpring(UDim2.fromScale(0.5, 0.51), UDim2.fromScale(0.5, 0.69), 0.3, 0.9),
			Size = UDim2.fromScale(0.9, 0.9),
			TowerName = props.TowerName,
			Active = shouldRenderViewport,
			UseViewportModel = true,
			UseCharacterBounds = useCharacterBounds,
			UsePortraitBounds = usePortraitBounds,
			PortraitUpdateInterval = if performanceMode then 1 / 20 else 0,
			CenterOnRoot = not viewportProfile.CenterOnBounds,
			RenderEffects = false,
			FitPadding = viewportProfile.FitPadding,
			FieldOfView = 35,
			FocusYOffset = viewportProfile.FocusYOffset,
			CameraDirection = Vector3.new(0, 0, -1),
			ModelRotation = 15,
			AnimationName = "Idle",
			AnimationLevel = level,
			AnimationFadeTime = 0,
			AnimationLooped = true,
			AnimationSpeed = 1,
			Ambient = Color3.fromRGB(205, 205, 205),
			ZIndex = 5,
		})
		end),

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
			Text = string.upper(rarity),
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 10,

			create("UIGradient")({
				Color = gradient,
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
			Position = UDim2.fromScale(0.107999, 0.618754),
			Size = UDim2.fromScale(0.84887, 0.172688),
			Text = props.TowerName or "Unknown",
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 10,

			create("UIStroke")({
				Name = "UIStroke",
				Thickness = 2,
			}),
		}),

		--[[create("UIAspectRatioConstraint")({
			Name = "UIAspectRatioConstraint",
		}),--]]

		create("ImageLabel")({
			Name = "Level",
			BackgroundTransparency = 1,
			Image = "rbxassetid://104083646922843",
			Position = UDim2.fromScale(-0.0129994, -0.05),
			Size = UDim2.fromScale(0.653434, 0.238322),
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
				Text = `Lvl {level}`,
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
			AnchorPoint = Vector2.new(1, 0),
			BackgroundTransparency = 1,
			Image = if traitInfo then traitInfo.Image else "",
			Position = UDim2.fromScale(0.975, 0.2),
			Size = UDim2.fromScale(0.24, 0.24),
			Visible = traitInfo ~= nil,
			ZIndex = 13,

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
			Name = "Cost",
			BackgroundTransparency = 1,
			FontFace = Font.new(
				"rbxasset://fonts/families/SourceSansPro.json",
				Enum.FontWeight.Bold,
				Enum.FontStyle.Normal
			),
			Position = UDim2.fromScale(0.108, 0.782623),
			Size = UDim2.fromScale(0.641, 0.2),
			Text = `₩{NumberUtils.FormatComma(cost)}`,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 10,

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
		create("ImageLabel")({
			Name = "EquippedCheck",
			AnchorPoint = Vector2.new(1, 0),
			BackgroundTransparency = 1,
			Image = "rbxassetid://91966631627808",
			Position = UDim2.fromScale(1.025, -0.025),
			Size = UDim2.fromScale(0.24, 0.24),
			Visible = props.IsEquipped,
			ZIndex = 14,
			create("UIAspectRatioConstraint")({}),
		}),

		create("ImageLabel")({
			Name = "Locked",
			AnchorPoint = Vector2.new(1, 0),
			BackgroundTransparency = 1,
			Image = "rbxassetid://70564113534462",
			Position = UDim2.fromScale(0.96, 0.04),
			Size = UDim2.fromScale(0.25, 0.25),
			Visible = props.IsLocked or false,
			ZIndex = 12,
			create("UIAspectRatioConstraint")({}),
		}),
		},
	})
end
