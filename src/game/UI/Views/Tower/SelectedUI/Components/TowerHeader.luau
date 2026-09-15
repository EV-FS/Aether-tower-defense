-- UI/Features/Tower/SelectedUI/Components/TowerHeader.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local RarityData = require(ReplicatedStorage.Settings.Data.RarityData)
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)
--local TowerDescriptions = require(ReplicatedStorage.Settings.Data.TowerData.TowerDescriptions)
local RarityColor = require(ReplicatedStorage.Settings.Visuals.RarityColor)

local create = Vide.create
local derive = Vide.derive

export type Props = {
	towerData: () -> {}?,
	showDescription: (boolean?) -> boolean,
	OnClose: () -> (),
}

return function(props: Props)
	local towerName = derive(function()
		local data = props.towerData()
		return if data then string.upper(data.Name) else ""
	end)

	local towerRarity = derive(function()
		local data = props.towerData()
		if not data then
			return ""
		end
		local config = TowerData.ByName[data.Name]
		return if config then RarityData.DisplayNames[config.Rarity] or "" else ""
	end)

	local rarityColor = derive(function()
		local data = props.towerData()
		if not data then
			return Color3.fromRGB(255, 255, 255)
		end
		local config = TowerData.ByName[data.Name]
		return if config then RarityColor[config.Rarity] else Color3.fromRGB(255, 255, 255)
	end)

	--[[local passiveIcon = derive(function()
		local data = props.towerData()
		if not data then
			return ""
		end
		local desc = TowerDescriptions[data.Name]
		return if desc then desc.PassiveIcon else "rbxassetid://109654149961084" -- fall back to info/default icon
	end)--]]

	return {
		create("TextLabel")({
			Name = "TowerName",
			BackgroundTransparency = 1,
			FontFace = Font.new(
				"rbxasset://fonts/families/GothamSSm.json",
				Enum.FontWeight.Bold,
				Enum.FontStyle.Normal
			),
			Position = UDim2.fromScale(0.0279733, 0.0211756),
			Size = UDim2.fromScale(0.373375, 0.0815689),
			Text = towerName,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextStrokeTransparency = 0.41,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 2,

			create("UICorner")({
				Name = "UICorner",
				BottomLeftRadius = UDim.new(0, 20),
				BottomRightRadius = UDim.new(0, 20),
				TopLeftRadius = UDim.new(0, 20),
				TopRightRadius = UDim.new(0, 20),
			}),

			create("UIStroke")({
				Name = "UIStroke",
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.1,
			}),

			create("UITextSizeConstraint")({
				Name = "UITextSizeConstraint",
				MaxTextSize = 20,
			}),
		}),

		create("TextLabel")({
			Name = "TowerRarity",
			BackgroundTransparency = 1,
			FontFace = Font.new(
				"rbxasset://fonts/families/GothamSSm.json",
				Enum.FontWeight.Bold,
				Enum.FontStyle.Normal
			),
			Position = UDim2.fromScale(0.0279733, 0.101897),
			Size = UDim2.fromScale(0.340408, 0.056335),
			Text = towerRarity,
			TextColor3 = rarityColor,
			TextScaled = true,
			TextStrokeTransparency = 0.41,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 2,

			create("UICorner")({
				Name = "UICorner",
				BottomLeftRadius = UDim.new(0, 20),
				BottomRightRadius = UDim.new(0, 20),
				TopLeftRadius = UDim.new(0, 20),
				TopRightRadius = UDim.new(0, 20),
			}),

			create("UIStroke")({
				Name = "UIStroke",
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.1,
			}),

			create("UITextSizeConstraint")({
				Name = "UITextSizeConstraint",
				MaxTextSize = 20,
			}),
		}),

		--[[
		create("ImageButton")({
			Name = "Skill",
			BackgroundColor3 = Color3.fromRGB(18, 18, 18),
			Position = UDim2.fromScale(1.051, 0),
			Size = UDim2.fromScale(0.18, 0.18),
			SizeConstraint = Enum.SizeConstraint.RelativeXX,
			Activated = function()
				props.showDescription(not props.showDescription())
			end,

			create("UICorner")({
				Name = "UICorner",
				BottomLeftRadius = UDim.new(0.15, 0),
				BottomRightRadius = UDim.new(0.15, 0),
				TopLeftRadius = UDim.new(0.15, 0),
				TopRightRadius = UDim.new(0.15, 0),
			}),

			create("ImageLabel")({
				Name = "ImageLabel",
				BackgroundTransparency = 1,
				Image = passiveIcon,
				Position = UDim2.fromScale(0.0744832, 0.0744832),
				Size = UDim2.fromScale(0.834212, 1.10737),
			}),

			create("ImageLabel")({
				Name = "ImageLabel",
				BackgroundTransparency = 1,
				Image = "rbxassetid://97129389415928",
				Position = UDim2.fromScale(0.7, 0.7),
				Size = UDim2.fromScale(0.478618, 0.541301),
			}),

			create("UIStroke")({
				Name = "UIStroke",
				Color = Color3.fromRGB(66, 66, 66),
				Thickness = 3,
			}),

			create("UIStroke")({
				Name = "UIStroke",
				Thickness = 7.5,
			}),
		}),
		]]
	}
end
