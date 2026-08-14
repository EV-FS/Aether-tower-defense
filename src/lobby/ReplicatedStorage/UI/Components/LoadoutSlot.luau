local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local TowerViewport = require(ReplicatedStorage.UI.Components.TowerViewport)

local create = Vide.create
local derive = Vide.derive

export type Props = {
	slotNumber: number,
	loadout: () -> { [string | number]: { Name: string?, Key: string?, towerName: string? }? },
	Activated: (() -> ())?,
}

return function(props: Props)
	local tower = derive(function()
		local currentLoadout = props.loadout()
		return currentLoadout[tostring(props.slotNumber)] or currentLoadout[props.slotNumber]
	end)

	local towerName = derive(function()
		local equipped = tower()
		if not equipped then
			return ""
		end

		return equipped.Name or equipped.towerName or ""
	end)

	local hasTower = derive(function()
		return towerName() ~= ""
	end)

	return create("ImageButton")({
		Name = `Slot{props.slotNumber}`,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Image = "rbxassetid://89434359315725",
		ImageTransparency = function()
			return if hasTower() then 0 else 0.2
		end,
		LayoutOrder = props.slotNumber,
		Size = UDim2.fromScale(0.0850976, 0.972242),

		Activated = props.Activated,

		create("TextLabel")({
			Name = "Num",
			BackgroundTransparency = 1,
			FontFace = Font.new(
				"rbxasset://fonts/families/GothamSSm.json",
				Enum.FontWeight.Bold,
				Enum.FontStyle.Normal
			),
			Position = UDim2.fromScale(0.0767423, 0.0759494),
			Size = UDim2.fromScale(0.422083, 0.278481),
			Text = tostring(props.slotNumber),
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 3,

			create("UIStroke")({
				Name = "UIStroke",
				Color = Color3.fromRGB(57, 71, 81),
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.1,
			}),
		}),

		TowerViewport({
			Name = "Unit",
			TowerName = towerName,
			AnimationName = "Idle",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			CameraDirection = Vector3.new(0, 0.82, -0.88),
			FieldOfView = 26,
			FitPadding = 0.62,
			Position = UDim2.fromScale(0.5, 0.54),
			Size = UDim2.fromScale(0.88, 0.56),
			Visible = hasTower,
			ZIndex = 2,
		}),

		create("TextLabel")({
			Name = "UnitName",
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			FontFace = Font.new(
				"rbxasset://fonts/families/GothamSSm.json",
				Enum.FontWeight.Bold,
				Enum.FontStyle.Normal
			),
			Position = UDim2.fromScale(0.5, 0.98),
			Size = UDim2.fromScale(0.92, 0.12),
			Text = towerName,
			TextColor3 = Color3.fromRGB(245, 242, 230),
			TextScaled = true,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Visible = hasTower,
			ZIndex = 4,

			create("UIStroke")({
				Name = "UIStroke",
				Color = Color3.fromRGB(57, 71, 81),
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.08,
			}),
		}),

		create("UIAspectRatioConstraint")({
			Name = "UIAspectRatioConstraint",
			AspectRatio = 0.92,
		}),
	})
end
