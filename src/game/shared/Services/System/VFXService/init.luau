local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local VFXCaches = require(script.VFXCaches)
local VFXRecipes = require(ReplicatedStorage.Settings.Visuals.VFXRecipes)
local Steps = require(ReplicatedStorage.Settings.Visuals.VFXRecipes.Steps)
local CharacterUtils = require(ReplicatedStorage.Shared.Modules.Utils.CharacterUtils)
local ForgeVFX = require(ReplicatedStorage.Shared.Modules.Utils.ForgeVFX)
local CustomHandlers = require(script.CustomHandlers)
local TimeService

local RANDOM = Random.new()

local DEFAULT_LIFETIME = 2.5
local DEFAULT_PROJECTILE_SPEED = 300
local PROJECTILE_OFFSET = 0.2
local BEAM_CHECK_RATE = 1 / 15

export type Recipes = { Steps.Recipe }

local ActiveBeams = {}

local function getBezierPoint(t: number, p0: Vector3, p1: Vector3, p2: Vector3): Vector3
	local oneMinusT = 1 - t
	return oneMinusT * oneMinusT * p0 + 2 * oneMinusT * t * p1 + t * t * p2
end

local function getBezierTangent(t: number, p0: Vector3, p1: Vector3, p2: Vector3): Vector3
	return 2 * (1 - t) * (p1 - p0) + 2 * t * (p2 - p1)
end

-------------------------------------------------
--// Local Functions
-------------------------------------------------
local function resolveInstance(value: any, sourceModel: Model, targetModel: Model)
	if typeof(value) == "BasePart" then
		return value
	end

	if type(value) ~= "string" then
		return
	end

	local parts = string.split(value, ".")
	local rootName = parts[1]

	local rootModel
	if rootName == "Source" then
		rootModel = sourceModel
	elseif rootName == "Target" then
		rootModel = targetModel
	else
		warn(`잘못된 경로: {rootName}`)
		return
	end

	if #parts == 1 then
		if rootModel.PrimaryPart then
			return rootModel.PrimaryPart
		end

		return
	end

	local current = rootModel
	for i = 2, #parts do
		if parts[i] == "@Ground" then
			return current.PrimaryPart, true
		end

		current = current:FindFirstChild(parts[i])

		if not current then
			warn(`경로를 찾을 수 없음: {value}`)
			return
		end
	end

	return current
end

local function getAttachment(parentPart: BasePart)
	local attachment = parentPart:FindFirstChild("BeamAttachment")
	if attachment then
		return attachment
	end

	attachment = Instance.new("Attachment")
	attachment.Name = "BeamAttachment"
	attachment.Parent = parentPart

	return attachment
end

local function isAlive(model): boolean
	if not model or not model:IsDescendantOf(workspace) then
		return false
	end

	return model.PrimaryPart:GetAttribute("Dead") ~= true
end

local function getBeamKey(recipe)
	return `{recipe.Effect}|{recipe.From}->{recipe.To}`
end

-------------------------------------------------
--// VFXService
-------------------------------------------------
local VFXService = {}

function VFXService.GetRecipes(sourceName: string, effectType: string, sourceLevel: number?): Recipes?
	local sourceRecipes = VFXRecipes[sourceName]
	if not sourceRecipes then
		return nil
	end

	local effectRecipes = sourceRecipes[effectType]
	if not effectRecipes then
		return nil
	end

	if effectRecipes[1] then
		return effectRecipes
	end

	local level = sourceLevel or 0

	for currentLevel = level, 0, -1 do
		local recipes = effectRecipes[currentLevel]

		if recipes then
			return recipes
		end
	end

	warn(`{sourceName}.{effectType}의 {level}레벨 이하 VFX 정보가 존재하지 않음.`)
	return nil
end

function VFXService.PlayVFX(vfxRecipes: Recipes, sourceModel: Model, targetModel: Model, range: number?, delay: number?)
	if typeof(vfxRecipes) ~= "table" then
		return
	end
	for _, recipe in vfxRecipes do
		if (recipe.Delay and recipe.Delay > 0) or delay then
			local delayedRecipe = table.clone(recipe)
			local totalDelay = (delay or 0) + (delayedRecipe.Delay or 0)

			delayedRecipe.Delay = nil

			TimeService.DeltaDelay(totalDelay):andThen(function()
				VFXService.PlayVFX({ delayedRecipe }, sourceModel, targetModel, range)
			end)

			continue
		end

		if recipe.Type == "Emit" then
			VFXService._PlayEmitType(recipe, sourceModel, targetModel)
		elseif recipe.Type == "Projectile" then
			VFXService._PlayProjectileType(recipe, sourceModel, targetModel)
		elseif recipe.Type == "Beam" then
			VFXService._PlayBeamType(recipe, sourceModel, targetModel, range)
		elseif recipe.Type == "Custom" then
			VFXService._PlayCustomType(recipe, sourceModel, targetModel)
		else
			warn(`알 수 없는 VFX Type: {recipe.Type}`)
		end
	end
end

function VFXService._PlayCustomType(recipe: Steps.CustomStep, sourceModel: Model, targetModel: Model)
	local handler = CustomHandlers[recipe.Effect]
	if handler then
		task.spawn(function()
			local success, err = pcall(handler, recipe, sourceModel, targetModel)
			if not success then
				warn(`커스텀 VFX 실행 실패 ({recipe.Effect}): {err}`)
			end
		end)
	else
		warn(`커스텀 VFX 핸들러를 찾을 수 없음: {recipe.Effect}`)
	end
end

function VFXService._PlayEmitType(recipe: Steps.EmitStep, sourceModel: Model, targetModel: Model)
	local playPart, isGround = resolveInstance(recipe.At, sourceModel, targetModel)
	if not playPart then
		warn(`위치를 찾을 수 없음: {recipe.Effect}`)
		return
	end

	local playCFrame
	if isGround then
		playCFrame = playPart.CFrame - Vector3.new(0, CharacterUtils.GetHipHeight(playPart.Parent), 0)
	else
		playCFrame = playPart.CFrame
	end

	if not playCFrame then
		warn(`위치를 찾을 수 없음: {recipe.Effect}`)
		return
	end

	local effect, runId = VFXCaches.Get(recipe.Effect, playCFrame)
	if not effect or not runId then
		return
	end

	if recipe.LockToSource then
		local connection
		local offset = playPart.CFrame:ToObjectSpace(playCFrame)
		connection = RunService.PreRender:Connect(function()
			if effect:GetAttribute("VFXRunId") ~= runId or not playPart:IsDescendantOf(workspace) then
				connection:Disconnect()
				return
			end
			VFXCaches.SetCFrame(effect, playPart.CFrame * offset)
		end)
	end

	ForgeVFX.emit(effect)
	VFXCaches.ReturnAfter(
		recipe.Effect,
		effect,
		runId,
		(recipe.Lifetime or DEFAULT_LIFETIME) / TimeService:GetGameSpeed()
	)
end

function VFXService._PlayProjectileType(recipe: Steps.ProjectileStep, sourceModel: Model, targetModel: Model)
	local sourceCFrame = resolveInstance(recipe.From, sourceModel, targetModel).CFrame
	local targetCFrame = resolveInstance(recipe.To, sourceModel, targetModel).CFrame
	if not sourceCFrame or not targetCFrame then
		warn(`위치를 찾을 수 없음: {recipe.Effect}`)
		return
	end

	local startPos = sourceCFrame.Position
	local endPos = targetCFrame.Position
	local direction = endPos - startPos
	local distance = direction.Magnitude

	if distance <= 0 then
		return
	end

	local spawnCFrame = CFrame.lookAt(startPos, endPos)
	local effect, runId = VFXCaches.Get(recipe.Effect, spawnCFrame)
	if not effect or not runId then
		return
	end

	if not effect:IsA("BasePart") and not effect:IsA("Model") then
		warn(`Projectile effect must be a BasePart or Model: {recipe.Effect}`)
		VFXCaches.Return(recipe.Effect, effect)
		return
	end

	local travelTime
	if recipe.TravelTime then
		travelTime = recipe.TravelTime
	else
		travelTime = distance / (recipe.Speed or DEFAULT_PROJECTILE_SPEED)
	end

	local goalOffset = Vector3.new(
		RANDOM:NextNumber(-PROJECTILE_OFFSET, PROJECTILE_OFFSET),
		RANDOM:NextNumber(-PROJECTILE_OFFSET, PROJECTILE_OFFSET),
		RANDOM:NextNumber(-PROJECTILE_OFFSET, PROJECTILE_OFFSET)
	)
	local goalCFrame = CFrame.lookAt(endPos, endPos + direction.Unit) + goalOffset
	ForgeVFX.emit(effect)

	local isBezier = (recipe.CurveHeight and recipe.CurveHeight ~= 0)
		or (recipe.CurveOffset and recipe.CurveOffset ~= 0)

	if isBezier then
		local midPoint = (startPos + endPos) / 2
		local controlPoint = midPoint
		if recipe.CurveHeight then
			controlPoint = controlPoint + Vector3.new(0, recipe.CurveHeight, 0)
		end
		if recipe.CurveOffset then
			local directionUnit = direction.Magnitude > 0 and direction.Unit or Vector3.new(0, 0, 1)
			local up = Vector3.new(0, 1, 0)
			local side = directionUnit:Cross(up)

			if side.Magnitude > 0 then
				side = side.Unit
			else
				side = Vector3.new(1, 0, 0)
			end

			local randomSign = RANDOM:NextInteger(1, 2) == 1 and 1 or -1

			controlPoint = controlPoint + side * (recipe.CurveOffset * randomSign)
		end

		task.spawn(function()
			RunService.PreRender:Wait()

			local elapsed = 0
			local connection
			connection = RunService.PreRender:Connect(function(dt)
				if not effect or not effect.Parent or effect:GetAttribute("VFXRunId") ~= runId then
					connection:Disconnect()
					return
				end

				elapsed = math.min(travelTime, elapsed + dt * TimeService:GetGameSpeed())
				local t = elapsed / travelTime

				local currentPos = getBezierPoint(t, startPos, controlPoint, endPos + goalOffset)
				local tangent = getBezierTangent(t, startPos, controlPoint, endPos + goalOffset)

				if tangent.Magnitude > 0 then
					VFXCaches.SetCFrame(effect, CFrame.lookAt(currentPos, currentPos + tangent.Unit))
				else
					VFXCaches.SetCFrame(effect, CFrame.new(currentPos))
				end

				if elapsed >= travelTime then
					connection:Disconnect()

					if recipe.OnHit then
						VFXService.PlayVFX({ recipe.OnHit }, sourceModel, targetModel)
					end

					RunService.PreRender:Wait()
					VFXCaches.Return(recipe.Effect, effect)
				end
			end)
		end)
	else
		local tweenValue = Instance.new("CFrameValue")
		tweenValue.Value = spawnCFrame

		local tweenConnection = tweenValue:GetPropertyChangedSignal("Value"):Connect(function()
			if effect:GetAttribute("VFXRunId") == runId then
				VFXCaches.SetCFrame(effect, tweenValue.Value)
			end
		end)

		local tween = TweenService:Create(
			tweenValue,
			TweenInfo.new(travelTime / TimeService:GetGameSpeed(), Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Value = goalCFrame }
		)

		tween.Completed:Once(function()
			tweenConnection:Disconnect()
			tweenValue:Destroy()

			if effect:GetAttribute("VFXRunId") ~= runId then
				return
			end
			if recipe.OnHit then
				VFXService.PlayVFX({ recipe.OnHit }, sourceModel, targetModel)
			end

			RunService.PreRender:Wait()
			VFXCaches.Return(recipe.Effect, effect)
		end)

		task.spawn(function()
			RunService.PreRender:Wait()
			tween:Play()
		end)
	end
end

function VFXService._PlayBeamType(recipe: Steps.BeamStep, sourceModel: Model, targetModel: Model, range: number?)
	local beamKey = getBeamKey(recipe)
	if not ActiveBeams[sourceModel] then
		ActiveBeams[sourceModel] = {}
	end
	if ActiveBeams[sourceModel][beamKey] then
		return
	end
	if not isAlive(sourceModel) or targetModel:GetAttribute("DeadByBeam") then
		return
	end

	local fromInstance = resolveInstance(recipe.From, sourceModel, targetModel)
	local toInstance = resolveInstance(recipe.To, sourceModel, targetModel)
	if not fromInstance or not toInstance then
		warn(`위치를 찾을 수 없음: {recipe.Effect}`)
		return
	end

	if not fromInstance or not toInstance then
		warn(`Instance를 찾을 수 없음: {recipe.Effect}`)
		return
	end

	if not fromInstance:IsA("BasePart") or not toInstance:IsA("BasePart") then
		warn(`Beam 위치는 BasePart여야 함: {recipe.Effect}`)
		return
	end

	local sourceAttachment = getAttachment(fromInstance)
	local targetAttachment = getAttachment(toInstance)

	local effect, runId = VFXCaches.Get(recipe.Effect, CFrame.new())
	if not effect or not runId then
		return
	end

	local state = {
		Target = targetModel,
		Effect = effect,
		RunId = runId,
		Connection = nil,
		Instances = {},
		Cleaned = false,
	}

	ActiveBeams[sourceModel][beamKey] = state

	local function track(instance: Instance)
		table.insert(state.Instances, instance)
		return instance
	end

	local effectContents: Instance = effect
	if effect:IsA("Model") and effect.PrimaryPart then
		effectContents = effect.PrimaryPart
	end

	local startAttach = effectContents:FindFirstChild("Start")
	local endAttach = effectContents:FindFirstChild("End")

	if startAttach then
		for _, eff in startAttach:GetChildren() do
			if not (eff:IsA("ParticleEmitter") or eff:IsA("Beam") or eff:IsA("Trail")) then
				continue
			end

			local clonedEff = track(eff:Clone())
			pcall(function()
				(clonedEff :: any).TimeScale = TimeService:GetGameSpeed()
			end)
			clonedEff.Parent = sourceAttachment
		end
	end

	if endAttach then
		for _, eff in endAttach:GetChildren() do
			if not (eff:IsA("ParticleEmitter") or eff:IsA("Beam") or eff:IsA("Trail")) then
				continue
			end

			local clonedEff = track(eff:Clone())
			pcall(function()
				(clonedEff :: any).TimeScale = TimeService:GetGameSpeed()
			end)
			clonedEff.Parent = targetAttachment
		end
	end

	for _, beam in effectContents:GetChildren() do
		if not beam:IsA("Beam") then
			continue
		end

		local clonedBeam = track(beam:Clone())
		clonedBeam.Attachment0 = sourceAttachment
		clonedBeam.Attachment1 = targetAttachment
		pcall(function()
			(clonedBeam :: any).TimeScale = TimeService:GetGameSpeed()
		end)
		clonedBeam.Enabled = true
		clonedBeam.Parent = sourceAttachment
	end

	ForgeVFX.emit(sourceAttachment)
	ForgeVFX.emit(targetAttachment)

	local function cleanup()
		if state.Cleaned then
			return
		end
		state.Cleaned = true

		if state.Connection then
			state.Connection:Disconnect()
			state.Connection = nil
		end

		for _, inst in state.Instances do
			if inst.Parent then
				inst:Destroy()
			end
		end

		table.clear(state.Instances)

		if ActiveBeams[sourceModel] then
			ActiveBeams[sourceModel][beamKey] = nil

			if not next(ActiveBeams[sourceModel]) then
				ActiveBeams[sourceModel] = nil
			end
		end

		if effect:GetAttribute("VFXRunId") == runId then
			VFXCaches.Return(recipe.Effect, effect)
		end
	end

	local passedTime = 0
	state.Connection = RunService.PreRender:Connect(function(dt)
		passedTime += dt
		if passedTime < BEAM_CHECK_RATE then
			return
		end
		passedTime = 0

		if not isAlive(sourceModel) or not isAlive(targetModel) then
			RunService.PreRender:Wait()
			targetModel:SetAttribute("DeadByBeam", true)
			cleanup()
			return
		end
		if not sourceAttachment:IsDescendantOf(workspace) or not targetAttachment:IsDescendantOf(workspace) then
			cleanup()
			return
		end

		if range then
			local offset = targetAttachment.WorldPosition - sourceAttachment.WorldPosition
			local distanceSq = offset.X * offset.X + offset.Z * offset.Z

			if distanceSq > range * range then
				cleanup()
				return
			end
		end
	end)
end

function VFXService.Init(services)
	TimeService = services:GetService("TimeService")
end

function VFXService.Start()
	ForgeVFX.init()

	local ClientSignals = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.ClientSignals)
	ClientSignals.GameSpeedChanged:Connect(function(newSpeed)
		for _, sourceBeams in pairs(ActiveBeams) do
			for _, state in pairs(sourceBeams) do
				for _, inst in ipairs(state.Instances) do
					if inst:IsA("ParticleEmitter") or inst:IsA("Beam") or inst:IsA("Trail") then
						pcall(function()
							(inst :: any).TimeScale = newSpeed
						end)
					end
				end
			end
		end
	end)
end

return VFXService
