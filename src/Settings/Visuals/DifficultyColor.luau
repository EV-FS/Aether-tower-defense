local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)

return TableUtils.DeepFreeze({
	Easy = Color3.new(0, 1, 0),
	Normal = Color3.new(1, 1, 0),
	Hard = Color3.new(1, 0, 0),
	Extreme = Color3.new(1, 0, 0.5),
	Eternal = Color3.new(0, 0.25, 0.5),
})
