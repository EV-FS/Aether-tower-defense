local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Components = require(ReplicatedStorage.Shared.Components)

local registered = {}
local addedConnection

local function registerLeaf(world, leaf)
	if registered[leaf] then
		return
	end
	registered[leaf] = true

	world:spawn(Components.Leaf({
		LeafModel = leaf,
	}))
end

return function(world)
	if not addedConnection then
		addedConnection = CollectionService:GetInstanceAddedSignal("Leaf"):Connect(function(leaf)
			registerLeaf(world, leaf)
		end)
	end

	for _, leaf in CollectionService:GetTagged("Leaf") do
		registerLeaf(world, leaf)
	end
end
