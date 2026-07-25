local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

export type Props = {
	Name: string,
	Title: string,
	IsOpen: () -> boolean,
	OnClose: () -> (),
	Content: GuiObject,
}

return function(props: Props)
	return create("Frame")({
		Name = props.Name,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = props.IsOpen,
		ZIndex = 20,

		create("TextButton")({
			Name = "Backdrop",
			AutoButtonColor = false,
			BackgroundColor3 = Color3.fromRGB(7, 12, 22),
			BackgroundTransparency = 0.35,
			Size = UDim2.fromScale(1, 1),
			Text = "",
			ZIndex = 20,

			Activated = props.OnClose,
		}),

		create("TextLabel")({
			Name = "Title",
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			FontFace = Font.fromEnum(Enum.Font.GothamBold),
			Position = UDim2.fromScale(0.5, 0.12),
			Size = UDim2.fromScale(0.4, 0.05),
			Text = props.Title,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			ZIndex = 31,

			create("UIStroke")({
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.08,
			}),
		}),

		create("TextButton")({
			Name = "Close",
			AnchorPoint = Vector2.new(0.5, 0.5),
			AutoButtonColor = false,
			BackgroundColor3 = Color3.fromRGB(42, 58, 83),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(62, 62),
			Text = "X",
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			ZIndex = 35,

			Activated = props.OnClose,

			create("UICorner")({
				CornerRadius = UDim.new(1, 0),
			}),

			create("UIStroke")({
				Color = Color3.fromRGB(88, 186, 255),
				Thickness = 2,
			}),
		}),

		props.Content,
	})
end
