local RANDOM = Random.new()

local Wizard = {}
Wizard.__index = Wizard

function Wizard.new(tower, config, _)
	local self = setmetatable({}, Wizard)

	self.Connection = tower:GetEvent("AfterDamaged"):Connect(function(target)
		if not target or target.IsDead then
			return
		end

		local chance = RANDOM:NextNumber() * 100
		if chance <= (config.KnockbackChance or -1) then
			target:TakeKnockback(config.KnockbackAmount or 7.5)
		elseif chance <= (config.StunChance or -1) then
			target:ApplyDebuff("Stun", config.StunDuration or 1.5)
		end
	end)

	return self
end

function Wizard:Destroy()
	self.Connection:Disconnect()
end

return Wizard
