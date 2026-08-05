local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

export type SlotConfig = {
	Index: number,
	AnchorPoint: Vector2,
	Position: UDim2,
	Image: string,
}

export type Props = {
	Name: string,
	ZIndex: number?,
	RenderSlot: (SlotConfig) -> GuiObject,
}

local SLOT_CONFIGS: { SlotConfig } = {
	{
		Index = 1,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(0.49, 0.49),
		Image = "rbxassetid://74473551495859",
	},
	{
		Index = 2,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0.51, 0.49),
		Image = "rbxassetid://140267716361991",
	},
	{
		Index = 3,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(0.49, 0.51),
		Image = "rbxassetid://80073985698143",
	},
	{
		Index = 4,
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromScale(0.51, 0.51),
		Image = "rbxassetid://125749684762510",
	},
}

return function(props: Props)
	local slots = table.create(#SLOT_CONFIGS)

	for _, slotConfig in ipairs(SLOT_CONFIGS) do
		table.insert(slots, props.RenderSlot(slotConfig))
	end

	return create("Frame")({
		Name = props.Name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.49, 0.49),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		ZIndex = props.ZIndex or 1,

		unpack(slots),
	})
end
