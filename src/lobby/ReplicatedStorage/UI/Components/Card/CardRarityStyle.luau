local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local RarityRegistry = require(ReplicatedStorage.Shared.Modules.Core.Rarity.RarityRegistry)
local useColorSequenceCycle = require(ReplicatedStorage.Shared.Modules.UI.Hooks.useColorSequenceCycle)

local create = Vide.create
local read = Vide.read

type Reactive<T> = T | (() -> T)

export type Props = {
	Rarity: Reactive<string>,
	Enabled: Reactive<boolean>?,
	FallbackGradient: ColorSequence?,
	PerformanceMode: boolean?,
	ShimmerEnabled: boolean?,
	GlowEnabled: boolean?,
	BorderEnabled: boolean?,
}

local DEFAULT_FALLBACK = ColorSequence.new(Color3.fromRGB(72, 76, 86))

local function enabled(props: Props): boolean
	return props.Enabled == nil or read(props.Enabled)
end

local function presentation(props: Props)
	return RarityRegistry.Get(read(props.Rarity)).Presentation
end

local function effectLevel(props: Props): number
	if not enabled(props) then
		return 0
	end
	return math.clamp(8 - RarityRegistry.GetOrder(read(props.Rarity)), 1, 7)
end

return function(props: Props)
	local shimmerEnabled = props.ShimmerEnabled ~= false and props.PerformanceMode ~= true
	local glowEnabled = props.GlowEnabled ~= false and props.PerformanceMode ~= true
	local borderEnabled = props.BorderEnabled ~= false
	local gradient = function()
		return if enabled(props) then presentation(props).Gradient else props.FallbackGradient or DEFAULT_FALLBACK
	end
	local cycleTime = function()
		return math.max(5.4 - effectLevel(props) * 0.48, 2.5)
	end
	local cycles = function()
		return shimmerEnabled and enabled(props) and effectLevel(props) >= 3
	end

	return {
		create("UIGradient")({
			Name = "CardRarityBackground",
			Color = gradient,
			Rotation = 45,
			if shimmerEnabled then useColorSequenceCycle(gradient, cycleTime, cycles) else nil,
		}),
		if glowEnabled then create("UIShadow")({
			Name = "CardRarityGlow",
			BlurRadius = function()
				return UDim.new(0.018 + effectLevel(props) * 0.008, 0)
			end,
			Color = function()
				return presentation(props).Glow
			end,
			Transparency = function()
				local level = effectLevel(props)
				if level <= 1 then return 1 end
				return math.max(1.04 - level * 0.115, 0.32)
			end,
			ZIndex = -1,
		}) else nil,
		if borderEnabled then create("UIStroke")({
			Name = "CardRarityStroke",
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Color3.new(1, 1, 1),
			Thickness = function()
				return 0.75 + effectLevel(props) * 0.27
			end,
			Transparency = function()
				local level = effectLevel(props)
				return if level > 0 then math.max(0.82 - level * 0.135, 0.02) else 1
			end,

			create("UIGradient")({
				Name = "CardRarityStrokeGradient",
				Color = gradient,
				Rotation = 45,
				if shimmerEnabled then useColorSequenceCycle(gradient, cycleTime, cycles) else nil,
			}),
		}) else nil,
	}
end
