--/Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

--/Modules
local FindTarget = require(ReplicatedStorage.Shared.Modules.Core.FindTarget)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local Net = require(ReplicatedStorage.Shared.Net)

local TimeService

-------------------------------------------------
--// AttackComponent
-------------------------------------------------
local AttackComponent = {}
AttackComponent.__index = AttackComponent

function AttackComponent.new(tower, stats, attackSlot)
	local self = setmetatable({}, AttackComponent)
	self.Tower = tower
	self.Stats = stats
	self.AttackSlot = attackSlot

	self.CooldownTimer = 0

	return self
end

function AttackComponent:SetStats(stats)
	self.Stats = stats
end

function AttackComponent:Start()
	TimeService = TimeService or ServiceRegistry:GetService("TimeService")

	self.HeartbeatConnection = RunService.Heartbeat:Connect(function(dt)
		self.CooldownTimer -= dt * TimeService:GetGameSpeed()

		if self.CooldownTimer > 0 then
			return
		end

		local attackCount = 0
		local maxAttacksPerFrame = 3

		while self.CooldownTimer <= 0 and attackCount < maxAttacksPerFrame do
			local didAttack = self:_Attack()

			if didAttack then
				self.CooldownTimer += self.Stats.Cooldown
				attackCount += 1
			else
				self.CooldownTimer = 0
				break
			end
		end
	end)
end

function AttackComponent:Destroy()
	if self.HeartbeatConnection then
		self.HeartbeatConnection:Disconnect()
		self.HeartbeatConnection = nil
	end
end

function AttackComponent:_ExecuteAttack(attackType, target)
	if not self.Tower or self.Tower.IsDestroyed then
		return
	end

	if attackType == "Single" then
		self:_ApplyDamage(target)
	elseif attackType == "Splash" then
		self:_SplashAOEAttack(target)
	elseif attackType == "Angle" then
		self:_AngleAOEAttack(target)
	elseif attackType == "Line" then
		self:_LineAOEAttack(target)
	end
end

function AttackComponent:_Attack(): boolean
	local target = FindTarget.GetTarget(self.Tower, self.Stats.Range)
	if not target then
		return false
	end

	local currentAttackType = self.Stats.AttackType
	local attackDelay = self.Stats.AttackDelay or 0

	Net.TowerService.OnAttackEnemy.FireAll({
		towerId = self.Tower.Id,
		enemyId = target.Id,
		attackSlot = self.AttackSlot,
	})

	if attackDelay > 0 then
		TimeService = TimeService or ServiceRegistry:GetService("TimeService")
		TimeService.DeltaDelay(attackDelay):andThen(function()
			self:_ExecuteAttack(currentAttackType, target)
		end)
	else
		self:_ExecuteAttack(currentAttackType, target)
	end

	return true
end

function AttackComponent:_ApplyDamage(target)
	if not target or target.IsDestroyed then
		return
	end

	local damageContext = {
		Amount = self.Stats.Damage,
		Target = target,
	}

	self.Tower:GetEvent("BeforeDamage"):Fire(damageContext)

	local actualDamage, isKilled = target:TakeDamage(damageContext.Amount)
	if actualDamage and actualDamage > 0 then
		self.Tower:GetEvent("AfterDamaged"):Fire(target, actualDamage)
	end

	if isKilled then
		self.Tower:GetEvent("Killed"):Fire(target)
	end
end

function AttackComponent:_SplashAOEAttack(target)
	local targetList = FindTarget.GetTargetInSplash(self.Stats, target.Position)
	self:_ApplyAOEDamage(targetList)
end

function AttackComponent:_AngleAOEAttack(target)
	local targetList = FindTarget.GetTargetInAngle(self.Tower, self.Stats, self.Tower.Position, target.Position)
	self:_ApplyAOEDamage(targetList)
end

function AttackComponent:_LineAOEAttack(target)
	local targetList = FindTarget.GetTargetInLine(self.Tower, self.Stats, target.Position)
	self:_ApplyAOEDamage(targetList)
end

function AttackComponent:_ApplyAOEDamage(targetList)
	for _, enemy in targetList do
		self:_ApplyDamage(enemy)
	end
end

return AttackComponent
