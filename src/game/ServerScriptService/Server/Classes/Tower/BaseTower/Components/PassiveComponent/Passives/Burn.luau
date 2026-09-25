local Burn = {}
Burn.__index = Burn

function Burn.new(tower, config, _)
	local self = setmetatable({}, Burn)
	self.Config = config

	self.Connection = tower:GetEvent("AfterDamaged"):Connect(function(enemy)
		if not enemy then
			return
		end

		enemy:ApplyDebuff("Burn", self.Config.Duration, self.Config.Amount, tower)
	end)

	return self
end

function Burn:UpdateConfig(newConfig)
	self.Config = newConfig
end

function Burn:Destroy()
	self.Connection:Disconnect()
end

return Burn
