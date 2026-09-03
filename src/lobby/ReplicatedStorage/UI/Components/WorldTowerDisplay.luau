local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Vide = require(ReplicatedStorage.Packages.Vide)
local ForgeVFX = require(ReplicatedStorage.Shared.Modules.Utils.ForgeVFX)

local cleanup = Vide.cleanup
local create = Vide.create
local effect = Vide.effect
local read = Vide.read
local source = Vide.source

type Reactive<T> = T | (() -> T)

type TransparencyTarget = {
	Instance: Instance,
	Original: any,
	OriginalEnabled: boolean?,
}

type ModelState = {
	Instance: Model,
	EffectRootPart: BasePart?,
	BaseHeight: number,
	BaseWidth: number,
	BaseDepth: number,
	BaseLocalCenter: Vector3,
	BaseScale: number,
	LastScale: number,
	LastTransparency: number,
	TransparencyTargets: { TransparencyTarget },
	BurstEffect: BasePart?,
	BurstEnvironment: any?,
	StaticEffect: BasePart?,
	EffectsStarted: boolean,
	StaticEnabled: boolean,
}

export type Props = {
	TowerName: Reactive<string?>,
	Rarity: Reactive<string?>?,
	RevealKey: Reactive<any>?,
	Visible: Reactive<boolean>?,
	ScreenPosition: Reactive<Vector2>?,
	ScreenHeight: Reactive<number>?,
	ScreenWidth: Reactive<number>?,
	Depth: Reactive<number>?,
	ModelRotation: Reactive<number>?,
	DisplayScale: Reactive<number>?,
	Transparency: Reactive<number>?,
	AnimationName: Reactive<string?>?,
	AnimationLevel: Reactive<number?>?,
	AnimationLooped: Reactive<boolean>?,
	AnimationSpeed: Reactive<number>?,
	AnimationFadeTime: Reactive<number>?,
}

local DEFAULT_SCREEN_POSITION = Vector2.new(0.5, 0.39)
local DEFAULT_SCREEN_HEIGHT = 0.44
local DEFAULT_SCREEN_WIDTH = 0.4
local DEFAULT_DEPTH = 7
local MINIMUM_HEIGHT = 0.01
local SUMMON_EFFECT_SCALE = 0.5
local MINIMUM_CAMERA_DISTANCE = 0.75
local OCCLUSION_PADDING = 0.15
local OCCLUSION_SAMPLE_OFFSETS = {
	Vector2.new(0, 0),
	Vector2.new(-0.45, -0.45),
	Vector2.new(0.45, -0.45),
	Vector2.new(-0.45, 0.45),
	Vector2.new(0.45, 0.45),
	Vector2.new(-0.45, 0),
	Vector2.new(0.45, 0),
	Vector2.new(0, -0.45),
	Vector2.new(0, 0.45),
}

local function isEffectRarity(rarity: string?): boolean
	return rarity ~= nil and rarity ~= "" and rarity ~= "Absolute"
end

local function ensureForgeVFX()
	if not ForgeVFX.setup then
		ForgeVFX.init()
	end
end

local function getTowerAsset(towerName: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local towers = assets and assets:FindFirstChild("Towers")
	local towerAsset = towers and towers:FindFirstChild(towerName)

	if not towerAsset or not towerAsset:IsA("Model") then
		warn(`[WorldTowerDisplay] Tower model "{towerName}" was not found in ReplicatedStorage.Assets.Towers.`)
		return nil
	end

	return towerAsset
end

local function findRootPart(model: Model): BasePart?
	local humanoidRootPart = model:FindFirstChild("HumanoidRootPart", true)
	if humanoidRootPart and humanoidRootPart:IsA("BasePart") then
		return humanoidRootPart
	end
	if model.PrimaryPart then
		return model.PrimaryPart
	end

	return model:FindFirstChildWhichIsA("BasePart", true)
end

local function getSummonEffectTemplate(rarity: string, isStatic: boolean): BasePart?
	local effectFolder = ReplicatedStorage:FindFirstChild("Effect")
	local summonFolder = effectFolder and effectFolder:FindFirstChild("Summon")
	local rarityFolder = if isStatic and summonFolder then summonFolder:FindFirstChild("Static") else summonFolder
	local template = rarityFolder and rarityFolder:FindFirstChild(rarity)

	if template and template:IsA("BasePart") then
		return template
	end

	warn(
		`[WorldTowerDisplay] Missing {if isStatic then "static " else ""}summon effect for rarity "{rarity}" at ReplicatedStorage.Effect.Summon.`
	)
	return nil
end

local function attachEffectPart(template: BasePart, model: Model, rootPart: BasePart, name: string): BasePart
	local effectPart = template:Clone()
	ForgeVFX.resize(SUMMON_EFFECT_SCALE, effectPart)
	effectPart.Name = name
	effectPart.Anchored = false
	effectPart.CanCollide = false
	effectPart.CanQuery = false
	effectPart.CanTouch = false
	effectPart.CastShadow = false
	effectPart.Massless = true
	effectPart.Transparency = 1
	effectPart.CFrame = rootPart.CFrame
	effectPart.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Name = "SummonEffectWeld"
	weld.Part0 = rootPart
	weld.Part1 = effectPart
	weld.Parent = effectPart

	return effectPart
end

local function setStaticEffectEnabled(effectPart: BasePart, enabled: boolean)
	if enabled then
		ForgeVFX.enable(effectPart)
	else
		ForgeVFX.disable(effectPart)
	end

	-- ForgeVFX handles its tagged effects plus particles and beams. Keep the
	-- remaining continuous Roblox effect classes in sync with the same state.
	for _, descendant in effectPart:GetDescendants() do
		if
			descendant:IsA("Trail")
			or descendant:IsA("Fire")
			or descendant:IsA("Smoke")
			or descendant:IsA("Sparkles")
			or descendant:IsA("Light")
			or descendant:IsA("Highlight")
		then
			descendant.Enabled = enabled
		end
	end
end

local function prepareSummonEffects(state: ModelState, rarity: string?)
	local rootPart = state.EffectRootPart
	if not rootPart or not isEffectRarity(rarity) then
		return
	end

	ensureForgeVFX()

	local burstTemplate = getSummonEffectTemplate(rarity :: string, false)
	if burstTemplate then
		state.BurstEffect = attachEffectPart(burstTemplate, state.Instance, rootPart, "SummonBurstEffect")
	end

	local staticTemplate = getSummonEffectTemplate(rarity :: string, true)
	if staticTemplate then
		state.StaticEffect = attachEffectPart(staticTemplate, state.Instance, rootPart, "SummonStaticEffect")
		setStaticEffectEnabled(state.StaticEffect, false)
	end
end

local function updateSummonEffects(state: ModelState, enabled: boolean)
	if enabled and not state.EffectsStarted then
		state.EffectsStarted = true
		if state.BurstEffect then
			state.BurstEnvironment = ForgeVFX.emit(state.BurstEffect)
		end
	end

	if not state.StaticEffect or state.StaticEnabled == enabled then
		return
	end

	state.StaticEnabled = enabled
	setStaticEffectEnabled(state.StaticEffect, enabled)
end

local function cleanupSummonEffects(state: ModelState)
	if state.BurstEnvironment then
		state.BurstEnvironment.Clear()
		state.BurstEnvironment = nil
	end
	if state.StaticEffect then
		setStaticEffectEnabled(state.StaticEffect, false)
	end
end

local function transformSequence(sequence: NumberSequence, alpha: number): NumberSequence
	local keypoints = table.create(#sequence.Keypoints)
	for index, keypoint in sequence.Keypoints do
		keypoints[index] = NumberSequenceKeypoint.new(
			keypoint.Time,
			keypoint.Value + (1 - keypoint.Value) * alpha,
			keypoint.Envelope * (1 - alpha)
		)
	end
	return NumberSequence.new(keypoints)
end

local function applyTransparency(state: ModelState, alpha: number)
	if math.abs(state.LastTransparency - alpha) < 0.002 then
		return
	end
	state.LastTransparency = alpha

	for _, target in state.TransparencyTargets do
		local instance = target.Instance
		if not instance.Parent then
			continue
		end

		if instance:IsA("BasePart") then
			instance.LocalTransparencyModifier = target.Original + (1 - target.Original) * alpha
		elseif instance:IsA("Decal") or instance:IsA("Texture") then
			instance.Transparency = target.Original + (1 - target.Original) * alpha
		elseif instance:IsA("ParticleEmitter") or instance:IsA("Beam") or instance:IsA("Trail") then
			instance.Transparency = transformSequence(target.Original, alpha)
			instance.Enabled = target.OriginalEnabled == true and alpha < 0.995
		elseif instance:IsA("Fire") or instance:IsA("Smoke") or instance:IsA("Sparkles") then
			instance.Enabled = target.Original and alpha < 0.995
		end
	end
end

local function getOcclusionSafeDepth(
	camera: Camera,
	viewportSize: Vector2,
	screenPosition: Vector2,
	screenWidth: number,
	screenHeight: number,
	requestedDepth: number,
	halfDepthRatio: number,
	raycastParams: RaycastParams
): number
	local nearestHitDistance = math.huge
	local castDistance = requestedDepth * (1 + halfDepthRatio) + OCCLUSION_PADDING

	for _, offset in OCCLUSION_SAMPLE_OFFSETS do
		local samplePosition = screenPosition + Vector2.new(screenWidth * offset.X, screenHeight * offset.Y)
		local ray = camera:ViewportPointToRay(
			viewportSize.X * math.clamp(samplePosition.X, 0, 1),
			viewportSize.Y * math.clamp(samplePosition.Y, 0, 1),
			0
		)
		local hit = workspace:Raycast(ray.Origin, ray.Direction * castDistance, raycastParams)
		if hit then
			nearestHitDistance = math.min(nearestHitDistance, hit.Distance)
		end
	end

	if nearestHitDistance == math.huge then
		return requestedDepth
	end

	local safeDepth = (nearestHitDistance - OCCLUSION_PADDING) / (1 + halfDepthRatio)
	return math.clamp(safeDepth, MINIMUM_CAMERA_DISTANCE, requestedDepth)
end

local function getOccluderTargetPoints(
	camera: Camera,
	viewportSize: Vector2,
	screenPosition: Vector2,
	screenWidth: number,
	screenHeight: number,
	depth: number
): { Vector3 }
	local targetPoints = table.create(#OCCLUSION_SAMPLE_OFFSETS)

	for _, offset in OCCLUSION_SAMPLE_OFFSETS do
		local samplePosition = screenPosition + Vector2.new(screenWidth * offset.X, screenHeight * offset.Y)
		local ray = camera:ViewportPointToRay(
			viewportSize.X * math.clamp(samplePosition.X, 0, 1),
			viewportSize.Y * math.clamp(samplePosition.Y, 0, 1),
			0
		)
		table.insert(targetPoints, ray.Origin + ray.Direction * depth)
	end

	return targetPoints
end

local function restoreOccluders(occluders: { [BasePart]: number })
	for part, originalTransparency in occluders do
		if part.Parent then
			part.LocalTransparencyModifier = originalTransparency
		end
	end
	table.clear(occluders)
end

local function updateOccluders(
	camera: Camera,
	state: ModelState,
	occluders: { [BasePart]: number },
	targetPoints: { Vector3 },
	active: boolean
)
	if not active then
		restoreOccluders(occluders)
		return
	end

	local nextOccluders: { [BasePart]: boolean } = {}
	local ok, obscuringParts = pcall(function()
		return camera:GetPartsObscuringTarget(targetPoints, { state.Instance })
	end)
	if not ok then
		return
	end

	for _, instance in obscuringParts do
		if instance:IsA("BasePart") then
			nextOccluders[instance] = true
			if occluders[instance] == nil then
				occluders[instance] = instance.LocalTransparencyModifier
			end
			instance.LocalTransparencyModifier = 1
		end
	end

	for part, originalTransparency in occluders do
		if not nextOccluders[part] then
			if part.Parent then
				part.LocalTransparencyModifier = originalTransparency
			end
			occluders[part] = nil
		end
	end
end

local function prepareModel(model: Model): ModelState
	local transparencyTargets = {}
	local rootPart = findRootPart(model)

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BaseScript") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			-- Keep rigged limbs animatable while preventing loose VFX helper parts
			-- from falling away under local physics.
			descendant.Anchored = descendant == rootPart or #descendant:GetJoints() == 0
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.CastShadow = false
			descendant.Massless = true
			table.insert(transparencyTargets, {
				Instance = descendant,
				Original = descendant.LocalTransparencyModifier,
			})
		elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
			table.insert(transparencyTargets, {
				Instance = descendant,
				Original = descendant.Transparency,
			})
		elseif descendant:IsA("ParticleEmitter") or descendant:IsA("Beam") or descendant:IsA("Trail") then
			table.insert(transparencyTargets, {
				Instance = descendant,
				Original = descendant.Transparency,
				OriginalEnabled = descendant.Enabled,
			})
		elseif descendant:IsA("Fire") or descendant:IsA("Smoke") or descendant:IsA("Sparkles") then
			table.insert(transparencyTargets, {
				Instance = descendant,
				Original = descendant.Enabled,
			})
		end
	end

	model:PivotTo(CFrame.identity)
	local baseScale = model:GetScale()
	local boundsCFrame, boundsSize = model:GetBoundingBox()
	local baseLocalCenter = model:GetPivot():PointToObjectSpace(boundsCFrame.Position)

	return {
		Instance = model,
		EffectRootPart = rootPart,
		BaseHeight = math.max(boundsSize.Y, MINIMUM_HEIGHT),
		BaseWidth = math.max(boundsSize.X, MINIMUM_HEIGHT),
		BaseDepth = math.max(boundsSize.Z, MINIMUM_HEIGHT),
		BaseLocalCenter = baseLocalCenter,
		BaseScale = baseScale,
		LastScale = baseScale,
		LastTransparency = -1,
		TransparencyTargets = transparencyTargets,
		BurstEffect = nil,
		BurstEnvironment = nil,
		StaticEffect = nil,
		EffectsStarted = false,
		StaticEnabled = false,
	}
end

local function getAnimation(towerName: string, animationName: string, level: number?): Animation?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local animations = assets and assets:FindFirstChild("Animations")
	local towerAnimations = animations and animations:FindFirstChild(towerName)
	if not towerAnimations then
		return nil
	end

	if level then
		for currentLevel = level, 0, -1 do
			local animation = towerAnimations:FindFirstChild(`{animationName}_{currentLevel}`)
			if animation and animation:IsA("Animation") then
				return animation:Clone()
			end
		end
	end

	local animation = towerAnimations:FindFirstChild(animationName)
	return if animation and animation:IsA("Animation") then animation:Clone() else nil
end

local function playAnimation(model: Model, towerName: string, props: Props): () -> ()
	local animationName = read(props.AnimationName)
	if not animationName or animationName == "" then
		return function() end
	end

	local animation = getAnimation(towerName, animationName, read(props.AnimationLevel))
	if not animation then
		warn(`[WorldTowerDisplay] Animation "{animationName}" was not found for tower "{towerName}".`)
		return function() end
	end

	local controller = model:FindFirstChildOfClass("AnimationController") or model:FindFirstChildOfClass("Humanoid")
	local animator = controller and controller:FindFirstChildOfClass("Animator")
	if controller and not animator then
		animator = Instance.new("Animator")
		animator.Parent = controller
	end

	if not animator then
		animation:Destroy()
		return function() end
	end

	local ok, loadedTrack = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if not ok then
		warn(`[WorldTowerDisplay] Failed to load animation for tower "{towerName}": {loadedTrack}`)
		animation:Destroy()
		return function() end
	end

	local track = loadedTrack :: AnimationTrack
	track.Looped = read(props.AnimationLooped) ~= false
	track:Play(read(props.AnimationFadeTime) or 0.1)
	track:AdjustSpeed(read(props.AnimationSpeed) or 1)

	return function()
		track:Stop(0)
		track:Destroy()
		animation:Destroy()
	end
end

return function(props: Props)
	local modelState = source(nil :: ModelState?)

	effect(function()
		local towerName = read(props.TowerName)
		local rarity = read(props.Rarity)
		local _revealKey = read(props.RevealKey)
		modelState(nil)
		if not towerName or towerName == "" then
			return
		end

		local towerAsset = getTowerAsset(towerName)
		if not towerAsset then
			return
		end

		local model = towerAsset:Clone()
		model.Name = `SummonDisplay_{towerName}`
		local state = prepareModel(model)
		prepareSummonEffects(state, rarity)
		model.Parent = workspace.CurrentCamera
		local stopAnimation = playAnimation(model, towerName, props)
		modelState(state)

		cleanup(function()
			cleanupSummonEffects(state)
			stopAnimation()
			if modelState() == state then
				modelState(nil)
			end
			model:Destroy()
		end)
	end)

	effect(function()
		local state = modelState()
		if not state then
			return
		end

		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = { state.Instance }
		raycastParams.IgnoreWater = true
		local occluders: { [BasePart]: number } = {}

		local connection = RunService.PreRender:Connect(function()
			local camera = workspace.CurrentCamera
			if not camera then
				restoreOccluders(occluders)
				return
			end
			if state.Instance.Parent ~= camera then
				state.Instance.Parent = camera
			end

			local visible = read(props.Visible) ~= false
			local transparency = if visible then math.clamp(read(props.Transparency) or 0, 0, 1) else 1
			applyTransparency(state, transparency)

			local viewportSize = camera.ViewportSize
			if viewportSize.X <= 0 or viewportSize.Y <= 0 then
				restoreOccluders(occluders)
				return
			end

			local screenPosition = read(props.ScreenPosition) or DEFAULT_SCREEN_POSITION
			local screenHeight = math.max(read(props.ScreenHeight) or DEFAULT_SCREEN_HEIGHT, 0.01)
			local screenWidth = math.max(read(props.ScreenWidth) or DEFAULT_SCREEN_WIDTH, 0.01)
			local requestedDepth = math.max(read(props.Depth) or DEFAULT_DEPTH, 2)
			local displayScale = math.max(read(props.DisplayScale) or 1, 0.01)
			local visibleWorldHeight = 2 * requestedDepth * math.tan(math.rad(camera.FieldOfView) * 0.5)
			local visibleWorldWidth = visibleWorldHeight * viewportSize.X / viewportSize.Y
			local heightScale = visibleWorldHeight * screenHeight / state.BaseHeight
			local widthScale = visibleWorldWidth * screenWidth / state.BaseWidth
			local requestedScale = state.BaseScale * math.min(heightScale, widthScale) * displayScale
			local requestedScaleRatio = requestedScale / state.BaseScale
			local halfDepthRatio = state.BaseDepth * requestedScaleRatio * 0.5 / requestedDepth
			local depth = getOcclusionSafeDepth(
				camera,
				viewportSize,
				screenPosition,
				screenWidth,
				screenHeight,
				requestedDepth,
				halfDepthRatio,
				raycastParams
			)
			local targetScale = requestedScale * depth / requestedDepth

			if math.abs(state.LastScale - targetScale) > 0.001 then
				state.Instance:ScaleTo(targetScale)
				state.LastScale = targetScale
			end

			local ray = camera:ViewportPointToRay(
				viewportSize.X * screenPosition.X,
				viewportSize.Y * screenPosition.Y,
				0
			)
			local targetCenter = ray.Origin + ray.Direction * depth
			local facing = CFrame.lookAt(targetCenter, targetCenter - ray.Direction, camera.CFrame.UpVector)
			local rotation = facing.Rotation * CFrame.Angles(0, math.rad(read(props.ModelRotation) or 0), 0)
			local scaleRatio = targetScale / state.BaseScale
			local localCenter = state.BaseLocalCenter * scaleRatio
			local pivotPosition = targetCenter - rotation:VectorToWorldSpace(localCenter)
			state.Instance:PivotTo(CFrame.new(pivotPosition) * rotation)

			local displayActive = visible and transparency < 0.9
			local halfDepth = state.BaseDepth * scaleRatio * 0.5
			local targetPoints = getOccluderTargetPoints(
				camera,
				viewportSize,
				screenPosition,
				screenWidth,
				screenHeight,
				depth + halfDepth
			)
			updateOccluders(camera, state, occluders, targetPoints, displayActive)
			updateSummonEffects(state, displayActive)
		end)

		cleanup(function()
			connection:Disconnect()
			restoreOccluders(occluders)
		end)
	end)

	return create("Frame")({
		Name = "WorldTowerDisplayController",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, 0),
		Visible = false,
	})
end
