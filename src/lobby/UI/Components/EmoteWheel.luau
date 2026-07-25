local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerCharacter = require(script.Parent.PlayerCharacter)
local QuadrantWheel = require(script.Parent.QuadrantWheel)
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
	local emoteGetters = {
		props.Emote1,
		props.Emote2,
		props.Emote3,
		props.Emote4,
	}

	return QuadrantWheel({
		Name = "EmoteWheel",
		ZIndex = 30,
		RenderSlot = function(slotConfig)
			local camera = createCamera()
			local emoteGetter = emoteGetters[slotConfig.Index]

			return create("ImageButton")({
				Name = `Emote{slotConfig.Index}`,
				AnchorPoint = slotConfig.AnchorPoint,
				BackgroundTransparency = 1,
				Image = slotConfig.Image,
				ScaleType = Enum.ScaleType.Fit,
				ImageTransparency = 0.3,
				Position = slotConfig.Position,
				Size = UDim2.fromScale(0.49, 0.49),
				ZIndex = 31,

				Activated = function()
					if emoteGetter and emoteGetter() and props.OnSelected then
						local emote = emoteGetter()
						if emote and emote.EmoteName then
							props.OnSelected(emote.EmoteName)
						end
					end
				end,

				useButtonEffect(0.95, 1.12),

				create("ViewportFrame")({
					BackgroundColor3 = Color3.new(),
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
					CurrentCamera = camera,
					ZIndex = 31,
					camera,

					show(emoteGetter, function()
						return PlayerCharacter({
							UseWorldModel = true,
							Origin = CFrame.new(0, -0.25, 1.5),
							AnimationId = function()
								local emote = emoteGetter()
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
						local emote = emoteGetter()
						return if emote and (emote.DisplayName or emote.EmoteName)
							then (emote.DisplayName or emote.EmoteName)
							else ""
					end,
					TextColor3 = Color3.fromRGB(0, 170, 255),
					TextScaled = true,
					ZIndex = 32,

					create("UIStroke")({
						StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
						Thickness = 0.08,
					}),
				}),
			})
		end,
	})
end
