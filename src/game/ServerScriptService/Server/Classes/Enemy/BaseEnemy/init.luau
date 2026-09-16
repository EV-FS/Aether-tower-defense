--/Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

--/Modules
local Debuffs = require(script.Debuffs)
local Signal = require(ReplicatedStorage.Packages.Signal)
local EnemyData = require(ReplicatedStorage.Settings.Data.EnemyData)
local GetPath = require(ReplicatedStorage.Shared.Modules.Core.GetPath)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local NumberUtils = require(ReplicatedStorage.Shared.Modules.Utils.NumberUtils)
local Net = require(ReplicatedStorage.Shared.Net)

local TimeService
local EconomyService
local GameService

local DOT_TICK_INTERVAL = 0.5

--/Types
export type Enemy = {
	Id: number,
	Name: string,
	MoveDirection: number,
	PathAlpha: number,
	PathId: number,

	Position: Vector3,

	ActiveDebuffs: {},
	DotValues: {},

	IsDead: boolean,
	Destroyed: typeof(Signal.new()),

	BaseSpeed: number,
	WalkSpeed: number,
	MaxHealth: number,
	Health: number,
	IsBoss: boolean?,
}

local sortedDebuffs = {}
for name, data in pairs(Debuffs) do
	table.insert(sortedDebuffs, { Name = name, Priority = data.Priority or 0 })
end
table.sort(sortedDebuffs, function(a, b)
	return a.Priority < b.Priority
end)

-------------------------------------------------
--// Local Functions
-------------------------------------------------
local function GetHealthMultiplier(): number
	GameService = GameService or ServiceRegistry:GetService("GameService")

	local difficulty = GameService and GameService.SelectedDifficulty or "Normal"
	local playerCount = GameService and GameService.StartPlayerCount or 1

	local diffMultiplier = 1
	if difficulty == "Hard" then
		diffMultiplier = 2
	elseif difficulty == "Eternal" then
		diffMultiplier = 3
	end
	local playerMultiplier = 1 + ((playerCount - 1) * 0.5)

	return diffMultiplier * playerMultiplier
end

-------------------------------------------------
--// BaseEnemy
-------------------------------------------------
local BaseEnemy = {}
BaseEnemy.__index = BaseEnemy

function BaseEnemy.new(id, name, isBoss, pathId: number?, pathAlpha: number?): Enemy
	local self = setmetatable({}, BaseEnemy)

	self.Id = id
	self.Name = name
	self.MoveDirection = 1
	self.PathId = pathId or 1
	self.PathAlpha = pathAlpha or 0
	self.IsBoss = isBoss

	self.Position = GetPath:Get(self.PathId):CalculateUniformPosition(self.PathAlpha)

	self.ActiveDebuffs = {}
	self.DotValues = {}
	self._DebuffTime = 0

	self.IsDead = false
	self._connections = {}

	self.Destroyed = Signal.new()

	local targetData = EnemyData.ByName[self.Name]
	if targetData then
		self.BaseSpeed = targetData.WalkSpeed
		self.WalkSpeed = self.BaseSpeed
		self.MaxHealth = math.floor(targetData.MaxHealth * GetHealthMultiplier())
		self.Health = self.MaxHealth
	end

	return self
end

function BaseEnemy:ApplyDebuff(name: string, duration: number, power: number?, source: any?)
	if self.IsDead or self.IsDestroyed or not self.ActiveDebuffs then
		return
	end

	local debuffData = Debuffs[name]
	if not debuffData then
		return
	end
	if self.IsBoss and debuffData.IgnoreBoss then
		return
	end

	TimeService = TimeService or ServiceRegistry:GetService("TimeService")

	local currentTime = self._DebuffTime
	local currentEndTime = currentTime + duration
	local existing = self.ActiveDebuffs[name]

	if name == "Stun" then
		if self._StunImmune and currentTime < self._StunImmune then
			return
		else
			self._StunImmune = currentTime + duration * 1.5
		end
	end

	if existing then
		local existingPower = existing.Power or 0
		local newPower = power or 0
		if existing.EndTime >= currentEndTime and existingPower >= newPower then
			return
		end

		existing.EndTime = currentEndTime
		existing.Power = power
		existing.Source = source
	else
		self.ActiveDebuffs[name] = {
			EndTime = currentEndTime,
			NextTickAt = currentTime + DOT_TICK_INTERVAL,
			Power = power,
			Source = source,
		}
	end

	self:_RecalculateStats()
	self:_StartDebuffLoop()
end

function BaseEnemy:TakeKnockback(studs: number)
	if studs <= 0 or self.IsBoss then
		return
	end

	studs = math.floor(studs * 10) / 10

	local pathLength = GetPath:Get(self.PathId):GetPathLength()
	local knockbackAlpha = studs / pathLength

	local duration = 0.2
	local startTime = os.clock()
	local startAlpha = self.PathAlpha
	local targetAlpha = math.clamp(startAlpha - knockbackAlpha, 0, 1)

	TimeService = TimeService or ServiceRegistry:GetService("TimeService")

	task.spawn(function()
		while true do
			local elapsed = (os.clock() - startTime) * TimeService:GetGameSpeed()
			if elapsed >= duration then
				break
			end

			local t = elapsed / duration
			local easedT = t * (2 - t)
			self.PathAlpha = math.clamp(NumberUtils.Lerp(startAlpha, targetAlpha, easedT), 0, 1)
			task.wait()
		end
		self.PathAlpha = targetAlpha
	end)

	Net.EnemyService.TakeKnockback.FireAll({
		enemyId = self.Id,
		["studs"] = studs * 10,
	})
end

function BaseEnemy:TakeDamage(amount: number)
	if self.IsDead or self.Health <= 0 then
		return 0, false
	end

	local actualDamage = math.min(self.Health, amount)
	self.Health -= actualDamage

	Net.EnemyService.OnDamaged.FireAll({
		enemyId = self.Id,
		damaged = actualDamage,
	})

	if self.Health <= 0 and not self.IsDead then
		self.IsDead = true

		EconomyService = EconomyService or ServiceRegistry:GetService("EconomyService")
		EconomyService.AddKillCash(self.MaxHealth)
		self:Destroy()
	end

	return actualDamage, self.IsDead
end

function BaseEnemy:Destroy(forcing: boolean?)
	self:_StopDebuffLoop()

	for _, conn in ipairs(self._connections) do
		conn:Disconnect()
	end

	self._connections = {}
	self.ActiveDebuffs = nil

	self.Destroyed:Fire(forcing)
end

function BaseEnemy:_RecalculateStats()
	local oldSpeed = self.WalkSpeed
	local oldDirection = self.MoveDirection

	self.WalkSpeed = self.BaseSpeed
	self.MoveDirection = 1

	local newDotValues = {}

	for _, data in ipairs(sortedDebuffs) do
		local activeInfo = self.ActiveDebuffs[data.Name]
		if not activeInfo then
			continue
		end

		local logic = Debuffs[data.Name]
		if logic and logic.OnApplyStats then
			logic.OnApplyStats(self, activeInfo.Power, newDotValues)
		end
	end

	if oldSpeed ~= self.WalkSpeed then
		Net.EnemyService.UpdateSpeed.FireAll({
			enemyId = self.Id,
			WalkSpeed = self.WalkSpeed * 100,
			sendTimeMs = math.floor(workspace:GetServerTimeNow() * 1000) % 65536,
		})
	end
	if oldDirection ~= self.MoveDirection then
		Net.EnemyService.UpdateDirection.FireAll({
			enemyId = self.Id,
			MoveDirection = (self.MoveDirection == 1),
			sendTimeMs = math.floor(workspace:GetServerTimeNow() * 1000) % 65536,
		})
	end

	self.DotValues = newDotValues
end

function BaseEnemy:_StartDebuffLoop()
	if self._DebuffConnection then
		return
	end

	self._DebuffConnection = RunService.Heartbeat:Connect(function(dt)
		self._DebuffTime += dt * TimeService:GetGameSpeed()
		self:_UpdateDebuffs(self._DebuffTime)
	end)
end

function BaseEnemy:_StopDebuffLoop()
	if self._DebuffConnection then
		self._DebuffConnection:Disconnect()
		self._DebuffConnection = nil
	end
end

function BaseEnemy:_UpdateDebuffs(currentTime: number)
	if self.IsDead or not self.ActiveDebuffs then
		return
	end

	local requiresStatRecalculation = false

	for name, activeInfo in pairs(self.ActiveDebuffs) do
		local damage = self.DotValues[name]
		local finalTickTime = math.min(currentTime, activeInfo.EndTime)

		while damage and damage > 0 and activeInfo.NextTickAt <= finalTickTime do
			activeInfo.NextTickAt += DOT_TICK_INTERVAL

			local source = activeInfo.Source
			local _, isKilled = self:TakeDamage(damage)
			if isKilled then
				if source then
					source:GetEvent("Killed"):Fire(self)
				end
				return
			end
		end

		if currentTime >= activeInfo.EndTime then
			self.ActiveDebuffs[name] = nil
			requiresStatRecalculation = true
		end
	end

	if requiresStatRecalculation and self.ActiveDebuffs then
		self:_RecalculateStats()
	end

	if not self.ActiveDebuffs or not next(self.ActiveDebuffs) then
		self:_StopDebuffLoop()
		self._DebuffTime = 0
	end
end

return BaseEnemy
