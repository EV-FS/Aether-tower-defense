local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local CharacterUtils = require(ReplicatedStorage.Shared.Modules.Utils.CharacterUtils)

local create, source, derive = Vide.create, Vide.source, Vide.derive
local root, cleanup, batch = Vide.root, Vide.cleanup, Vide.batch

--// Settings
local BAR_OFFSET = -1.25
local BAR_SIZE_STUDS = Vector2.new(5, 1.5)
local MIN_BAR_HEIGHT = 6

local SIZE_UPDATE_INTERVAL = 1 / 30

local HEALTH_HIGH_COLOR = Color3.fromRGB(72, 225, 119)
local HEALTH_MID_COLOR = Color3.fromRGB(255, 211, 77)
local HEALTH_LOW_COLOR = Color3.fromRGB(237, 70, 70)

type HealthBarView = {
	Gui: Frame,
	SetContent: (enemyName: string, health: number, maxHealth: number) -> (),
	Destroy: () -> (),
}

type HealthBarState = {
	Name: string,
	IsBoss: boolean,
	RootPart: BasePart,
	Offset: Vector3,
	Health: number,
	MaxHealth: number,
	Dirty: boolean,
	View: HealthBarView?,
}

local healthBars: { [number]: HealthBarState } = {}
local availableViews: { HealthBarView } = {}

local healthBarContainer = Instance.new("ScreenGui")
healthBarContainer.Name = "EnemyHealthBars"
healthBarContainer.IgnoreGuiInset = true
healthBarContainer.ResetOnSpawn = false
healthBarContainer.DisplayOrder = -1
healthBarContainer.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
healthBarContainer.Enabled = false
healthBarContainer.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

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
	})
end

local function createHealthBar(enemyName: string, maxHealth: number): HealthBarView
	local health = source(maxHealth)
	local maximumHealth = source(maxHealth)
	local name = source(enemyName)
	local destroyScope, gui = root(function()
		local ratio = derive(function()
			local maximum = maximumHealth()
			if maximum <= 0 then
				return 0
			end
			return math.clamp(health() / maximum, 0, 1)
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
						local maximum = math.max(maximumHealth(), 0)
						return `{math.floor(current)}/{math.floor(maximum)}`
					end,
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					create("UIStroke")({
						StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
						Thickness = 0.12,
					}),
				}),
			}),
		})
		frame.Visible = false
		frame.Parent = healthBarContainer
		cleanup(function()
			frame:Destroy()
		end)
		return frame
	end)
	return {
		Gui = gui,
		SetContent = function(newName: string, newHealth: number, newMaxHealth: number)
			batch(function()
				name(newName)
				maximumHealth(newMaxHealth)
				health(newHealth)
			end)
		end,
		Destroy = destroyScope,
	}
end

local function releaseView(state: HealthBarState)
	local view = state.View
	if view then
		view.Gui.Visible = false
		state.View = nil
		table.insert(availableViews, view)
	end
end

local function getScreenBounds(state: HealthBarState, camera: Camera, projectionScale: number): (Vector2?, Vector2?)
	if not state.RootPart.Parent or state.MaxHealth <= 0 then
		return nil, nil
	end

	local position = camera:WorldToViewportPoint(state.RootPart.Position + state.Offset)
	if position.Z <= 0 then
		return nil, nil
	end

	local size = BAR_SIZE_STUDS * (projectionScale / position.Z)
	if not state.IsBoss and size.Y < MIN_BAR_HEIGHT then
		return nil, nil
	end

	local viewport = camera.ViewportSize
	if
		position.X + size.X / 2 < 0
		or position.X - size.X / 2 > viewport.X
		or position.Y + size.Y / 2 < 0
		or position.Y - size.Y / 2 > viewport.Y
	then
		return nil, nil
	end

	return Vector2.new(position.X, position.Y), size, position.Z
end

local EnemyVisuals = {}

function EnemyVisuals.Render(_dt: number)
	local camera = workspace.CurrentCamera
	healthBarContainer.Enabled = camera ~= nil and next(healthBars) ~= nil
	if not camera or not healthBarContainer.Enabled then
		return
	end

	local projectionScale = camera.ViewportSize.Y / (2 * math.tan(math.rad(camera.FieldOfView) * 0.5))
	for _, state in healthBars do
		local position, size, depth = getScreenBounds(state, camera, projectionScale)
		if not position or not size then
			releaseView(state)
			continue
		end

		local view = state.View
		if not view then
			view = table.remove(availableViews) or createHealthBar(state.Name, state.MaxHealth)
			state.View = view
			state.Dirty = true
		end

		if state.Dirty then
			view.SetContent(state.Name, state.Health, state.MaxHealth)
			state.Dirty = false
		end

		local gui = view.Gui
		local guiPosition = UDim2.fromOffset(position.X, position.Y)
		local guiSize = UDim2.fromOffset(size.X, size.Y)
		local guiIndex = -depth * 2
		if gui.Position ~= guiPosition then
			gui.Position = guiPosition
		end
		if gui.Size ~= guiSize then
			gui.Size = guiSize
		end
		if gui.ZIndex ~= guiIndex then
			gui.ZIndex = guiIndex
		end

		gui.Visible = true
	end
end

function EnemyVisuals.Attach(enemyId: number, enemyName: string, enemyModel: Model, maxHealth: number, isBoss: boolean?)
	EnemyVisuals.Destroy(enemyId)

	local rootPart = enemyModel.PrimaryPart
	if not rootPart or maxHealth <= 0 then
		return
	end

	healthBars[enemyId] = {
		Name = enemyName,
		IsBoss = isBoss == true,
		RootPart = rootPart,
		Offset = Vector3.new(0, CharacterUtils.GetHipHeight(enemyModel) - BAR_OFFSET, 0),
		Health = maxHealth,
		MaxHealth = maxHealth,
		Dirty = true,
	}
end

function EnemyVisuals.Update(enemyId: number, health: number, maxHealth: number?)
	local state = healthBars[enemyId]
	if not state then
		return
	end
	if health <= 0 then
		EnemyVisuals.Destroy(enemyId)
		return
	end

	local maximum = if maxHealth ~= nil then maxHealth else state.MaxHealth
	if state.Health ~= health or state.MaxHealth ~= maximum then
		state.Health = health
		state.MaxHealth = maximum
		state.Dirty = true
	end
end

function EnemyVisuals.Destroy(enemyId: number)
	local state = healthBars[enemyId]
	if not state then
		return
	end

	releaseView(state)
	healthBars[enemyId] = nil
	if next(healthBars) == nil then
		healthBarContainer.Enabled = false
		for _, view in availableViews do
			view.Destroy()
		end
		table.clear(availableViews)
	end
end

return EnemyVisuals
