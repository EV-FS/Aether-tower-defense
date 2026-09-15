local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)
local RarityColor = require(ReplicatedStorage.Settings.Visuals.RarityColor)
local useButtonEffect = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useButtonEffect)
local NumberUtils = require(ReplicatedStorage.Shared.Modules.Utils.NumberUtils)

local create = Vide.create
local derive = Vide.derive

export type Props = {
	slotNumber: number,
	loadout: () -> {},
	ownedTowers: () -> {},
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
	local imageColor = derive(function()
		local t = tower()
		if not t then
			return Color3.new(0.75, 0.75, 0.75)
		end

		local towerName = t.Name or t.towerName
		local towerInfo = TowerData.ByName[towerName]
		local rarity = towerInfo and towerInfo.Rarity

		return RarityColor[rarity] or Color3.new(0.75, 0.75, 0.75)
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
	local towerCost = derive(function()
		local t = tower()
		if not t then
			return "$0"
		end

		local towerName = t.Name or t.towerName
		local towerInfo = TowerData.ByName[towerName]
		local cost = 0
		if towerInfo and towerInfo.Stats and towerInfo.Stats[0] then
			cost = towerInfo.Stats[0].Cost or 0
		end
		return `${NumberUtils.FormatComma(cost)}`
	end)

	return create("ImageButton")({
		Name = `Slot{props.slotNumber}`,
		BackgroundTransparency = 1,
		Image = "rbxassetid://128510116496993",
		Size = UDim2.fromScale(1, 1),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		ImageColor3 = imageColor,

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
			ZIndex = 2,
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

			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			ZIndex = 2,
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

			create("UIAspectRatioConstraint")({}),
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
			ZIndex = 2,
			create("UIStroke")({ Thickness = 2 }),
		}),

		create("UIGradient")({
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(136, 136, 136)),
			}),
			Rotation = 90,
		}),

		useButtonEffect(nil, 1),
	})
end
