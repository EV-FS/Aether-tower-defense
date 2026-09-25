local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Slot = require(ReplicatedStorage.UI.Components.Slot)

return function(target)
	local destroyVide = Vide.mount(function()
		return Slot({
			Position = UDim2.fromScale(0.5, 0.5),
			Visible = true,

			AssetType = "Tower",
			AssetProps = {
				TowerName = "Galahad",
				TowerLevel = 30,
			},
			Rarity = "Absolute",

			OnActivated = function() end,
		})
	end, target)

	return function()
		destroyVide()
	end
end
