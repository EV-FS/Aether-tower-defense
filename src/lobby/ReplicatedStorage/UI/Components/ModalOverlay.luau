local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create
local spring = Vide.spring

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
			BackgroundTransparency = spring(function()
				return if props.IsOpen() then 0.35 else 1
			end, 0.2, 0.9),
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
			Position = spring(function()
				return if props.IsOpen() then UDim2.fromScale(0.5, 0.12) else UDim2.fromScale(0.5, 0.15)
			end, 0.4, 0.6),
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

		create("Frame")({
			Name = "Content",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),

			Rotation = spring(function()
				return if props.IsOpen() then 0 else -90
			end, 0.6, 0.75),

			Size = spring(function()
				return if props.IsOpen() then UDim2.fromScale(1, 1) else UDim2.fromScale(0, 0)
			end, 0.6, 0.75),

			ZIndex = 30,

			props.Content,
		}),
	})
end
