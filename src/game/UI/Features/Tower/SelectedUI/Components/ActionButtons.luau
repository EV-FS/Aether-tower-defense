local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)

local create = Vide.create
local derive = Vide.derive

export type Props = {
	towerData: () -> {}?,
	playerCash: () -> number,
	showDescription: (boolean?) -> boolean,
	OnUpgrade: () -> (),
	OnSell: () -> (),
}

return function(props: Props)
	local upgradeState = derive(function()
		local data = props.towerData()
		if not data then
			return {
				isMax = true,
				label = "Upgrade",
				text = "Max Level!",
				color = Color3.fromRGB(100, 100, 100),
				strokeColor = Color3.fromRGB(60, 60, 60),
			}
		end

		local config = TowerData.ByName[data.Name]
		local nextLevel = config and config.Stats[data.Level + 1]

		if not nextLevel then
			return {
				isMax = true,
				label = "Max Level!",
				text = "",
				color = Color3.fromRGB(100, 100, 100),
				strokeColor = Color3.fromRGB(60, 60, 60),
			}
		end

		local cost = nextLevel.Cost or 0
		local canAfford = props.playerCash() >= cost
		return {
			isMax = false,
			cost = cost,
			canAfford = canAfford,
			label = "Upgrade",
			text = "$" .. cost,
			color = if canAfford then Color3.fromRGB(0, 255, 0) else Color3.fromRGB(100, 100, 100),
			strokeColor = if canAfford then Color3.fromRGB(29, 125, 0) else Color3.fromRGB(60, 60, 60),
		}
	end)

	local sellCostText = derive(function()
		local data = props.towerData()
		if not data then
			return "0"
		end
		local config = TowerData.ByName[data.Name]
		if not config then
			return "0"
		end
		local totalSpent = 0
		for level = 0, data.Level do
			local lvStats = config.Stats[level]
			if lvStats and lvStats.Cost then
				totalSpent += lvStats.Cost
			end
		end
		return tostring(math.floor(totalSpent / 2))
	end)

	local upgradeLabel = derive(function()
		local state = upgradeState()
		return if state.isMax then state.label else state.label .. " [E]"
	end)

	local upgradeCostDisplay = derive(function()
		return upgradeState().text
	end)

	local sellCostDisplay = derive(function()
		return "$" .. sellCostText()
	end)

	local infoButtonText = derive(function()
		return if props.showDescription() then "▲ Hide" else "▼ Info"
	end)

	return create("Frame")({
		Name = "Action",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,

		create("TextButton")({
			Name = "Upgrade",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = derive(function()
				return upgradeState().color
			end),
			FontFace = Font.new(
				"rbxasset://fonts/families/SourceSansPro.json",
				Enum.FontWeight.Bold,
				Enum.FontStyle.Normal
			),
			Position = UDim2.fromScale(0.499561, 0.906372),
			RichText = true,
			Size = UDim2.fromScale(0.5191, 0.11),
			Text = "",
			TextColor3 = Color3.new(),
			TextScaled = true,
			Activated = function()
				if not upgradeState().isMax and upgradeState().canAfford then
					props.OnUpgrade()
				end
			end,

			create("UICorner")({
				Name = "UICorner",
				BottomLeftRadius = UDim.new(0.1, 0),
				BottomRightRadius = UDim.new(0.1, 0),
				TopLeftRadius = UDim.new(0.1, 0),
				TopRightRadius = UDim.new(0.1, 0),
			}),

			create("UIStroke")({
				Name = "UIStroke",
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = derive(function()
					return upgradeState().strokeColor
				end),
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.05,
			}),

			create("UIGradient")({
				Name = "UIGradient",
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
					ColorSequenceKeypoint.new(0.495, Color3.new(1, 1, 1)),
					ColorSequenceKeypoint.new(0.505, Color3.fromRGB(195, 195, 195)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(195, 195, 195)),
				}),
				Rotation = 90,
			}),

			create("TextLabel")({
				Name = "TextLabel",
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/GothamSSm.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(0.145287, -0.408604),
				Size = UDim2.fromScale(0.702747, 0.4),
				Text = upgradeLabel,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,

				create("UIStroke")({
					Name = "UIStroke",
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.15,
				}),
			}),

			create("TextLabel")({
				Name = "Title",
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/GothamSSm.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(0.145288, 0.300725),
				Size = UDim2.fromScale(0.702747, 0.494278),
				Text = upgradeCostDisplay,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				Visible = derive(function()
					return not upgradeState().isMax
				end),

				create("UIStroke")({
					Name = "UIStroke",
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.15,
				}),
			}),
		}),

		create("TextButton")({
			Name = "Description",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(30, 30, 30),
			FontFace = Font.new(
				"rbxasset://fonts/families/SourceSansPro.json",
				Enum.FontWeight.Bold,
				Enum.FontStyle.Normal
			),
			Position = UDim2.fromScale(0.875305, 0.904102),
			RichText = true,
			Size = UDim2.fromScale(0.17, 0.087),
			Text = "",
			TextColor3 = Color3.new(),
			TextScaled = true,
			Activated = function()
				props.showDescription(not props.showDescription())
			end,

			create("TextLabel")({
				Name = "TextLabel",
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/GothamSSm.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(0.145288, -0.703397),
				Size = UDim2.fromScale(0.702747, 0.560373),
				Text = "Description",
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,

				create("UIStroke")({
					Name = "UIStroke",
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.15,
				}),
			}),

			create("UICorner")({
				Name = "UICorner",
				BottomLeftRadius = UDim.new(0.1, 0),
				BottomRightRadius = UDim.new(0.1, 0),
				TopLeftRadius = UDim.new(0.1, 0),
				TopRightRadius = UDim.new(0.1, 0),
			}),

			create("UIStroke")({
				Name = "UIStroke",
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Color3.fromRGB(85, 85, 85),
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.05,
			}),

			create("TextLabel")({
				Name = "Title",
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/GothamSSm.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(0.028, 0.5),
				Size = UDim2.fromScale(0.943, 0.7),
				Text = infoButtonText,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,

				create("UIStroke")({
					Name = "UIStroke",
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.1,
				}),
			}),
		}),

		create("TextButton")({
			Name = "Sell",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(255, 32, 36),
			FontFace = Font.new(
				"rbxasset://fonts/families/SourceSansPro.json",
				Enum.FontWeight.Bold,
				Enum.FontStyle.Normal
			),
			Position = UDim2.fromScale(0.124909, 0.911121),
			RichText = true,
			Size = UDim2.fromScale(0.17, 0.087),
			Text = "",
			TextColor3 = Color3.new(),
			TextScaled = true,
			Activated = props.OnSell,

			create("UICorner")({
				Name = "UICorner",
				BottomLeftRadius = UDim.new(0.1, 0),
				BottomRightRadius = UDim.new(0.1, 0),
				TopLeftRadius = UDim.new(0.1, 0),
				TopRightRadius = UDim.new(0.1, 0),
			}),

			create("UIStroke")({
				Name = "UIStroke",
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Color3.fromRGB(85, 0, 0),
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.05,
			}),

			create("UIGradient")({
				Name = "UIGradient",
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
					ColorSequenceKeypoint.new(0.495, Color3.new(1, 1, 1)),
					ColorSequenceKeypoint.new(0.505, Color3.fromRGB(195, 195, 195)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(195, 195, 195)),
				}),
				Rotation = 90,
			}),

			create("TextLabel")({
				Name = "TextLabel",
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/GothamSSm.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(0.130698, -0.537577),
				Size = UDim2.fromScale(0.702747, 0.5),
				Text = "Sell [X]",
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,

				create("UIStroke")({
					Name = "UIStroke",
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.15,
				}),
			}),

			create("TextLabel")({
				Name = "Title",
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/GothamSSm.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(0.145288, 0.300725),
				Size = UDim2.fromScale(0.702747, 0.494278),
				Text = sellCostDisplay,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,

				create("UIStroke")({
					Name = "UIStroke",
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.1,
				}),
			}),
		}),
	})
end
