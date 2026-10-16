--/Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

--/Modules
local Debuffs = require(script.Debuffs)
local AbilityComponent = require(script.Components.AbilityComponent)
local AttributeComponent = require(script.Components.AttributeComponent)
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
	IsDestroyed: boolean,
	Components: { [string]: any },
	EventSignals: { [string]: typeof(Signal.new()) },

	BaseSpeed: number,
	WalkSpeed: number,
	MaxHealth: number,
	Health: number,
	MaxShieldHealth: number,
	ShieldHealth: number,
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
	self.IsDestroyed = false
	self.Started = false
	self.Components = {}
	self.EventSignals = {}
	self._connections = {}

	self.Destroyed = Signal.new()

	local targetData = EnemyData.ByName[self.Name]
	if targetData then
		self.BaseSpeed = targetData.WalkSpeed
		self.WalkSpeed = self.BaseSpeed

		local healthMultiplier = GetHealthMultiplier()
		self.MaxHealth = math.floor(targetData.MaxHealth * healthMultiplier)
		self.Health = self.MaxHealth
		self.MaxShieldHealth = math.max(0, math.floor((targetData.ShieldHealth or 0) * healthMultiplier))
		self.ShieldHealth = self.MaxShieldHealth

		if targetData.Attributes and next(targetData.Attributes) then
			self.Components.Attributes = AttributeComponent.new(self, targetData.Attributes)
		end
		if targetData.Abilities and next(targetData.Abilities) then
			self.Components.Abilities = AbilityComponent.new(self, targetData.Abilities)
		end
	end

	return self
end

function BaseEnemy:GetEvent(eventName: string)
	if not self.EventSignals[eventName] then
		self.EventSignals[eventName] = Signal.new()
	end
	return self.EventSignals[eventName]
end

function BaseEnemy:SetAttribute(name: string, config)
	if self.IsDead or self.IsDestroyed then
		return
	end

	local component = self.Components.Attributes
	if not component then
		component = AttributeComponent.new(self)
		self.Components.Attributes = component
		if self.Started then
			component:Start()
		end
	end
	return component:SetAttribute(name, config)
end

function BaseEnemy:GetAttribute(name: string)
	local component = self.Components.Attributes
	return component and component:GetAttribute(name)
end

function BaseEnemy:HasAttribute(name: string): boolean
	local component = self.Components.Attributes
	return component ~= nil and component:HasAttribute(name)
end

function BaseEnemy:RemoveAttribute(name: string)
	local component = self.Components.Attributes
	if component then
		component:RemoveAttribute(name)
	end
end

function BaseEnemy:Start()
	if self.Started or self.IsDead or self.IsDestroyed then
		return
	end
	self.Started = true
	for _, component in pairs(self.Components) do
		component:Start()
	end
	self:GetEvent("Spawned"):Fire(self)
end

function BaseEnemy:Update(now: number, gameDt: number)
	if not self.Started or self.IsDead or self.IsDestroyed then
		return
	end
	for _, component in pairs(self.Components) do
		if component.Update then
			component:Update(now, gameDt)
		end
	end
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
	if self.IsDead or self.IsDestroyed or self.Health <= 0 or amount <= 0 then
		return 0, false
	end

	local shieldDamage = math.min(self.ShieldHealth, amount)
	local healthDamage = if self.ShieldHealth > 0 then 0 else math.min(self.Health, amount)
	local actualDamage = shieldDamage + healthDamage
	self.ShieldHealth -= shieldDamage
	self.Health -= healthDamage
	self:_ReplicateHealth()

	local isKilled = self.Health <= 0
	local context = {
		EnemyId = self.Id,
		Name = self.Name,
		Damage = actualDamage,
		HealthDamage = healthDamage,
		ShieldDamage = shieldDamage,
		Health = self.Health,
		MaxHealth = self.MaxHealth,
		ShieldHealth = self.ShieldHealth,
		MaxShieldHealth = self.MaxShieldHealth,
		Position = self.Position,
		PathId = self.PathId,
		PathAlpha = self.PathAlpha,
	}

	if isKilled then
		self.IsDead = true
	end

	if not self.IsDestroyed then
		self:GetEvent("Damaged"):Fire(context)
	end

	if isKilled then
		EconomyService = EconomyService or ServiceRegistry:GetService("EconomyService")
		EconomyService.AddKillCash(self.MaxHealth)
		if not self.IsDestroyed then
			self:GetEvent("Died"):Fire(context)
		end
		self:Destroy()
	end

	return actualDamage, isKilled
end

function BaseEnemy:Heal(amount: number): number
	if self.IsDead or self.IsDestroyed or amount <= 0 then
		return 0
	end

	local healed = math.min(self.MaxHealth - self.Health, math.floor(amount))
	if healed <= 0 then
		return 0
	end
	self.Health += healed
	self:_ReplicateHealth()
	return healed
end

function BaseEnemy:RestoreShield(amount: number): number
	if self.IsDead or self.IsDestroyed or amount <= 0 then
		return 0
	end

	local restored = math.min(self.MaxShieldHealth - self.ShieldHealth, math.floor(amount))
	if restored <= 0 then
		return 0
	end
	self.ShieldHealth += restored
	self:_ReplicateHealth()
	return restored
end

function BaseEnemy:_ReplicateHealth()
	Net.EnemyService.HealthUpdated.FireAll({
		enemyId = self.Id,
		health = self.Health,
		shieldHealth = self.ShieldHealth,
	})
end

function BaseEnemy:Destroy(forcing: boolean?)
	if self.IsDestroyed then
		return
	end
	self.IsDestroyed = true
	self.Started = false

	for _, component in pairs(self.Components) do
		component:Destroy()
	end
	table.clear(self.Components)

	self:_StopDebuffLoop()

	for _, conn in ipairs(self._connections) do
		conn:Disconnect()
	end

	self._connections = {}
	self.ActiveDebuffs = nil

	self.Destroyed:Fire(forcing)
	for _, signal in pairs(self.EventSignals) do
		signal:Destroy()
	end
	table.clear(self.EventSignals)
	task.defer(self.Destroyed.Destroy, self.Destroyed)
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
			sentClockTime = NumberUtils.FormatSendClockTime(),
		})
	end
	if oldDirection ~= self.MoveDirection then
		Net.EnemyService.UpdateDirection.FireAll({
			enemyId = self.Id,
			MoveDirection = (self.MoveDirection == 1),
			sentClockTime = NumberUtils.FormatSendClockTime(),
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
