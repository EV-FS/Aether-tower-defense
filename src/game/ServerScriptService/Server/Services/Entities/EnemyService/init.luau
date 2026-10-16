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
local NumberUtils = require(ReplicatedStorage.Shared.Modules.Utils.NumberUtils)
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
	EnemyService.EnemyGrid:Update(self, self.Position)

	EnemyService:StartMoveEnemies()

	Net.EnemyService.ReplicatedEnemy.FireAll({
		enemyId = self.Id,
		enemyIndex = EnemyData.ByName[self.Name].Index,
		sentClockMs = NumberUtils.FormatSendClockTimeMs(),
		isBoss = self.IsBoss,
		startPathAlpha = if self.PathAlpha == 0 then nil else self.PathAlpha,
		pathId = self.PathId,
		maxHealth = self.MaxHealth,
		maxShieldHealth = self.MaxShieldHealth,
	})

	self:Start()
	return self
end

function EnemyService.Spawn(
	name: string,
	spawnCount: number?,
	spawnDelay: number?,
	isBoss: boolean?,
	path: (string | number)?
)
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
		-- New summons join the next update rather than the current iteration.
		local toMoveEnemies = table.clone(EnemyRegistry.getAll())

		if next(toMoveEnemies) == nil then
			isActived = false

			connection:Disconnect()
			connection = nil

			return
		end

		local gameSpeed = TimeService:GetGameSpeed()
		local gameDt = dt * gameSpeed
		local now = TimeService:Now()
		for _, enemy in pairs(toMoveEnemies) do
			if enemy.IsDead or enemy.IsDestroyed then
				continue
			end
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

		-- Select targets and spawn at positions updated during this heartbeat.
		for _, enemy in pairs(toMoveEnemies) do
			if not enemy.IsDead and not enemy.IsDestroyed then
				enemy:Update(now, gameDt)
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
		if enemy.IsDead or enemy.IsDestroyed then
			continue
		end
		Net.EnemyService.ReplicatedEnemy.Fire(player, {
			enemyId = enemy.Id,
			enemyIndex = EnemyData.ByName[enemy.Name].Index,
			sentClockMs = NumberUtils.FormatSendClockTimeMs(),
			isBoss = enemy.IsBoss,
			startPathAlpha = if enemy.PathAlpha == 0 then nil else enemy.PathAlpha,
			pathId = enemy.PathId,
			maxHealth = enemy.MaxHealth,
			maxShieldHealth = enemy.MaxShieldHealth,
		})
		if enemy.Health ~= enemy.MaxHealth or enemy.ShieldHealth ~= enemy.MaxShieldHealth then
			Net.EnemyService.HealthUpdated.Fire(player, {
				enemyId = enemy.Id,
				health = enemy.Health,
				shieldHealth = enemy.ShieldHealth,
			})
		end
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
