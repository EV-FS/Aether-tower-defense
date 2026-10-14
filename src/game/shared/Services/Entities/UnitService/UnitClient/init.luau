--/Services
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")

--/Modules
local ClientSignals = require(StarterPlayer.StarterPlayerScripts.Client.ClientSignals)
local UnitData = require(ReplicatedStorage.Settings.Data.UnitData)
local EnemyData = require(ReplicatedStorage.Settings.Data.EnemyData)
local TowerClient = require(ReplicatedStorage.Shared.Services.Entities.TowerService.TowerClient)
local UnitRenderer = require(script.UnitRenderer)
local UnitVisuals = require(script.UnitVisuals)
local GetPath = require(ReplicatedStorage.Shared.Modules.Core.GetPath)
local CharacterUtils = require(ReplicatedStorage.Shared.Modules.Utils.CharacterUtils)
local NumberUtils = require(ReplicatedStorage.Shared.Modules.Utils.NumberUtils)
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)
local Net = require(ReplicatedStorage.Shared.Net)
local AnimationService
local VisualService
local TimeService

local RANDOM = Random.new()

local isActived = false
local ActivedUnits = {}

local partsToMove = {}
local cframesToMove = {}

-------------------------------------------------
--// Local Functions
-------------------------------------------------
local function playSpawnEffects(summoner, clonedModel: Model, unitName: string)
	if summoner then
		VisualService.Play(summoner.Name, "Summon", summoner.Level, summoner.Model, clonedModel)
	end

	VisualService.Play(unitName, "OnSpawn", 0, clonedModel, clonedModel)
end

local function getUnitBaseStats(unitData, summoner)
	local walkSpeed = unitData.WalkSpeed
	local maxHealth = unitData.MaxHealth
	local stats = unitData.Stats and TableUtils.DeepCopy(unitData.Stats)

	local summonerStats = summoner and summoner.Stats
	if summonerStats then
		local custom = nil

		if summonerStats.Summons then
			for _, summonConfig in summonerStats.Summons do
				if summonConfig.SummonUnit == unitData.Name then
					custom = summonConfig.UnitStats
					break
				end
			end
		elseif summonerStats.SummonUnit == unitData.Name then
			custom = summonerStats.UnitStats
		end

		if custom then
			if custom.MaxHealth then
				maxHealth = custom.MaxHealth
			end
			if custom.WalkSpeed then
				walkSpeed = custom.WalkSpeed
			end

			if stats then
				for key, val in pairs(custom) do
					if key ~= "MaxHealth" and key ~= "WalkSpeed" then
						stats[key] = val
					end
				end
			end
		end
	end

	return walkSpeed, maxHealth, stats
end

-------------------------------------------------
--// UnitClient
-------------------------------------------------
local UnitClient = {}

function UnitClient.Init(services)
	UnitRenderer.Init(services)

	AnimationService = services:GetService("AnimationService")
	VisualService = services:GetService("VisualService")
	TimeService = services:GetService("TimeService")
end

function UnitClient.Start()
	UnitRenderer.Start()

	Net.UnitService.ReplicatedUnit.On(UnitClient.newUnit)
	Net.UnitService.UnitDestroyed.On(UnitClient.Destroy)
	Net.UnitService.OnAttackEnemy.On(UnitClient._OnAttackEnemy)
	Net.UnitService.OnDamaged.On(UnitClient._OnDamaged)

	ClientSignals.GameSpeedChanged:Connect(UnitClient._OnGameSpeedChanged)
end

function UnitClient.newUnit(data: {
	unitId: number,
	unitIndex: number,
	summonerId: number,
	sentClockMs: number,
	pathAlpha: number?,
	isEnemyType: boolean?,
})
	local unitData = if data.isEnemyType then EnemyData.ByIndex[data.unitIndex] else UnitData.ByIndex[data.unitIndex]
	if not unitData then
		return
	end

	local unitModel = (if data.isEnemyType then ReplicatedStorage.Assets.Enemies else ReplicatedStorage.Assets.Units):FindFirstChild(
		unitData.Name
	)
	if not unitModel then
		return
	end

	local clonedModel = unitModel:Clone()
	clonedModel.Name = `Unit_{data.unitId}`
	clonedModel.PrimaryPart.Anchored = true
	clonedModel.Parent = workspace.Units

	AnimationService.Load(clonedModel, unitData.Name)
	AnimationService.Play(clonedModel, "Walk", nil, 0)

	CharacterUtils.SetCollisionGroup(clonedModel, "Unit", function(part)
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
	end)

	local summoner = TowerClient.ActiveTowers[data.summonerId]
	playSpawnEffects(summoner, clonedModel, unitData.Name)

	local pingTime = NumberUtils.GetClockPingTime(data.sentClockMs / 1000)

	local walkSpeed, maxHealth, stats = getUnitBaseStats(unitData, summoner)

	local pathLength = GetPath:Get():GetPathLength()
	local startAlpha = data.pathAlpha and (data.pathAlpha / 65535) or 1

	ActivedUnits[data.unitId] = {
		Model = clonedModel,
		Name = unitData.Name,
		WalkSpeed = walkSpeed,
		MaxHealth = maxHealth,
		Health = maxHealth,
		Stats = stats,
		Offset = RANDOM:NextNumber(-0.5, 0.5),
		PathAlpha = startAlpha - (walkSpeed * pingTime) / pathLength,
	}

	UnitVisuals.Attach(data.unitId, unitData.Name, clonedModel, maxHealth)

	UnitClient.StartMoveLoop()
end

function UnitClient.Destroy(unitId: number)
	local targetUnit = ActivedUnits[unitId]
	if not targetUnit then
		return
	end

	UnitVisuals.Destroy(unitId)
	UnitRenderer.Cleanup(unitId, targetUnit.Model)

	if targetUnit.Model then
		UnitClient.DisappearModel(targetUnit.Model)
		Debris:AddItem(targetUnit.Model, 5)
	end

	ActivedUnits[unitId] = nil
end

function UnitClient.StartMoveLoop()
	if isActived then
		return
	end
	isActived = true

	local connection
	connection = RunService.PreRender:Connect(function(dt)
		local hasUnits = UnitClient.MoveAllUnits(dt)

		if not hasUnits then
			isActived = false
			connection:Disconnect()
		end
	end)
end

function UnitClient.MoveAllUnits(dt)
	table.clear(partsToMove)
	table.clear(cframesToMove)

	local hasUnits = false

	for id, unit in pairs(ActivedUnits) do
		hasUnits = true

		local rootPart = unit.Model.PrimaryPart
		if not rootPart then
			continue
		end

		if not unit.PauseEndTime or os.clock() >= unit.PauseEndTime then
			if unit.IsPaused then
				unit.IsPaused = false
				AnimationService.Play(unit.Model, "Walk", nil, 0.1)
			end

			local pathLength = GetPath:Get():GetPathLength()

			unit.PathAlpha -= ((unit.WalkSpeed * dt * TimeService:GetGameSpeed()) / pathLength)
			unit.PathAlpha = math.clamp(unit.PathAlpha, 0, 1)
		else
			if not unit.IsPaused then
				unit.IsPaused = true
				AnimationService.Stop(unit.Model, "Walk")
			end
		end

		if unit.PathAlpha <= 0 then
			UnitClient.Destroy(id)
			continue
		end

		local Height = CharacterUtils.GetHipHeight(unit.Model)
		local targetCFrame = GetPath:Get():CalculateUniformCFrame(unit.PathAlpha) + Vector3.new(0, Height, 0)
		local cframeOffset = targetCFrame.RightVector * unit.Offset

		local finalCFrame = targetCFrame + cframeOffset

		if unit.LookEndTime and os.clock() < unit.LookEndTime and unit.TargetEnemy and unit.TargetEnemy.PrimaryPart then
			local lookPos = unit.TargetEnemy.PrimaryPart.Position
			local unitPos = finalCFrame.Position
			finalCFrame = CFrame.lookAt(unitPos, Vector3.new(lookPos.X, unitPos.Y, lookPos.Z))
		else
			finalCFrame *= CFrame.Angles(0, math.rad(180), 0)
		end

		table.insert(partsToMove, rootPart)
		table.insert(cframesToMove, finalCFrame)
	end

	if #partsToMove > 0 then
		workspace:BulkMoveTo(partsToMove, cframesToMove, Enum.BulkMoveMode.FireCFrameChanged)
	end

	return hasUnits
end

function UnitClient.DisappearModel(model)
	model.PrimaryPart.CFrame = CFrame.new(2 ^ 24, 2 ^ 24, 2 ^ 24)
end

function UnitClient._OnAttackEnemy(data: { enemyId: number, unitId: number })
	local unitData = ActivedUnits[data.unitId]
	local enemyModel = workspace.Enemies:FindFirstChild(`Enemy_{data.enemyId}`)

	if not unitData or not enemyModel then
		return
	end

	if unitData.Stats and unitData.Stats.StopWhenAttacking then
		unitData.PauseEndTime = os.clock() + 3
	end

	unitData.TargetEnemy = enemyModel
	unitData.LookEndTime = os.clock() + 3

	UnitRenderer.OnAttack(data.unitId, unitData.Model, unitData.Name, enemyModel, unitData.Stats)
end

function UnitClient._OnDamaged(data: { unitId: number, damaged: number })
	local updatedUnit = ActivedUnits[data.unitId]
	if not updatedUnit then
		return
	end

	updatedUnit.Health -= data.damaged
	UnitVisuals.Update(data.unitId, updatedUnit.Health, updatedUnit.MaxHealth)

	if updatedUnit.Health <= 0 then
		UnitClient.Destroy(data.unitId)
	end
end

function UnitClient._OnGameSpeedChanged(newSpeed: number, oldSpeed: number, pingTime: number)
	local pathLength = GetPath:Get():GetPathLength()

	for _, unit in pairs(ActivedUnits) do
		local pingOffset = (unit.WalkSpeed * pingTime * (newSpeed - oldSpeed)) / pathLength

		unit.PathAlpha -= pingOffset
	end
end

return UnitClient
