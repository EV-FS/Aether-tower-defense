local Burn = {}
Burn.__index = Burn

function Burn.new(tower, config, _)
	local self = setmetatable({}, Burn)

	self.Connection = tower:GetEvent("AfterDamaged"):Connect(function(enemy)
		if not enemy then
			return
		end

		enemy:ApplyDebuff("Burn", config.Duration, config.Amount, tower)
	end)

	return self
end

function Burn:Destroy()
	self.Connection:Disconnect()
end

return Burn
