local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)

local AbilityComponent = {}
AbilityComponent.__index = AbilityComponent

function AbilityComponent.new(enemy, abilities)
	local self = setmetatable({}, AbilityComponent)
	self.Enemy = enemy
	self.Abilities = abilities or {}
	self.ActiveAbilities = {}
	self.Started = false
	self.IsDestroyed = false

	self.FireTriggered = function(abilityType: string, arg: any?)
		if self.IsDestroyed or self.Enemy.IsDestroyed then
			return
		end
		Net.EnemyService.AbilityTriggered.FireAll({
			enemyId = self.Enemy.Id,
			abilityType = abilityType,
			arg = arg,
		})
		self.Enemy:GetEvent("AbilityTriggered"):Fire(abilityType, arg)
	end

	return self
end

function AbilityComponent:Start()
	if self.Started or self.IsDestroyed or self.Enemy.IsDead or self.Enemy.IsDestroyed then
		return
	end

	self.Started = true
	self:_SyncAbilities()
end

function AbilityComponent:_SyncAbilities()
	self:_DestroyAbilities()

	for _, config in ipairs(self.Abilities) do
		local module = script.Abilities:FindFirstChild(config.Type)
		if not module or not module:IsA("ModuleScript") then
			warn(`알 수 없는 어빌리티: {config.Type}.`)
			continue
		end

		table.insert(self.ActiveAbilities, require(module).new(self.Enemy, config, self.FireTriggered))
	end

	for _, ability in ipairs(self.ActiveAbilities) do
		if self.IsDestroyed or self.Enemy.IsDead or self.Enemy.IsDestroyed then
			break
		end
		if ability.Start then
			ability:Start()
		end
	end
end

function AbilityComponent:Update(now: number, gameDt: number)
	if not self.Started or self.IsDestroyed or self.Enemy.IsDead or self.Enemy.IsDestroyed then
		return
	end

	for _, ability in ipairs(self.ActiveAbilities) do
		if self.IsDestroyed or self.Enemy.IsDead or self.Enemy.IsDestroyed then
			break
		end
		if ability.Update then
			ability:Update(now, gameDt)
		end
	end
end

function AbilityComponent:_DestroyAbilities()
	local abilities = self.ActiveAbilities
	self.ActiveAbilities = {}
	for _, ability in ipairs(abilities) do
		ability:Destroy()
	end
end

function AbilityComponent:Destroy()
	if self.IsDestroyed then
		return
	end

	self.IsDestroyed = true
	self.Started = false
	self:_DestroyAbilities()
end

return AbilityComponent
