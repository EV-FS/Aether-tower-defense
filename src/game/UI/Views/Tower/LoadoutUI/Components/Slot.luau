local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)
local SummonConfig = require(ReplicatedStorage.Settings.Data.SummonConfig)
local RarityGradient = require(ReplicatedStorage.Settings.Visuals.RarityGradient)
local useButtonEffect = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useButtonEffect)
local useColorSequenceCycle = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useColorSequenceCycle)
local useDiagonalShine = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useDiagonalShine)
local NumberUtils = require(ReplicatedStorage.Shared.Modules.Utils.NumberUtils)

local create = Vide.create
local derive = Vide.derive
local spring = Vide.spring

local EMPTY_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(136, 136, 136)),
})

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
	local hasTower = derive(function()
		return tower() ~= nil
	end)
	local rarity = derive(function()
		local t = tower()
		if not t then
			return "Common"
		end

		local towerName = t.Name or t.towerName
		local towerInfo = TowerData.ByName[towerName]
		return towerInfo and towerInfo.Rarity or "Common"
	end)
	local imageTint = derive(function()
		return if hasTower() then Color3.new(1, 1, 1) else Color3.new(0.75, 0.75, 0.75)
	end)
	local backgroundGradient = derive(function()
		if not hasTower() then
			return EMPTY_GRADIENT
		end

		return SummonConfig.RarityGradients[rarity()] or SummonConfig.RarityGradients.Common
	end)
	local shimmerSpeed = derive(function()
		return RarityGradient.ShimmerSpeed[rarity()] or 0.75
	end)
	local gradientTransitionTime = derive(function()
		return 3.4 / shimmerSpeed()
	end)
	local towerImage = derive(function()
		local t = tower()
		if not t then
			return ""
		end

		local towerName = t.Name or t.towerName
		local towerInfo = TowerData.ByName[towerName]
		return if towerInfo then towerInfo.TowerImage else ""
	end)
	local towerLevel = derive(function()
		local t = tower()
		if not t then
			return "Lv.0"
		end

		local towerName = t.Name
		local towerKey = t.Key

		local ownedTowersData = props.ownedTowers()
		if towerName and towerKey and ownedTowersData[towerName] then
			local towerData = ownedTowersData[towerName][towerKey]
			if towerData and towerData.Lv then
				return `Lv.{towerData.Lv}`
			end
		end

		return `Lv.{0}`
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

	return create("ImageButton")({
		Name = `Slot{props.slotNumber}`,
		BackgroundTransparency = 1,
		Image = "rbxassetid://128510116496993",
		Size = UDim2.fromScale(1, 1),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		ImageColor3 = imageTint,

		Activated = props.Activated,

		create("UIAspectRatioConstraint")({}),

		create("TextLabel")({
			Name = "Num",
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.ExtraBold),
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromScale(0.13, 0.15),
			Size = UDim2.fromScale(0.4, 0.185),
			Text = `[{props.slotNumber}]`,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 5,
			create("UIStroke")({}),
		}),

		create("TextLabel")({
			Name = "Cost",
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.48, 0.86),
			Size = UDim2.fromScale(0.75, 0.175),

			Visible = hasTower,
			Text = towerCost,

			TextColor3 = function()
				return if canAfford() then Color3.new(1, 1, 1) else Color3.fromRGB(255, 62, 62)
			end,
			TextScaled = true,
			ZIndex = 5,
			create("UIStroke")({ Thickness = 2 }),
		}),

		create("ImageLabel")({
			Name = "UnitImage",
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.fromScale(1.1, 1.1),

			Visible = hasTower,
			Image = towerImage,
			ZIndex = 1,

			create("UIAspectRatioConstraint")({}),
		}),

		create("Frame")({
			Name = "RarityShineClip",
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Position = UDim2.fromScale(0.055, 0.055),
			Size = UDim2.fromScale(0.89, 0.89),
			Visible = hasTower,
			ZIndex = 2,

			create("UICorner")({
				CornerRadius = UDim.new(0.12, 0),
			}),

			create("Frame")({
				Name = "DiagonalShine",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 0.12,
				BorderSizePixel = 0,
				Rotation = 18,
				Size = UDim2.fromScale(0.2, 1.55),
				ZIndex = 2,

				create("UIGradient")({
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 1),
						NumberSequenceKeypoint.new(0.22, 0.85),
						NumberSequenceKeypoint.new(0.5, 0.2),
						NumberSequenceKeypoint.new(0.78, 0.85),
						NumberSequenceKeypoint.new(1, 1),
					}),
				}),

				useDiagonalShine(hasTower, shimmerSpeed, 0.25 + props.slotNumber * 0.16),
			}),
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
			Name = "Level",
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 0.7),
			Size = UDim2.fromScale(0.5, 0.14),

			Visible = hasTower,
			Text = towerLevel,

			TextColor3 = Color3.fromRGB(255, 170, 0),
			TextScaled = true,
			ZIndex = 5,
			create("UIStroke")({ Thickness = 2 }),
		}),

		create("UIGradient")({
			Name = "RarityGradient",
			Rotation = 45,

			useColorSequenceCycle(backgroundGradient, gradientTransitionTime, hasTower),
		}),

		useButtonEffect(nil, 1),
	})
end
