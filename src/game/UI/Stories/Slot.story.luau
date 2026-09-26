local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Slot = require(ReplicatedStorage.UI.Components.Base.Slot)

return function(target)
	local destroyVide = Vide.mount(function()
		return Slot({
			Position = UDim2.fromScale(0.5, 0.5),
			Visible = true,

			AssetType = "Tower",
			AssetProps = {
				TowerName = "Galahad",
				TraitName = "Dragon",
			},
			Rarity = "Secret",

			OnActivated = function() end,
		})
	end, target)

	return function()
		destroyVide()
	end
end
