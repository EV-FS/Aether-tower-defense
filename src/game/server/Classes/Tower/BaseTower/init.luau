--/Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--/Configs
local Signal = require(ReplicatedStorage.Packages.Signal)
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)
local TraitData = require(ReplicatedStorage.Settings.Data.TraitData)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local TableUtils = require(ReplicatedStorage.Shared.Modules.Utils.TableUtils)
local Net = require(ReplicatedStorage.Shared.Net)
local DataService

export type Tower = {
	Id: number,
	Name: string,
	TowerKey: string,
	Owner: Player,
	Level: number,
	MaxLevel: number,
	TargetMode: string,
	Position: Vector3,

	Destroyed: typeof(Signal.new()),

	Components: { [string]: any },
	Stats: { [string]: any },
}

-------------------------------------------------
--// Local Functions
-------------------------------------------------
local function getSummonKey(i)
	return if i == 1 then "Summon" else "Summon_" .. i
end

-------------------------------------------------
--// BaseTower
-------------------------------------------------
local BaseTower = {}
BaseTower.__index = BaseTower

function BaseTower.new(
	player: Player,
	towerId: number,
	towerName: string,
	towerKey: string,
	position: Vector3,
	towerProfile
): Tower
	local self = setmetatable({}, BaseTower)

	self.Id = towerId
	self.Name = towerName
	self.TowerKey = towerKey
	self.Owner = player
	self.TowerProfile = towerProfile
	self.Level = 0
	self.MaxLevel = self:_CalculateMaxLevel()
	self.TargetMode = "First"
	self.Position = position

	self.Destroyed = Signal.new()

	self.Components = {}
	self.EventSignals = {}

	self:_ApplyNewStats()
	self:_AddTowerExp()

	return self
end

function BaseTower:Upgrade(player: Player): boolean
	if self.Owner ~= player or self.Level >= self.MaxLevel then
		return false
	end

	self.Level += 1
	self:_ApplyNewStats()
	self:GetEvent("LevelUp"):Fire(self.Level)

	return true
end

function BaseTower:Sell(player: Player): boolean
	if self.Owner ~= player then
		return false
	end

	self:Destroy()

	return true
end

function BaseTower:GetEvent(eventName: string)
	if not self.EventSignals[eventName] then
		self.EventSignals[eventName] = Signal.new()
	end
	return self.EventSignals[eventName]
end

function BaseTower:Destroy()
	if self.IsDestroyed then
		return
	end
	self.IsDestroyed = true

	for _, component in pairs(self.Components) do
		component:Destroy()
	end
	table.clear(self.Components)

	self.Destroyed:Fire()

	if self.EventSignals then
		for _, signal in pairs(self.EventSignals) do
			signal:Destroy()
		end
		table.clear(self.EventSignals)
	end
	if self.Destroyed then
		task.defer(self.Destroyed.Destroy, self.Destroyed)
	end

	Net.TowerService.TowerDestroyed.FireAll(self.Id)
end

function BaseTower:_AddTowerExp()
	if not self.Owner or not self.Owner:IsDescendantOf(Players) then
		return
	end

	DataService = DataService or ServiceRegistry:GetService("DataService")
	if self.TowerKey then
		self:GetEvent("Killed"):Connect(function(_)
			DataService:AdjustTower(self.Owner, self.Name, self.TowerKey, "Exp", 10)
		end)
	end
end

function BaseTower:_RecalculateStats()
	self.Stats = TableUtils.DeepCopy(TowerData.ByName[self.Name].Stats[self.Level])

	local traitName = self.TowerProfile.Trait
	local traitData = TraitData.ByName[traitName]

	local handlers = {
		DamageMultiflier = function(val)
			if not self.Stats.Damage then
				return
			end

			self.Stats.Damage *= 1 + val
		end,
		RangeMultiflier = function(val)
			if not self.Stats.Damage then
				return
			end

			self.Stats.Range *= 1 + val
		end,
		CooldownMultiflier = function(val)
			if not self.Stats.Range then
				return
			end

			self.Stats.Cooldown *= 1 - val
		end,
	}

	for effectName, effectValue in traitData.Effects do
		local handler = handlers[effectName]
		if handler then
			handler(effectValue)
		end
	end
end

function BaseTower:_ApplyNewStats()
	self:_RecalculateStats()

	local needsAttack = self.Stats.AttackType and self.Stats.Damage
	local needsSecondaryAttack = self.Stats.Secondary and self.Stats.Secondary.AttackType
	local needsFarm = self.Stats.Income
	local needsBuff = self.Stats.DamageBuff or self.Stats.RangeBuff or self.Stats.CooldownBuff

	self:_SyncComponent("Attack", "AttackComponent", needsAttack, self.Stats)
	self:_SyncComponent("SecondaryAttack", "AttackComponent", needsSecondaryAttack, self.Stats.Secondary, 2)
	self:_SyncComponent("Farm", "FarmComponent", needsFarm)
	self:_SyncComponent("Buff", "BuffComponent", needsBuff)

	local passives = self.Stats.Passives or {}
	self:_SyncComponent("Passives", "PassiveComponent", TableUtils.Length(passives) > 0, passives)

	local summons = self.Stats.Summons or (self.Stats.SummonUnit and { self.Stats }) or {}

	local previousCount = self._activeSummonCount or 0
	self._activeSummonCount = #summons

	for i, config in ipairs(summons) do
		self:_SyncComponent(getSummonKey(i), "SummonComponent", config.SummonUnit ~= nil, config)
	end

	for i = #summons + 1, previousCount do
		self:_SyncComponent(getSummonKey(i), "SummonComponent", false)
	end
end

function BaseTower:_SyncComponent(key: string, componentName: string, shouldExist: boolean?, ...)
	local component = self.Components[key]

	if shouldExist then
		if not component then
			self:_AddComponent(key, componentName, ...)
			return
		end

		if component.SetStats and select("#", ...) > 0 then
			component:SetStats(...)
		end
		return
	end

	if component then
		component:Destroy()
		self.Components[key] = nil
	end
end

function BaseTower:_AddComponent(key: string, componentName: string, ...)
	if self.Components[key] then
		warn(`이미 '{key}' 컴포넌트가 존재함.`)
		return self.Components[key]
	end

	local targetComponent = script.Components:FindFirstChild(componentName)
	if not targetComponent then
		warn(`'{componentName}'는 존재하지 않는 컴포넌트임.`)
		return nil
	end

	local newComponent = require(targetComponent).new(self, ...)
	self.Components[key] = newComponent

	if type(newComponent.Start) == "function" then
		newComponent:Start()
	end

	return newComponent
end

function BaseTower:_CalculateMaxLevel(): number
	local maxLevel = 0
	local statsData = TowerData.ByName[self.Name].Stats

	for level in statsData do
		if level > maxLevel then
			maxLevel = level
		end
	end

	return maxLevel
end

return BaseTower
