local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

return function(views: { Instance })
	return create("ScreenGui")({
		Name = "Interface",
		DisplayOrder = 10,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,

		unpack(views),
	})
end
