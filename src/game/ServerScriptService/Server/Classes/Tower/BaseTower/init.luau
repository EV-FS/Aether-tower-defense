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
local TraitHandlers = require(script.TraitHandlers)
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

function BaseTower.new(player: Player, towerId: number, towerName: string, towerKey: string, position: Vector3): Tower
	local self = setmetatable({}, BaseTower)

	self.Id = towerId
	self.Name = towerName
	self.TowerKey = towerKey
	self.Owner = player
	self.Level = 0
	self.MaxLevel = self:_CalculateMaxLevel()
	self.TargetMode = "First"
	self.Position = position
	DataService = DataService or ServiceRegistry:GetService("DataService")
	local playerData = DataService and DataService:GetData(player)
	local ownedTower = playerData and playerData.OwnedTowers[towerName] and playerData.OwnedTowers[towerName][towerKey]
	self.Trait = if ownedTower then ownedTower.Trait else nil

	self.Destroyed = Signal.new()

	self.Components = {}
	self.EventSignals = {}
	self.ActiveBuffs = {}

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

	local trait = if self.Trait then TraitData.ByName[self.Trait] else nil
	if trait then
		for _, effect in trait.Effects or {} do
			local handler = TraitHandlers[effect.Handler]
			if handler then
				handler(self, effect.Value)
			end
		end
	end

	if self.ActiveBuffs then
		local maxDamageBuff = 0
		local maxRangeBuff = 0
		local maxCooldownBuff = 0

		for _, buffData in pairs(self.ActiveBuffs) do
			maxDamageBuff = math.max(maxDamageBuff, buffData.DamageBuff)
			maxRangeBuff = math.max(maxRangeBuff, buffData.RangeBuff)
			maxCooldownBuff = math.max(maxCooldownBuff, buffData.CooldownBuff)
		end

		if self.Stats.Damage then
			self.Stats.Damage *= 1 + maxDamageBuff / 100
		end
		if self.Stats.Range then
			self.Stats.Range *= 1 + maxRangeBuff / 100
		end
		if self.Stats.Cooldown then
			self.Stats.Cooldown *= 1 - maxCooldownBuff / 100
		end
	end

	if self.Stats.Damage then
		self.Stats.Damage = math.floor(self.Stats.Damage)
	end
	if self.Stats.Range then
		self.Stats.Range = math.floor(self.Stats.Range * 10) / 10
	end
	if self.Stats.Cooldown then
		self.Stats.Cooldown = math.floor(self.Stats.Cooldown * 100) / 100
	end
end

function BaseTower:_ApplyNewStats()
	if self.IsDestroyed then
		return
	end

	self:_RecalculateStats()

	local needsAttack = self.Stats.AttackType and self.Stats.Damage
	local needsSecondaryAttack = self.Stats.Secondary and self.Stats.Secondary.AttackType
	local needsFarm = self.Stats.Income and self.Stats.IsFarm
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

	Net.TowerService.StatsUpdated.FireAll({
		towerId = self.Id,
		stats = self.Stats,
	})
end

function BaseTower:_SyncComponent(key: string, componentName: string, shouldExist: boolean?, ...)
	local component = self.Components[key]

	if shouldExist then
		if not component then
			self:_AddComponent(key, componentName, ...)
			return
		end

		if component.SetStats then
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
