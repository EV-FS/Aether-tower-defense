--/Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

--/Modules
local TowerData = require(ReplicatedStorage.Settings.Data.TowerData)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local Registry = require(ServerScriptService.Server.Services.Entities.TowerService.Registry)
local TimeService

-------------------------------------------------
--// BuffComponent
-------------------------------------------------
local BuffComponent = {}
BuffComponent.__index = BuffComponent

function BuffComponent.new(tower)
	local self = setmetatable({}, BuffComponent)
	self.Tower = tower
	if not self.Tower.ActiveBuffs then
		self.Tower.ActiveBuffs = {}
	end

	self.LevelUpConnection = {}
	self.BuffedTowers = {}

	self.Tower:GetEvent("LevelUp"):Connect(function()
		for buffedTower, _ in pairs(self.BuffedTowers) do
			self:_ApplyBuff(buffedTower)
		end
		self:_UpdateBuff()
	end)

	return self
end

function BuffComponent:Start()
	local checkInterval = 0.2
	local timeLeft = 0

	TimeService = TimeService or ServiceRegistry:GetService("TimeService")

	self.HeartbeatConnection = RunService.Heartbeat:Connect(function(dt)
		timeLeft -= dt * TimeService:GetGameSpeed()
		if timeLeft > 0 then
			return
		end
		timeLeft += checkInterval

		self:_UpdateBuff()
	end)
end

function BuffComponent:_UpdateBuff()
	local towersCurrentlyInRange = {}

	for _, tower in Registry.getAll() do
		if tower == self.Tower then
			continue
		end

		local offset = tower.Position - self.Tower.Position

		if offset.X ^ 2 + offset.Z ^ 2 <= self.Tower.Stats.Range ^ 2 then
			towersCurrentlyInRange[tower] = true

			if not self.BuffedTowers[tower] then
				self:_ApplyBuff(tower)
				self.BuffedTowers[tower] = true
			end
		end
	end

	for buffedTower, _ in pairs(self.BuffedTowers) do
		if not towersCurrentlyInRange[buffedTower] then
			self:_RemoveBuff(buffedTower)
			self.BuffedTowers[buffedTower] = nil
		end
	end
end

function BuffComponent:_ApplyBuff(targetTower)
	if self.LevelUpConnection[targetTower.Id] then
		self.LevelUpConnection[targetTower.Id]:Disconnect()
		self.LevelUpConnection[targetTower.Id] = nil
	end

	targetTower.ActiveBuffs[self.Tower] = {
		DamageBuff = self.Tower.Stats.DamageBuff or 0,
		RangeBuff = self.Tower.Stats.RangeBuff or 0,
		CooldownBuff = self.Tower.Stats.CooldownBuff or 0,
	}

	self.LevelUpConnection[targetTower.Id] = targetTower:GetEvent("LevelUp"):Connect(function()
		self:_ApplyBuff(targetTower)
	end)

	self:_SetTargetStats(targetTower)
end

function BuffComponent:_RemoveBuff(targetTower)
	if self.LevelUpConnection[targetTower.Id] then
		self.LevelUpConnection[targetTower.Id]:Disconnect()
		self.LevelUpConnection[targetTower.Id] = nil
	end

	targetTower.ActiveBuffs[self.Tower] = nil

	self:_SetTargetStats(targetTower)
end

function BuffComponent:_SetTargetStats(tower)
	local defaultStats = TowerData.ByName[tower.Name].Stats[tower.Level]

	local maxDamageBuff = 0
	local maxRangeBuff = 0
	local maxCooldownBuff = 0

	for _, buffData in pairs(tower.ActiveBuffs) do
		maxDamageBuff = math.max(maxDamageBuff, buffData.DamageBuff)
		maxRangeBuff = math.max(maxRangeBuff, buffData.RangeBuff)
		maxCooldownBuff = math.max(maxCooldownBuff, buffData.CooldownBuff)
	end

	tower.Stats.Damage = defaultStats.Damage * (1 + maxDamageBuff / 100)
	tower.Stats.Range = defaultStats.Range * (1 + maxRangeBuff / 100)
	tower.Stats.Cooldown = defaultStats.Cooldown * (1 - maxCooldownBuff / 100)
end

function BuffComponent:Destroy()
	if self.HeartbeatConnection then
		self.HeartbeatConnection:Disconnect()
		self.HeartbeatConnection = nil
	end

	for _, connection in pairs(self.LevelUpConnection) do
		connection:Disconnect()
	end
	table.clear(self.LevelUpConnection)

	for buffedTower, _ in pairs(self.BuffedTowers) do
		self:_RemoveBuff(buffedTower)
	end
	table.clear(self.BuffedTowers)
end

return BuffComponent
