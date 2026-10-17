--/Services
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")

--/Modules
local ClientSignals = require(StarterPlayer.StarterPlayerScripts.Client.ClientSignals)
local EnemyData = require(ReplicatedStorage.Settings.Data.EnemyData)
local GetPath = require(ReplicatedStorage.Shared.Modules.Core.GetPath)
local CharacterUtils = require(ReplicatedStorage.Shared.Modules.Utils.CharacterUtils)
local Net = require(ReplicatedStorage.Shared.Net)
local EnemyVisuals = require(script.EnemyVisuals)
local NumberUtils = require(ReplicatedStorage.Shared.Modules.Utils.NumberUtils)
local TimeService
local AnimationService
local VisualService

local RANDOM = Random.new()
local DEATH_EXTRA_DELAY = 2.0
local RENDER_STEP_NAME = "EnemyClient.Render"

local isActived = false
local ActivedEnemies = {}
local DyingEnemies = {}

local partsToMove = {}
local cframesToMove = {}

-------------------------------------------------
--// Local Functions
-------------------------------------------------
local function removeStunVisuals(enemy)
	if enemy.StunEffect then
		enemy.StunEffect:Destroy()
		enemy.StunEffect = nil
	end
end

local function getEnemyCFrame(
	model: Model,
	pathAlpha: number,
	offset: number,
	moveDirection: number?,
	pathId: number
): CFrame
	local Height = CharacterUtils.GetHipHeight(model)
	local targetCFrame = GetPath:Get(pathId):CalculateUniformCFrame(pathAlpha) + Vector3.new(0, Height, 0)
	local cframeOffset = targetCFrame.RightVector * offset
	local finalCFrame = targetCFrame + cframeOffset

	if moveDirection and moveDirection < 0 then
		finalCFrame *= CFrame.Angles(0, math.rad(180), 0)
	end

	return finalCFrame
end

local function applyStunVisuals(enemy)
	if enemy.StunEffect then
		return
	end

	local stunModel = ReplicatedStorage.Assets.Visuals:FindFirstChild("Stun")
	if not stunModel then
		return
	end

	local stunEffect = stunModel:Clone()
	local rootPart = enemy.Model.PrimaryPart
	if not rootPart then
		stunEffect:Destroy()
		return
	end

	if stunEffect:IsA("BasePart") then
		stunEffect.Anchored = true
	end
	for _, part in stunEffect:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end

	local scale = 1
	local headPart = enemy.Model:FindFirstChild("Head")
	if headPart and headPart:IsA("BasePart") then
		scale = headPart.Size.Y
	else
		scale = rootPart.Size.Y / 2
	end

	if stunEffect:IsA("Model") then
		stunEffect:ScaleTo(scale)
	elseif stunEffect:IsA("BasePart") then
		stunEffect.Size = stunEffect.Size * scale
	end

	local targetCFrame
	if headPart and headPart:IsA("BasePart") then
		targetCFrame = CFrame.new(headPart.Position + Vector3.new(0, scale, 0))
	else
		local HipHeight = CharacterUtils.GetHipHeight(enemy.Model)
		targetCFrame = rootPart.CFrame + Vector3.new(0, HipHeight, 0)
	end

	if stunEffect:IsA("Model") then
		stunEffect:PivotTo(targetCFrame)
	elseif stunEffect:IsA("BasePart") then
		stunEffect.CFrame = targetCFrame
	end

	stunEffect.Parent = workspace:WaitForChild("Visuals")
	enemy.StunEffect = stunEffect
end

-------------------------------------------------
--// EnemyClient
-------------------------------------------------
local EnemyClient = {}

function EnemyClient.Init(services)
	TimeService = services:GetService("TimeService")
	AnimationService = services:GetService("AnimationService")
	VisualService = services:GetService("VisualService")
end

function EnemyClient.Start()
	Net.EnemyService.ReplicatedEnemy.On(EnemyClient.newEnemy)
	Net.EnemyService.UpdateSpeed.On(EnemyClient._OnUpdateSpeed)
	Net.EnemyService.UpdateDirection.On(EnemyClient._OnUpdateDirection)
	Net.EnemyService.HealthUpdated.On(EnemyClient._OnHealthUpdated)
	Net.EnemyService.AttributesUpdated.On(EnemyClient._OnAttributesUpdated)
	Net.EnemyService.AbilityTriggered.On(EnemyClient._OnAbilityTriggered)
	Net.EnemyService.TakeKnockback.On(EnemyClient._TakeKnockback)
	Net.EnemyService.DestroyEnemy.On(function(enemyId: number)
		EnemyClient.Destroy(enemyId, true)
	end)

	ClientSignals.GameSpeedChanged:Connect(EnemyClient._OnGameSpeedChanged)
end

function EnemyClient.newEnemy(data: {
	enemyId: number,
	enemyIndex: number,
	sentClockMs: number,
	isBoss: boolean?,
	startPathAlpha: number?,
	pathId: number,
	maxHealth: number,
	maxShieldHealth: number,
})
	if data.maxHealth <= 0 then
		return
	end
	local enemyData = EnemyData.ByIndex[data.enemyIndex]
	if not enemyData then
		return
	end

	local enemyModel = ReplicatedStorage.Assets.Enemies:FindFirstChild(enemyData.Name)
	if not enemyModel then
		warn("적 모델이 존재하지 않음.")
		return
	end

	local clonedModel = enemyModel:Clone()
	clonedModel.Name = `Enemy_{data.enemyId}`
	clonedModel.PrimaryPart.Anchored = true

	local pathLength = GetPath:Get(data.pathId):GetPathLength()
	local pingTime = NumberUtils.GetClockPingTime(data.sentClockMs / 1000)

	local offsetVal = RANDOM:NextNumber(-0.5, 0.5)

	local baseAlpha = data.startPathAlpha or 0
	local pathAlphaVal = baseAlpha + ((enemyData.WalkSpeed * pingTime) / pathLength)
	pathAlphaVal = math.clamp(pathAlphaVal, 0, 1)

	local finalCFrame = getEnemyCFrame(clonedModel, pathAlphaVal, offsetVal, 1, data.pathId)
	clonedModel:PivotTo(finalCFrame)

	clonedModel.Parent = workspace.Enemies

	AnimationService.Load(clonedModel, enemyData.Name)
	AnimationService.Play(clonedModel, "Walk", nil, 0)

	CharacterUtils.SetCollisionGroup(clonedModel, "Enemy", function(part)
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
	end)

	VisualService.Play(enemyData.Name, "OnSpawn", 0, clonedModel, clonedModel)

	ActivedEnemies[data.enemyId] = {
		Id = data.enemyId,
		Name = enemyData.Name,
		Model = clonedModel,

		BaseSpeed = enemyData.WalkSpeed,
		WalkSpeed = enemyData.WalkSpeed,
		PathAlpha = pathAlphaVal,
		PathId = data.pathId,
		Offset = offsetVal,
		MoveDirection = 1,

		MaxHealth = data.maxHealth,
		Health = data.maxHealth,
		MaxShieldHealth = data.maxShieldHealth,
		ShieldHealth = data.maxShieldHealth,
		Attributes = {},

		IsBoss = data.isBoss,
	}

	if data.isBoss then
		ClientSignals.BossSpawned:Fire(ActivedEnemies[data.enemyId])
	end

	EnemyVisuals.Attach(ActivedEnemies[data.enemyId])

	EnemyClient.StartMoveLoop()
end

function EnemyClient.Destroy(enemyId: number, forcing: boolean?)
	local targetEnemy = ActivedEnemies[enemyId]
	if not targetEnemy then
		return
	end

	if targetEnemy.IsBoss then
		ClientSignals.BossDestroyed:Fire(enemyId)
	end

	EnemyVisuals.Destroy(enemyId)

	if targetEnemy.Model then
		if not forcing then
			DyingEnemies[enemyId] = targetEnemy
			targetEnemy.Model.Destroying:Once(function()
				if DyingEnemies[enemyId] == targetEnemy then
					DyingEnemies[enemyId] = nil
				end
			end)
		end

		if not forcing and AnimationService.GetTrack(targetEnemy.Model, "Death") then
			AnimationService.Stop(targetEnemy.Model)
			local track = AnimationService.Play(targetEnemy.Model, "Death") :: AnimationTrack

			local animLength = (track and track.Length > 0) and track.Length or 1.5
			local delayTime = animLength + DEATH_EXTRA_DELAY

			TimeService.DeltaDelay(math.max(0.01, animLength - 0.05)):andThen(function()
				track:AdjustSpeed(0)
			end)
			TimeService.DeltaDelay(delayTime):andThen(function()
				EnemyClient.DisappearModel(targetEnemy.Model)
			end)

			Debris:AddItem(targetEnemy.Model, delayTime + 5)
		else
			task.defer(EnemyClient.DisappearModel, targetEnemy.Model)
			Debris:AddItem(targetEnemy.Model, 5)
		end
	end

	removeStunVisuals(targetEnemy)

	ActivedEnemies[enemyId] = nil
end

function EnemyClient.StartMoveLoop()
	if isActived then
		return
	end
	isActived = true

	RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Last.Value + 2, function(dt)
		local hasEnemies = EnemyClient.MoveAllEnemies(dt)
		EnemyVisuals.Render(dt)

		if not hasEnemies then
			isActived = false
			RunService:UnbindFromRenderStep(RENDER_STEP_NAME)
		end
	end)
end

function EnemyClient.MoveAllEnemies(dt)
	table.clear(partsToMove)
	table.clear(cframesToMove)

	local hasEnemies = false

	for id, enemy in pairs(ActivedEnemies) do
		hasEnemies = true

		local rootPart = enemy.Model.PrimaryPart
		if not rootPart then
			continue
		end

		local pathLength = GetPath:Get(enemy.PathId):GetPathLength()

		enemy.PathAlpha += ((enemy.WalkSpeed * dt * TimeService:GetGameSpeed()) / pathLength) * enemy.MoveDirection
		enemy.PathAlpha = math.clamp(enemy.PathAlpha, 0, 1)

		if enemy.PathAlpha >= 1 then
			EnemyClient.Destroy(id)
			continue
		end

		local finalCFrame =
			getEnemyCFrame(enemy.Model, enemy.PathAlpha, enemy.Offset, enemy.MoveDirection, enemy.PathId)

		table.insert(partsToMove, rootPart)
		table.insert(cframesToMove, finalCFrame)
	end

	if #partsToMove > 0 then
		workspace:BulkMoveTo(partsToMove, cframesToMove, Enum.BulkMoveMode.FireCFrameChanged)
	end

	return hasEnemies
end

function EnemyClient.DisappearModel(model)
	model.PrimaryPart:SetAttribute("Dead", true)

	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") or part:IsA("Decal") then
			part.Transparency = 1
		end
	end
end

function EnemyClient._OnGameSpeedChanged(newSpeed: number, oldSpeed: number, pingTime: number)
	for _, enemy in pairs(ActivedEnemies) do
		local pathLength = GetPath:Get(enemy.PathId):GetPathLength()
		local pingOffset = (enemy.WalkSpeed * pingTime * (newSpeed - oldSpeed) * enemy.MoveDirection) / pathLength

		enemy.PathAlpha += pingOffset
	end
end

function EnemyClient._OnUpdateSpeed(data: { enemyId: number, WalkSpeed: number, sentClockTime: number })
	local updatedEnemy = ActivedEnemies[data.enemyId]
	if not updatedEnemy then
		return
	end

	local pingTime = NumberUtils.GetClockPingTime(data.sentClockTime)

	local CalWalkSpeed = data.WalkSpeed / 100
	local pathLength = GetPath:Get(updatedEnemy.PathId):GetPathLength()

	local pingOffset = (updatedEnemy.WalkSpeed * pingTime * updatedEnemy.MoveDirection) / pathLength
	local alphaOffset = (CalWalkSpeed * pingTime * updatedEnemy.MoveDirection) / pathLength

	updatedEnemy.WalkSpeed = CalWalkSpeed
	updatedEnemy.PathAlpha += -pingOffset + alphaOffset

	local speedRatio = CalWalkSpeed / updatedEnemy.BaseSpeed
	local walkTrack = AnimationService.GetTrack(updatedEnemy.Model, "Walk")
	if walkTrack then
		walkTrack:AdjustSpeed(speedRatio)
	end

	if CalWalkSpeed == 0 then
		task.spawn(function()
			RunService.PreRender:Wait()
			task.defer(applyStunVisuals, updatedEnemy)
		end)
	else
		removeStunVisuals(updatedEnemy)
	end
end

function EnemyClient._OnUpdateDirection(data: { enemyId: number, MoveDirection: boolean, sentClockTime: number })
	local updatedEnemy = ActivedEnemies[data.enemyId]
	if not updatedEnemy then
		return
	end

	local pingTime = NumberUtils.GetClockPingTime(data.sentClockTime)

	local convertDirection = data.MoveDirection and 1 or -1
	local pathLength = GetPath:Get(updatedEnemy.PathId):GetPathLength()

	local pingOffset = (updatedEnemy.WalkSpeed * pingTime * (convertDirection - updatedEnemy.MoveDirection))
		/ pathLength

	updatedEnemy.MoveDirection = convertDirection
	updatedEnemy.PathAlpha += pingOffset
end

function EnemyClient._TakeKnockback(data: { enemyId: number, studs: number })
	local updatedEnemy = ActivedEnemies[data.enemyId]
	if not updatedEnemy then
		return
	end

	local pathLength = GetPath:Get(updatedEnemy.PathId):GetPathLength()
	local converknockback = (data.studs / 10) / pathLength

	local duration = 0.2
	local startTime = os.clock()
	local startAlpha = updatedEnemy.PathAlpha
	local targetAlpha = math.clamp(startAlpha - converknockback, 0, 1)

	task.spawn(function()
		while true do
			local currentEnemy = ActivedEnemies[data.enemyId]
			if not currentEnemy then
				break
			end

			local elapsed = (os.clock() - startTime) * TimeService:GetGameSpeed()
			if elapsed >= duration then
				break
			end

			local t = elapsed / duration
			local easedT = t * (2 - t)
			currentEnemy.PathAlpha = math.clamp(NumberUtils.Lerp(startAlpha, targetAlpha, easedT), 0, 1)
			task.wait()
		end

		local finalEnemy = ActivedEnemies[data.enemyId]
		if finalEnemy then
			finalEnemy.PathAlpha = targetAlpha
		end
	end)
end

function EnemyClient._OnHealthUpdated(data: { enemyId: number, health: number, shieldHealth: number })
	local enemy = ActivedEnemies[data.enemyId]
	if not enemy then
		return
	end

	enemy.Health = data.health
	enemy.ShieldHealth = data.shieldHealth
	EnemyVisuals.Update(enemy)
	if enemy.IsBoss then
		ClientSignals.BossDamaged:Fire(data.enemyId, enemy.Health, enemy.MaxHealth, enemy.ShieldHealth)
	end

	if enemy.Health <= 0 then
		EnemyClient.Destroy(data.enemyId)
	end
end

function EnemyClient.Get(enemyId: number)
	return ActivedEnemies[enemyId]
end

function EnemyClient._OnAttributesUpdated(data: { enemyId: number, attributes: { [string]: any } })
	local enemy = ActivedEnemies[data.enemyId]
	if not enemy then
		return
	end

	enemy.Attributes = data.attributes
	ClientSignals.EnemyAttributesChanged:Fire(enemy)
end

function EnemyClient._OnAbilityTriggered(data: { enemyId: number, abilityType: string, arg: any? })
	local enemy = ActivedEnemies[data.enemyId] or DyingEnemies[data.enemyId]
	if not enemy or not enemy.Model.Parent then
		return
	end

	local eventName = `Ability_{data.abilityType}`
	local arg = data.arg
	local targetModel = if typeof(arg) == "table" and arg.EnemyId
		then workspace.Enemies:FindFirstChild(`Enemy_{arg.EnemyId}`)
		else nil
	local range = if typeof(arg) == "table" and typeof(arg.Range) == "number" then arg.Range else nil

	if ActivedEnemies[data.enemyId] and AnimationService.GetTrack(enemy.Model, eventName) then
		AnimationService.Play(enemy.Model, eventName)
	end
	VisualService.Play(enemy.Name, eventName, 0, enemy.Model, targetModel, range)
	ClientSignals.EnemyAbilityTriggered:Fire(enemy, data.abilityType, arg)
end

return EnemyClient
