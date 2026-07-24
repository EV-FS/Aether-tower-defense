local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local EmoteWheel = require(ReplicatedStorage.UI.Components.EmoteWheel)
local EmoteClient

local create = Vide.create
local source = Vide.source

local playerEmote = {
	Emote1 = source({ EmoteName = "Mesmerizer", AnimationId = "103556706215217" }),
	Emote2 = source({ EmoteName = "Shutter", AnimationId = "132177421118009" }),
	Emote3 = source(),
	Emote4 = source(),
	OnSelected = nil,
}

local EmoteUI = {}

function EmoteUI.OnSelected(emoteName)
	EmoteClient = EmoteClient or ServiceRegistry:GetService("EmoteClient")

	EmoteClient.PlayEmote(emoteName)
end

function EmoteUI.RenderUI()
	return create("Frame")({
		Name = "EmoteFrame",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromScale(1, 1),

		create("TextLabel")({
			Name = "Title",
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			FontFace = Font.fromEnum(Enum.Font.GothamBold),
			Position = UDim2.fromScale(0.5, 0.12),
			Size = UDim2.fromScale(0.4, 0.045),
			Text = "Emote Wheel",
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,

			create("UIStroke")({
				Name = "UIStroke",
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.08,
			}),
		}),

		EmoteWheel(playerEmote),
	})
end

function EmoteUI.Init() end

function EmoteUI.Start()
	playerEmote.OnSelected = EmoteUI.OnSelected
end

return EmoteUI
