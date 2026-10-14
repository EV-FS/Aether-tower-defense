--/Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

--/Modules
local FindTarget = require(ReplicatedStorage.Shared.Modules.Core.FindTarget)
local ServiceRegistry = require(ReplicatedStorage.Shared.Modules.Core.ServiceRegistry)
local Net = require(ReplicatedStorage.Shared.Net)

local TimeService

local function resolveHitStats(stats, hit)
	return {
		AttackType = hit.AttackType or stats.AttackType,
		Damage = math.max(0, math.floor(stats.Damage * (hit.DamageScale or 1))),

		Range = hit.Range or stats.Range,
		SplashRange = hit.SplashRange or stats.SplashRange,
		Angle = hit.Angle or stats.Angle,
		Width = hit.Width or stats.Width,
	}
end

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
		if self.Tower.StunRemaining > 0 then
			return false
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

function AttackComponent:_ApplyDamage(target, hitStats, hitIndex, hitCount)
	if not target or target.IsDestroyed then
		return
	end

	local damageContext = {
		Amount = hitStats.Damage,
		Target = target,
		HitIndex = hitIndex,
		HitCount = hitCount,
		AttackSlot = self.AttackSlot,
	}

	self.Tower:GetEvent("BeforeDamage"):Fire(damageContext)

	local actualDamage, isKilled = target:TakeDamage(damageContext.Amount)
	if actualDamage and actualDamage > 0 then
		self.Tower:GetEvent("AfterDamaged"):Fire(target, actualDamage, damageContext)
	end

	if isKilled then
		self.Tower:GetEvent("Killed"):Fire(target)
	end
end

function AttackComponent:_DamageToEnemies(targetList, hitStats, hitIndex, hitCount)
	if not targetList then
		return
	end

	for _, enemy in targetList do
		self:_ApplyDamage(enemy, hitStats, hitIndex, hitCount)
	end
end

function AttackComponent:_ExecuteAttack(stats, hit, target, hitIndex, hitCount)
	if not self.Tower or self.Tower.IsDestroyed or not target then
		return
	end

	local hitStats = resolveHitStats(stats, hit)
	local attackType = hitStats.AttackType
	local targetPosition = target.Position
	local targetList

	if attackType == "Single" then
		targetList = { target }
	elseif attackType == "Splash" then
		targetList = FindTarget.GetTargetInSplash(hitStats, targetPosition)
	elseif attackType == "Angle" then
		targetList = FindTarget.GetTargetInAngle(self.Tower, hitStats, self.Tower.Position, targetPosition)
	elseif attackType == "Line" then
		targetList = FindTarget.GetTargetInLine(self.Tower, hitStats, targetPosition)
	else
		warn(`Unknown AttackType: {tostring(attackType)}`)
		return
	end

	self:_DamageToEnemies(targetList, hitStats, hitIndex, hitCount)
end

function AttackComponent:_Attack(): boolean
	local stats = table.clone(self.Stats)
	local target = FindTarget.GetTarget(self.Tower, stats.Range)
	if not target then
		return false
	end

	local hits = stats.Hits or {
		{
			Delay = stats.AttackDelay or 0,
			AttackType = stats.AttackType,
		},
	}

	Net.TowerService.OnAttackEnemy.FireAll({
		towerId = self.Tower.Id,
		enemyId = target.Id,
		attackSlot = self.AttackSlot,
	})

	for hitIndex, hit in hits do
		local currentHit = hit
		local currentHitIndex = hitIndex
		local hitDelay = currentHit.Delay or 0

		local function executeHit()
			self:_ExecuteAttack(stats, currentHit, target, currentHitIndex, #hits)
		end

		if hitDelay > 0 then
			TimeService.DeltaDelay(hitDelay):andThen(executeHit)
		else
			executeHit()
		end
	end

	return true
end

return AttackComponent
