--/Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

--/Modules
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local Net = require(ReplicatedStorage.Shared.Net)
local TowerService
local TimeService

local CHECK_INTERVAL = 0.1

-------------------------------------------------
--// BuffComponent
-------------------------------------------------
local BuffComponent = {}
BuffComponent.__index = BuffComponent

function BuffComponent.new(tower)
	local self = setmetatable({}, BuffComponent)
	self.Tower = tower
	self.BuffedTowers = {}
	self.IsDestroyed = false

	if not self.Tower.ActiveBuffs then
		self.Tower.ActiveBuffs = {}
	end

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
		timeLeft = CHECK_INTERVAL
		self:_UpdateBuff()
	end)
end

function BuffComponent:SetStats()
	self:_UpdateBuff(true)
end

function BuffComponent:_UpdateBuff(refreshExisting)
	local towersCurrentlyInRange = {}
	local range = self.Tower.Stats.Range or 0

	TowerService = TowerService or ServiceRegistry:GetService("TowerService")

	for _, tower in TowerService.GetAll() do
		if tower == self.Tower or tower.IsDestroyed then
			continue
		end

		local offset = tower.Position - self.Tower.Position

		if offset.X ^ 2 + offset.Z ^ 2 <= range ^ 2 then
			towersCurrentlyInRange[tower] = true

			if refreshExisting or not self.BuffedTowers[tower] then
				self.BuffedTowers[tower] = true
				self:_ApplyBuff(tower)
			end
		end
	end

	for buffedTower, _ in pairs(self.BuffedTowers) do
		if not towersCurrentlyInRange[buffedTower] then
			self.BuffedTowers[buffedTower] = nil
			self:_RemoveBuff(buffedTower)
		end
	end
end

function BuffComponent:_ApplyBuff(targetTower)
	if self.IsDestroyed or targetTower.IsDestroyed then
		return
	end

	local damage = self.Tower.Stats.DamageBuff or 0
	local range = self.Tower.Stats.RangeBuff or 0
	local cooldown = self.Tower.Stats.CooldownBuff or 0
	local previous = targetTower.ActiveBuffs[self.Tower]
	if
		previous
		and previous.DamageBuff == damage
		and previous.RangeBuff == range
		and previous.CooldownBuff == cooldown
	then
		return
	end

	targetTower.ActiveBuffs[self.Tower] = {
		DamageBuff = damage,
		RangeBuff = range,
		CooldownBuff = cooldown,
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
	if not targetTower.ActiveBuffs[self.Tower] then
		return
	end
	targetTower.ActiveBuffs[self.Tower] = nil

	if targetTower.IsDestroyed then
		return
	end

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
	if self.IsDestroyed then
		return
	end
	self.IsDestroyed = true

	if self.HeartbeatConnection then
		self.HeartbeatConnection:Disconnect()
		self.HeartbeatConnection = nil
	end

	for buffedTower, _ in pairs(self.BuffedTowers) do
		self.BuffedTowers[buffedTower] = nil
		self:_RemoveBuff(buffedTower)
	end
	table.clear(self.BuffedTowers)
end

return BuffComponent
