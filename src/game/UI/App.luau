local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

return function(views: { Instance })
	return create("ScreenGui")({
		Name = "Interface",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,

		unpack(views),
	})
end
