local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)

return TableUtils.DeepFreeze({
	Common = Color3.new(1, 1, 1),
	Rare = Color3.new(0, 1, 1),
	Epic = Color3.new(0.5, 0, 1),
	Legendary = Color3.new(1, 1, 0),
	Mythic = Color3.new(1, 0, 0),
	Absolute = Color3.new(0.15, 0.15, 1),
	Secret = Color3.new(1, 0, 1),
})
