local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RarityRegistry = require(ReplicatedStorage.Shared.Modules.Core.Rarity.RarityRegistry)

local gradients = {}
local glow = {}
local shimmerSpeed = {}
for rarity, entity in RarityRegistry.Entities do
	gradients[rarity] = entity.Presentation.Gradient
	glow[rarity] = entity.Presentation.Glow
	shimmerSpeed[rarity] = entity.Presentation.ShimmerSpeed
end

return table.freeze({
	Gradients = table.freeze(gradients),
	Glow = table.freeze(glow),
	ShimmerSpeed = table.freeze(shimmerSpeed),
})
