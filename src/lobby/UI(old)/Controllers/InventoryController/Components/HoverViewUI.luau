local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
--local Net = require(ReplicatedStorage.Shared.Net.client)
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)
local NumberUtils = require(ReplicatedStorage.Shared.Modules.Utils.NumberUtils)

local State = require(script.Parent.Parent.State)
local HoverTracker = require(script.Parent.Parent.HoverTracker)

return function()
	local hoveredInfo = Vide.derive(function()
		local t = State.HoveredTower()
		return t and TowerData.ByName[t.Name] or nil
	end)

	local rarityColor = Vide.derive(function()
		local info = hoveredInfo()
		local r = info and info.Rarity
		return State.RARITY_CONFIG[r] and State.RARITY_CONFIG[r].Colors or ColorSequence.new(State.COLORS.DEFAULT)
	end)

	local maxLevel = Vide.derive(function()
		local info = hoveredInfo()
		if not info or not info.Stats then
			return 0
		end
		local maxLv = 0
		for lv, _ in pairs(info.Stats) do
			if type(lv) == "number" and lv > maxLv then
				maxLv = lv
			end
		end
		return maxLv
	end)

	local function StatRow(statKey, statName, color, formatStr)
		return Vide.create("TextLabel")({
			Name = statKey,
			BackgroundTransparency = 1,
			FontFace = Font.new(
				"rbxasset://fonts/families/GothamSSm.json",
				Enum.FontWeight.Bold,
				Enum.FontStyle.Normal
			),
			Size = UDim2.new(1, 0, 0, 20),
			RichText = true,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 2,
			Visible = function()
				local info = hoveredInfo()
				if not info or not info.Stats then
					return false
				end
				local stats0 = info.Stats[0] or {}
				local statsMax = info.Stats[maxLevel()] or stats0

				if statKey == "DPS" then
					local has0 = stats0.Damage and stats0.Cooldown and stats0.Cooldown > 0
					local hasMax = statsMax.Damage and statsMax.Cooldown and statsMax.Cooldown > 0
					return has0 or hasMax
				end

				return stats0[statKey] ~= nil or statsMax[statKey] ~= nil
			end,
			Text = function()
				local info = hoveredInfo()
				if not info or not info.Stats then
					return ""
				end
				local stats0 = info.Stats[0] or {}
				local statsMax = info.Stats[maxLevel()] or stats0

				local val0, valMax
				if statKey == "DPS" then
					val0 = (stats0.Damage and stats0.Cooldown and stats0.Cooldown > 0)
							and math.floor((stats0.Damage / stats0.Cooldown) * 10) / 10
						or 0
					valMax = (statsMax.Damage and statsMax.Cooldown and statsMax.Cooldown > 0)
							and math.floor((statsMax.Damage / statsMax.Cooldown) * 10) / 10
						or 0
				else
					val0 = stats0[statKey] or 0
					valMax = statsMax[statKey] or val0
				end

				local val0Str = string.gsub(formatStr, "{v}", NumberUtils.FormatComma(val0))
				local valMaxStr = string.gsub(formatStr, "{v}", NumberUtils.FormatComma(valMax))

				if val0 == valMax then
					return `<font color="{color}">{statName}:</font> {val0Str}`
				else
					return `<font color="{color}">{statName}:</font> {val0Str} → {valMaxStr}`
				end
			end,

			Vide.create("UIStroke")({
				Thickness = 0.05,
			}),
		})
	end

	return Vide.create("Frame")({
		Name = "ViewUi",
		BackgroundColor3 = Color3.fromRGB(31, 30, 39),
		Position = UDim2.fromScale(0.1, 0.3),
		Size = UDim2.fromScale(0.26, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = function()
			return State.HoveredTower() ~= nil
		end,
		ZIndex = 50,
		Vide.action(function(inst)
			HoverTracker.viewUIRef = inst
		end),

		Vide.create("UICorner")({
			Name = "UICorner",
			CornerRadius = UDim.new(0, 12),
		}),

		Vide.create("UIStroke")({
			Name = "UIStroke",
			Color = Color3.fromRGB(50, 48, 63),
			Thickness = 2,
		}),

		Vide.create("UIPadding")({
			PaddingBottom = UDim.new(0, 15),
			PaddingLeft = UDim.new(0, 15),
			PaddingRight = UDim.new(0, 15),
			PaddingTop = UDim.new(0, 15),
		}),

		Vide.create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),

		-- Title Section
		Vide.create("Frame")({
			Name = "Header",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 1,

			Vide.create("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 2),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			Vide.create("TextLabel")({
				Name = "NameTitle",
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/GothamSSm.json",
					Enum.FontWeight.ExtraBold,
					Enum.FontStyle.Italic
				),
				Size = UDim2.new(1, 0, 0, 30),
				Text = function()
					return (State.HoveredTower() or {}).Name or ""
				end,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 1,
				Vide.create("UIStroke")({ Thickness = 1.5 }),
			}),

			Vide.create("TextLabel")({
				Name = "Rarity",
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/GothamSSm.json",
					Enum.FontWeight.ExtraBold,
					Enum.FontStyle.Italic
				),
				Size = UDim2.new(1, 0, 0, 20),
				Text = function()
					return (hoveredInfo() or {}).Rarity or ""
				end,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 2,
				Vide.create("UIGradient")({
					Color = rarityColor,
					Offset = Vector2.new(0, 0.1),
					Rotation = 90,
				}),
				Vide.create("UIStroke")({ Thickness = 1.5 }),
			}),
		}),

		-- Divider
		Vide.create("Frame")({
			Name = "Divider",
			BackgroundColor3 = Color3.fromRGB(50, 48, 63),
			Size = UDim2.new(1, 0, 0, 2),
			LayoutOrder = 2,
			Vide.create("UICorner")({ CornerRadius = UDim.new(1, 0) }),
		}),

		-- Stats Section
		Vide.create("Frame")({
			Name = "StatsContainer",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 3,

			Vide.create("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 5),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			StatRow("Damage", "Damage", "#ff0000", "{v}"),
			StatRow("Cooldown", "Cooldown", "#5fd0ec", "{v}s"),
			StatRow("Range", "Range", "#f8c671", "{v}"),
			StatRow("DPS", "DPS", "#00ff00", "{v}"),
			StatRow("Income", "Income", "#00ff88", "${v}"),
			StatRow("SplashRange", "Splash", "#ff8800", "{v}"),
			StatRow("Slow", "Slow", "#4488ff", "{v}%"),
			StatRow("HackingChance", "Hack", "#aaff00", "{v}%"),
		}),

		Vide.create("Frame")({
			Name = "Spacer",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 2),
			LayoutOrder = 4,
			Visible = function()
				return (State.HoveredTower() and State.HoveredTower().Data.Lv) ~= nil
			end,
		}),

		Vide.create("Frame")({
			Name = "LevelBarContainer",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 24),
			LayoutOrder = 5,
			Visible = function()
				return (State.HoveredTower() and State.HoveredTower().Data.Lv) ~= nil
			end,

			Vide.create("TextLabel")({
				Name = "LevelText",
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/GothamSSm.json",
					Enum.FontWeight.ExtraBold,
					Enum.FontStyle.Normal
				),
				Size = UDim2.new(0.3, 0, 1, 0),
				Text = function()
					return `Lv.{State.HoveredTower() and State.HoveredTower().Data.Lv or 0}`
				end,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				Vide.create("UIStroke")({ Color = Color3.fromRGB(38, 38, 38), Thickness = 1.5 }),
			}),

			Vide.create("Frame")({
				Name = "LevelBar",
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundColor3 = Color3.fromRGB(24, 24, 24),
				Position = UDim2.new(1, 0, 0.5, 0),
				Size = UDim2.new(0.65, 0, 0.6, 0),
				ClipsDescendants = true,
				Vide.create("UICorner")({ CornerRadius = UDim.new(1, 0) }),
				Vide.create("UIStroke")({ Thickness = 1.5, Transparency = 0.5 }),
				Vide.create("Frame")({
					Name = "Fill",
					BackgroundColor3 = Color3.new(1, 1, 1),
					Size = function()
						local t = State.HoveredTower()
						if not t then
							return UDim2.new(0, 0, 1, 0)
						end
						local prog = State.calculateExpProgress(t.Data.Exp or 0, t.Data.Lv or 0)
						return UDim2.new(prog, 0, 1, 0)
					end,
					Vide.create("UICorner")({ CornerRadius = UDim.new(1, 0) }),
					Vide.create("UIGradient")({
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 234, 0)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 106, 0)),
						}),
						Rotation = 90,
					}),
				}),
			}),
		}),

		Vide.create("TextLabel")({
			Name = "Exists",
			BackgroundTransparency = 1,
			FontFace = Font.new(
				"rbxasset://fonts/families/GothamSSm.json",
				Enum.FontWeight.ExtraBold,
				Enum.FontStyle.Italic
			),
			Size = UDim2.new(1, 0, 0, 20),
			Text = function()
				local t = State.HoveredTower()
				if not t then
					return ""
				end

				local countSource = State.ExistCounts[t.Name]
				local count = countSource and countSource() or -1

				if count == -1 then
					return "Loading Exists..."
				end
				if count == -2 then
					return "Exists: Error"
				end
				return `{NumberUtils.Abbreviate(count, 2)} Exists`
			end,
			TextColor3 = Color3.fromRGB(102, 222, 255),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Right,
			LayoutOrder = 6,
			Vide.create("UIStroke")({ Thickness = 1.5 }),
		}),
	})
end
