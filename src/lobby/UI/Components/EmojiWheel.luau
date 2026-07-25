local ReplicatedStorage = game:GetService("ReplicatedStorage")
local QuadrantWheel = require(script.Parent.QuadrantWheel)
local Vide = require(ReplicatedStorage.Packages.Vide)
local useButtonEffect = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useButtonEffect)

local create = Vide.create

export type EmojiData = {
	Id: string,
	DisplayName: string?,
	Image: string,
}

export type Props = {
	Emoji1: () -> EmojiData?,
	Emoji2: () -> EmojiData?,
	Emoji3: () -> EmojiData?,
	Emoji4: () -> EmojiData?,
	OnSelected: (emojiId: string) -> (),
}

return function(props: Props)
	local emojiGetters = {
		props.Emoji1,
		props.Emoji2,
		props.Emoji3,
		props.Emoji4,
	}

	return QuadrantWheel({
		Name = "EmojiWheel",
		ZIndex = 30,
		RenderSlot = function(slotConfig)
			local emojiGetter = emojiGetters[slotConfig.Index]

			return create("ImageButton")({
				Name = `Emoji{slotConfig.Index}`,
				AnchorPoint = slotConfig.AnchorPoint,
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				Image = slotConfig.Image,
				ImageColor3 = Color3.fromRGB(235, 248, 255),
				ImageTransparency = 0.08,
				Position = slotConfig.Position,
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromScale(0.49, 0.49),
				ZIndex = 31,

				Activated = function()
					local emoji = emojiGetter and emojiGetter()
					if emoji and emoji.Image ~= "" and props.OnSelected then
						props.OnSelected(emoji.Id)
					end
				end,

				useButtonEffect(0.95, 1.12),

				create("ImageLabel")({
					Name = "EmojiImage",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = function()
						local emoji = emojiGetter()
						return if emoji then emoji.Image else ""
					end,
					Position = UDim2.fromScale(0.5, 0.46),
					ScaleType = Enum.ScaleType.Fit,
					Size = UDim2.fromScale(0.58, 0.58),
					ZIndex = 32,
				}),

				create("TextLabel")({
					Name = "EmojiName",
					AnchorPoint = Vector2.new(0.5, 1),
					BackgroundTransparency = 1,
					FontFace = Font.fromEnum(Enum.Font.FredokaOne),
					Position = UDim2.fromScale(0.5, 0.94),
					Size = UDim2.fromScale(0.78, 0.12),
					Text = function()
						local emoji = emojiGetter()
						return if emoji then (emoji.DisplayName or emoji.Id) else ""
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
