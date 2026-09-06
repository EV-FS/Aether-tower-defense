--/Services
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")

--/Service Modules
local EconomyService
local InputService

--/Core Modules
local ClientSignals = require(StarterPlayer.StarterPlayerScripts.Client.ClientSignals)
local TowerPlacement = require(script.TowerPlacement)
local TowerRenderer = require(script.TowerRenderer)
local PlaceValidator = require(script.Parent.Utils.PlaceValidator)
local Net = require(ReplicatedStorage.Shared.Net)

--/Modules
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)
local MouseRayCast = require(ReplicatedStorage.Shared.Modules.Utils.MouseRayCast)
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)
local CharacterUtils = require(ReplicatedStorage.Shared.Modules.Utils.CharacterUtils)
local NotificationService = require(ReplicatedStorage.Shared.Services.System.NotificationService)
local CreateRangeIndicator = require(script.Parent.Utils.CreateRangeIndicator)

--/Constants
local PLAYER = Players.LocalPlayer
local placementSession
local hoveredTowerModel
local selectedTowerId
local PlacementScope
local SelectionScope

-------------------------------------------------
--// Local Functions
-------------------------------------------------
local function findTaggedAncestor(instance: Instance): Model?
	local current = instance

	while current do
		if current:IsA("Model") and CollectionService:HasTag(current, "Tower") then
			return current
		end

		current = current.Parent
	end

	return nil
end

local function getSortedPlayers()
	local players = Players:GetPlayers()
	table.sort(players, function(a, b)
		if a.UserId == b.UserId then
			return a.Name < b.Name
		end
		return a.UserId < b.UserId
	end)

	return players
end

local function getPlayerBySlot(slot: number): Player?
	return getSortedPlayers()[slot]
end

-------------------------------------------------
--// TowerClient
-------------------------------------------------
local TowerClient = {}
TowerClient.PlacedTowers = {}
TowerClient.ActiveTowers = {}

function TowerClient.Init(services)
	EconomyService = services:GetService("EconomyService")
	InputService = services:GetService("InputService")

	TowerRenderer.Init(services)
	TowerPlacement.Init(services, TowerClient.GetTowerCount)
	CreateRangeIndicator.Init()
end

function TowerClient.Start()
	TowerRenderer.Start()

	--/Input
	local iScope = InputService.Scope
	local iAction = InputService.Action
	local iInfo = InputService.Info

	PlacementScope = iScope("PlacementInput", {
		iAction("Spawn", iInfo({ Enum.UserInputType.MouseButton1, "DoubleTap" })),
		iAction("Rotate", iInfo({ Enum.KeyCode.R })),
		iAction("Cancel", iInfo({ Enum.KeyCode.X })),
	}):Disable()

	SelectionScope = iScope("SelectionInput", {
		iAction("Click", iInfo({ Enum.UserInputType.MouseButton1, "Touch" })),
	}):Enable()

	--/Connect
	RunService.PreRender:Connect(function()
		TowerClient._UpdateHoverState()

		if placementSession then
			placementSession:Update()
		end
	end)

	TowerClient._SetPlacementInput()
	TowerClient._SetSelectionInput()

	ClientSignals.SpawnRequested:Connect(function(towerName: string, towerKey: string)
		TowerClient.StartPlacement(towerName, towerKey)
	end)

	ClientSignals.UpgradeRequested:Connect(TowerClient.RequestUpgrade)
	ClientSignals.SellRequested:Connect(TowerClient.RequestSell)
	ClientSignals.ChangeTargetRequested:Connect(TowerClient.RequestSetTargetMode)

	Net.TowerService.OnAttackEnemy.On(TowerClient._OnAttackEnemy)
	Net.TowerService.TowerUpdated.On(TowerClient._TowerUpdated)
	Net.TowerService.TowerDestroyed.On(TowerClient.RemoveTower)
	Net.TowerService.TowerSpawned.On(TowerClient._TowerSpawned)
	Net.TowerService.TowerTargetModeUpdated.On(TowerClient._TowerTargetModeUpdated)
	Net.TowerService.PassiveTriggered.On(TowerClient._PassiveTriggered)
end

function TowerClient._SetPlacementInput()
	PlacementScope.Actions.Spawn.Began:Connect(TowerClient.RequestSpawn)
	PlacementScope.Actions.Rotate.Began:Connect(function()
		placementSession:Rotate()
	end)
	PlacementScope.Actions.Cancel.Began:Connect(function()
		placementSession:Destroy()
		placementSession = nil

		PlacementScope:Disable()
		SelectionScope:Enable()
	end)
end

function TowerClient._SetSelectionInput()
	SelectionScope.Actions.Click.Began:Connect(function()
		local result = MouseRayCast()

		if result and result.Instance then
			local model = findTaggedAncestor(result.Instance)
			if model then
				local towerId = model:GetAttribute("Id")
				local towerData = TowerClient.ActiveTowers[towerId]
				selectedTowerId = towerId

				TowerRenderer.ToggleRangeIndicator(true, towerId, towerData)
				ClientSignals.TowerSelected:Fire(towerId, towerData)
				return
			end
		end

		selectedTowerId = nil
		TowerRenderer.ToggleRangeIndicator(false)
		ClientSignals.TowerUnselected:Fire()
	end)
end

function TowerClient.GetTowerCount(towerName)
	return TowerClient.PlacedTowers[towerName] or 0
end

function TowerClient.StartPlacement(towerName: string, towerKey: string?)
	if placementSession then
		placementSession:Destroy()
	end

	if selectedTowerId then
		selectedTowerId = nil
		TowerRenderer.ToggleRangeIndicator(false)
		ClientSignals.TowerUnselected:Fire()
	end

	placementSession = TowerPlacement.new(towerName, towerKey)
	placementSession:Start()

	PlacementScope:Enable()
	SelectionScope:Disable()
end

function TowerClient.RegisterTower(player: Player?, towerId: number, data)
	TowerRenderer.Setup(towerId, data.towerModel, data.towerName, data.borderData)

	if player == PLAYER then
		TowerClient.PlacedTowers[data.towerName] = (TowerClient.PlacedTowers[data.towerName] or 0) + 1
		ClientSignals.TowerCountChanged:Fire(data.towerName, TowerClient.PlacedTowers[data.towerName])
	end

	TowerClient.ActiveTowers[towerId] = {
		Owner = player,
		Name = data.towerName,
		Model = data.towerModel,
		Position = data.position or Vector3.new(data.borderData.x, 0, data.borderData.z),
		Target = "First",
		Level = 0,
		Stats = TableUtils.DeepCopy(TowerData.ByName[data.towerName].Stats[0]),
	}

	PlaceValidator.AddBorder(towerId, data.borderData)
end

function TowerClient._CreateTowerModel(towerName: string, spawnPosition: Vector3, rotation: number?): Model?
	local towerAsset = ReplicatedStorage.Assets.Towers:FindFirstChild(towerName)
	if not towerAsset then
		return nil
	end

	local towerModel = towerAsset:Clone()
	if towerModel.PrimaryPart then
		towerModel.PrimaryPart.Anchored = true
	end

	local heightOffset = CharacterUtils.GetHipHeight(towerModel)
	local targetCFrame = CFrame.new(spawnPosition + Vector3.new(0, heightOffset, 0))
		* CFrame.Angles(0, math.rad(rotation or 0), 0)
	towerModel:PivotTo(targetCFrame)

	return towerModel
end

function TowerClient._TowerSpawned(data: {
	towerId: number,
	towerIndex: number,
	ownerSlot: number,
	spawnLocation: Vector3,
})
	if TowerClient.ActiveTowers[data.towerId] then
		return
	end

	local towerInfo = TowerData.ByIndex[data.towerIndex]
	if not towerInfo then
		return
	end

	local towerModel = TowerClient._CreateTowerModel(towerInfo.Name, data.spawnLocation)
	if not towerModel or not towerModel.PrimaryPart then
		return
	end

	local borderRadius = towerModel.PrimaryPart.Size.X * 1.5
	TowerClient.RegisterTower(getPlayerBySlot(data.ownerSlot), data.towerId, {
		towerName = towerInfo.Name,
		position = data.spawnLocation,
		borderData = {
			x = data.spawnLocation.X,
			z = data.spawnLocation.Z,
			r = borderRadius,
		},
		towerModel = towerModel,
	})
end

function TowerClient.RemoveTower(towerId: number)
	local towerData = TowerClient.ActiveTowers[towerId]
	if not towerData then
		return
	end

	if TowerClient.PlacedTowers[towerData.Name] then
		TowerClient.PlacedTowers[towerData.Name] = math.max(0, TowerClient.PlacedTowers[towerData.Name] - 1)
		ClientSignals.TowerCountChanged:Fire(towerData.Name, TowerClient.PlacedTowers[towerData.Name])
	end

	TowerRenderer.SellVisuals(towerId)
	TowerRenderer.Cleanup(towerId)
	PlaceValidator.RemoveBorder(towerId)

	TowerClient.ActiveTowers[towerId] = nil

	ClientSignals.TowerDestroyed:Fire(towerId)

	if hoveredTowerModel == towerData.Model then
		hoveredTowerModel = nil
	end

	if selectedTowerId == towerId then
		selectedTowerId = nil
	end
end

function TowerClient.RequestSpawn()
	if not placementSession then
		return
	end

	local placementData = placementSession:GetPlacementData()
	if not placementData then
		return
	end

	local towerName = placementSession.TowerName
	local towerKey = placementSession.TowerKey
	local spawnPosition = placementData.Position
	if typeof(towerKey) ~= "string" then
		warn(`Cannot spawn tower "{towerName}" without a tower key.`)
		return
	end

	local validationData = {
		["TowerName"] = towerName,
		["SpawnPosition"] = spawnPosition,
		["BorderRadius"] = placementData.BorderRadius,
		["CurrentCash"] = EconomyService.GetCash(PLAYER),
		["CurrentCount"] = TowerClient.GetTowerCount(towerName),
	}

	local canSpawn, errorMsg = PlaceValidator.CheckSpawn(validationData)
	if not canSpawn then
		NotificationService:Pull(PLAYER, errorMsg, "Error", 3)
		return
	end

	local spawnRequestData = {
		spawnLocation = spawnPosition,
		towerIndex = TowerData.ByName[towerName].Index,
		towerKey = towerKey,
	}

	local newTowerId = Net.TowerService.SpawnNewTower.Invoke(spawnRequestData):expect()

	if newTowerId then
		local newModel = TowerClient._CreateTowerModel(towerName, spawnPosition, placementData.Rotation)
		if not newModel then
			return
		end

		local borderData = {
			x = spawnPosition.X,
			z = spawnPosition.Z,
			r = placementData.BorderRadius,
		}

		local newTowerData = {
			towerName = towerName,
			position = spawnPosition,
			borderData = borderData,
			towerModel = newModel,
		}

		TowerClient.RegisterTower(PLAYER, newTowerId, newTowerData)

		placementSession:Destroy()
		placementSession = nil

		PlacementScope:Disable()
		SelectionScope:Enable()
	end
end

function TowerClient.RequestUpgrade(towerId)
	if placementSession then
		return false
	end

	local towerData = TowerClient.ActiveTowers[towerId]
	if not towerData or towerData._isUpgrading then
		return
	end

	towerData._isUpgrading = true

	local success = Net.TowerService.UpgradeTower.Invoke(towerId):expect()

	towerData._isUpgrading = false

	if not success then
		warn("업그레이드 실패.")
	end

	return success
end

function TowerClient.RequestSell(towerId)
	if placementSession then
		return false
	end

	local success = Net.TowerService.SellTower.Invoke(towerId):expect()
	if not success then
		warn("판매 실패.")
	end

	return success
end

function TowerClient.RequestSetTargetMode(towerId, targetMode)
	local success = Net.TowerService.SetTargetMode
		.Invoke({
			towerId = towerId,
			targetMode = targetMode,
		})
		:expect()

	if not success then
		warn("타겟 변경 실패.")
	end

	return success
end

function TowerClient._TowerTargetModeUpdated(data: { towerId: number, targetMode: string })
	local towerData = TowerClient.ActiveTowers[data.towerId]
	if not towerData then
		return
	end

	towerData.Target = data.targetMode
	if selectedTowerId == data.towerId then
		ClientSignals.TowerUpdated:Fire(data.towerId, towerData)
	end
end

function TowerClient._PassiveTriggered(data: { towerId: number, passiveType: string, arg: { [string]: any }? })
	local towerData = TowerClient.ActiveTowers[data.towerId]
	if not towerData then
		return
	end

	TowerRenderer.OnPassiveTriggered(data.towerId, data.passiveType, data.arg)
end

function TowerClient._OnAttackEnemy(data: { enemyId: number, towerId: number, attackSlot: number? })
	local towerData = TowerClient.ActiveTowers[data.towerId]
	local enemyModel = workspace.Enemies:FindFirstChild(`Enemy_{data.enemyId}`)

	if not towerData or not enemyModel then
		return
	end

	local attackVariant = nil
	local attackStats = towerData.Stats

	if data.attackSlot == 2 then
		attackStats = towerData.Stats.Secondary
		attackVariant = "Secondary"
	elseif data.attackSlot == 3 then
		attackStats = towerData.Stats.Tertiary
		attackVariant = "Tertiary"
	end

	TowerRenderer.OnAttack(data.towerId, enemyModel, attackStats, attackVariant)
end

function TowerClient._TowerUpdated(data: { towerId: number, towerLevel: number })
	local towerData = TowerClient.ActiveTowers[data.towerId]
	if not towerData then
		return
	end

	towerData.Level = data.towerLevel
	towerData.Stats = TableUtils.DeepCopy(TowerData.ByName[towerData.Name].Stats[data.towerLevel])

	TowerRenderer.UpgradeVisuals(data.towerLevel, data.towerId)
	if selectedTowerId == data.towerId then
		TowerRenderer.ToggleRangeIndicator(true, data.towerId, towerData)
	end

	ClientSignals.TowerUpdated:Fire(data.towerId, towerData)
end

function TowerClient._UpdateHoverState()
	local result = MouseRayCast()

	if result and result.Instance then
		local model = findTaggedAncestor(result.Instance)

		if model and CollectionService:HasTag(model, "Tower") then
			if model ~= hoveredTowerModel then
				if hoveredTowerModel then
					ClientSignals.TowerUnhovered:Fire()
				end
				hoveredTowerModel = model
				local towerId = model:GetAttribute("Id")
				local towerData = TowerClient.ActiveTowers[towerId]
				ClientSignals.TowerHovered:Fire(model, towerData)
			end
			return
		end
	end

	if hoveredTowerModel then
		hoveredTowerModel = nil
		ClientSignals.TowerUnhovered:Fire()
	end
end

return TowerClient
