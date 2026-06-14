local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local InstanceCache = require(ReplicatedStorage.Shared.Modules.Core.InstanceCache)
local CharacterUtils = require(ReplicatedStorage.Shared.Modules.Utils.CharacterUtils)

local Visuals = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Visuals")
local HealthBarGui = Visuals:WaitForChild("HealthBarGui") :: BillboardGui
local CacheFolder = workspace:WaitForChild("Caches")

local BAR_OFFSET = 0.45
local CACHE_SIZE = 30
local TWEEN_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local HEALTH_HIGH_COLOR = Color3.fromRGB(52, 152, 219)
local HEALTH_MID_COLOR = Color3.fromRGB(155, 89, 182)
local HEALTH_LOW_COLOR = Color3.fromRGB(237, 70, 70)

type HealthBarState = {
	Gui: BillboardGui,
	Fill: Frame,
	HealthText: TextLabel,
	Tween: Tween?,
	MaxHealth: number,
}

local HealthBarStorage = InstanceCache.new(HealthBarGui, CACHE_SIZE, CacheFolder)
local healthBars: { [number]: HealthBarState } = {}

-------------------------------------------------
--// Local Functions
-------------------------------------------------
local function getAdornee(model: Model): (BasePart?, Vector3)
	local primaryPart = model.PrimaryPart
	if primaryPart then
		return primaryPart, Vector3.new(0, CharacterUtils.GetHipHeight(model) - BAR_OFFSET, 0)
	end

	return nil, Vector3.zero
end

local function getHealthColor(ratio: number): Color3
	if ratio > 0.5 then
		return HEALTH_MID_COLOR:Lerp(HEALTH_HIGH_COLOR, (ratio - 0.5) / 0.5)
	end

	return HEALTH_LOW_COLOR:Lerp(HEALTH_MID_COLOR, ratio / 0.5)
end

local function createBar(unitModel: Model, unitName: string, maxHealth: number): HealthBarState?
	local adornee, offset = getAdornee(unitModel)
	if not adornee then
		return nil
	end

	local healthGui = HealthBarStorage:GetInstance() :: BillboardGui
	healthGui.Adornee = adornee
	healthGui.StudsOffsetWorldSpace = offset
	healthGui.Parent = adornee

	local nameText = healthGui:WaitForChild("EnemyName") :: TextLabel
	nameText.Text = unitName

	local background = healthGui:WaitForChild("Background") :: Frame
	local fillBar = background:WaitForChild("Bar") :: Frame
	fillBar.BackgroundColor3 = HEALTH_HIGH_COLOR
	fillBar.Size = UDim2.fromScale(1, 1)

	local healthText = background:WaitForChild("Health") :: TextLabel
	healthText.Text = `{maxHealth}/{maxHealth}`

	healthGui.Enabled = true

	return {
		Gui = healthGui,
		Fill = fillBar,
		HealthText = healthText,
		Tween = nil,
		MaxHealth = maxHealth,
	}
end

-------------------------------------------------
--// UnitVisuals
-------------------------------------------------
local UnitVisuals = {}

function UnitVisuals.Attach(unitId: number, unitName: string, unitModel: Model, maxHealth: number)
	UnitVisuals.Destroy(unitId)

	if maxHealth <= 0 then
		return
	end

	local state = createBar(unitModel, unitName, maxHealth)
	if state then
		healthBars[unitId] = state
	end
end

function UnitVisuals.Update(unitId: number, health: number, maxHealth: number?)
	local state = healthBars[unitId]
	if not state then
		return
	end

	local targetMaxHealth = maxHealth or state.MaxHealth
	if targetMaxHealth <= 0 then
		return
	end

	state.MaxHealth = targetMaxHealth

	local ratio = math.clamp(health / targetMaxHealth, 0, 1)
	local targetHealth = math.clamp(health, 0, targetMaxHealth)
	local targetText = `{targetHealth}/{targetMaxHealth}`
	local targetSize = UDim2.fromScale(ratio, 1)
	local targetColor = getHealthColor(ratio)

	state.HealthText.Text = targetText

	if state.Tween then
		state.Tween:Cancel()
	end

	state.Tween = TweenService:Create(state.Fill, TWEEN_INFO, {
		BackgroundColor3 = targetColor,
		Size = targetSize,
	})
	state.Tween:Play()
end

function UnitVisuals.Destroy(unitId: number)
	local state = healthBars[unitId]
	if not state then
		return
	end

	if state.Tween then
		state.Tween:Cancel()
		state.Tween = nil
	end

	if state.Gui then
		state.Gui.Enabled = false
		state.Gui.Adornee = nil
		HealthBarStorage:ReturnInstance(state.Gui)
	end

	healthBars[unitId] = nil
end

return UnitVisuals
