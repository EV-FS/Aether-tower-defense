local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)
local UnitCatalog = require(ReplicatedStorage.Settings.Data.UnitCatalog)
local NumberUtils = require(ReplicatedStorage.Shared.Modules.Utils.NumberUtils)
local RarityGradient = require(ReplicatedStorage.Settings.Visuals.RarityGradient)
local useButtonEffect = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useButtonEffect)
local useColorSequenceCycle = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useColorSequenceCycle)

local create = Vide.create
local spring = Vide.spring

return function(props)
	local towerInfo = TowerData.ByName[props.TowerName]
	local rarity = UnitCatalog.GetRarity(props.TowerName)
	local unitImage = UnitCatalog.GetImage(props.TowerName)
	local isInWindow = props.IsInWindow or function() return true end
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
	local gradient = RarityGradient.Gradients[rarity] or RarityGradient.Gradients.Common
	local shimmerSpeed = RarityGradient.ShimmerSpeed[rarity] or 0.75

	return create("ImageButton")({
		props.Bind,

		Name = "ImageButton",
		BackgroundTransparency = 1,
		Image = "",

		LayoutOrder = props.LayoutOrder or 0,
		Size = UDim2.fromScale(0.186, 0.125),
		MouseButton1Click = props.OnActivated,
		ZIndex = function()
			if props.IsSelected() then
				return 10
			elseif props.IsEquipped() then
				return 5
			end

			return 1
		end,

		useButtonEffect(),

		create("UICorner")({
			CornerRadius = UDim.new(0.08),
		}),

		create("ImageLabel")({
			Name = "TowerImage",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,

			Position = spring(function()
				return if isInWindow() then UDim2.fromScale(0.5, 0.5) else UDim2.fromScale(0.5, 0.7)
			end, 0.3, 0.9),
			Size = UDim2.fromScale(1, 1),

			Image = unitImage,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 5,
			ImageTransparency = spring(function()
				return if isInWindow() then 0 else 1
			end, 0.5, 1),
		}),

		create("ImageLabel")({
			Name = "BG",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Rotation = spring(function()
				return if isInWindow() then 0 else -10
			end, 0.5, 1),

			Size = spring(function()
				return if isInWindow() then UDim2.fromScale(1, 1) else UDim2.fromScale(0.8, 0.8)
			end, 0.5, 1),

			Position = UDim2.fromScale(0.5, 0.5),
			Image = "rbxassetid://87496848270095",
			ImageTransparency = spring(function()
				return if isInWindow() then 0 else 1
			end, 0.5, 1),
			ZIndex = -1,

			create("UIGradient")({
				Name = "UIGradient",
				Rotation = 45,

				useColorSequenceCycle(gradient, shimmerSpeed, isInWindow),
			}),

			create("UIShadow")({
				BlurRadius = UDim.new(0.075),
				Color = function()
					return if props.IsEquipped() then Color3.new(0, 1, 0) else Color3.new(1, 1, 1)
				end,
				Transparency = spring(function()
					return if props.IsSelected() or props.IsEquipped() then 0.2 else 1
				end, 0.2, 1),
				ZIndex = -1,
			}),

			create("Frame")({
				Name = "SelectedEffect",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(0.95, 0.95),
				Position = UDim2.fromScale(0.5, 0.5),

				create("UICorner")({
					CornerRadius = UDim.new(0.08),
				}),

				create("UIStroke")({
					Color = function()
						return if props.IsEquipped() then Color3.new(0, 1, 0) else Color3.new(1, 1, 1)
					end,
					Thickness = 3,
					Transparency = spring(function()
						return if props.IsSelected() or props.IsEquipped() then 0 else 1
					end, 0.2, 1),
				}),
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
				Text = `Level {level}`,
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
		create("TextLabel")({
			Name = "EquippedSlot",
			AnchorPoint = Vector2.new(1, 0),
			BackgroundColor3 = Color3.fromRGB(34, 177, 76),
			BackgroundTransparency = 0.08,
			FontFace = Font.new(
				"rbxasset://fonts/families/SourceSansPro.json",
				Enum.FontWeight.Bold,
				Enum.FontStyle.Normal
			),
			Position = UDim2.fromScale(0.95, 0.055),
			Size = UDim2.fromScale(0.3, 0.13),
			Text = function()
				local slot = props.EquippedSlot and props.EquippedSlot()
				return if slot then `SLOT {slot}` else ""
			end,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			Visible = props.IsEquipped,
			ZIndex = 11,

			create("UICorner")({
				CornerRadius = UDim.new(0.25, 0),
			}),

			create("UIStroke")({
				Color = Color3.fromRGB(14, 72, 32),
				Thickness = 1.5,
			}),
		}),

	})
end
