local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local Vide = require(ReplicatedStorage.Packages.Vide)
local RarityData = require(ReplicatedStorage.Settings.Data.RarityData)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local ForgeVFX = require(ReplicatedStorage.Shared.Modules.Utils.ForgeVFX)
local TowerViewport = require(ReplicatedStorage.UI.Components.TowerViewport)

local create = Vide.create
local cleanup = Vide.cleanup
local effect = Vide.effect
local source = Vide.source
local spring = Vide.spring

export type PulledUnit = {
	UnitName: string,
	Rarity: string,
}

local VIEW_ID = "SummonResult"

local RARITY_GRADIENTS = {
	Common = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(199, 199, 199)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(160, 160, 160)),
	}),
	Rare = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(42, 106, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 34, 255)),
	}),
	Epic = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(235, 85, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 32, 170)),
	}),
	Legendary = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 194, 52)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 126, 61)),
	}),
	Mythic = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 14, 18)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(189, 0, 3)),
	}),
	Absolute = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(185, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(239, 189, 255)),
	}),
}

local UIController

local resultsQueue = source({} :: { PulledUnit })
local currentIndex = source(0)
local revealPhase = source(false)
local isTransitioning = source(false)
local isClosing = source(false)
local slideSign = source(1)
local viewportModel = source(nil :: Model?)

local EXIT_DELAY = 0.34
local ENTER_DELAY = 0.42
local CLOSE_DELAY = 0.4
local SUMMON_EFFECT_LIFETIME = 2.5
local SUMMON_EFFECT_DISTANCE = 12
local SUMMON_EFFECT_SCALE = 0.7
local BACKDROP_BLUR_SIZE = 8

local closeToken = 0

local SummonResultUI = {}

local function getCurrentUnit(): PulledUnit?
	local queue = resultsQueue()
	local index = currentIndex()
	if index < 1 or index > #queue then
		return nil
	end

	return queue[index]
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

local function getSummonTemplate(rarity: string, ...: string): Instance?
	local current: Instance? = ReplicatedStorage:FindFirstChild("Effect")
	current = current and current:FindFirstChild("Summon")
	for _, name in { ... } do
		current = current and current:FindFirstChild(name)
	end

	if current and (current:IsA("BasePart") or current:IsA("Model")) then
		return current
	end

	return nil
end

local function getSummonEffectTemplate(rarity: string): Instance?
	if rarity == "Absolute" then
		return getSummonTemplate(rarity, "Absolute", "Absolute")
	end

	local template = getSummonTemplate(rarity, rarity)
	if not template then
		warn(`[SummonResultUI] Summon effect "{rarity}" was not found in ReplicatedStorage.Effect.Summon.`)
	end

	return template
end

local function getStaticSummonTemplate(rarity: string): Instance?
	return getSummonTemplate(rarity, "Static", rarity)
end

local function setEffectCFrame(effect: Instance, cframe: CFrame)
	if effect:IsA("BasePart") then
		effect.Anchored = true
		effect.CanCollide = false
		effect.CanQuery = false
		effect.CanTouch = false
		effect.CastShadow = false
		effect.Massless = true
		effect.CFrame = cframe
	elseif effect:IsA("Model") then
		effect:PivotTo(cframe)
		for _, descendant in effect:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.CanCollide = false
				descendant.CanQuery = false
				descendant.CanTouch = false
				descendant.CastShadow = false
				descendant.Massless = true
			end
		end
	end
end

local function getViewportScreenPoint(viewport: ViewportFrame, worldPoint: Vector3): Vector2
	local vpCamera = viewport.CurrentCamera
	local size = viewport.AbsoluteSize
	if not vpCamera or size.X <= 0 or size.Y <= 0 then
		return viewport.AbsolutePosition + size * 0.5
	end

	local localPoint = vpCamera.CFrame:PointToObjectSpace(worldPoint)
	local depth = -localPoint.Z
	if depth <= 0.01 then
		return viewport.AbsolutePosition + size * 0.5
	end

	local aspect = size.X / size.Y
	local tanHalfFov = math.tan(math.rad(vpCamera.FieldOfView) * 0.5)
	local ndcX = localPoint.X / (depth * tanHalfFov * aspect)
	local ndcY = localPoint.Y / (depth * tanHalfFov)

	return viewport.AbsolutePosition + Vector2.new((ndcX + 1) * 0.5 * size.X, (1 - ndcY) * 0.5 * size.Y)
end

local function getWorldOverlayCFrame(model: Model, rootPart: BasePart, targetPoint: Vector3?): CFrame?
	local worldCamera = workspace.CurrentCamera
	if not worldCamera then
		return nil
	end

	local viewport = model:FindFirstAncestorWhichIsA("ViewportFrame")
	if not viewport then
		return worldCamera.CFrame * CFrame.new(0, 0.6, -SUMMON_EFFECT_DISTANCE)
	end

	local screenPoint = getViewportScreenPoint(viewport, targetPoint or rootPart.Position + Vector3.new(0, -0.5, 0))
	local ray = worldCamera:ViewportPointToRay(screenPoint.X, screenPoint.Y)
	local position = ray.Origin + ray.Direction.Unit * SUMMON_EFFECT_DISTANCE
	return CFrame.lookAlong(position, worldCamera.CFrame.LookVector, worldCamera.CFrame.UpVector)
end

local function getModelFootPoint(model: Model, rootPart: BasePart): Vector3
	local boundsCFrame, boundsSize = model:GetBoundingBox()
	return Vector3.new(rootPart.Position.X, boundsCFrame.Position.Y - boundsSize.Y * 0.5, rootPart.Position.Z)
end

local function emitFallbackParticles(root: Instance)
	local emitters = root:GetDescendants()
	table.insert(emitters, 1, root)

	for _, descendant in emitters do
		if not descendant:IsA("ParticleEmitter") then
			continue
		end

		local count = descendant:GetAttribute("EmitCount")
		local duration = descendant:GetAttribute("EmitDuration") or 0
		if (typeof(count) ~= "number" or count <= 0) and duration <= 0 then
			descendant:Emit(20)
		end
	end
end

local function scaleNumberSequence(sequence: NumberSequence, scale: number): NumberSequence
	local keypoints = table.create(#sequence.Keypoints)
	for index, keypoint in sequence.Keypoints do
		keypoints[index] = NumberSequenceKeypoint.new(keypoint.Time, keypoint.Value * scale, keypoint.Envelope * scale)
	end

	return NumberSequence.new(keypoints)
end

-- Dynamic summon effects are rendered over the result viewport. Scale only these
-- particles down so they stay inside the screen; static rarity effects are untouched.
local function scaleSummonEffect(effectInstance: Instance, scale: number)
	local isModel = effectInstance:IsA("Model")
	if isModel then
		effectInstance:ScaleTo(scale)
	elseif effectInstance:IsA("BasePart") then
		effectInstance.Size *= scale
	end

	for _, descendant in effectInstance:GetDescendants() do
		if not isModel and descendant:IsA("Attachment") then
			descendant.Position *= scale
		elseif descendant:IsA("ParticleEmitter") then
			descendant.Size = scaleNumberSequence(descendant.Size, scale)
			descendant.Speed = NumberRange.new(descendant.Speed.Min * scale, descendant.Speed.Max * scale)
			descendant.Acceleration *= scale
		elseif descendant:IsA("Beam") then
			descendant.Width0 *= scale
			descendant.Width1 *= scale
			descendant.CurveSize0 *= scale
			descendant.CurveSize1 *= scale
		elseif descendant:IsA("Trail") then
			descendant.WidthScale = scaleNumberSequence(descendant.WidthScale, scale)
		end
	end
end

local function playSummonEffect(
	model: Model,
	rarity: string,
	templateName: string?,
	targetPointGetter: ((Model, BasePart) -> Vector3)?
): () -> ()
	local template = if templateName then getSummonTemplate(rarity, "Absolute", templateName) else getSummonEffectTemplate(rarity)
	if not template then
		return function() end
	end

	local rootPart = findRootPart(model)
	if not rootPart then
		warn(`[SummonResultUI] HumanoidRootPart was not found on "{model.Name}".`)
		return function() end
	end

	local effectInstance = template:Clone()
	if not effectInstance:IsA("BasePart") and not effectInstance:IsA("Model") then
		effectInstance:Destroy()
		return function() end
	end
	scaleSummonEffect(effectInstance, SUMMON_EFFECT_SCALE)

	local targetPoint = if targetPointGetter then targetPointGetter(model, rootPart) else nil
	local overlayCFrame = getWorldOverlayCFrame(model, rootPart, targetPoint)
	if not overlayCFrame then
		effectInstance:Destroy()
		return function() end
	end

	effectInstance.Parent = workspace
	setEffectCFrame(effectInstance, overlayCFrame)

	local emitEnv = ForgeVFX.emit(effectInstance)
	emitFallbackParticles(effectInstance)

	local follow = RunService.PreRender:Connect(function()
		if not effectInstance.Parent or not rootPart.Parent then
			return
		end

		local nextTargetPoint = if targetPointGetter then targetPointGetter(model, rootPart) else nil
		local nextCFrame = getWorldOverlayCFrame(model, rootPart, nextTargetPoint)
		if nextCFrame then
			setEffectCFrame(effectInstance, nextCFrame)
		end
	end)

	local destroyed = false

	local function destroy()
		if destroyed then
			return
		end

		destroyed = true
		follow:Disconnect()
		if emitEnv.Clear then
			emitEnv.Clear()
		end
		effectInstance:Destroy()
	end

	task.delay(SUMMON_EFFECT_LIFETIME, destroy)

	return destroy
end

local function enableLoopingVisuals(root: Instance)
	local function enable(object: Instance)
		if object:IsA("ParticleEmitter") or object:IsA("Beam") or object:IsA("Trail") then
			object.Enabled = true
		end
	end

	enable(root)
	for _, descendant in root:GetDescendants() do
		enable(descendant)
	end
end

local function getEffectPart(effectInstance: Instance): BasePart?
	if effectInstance:IsA("BasePart") then
		return effectInstance
	end

	if effectInstance:IsA("Model") then
		return effectInstance.PrimaryPart or effectInstance:FindFirstChildWhichIsA("BasePart", true)
	end

	return nil
end

local function attachToRootPart(effectInstance: Instance, rootPart: BasePart)
	local effectPart = getEffectPart(effectInstance)
	if not effectPart then
		effectInstance.Parent = rootPart
		return
	end

	effectPart.Anchored = false
	effectPart.CanCollide = false
	effectPart.CanQuery = false
	effectPart.CanTouch = false
	effectPart.CastShadow = false
	effectPart.Massless = true

	effectInstance.Parent = rootPart
	if effectInstance:IsA("BasePart") then
		effectInstance.CFrame = rootPart.CFrame
	elseif effectInstance:IsA("Model") then
		effectInstance:PivotTo(rootPart.CFrame)
	end

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = rootPart
	weld.Part1 = effectPart
	weld.Parent = effectPart
end

local function playStaticSummonEffect(model: Model, rarity: string): () -> ()
	local template = getStaticSummonTemplate(rarity)
	if not template then
		return function() end
	end

	local rootPart = findRootPart(model)
	if not rootPart then
		warn(`[SummonResultUI] HumanoidRootPart was not found on "{model.Name}".`)
		return function() end
	end

	local attached = template:Clone()
	if not attached:IsA("BasePart") and not attached:IsA("Model") then
		attached:Destroy()
		return function() end
	end

	attachToRootPart(attached, rootPart)
	enableLoopingVisuals(attached)

	local overlay = template:Clone()
	if not overlay:IsA("BasePart") and not overlay:IsA("Model") then
		overlay:Destroy()
		return function()
			attached:Destroy()
		end
	end

	local overlayCFrame = getWorldOverlayCFrame(model, rootPart)
	overlay.Parent = workspace
	if overlayCFrame then
		setEffectCFrame(overlay, overlayCFrame)
	end
	enableLoopingVisuals(overlay)

	local follow = RunService.PreRender:Connect(function()
		if not overlay.Parent or not rootPart.Parent then
			return
		end

		local nextCFrame = getWorldOverlayCFrame(model, rootPart)
		if nextCFrame then
			setEffectCFrame(overlay, nextCFrame)
		end
	end)

	local destroyed = false

	return function()
		if destroyed then
			return
		end

		destroyed = true
		follow:Disconnect()
		attached:Destroy()
		overlay:Destroy()
	end
end

local function isRevealed(): boolean
	return UIController:IsOpen(VIEW_ID) and revealPhase()
end

local function canInteract(): boolean
	return isRevealed() and not isTransitioning()
end

local function isHintVisible(): boolean
	return isRevealed() and not isTransitioning() and not isClosing()
end

local function playInitialReveal()
	isTransitioning(false)
	revealPhase(false)
	task.defer(function()
		if UIController:IsOpen(VIEW_ID) then
			revealPhase(true)
		end
	end)
end

local function playTransition(onSwitch: () -> ())
	isTransitioning(true)
	revealPhase(false)

	task.delay(EXIT_DELAY, function()
		if not UIController:IsOpen(VIEW_ID) then
			isTransitioning(false)
			return
		end

		slideSign(-slideSign())
		onSwitch()

		task.defer(function()
			if not UIController:IsOpen(VIEW_ID) then
				isTransitioning(false)
				return
			end

			revealPhase(true)

			task.delay(ENTER_DELAY, function()
				isTransitioning(false)
			end)
		end)
	end)
end

local function playClose(onFinished: () -> ())
	if isTransitioning() or isClosing() then
		return
	end

	closeToken += 1
	local token = closeToken

	isTransitioning(true)
	isClosing(true)
	revealPhase(false)

	task.delay(CLOSE_DELAY, function()
		if token ~= closeToken or not UIController:IsOpen(VIEW_ID) then
			isClosing(false)
			isTransitioning(false)
			return
		end

		isClosing(false)
		isTransitioning(false)
		onFinished()
	end)
end

function SummonResultUI.ShowResults(units: { PulledUnit })
	if #units == 0 then
		return
	end

	closeToken += 1
	resultsQueue(units)
	currentIndex(1)
	slideSign(1)
	isTransitioning(false)
	isClosing(false)
	revealPhase(false)
	UIController:Open(VIEW_ID)
	playInitialReveal()
end

function SummonResultUI.Advance()
	if isTransitioning() then
		return
	end

	local queue = resultsQueue()
	local index = currentIndex()

	if index < #queue then
		playTransition(function()
			currentIndex(index + 1)
		end)
		return
	end

	playClose(function()
		SummonResultUI.Close()
	end)
end

function SummonResultUI.Close()
	closeToken += 1
	UIController:Close(VIEW_ID)
	resultsQueue({})
	currentIndex(0)
	revealPhase(false)
	isTransitioning(false)
	isClosing(false)
end

function SummonResultUI.RenderUI()
	local backdropBlur = Instance.new("BlurEffect")
	backdropBlur.Name = "SummonResultBackdropBlur"
	backdropBlur.Size = 0
	backdropBlur.Enabled = false
	backdropBlur.Parent = Lighting
	cleanup(function()
		backdropBlur:Destroy()
	end)

	effect(function()
		-- Keep the background blurred while swapping results; only clear it once
		-- the summon flow has fully closed.
		local shouldBlur = UIController:IsOpen(VIEW_ID)
		backdropBlur.Enabled = shouldBlur
		backdropBlur.Size = if shouldBlur then BACKDROP_BLUR_SIZE else 0
	end)

	effect(function()
		if not isRevealed() then
			return
		end

		local unit = getCurrentUnit()
		local model = viewportModel()
		if not unit or not model then
			return
		end

		cleanup(playSummonEffect(model, unit.Rarity))
		if unit.Rarity == "Absolute" then
			cleanup(playSummonEffect(model, unit.Rarity, "AbsolutePlus", getModelFootPoint))
		end
		cleanup(playStaticSummonEffect(model, unit.Rarity))
	end)

	return create("Frame")({
		Name = "SummonResultUI",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = UIController:IsVisible(VIEW_ID),
		ZIndex = 50,

		create("TextButton")({
			Name = "Backdrop",
			AutoButtonColor = false,
			Active = function()
				return canInteract()
			end,
			BackgroundColor3 = Color3.fromRGB(5, 5, 10),
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Text = "",
			ZIndex = 50,

			Activated = SummonResultUI.Advance,
		}),

		create("Frame")({
			Name = "ResultPanel",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.5),
			Rotation = spring(function()
				if isRevealed() then
					return 0
				end

				if isClosing() then
					return -6
				end

				return slideSign() * 8
			end, if isClosing() then 0.32 else 0.38, 0.68),
			Size = UDim2.fromScale(1, 1),
			ZIndex = 51,

			create("UIScale")({
				Scale = spring(function()
					if isRevealed() then
						return 1
					end

					if isClosing() then
						return 0.88
					end

					return 0.94
				end, if isClosing() then 0.3 else 0.38, 0.68),
			}),

			create("Frame")({
				Name = "ViewportHolder",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Position = spring(function()
					if isRevealed() then
						return UDim2.fromScale(0.5, 0.38)
					end

					if isClosing() then
						return UDim2.fromScale(0.5, 0.58)
					end

					return UDim2.fromScale(0.5 + slideSign() * 0.14, 0.54)
				end, if isClosing() then 0.32 else 0.38, 0.66),
				Size = spring(function()
					if isRevealed() then
						return UDim2.fromScale(0.42, 0.48)
					end

					if isClosing() then
						return UDim2.fromScale(0.08, 0.09)
					end

					return UDim2.fromScale(0.12, 0.14)
				end, if isClosing() then 0.3 else 0.38, 0.64),
				ZIndex = 53,

				TowerViewport({
					TowerName = function()
						local unit = getCurrentUnit()
						return unit and unit.UnitName or ""
					end,
					AnimationName = "Idle",
					AnchorPoint = Vector2.new(0.5, 1),
					BackgroundTransparency = 1,
					ImageTransparency = spring(function()
						return if isRevealed() then 0 else 1
					end, 0.45, 0.85),
					Position = UDim2.fromScale(0.5, 1),
					Size = UDim2.fromScale(1, 1),
					ModelRotation = spring(function()
						if isRevealed() then
							return 0
						end

						if isClosing() then
							return 35
						end

						return slideSign() * 95
					end, if isClosing() then 0.38 else 0.45, 0.58),
					UseViewportModel = true,
					OnModelChanged = viewportModel,
				}),
			}),

			create("TextLabel")({
				Name = "TowerName",
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/SourceSansPro.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = spring(function()
					if isRevealed() then
						return UDim2.fromScale(0.5, 0.66)
					end

					return UDim2.fromScale(0.5 - slideSign() * 0.08, 0.74)
				end, 0.38, 0.68),
				Size = UDim2.fromScale(0.7, 0.07),
				Text = function()
					local unit = getCurrentUnit()
					return unit and unit.UnitName or ""
				end,
				TextColor3 = Color3.fromRGB(245, 242, 230),
				TextScaled = true,
				TextTransparency = spring(function()
					return if isRevealed() then 0 else 1
				end, 0.45, 0.85),
				ZIndex = 54,

				create("UIStroke")({
					Thickness = 1.5,
					Transparency = spring(function()
						return if isRevealed() then 0.4 else 1
					end, 0.45, 0.85),
				}),
			}),

			create("TextLabel")({
				Name = "Rarity",
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/SourceSansPro.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = spring(function()
					if isRevealed() then
						return UDim2.fromScale(0.5, 0.735)
					end

					return UDim2.fromScale(0.5 + slideSign() * 0.08, 0.8)
				end, 0.4, 0.68),
				Size = UDim2.fromScale(0.5, 0.055),
				Text = function()
					local unit = getCurrentUnit()
					return unit and RarityData.DisplayNames[unit.Rarity] or ""
				end,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextTransparency = spring(function()
					return if isRevealed() then 0 else 1
				end, 0.5, 0.85),
				ZIndex = 54,

				create("UIStroke")({
					Thickness = 2,
					Transparency = spring(function()
						return if isRevealed() then 0.15 else 1
					end, 0.5, 0.85),
				}),

				create("UIGradient")({
					Color = function()
						local unit = getCurrentUnit()
						local rarity = unit and unit.Rarity or "Common"
						return RARITY_GRADIENTS[rarity] or RARITY_GRADIENTS.Common
					end,
					Rotation = 90,
				}),
			}),

			create("TextLabel")({
				Name = "Progress",
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/SourceSansPro.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(0.5, 0.805),
				Size = UDim2.fromScale(0.3, 0.04),
				Text = function()
					local total = #resultsQueue()
					if total <= 1 then
						return ""
					end

					return `{currentIndex()} / {total}`
				end,
				TextColor3 = Color3.fromRGB(180, 175, 150),
				TextScaled = true,
				TextTransparency = spring(function()
					return if isRevealed() then 0.15 else 1
				end, 0.45, 0.85),
				ZIndex = 54,
			}),

			create("TextLabel")({
				Name = "ContinueHint",
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/SourceSansPro.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = spring(function()
					if isHintVisible() then
						return UDim2.fromScale(0.5, 0.94)
					end

					return UDim2.fromScale(0.5, 1.06)
				end, 0.42, 1),
				Size = UDim2.fromScale(0.45, 0.04),
				Text = function()
					local total = #resultsQueue()
					local index = currentIndex()
					if total <= 1 then
						return "Tap to close"
					end

					return if index < total then "Tap to continue" else "Tap to finish"
				end,
				TextColor3 = Color3.fromRGB(150, 145, 120),
				TextScaled = true,
				TextTransparency = spring(function()
					return if isHintVisible() then 0.25 else 1
				end, 0.4, 1),
				ZIndex = 54,
			}),
		}),
	})
end

function SummonResultUI.Init()
	UIController = ServiceRegistry:GetService("UIController")
	ForgeVFX.init()
end

function SummonResultUI.Start() end

return SummonResultUI
