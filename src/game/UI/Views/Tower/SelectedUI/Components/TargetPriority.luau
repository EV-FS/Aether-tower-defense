-- UI/Features/Tower/SelectedUI/Components/TargetPriority.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create
local derive = Vide.derive

export type Props = {
	towerData: () -> {}?,
	OnChangeTarget: (step: number) -> (),
}

return function(props: Props)
	local targetMode = derive(function()
		local data = props.towerData()
		return if data then (data.Target or "First") else "First"
	end)

	return create("Frame")({
		Name = "Target",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.275334, 0.411076),
		Size = UDim2.fromScale(0.428187, 0.629126),
		ZIndex = 2,

		create("ImageButton")({
			Name = "Back",
			BackgroundTransparency = 1,
			Image = "rbxassetid://107520954450439",
			Position = UDim2.fromScale(0.220901, 0.904159),
			Size = UDim2.fromScale(0.16123, 0.157647),
			Activated = function()
				props.OnChangeTarget(-1)
			end,
		}),

		create("ImageButton")({
			Name = "Next",
			BackgroundTransparency = 1,
			Image = "rbxassetid://95341796804988",
			Position = UDim2.fromScale(0.630906, 0.904159),
			Size = UDim2.fromScale(0.16123, 0.157647),
			Activated = function()
				props.OnChangeTarget(1)
			end,
		}),

		create("TextLabel")({
			Name = "Current",
			BackgroundTransparency = 1,
			FontFace = Font.new(
				"rbxasset://fonts/families/GothamSSm.json",
				Enum.FontWeight.Bold,
				Enum.FontStyle.Normal
			),
			Position = UDim2.fromScale(0.371345, 0.929779),
			Size = UDim2.fromScale(0.262287, 0.105223),
			Text = targetMode,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextStrokeTransparency = 0.41,
			ZIndex = 2,

			create("UICorner")({
				Name = "UICorner",
				BottomLeftRadius = UDim.new(0, 20),
				BottomRightRadius = UDim.new(0, 20),
				TopLeftRadius = UDim.new(0, 20),
				TopRightRadius = UDim.new(0, 20),
			}),

			create("UIStroke")({
				Name = "UIStroke",
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.1,
			}),
		}),

		create("TextLabel")({
			Name = "Title",
			BackgroundTransparency = 1,
			FontFace = Font.new(
				"rbxasset://fonts/families/GothamSSm.json",
				Enum.FontWeight.Bold,
				Enum.FontStyle.Normal
			),
			Position = UDim2.fromScale(0.104209, 0.811622),
			Size = UDim2.fromScale(0.787909, 0.105223),
			Text = "Unit Priority [T]:",
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextStrokeTransparency = 0.41,
			ZIndex = 2,

			create("UICorner")({
				Name = "UICorner",
				BottomLeftRadius = UDim.new(0, 20),
				BottomRightRadius = UDim.new(0, 20),
				TopLeftRadius = UDim.new(0, 20),
				TopRightRadius = UDim.new(0, 20),
			}),

			create("UIStroke")({
				Name = "UIStroke",
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.1,
			}),
		}),
	})
end
