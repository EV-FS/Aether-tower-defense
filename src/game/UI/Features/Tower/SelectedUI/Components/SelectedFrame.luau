-- UI/Features/Tower/SelectedUI/Components/SelectedFrame.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)
local RarityColor = require(ReplicatedStorage.Settings.Visuals.RarityColor)

-- Child Components
local TowerHeader = require(script.Parent.TowerHeader)
local TowerIcon = require(script.Parent.TowerIcon)
local StatsScroll = require(script.Parent.StatsScroll)
local TargetPriority = require(script.Parent.TargetPriority)
local ActionButtons = require(script.Parent.ActionButtons)
local DetailPanels = require(script.Parent.DetailPanels)

local create = Vide.create
local source = Vide.source
local derive = Vide.derive

export type Props = {
	towerId: () -> string?,
	towerData: () -> {}?,
	playerCash: () -> number,
	OnChangeTarget: (step: number) -> (),
	OnUpgrade: () -> (),
	OnSell: () -> (),
	OnClose: () -> (),
}

return function(props: Props)
	local showDescription = source(false)

	local isMenuVisible = derive(function()
		local hasTower = props.towerId() ~= nil
		if not hasTower then
			showDescription(false)
		end
		return hasTower
	end)

	local rarityColor = derive(function()
		local data = props.towerData()
		if not data then
			return Color3.fromRGB(255, 255, 255)
		end
		local config = TowerData.ByName[data.Name]
		return if config then RarityColor[config.Rarity] else Color3.fromRGB(255, 255, 255)
	end)

	return create("Frame")({
		Name = "Selected",
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = rarityColor,
		Position = UDim2.fromScale(0.0135543, 0.498736),
		Size = UDim2.new(0.2, 70, 0.2, 65),
		Visible = isMenuVisible,
		ZIndex = 2,

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

		create("UICorner")({
			Name = "UICorner",
			BottomLeftRadius = UDim.new(0.04, 0),
			BottomRightRadius = UDim.new(0.04, 0),
			TopLeftRadius = UDim.new(0.04, 0),
			TopRightRadius = UDim.new(0.04, 0),
		}),

		create("UIGradient")({
			Name = "UIGradient",
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(65, 65, 65)),
				ColorSequenceKeypoint.new(0.440273, Color3.new()),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(21, 21, 21)),
			}),
		}),

		TowerHeader({
			towerData = props.towerData,
			showDescription = showDescription,
			OnClose = props.OnClose,
		}),

		TowerIcon({
			towerData = props.towerData,
		}),

		StatsScroll({
			towerData = props.towerData,
		}),

		TargetPriority({
			towerData = props.towerData,
			OnChangeTarget = props.OnChangeTarget,
		}),

		ActionButtons({
			towerData = props.towerData,
			playerCash = props.playerCash,
			showDescription = showDescription,
			OnUpgrade = props.OnUpgrade,
			OnSell = props.OnSell,
		}),

		DetailPanels({
			towerData = props.towerData,
			showDescription = showDescription,
		}),
	})
end
