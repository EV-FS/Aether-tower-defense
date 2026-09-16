--/Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--/Modules
local FindTarget = require(ReplicatedStorage.Shared.Modules.Core.FindTarget)

-------------------------------------------------
--// ExplosionComponent
-------------------------------------------------
local ExplosionComponent = {}
ExplosionComponent.__index = ExplosionComponent

function ExplosionComponent.new(unit)
	local self = setmetatable({}, ExplosionComponent)
	self.Unit = unit

	return self
end

function ExplosionComponent:Start()
	self.DiedConnection = self.Unit.Died:Connect(function()
		self:Explosion()
	end)
end

function ExplosionComponent:Explosion()
	local affectEnemies = FindTarget.GetEnemiesInRange(self.Unit, self.Unit.Stats.ExplosionRange)

	for _, enemy in affectEnemies do
		local _, isKilled = enemy:TakeDamage(self.Unit.Stats.ExplosionDamage)

		if isKilled and self.Unit.Summoner then
			self.Unit.Summoner:GetEvent("Killed"):Fire(enemy)
		end
	end
end

function ExplosionComponent:Destroy()
	if self.DiedConnection then
		self.DiedConnection:Disconnect()
		self.DiedConnection = nil
	end
end

return ExplosionComponent
