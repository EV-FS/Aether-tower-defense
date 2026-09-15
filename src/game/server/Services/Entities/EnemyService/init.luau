--/Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

--/Modules
local Promise = require(ReplicatedStorage.Packages.Promise)
local BaseEnemy = require(ServerScriptService.Server.Classes.Enemy.BaseEnemy)
local Signal = require(ReplicatedStorage.Packages.Signal)
local EnemyData = require(ReplicatedStorage.Settings.Data.EnemyData)
local GameSettings = require(ReplicatedStorage.Settings.Game.GameSettings)
local GetPath = require(ReplicatedStorage.Shared.Modules.Core.GetPath)
local SpatialHashGrid = require(ReplicatedStorage.Shared.Modules.Core.SpatialHashGrid)
local Net = require(ReplicatedStorage.Shared.Net)
local EnemyRegistry = require(script.Registry)

local TimeService

--/Variables
local isActived = false
local connection
local enemyClasses = {}

-------------------------------------------------
--// EnemyService
-------------------------------------------------
local EnemyService = {}
EnemyService.EnemyReached = Signal.new()
EnemyService.EnemyDefeated = Signal.new()

EnemyService.EnemyGrid = SpatialHashGrid.new(10)

EnemyService.Get = EnemyRegistry.get
EnemyService.GetAll = EnemyRegistry.getAll

function EnemyService.SetupNewEnemy(name: string, isBoss: boolean?, pathAlpha: number?, pathId: number?)
	local self
	if enemyClasses[name] then
		self = enemyClasses[name].new(EnemyRegistry.generateId(), name, isBoss, pathId, pathAlpha)
	else
		self = BaseEnemy.new(EnemyRegistry.generateId(), name, isBoss, pathId, pathAlpha)
	end

	self.Destroyed:Connect(function(forcing: boolean?)
		self.IsDestroyed = true
		EnemyService.EnemyGrid:Remove(self)
		if forcing then
			Net.EnemyService.DestroyEnemy.FireAll(self.Id)
		end

		EnemyRegistry.remove(self.Id)
		EnemyService.EnemyDefeated:Fire(self)
	end)

	EnemyRegistry.add(self)

	EnemyService:StartMoveEnemies()

	self.SendTimeMs = math.floor(workspace:GetServerTimeNow() * 1000) % 65536
	Net.EnemyService.ReplicatedEnemy.FireAll({
		enemyId = self.Id,
		enemyIndex = EnemyData.ByName[self.Name].Index,
		sendTimeMs = self.SendTimeMs,
		isBoss = self.IsBoss,
		-- Omit the optional f32 for the usual start-at-zero spawn (saves 4 bytes).
		startPathAlpha = if self.PathAlpha == 0 then nil else self.PathAlpha,
		pathId = self.PathId,
	})
end

function EnemyService.Spawn(
	name: string,
	spawnCount: number?,
	spawnDelay: number?,
	isBoss: boolean?,
	path: (string | number)?
)
	-- Resolve names once per group, before starting the asynchronous spawn loop.
	local pathIds = GetPath:GetSpawnPathIds(isBoss, path)
	return Promise.new(function(resolve, _, onCancel)
		local isCancelled = false

		onCancel(function()
			isCancelled = true
		end)

		task.spawn(function()
			local timeOffset = 0
			local count = spawnCount or 1
			local targetDelay = spawnDelay or GameSettings.SpawnDelay
			for _ = 1, count or 1 do
				if isCancelled then
					return
				end

				-- Explicit routes override defaults; unnamed spawns only use numbered paths.
				for _, pathId in ipairs(pathIds) do
					if isCancelled then
						return
					end
					EnemyService.SetupNewEnemy(name, isBoss, nil, pathId)
				end

				local waitTime = targetDelay - timeOffset
				if waitTime > 0 then
					timeOffset = TimeService.DeltaWait(waitTime)
				else
					timeOffset = -waitTime
				end

				if isCancelled then
					return
				end
			end

			resolve()
		end)
	end)
end

function EnemyService:StartMoveEnemies()
	if isActived then
		return
	end
	isActived = true

	connection = RunService.Heartbeat:Connect(function(dt)
		local toMoveEnemies = EnemyRegistry.getAll()

		if next(toMoveEnemies) == nil then
			isActived = false

			connection:Disconnect()
			connection = nil

			return
		end

		local gameSpeed = TimeService:GetGameSpeed()
		for _, enemy in pairs(toMoveEnemies) do
			local path = GetPath:Get(enemy.PathId)
			local pathLength = path:GetPathLength()
			enemy.PathAlpha += ((enemy.WalkSpeed * dt * gameSpeed) / pathLength) * enemy.MoveDirection
			enemy.PathAlpha = math.clamp(enemy.PathAlpha, 0, 1)

			enemy.Position = path:CalculateUniformPosition(enemy.PathAlpha)
			self.EnemyGrid:Update(enemy, enemy.Position)

			if enemy.PathAlpha >= 1 then
				self.EnemyGrid:Remove(enemy)
				self.EnemyReached:Fire(enemy)
				enemy:Destroy()
			end
		end
	end)
end

function EnemyService:DestroyAll()
	local list = {}
	for _, enemy in pairs(EnemyService.GetAll()) do
		table.insert(list, enemy)
	end
	for _, enemy in ipairs(list) do
		enemy:Destroy(true)
	end
end

function EnemyService.PlayerAdded(player: Player)
	for _, enemy in EnemyRegistry.getAll() do
		Net.EnemyService.ReplicatedEnemy.Fire(player, {
			enemyId = enemy.Id,
			enemyIndex = EnemyData.ByName[enemy.Name].Index,
			sendTimeMs = math.floor(workspace:GetServerTimeNow() * 1000) % 65536,
			isBoss = enemy.IsBoss,
			startPathAlpha = if enemy.PathAlpha == 0 then nil else enemy.PathAlpha,
			pathId = enemy.PathId,
		})
	end
end

function EnemyService.Init(services)
	TimeService = services:GetService("TimeService")

	local ClassesFolder = ServerScriptService.Server.Classes.Enemy
	if ClassesFolder then
		for _, module in ClassesFolder:GetChildren() do
			if module:IsA("ModuleScript") and module.Name ~= "BaseEnemy" then
				enemyClasses[module.Name] = require(module)
			end
		end
	end
end

function EnemyService.Start() end

return EnemyService
