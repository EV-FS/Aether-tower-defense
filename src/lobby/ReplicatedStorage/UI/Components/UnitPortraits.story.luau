local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local TowerButton = require(script.Parent.TowerButton)

return {
	vide = Vide,
	summary = "Animated portrait regression: compare face scale and alignment across different rigs and weapons.",
	story = function()
		local cards = {}
		for index, name in { "Fighter", "Galahad", "Knight", "Elder Wizard", "Ganet", "Harvester" } do
			cards[index] = TowerButton({
				TowerName = name,
				TowerData = { Lv = 0 },
				LayoutOrder = index,
				PerformanceMode = true,
				IsSelected = function() return false end,
				IsEquipped = function() return false end,
			})
		end
		return Vide.create("Frame")({
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(25, 25, 30),
			Vide.create("UIPadding")({
				PaddingLeft = UDim.new(0, 16), PaddingTop = UDim.new(0, 16),
			}),
			Vide.create("UIGridLayout")({
				CellSize = UDim2.fromOffset(140, 140),
				CellPadding = UDim2.fromOffset(12, 18),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			cards,
		})
	end,
}
