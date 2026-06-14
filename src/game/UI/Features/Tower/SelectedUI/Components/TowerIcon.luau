-- UI/Features/Tower/SelectedUI/Components/TowerIcon.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)

local create = Vide.create
local derive = Vide.derive

export type Props = {
	towerData: () -> {}?,
}

return function(props: Props)
	local towerImage = derive(function()
		local data = props.towerData()
		if not data then
			return ""
		end
		local config = TowerData.ByName[data.Name]
		return if config then config.TowerImage else ""
	end)

	return create("Frame")({
		Name = "TowerIcon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.252008, 0.340308),
		Size = UDim2.fromScale(0.412613, 0.520657),

		create("ImageLabel")({
			Name = "TowerImage",
			BackgroundTransparency = 1,
			Image = towerImage,
			Position = UDim2.fromScale(-0.763159, -0.680819),
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromScale(2.64955, 2.76097),

			create("UICorner")({
				Name = "UICorner",
				BottomLeftRadius = UDim.new(0.04, 0),
				BottomRightRadius = UDim.new(0.04, 0),
				TopLeftRadius = UDim.new(0.04, 0),
				TopRightRadius = UDim.new(0.04, 0),
			}),

			create("UIGradient")({
				Name = "UIGradient",
				Rotation = -90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(1, 0),
				}),
			}),
		}),
	})
end
