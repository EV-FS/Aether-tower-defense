--/Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

--/Modules
local BaseTower = require(ServerScriptService.Server.Classes.Tower.BaseTower)
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)
local Net = require(ReplicatedStorage.Shared.Net)
local PlaceValidator = require(ReplicatedStorage.Shared.Services.Entities.TowerService.Utils.PlaceValidator)
local TowerRegistry = require(script.Registry)

local EconomyService

--/Variables
local towerClasses = {}

-------------------------------------------------
--// Local Functions
-------------------------------------------------
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

local function getPlayerSlot(player: Player): number
	for index, sortedPlayer in getSortedPlayers() do
		if sortedPlayer == player then
			return index
		end
	end

	return 0
end

-------------------------------------------------
--// TowerService
-------------------------------------------------
local TowerService = {}
TowerService.PlacedTowers = {}

function TowerService.GetTowerCount(player: Player, towerName: string)
	local playerData = TowerService.PlacedTowers[player.UserId]
	return (playerData and playerData[towerName]) or 0
end

function TowerService.SpawnTower(player: Player, towerName: string, spawnLocation: Vector3)
	local towerModel = ReplicatedStorage.Assets.Towers:FindFirstChild(towerName)
	if not towerModel then
		warn(`{towerName}의 이름을 가진 모델을 찾을 수 없습니다.`)
		return
	end

	local borderRadius = towerModel.PrimaryPart.Size.X * 1.5
	local sendData = {
		["TowerName"] = towerName,
		["SpawnPosition"] = spawnLocation,
		["BorderRadius"] = borderRadius,
		["CurrentCash"] = EconomyService.GetCash(player),
		["CurrentCount"] = TowerService.GetTowerCount(player, towerName),
	}

	local canSpawn, errorMsg = PlaceValidator.CheckSpawn(sendData)
	if not canSpawn then
		warn(errorMsg)
		return
	end

	local towerInfo = TowerData.ByName[towerName]
	EconomyService.SubtractCash(player, towerInfo.Stats[0].Cost)

	local placedCounts = TowerService.PlacedTowers[player.UserId]
	placedCounts[towerName] = (placedCounts[towerName] or 0) + 1

	local newTower
	if towerClasses[towerName] then
		newTower = towerClasses[towerName].new(player, TowerRegistry.generateId(), towerName, spawnLocation)
	else
		newTower = BaseTower.new(player, TowerRegistry.generateId(), towerName, spawnLocation)
	end

	newTower.SpendedCash = towerInfo.Stats[0].Cost

	newTower.Destroyed:Connect(function()
		newTower.IsDestroyed = true
		PlaceValidator.RemoveBorder(newTower.Id)
		TowerRegistry.remove(newTower.Id)

		placedCounts[towerName] -= 1
	end)

	local borderData = { x = spawnLocation.X, z = spawnLocation.Z, r = borderRadius }
	PlaceValidator.AddBorder(newTower.Id, borderData)
	TowerRegistry.add(newTower)

	return newTower
end

function TowerService.UpgradeTower(player: Player, towerId: number)
	local targetTower = TowerRegistry.get(towerId)

	if not targetTower or targetTower.Owner ~= player then
		warn(`비정상적인 업그레이드 시도: {player.Name}, {towerId}`)
		return false
	end

	local towerInfo = TowerData.ByName[targetTower.Name]
	local nextLevelStats = towerInfo.Stats[targetTower.Level + 1]
	local nextCost = nextLevelStats.Cost
	if not nextLevelStats or not nextCost then
		return false
	end

	if EconomyService.GetCash(player) < nextCost then
		return false
	end

	local success = targetTower:Upgrade(player)
	if success then
		targetTower.SpendedCash += nextCost
		EconomyService.SubtractCash(player, nextCost)

		Net.TowerService.TowerUpdated.FireAll({
			towerId = towerId,
			towerLevel = targetTower.Level,
		})
	end

	return success
end

function TowerService.SellTower(player: Player, towerId: number)
	local targetTower = TowerRegistry.get(towerId)

	if not targetTower or targetTower.Owner ~= player then
		warn(`비정상적인 판매 시도: {player.Name}, {towerId}`)
		return false
	end

	local success = targetTower:Sell(player)
	if success then
		EconomyService.AddCash(player, targetTower.SpendedCash / 2)
	end

	return success
end

function TowerService:DestroyAll()
	for _, tower in TowerRegistry.getAll() do
		tower:Destroy()
	end
end

function TowerService._SpawnNewTower(player: Player, data: { towerIndex: number, spawnLocation: Vector3 })
	if typeof(data) ~= "table" or typeof(data.towerIndex) ~= "number" or typeof(data.spawnLocation) ~= "Vector3" then
		return
	end

	local towerInfo = TowerData.ByIndex[data.towerIndex]
	if not towerInfo then
		return
	end

	local towerClass = TowerService.SpawnTower(player, towerInfo.Name, data.spawnLocation)
	if not towerClass then
		return
	end

	Net.TowerService.TowerSpawned.FireExcept(player, {
		towerId = towerClass.Id,
		towerIndex = data.towerIndex,
		ownerSlot = getPlayerSlot(player),
		spawnLocation = data.spawnLocation,
	})

	return towerClass.Id
end

function TowerService.Init(services)
	EconomyService = services:GetService("EconomyService")

	local ClassesFolder = ServerScriptService.Server.Classes.Tower
	if ClassesFolder then
		for _, module in ClassesFolder:GetChildren() do
			if module:IsA("ModuleScript") and module.Name ~= "BaseTower" then
				towerClasses[module.Name] = require(module)
			end
		end
	end
end

function TowerService.Start()
	for _, player in Players:GetPlayers() do
		TowerService.PlacedTowers[player.UserId] = {}
	end
	Players.PlayerAdded:Connect(function(player)
		TowerService.PlacedTowers[player.UserId] = {}
	end)
	Players.PlayerRemoving:Connect(function(player)
		TowerService.PlacedTowers[player.UserId] = nil
	end)

	Net.TowerService.SpawnNewTower.On(function(player, data)
		return TowerService._SpawnNewTower(player, data)
	end)

	Net.TowerService.UpgradeTower.On(function(player: Player, towerId: number)
		return TowerService.UpgradeTower(player, towerId)
	end)

	Net.TowerService.SellTower.On(function(player: Player, towerId: number)
		return TowerService.SellTower(player, towerId)
	end)

	Net.TowerService.SetTargetMode.On(function(player: Player, data)
		return TowerService.SetTargetMode(player, data)
	end)
end

function TowerService.SetTargetMode(player: Player, data: { towerId: number, targetMode: string }): boolean
	local targetTower = TowerRegistry.get(data.towerId)

	if not targetTower or targetTower.Owner ~= player then
		warn(`비정상적인 타겟 모드 변경 시도: {player.Name}, {data.towerId}`)
		return false
	end

	local validModes = { "First", "Last", "Strongest", "Weakest", "Closest", "Farthest", "Random" }
	if not table.find(validModes, data.targetMode) then
		warn(`잘못된 타겟 모드: {data.targetMode}`)
		return false
	end

	targetTower.TargetMode = data.targetMode

	Net.TowerService.TowerTargetModeUpdated.FireAll({
		towerId = data.towerId,
		targetMode = data.targetMode,
	})

	return true
end

return TowerService
