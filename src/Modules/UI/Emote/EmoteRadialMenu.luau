-- Shared radial emote menu used in every place.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerCharacter = require(script.Parent.PlayerCharacter)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create
local show = Vide.show
local source = Vide.source
local spring = Vide.spring

export type EmoteData = {
	Id: string?,
	Name: string?,
	EmoteName: string?,
	DisplayName: string?,
	AnimationId: (number | string)?,
	PlaybackSpeed: number?,
}

export type Props = {
	Emote1: () -> EmoteData?,
	Emote2: () -> EmoteData?,
	Emote3: () -> EmoteData?,
	Emote4: () -> EmoteData?,
	UserId: ((() -> number?) | number)?,
	OnSelected: (emoteName: string) -> (),
}

type SlotConfig = {
	Index: number,
	Image: string,
	Shadow: string,
	Position: UDim2,
	AnchorPoint: Vector2,
	HighlightPosition: UDim2,
	ShadowPosition: UDim2,
	NamePosition: UDim2,
	NameSize: UDim2,
	TooltipPosition: UDim2,
}

local SLOT_CONFIGS: { SlotConfig } = {
	{
		Index = 1,
		Image = "rbxassetid://85375303952247",
		Shadow = "rbxassetid://75984171493972",
		Position = UDim2.fromScale(0.2355, 0.248),
		AnchorPoint = Vector2.new(0.5, 0.5),
		HighlightPosition = UDim2.fromScale(-0.0809784, -0.0563052),
		ShadowPosition = UDim2.fromScale(0.51564, 0.51378),
		NamePosition = UDim2.fromScale(0.302812, 0.740618),
		NameSize = UDim2.fromScale(0.451239, 0.140752),
		TooltipPosition = UDim2.fromScale(0.345753, 0.88137),
	},
	{
		Index = 2,
		Image = "rbxassetid://101263877757551",
		Shadow = "rbxassetid://133628792436402",
		Position = UDim2.fromScale(0.7585, 0.248),
		AnchorPoint = Vector2.new(0.5, 0.5),
		HighlightPosition = UDim2.fromScale(-0.284901, -0.0616716),
		ShadowPosition = UDim2.fromScale(0.494174, 0.508413),
		NamePosition = UDim2.fromScale(0.0827899, 0.729886),
		NameSize = UDim2.fromScale(0.813235, 0.140752),
		TooltipPosition = UDim2.fromScale(0.281357, 0.876003),
	},
	{
		Index = 3,
		Image = "rbxassetid://93847193101743",
		Shadow = "rbxassetid://101043806354019",
		Position = UDim2.fromScale(0.2355, 0.77),
		AnchorPoint = Vector2.new(0.5, 0.5),
		HighlightPosition = UDim2.fromScale(-0.113177, -0.329991),
		ShadowPosition = UDim2.fromScale(0.510274, 0.486948),
		NamePosition = UDim2.fromScale(0.14182, 0.0537204),
		NameSize = UDim2.fromScale(0.813235, 0.140752),
		TooltipPosition = UDim2.fromScale(0.340387, 0.199838),
	},
	{
		Index = 4,
		Image = "rbxassetid://119095003806239",
		Shadow = "rbxassetid://96998108143818",
		Position = UDim2.fromScale(0.7575, 0.77),
		AnchorPoint = Vector2.new(0.5, 0.5),
		HighlightPosition = UDim2.fromScale(-0.263436, -0.372922),
		ShadowPosition = UDim2.fromScale(0.510274, 0.486948),
		NamePosition = UDim2.fromScale(0.14182, 0.0537204),
		NameSize = UDim2.fromScale(0.813235, 0.140752),
		TooltipPosition = UDim2.fromScale(0.340387, 0.199838),
	},
}

local function createCamera(): Camera
	return create("Camera")({
		FieldOfView = 50,
		CFrame = CFrame.lookAt(Vector3.new(0, 0, -5.5), Vector3.new(0, -0.3, 0)),
	})
end

local function createGradient(color: Color3)
	return create("UIGradient")({
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, color),
			ColorSequenceKeypoint.new(1, color),
		}),
	})
end

return function(props: Props)
	local emoteGetters = { props.Emote1, props.Emote2, props.Emote3, props.Emote4 }
	local hoveredSlot = source(nil :: number?)
	local pressedSlot = source(nil :: number?)

	local slots = table.create(#SLOT_CONFIGS)

	for _, config in SLOT_CONFIGS do
		local emoteGetter = emoteGetters[config.Index]
		local camera = createCamera()
		local direction = Vector2.new(
			if config.Index % 2 == 1 then -1 else 1,
			if config.Index <= 2 then -1 else 1
		)
		local offset = spring(function()
			if hoveredSlot() == config.Index then
				return 0.03
			elseif hoveredSlot() ~= nil then
				return 0.012
			end
			return 0
		end, 0.18, 0.78)

		table.insert(slots, create("ImageButton")({
			Name = `Emote{config.Index}`,
			Active = true,
			AnchorPoint = config.AnchorPoint,
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			ClipsDescendants = false,
			Image = config.Image,
			ImageTransparency = spring(function()
				return if hoveredSlot() == config.Index then 0 else 0.08
			end, 0.16, 0.82),
			Position = function()
				local amount = offset()
				return UDim2.fromScale(
					config.Position.X.Scale + direction.X * amount,
					config.Position.Y.Scale + direction.Y * amount
				)
			end,
			Rotation = spring(function()
				return if hoveredSlot() == config.Index then direction.X * 1.5 else 0
			end, 0.18, 0.78),
			Size = UDim2.fromScale(0.505, 0.522),
			ZIndex = 31,

			MouseEnter = function()
				hoveredSlot(config.Index)
			end,
			MouseLeave = function()
				if hoveredSlot() == config.Index then
					hoveredSlot(nil)
				end
				if pressedSlot() == config.Index then
					pressedSlot(nil)
				end
			end,
			MouseButton1Down = function()
				pressedSlot(config.Index)
			end,
			MouseButton1Up = function()
				if pressedSlot() == config.Index then
					pressedSlot(nil)
				end
			end,
			Activated = function()
				local emote = emoteGetter and emoteGetter()
				local emoteName = emote and (emote.EmoteName or emote.Name)
				if emoteName then
					props.OnSelected(emoteName)
				end
			end,

			create("UIAspectRatioConstraint")({}),
			create("UIScale")({
				Scale = spring(function()
					if pressedSlot() == config.Index then
						return 0.9
					elseif hoveredSlot() == config.Index then
						return 1.14
					end
					return 1
				end, 0.12, 0.72),
			}),

			create("UIGradient")({
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(86, 86, 86)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(86, 86, 86)),
				}),
			}),

			create("ViewportFrame")({
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.0687055, 0.0416977),
				Size = UDim2.fromScale(0.886604, 0.916977),
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
						PlaybackSpeed = (emoteGetter() and emoteGetter().PlaybackSpeed) or 1,
					})
				end),
			}),

			create("ImageLabel")({
				Name = "HighLight",
				BackgroundTransparency = 1,
				Image = "rbxassetid://84600302742722",
				ImageTransparency = spring(function()
					return if hoveredSlot() == config.Index then 0 else 1
				end, 0.16, 0.82),
				Position = config.HighlightPosition,
				Size = UDim2.fromScale(1.37311, 1.32613),
				ZIndex = 1,
				create("UIAspectRatioConstraint")({}),
				createGradient(Color3.fromRGB(86, 86, 86)),
			}),

			create("ImageLabel")({
				Name = "Shadow",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = config.Shadow,
				Position = config.ShadowPosition,
				Size = UDim2.fromScale(0.96872, 0.941882),
				ZIndex = 33,
				create("UIAspectRatioConstraint")({}),
				createGradient(Color3.fromRGB(86, 86, 86)),
			}),

			create("TextLabel")({
				Name = "EmoteName",
				BackgroundTransparency = 1,
				FontFace = Font.fromEnum(Enum.Font.FredokaOne),
				Position = config.NamePosition,
				Size = config.NameSize,
				Text = function()
					local emote = emoteGetter()
					return if emote then (emote.DisplayName or emote.EmoteName or "") else ""
				end,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				ZIndex = 35,
				createGradient(Color3.fromRGB(135, 245, 255)),
				create("UIStroke")({ Thickness = 3 }),
			}),

			create("TextLabel")({
				Name = "ToolTip",
				BackgroundTransparency = 1,
				FontFace = Font.fromEnum(Enum.Font.FredokaOne),
				Position = config.TooltipPosition,
				Size = UDim2.fromScale(0.333149, 0.085883),
				Text = "Tap to play",
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				ZIndex = 35,
				create("UIStroke")({ Thickness = 3 }),
				createGradient(Color3.fromRGB(193, 193, 193)),
			}),
		}))
	end

	return create("Frame")({
		Name = "Container",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 30,

		create("UIAspectRatioConstraint")({
			AspectRatio = 1.547,
			AspectType = Enum.AspectType.ScaleWithParentSize,
		}),

		create("Frame")({
			Name = "Main",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.423847, 0.640625),
			ZIndex = 30,

			create("UIAspectRatioConstraint")({}),
			unpack(slots),
		}),
	})
end
