local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerCharacter = require(script.Parent.PlayerCharacter)
local Vide = require(ReplicatedStorage.Packages.Vide)
local useButtonEffect = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useButtonEffect)

local create = Vide.create
local show = Vide.show

export type EmoteData = {
	Id: string?,
	EmoteName: string?,
	DisplayName: string?,
	AnimationId: (number | string)?,
}

export type Props = {
	Emote1: () -> EmoteData?,
	Emote2: () -> EmoteData?,
	Emote3: () -> EmoteData?,
	Emote4: () -> EmoteData?,
	UserId: ((() -> number?) | number)?,
	OnSelected: (emoteName: string) -> (),
}

local function createCamera(): Camera
	return create("Camera")({
		FieldOfView = 50,
		CFrame = CFrame.lookAt(Vector3.new(0, 0, -5.5), Vector3.new(0, -0.3, 0)),
	})
end

return function(props: Props)
	local camera1 = createCamera()
	local camera2 = createCamera()
	local camera3 = createCamera()
	local camera4 = createCamera()

	return create("Frame")({
		Name = "EmoteWheel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.49, 0.49),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,

		create("ImageButton")({
			Name = "Emote1",
			AnchorPoint = Vector2.new(1, 1),
			BackgroundTransparency = 1,
			Image = "rbxassetid://74473551495859",
			ScaleType = Enum.ScaleType.Fit,
			ImageTransparency = 0.3,
			Position = UDim2.fromScale(0.49, 0.49),
			Size = UDim2.fromScale(0.49, 0.49),

			Activated = function()
				if props.Emote1() and props.OnSelected then
					props.OnSelected(props.Emote1().EmoteName)
				end
			end,

			useButtonEffect(0.95, 1.12),

			create("ViewportFrame")({
				BackgroundColor3 = Color3.new(),
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				CurrentCamera = camera1,
				camera1,

				show(props.Emote1, function()
					return PlayerCharacter({
						UseWorldModel = true,
						Origin = CFrame.new(0, -0.25, 1.5),
						AnimationId = function()
							local emote = props.Emote1()
							return if emote then emote.AnimationId else nil
						end,
					})
				end),
			}),

			create("TextLabel")({
				Name = "EmoteName",
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundTransparency = 1,
				FontFace = Font.fromEnum(Enum.Font.FredokaOne),
				Position = UDim2.fromScale(0.5, 0.95),
				Size = UDim2.fromScale(0.9, 0.11),
				Text = function()
					local emote = props.Emote1()
					return if emote and emote.EmoteName then emote.EmoteName else ""
				end,
				TextColor3 = Color3.fromRGB(0, 170, 255),
				TextScaled = true,
				ZIndex = 2,

				create("UIStroke")({
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.08,
				}),
			}),
		}),

		create("ImageButton")({
			Name = "Emote2",
			AnchorPoint = Vector2.new(0, 1),
			BackgroundTransparency = 1,
			Image = "rbxassetid://140267716361991",
			ScaleType = Enum.ScaleType.Fit,
			ImageTransparency = 0.3,
			Position = UDim2.fromScale(0.51, 0.49),
			Size = UDim2.fromScale(0.49, 0.49),

			Activated = function()
				if props.Emote2() and props.OnSelected then
					props.OnSelected(props.Emote2().EmoteName)
				end
			end,

			useButtonEffect(0.95, 1.12),

			create("ViewportFrame")({
				BackgroundColor3 = Color3.new(),
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				CurrentCamera = camera2,
				camera2,

				show(props.Emote2, function()
					return PlayerCharacter({
						UseWorldModel = true,
						Origin = CFrame.new(0, -0.25, 1.5),
						AnimationId = function()
							local emote = props.Emote2()
							return if emote then emote.AnimationId else nil
						end,
					})
				end),
			}),

			create("TextLabel")({
				Name = "EmoteName",
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundTransparency = 1,
				FontFace = Font.fromEnum(Enum.Font.FredokaOne),
				Position = UDim2.fromScale(0.5, 0.95),
				Size = UDim2.fromScale(0.9, 0.11),
				Text = function()
					local emote = props.Emote2()
					return if emote and emote.EmoteName then emote.EmoteName else ""
				end,
				TextColor3 = Color3.fromRGB(0, 170, 255),
				TextScaled = true,
				ZIndex = 2,

				create("UIStroke")({
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.08,
				}),
			}),
		}),

		create("ImageButton")({
			Name = "Emote3",
			AnchorPoint = Vector2.new(1, 0),
			BackgroundTransparency = 1,
			Image = "rbxassetid://80073985698143",
			ScaleType = Enum.ScaleType.Fit,
			ImageTransparency = 0.3,
			Position = UDim2.fromScale(0.49, 0.51),
			Size = UDim2.fromScale(0.49, 0.49),

			Activated = function()
				if props.Emote3() and props.OnSelected then
					props.OnSelected(props.Emote3().EmoteName)
				end
			end,

			useButtonEffect(0.95, 1.12),

			create("ViewportFrame")({
				BackgroundColor3 = Color3.new(),
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(2, 2),
				CurrentCamera = camera3,
				camera3,

				show(props.Emote3, function()
					return PlayerCharacter({
						UseWorldModel = true,
						Origin = CFrame.new(0, -0.25, 1.5),
						AnimationId = function()
							local emote = props.Emote3()
							return if emote then emote.AnimationId else nil
						end,
					})
				end),
			}),

			create("TextLabel")({
				Name = "EmoteName",
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundTransparency = 1,
				FontFace = Font.fromEnum(Enum.Font.FredokaOne),
				Position = UDim2.fromScale(0.5, 0.95),
				Size = UDim2.fromScale(0.9, 0.11),
				Text = function()
					local emote = props.Emote3()
					return if emote and emote.EmoteName then emote.EmoteName else ""
				end,
				TextColor3 = Color3.fromRGB(0, 170, 255),
				TextScaled = true,
				ZIndex = 2,

				create("UIStroke")({
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.08,
				}),
			}),
		}),

		create("ImageButton")({
			Name = "Emote4",
			AnchorPoint = Vector2.new(0, 0),
			BackgroundTransparency = 1,
			Image = "rbxassetid://125749684762510",
			ScaleType = Enum.ScaleType.Fit,
			ImageTransparency = 0.3,
			Position = UDim2.fromScale(0.51, 0.51),
			Size = UDim2.fromScale(0.49, 0.49),

			Activated = function()
				if props.Emote4() and props.OnSelected then
					props.OnSelected(props.Emote4().EmoteName)
				end
			end,

			useButtonEffect(0.95, 1.12),

			create("ViewportFrame")({
				BackgroundColor3 = Color3.new(),
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				CurrentCamera = camera4,
				camera4,

				show(props.Emote4, function()
					return PlayerCharacter({
						UseWorldModel = true,
						Origin = CFrame.new(0, -0.25, 1.5),
						AnimationId = function()
							local emote = props.Emote4()
							return if emote then emote.AnimationId else nil
						end,
					})
				end),
			}),

			create("TextLabel")({
				Name = "EmoteName",
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundTransparency = 1,
				FontFace = Font.fromEnum(Enum.Font.FredokaOne),
				Position = UDim2.fromScale(0.5, 0.95),
				Size = UDim2.fromScale(0.9, 0.11),
				Text = function()
					local emote = props.Emote4()
					return if emote and emote.EmoteName then emote.EmoteName else ""
				end,
				TextColor3 = Color3.fromRGB(0, 170, 255),
				TextScaled = true,
				ZIndex = 2,

				create("UIStroke")({
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.08,
				}),
			}),
		}),
	})
end
