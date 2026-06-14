--/Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

--/Modules
local Debuffs = require(script.Debuffs)
local Promise = require(ReplicatedStorage.Packages.Promise)
local Signal = require(ReplicatedStorage.Packages.Signal)
local EnemyData = require(ReplicatedStorage.Settings.Data.EnemyData)
local GetPath = require(ReplicatedStorage.Shared.Modules.Core.GetPath)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local NumberUtils = require(ReplicatedStorage.Shared.Modules.Utils.NumberUtils)
local Net = require(ReplicatedStorage.Shared.Net)

local TimeService
local EconomyService
local GameService

--/Types
export type Enemy = {
	Id: number,
	Name: string,
	MoveDirection: number,
	PathAlpha: number,

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
	if difficulty == "Normal" then
		diffMultiplier = 1.5
	elseif difficulty == "Hard" then
		diffMultiplier = 2
	elseif difficulty == "Extreme" then
		diffMultiplier = 2.5
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

function BaseEnemy.new(id, name, isBoss): Enemy
	local self = setmetatable({}, BaseEnemy)

	self.Id = id
	self.Name = name
	self.MoveDirection = 1
	self.PathAlpha = 0
	self.IsBoss = isBoss

	self.Position = GetPath:Get():CalculateUniformPosition(self.PathAlpha)

	self.ActiveDebuffs = {}
	self.DotValues = {}

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
	local debuffData = Debuffs[name]
	if not debuffData then
		return
	end
	if self.IsBoss and debuffData.IgnoreBoss then
		return
	end

	local currentEndTime = os.clock() + duration
	local existing = self.ActiveDebuffs[name]

	if existing then
		if existing.EndTime >= currentEndTime and existing.Power >= power then
			return
		end
		if existing.TimerPromise then
			existing.TimerPromise:cancel()
		end

		existing.EndTime = currentEndTime
		existing.Power = power
		existing.Source = source
	else
		self.ActiveDebuffs[name] = {
			EndTime = currentEndTime,
			Power = power,
			Source = source,
			TimerPromise = nil,
		}
	end

	self:_RecalculateStats()

	TimeService = TimeService or ServiceRegistry:GetService("TimeService")

	local newPromise = TimeService.DeltaDelay(duration):andThen(function()
		if not self.ActiveDebuffs then
			return
		end

		if self.ActiveDebuffs[name] then
			self.ActiveDebuffs[name] = nil
			self:_RecalculateStats()
		end
	end)

	self.ActiveDebuffs[name].TimerPromise = newPromise
end

function BaseEnemy:TakeKnockback(studs: number)
	if studs <= 0 or self.IsBoss then
		return
	end

	studs = math.floor(studs * 10) / 10

	local pathLength = GetPath:Get():GetPathLength()
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
	self:_StopDotLoop()

	for _, conn in ipairs(self._connections) do
		conn:Disconnect()
	end
	self._connections = {}

	if self.ActiveDebuffs then
		for _, debuff in pairs(self.ActiveDebuffs) do
			if debuff.TimerPromise then
				debuff.TimerPromise:cancel()
			end
		end
	end
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

	if next(self.DotValues) then
		self:_StartDotLoop()
	else
		self:_StopDotLoop()
	end
end

function BaseEnemy:_StartDotLoop()
	if self._DotConnection then
		return
	end

	self._DotConnection = RunService.Heartbeat:Connect(function(dt)
		self._dotTimer = (self._dotTimer or 0) + dt * TimeService:GetGameSpeed()
		if self._dotTimer >= 1 then
			self._dotTimer = 0
			self:_ProcessDotDamage()
		end
	end)
end

function BaseEnemy:_StopDotLoop()
	if self._DotConnection then
		self._DotConnection:Disconnect()
		self._DotConnection = nil
	end
end

function BaseEnemy:_ProcessDotDamage()
	for dotType, damage in pairs(self.DotValues) do
		if damage <= 0 then
			continue
		end

		local activeInfo = self.ActiveDebuffs[dotType]
		local source = activeInfo and activeInfo.Source
		local _, isKilled = self:TakeDamage(damage)

		if isKilled then
			if source then
				source:GetEvent("Killed"):Fire(self)
			end
			break
		end
	end
end

return BaseEnemy
