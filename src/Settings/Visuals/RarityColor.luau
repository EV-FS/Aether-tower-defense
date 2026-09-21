local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RarityRegistry = require(ReplicatedStorage.Shared.Modules.Core.Rarity.RarityRegistry)

local colors = {}
for rarity, entity in RarityRegistry.Entities do
	colors[rarity] = entity.Presentation.Color
end

return table.freeze(colors)
