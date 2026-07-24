local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

local Shared = {}

function Shared.Corner(radius)
	return Vide.create("UICorner")({ CornerRadius = radius or UDim.new(0, 8) })
end

function Shared.Stroke(thickness, color, mode)
	return Vide.create("UIStroke")({
		Thickness = thickness,
		Color = color or Color3.new(0, 0, 0),
		StrokeSizingMode = mode or Enum.StrokeSizingMode.ScaledSize,
	})
end

return Shared
