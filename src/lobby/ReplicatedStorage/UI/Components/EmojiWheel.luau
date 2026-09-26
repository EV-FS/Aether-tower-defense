local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local EmoteRadialMenu = require(ReplicatedStorage.Shared.Modules.UI.Emote.EmoteRadialMenu)

local create = Vide.create

export type EmojiEntry = { Id: string, Name: string, DisplayName: string, Image: string, Symbol: string }
export type Props = {
	Emojis: { () -> EmojiEntry? },
	EquipMode: (() -> boolean)?,
	InteractionDisabled: (() -> boolean)?,
	OnSelected: (string) -> (),
	OnSlotSelected: ((number, string?) -> ())?,
}

return function(props: Props)
	return EmoteRadialMenu({
		Emotes = props.Emojis,
		EquipMode = props.EquipMode,
		InteractionDisabled = props.InteractionDisabled,
		OnSelected = props.OnSelected,
		OnSlotSelected = props.OnSlotSelected,
		SlotActionText = function(_slot, emojiId)
			if props.EquipMode and props.EquipMode() then
				return if emojiId then "Tap to Replace" else "Tap to Equip"
			end
			return "Tap to show"
		end,
		RenderPreview = function(_slot, getEmoji)
			return create("Frame")({
				Name = "EmojiPreview",
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.08, 0.08),
				Size = UDim2.fromScale(0.84, 0.67),
				ZIndex = 34,
				create("ImageLabel")({
					Name = "EmojiImage",
					BackgroundTransparency = 1,
					Image = function()
						local emoji = getEmoji()
						return if emoji then emoji.Image else ""
					end,
					ScaleType = Enum.ScaleType.Fit,
					Size = UDim2.fromScale(1, 1),
					Visible = function()
						local emoji = getEmoji()
						return emoji ~= nil and emoji.Image ~= ""
					end,
				}),
				create("TextLabel")({
					Name = "EmojiSymbol",
					BackgroundTransparency = 1,
					FontFace = Font.fromEnum(Enum.Font.FredokaOne),
					Size = UDim2.fromScale(1, 1),
					Text = function()
						local emoji = getEmoji()
						return if emoji then emoji.Symbol else "+"
					end,
					TextColor3 = Color3.fromRGB(115, 215, 255),
					TextScaled = true,
					Visible = function()
						local emoji = getEmoji()
						return emoji == nil or emoji.Image == ""
					end,
					create("UIStroke")({ Thickness = 3, Color = Color3.fromRGB(20, 28, 62) }),
				}),
			})
		end,
	})
end
