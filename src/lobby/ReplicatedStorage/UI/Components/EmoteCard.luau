local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local EmoteData = require(ReplicatedStorage.Settings.Data.EmoteData)
local CardFrame = require(ReplicatedStorage.UI.Components.Card.CardFrame)
local PlayerCharacter = require(ReplicatedStorage.Shared.Modules.UI.Emote.PlayerCharacter)

local create = Vide.create

export type Props = {
	EmoteName: string,
	LayoutOrder: number | (() -> number),
	IsSelected: () -> boolean,
	IsEquipped: () -> boolean,
	Activated: () -> (),
}

return function(props: Props)
	local info = EmoteData.ByName[props.EmoteName]
	local camera = create("Camera")({
		FieldOfView = 42,
		CFrame = CFrame.lookAt(Vector3.new(0, 0.35, -6.2), Vector3.new(0, -0.35, 0)),
	})

	return CardFrame({
		Name = props.EmoteName,
		Active = true,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.fromScale(0.239841, 0.354932),
		CornerRadius = UDim.new(0.06, 0),
		Rarity = "Rare",
		Selected = props.IsSelected,
		ShimmerEnabled = false,
		GlowEnabled = false,
		RarityBorderEnabled = false,
		PressedScale = 0.96,
		HoverScale = 1.025,
		HoverEnabled = false,
		Activated = props.Activated,
		Content = {
			create("UIAspectRatioConstraint")({}),
			create("ViewportFrame")({
				Name = "Preview",
				BackgroundTransparency = 1,
				CurrentCamera = camera,
				Position = UDim2.fromScale(0.035, 0.02),
				Size = UDim2.fromScale(0.93, 0.9),
				ZIndex = 5,
				camera,
				if info then PlayerCharacter({
					UseWorldModel = true,
					Origin = CFrame.new(0, -2.35, 1.5),
					IntroAnimationId = info.IntroAnimationId,
					AnimationId = info.AnimationId,
					Looped = info.Looped == true,
					PlaybackSpeed = info.PlaybackSpeed or 1,
				}) else nil,
			}),
			create("TextLabel")({
				Name = "EmoteName",
				AnchorPoint = Vector2.new(0, 1),
				BackgroundTransparency = 1,
				FontFace = Font.fromEnum(Enum.Font.FredokaOne),
				Position = UDim2.fromScale(0.075, 0.94),
				Size = UDim2.fromScale(0.82, 0.14),
				Text = info and (info.DisplayName or info.Name) or props.EmoteName,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 9,
				create("UIStroke")({ Thickness = 2 }),
			}),
			create("ImageLabel")({
				Name = "EquippedCheck",
				AnchorPoint = Vector2.new(1, 0),
				BackgroundTransparency = 1,
				Image = "rbxassetid://91966631627808",
				Position = UDim2.fromScale(0.96, 0.04),
				Size = UDim2.fromScale(0.2, 0.2),
				ScaleType = Enum.ScaleType.Fit,
				Visible = props.IsEquipped,
				ZIndex = 10,
				create("UIAspectRatioConstraint")({}),
			}),
		},
	})
end
