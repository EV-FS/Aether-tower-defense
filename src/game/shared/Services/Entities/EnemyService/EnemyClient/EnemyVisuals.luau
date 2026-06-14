local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local InstanceCache = require(ReplicatedStorage.Shared.Modules.Core.InstanceCache)
local CharacterUtils = require(ReplicatedStorage.Shared.Modules.Utils.CharacterUtils)

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local Visuals = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Visuals")
local HealthBarGui = Visuals:WaitForChild("HealthBarGui") :: BillboardGui
local CacheFolder = workspace:WaitForChild("Caches")

local BAR_OFFSET = 0.45
local CACHE_SIZE = 30
local TWEEN_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local HEALTH_HIGH_COLOR = Color3.fromRGB(72, 225, 119)
local HEALTH_MID_COLOR = Color3.fromRGB(255, 211, 77)
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

local function createBar(enemyModel: Model, enemyName: string, maxHealth: number): HealthBarState?
	local adornee, offset = getAdornee(enemyModel)
	if not adornee then
		return nil
	end

	local healthGui = HealthBarStorage:GetInstance() :: BillboardGui
	healthGui.Adornee = adornee
	healthGui.StudsOffsetWorldSpace = offset
	healthGui.Parent = playerGui:WaitForChild("Billboard")

	local nameText = healthGui:WaitForChild("EnemyName") :: TextLabel
	nameText.Text = enemyName

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
--// EnemyVisuals
-------------------------------------------------
local EnemyVisuals = {}

function EnemyVisuals.Attach(enemyId: number, enemyName: string, enemyModel: Model, maxHealth: number)
	EnemyVisuals.Destroy(enemyId)

	if maxHealth <= 0 then
		return
	end

	local state = createBar(enemyModel, enemyName, maxHealth)
	if state then
		healthBars[enemyId] = state
	end
end

function EnemyVisuals.Update(enemyId: number, health: number, maxHealth: number?)
	local state = healthBars[enemyId]
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

function EnemyVisuals.Destroy(enemyId: number)
	local state = healthBars[enemyId]
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

	healthBars[enemyId] = nil
end

return EnemyVisuals
