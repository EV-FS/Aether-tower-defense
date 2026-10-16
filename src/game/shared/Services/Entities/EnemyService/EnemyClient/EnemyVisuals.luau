--/Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--/Modules
local Vide = require(ReplicatedStorage.Packages.Vide)
local UIBillboard = require(ReplicatedStorage.Shared.Modules.UI.UIBillboard)
local CharacterUtils = require(ReplicatedStorage.Shared.Modules.Utils.CharacterUtils)
local NumberUtils = require(ReplicatedStorage.Shared.Modules.Utils.NumberUtils)

local create, source, derive = Vide.create, Vide.source, Vide.derive
local root, cleanup, batch = Vide.root, Vide.cleanup, Vide.batch

--/Constants
local BAR_OFFSET = -1.25
local BAR_SIZE_STUDS = Vector2.new(5, 1.5)
local MIN_BAR_HEIGHT = 6

local HEALTH_HIGH_COLOR = Color3.fromRGB(72, 225, 119)
local HEALTH_MID_COLOR = Color3.fromRGB(255, 211, 77)
local HEALTH_LOW_COLOR = Color3.fromRGB(237, 70, 70)
local SHIELD_COLOR = Color3.fromRGB(255, 255, 0)

--/Types
type HealthBarContent = {
	Name: string,
	Health: number,
	MaxHealth: number,
	ShieldHealth: number,
	MaxShieldHealth: number,
}

local healthBars: { [number]: HealthBarContent } = {}

local function getHealthColor(ratio: number): Color3
	if ratio > 0.5 then
		return HEALTH_MID_COLOR:Lerp(HEALTH_HIGH_COLOR, (ratio - 0.5) / 0.5)
	end
	return HEALTH_LOW_COLOR:Lerp(HEALTH_MID_COLOR, ratio / 0.5)
end

local function createDivider(position: number)
	return create("Frame")({
		Name = "Divider",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(21, 21, 21),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(position, 0.5),
		Size = UDim2.fromScale(0.008, 1),
		ZIndex = 3,
	})
end

local function createHealthBar(content: HealthBarContent): UIBillboard.View<HealthBarContent>
	local health = source(content.Health)
	local maximumHealth = source(content.MaxHealth)
	local shieldHealth = source(content.ShieldHealth)
	local maximumShieldHealth = source(content.MaxShieldHealth)
	local name = source(content.Name)
	local destroyScope, gui = root(function()
		local ratio = derive(function()
			local maximum = maximumHealth()
			if maximum <= 0 then
				return 0
			end
			return math.clamp(health() / maximum, 0, 1)
		end)
		local shieldRatio = derive(function()
			local maximum = maximumShieldHealth()
			return if maximum > 0 then math.clamp(shieldHealth() / maximum, 0, 1) else 0
		end)
		local frame = create("Frame")({
			Name = "HealthBar",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(1, 1),
			create("TextLabel")({
				Name = "EnemyName",
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
				Position = UDim2.fromScale(0.5, 0.2),
				Size = UDim2.fromScale(1, 0.35),
				RichText = true,
				Text = name,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				create("UIStroke")({
					Name = "Stroke",
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.1,
				}),
			}),
			create("Frame")({
				Name = "Background",
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundColor3 = Color3.fromRGB(21, 21, 21),
				Position = UDim2.fromScale(0.5, 0.9),
				Size = UDim2.fromScale(0.9, 0.3),
				create("UICorner")({
					CornerRadius = UDim.new(1, 0),
				}),
				create("UIStroke")({
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.1,
				}),
				create("Frame")({
					BackgroundColor3 = function()
						return getHealthColor(ratio())
					end,
					Size = function()
						return UDim2.fromScale(ratio(), 1)
					end,
					create("UIGradient")({
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(168, 168, 168)),
							ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
						}),
						Rotation = -90,
					}),
					create("UICorner")({
						CornerRadius = UDim.new(1, 0),
					}),
					ZIndex = 1,
				}),
				create("Frame")({
					Name = "ShieldHealth",
					BackgroundColor3 = SHIELD_COLOR,
					Size = function()
						return UDim2.fromScale(shieldRatio(), 1)
					end,
					create("UIGradient")({
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(168, 168, 168)),
							ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
						}),
						Rotation = -90,
					}),
					create("UICorner")({
						CornerRadius = UDim.new(1, 0),
					}),
					ZIndex = 2,
				}),
				createDivider(0.1),
				createDivider(0.3),
				createDivider(0.5),
				createDivider(0.7),
				createDivider(0.9),
				create("TextLabel")({
					Name = "Health",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(1, 0.7),
					Text = function()
						local current = math.max(health(), 0)
						local shield = math.max(shieldHealth(), 0)
						local maximum = math.max(maximumHealth(), 0)
						return `{NumberUtils.FormatComma(current + shield)}/{NumberUtils.FormatComma(maximum)}`
					end,
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					create("UIStroke")({
						StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
						Thickness = 0.12,
					}),
					ZIndex = 4,
				}),
			}),
		})
		frame.Visible = false
		cleanup(function()
			frame:Destroy()
		end)
		return frame
	end)
	return {
		Gui = gui,
		SetContent = function(newContent: HealthBarContent)
			batch(function()
				name(newContent.Name)
				maximumHealth(newContent.MaxHealth)
				health(newContent.Health)
				maximumShieldHealth(newContent.MaxShieldHealth)
				shieldHealth(newContent.ShieldHealth)
			end)
		end,
		Destroy = destroyScope,
	}
end

local billboards = UIBillboard.new({
	Name = "EnemyHealthBars",
	DisplayOrder = -1,
	CreateView = createHealthBar,
})

local EnemyVisuals = {}

function EnemyVisuals.Render(_dt: number)
	billboards:Render()
end

function EnemyVisuals.Attach(enemy)
	EnemyVisuals.Destroy(enemy.Id)

	local enemyModel = enemy.Model
	local rootPart = enemyModel.PrimaryPart
	if not rootPart or enemy.Health <= 0 then
		return
	end

	local content: HealthBarContent = {
		Name = enemy.Name,
		Health = enemy.Health,
		MaxHealth = enemy.MaxHealth,
		ShieldHealth = enemy.ShieldHealth,
		MaxShieldHealth = enemy.MaxShieldHealth,
	}
	healthBars[enemy.Id] = content
	billboards:Attach(enemy.Id, {
		Adornee = rootPart,
		Offset = Vector3.new(0, CharacterUtils.GetHipHeight(enemyModel) - BAR_OFFSET, 0),
		Size = BAR_SIZE_STUDS,
		MinHeight = if enemy.IsBoss then 0 else MIN_BAR_HEIGHT,
	}, content)
end

function EnemyVisuals.Update(enemy)
	local state = healthBars[enemy.Id]
	if not state then
		return
	end
	if enemy.Health <= 0 then
		EnemyVisuals.Destroy(enemy.Id)
		return
	end

	if
		state.Health ~= enemy.Health
		or state.MaxHealth ~= enemy.MaxHealth
		or state.ShieldHealth ~= enemy.ShieldHealth
		or state.MaxShieldHealth ~= enemy.MaxShieldHealth
	then
		state.Health = enemy.Health
		state.MaxHealth = enemy.MaxHealth
		state.ShieldHealth = enemy.ShieldHealth
		state.MaxShieldHealth = enemy.MaxShieldHealth
		billboards:Update(enemy.Id, state)
		billboards:SetEnabled(enemy.Id, enemy.MaxHealth > 0)
	end
end

function EnemyVisuals.Destroy(enemyId: number)
	billboards:Remove(enemyId)
	healthBars[enemyId] = nil
end

return EnemyVisuals
