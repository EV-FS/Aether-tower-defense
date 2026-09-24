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
	IntroAnimationId: (number | string)?,
	Looped: boolean?,
	PlaybackSpeed: number?,
}

export type Props = {
	Emotes: { () -> EmoteData? },
	EquipMode: (boolean | (() -> boolean))?,
	UserId: ((() -> number?) | number)?,
	OnSelected: (emoteName: string) -> (),
	OnSlotSelected: ((slotIndex: number, emoteName: string?) -> ())?,
	SlotActionText: (string | ((slotIndex: number, emoteName: string?) -> string))?,
	InteractionDisabled: (boolean | (() -> boolean))?,
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
		Position = UDim2.fromScale(0.233624, 0.237624),
		AnchorPoint = Vector2.new(0.5, 0.5),
		HighlightPosition = UDim2.fromScale(0.579434, 0.604107),
		ShadowPosition = UDim2.fromScale(0.51564, 0.51378),
		NamePosition = UDim2.fromScale(0.525554, 0.810958),
		NameSize = UDim2.fromScale(0.451239, 0.140752),
		TooltipPosition = UDim2.fromScale(0.509879, 0.920447),
	},
	{
		Index = 2,
		Image = "rbxassetid://101263877757551",
		Shadow = "rbxassetid://133628792436402",
		Position = UDim2.fromScale(0.756624, 0.237624),
		AnchorPoint = Vector2.new(0.5, 0.5),
		HighlightPosition = UDim2.fromScale(0.375511, 0.59874),
		ShadowPosition = UDim2.fromScale(0.494174, 0.508413),
		NamePosition = UDim2.fromScale(0.489197, 0.800225),
		NameSize = UDim2.fromScale(0.813235, 0.140752),
		TooltipPosition = UDim2.fromScale(0.445483, 0.915081),
	},
	{
		Index = 3,
		Image = "rbxassetid://93847193101743",
		Shadow = "rbxassetid://101043806354019",
		Position = UDim2.fromScale(0.233624, 0.759624),
		AnchorPoint = Vector2.new(0.5, 0.5),
		HighlightPosition = UDim2.fromScale(0.547235, 0.330421),
		ShadowPosition = UDim2.fromScale(0.510274, 0.486948),
		NamePosition = UDim2.fromScale(0.548228, 0.12406),
		NameSize = UDim2.fromScale(0.813235, 0.140752),
		TooltipPosition = UDim2.fromScale(0.504513, 0.238916),
	},
	{
		Index = 4,
		Image = "rbxassetid://119095003806239",
		Shadow = "rbxassetid://96998108143818",
		Position = UDim2.fromScale(0.755624, 0.759624),
		AnchorPoint = Vector2.new(0.5, 0.5),
		HighlightPosition = UDim2.fromScale(0.396976, 0.28749),
		ShadowPosition = UDim2.fromScale(0.510274, 0.486948),
		NamePosition = UDim2.fromScale(0.473098, 0.12406),
		NameSize = UDim2.fromScale(0.813235, 0.140752),
		TooltipPosition = UDim2.fromScale(0.428, 0.238916),
	},
}

local function getSlotConfigs(count: number): { SlotConfig }
	if count <= #SLOT_CONFIGS then
		return SLOT_CONFIGS
	end

	local configs = table.create(count)
	for index = 1, count do
		local base = SLOT_CONFIGS[(index - 1) % #SLOT_CONFIGS + 1]
		local angle = -math.pi / 2 + (index - 1) * math.pi * 2 / count
		local position = UDim2.fromScale(0.5 + math.cos(angle) * 0.27, 0.5 + math.sin(angle) * 0.27)
		table.insert(configs, {
			Index = index,
			Image = base.Image,
			Shadow = base.Shadow,
			Position = position,
			AnchorPoint = Vector2.new(0.5, 0.5),
			HighlightPosition = UDim2.fromScale(-0.18, -0.18),
			ShadowPosition = UDim2.fromScale(0.5, 0.5),
			NamePosition = UDim2.fromScale(0.1, 0.78),
			NameSize = UDim2.fromScale(0.8, 0.14),
			TooltipPosition = UDim2.fromScale(0.3, 0.9),
		})
	end

	return configs
end

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
	local emoteGetters = props.Emotes
	local slotConfigs = getSlotConfigs(#emoteGetters)
	local hoveredSlot = source(nil :: number?)
	local pressedSlot = source(nil :: number?)

	local slots = table.create(#slotConfigs)

	for _, config in slotConfigs do
		local emoteGetter = emoteGetters[config.Index]
		local function isEquipMode(): boolean
			return if type(props.EquipMode) == "function" then props.EquipMode() else props.EquipMode == true
		end
		local function canInteract(): boolean
			local disabled = props.InteractionDisabled
			local isDisabled = if type(disabled) == "function" then disabled() else disabled == true
			return not isDisabled and (isEquipMode() or emoteGetter() ~= nil)
		end
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
			Active = canInteract,
			Interactable = canInteract,
			AnchorPoint = config.AnchorPoint,
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			ClipsDescendants = false,
			Image = config.Image,
			ImageTransparency = spring(function()
				return if canInteract() and hoveredSlot() == config.Index then 0 else 0.08
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
			Size = UDim2.fromScale(0.505, 0.505),
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
				if not canInteract() then return end
				local emote = emoteGetter and emoteGetter()
				local emoteName = emote and (emote.EmoteName or emote.Name)
				if props.OnSlotSelected then
					props.OnSlotSelected(config.Index, emoteName)
				elseif emoteName then
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
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.510283, 0.498906),
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
						IntroAnimationId = function()
							local emote = emoteGetter()
							return if emote then emote.IntroAnimationId else nil
						end,
						Looped = function()
							local emote = emoteGetter()
							return emote ~= nil and emote.Looped == true
						end,
						PlaybackSpeed = (emoteGetter() and emoteGetter().PlaybackSpeed) or 1,
					})
				end),
			}),

			create("ImageLabel")({
				Name = "HighLight",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = "rbxassetid://84600302742722",
				ImageTransparency = spring(function()
					return if hoveredSlot() == config.Index then 0 else 1
				end, 0.16, 0.82),
				Position = config.HighlightPosition,
				Size = UDim2.fromScale(1.32613, 1.32613),
				ZIndex = -1,
				create("UIAspectRatioConstraint")({}),
				createGradient(Color3.fromRGB(86, 86, 86)),
			}),

			create("ImageLabel")({
				Name = "Shadow",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = config.Shadow,
				Position = config.ShadowPosition,
				Size = UDim2.fromScale(0.941882, 0.941882),
				ZIndex = 33,
				create("UIAspectRatioConstraint")({}),
				createGradient(Color3.fromRGB(86, 86, 86)),
			}),

			create("TextLabel")({
				Name = "EmoteName",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.fromEnum(Enum.Font.FredokaOne),
				Position = config.NamePosition,
				Size = config.NameSize,
				Text = function()
					local emote = emoteGetter()
					return if emote then (emote.DisplayName or emote.EmoteName or "") else "Empty"
				end,
				TextColor3 = function()
					return if emoteGetter() then Color3.new(1, 1, 1) else Color3.fromRGB(177, 177, 177)
				end,
				TextScaled = true,
				ZIndex = 35,
				create("UIGradient")({
					Color = ColorSequence.new(Color3.fromRGB(53, 76, 231), Color3.fromRGB(58, 212, 255)),
					Enabled = function() return emoteGetter() ~= nil end,
					Rotation = 90,
				}),
				create("UIStroke")({ Thickness = 3 }),
			}),

			create("TextLabel")({
				Name = "ToolTip",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.fromEnum(Enum.Font.FredokaOne),
				Position = config.TooltipPosition,
				Size = UDim2.fromScale(0.333149, 0.085883),
				Text = function()
					local actionText = props.SlotActionText
					local emote = emoteGetter()
					local emoteName = emote and (emote.EmoteName or emote.Name)
					if type(actionText) == "function" then return actionText(config.Index, emoteName) end
					return actionText or "Tap to play"
				end,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				Visible = function() return emoteGetter() ~= nil or isEquipMode() end,
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
		Size = UDim2.fromScale(0.753032, 1),
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
			Size = UDim2.fromScale(0.414108, 0.640625),
			ZIndex = 30,

			create("UIAspectRatioConstraint")({}),
			unpack(slots),
		}),
	})
end
