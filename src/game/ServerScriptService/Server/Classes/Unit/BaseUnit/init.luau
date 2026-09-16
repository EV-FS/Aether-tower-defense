local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Packages.Signal)
local UnitData = require(ReplicatedStorage.Settings.Data.UnitData)
local EnemyData = require(ReplicatedStorage.Settings.Data.EnemyData)
local GetPath = require(ReplicatedStorage.Shared.Modules.Core.GetPath)
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)
local Net = require(ReplicatedStorage.Shared.Net)

-------------------------------------------------
--// BaseUnit
-------------------------------------------------
local BaseUnit = {}
BaseUnit.__index = BaseUnit

function BaseUnit.new(
	summoner,
	unitId: number,
	unitName: string,
	pathAlpha: number?,
	isEnemyType: boolean?,
	customUnitStats: { [string]: any }?
)
	local self = setmetatable({}, BaseUnit)

	self.Id = unitId
	self.Summoner = summoner
	self.SummonerId = summoner.Id

	self.Name = unitName
	self.PathAlpha = pathAlpha or 1
	self.IsEnemyType = isEnemyType
	self.TargetMode = "First"

	self.Position = GetPath:Get():CalculateUniformPosition(self.PathAlpha)

	self.Died = Signal.new()
	self.Destroyed = Signal.new()

	local targetData = isEnemyType and EnemyData.ByName[self.Name] or UnitData.ByName[self.Name]
	if targetData then
		self.BaseSpeed = targetData.WalkSpeed
		self.MaxHealth = targetData.MaxHealth
		self.Stats = targetData.Stats and TableUtils.DeepCopy(targetData.Stats)

		local custom = customUnitStats or (self.Summoner and self.Summoner.Stats and self.Summoner.Stats.UnitStats)
		if custom then
			if custom.MaxHealth then
				self.MaxHealth = custom.MaxHealth
			end
			if custom.WalkSpeed then
				self.BaseSpeed = custom.WalkSpeed
			end

			if self.Stats then
				for key, val in pairs(custom) do
					if key ~= "MaxHealth" and key ~= "WalkSpeed" then
						self.Stats[key] = val
					end
				end
			end
		end

		self.WalkSpeed = self.BaseSpeed
		self.Health = self.MaxHealth
	end

	self.Components = {}
	self:_AddComponent("CrashComponent")

	self:_ApplyNewStats()

	return self
end

function BaseUnit:TakeDamage(amount: number)
	if self.IsDead then
		return
	end

	self.Health -= amount

	Net.UnitService.OnDamaged.FireAll({
		unitId = self.Id,
		damaged = amount,
	})

	if self.Health <= 0 and not self.IsDead then
		self.IsDead = true
		self.Died:Fire()

		self:Destroy()
	end
end

function BaseUnit:Destroy(forcing: boolean?)
	for _, component in pairs(self.Components) do
		component:Destroy()
	end
	table.clear(self.Components)

	self.Destroyed:Fire(forcing)

	if self.Destroyed then
		task.defer(self.Destroyed.Destroy, self.Destroyed)
	end
end

function BaseUnit:_ApplyNewStats()
	if not self.Stats then
		return
	end

	local needsAttack = self.Stats.AttackType and self.Stats.Damage
	local needsExplosion = self.Stats.ExplosionRange and self.Stats.ExplosionDamage

	if needsAttack and not self.Components["AttackComponent"] then
		self:_AddComponent("AttackComponent")
	end
	if needsExplosion and not self.Components["ExplosionComponent"] then
		self:_AddComponent("ExplosionComponent")
	end
end

function BaseUnit:_AddComponent(componentName: string)
	if self.Components[componentName] then
		warn(`이미 '{componentName}' 컴포넌트가 존재함.`)
		return self.Components[componentName]
	end

	local targetComponent = script.Components:FindFirstChild(componentName)
	if not targetComponent then
		warn(`'{componentName}'는 존재하지 않는 컴포넌트임.`)
		return nil
	end

	local newComponent = require(targetComponent).new(self)
	self.Components[componentName] = newComponent

	if type(newComponent.Start) == "function" then
		newComponent:Start()
	end

	return newComponent
end

return BaseUnit
