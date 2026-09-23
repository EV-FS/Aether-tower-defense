-- UI/Features/Tower/SelectedUI/Components/DetailPanels.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)
local TowerDescriptions = require(ReplicatedStorage.Settings.Data.TowerData.TowerDescriptions)
local RarityColor = require(ReplicatedStorage.Settings.Visuals.RarityColor)

local create = Vide.create
local derive = Vide.derive

export type Props = {
	towerData: () -> {}?,
	showDescription: (boolean?) -> boolean,
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

	local isFarmer = derive(function()
		local data = props.towerData()
		if not data then
			return false
		end
		return data.Stats.Income ~= nil
	end)

	local isBuffer = derive(function()
		local data = props.towerData()
		if not data then
			return false
		end

		return (data.Stats.DamageBuff or data.Stats.RangeBuff or data.Stats.CooldownBuff) ~= nil
	end)

	local farmerDetailText = derive(function()
		local data = props.towerData()
		if not data or not data.Stats then
			return ""
		end
		local cur = data.Stats.Income or 0
		local nextData = nextLevelData()
		local nxt = nextData and nextData.Income

		return if nxt and nxt ~= cur then `{cur} → {nxt}` else `{cur}`
	end)

	local buff1Text = derive(function()
		local data = props.towerData()
		if not data or not data.Stats then
			return ""
		end
		local cur = data.Stats.BuffAmount or 0
		local nextData = nextLevelData()
		local nxt = nextData and nextData.BuffAmount
		return if nxt and nxt ~= cur then `{cur}% → {nxt}%` else `{cur}%`
	end)

	local buff2Text = derive(function()
		local data = props.towerData()
		if not data or not data.Stats then
			return ""
		end
		local cur = data.Stats.BuffRange or 0
		local nextData = nextLevelData()
		local nxt = nextData and nextData.BuffRange
		return if nxt and nxt ~= cur then `{cur} → {nxt}` else `{cur}`
	end)

	local descriptionData = derive(function()
		local data = props.towerData()
		if not data then
			return nil
		end
		return TowerDescriptions[data.Name]
	end)

	local hasDescription = derive(function()
		return descriptionData() ~= nil
	end)

	local rarityColor = derive(function()
		local data = props.towerData()
		if not data then
			return Color3.fromRGB(255, 255, 255)
		end
		local config = TowerData.ByName[data.Name]
		return if config then RarityColor[config.Rarity] else Color3.fromRGB(255, 255, 255)
	end)

	local passiveName = derive(function()
		local desc = descriptionData()
		return if desc then desc.PassiveName else ""
	end)

	local passiveDescription = derive(function()
		local desc = descriptionData()
		return if desc then desc.PassiveDescription else ""
	end)

	local passiveDetailsText = derive(function()
		local desc = descriptionData()
		local data = props.towerData()
		if not desc or not desc.PassiveDetails or not data or not data.Stats then
			return ""
		end

		local lines = {}
		for _, detail in ipairs(desc.PassiveDetails) do
			local value = data.Stats[detail.Key]
			if value then
				local nextData = nextLevelData()
				local nxt = nextData and nextData[detail.Key]
				local suffix = detail.Suffix or ""
				if nxt and nxt ~= value then
					table.insert(lines, `{detail.Label}: {value}{suffix} → {nxt}{suffix}`)
				else
					table.insert(lines, `{detail.Label}: {value}{suffix}`)
				end
			end
		end
		return table.concat(lines, "\n")
	end)

	local finalTitleText = derive(function()
		if isFarmer() then
			return "Farm:"
		elseif isBuffer() then
			return "Support:"
		elseif hasDescription() then
			return `Passive: {passiveName()}`
		else
			return "Normal:"
		end
	end)

	local finalDescriptionText = derive(function()
		if isFarmer() then
			return "Generates extra cash at the end of each wave to fund your defense."
		elseif isBuffer() then
			return "Buffs and inspires nearby towers, cranking up their combat stats."
		elseif hasDescription() then
			return passiveDescription()
		else
			return "A dependable defender eternal. Upgrade to unleash its true potential!"
		end
	end)

	local finalDetailsText = derive(function()
		if isFarmer() then
			return `Income: ${farmerDetailText()}`
		elseif isBuffer() then
			return `Buff Amount: {buff1Text()} | Buff Range: {buff2Text()}`
		elseif hasDescription() then
			return passiveDetailsText()
		else
			return ""
		end
	end)

	return create("Frame")({
		Name = "DescriptionFrame",
		BackgroundColor3 = Color3.fromRGB(18, 18, 18),
		Position = UDim2.fromScale(0, 1.06),
		Size = UDim2.fromScale(1, 0.3),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = props.showDescription,
		ZIndex = 2,

		create("UICorner")({
			Name = "UICorner",
			CornerRadius = UDim.new(0, 8),
		}),

		create("UIStroke")({
			Name = "UIStroke",
			Color = rarityColor,
			Thickness = 3,
			ZIndex = 2,
		}),

		create("UIStroke")({
			Name = "UIStroke",
			Thickness = 7,
		}),

		create("UIListLayout")({
			Name = "UIListLayout",
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),

		create("UIPadding")({
			Name = "UIPadding",
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
			PaddingTop = UDim.new(0, 12),
			PaddingBottom = UDim.new(0, 12),
		}),

		-- Title Label
		create("TextLabel")({
			Name = "Title",
			BackgroundTransparency = 1,
			FontFace = Font.new(
				"rbxasset://fonts/families/GothamSSm.json",
				Enum.FontWeight.Bold,
				Enum.FontStyle.Normal
			),
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = finalTitleText,
			TextColor3 = Color3.fromRGB(120, 180, 255),
			TextSize = 16,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 1,

			create("UIStroke")({
				Name = "UIStroke",
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.1,
			}),
		}),

		-- Description Label
		create("TextLabel")({
			Name = "Description",
			BackgroundTransparency = 1,
			FontFace = Font.new(
				"rbxasset://fonts/families/GothamSSm.json",
				Enum.FontWeight.Regular,
				Enum.FontStyle.Normal
			),
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = finalDescriptionText,
			TextColor3 = Color3.fromRGB(190, 190, 200),
			TextSize = 14,
			RichText = true,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			LayoutOrder = 2,
		}),

		-- Details Label
		create("TextLabel")({
			Name = "Details",
			BackgroundTransparency = 1,
			FontFace = Font.new(
				"rbxasset://fonts/families/GothamSSm.json",
				Enum.FontWeight.Bold,
				Enum.FontStyle.Normal
			),
			Size = UDim2.fromScale(0.9, 0.18),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = finalDetailsText,
			TextColor3 = Color3.fromRGB(255, 220, 100),
			TextSize = 13,
			RichText = true,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 3,

			create("UIStroke")({
				Name = "UIStroke",
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.08,
			}),
		}),
	})
end
