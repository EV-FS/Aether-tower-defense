local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local RarityRegistry = require(ReplicatedStorage.Shared.Modules.Core.Rarity.RarityRegistry)
local useButtonEffect = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useButtonEffect)
local useButtonHoverEffect = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useButtonHoverEffect)
local useColorSequenceCycle = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useColorSequenceCycle)

local action = Vide.action
local create = Vide.create
local derive = Vide.derive
local read = Vide.read

type Reactive<T> = T | (() -> T)

type Props = {
	Active: Reactive<boolean>?,
	AnchorPoint: Reactive<Vector2>?,
	ClipsDescendants: Reactive<boolean>?,
	LayoutOrder: Reactive<number>?,
	Name: Reactive<string>?,
	Position: Reactive<UDim2>?,
	Rotation: Reactive<number>?,
	Size: Reactive<UDim2>?,
	Visible: Reactive<boolean>?,
	ZIndex: Reactive<number>?,

	AssetType: string?,
	AssetProps: any?,
	Rarity: Reactive<string>?,
	UseButtonEffect: boolean?,

	OnActivated: (() -> nil)?,
}

local AssetComponents = {
	Currency = require(script.Currency),
	Tower = require(script.Tower),
	Item = require(script.Item),
}

local function set(reactive, default)
	return function()
		return read(reactive) or default
	end
end

return function(props: Props)
	local gradientData = derive(function()
		local rarityEntity = RarityRegistry.Get(props.Rarity)

		return rarityEntity and rarityEntity.Presentation
	end)

	return create("ImageButton")({
		Active = props.Active,
		AnchorPoint = set(props.AnchorPoint, Vector2.new(0.5, 0.5)),
		ClipsDescendants = props.ClipsDescendants,
		BackgroundTransparency = 1,
		Image = "rbxassetid://87496848270095",
		LayoutOrder = props.LayoutOrder,
		Name = set(props.Name, "Slot"),
		Position = props.Position,
		Rotation = props.Rotation,
		Size = set(props.Size, UDim2.fromScale(0.186, 0.339)),
		Visible = props.Visible,
		ZIndex = props.ZIndex,

		create("UIAspectRatioConstraint")({}),

		create("UIGradient")({
			useColorSequenceCycle(function()
				return gradientData().Gradient or ColorSequence.new(Color3.new())
			end, function()
				return gradientData().ShimmerSpeed or 1
			end),

			Rotation = 45,
		}),

		create("UICorner")({
			CornerRadius = UDim.new(0.1, 0),
		}),

		if props.UseButtonEffect then useButtonEffect() else nil,
		if props.UseButtonEffect then useButtonHoverEffect() else nil,

		action(function(slotFrame)
			local targetComponent = AssetComponents[props.AssetType]
			if targetComponent then
				local content = targetComponent(props.AssetProps)

				content.Parent = slotFrame
			end
		end),
	})
end
