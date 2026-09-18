--/Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

--/Modules
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local Net = require(ReplicatedStorage.Shared.Net)
local TowerService
local TimeService

local CHECK_INTERVAL = 0.2

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
	local timeLeft = 0

	TimeService = TimeService or ServiceRegistry:GetService("TimeService")

	self.HeartbeatConnection = RunService.Heartbeat:Connect(function(dt)
		timeLeft -= dt * TimeService:GetGameSpeed()
		if timeLeft > 0 then
			return
		end
		timeLeft += CHECK_INTERVAL

		self:_UpdateBuff()
	end)
end

function BuffComponent:_UpdateBuff()
	local towersCurrentlyInRange = {}

	TowerService = TowerService or ServiceRegistry:GetService("TowerService")

	for _, tower in TowerService.GetAll() do
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
	targetTower.ActiveBuffs[self.Tower] = {
		DamageBuff = self.Tower.Stats.DamageBuff or 0,
		RangeBuff = self.Tower.Stats.RangeBuff or 0,
		CooldownBuff = self.Tower.Stats.CooldownBuff or 0,
	}

	targetTower:_ApplyNewStats()

	Net.TowerService.OnApplyBuff.FireAll({
		towerId = self.Tower.Id,
		targetId = targetTower.Id,
	})
	Net.TowerService.OnBuffAdded.FireAll({
		bufferId = self.Tower.Id,
		targetId = targetTower.Id,
		activeBuffs = targetTower.ActiveBuffs[self.Tower],
	})
end

function BuffComponent:_RemoveBuff(targetTower)
	targetTower.ActiveBuffs[self.Tower] = nil

	targetTower:_ApplyNewStats()

	Net.TowerService.OnRemoveBuff.FireAll({
		towerId = self.Tower.Id,
		targetId = targetTower.Id,
	})
	Net.TowerService.OnBuffRemoved.FireAll({
		bufferId = self.Tower.Id,
		targetId = targetTower.Id,
	})
end

function BuffComponent:Destroy()
	if self.HeartbeatConnection then
		self.HeartbeatConnection:Disconnect()
		self.HeartbeatConnection = nil
	end

	for buffedTower, _ in pairs(self.BuffedTowers) do
		self:_RemoveBuff(buffedTower)
	end
	table.clear(self.BuffedTowers)
end

return BuffComponent
