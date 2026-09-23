-- UI/Features/Tower/SelectedUI/Components/StatsScroll.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)
local NumberUtils = require(ReplicatedStorage.Shared.Modules.Utils.NumberUtils)

local create = Vide.create
local derive = Vide.derive

export type Props = {
	towerData: () -> {}?,
}

return function(props: Props)
	local nextLevelData = derive(function()
		local data = props.towerData()
		if not data then
			return nil
		end
		local config = TowerData.ByName[data.Name]
		return data.NextStats or (config and config.Stats[data.Level + 1])
	end)

	local function deriveStatText(statKey: string)
		return derive(function()
			local data = props.towerData()
			if not data or not data.Stats then
				return ""
			end
			local cur = data.Stats[statKey]
			if cur == nil then
				return ""
			end
			local nextData = nextLevelData()
			local nxt = nextData and nextData[statKey]
			if nxt and nxt ~= cur then
				return `{NumberUtils.FormatComma(cur)} → {NumberUtils.FormatComma(nxt)}`
			end
			return `{NumberUtils.FormatComma(cur)}`
		end)
	end

	local function deriveStatVisibility(statKey: string)
		return derive(function()
			local data = props.towerData()
			return data ~= nil and data.Stats ~= nil and data.Stats[statKey] ~= nil
		end)
	end

	local damageText = deriveStatText("Damage")
	local damageVisible = deriveStatVisibility("Damage")

	local rangeText = deriveStatText("Range")
	local rangeVisible = deriveStatVisibility("Range")

	local cooldownText = deriveStatText("Cooldown")
	local cooldownVisible = deriveStatVisibility("Cooldown")

	local splashText = deriveStatText("SplashRange")
	local splashVisible = deriveStatVisibility("SplashRange")

	local wideText = deriveStatText("Width")
	local wideVisible = deriveStatVisibility("Width")

	local angleText = deriveStatText("Angle")
	local angleVisible = deriveStatVisibility("Angle")

	local incomeText = deriveStatText("Income")
	local incomeVisible = deriveStatVisibility("Income")

	local function createStatRow(params)
		return create("Frame")({
			Name = params.Name,
			BackgroundColor3 = Color3.fromRGB(58, 58, 58),
			BorderColor3 = Color3.new(),
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 0.2),
			SizeConstraint = Enum.SizeConstraint.RelativeXX,
			Visible = params.Visible,
			LayoutOrder = params.LayoutOrder,

			create("UIStroke")({
				Name = "UIStroke",
				Color = Color3.fromRGB(102, 102, 102),
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.05,

				create("UIGradient")({
					Name = "UIGradient",
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 1),
						NumberSequenceKeypoint.new(0.5, 0),
						NumberSequenceKeypoint.new(1, 1),
					}),
				}),
			}),

			create("UIGradient")({
				Name = "UIGradient",
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.5, 0),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),

			create("UIListLayout")({
				Name = "UIListLayout",
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0.05, 0),
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),

			create("ImageLabel")({
				Name = "Icon",
				BackgroundTransparency = 1,
				Image = params.Icon,
				ScaleType = Enum.ScaleType.Fit,
				Position = params.IconPos or UDim2.fromScale(0.0685593, 0),
				Size = params.IconSize or UDim2.fromScale(0.174324, 1.0322),

				create("UIGradient")({
					Name = "UIGradient",
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, params.GradientStart),
						ColorSequenceKeypoint.new(1, params.GradientEnd),
					}),
					Rotation = 90,
				}),
			}),

			create("TextLabel")({
				Name = "Title",
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
				Position = UDim2.fromScale(0.325, 0.163454),
				Size = UDim2.fromScale(0.6, 0.607711),
				Text = params.Text,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextStrokeTransparency = 0.41,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 2,
			}),
		})
	end

	return create("Frame")({
		Name = "Stats",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.545571, 0.103059),
		Size = UDim2.fromScale(0.412068, 0.622849),
		ZIndex = 2,

		create("ScrollingFrame")({
			Name = "Scroll",
			Active = true,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			CanvasSize = UDim2.new(),
			ScrollBarThickness = 8,
			Size = UDim2.fromScale(1, 1),

			create("UIListLayout")({
				Name = "UIListLayout",
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0.05, 0),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			createStatRow({
				Name = "Income",
				Icon = "rbxassetid://119558116195723",
				Text = incomeText,
				Visible = incomeVisible,
				GradientStart = Color3.new(0.168627, 1, 0.360784),
				GradientEnd = Color3.fromRGB(206, 255, 31),
				LayoutOrder = 0,
			}),

			createStatRow({
				Name = "Damage",
				Icon = "rbxassetid://7485051715",
				Text = damageText,
				Visible = damageVisible,
				GradientStart = Color3.fromRGB(255, 8, 204),
				GradientEnd = Color3.fromRGB(255, 0, 4),
				LayoutOrder = 1,
			}),

			createStatRow({
				Name = "Range",
				Icon = "rbxassetid://103285003019046",
				IconPos = UDim2.fromScale(0.0878378, 0.196143),
				IconSize = UDim2.fromScale(0.174324, 0.739667),
				Text = rangeText,
				Visible = rangeVisible,
				GradientStart = Color3.fromRGB(255, 234, 0),
				GradientEnd = Color3.fromRGB(255, 106, 0),
				LayoutOrder = 2,
			}),

			createStatRow({
				Name = "Cooldown",
				Icon = "rbxassetid://130076903983220",
				Text = cooldownText,
				Visible = cooldownVisible,
				GradientStart = Color3.fromRGB(0, 238, 255),
				GradientEnd = Color3.fromRGB(0, 119, 255),
				LayoutOrder = 3,
			}),

			createStatRow({
				Name = "SplashAttack",
				Icon = "rbxassetid://110061553820317",
				Text = splashText,
				Visible = splashVisible,
				GradientStart = Color3.fromRGB(255, 255, 128),
				GradientEnd = Color3.fromRGB(174, 255, 200),
				LayoutOrder = 4,
			}),

			createStatRow({
				Name = "WideArea",
				Icon = "rbxassetid://128603991289472",
				Text = wideText,
				Visible = wideVisible,
				GradientStart = Color3.fromRGB(168, 106, 255),
				GradientEnd = Color3.fromRGB(255, 13, 154),
				LayoutOrder = 5,
			}),

			createStatRow({
				Name = "AngleAttack",
				Icon = "rbxassetid://140636955832491",
				Text = angleText,
				Visible = angleVisible,
				GradientStart = Color3.new(0.752941, 0.447059, 0.098039),
				GradientEnd = Color3.fromRGB(255, 0, 0),
				LayoutOrder = 6,
			}),

			create("Frame")({
				Name = "Empty",
				BackgroundTransparency = 1,
				LayoutOrder = 1000,
				Size = UDim2.fromScale(1, 0),
				SizeConstraint = Enum.SizeConstraint.RelativeXX,
			}),
		}),
	})
end
