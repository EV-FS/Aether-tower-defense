local REGEN_RATIO = 1
local REGEN_CYCLE = 1

local HealthRegen = {}
HealthRegen.__index = HealthRegen

function HealthRegen.new(enemy, config)
	local self = setmetatable({}, HealthRegen)
	self.Enemy = enemy
	self.Elapsed = 0
	self.IsDestroyed = false
	self:UpdateConfig(config)

	return self
end

function HealthRegen:UpdateConfig(config)
	self.Config = config or {}
end

function HealthRegen:Update(_now: number, gameDt: number)
	if self.IsDestroyed or self.Enemy.IsDead or self.Enemy.IsDestroyed then
		return
	end

	self.Elapsed += gameDt
	if self.Elapsed >= REGEN_CYCLE then
		self.Elapsed -= REGEN_CYCLE

		self.Enemy:Heal(math.max(1, math.floor(self.Enemy.MaxHealth * (self.Config.RegenRatio or REGEN_RATIO / 100))))
	end
end

function HealthRegen:Destroy()
	self.IsDestroyed = true
end

return HealthRegen
