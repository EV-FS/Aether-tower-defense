local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local CardRarityStyle = require(script.Parent.CardRarityStyle)
local RarityRegistry = require(ReplicatedStorage.Shared.Modules.Core.Rarity.RarityRegistry)
local useButtonEffect = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useButtonEffect)

local create = Vide.create
local read = Vide.read
local source = Vide.source
local spring = Vide.spring

type Reactive<T> = T | (() -> T)

export type Props = {
	Name: string?,
	RootType: "ImageButton" | "Frame"?,
	Bind: any?,
	Active: Reactive<boolean>?,
	AnchorPoint: Reactive<Vector2>?,
	BackgroundColor3: Reactive<Color3>?,
	BackgroundTransparency: Reactive<number>?,
	Position: Reactive<UDim2>?,
	Size: Reactive<UDim2>?,
	LayoutOrder: Reactive<number>?,
	Rotation: Reactive<number>?,
	Visible: Reactive<boolean>?,
	ZIndex: Reactive<number>?,
	ClipsDescendants: boolean?,
	Image: string?,
	ImageColor3: Reactive<Color3>?,
	ImageTransparency: Reactive<number>?,
	Rarity: Reactive<string>,
	RarityEnabled: Reactive<boolean>?,
	FallbackGradient: ColorSequence?,
	PerformanceMode: boolean?,
	ShimmerEnabled: boolean?,
	GlowEnabled: boolean?,
	RarityBorderEnabled: boolean?,
	HoverEnabled: boolean?,
	HoverRotation: number?,
	HoverImageTransparency: number?,
	Selected: Reactive<boolean>?,
	Equipped: Reactive<boolean>?,
	CornerRadius: UDim?,
	ButtonEffect: boolean?,
	PressedScale: number?,
	HoverScale: number?,
	Activated: (() -> ())?,
	Content: any?,
}

local DEFAULT_IMAGE = "rbxassetid://87496848270095"

local function readOptional(value, fallback)
	return if value == nil then fallback else read(value)
end

return function(props: Props)
	local rootType = props.RootType or "ImageButton"
	local isButton = rootType == "ImageButton"
	local hoverEnabled = isButton and props.HoverEnabled ~= false and props.PerformanceMode ~= true
	local hovered = source(false)
	-- Performance cards do not allocate dormant hover springs or audio actions.
	local hoverTransparency = if hoverEnabled then spring(function()
		return if hovered() then props.HoverImageTransparency or 0.72 else 1
	end, 0.16, 0.82) else 1
	local hoverStrokeTransparency = if hoverEnabled then spring(function()
		return if hovered() then 0.05 else 1
	end, 0.14, 0.8) else 1
	local rotation = if hoverEnabled then spring(function()
		local base = readOptional(props.Rotation, 0)
		return base + (if hovered() then props.HoverRotation or 0 else 0)
	end, 0.18, 0.78) else props.Rotation or 0
	local cornerRadius = props.CornerRadius or UDim.new(0.08)
	local function selected(): boolean return readOptional(props.Selected, false) end
	local function equipped(): boolean return readOptional(props.Equipped, false) end
	local buttonEffect = if isButton and props.ButtonEffect ~= false and props.PerformanceMode ~= true
		then useButtonEffect(props.PressedScale, props.HoverScale)
		else nil
	local rarityGradient = function()
		return RarityRegistry.Get(read(props.Rarity)).Presentation.Gradient
	end

	local properties = {
		props.Bind,
		Name = props.Name or "CardFrame",
		Active = props.Active,
		AnchorPoint = props.AnchorPoint,
		BackgroundColor3 = props.BackgroundColor3 or Color3.new(1, 1, 1),
		BackgroundTransparency = props.BackgroundTransparency
			or (if isButton then 1 else 0),
		BorderSizePixel = 0,
		ClipsDescendants = props.ClipsDescendants == true,
		LayoutOrder = props.LayoutOrder,
		Position = props.Position,
		Rotation = rotation,
		Size = props.Size or UDim2.fromScale(1, 1),
		Visible = props.Visible,
		ZIndex = props.ZIndex,

		CardRarityStyle({
			Rarity = props.Rarity,
			Enabled = props.RarityEnabled,
			FallbackGradient = props.FallbackGradient,
			PerformanceMode = props.PerformanceMode,
			ShimmerEnabled = props.ShimmerEnabled,
			GlowEnabled = props.GlowEnabled,
			BorderEnabled = props.RarityBorderEnabled,
		}),
		buttonEffect,

		create("UICorner")({ Name = "CardCorner", CornerRadius = cornerRadius }),

		create("UIStroke")({
			Name = "CardStateStroke",
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = function()
				return if equipped() then Color3.new(0, 1, 0) else Color3.new(1, 1, 1)
			end,
			Thickness = 3,
			Transparency = function()
				return if selected() or equipped() then 0 else 1
			end,
		}),

		if hoverEnabled then create("ImageLabel")({
			Name = "CardHoverHighlight",
			Active = false,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = props.Image or DEFAULT_IMAGE,
			ImageTransparency = hoverTransparency,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.95, 0.95),
			ZIndex = 2,
			create("UICorner")({ CornerRadius = cornerRadius }),
			create("UIGradient")({ Color = rarityGradient, Rotation = 45 }),
		}) else nil,

		if hoverEnabled then create("UIStroke")({
			Name = "CardHoverStroke",
			Color = Color3.new(1, 1, 1),
			Thickness = 2,
			Transparency = hoverStrokeTransparency,
		}) else nil,

		props.Content,
	}

	if isButton then
		properties.AutoButtonColor = false
		properties.Image = props.Image or DEFAULT_IMAGE
		properties.ImageColor3 = props.ImageColor3 or Color3.new(1, 1, 1)
		properties.ImageTransparency = props.ImageTransparency or 0
		properties.Activated = props.Activated
		properties.MouseEnter = function() hovered(true) end
		properties.MouseLeave = function() hovered(false) end
	end

	return create(rootType)(properties)
end
