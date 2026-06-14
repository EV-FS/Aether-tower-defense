--/Services
local ServerScriptService = game:GetService("ServerScriptService")

--/Classes
local BaseTower = require(ServerScriptService.Server.Classes.Tower.BaseTower)

--/Constants
local RANDOM = Random.new()

-------------------------------------------------
--// WizardNoob
-------------------------------------------------
local WizardNoob = setmetatable({}, BaseTower)
WizardNoob.__index = WizardNoob

function WizardNoob.new(player: Player, towerId: number, towerName: string, position: Vector3)
	local self = BaseTower.new(player, towerId, towerName, position)
	setmetatable(self, WizardNoob)

	self:GetEvent("AfterDamaged"):Connect(function(target)
		if not target or target.IsDead then
			return
		end

		local chance = RANDOM:NextNumber() * 100
		if chance <= (self.Stats.KnockbackChance or 0) then
			target:TakeKnockback(self.Stats.KnockbackDistance or 7.5)
		elseif chance <= (self.Stats.StunChance or 0) then
			target:ApplyDebuff("Stun", self.Stats.StunDuration or 1.5)
		end

		target:ApplyDebuff("Slow", self.Stats.SlowDuration or 1.5, self.Stats.Slow)
	end)

	return self
end

return WizardNoob
